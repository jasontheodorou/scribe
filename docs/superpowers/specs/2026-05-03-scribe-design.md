# scribe — design spec

## Context

The user built `terminal-project-kit` (the existing Claude Project Kit) but concluded it tries to do too many things. They want to extract one feature — auto-journaling — into a standalone, focused product called **scribe**.

**Requirements:**
- One-line install into Claude Code (terminal).
- Always-on auto-journaling whenever Claude works in a consenting project.
- Pause/resume via slash commands **and** plain English ("pause journaling").
- Multiple themed MD files written across each session.
- Lean SessionStart context: latest logbook entry + `lessons.md` + index of the rest.
- Per-project consent — for company use, no surveillance of unrelated projects.
- Minimal user knowledge required: after install, the user only ever talks to Claude in English. Claude runs `scribe` commands on their behalf.

**Decisions already made:**
- **Architecture:** global hooks, per-project consent gathered conversationally by Claude (not by a CLI command the user types).
- **User experience target:** after the one-line install, the user never types a `scribe` command directly. Claude asks for consent and runs commands on their behalf. The CLI exists but is invoked by Claude, not by humans.
- **Tool/repo name:** `scribe`.
- **Journal location:** `./journal/` in project root.
- **Default visibility:** entire `journal/` directory is gitignored. Private to each user's checkout.
- **Data model:** fixed core (`logbook/`, `decisions/`, `lessons.md`) + adaptive (`experiments/`, `glossary.md`, project-specific themed MDs Claude infers).
- **Memory model:** lean SessionStart load — most recent logbook entry + `lessons.md` + an index of the rest. Claude reads other files on demand.
- **Mechanism:** hybrid live writes (CLAUDE.md instruction → main Claude writes during session) + Stop-hook sub-Claude safety net.

## Architecture

### User-facing surface area (the whole thing)

A new terminal user should only ever need to do **three things in their lifetime**, none of which require knowing anything about the terminal beyond pasting one line. Everything else happens through Claude in plain English.

| Purpose | What the user does |
|---|---|
| **Install** | Download one file from a webpage. Run it with `bash`. Done. |
| **Use it** | Open Claude Code in any project. Answer "yes" once to a yes/no question. Then talk to Claude in English forever after. |
| **Uninstall** | Run `bash ~/.scribe/uninstall.sh`. Done. (No network needed.) |

There is **no** `scribe` command they need to learn, no `init` to run, no flags, no config files to edit, no environment variables to set. The CLI exists only so Claude can invoke it on the user's behalf.

### Distribution: a single self-contained installer (no curl, no network at install time)

**The problem with `curl | bash`:** in locked-down corporate environments, any of these can fail:
- Outbound HTTPS to github.com or raw.githubusercontent.com may be blocked or proxied.
- SSL inspection appliances can break `curl` certificate validation.
- Security policy may flag or block the `| bash` pattern specifically.
- Auto-downloading binary dependencies during install (e.g. `jq`) may fail for the same reasons.
- DNS for raw.githubusercontent.com may be blocked even when github.com is allowed.

**The solution: distribute scribe as a single, self-contained, self-extracting installer script.** The user downloads one file via a normal browser (which is almost always allowed), then runs it locally. No network access is required after the download.

**`scribe-installer.sh`** is a single bash script (~5–10 MB) published as a release asset on GitHub. It embeds:
- All of scribe's source files (CLI, hooks, templates, slash commands) as base64-encoded heredocs.
- Static `jq` binaries for macOS (arm64 + x86_64) and Linux (x86_64 + arm64), embedded as base64. The right one is selected at install time based on `uname`.
- The uninstaller, copied to `~/.scribe/uninstall.sh` so it works offline forever after.

**The user's path:**
1. In a browser, visit `https://github.com/<org>/scribe/releases/latest` (only step that needs network).
2. Click "scribe-installer.sh" to download. Saves to `~/Downloads/`.
3. Open Terminal. Run `bash ~/Downloads/scribe-installer.sh`.
4. Done.

For users in unrestricted environments, the same file is also installable via a curl one-liner if they prefer — but it is **not** the documented primary path. Browser download is the documented primary path because it works everywhere.

