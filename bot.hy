(import discord)
(import json [loads])
(import openai)
(import re [sub])
(import asyncio)

(setv commands #{".gpt" ".code" ".clear"})

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
                     {"role" "system"  "content" "You're a smart and helpful AI chatbot"}])
        unawaited-completion (openai.ChatCompletion.acreate
                               :model "gpt-3.5-turbo"
                               :messages messages)
        completion (await unawaited-completion)
        choice (get completion.choices 0)]
    choice.message.content))

(defn/a write-code [prompt]
  "Write code in markdown format"
  (let [system-message "You write code in markdown format based on what the user wants"
        messages [{"role" "user"    "content" prompt}
                  {"role" "system"  "content" system-message}]
        unawaited-completion (openai.ChatCompletion.acreate
                               :model "gpt-3.5-turbo"
                               :messages messages)
        code-completion (await unawaited-completion)
        choice (get code-completion.choices 0)]
    choice.message.content))
       

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
                     ".code" (with/a [_ (message.channel.typing)]
                               (await (write-code argument)))
                     ".clear" (do
                                (del (get conversations username))
                                "Cleared the history 😇"))
          reply (message.reply response)]
      ;; Respond
      (await reply)
      ;; Update history
      (when (in username conversations)
        (+= (get conversations username)
            [{"role" "user"      "content" argument}
             {"role" "assistant" "content" response}])))))

(when (= __name__ "__main__")
  (client.run discord-token))
