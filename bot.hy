(import discord
        json [loads]
        openai
        re [sub]
        asyncio
        os.path [exists :as file-exists?]
        EdgeGPT [Chatbot :as BingChat]
        ImageGen [ImageGen]
        pprint [pprint])

(setv commands #{".gpt" ".bingpt" ".dalle" ".code" ".clear"})
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
(setv client (discord.Client :intents intents))

;; A dict to hold conversation history. [User -> Messasge list]
(setv conversations (dict))

(defn/a gpt-response [message [message-history (list)]]
  "Create GPT response based on the message and the user history"
  (let [messages (+ message-history
                    [{"role" "user"  "content" message}])
        unawaited-completion (openai.ChatCompletion.acreate
                               :model model
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
                               :model model
                               :messages messages)
        code-completion (await unawaited-completion)
        choice (get code-completion.choices 0)]
    choice.message.content))
 
(defn/a bingai-response [message]
  (when (is edgegpt-cookies None)
    "Sorry, but I can't do that 😢")
  ;; TODO: Move the bot outside instead of closing on every function call
  ;; TODO: Add citations
  (let [bot (BingChat :cookies edgegpt-cookies)
        response (await (bot.ask :prompt message))
        message-history (get (get response "item") "messages")
        bot-response (get message-history 1)
        text (get bot-response "text")]
    (await (bot.close))
    text))

(defn/a bingai-dalle [prompt]
  (when (is edgegpt-cookies None)
    "Sorry, but I can't do that 😢")
  (let [cookies (filter (fn [cookie] (= (get cookie "name") "_U"))
                          edgegpt-cookies)
        auth-cookie (next cookies)
        cookie-value (get auth-cookie "value")
        image-generator (ImageGen cookie-value)
        images (image-generator.get-images prompt)
        links (.join "\n" images)]
    links))
      

(defn/a [client.event] on-message [message]
  "On message event"
  (global conversations)
  ;; TODO: Change this to a logger
  (print message)
  ;; TODO: Add functionality to keep message history via replies instead of commands
  (when (and (.startswith message.content ".")
             (!= message.author client.user))
    (let [split (.split message.content)
          ;; TODO: Macros for car and cdr cuz lispy brain go brrr
          command (get split 0)
          argument (.join " " (cut split 1 None))
          username (str message.author)
          user-history (if (in username conversations)
                           (get conversations username)
                           (list))
          response (match
                     command
                     ;; FIXME: Clean up all these async with's 
                     ".gpt" (with/a [_ (message.channel.typing)]
                              (await (gpt-response argument user-history)))
                     ".code" (with/a [_ (message.channel.typing)]
                               (await (write-code argument)))
                     ".clear" (do
                                (del (get conversations username))
                                "Cleared the history 😇")
                     ".bingpt" (with/a [_ (message.channel.typing)]
                                 (await (bingai-response argument)))
                     ;; TODO: Have the images be sent separately
                     ".dalle" (with/a [_ (message.channel.typing)]
                                (await (bingai-dalle argument)))
                     _ "Hmmm")
          reply (message.reply response)]
      ;; Respond
      (await reply)
      ;; Update history
      (if (in username conversations)
        (+= (get conversations username)
            [{"role" "user"      "content" argument}
             {"role" "assistant" "content" response}])
        (|= conversations {username (list)})))))

(when (= __name__ "__main__")
  (client.run discord-token))
