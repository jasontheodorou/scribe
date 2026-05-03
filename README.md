# Terminal Scribe

![scribe](https://github.com/jasontheodorou/terminal-scribe/blob/main/scribe_logo_001.png)

**A quiet co-author that keeps a record of your project as it unfolds.**

When you work with Claude in the terminal, you're making decisions, trying things, changing your mind, learning lessons. Most of that disappears the moment a session ends. Terminal Scribe writes it all down for you — in plain English, automatically — so it's there whenever you need it.

## Why you'd want this

**A living history of your project, with no effort.** Every Claude Code session leaves behind a journal entry: what you talked about, what you decided, what you tried. You don't have to remember to take notes. You don't have to summarise anything. It just happens.

**Continuity across sessions.** Pick up a project a week later and Claude already knows where you left off — because the journal is read at the start of every session. No more "remind me where we got to?" No more pasting in old screenshots or chat logs.

**A clean handoff when you're done.** When a project wraps up, just say *"archive this project"* and Claude saves a single tidy document to your desktop. The project summary, the key decisions, the lessons learned — all in one place. Email it to a stakeholder, save it for your portfolio, hand it to whoever takes over.

**Lessons that travel with you.** Every project you archive joins your personal library. Next time you start something new, you can ask *"have I run into this before?"* and Claude will pull the relevant wisdom from a past project. Your hard-won insights stop dying with each piece of work.

**Total privacy by default.** Your journal lives on your computer, not in the cloud. It's hidden from any team git repository so it never accidentally gets shared. You stay in control of what's recorded and what isn't.

**You can pause it anytime.** If you're about to discuss something sensitive, just tell Claude *"pause journaling"*. Resume when you're ready. The choice is always yours.

## How it works

Once installed, every Claude Code session quietly contributes to a journal folder in your project. **You don't run any commands. Claude does the writing.** You can pause it, resume it, look things up in it, or turn it off any time — just by talking to Claude in plain English.

## Install

1. Go to the [latest release](https://github.com/jasontheodorou/terminal-scribe/releases/latest) and download the file called **`scribe-installer.sh`**.
2. Open Terminal and paste this in:

   ```
   bash ~/Downloads/scribe-installer.sh
   ```

3. Open Claude Code in any project, as you normally would. Claude will ask once whether you'd like Terminal Scribe to keep a journal for that project. Say yes.

That's the whole setup. You won't need to think about it again.

## How to use it

You don't, really — that's the point. Keep working with Claude exactly as you do now.

When you want to interact with Terminal Scribe, just say so in plain English. A few things you can ask:

- *"What did we decide about the navigation last week?"* — Claude reads your journal and tells you.
- *"Summarise what we've done on this project."* — Claude writes you a recap from the journal.
- *"Pause journaling for now."* — Claude stops writing until you say resume.
- *"Resume journaling."* — Back on.
- *"Archive this project."* — Claude saves a clean summary document to your desktop.
- *"Have we faced this kind of problem before?"* — Claude looks across all your archived past projects and surfaces what's relevant.
- *"Turn off Terminal Scribe in this project."* — Claude removes it from the current project (the rest of your projects stay as they are).

No commands to memorise, no menus to navigate. Just talk.

## Uninstall

If you change your mind, open Terminal and paste this:

```
bash ~/.scribe/uninstall.sh
```

It'll ask whether you want to keep your library of past-project summaries (defaults to yes). Then it's gone.

## What you need

- A Mac, or a Linux laptop.
- [Claude Code](https://claude.com/claude-code) — the terminal app from Anthropic. If you don't have it yet, that link will sort you out.

That's it. No accounts to create, no subscriptions, no API keys. Terminal Scribe runs entirely on your own machine.

## Made for design teams

Terminal Scribe is built to match the way design work actually unfolds — messy, iterative, full of half-formed ideas that turn out to matter later. It captures the *why* behind your decisions, not just the *what*, so the trail you leave is one you can actually follow.

---

Terminal Scribe is built to stay out of your way.
