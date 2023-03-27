(import discord)
(import json [loads])
(import openai)

(setv creds
  (with [f (open "creds.json" "r")]
    (loads (.read f))))

;; Ideally this would be a slash command but for now it's aight
(setv prefix ".gpt ")

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

(defn/a [client.event] on-message [message]
  "On message event"
  (when (message.content.startswith prefix)
    (let [request (cut message.content (len prefix) None)
          response (await (get-response request))]
      (await (message.reply response)))))


(when (= __name__ "__main__")
  (client.run discord-token))
