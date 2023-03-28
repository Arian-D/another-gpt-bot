(import discord)
(import json [loads])
(import openai)
(import re [sub])
(import asyncio)

(setv commands #{".gpt" ".run" ".clear"})

(setv creds
  (with [f (open "creds.json" "r")]
    (loads (.read f))))

;; OpenAI
(setv openai.api-key (get creds "openai"))

;; Discord.py stuff
(setv discord-token (get creds "discord"))
(setv intents (discord.Intents.default))
(setv intents.message-content True)
(setv client (discord.Client :intents intents))

;; A dict to hold conversation history. [User -> Messasge list]
(setv conversations (dict))

(defn/a get-response [message [message-history (list)]]
  "Create GPT response based on the message and the user history"
  (global conversations)
  (let [messages (+ message-history
                    [{"role" "user"  "content" message}
                     {"role" "system"  "content" "Act like you're a helpful AI chatbot"}])
        completion (await (openai.ChatCompletion.acreate
                            :model "gpt-3.5-turbo"
                            :messages messages))
        choice (get completion.choices 0)]
    choice.message.content))

(defn/a run-code [prompt]
  "Write code and prepend './run' to run the code on discord. For now, it's broken"
  (let [silencer "Write code that does what the next line says. Do not say any words, do not explain, and do not send anything except the code in markdown format."
        ;; TODO: Use a separate function instead of get-response for generating code
        md-code (await (get-response f"{silencer}\n{prompt}"))]
    f"./run\n{md-code}"))

(defn/a [client.event] on-message [message]
  "On message event"
  ;; TODO: Change this to a logger
  (print message)
  ;; TODO: Add functionality to keep message history via replies instead of commands
  (when (and (.startswith message.content ".")
             (!= message.author client.user))
    (let [split (.split message.content)
          command (get split 0)
          argument (.join " " (cut split 1 None))
          username (str message.author)
          user-history (if (in username conversations)
                           (get conversations username)
                           (list))
          response (match
                     command
                     ".gpt" (with/a [_ (message.channel.typing)]
                              (await (get-response argument user-history)))
                     ".run" (await (run-code argument))
                     ".clear" (do
                                (del (get conversations username))
                                "Cleared the history 😇"))]
      ;; Respond
      (await (message.reply response))
      ;; Update history
      (when (not (.get conversations username))
        (setv (get conversations username) (list)))
      (+= (get conversations username) [{"role" "user"      "content" argument}
                                        {"role" "assistant" "content" response}]))))

(when (= __name__ "__main__")
  (client.run discord-token))
