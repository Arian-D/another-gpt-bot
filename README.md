Yet another GPT discord bot
===========================

You've seen enough of these ChatGPT frontends; close this tab.

# Usage #

Set up API tokens in a file called `creds.json` like this:

``` json
{
    "openai": "joemama",
    "discord": "ligma"
}
```

## Docker/Podman ##
Build and run like this:
``` shell
docker build . -t bot
docker run --rm -d --name=bot bot
```

## Manual ##

``` shell
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
./venv/bin/hy bot.hy
```

# Notes and resources #
- It's better to put the system role at the end because of
  [this](https://community.openai.com/t/has-anyone-brainstormed-a-cost-efficient-way-to-include-the-chat-history-for-conversation-based-applications/114444) 
- [OpenAI Cookbook](https://github.com/openai/openai-cookbook) has
  examples and explanation on usage tips.
- [Discord.py
  API manual](https://discordpy.readthedocs.io/en/stable/api.html)
  because I have a short memory lol
- [Hy lang
  cheatsheet](https://docs.hylang.org/en/stable/cheatsheet.html) as a
  reference
