# osu!bot

**[osu!bot](https://reddit.com/u/osu-bot) is a Reddit bot that posts beatmap and player information to [/r/osugame](https://reddit.com/r/osugame) score posts.**

This is its third iteration, which replaces the original spaghetti-tier Ruby implementation and the "Wow I love multiple dispatch so let's write a combinatorial explosion of methods with excessively fine-grained signatures" Julia implementation. They can be found in separate branches as historical artifacts.

### Formatting Score Posts

The bot depends on you to properly format your title! The beginning of your post title should look something like this:

```
Player Name | Song Artist - Song Title [Diff Name] +Mods
```

For example:

```
Cookiezi | xi - FREEDOM DiVE [FOUR DIMENSIONS] +HDHR 99.83% FC 800pp *NEW PP RECORD*
```

In general, anything following the [official criteria](https://reddit.com/r/osugame/wiki/scoreposting) should work.

There's one notable exception which doesn't work, which is mods separated by spaces: "HD HR" and "HD, HR" both get parsed as HD only.
Additionally, prefixing the mods with "+" makes parsing much more consistent, for example "+HDHR".

### Manually Triggering Comments

The bot generally does not retry comments.
If your post didn't get a reply, you can try sending a POST request to `https://2s5lll4kz9.execute-api.us-east-1.amazonaws.com/scorepost/proxy?id=ID` where `ID` is the Reddit post ID.
For example, for [this post](https://redd.it/53l422):

```sh
# Linux/MacOS
curl -X POST "https://2s5lll4kz9.execute-api.us-east-1.amazonaws.com/scorepost/proxy?id=53l422"
```

```Powershell
# Windows (PowerShell)
Invoke-WebRequest "https://2s5lll4kz9.execute-api.us-east-1.amazonaws.com/scorepost/proxy?id=53l422" -Method POST -UseBasicParsing
```

Even if this doesn't work, the JSON response you get back should provide some insight on what went wrong.

### Contact

Messages to the bot are forwarded to me, so feel free to [PM](https://www.reddit.com/message/compose?to=osu-bot&subject=Feedback) any problems, questions, or suggestions, or just reply to one of its comments.

### Acknowledgements

Thanks to [Franc[e]sco](https://github.com/Francesco149) and [khazhyk](https://github.com/khazhyk) for [oppai](https://github.com/Francesco149/oppai-ng) and [osuapi](https://github.com/khazhyk/osuapi) respectively, both of which have saved me much time and effort.
