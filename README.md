# scribe

Always-on auto-journaling for Claude Code. Per-project consent. Single-file install. No CLI knowledge required.

## What it does

scribe makes Claude write a plain-English design history of your project as you work — decisions, lessons, experiments, and a daily log of every session. You talk to Claude in plain English; scribe handles the rest.

- **Always on.** Once enabled in a project, every Claude Code session contributes to a `journal/` folder.
- **Per-project consent.** scribe never journals a project until you say yes to it. The first time you open Claude in a new project, Claude asks once.
- **Pause/resume in English.** Say "pause journaling" or "resume journaling". Or use the `/journal-pause` slash command.
- **Archive at project end.** Say "archive this project" and Claude saves a single-file Markdown summary to your desktop. A copy is kept in scribe's library so future projects can recall what you learned.
- **Cross-project recall.** Ask Claude "have we faced this before?" — scribe searches your past projects and surfaces relevant excerpts.

## Install

1. Download `scribe-installer.sh` from the [latest release](https://github.com/<org>/scribe/releases/latest) using your browser.
2. Open Terminal and run:

   ```
   bash ~/Downloads/scribe-installer.sh
   ```

3. Open Claude Code in any project. Claude will ask once whether to enable journaling there. Answer yes.

That's it. No `curl | bash`, no network access required during install (everything is bundled), no system packages to install. Works in restricted corporate environments.

## Uninstall

```
bash ~/.scribe/uninstall.sh
```

You'll be asked whether to keep your archived past-project journals (defaults to yes).

## Requirements

- macOS or Linux (including WSL).
- bash 3.2+ (built-in on macOS).
- [Claude Code](https://claude.com/claude-code) installed and on PATH.

## How it works

scribe ships as a single self-extracting installer (~7 MB) that bundles everything it needs, including platform-specific `jq` binaries. After install:

- Two hooks are wired into Claude Code's global settings: `SessionStart` (loads journal context at the start of each session) and `Stop` (a safety net that catches anything live writes missed).
- Per-project state lives in `./journal/` (gitignored by default — private to your local checkout).
- Cross-project archives live in `~/.scribe/library/`.

For the full architecture, see `docs/superpowers/specs/2026-05-03-scribe-design.md`.

## License

MIT. Bundled `jq` is also MIT — see `src/installer/jq-binaries/LICENSE-jq`.
