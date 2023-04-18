(import discord
        json [loads]
        openai
        os.path [exists :as file-exists?]
        EdgeGPT [Chatbot :as BingChat]
        ImageGen [ImageGen]
        pprint [pprint])

(require hyrule [unless])

(setv model "gpt-3.5-turbo")

(setv creds
      (with [f (open "creds.json" "r")]
        (loads (.read f))))

(setv edgegpt-cookies
      (if (file-exists? "cookies.json")
          (with [f (open "cookies.json" "r")]
            (loads (.read f)))
          None))

;; OpenAI
(setv openai.api-key (get creds "openai"))

;; Discord.py stuff
(setv discord-token (get creds "discord"))
(setv intents (discord.Intents.default))
(setv intents.message-content True)

(defclass MyClient [discord.Client]
  "A wrapper class for adding slash commands"
  (defn __init__ [self * #^discord.Intents intents]
    (.__init__ (super) :intents intents)
    (setv self.tree (discord.app_commands.CommandTree self)))
  (defn/a setup-hook [self]
    "Add the guild to my main server"
    (unless (.get creds "guild")
      (return))
    (let [guild-id (get creds "guild")
          guild (discord.Object :id guild-id)]
      (self.tree.copy_global_to :guild guild)
      (await (self.tree.sync :guild guild)))))

(setv client (MyClient :intents intents))

(defn/a [client.event] on-ready []
  (print f"Logged in as {client.user}"))

;; A dict to hold conversation history. [User -> Messasge list]
(setv conversations (dict))


(defn/a
  [(client.tree.command)
   (discord.app-commands.describe
     :prompt "Enter the prompt")]
  chatgpt [#^discord.Interaction interaction
           #^str prompt]
  "Create GPT response based on the message and the user history"
  (await (interaction.response.defer))
  (global conversations)
  (let [username (str interaction.user)
        message-history (.get conversations username)
        messages (+ (or message-history (list))
                    [{"role" "user"  "content" prompt}])
        unawaited-completion (openai.ChatCompletion.acreate
                               :model model
                               :messages messages)
        completion (await unawaited-completion)
        choice (get completion.choices 0)
        response choice.message.content]
    (await (interaction.followup.send response))
    (if (in username conversations)
        (+= (get conversations username)
            [{"role" "user"      "content" prompt}
             {"role" "assistant" "content" response}])
        (|= conversations {username (list)}))))

(defn/a
  [(client.tree.command)
   (discord.app-commands.describe
     :prompt "Enter the prompt")]
  bingpt [#^discord.Interaction interaction
          #^str prompt]
  "Bing AI chat"
  (when (not edgegpt-cookies)
    (return))
  (await (interaction.response.defer))
  ;; TODO: Move the bot outside instead of closing on every function call
  ;; TODO: Add citations through views
  (let [bot (BingChat :cookies edgegpt-cookies)
        response (await (bot.ask :prompt prompt))
        message-history (get (get response "item") "messages")
        bot-response (get message-history 1)
        text (get bot-response "text")]
    (await (bot.close))
    (await (interaction.followup.send text))))

(defn/a
  [(client.tree.command)
   (discord.app-commands.describe
     :prompt "Enter the prompt")]
  dalle [#^discord.Interaction interaction
         #^str prompt]
  "Bing AI's DALLE for generating images"
  (unless edgegpt-cookies
    (return))
  (await (interaction.response.defer))
  (let [cookies (filter (fn [cookie] (= (get cookie "name") "_U"))
                        edgegpt-cookies)
        auth-cookie (next cookies)
        cookie-value (get auth-cookie "value")
        image-generator (ImageGen cookie-value)
        images (image-generator.get-images prompt)
        links (.join "\n" images)]
    (for [image images]
      (await (interaction.followup.send image)))))

(defn/a
  [(client.tree.command)]
  clear [#^discord.Interaction interaction]
  "Clear conversation history"
  (global conversations)
  (del (get conversations (str interaction.user)))
  (await (interaction.response.send-message "Cleared 👍"
                                            :ephemeral True)))

(when (= __name__ "__main__")
  (client.run discord-token))