### Install

**Primary path (works in restricted environments):**
1. Browser → `https://github.com/<org>/scribe/releases/latest` → download `scribe-installer.sh`.
2. Terminal → `bash ~/Downloads/scribe-installer.sh`.

**Optional path (only if curl + outbound HTTPS are unrestricted):**
`curl -fsSL https://github.com/<org>/scribe/releases/latest/download/scribe-installer.sh | bash`

The installer script:

1. **Pre-flight checks** using only built-in shell tools (no `curl`, no network):
   - Detects platform via `uname`: macOS / Linux / WSL / Git Bash.
   - Verifies bash 3.2+ (macOS ships bash 3.2 — code is written to that floor).
   - Checks `claude` CLI is on PATH. If missing, prints: *"Claude Code isn't installed yet. Install it from https://claude.com/claude-code, then run this script again."* Exits.
   - Checks write access to `~/.claude/`. If missing, prints a clear error.
2. **Extracts embedded files** to a temp directory using only `base64`, `tar`, `mkdir`, `mv` (all POSIX-standard).
3. **Selects the right `jq` binary** for the platform from the embedded set, copies it to `~/.scribe/bin/jq`, and `chmod +x`s it. Strips macOS quarantine attribute via `xattr -d com.apple.quarantine` (with `2>/dev/null || true` so it's harmless on Linux).
4. **Creates `~/.scribe/`** with `bin/`, `hooks/`, `templates/`, `library/`, `VERSION`, and the embedded uninstaller at `~/.scribe/uninstall.sh`.
5. **Merges into `~/.claude/settings.json`** using the bundled `jq` — adds the SessionStart and Stop hooks pointing at `~/.scribe/hooks/*.sh`. Idempotent: preserves existing hooks, detects existing scribe entries and updates in place.
6. **Installs slash commands** into `~/.claude/commands/` (`journal-pause.md`, `journal-resume.md`, `journal-status.md`).
7. **Adds `~/.scribe/bin` to PATH** by appending one line to the user's shell rc (`~/.zshrc` or `~/.bashrc`, detected from `$SHELL`). Skipped silently if already present. Not required for normal use — Claude calls scribe via full path — but lets power users type `scribe` directly if they want.
8. **Prints friendly output** in plain English:
   ```
   Welcome to scribe.

     ✓ Detected macOS (Apple Silicon)
     ✓ Found Claude Code
     ✓ Installed scribe to ~/.scribe/
     ✓ Wired into Claude Code
     ✓ Added scribe to your PATH

   Done.

   What's next:
     1. Open Claude Code in any project (cd into your project, run "claude").
     2. Claude will ask once if you want to turn on auto-journaling there.
     3. Say yes to enable, no to skip, "not now" to be asked again next time.

   To remove scribe later:
     bash ~/.scribe/uninstall.sh
   ```
9. **Never prompts the user during install.** No yes/no questions, no PATH-edit confirmation. Just runs.
10. **Exits non-zero only on hard failures.** Soft failures (e.g. couldn't add to PATH) print a warning but exit 0 so the install is considered complete.

### Uninstall

**The recommended path:** `bash ~/.scribe/uninstall.sh` — the uninstaller was placed there by the installer. **No network required.** Works in any environment scribe was installed in.

(Equivalent: `scribe uninstall` for users who have `~/.scribe/bin` on PATH. Same script.)

The uninstaller:

1. **Removes scribe hooks from `~/.claude/settings.json`** via the bundled `jq` (precise removal of the scribe entries; preserves any other hooks the user has).
2. **Removes scribe slash commands** from `~/.claude/commands/`.
3. **Removes the `~/.scribe/bin` PATH line** from the user's shell rc.
4. **Asks once about user data:** *"You have N archived past-project journals at ~/.scribe/library/. Remove them too? (y/N)"* — defaults to **No**, because that's user data and losing it accidentally would be bad.
5. **Removes `~/.scribe/`** (or, if user kept the library, removes everything except `~/.scribe/library/`).
6. **Prints friendly output:**
   ```
   Removing scribe...

     ✓ Unwired from Claude Code
     ✓ Removed slash commands
     ✓ Removed ~/.scribe/

   Done. scribe has been uninstalled.

   Note: active project journals (./journal/ folders inside your projects) are
   untouched. If you want to remove journaling from a specific project, ask
   Claude in that project: "turn off journaling here".
   ```
7. **Idempotent and forgiving.** Safe to run multiple times. Reports "scribe isn't installed" cleanly if there's nothing to remove.

### Updates

To update scribe, the user re-downloads the latest `scribe-installer.sh` from the releases page and runs it again. The installer detects an existing install and updates in place, preserving `~/.scribe/library/` and `~/.claude/settings.json` user customisations. No special "update" command is needed.

### Dependencies and minimalism

scribe is designed for restricted environments. The only **hard requirements** at install time are:

- `bash` 3.2+ (always present on macOS and Linux)
- `tar`, `base64`, `mkdir`, `mv`, `cp`, `rm`, `chmod`, `cat`, `grep`, `sed`, `awk`, `uname` (all POSIX-standard)
- The `claude` CLI (Claude Code) on PATH
- Write access to `~/.claude/` and the user's home directory

**No required network access at install time.** The browser handles the only network step.

**No required system packages** beyond what's already on the OS. `jq` is bundled. There's no `brew install`, no `apt-get`, no `pip install`, no `npm install`.

At runtime, hooks degrade gracefully:
- If `git` is missing, fall back to `$PWD` for project root detection.
- If `flock` is missing, skip the daily-logbook lock (single-session use is unaffected).
- If `xdg-user-dir` is missing, fall back to `~/Desktop`.
- If the bundled `jq` somehow gets removed, hooks fall back to plain text output instead of structured JSON.

### Install layout (what gets created where)

- **`~/.scribe/`** — tool home
  - `bin/scribe` — the CLI
  - `bin/jq` — bundled static binary for the user's platform
  - `hooks/session-start.sh`, `hooks/stop.sh`
  - `templates/CLAUDE-block.md`, `templates/journal-seed/`
  - `library/` — archived past projects (created empty; populated by `scribe archive`)
  - `uninstall.sh` — local uninstaller, runnable offline forever
  - `VERSION`
- **`~/.claude/settings.json`** — `jq`-merged in: SessionStart + Stop hooks.
- **`~/.claude/commands/`** — slash commands `journal-pause.md`, `journal-resume.md`, `journal-status.md`.
- **`~/.zshrc` or `~/.bashrc`** — one line appended adding `~/.scribe/bin` to PATH.

Both hooks short-circuit silently when the current project has no `./journal/` directory — global install does **not** journal projects that haven't opted in.

### Per-project opt-in: conversational bootstrap

**The user-facing path is zero CLI knowledge after install.** The `scribe init` command exists, but Claude runs it on the user's behalf when given consent. The user only ever speaks English.

**Bootstrap flow.** On every session start, the SessionStart hook checks three states for the current project:

1. `./journal/` exists → emit normal journal context (active flow).
2. `./.scribe-declined` exists → exit silently (user has opted this project out).
3. Neither exists → emit a one-line consent prompt as SessionStart context: *"Scribe is installed on this machine but not enabled for this project. On your next response to the user, ask once whether they want to turn on auto-journaling for this project. If they say yes, run `scribe init`. If they say no, run `scribe init --decline`. If unclear or 'not now', say nothing further about it this session."*

Claude reads this and asks naturally: *"You have scribe installed — want me to turn on auto-journaling for this project? (yes / no / not now)"*

- **Yes** → Claude runs `scribe init` via Bash. Subsequent sessions land in state 1.
- **No** → Claude runs `scribe init --decline`, which creates `./.scribe-declined`. Subsequent sessions land in state 2; user is never asked again unless the file is removed.
- **Not now / unclear** → Claude does nothing. The prompt re-fires on the next session.

The company user's full lifetime path is therefore: (1) run the install one-liner once on their machine, (2) open Claude Code in any project, (3) answer one yes/no question. Done.

**`scribe init` (mechanical work).** Idempotent. Whether invoked by Claude or run manually:

1. Creates `./journal/` with seed files:
   - `logbook/.keep`, `decisions/.keep`, `experiments/.keep` (placeholders)
   - `lessons.md` — minimal frontmatter + "how to read this manual" header
   - `README.md` — explains the directory's purpose
2. Adds a block to `./CLAUDE.md` (creates the file if missing) — see "CLAUDE.md instruction block" below.
3. Adds `journal/` to `.gitignore` (creates if missing). Skips the line if already present.
4. Re-running `init` does not overwrite existing journal files; only adds missing seeds and ensures the gitignore + CLAUDE.md block are in place.

**`scribe init --decline`.** Creates an empty `./.scribe-declined` file at the project root. No other side effects.

### Natural-language control

The CLAUDE.md block (added by `init`) instructs Claude that **all journal interaction happens through Claude**. The user only ever speaks English; Claude reads, writes, runs commands.

**Lifecycle:**
- "Pause journaling" / "stop the journal for now" → run `scribe pause`.
- "Resume journaling" / "start journaling again" → run `scribe resume`.
- "Turn off journaling here" / "remove scribe from this project" → run `scribe off` (with confirmation).
- "Is journaling on?" / "what's the journal status" → run `scribe status` and report.

**Reading the journal mid-project (no CLI, no folder navigation):**
- "What did we decide about X?" / "show me the decisions" → Claude reads `journal/decisions/` and reports.
- "What have we learned?" / "summarize the lessons" → Claude reads `journal/lessons.md`.
- "Summarize the journal" / "what's in the journal" → Claude reads the full journal and produces a digest in chat.
- "Show me last week's logbook" / "what did I do yesterday" → Claude reads relevant `journal/logbook/*.md` files and reports.
- "Has X come up before?" → Claude greps both the project journal **and** `~/.scribe/library/` (see archive section).

**End-of-project handoff and cross-project recall:**
- "Archive this project" / "wrap up the journal" / "give me a project summary" / "save this for future reference" → run `scribe archive`. The file lands on the user's desktop; Claude tells them where it is.
- "Bring in lessons from project foo" / "use foo as background context" → run `scribe link foo`.
- "What past projects do I have archived?" → run `scribe library`.

Slash commands (`/journal-pause`, `/journal-resume`, `/journal-status`) remain available for users who prefer them, but the natural-language path is the primary one.

### Pause / resume

Sentinel file: **`./journal/.paused`**. Presence = paused. Absence = active.

- `/journal-pause` and `scribe pause` create the sentinel.
- `/journal-resume` and `scribe resume` remove it.
- `/journal-status` and `scribe status` report active/paused + entry counts + most recent entry date.
- The Stop hook checks for the sentinel and exits silently if paused.
- The CLAUDE.md instruction tells the main Claude to do the same — if `journal/.paused` exists, do not touch journal files this session.

### SessionStart hook (`~/.scribe/hooks/session-start.sh`)

1. Recursion guard: if `CLAUDE_JOURNAL_HOOK=1`, exit 0.
2. Resolve project root via `git rev-parse --show-toplevel`, falling back to `$PWD`.
3. **State machine:**
   - If `./journal/.paused` exists → emit a one-line "journal paused" note and exit.
   - If `./journal/` exists and `.paused` does not → build the active-context block (step 4).
   - If `./journal/` does not exist and `./.scribe-declined` exists → exit silently.
   - If neither exists → emit the **bootstrap prompt** (step 5) and exit.
4. **Active context block:**
   - Project name + path
   - The most recent file in `journal/logbook/` (full content)
   - `journal/lessons.md` (full content)
   - Index of `decisions/`, `experiments/`, `glossary.md`, plus any other top-level `*.md` files in `journal/` (names + counts only, not contents)
   - **Imported context** — for each project listed in `./journal/.imports.txt`, extract the `## Summary` and `## Lessons learned` sections from `~/.scribe/library/<project>_archive.md` and append them, prefixed with `## Imported context from <project>`. Bounded — only those two sections per linked project, never the full archive.
   - A reminder pointer: "the past-projects library is at `~/.scribe/library/`; grep it on demand when the user asks 'have we seen this before?'"
5. **Bootstrap prompt context:** a short instruction that tells Claude to ask the user once during this session whether to enable journaling, and to run `scribe init` (yes), `scribe init --decline` (no), or nothing (not now / unclear) based on the answer.
6. Emit as `{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: "..."}}` JSON via `jq`. Falls back to plain stdout if `jq` is missing.
7. All errors log to `~/.scribe/scribe.log` (when no project journal exists) or `./journal/.scribe.log` (when one does), and exit 0.

This mirrors the lean memory model already proven in `~/.claude-project-kit/kit/template/.claude/hooks/session-start.sh`, extended with the bootstrap, decline, and imported-context states.

### Stop hook (`~/.scribe/hooks/stop.sh`)

1. Recursion guard via `CLAUDE_JOURNAL_HOOK=1`.
2. Resolve project root; bail if no `./journal/` or `./journal/.paused` exists.
3. Read transcript path from stdin JSON (`jq -r '.transcript_path'`).
4. Skip if transcript is below threshold (~2KB) — trivial sessions don't get a sub-Claude.
5. Rate limit per session: skip if same session ran within 5 min. State files at `./journal/.scribe.state.d/<session-id>`.
6. Build a prompt that instructs the sub-Claude to:
   - Read the transcript + existing journal files.
   - Update today's logbook with anything live writes missed (do not duplicate).
   - Create a numbered ADR in `decisions/` if there's a real architectural decision (not just discussion).
   - Append to `lessons.md` only if a durable lesson emerged — high bar: "would someone joining in six months thank me for this?"
   - Create an experiment file in `experiments/` if there was a hypothesis + outcome (failures explicitly welcomed).
   - Update `glossary.md` if project vocabulary emerged.
   - Create or extend project-specific themed MDs at the journal root if a recurring topic warrants its own file.
   - Never touch `.paused`, `.scribe.log`, or `.scribe.state.d/`.
7. Spawn sub-Claude in background with `CLAUDE_JOURNAL_HOOK=1 claude -p --permission-mode bypassPermissions < prompt`. Use `flock` on the daily logbook path if available so concurrent sessions don't race.
8. All errors log to `./journal/.scribe.log` and exit 0. Never blocks the user.

This pattern is lifted from `~/.claude-project-kit/kit/template/design-journal/.journal-hook.sh` (which is already battle-tested) — minus the consent gate, swarm capture, and worktree tagging. We keep the recursion guard, rate limit, transcript-size filter, lockfile, and silent-failure discipline.

### CLAUDE.md instruction block

Inserted by `scribe init`. The block tells the main Claude:

**Writing (live during sessions):**
- Before any journal write, check whether `journal/.paused` exists; if so, skip all journal writes this session.
- Extend `journal/logbook/YYYY-MM-DD.md` in chronological prose as we work.
- Create `journal/decisions/NNN-slug.md` for real architectural decisions (Context / Decision / Why / Consequences).
- Append to `journal/lessons.md` only when a durable, generalizable lesson emerges.
- Create `journal/experiments/YYYY-MM-DD-slug.md` for hypothesis + outcome moments, including failures.
- Update `journal/glossary.md` when project vocabulary emerges.
- Create project-specific themed MDs at the journal root (e.g. `bugs.md`, `ui.md`) when a recurring topic warrants its own file. Use judgment.
- Every file starts with YAML frontmatter: `id`, `type`, `date`, `topic`, `tags`, `status`, `related`.
- Live writes are preferred. The Stop hook only catches misses.

**Reading on the user's behalf (never make them open files):**
- When the user asks about anything in the journal — decisions, lessons, what they did yesterday, summaries — read the relevant files and report in chat.
- For "summarize the journal" or "what have we covered" — read across files and produce a synthesized answer, not a file dump.
- When the user asks "have we faced this before?" or "any past lessons on X?", grep `~/.scribe/library/` (the archived past projects) in addition to the current journal, and surface relevant excerpts.

**Lifecycle commands the user invokes via plain English:**
- "Pause journaling" → `scribe pause`. "Resume journaling" → `scribe resume`.
- "Archive this project" / "give me a project summary" / "wrap this up" → `scribe archive`. After it runs, tell the user where the file is on their desktop.
- "Bring in context from project X" → `scribe link X`.
- "Turn off journaling here" → `scribe off` (with explicit confirmation).

The exact text lives at `~/.scribe/templates/CLAUDE-block.md` so it can be updated centrally and re-stamped by re-running `init`.

### CLI surface (`bin/scribe`)

Small bash script. Most subcommands are invoked by Claude on the user's behalf, not typed directly.

**Lifecycle (per-project):**
- `scribe init` — per-project setup (described above).
- `scribe init --decline` — drops a `./.scribe-declined` marker so the bootstrap prompt never re-fires for this project.
- `scribe off` — removes `./journal/`, the `.scribe-declined` marker if present, and the CLAUDE.md block. Requires a `--yes` flag or interactive confirmation.
- `scribe pause` / `scribe resume` — flip the `./journal/.paused` sentinel.
- `scribe status` — active / paused / declined / not-initialized, plus entry counts and last entry date.

**Handoff and cross-project recall:**
- `scribe archive` — produces one self-contained Markdown file. Lands on the user's desktop as `<project>_archive.md` and is also copied into `~/.scribe/library/` for future cross-project recall. Idempotent; rerunning refreshes both copies.
- `scribe link <project-name>` — adds `<project-name>` to `./journal/.imports.txt`. Verifies the named project exists in `~/.scribe/library/`. SessionStart hook will load that project's summary + lessons into context on next session.
- `scribe unlink <project-name>` — removes the entry.
- `scribe library` — lists archived projects with their summaries' first line and archive dates.

**Diagnostics & lifecycle:**
- `scribe doctor` — verifies `~/.scribe/` exists, hooks are wired in `~/.claude/settings.json`, slash commands installed, `claude` CLI present, `jq` available.
- `scribe version` — prints contents of `~/.scribe/VERSION`.
- `scribe uninstall` — same as the curl-line uninstaller; provided so users with `~/.scribe/bin` on PATH can run it without hitting GitHub. Behaviour described in the Uninstall section.

### Archive and cross-project recall

The archive is **one self-contained Markdown file**. Nothing else. The user gets a single document they can read, email, print, or attach to a message. There is no directory tree, no JSON, no rollup files to keep track of.

**File structure** — every archive looks the same:

```markdown
---
project: <name>
archived: <YYYY-MM-DD>
sessions: <count>
---

# <Project Name>

## Summary
(~300 words plain prose, sub-Claude-written: what the project was, who it was
 for, the key decisions, the key lessons, the final state.)

## Lessons learned
(contents of journal/lessons.md)

## Decisions
### 001 — <title>
(ADR content)

### 002 — <title>
(ADR content)

## Experiments
### YYYY-MM-DD — <title>
(experiment content)

## Glossary
(contents of journal/glossary.md, if present)

## Recent activity
(the last N logbook entries — default 10 — concatenated in chronological order)
```

**`scribe archive` flow:**
1. Refuses to run if `./journal/` is missing or empty.
2. Spawns a sub-Claude (`CLAUDE_JOURNAL_HOOK=1 claude -p`) to write the `## Summary` section.
3. Assembles the file by concatenating sections from the live journal.
4. Resolves the user's desktop path (see "Desktop resolution" below).
5. Writes the result to **two locations**:
   - `<desktop>/<sanitized-project-name>_archive.md` — the user's deliverable. Always lands on the desktop. They see it appear; they can do whatever they want with it.
   - `~/.scribe/library/<sanitized-project-name>_archive.md` — the system's recall asset. Same file, hidden location.
6. Reports both paths in stdout (Claude relays the desktop path to the user in chat: "Saved to your desktop as `<filename>`").
7. Idempotent. Rerunning refreshes both copies; never destructive to the source journal.

**Desktop resolution** (cross-platform, in priority order):
1. **WSL detected** (`/proc/version` contains "microsoft" or `$WSL_DISTRO_NAME` set) → use `wslvar USERPROFILE` if available, append `/Desktop`, then convert to a WSL path with `wslpath`. Fall back to `/mnt/c/Users/$USER/Desktop` if `wslvar` is missing.
2. **`xdg-user-dir DESKTOP`** if the command exists (handles localized folder names on Linux desktop environments).
3. **`~/Desktop`** if that directory exists (covers macOS, Linux without xdg, Git Bash on Windows).
4. **`~`** (home directory) as final fallback, with a warning printed.

The resolved path is exposed via a small helper `scribe-desktop-path` (or an internal function) so the same logic can be used by `archive` and any future commands.

**Project name sanitization:**
- Take the basename of the project root (`basename "$(pwd)"`).
- Lowercase optional (preserve original case to keep the file recognizable).
- Replace any character not in `[A-Za-z0-9._-]` with `_`.
- Collapse runs of `_` to a single `_`.
- Examples: `my-cool-app` → `my-cool-app_archive.md`; `My Cool App` → `My_Cool_App_archive.md`; `weird/path:name` → `weird_path_name_archive.md`.

**Cross-project recall:**
The library is a flat directory of single-file archives:

```
~/.scribe/library/
├── project-foo_archive.md
├── project-bar_archive.md
└── project-baz_archive.md
```

Claude is instructed to grep `~/.scribe/library/*.md` when the user asks recall-style questions ("have we faced this before?"). No vector store, no embeddings — just `grep` across markdown. Scales to dozens of projects with no infrastructure. Vector indexing can be layered on later without changing the user-facing behavior.

**`scribe link <project>` flow:**
1. Validates that `~/.scribe/library/<sanitized-project>_archive.md` exists.
2. Appends `<sanitized-project>` to `./journal/.imports.txt` (creates the file if missing). Skips if already linked.
3. SessionStart picks it up on next session and includes the linked archive's `## Summary` and `## Lessons learned` sections in the active context block (not the full archive — keeps imports lean).

### Repo layout

```
scribe/
├── README.md
├── LICENSE
├── VERSION
├── build.sh             # produces dist/scribe-installer.sh from source
├── src/
│   ├── bin/
│   │   └── scribe       # the CLI (also handles `scribe uninstall`)
│   ├── hooks/
│   │   ├── session-start.sh
│   │   └── stop.sh
│   ├── commands/
│   │   ├── journal-pause.md
│   │   ├── journal-resume.md
│   │   └── journal-status.md
│   ├── templates/
│   │   ├── CLAUDE-block.md
│   │   └── journal-seed/
│   │       ├── README.md
│   │       ├── lessons.md
│   │       ├── logbook/.keep
│   │       ├── decisions/.keep
│   │       └── experiments/.keep
│   └── installer/
│       ├── installer-template.sh   # the shell template that becomes scribe-installer.sh
│       ├── uninstall.sh            # shipped to ~/.scribe/uninstall.sh
│       └── jq-binaries/            # static jq builds for each supported platform
│           ├── jq-macos-arm64
│           ├── jq-macos-x86_64
│           ├── jq-linux-x86_64
│           └── jq-linux-arm64
├── dist/                # build output (git-ignored)
│   └── scribe-installer.sh
└── test/
    ├── scenarios/       # sample transcripts + expected file changes for hook tests
    └── installer/       # tests the build + extract round-trip
```

**Build flow:** `build.sh` reads everything under `src/`, base64-encodes the binaries, embeds source files as heredocs into `installer-template.sh`, and writes the self-extracting `dist/scribe-installer.sh`. CI runs the build on every release tag and uploads the artifact to the GitHub release page.

## Critical files to be reused / referenced from the existing kit

These are battle-tested patterns to mirror, not files to copy verbatim — `scribe` is a fresh repo:

- `~/.claude-project-kit/kit/template/design-journal/.journal-hook.sh` — Stop hook reference implementation (recursion guard, rate limit, lockfile, sub-Claude prompt, silent failure).
- `~/.claude-project-kit/kit/template/.claude/hooks/session-start.sh` — SessionStart hook reference (overview + latest log + index pattern).
- `~/.claude-project-kit/kit/template/CLAUDE.md` — CLAUDE.md instruction style for live writes.
- `~/.claude-project-kit/kit/demo/design-journal/` — examples of healthy file shapes (frontmatter conventions, ADR template, experiment template).

## Error handling

- Hooks **never** block the user. All failures log to `./journal/.scribe.log` and exit 0.
- `install.sh` is idempotent: `jq`-merges into `~/.claude/settings.json` rather than overwriting; detects existing scribe entries and updates in place.
- `scribe init` is idempotent: never overwrites existing journal files.
- `scribe off` requires confirmation; only removes what `scribe init` created (the directory + the bracketed CLAUDE.md block).
- Recursion guard (`CLAUDE_JOURNAL_HOOK=1`) prevents the sub-Claude's session from re-triggering the Stop hook.

## Testing / verification

**Manual end-to-end (the path a real user takes):**
1. Download `scribe-installer.sh` from the GitHub releases page via a browser. Run `bash ~/Downloads/scribe-installer.sh` on a clean machine. Confirm friendly output, no prompts, no errors. Confirm no network calls happen during install (verify with `nettop` on macOS or `ss -tp` on Linux while running).
2. `scribe doctor` — should report green.
3. Open Claude Code in a fresh project that has no `journal/`. Confirm Claude asks "want me to enable auto-journaling here?" within its first response.
4. Answer "yes". Confirm Claude runs `scribe init`, the directory + gitignore line + CLAUDE.md block appear, and Claude acknowledges.
5. Do trivial work; close session. Confirm logbook entry exists, no errors in `journal/.scribe.log`.
6. Re-open the same project. Confirm SessionStart now injects active context (latest log + lessons + index), no consent prompt re-fires.
7. Tell Claude "pause journaling". Confirm `.paused` sentinel created. Do work; close session. Confirm no journal writes happened.
8. Tell Claude "resume journaling". Confirm sentinel removed.
9. **Reading-on-behalf:** ask Claude "what did we decide?" — confirm Claude reads `decisions/` and replies in chat without the user having opened anything.
10. **Archive:** tell Claude "archive this project". Confirm a single file `<project>_archive.md` appears on the desktop, and an identical copy lands in `~/.scribe/library/`.
11. **Re-archive:** rerun. Confirm both copies refresh in place; source journal is untouched.
12. **Cross-project recall:** start a fresh project with `scribe init`. Ask "have we faced X before?" where X is mentioned in an archived project. Confirm Claude greps the library and surfaces the relevant excerpt.
13. **Link:** tell Claude "use project foo as background context". Confirm `journal/.imports.txt` updated. Reopen session; confirm imported summary + lessons appear in SessionStart context.
14. Tell Claude "turn off journaling here". Confirm clean removal after confirmation.
15. **Decline path:** open Claude Code in a fresh project. Answer "no" to the consent prompt. Confirm `.scribe-declined` is created and the prompt does not re-fire on re-open.
16. **Not-now path:** open Claude Code in a fresh project. Answer "not now". Confirm no marker is created and the prompt re-fires next session.
17. **Uninstall:** run `bash ~/.scribe/uninstall.sh` (the local uninstaller). Confirm scribe entries removed from `~/.claude/settings.json`, slash commands removed, `~/.scribe/bin` PATH line removed from rc file. Confirm the prompt about keeping `~/.scribe/library/` defaults to No. Confirm active project `journal/` folders are untouched. Confirm no network calls happen during uninstall.
18. **Re-install after uninstall:** re-download `scribe-installer.sh` (or reuse the previously downloaded one) and run again. Confirm clean re-install with no leftover state issues.
19. **Restricted-environment dry-run:** disconnect the test machine from the network *after* downloading the installer. Run install. Confirm it succeeds end-to-end with no internet access.

**Automated:**
- `bats` tests for each hook script: feed sample stdin JSON, snapshot expected stdout/stderr.
- Integration tests in `test/scenarios/`: sample transcripts piped through `stop.sh` with a mocked `claude` CLI; assert correct prompt construction and rate-limiting behavior.

## Explicitly out of scope

- No `proj`, `newproj`, ports, INDEX, status line, preship, doctor-for-projects, demo project.
- No weekly digest / `launchd` job.
- No `/decide`, `/experiment`, `/glossary`, `/note` content-creation slash commands — main Claude writes these inline as instructed by the CLAUDE.md block.
- No swarm capture, worktree tagging.
- No global consent file — consent is per-project, gathered conversationally on first session in each project.
- No `artefacts/` directory.
- No cross-project digest or training-manual rollups.
