# scribe

Always-on auto-journaling for Claude Code. Per-project consent. Single-file install.

## Install

1. Download `scribe-installer.sh` from the [latest release](https://github.com/<org>/scribe/releases/latest).
2. Open Terminal and run:

   ```
   bash ~/Downloads/scribe-installer.sh
   ```

3. Open Claude Code in any project. Claude will ask once whether to enable journaling there. Answer yes.

## Uninstall

```
bash ~/.scribe/uninstall.sh
```

## What it does

scribe makes Claude write a plain-English design history of your project as you work — decisions, lessons, experiments, and a daily log. You can pause/resume in plain English. At project end, ask Claude "archive this project" and you get a single-file Markdown summary on your desktop, plus a copy in scribe's library so future projects can recall what you've learned.

See `docs/superpowers/specs/2026-05-03-scribe-design.md` for the full design.
