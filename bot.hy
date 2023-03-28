(import discord)
(import json [loads])
(import openai)
(import re [sub])

(setv commands #{".gpt" ".run"})

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

(defn/a get-response [message]
  "Create GPT response based on the message"
  (let [completion (await (openai.ChatCompletion.acreate
                            :model "gpt-3.5-turbo"
                            :messages [{"role" "user"  "content" message}]))
        choice (get completion.choices 0)]
    choice.message.content))

(defn/a run-code [prompt]
  "Write code and prepend './run' to run the code on discord. For now, it's broken"
  (let [silencer "Write code that does what the next line says. Do not say any words, do not explain, and do not send anything except the code in markdown format."
        md-code (await (get-response f"{silencer}\n{prompt}"))]
    f"./run\n{md-code}"))

(defn/a [client.event] on-message [message]
  "On message event"
  (when (and (in (get (.split message.content) 0) commands)
             (!= message.author client.user))
    (let [split (.split message.content)
          command (get split 0)
          argument (.join " " (cut split 1 None))
          response (await (match
                            command
                            ".gpt" (get-response argument)
                            ".run" (run-code argument)))]
      (await (message.reply response)))))

(when (= __name__ "__main__")
  (client.run discord-token))
