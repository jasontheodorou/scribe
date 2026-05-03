# scribe Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `scribe` — a single-file installer for an always-on Claude Code journaling tool with per-project consent, archive-to-desktop, and cross-project recall.

**Architecture:** Pure bash 3.2-compatible source tree → `build.sh` → single self-extracting `dist/scribe-installer.sh`. Source includes a CLI dispatcher, two hooks, three slash commands, templates, and an uninstaller. The build embeds all sources as base64 heredocs alongside platform-specific static `jq` binaries. The installer requires no network access and no system package manager.

**Tech Stack:**
- `bash` 3.2+ (macOS-compatible)
- `jq` 1.7.1 (bundled, four platform binaries)
- `bats-core` for tests
- POSIX-standard tools only (`tar`, `base64`, `sed`, `awk`, `grep`)

**Reference patterns:** existing kit at `~/.claude-project-kit/kit/template/` (Stop hook, SessionStart hook, CLAUDE.md style). Mirror the patterns; do not copy verbatim.

**Spec:** `~/.claude/plans/ticklish-fluttering-moler.md` (the approved design). Task 2 copies it into the new repo as `docs/superpowers/specs/2026-05-03-scribe-design.md`.

---

## Spec coverage map

| Spec section | Implementing task(s) |
|---|---|
| Install layout (`~/.scribe/`) | T1, T19 |
| Distribution (single-file installer) | T19, T21 |
| Pre-flight checks | T19 |
| `scribe init` + `--decline` | T5, T6 |
| Conversational bootstrap (CLAUDE injection) | T14, T16 |
| Natural-language control (CLAUDE.md block) | T16 |
| Pause/resume/status | T7 |
| `scribe off` | T8 |
| `scribe archive` (single .md to desktop + library) | T11 |
| Desktop resolution (macOS / Linux / WSL) | T9 |
| Project name sanitization | T10 |
| Cross-project recall (grep library) | covered by T16 instructions |
| `scribe link` / `unlink` / `library` | T12 |
| `scribe doctor` / `version` / `uninstall` | T4, T13, T20 |
| SessionStart hook | T14 |
| Stop hook | T15 |
| Slash commands | T17 |
| jq binaries | T18 |
| Installer template | T19 |
| Uninstaller | T20 |
| Build script | T21 |
| End-to-end smoke | T22 |

## File structure (target)

```
~/projects/scribe/
├── README.md
├── LICENSE
├── VERSION
├── .gitignore
├── build.sh
├── docs/
│   └── superpowers/
│       ├── specs/2026-05-03-scribe-design.md
│       └── plans/2026-05-03-scribe-implementation.md
├── src/
│   ├── bin/scribe
│   ├── hooks/session-start.sh
│   ├── hooks/stop.sh
│   ├── commands/journal-pause.md
│   ├── commands/journal-resume.md
│   ├── commands/journal-status.md
│   ├── templates/CLAUDE-block.md
│   ├── templates/journal-seed/README.md
│   ├── templates/journal-seed/lessons.md
│   ├── templates/journal-seed/logbook/.keep
│   ├── templates/journal-seed/decisions/.keep
│   ├── templates/journal-seed/experiments/.keep
│   └── installer/
│       ├── installer-template.sh
│       ├── uninstall.sh
│       └── jq-binaries/
│           ├── jq-macos-arm64
│           ├── jq-macos-x86_64
│           ├── jq-linux-x86_64
│           └── jq-linux-arm64
├── dist/                                 # gitignored
│   └── scribe-installer.sh
└── test/
    ├── helpers.bash
    ├── test_dispatcher.bats
    ├── test_init.bats
    ├── test_pause_resume.bats
    ├── test_off.bats
    ├── test_desktop_path.bats
    ├── test_sanitize.bats
    ├── test_archive.bats
    ├── test_link.bats
    ├── test_doctor.bats
    ├── test_session_start.bats
    ├── test_stop.bats
    ├── test_installer.bats
    └── fixtures/
        └── transcript.jsonl
```

---

### Task 1: Bootstrap repo

**Files:**
- Create: `~/projects/scribe/` (directory)
- Create: `~/projects/scribe/.gitignore`

- [ ] **Step 1: Create the project directory tree**

```bash
mkdir -p ~/projects/scribe/{src/{bin,hooks,commands,templates/journal-seed/{logbook,decisions,experiments},installer/jq-binaries},docs/superpowers/{specs,plans},test/fixtures,dist}
```

- [ ] **Step 2: Initialize git**

```bash
cd ~/projects/scribe
git init -q
```

- [ ] **Step 3: Write `.gitignore`**

```
dist/
*.swp
.DS_Store
*.log
.bats-tmp/
```

- [ ] **Step 4: Move the design spec and this plan into the repo**

```bash
cp ~/.claude/plans/ticklish-fluttering-moler.md ~/projects/scribe/docs/superpowers/specs/2026-05-03-scribe-design.md
cp ~/.claude/plans/2026-05-03-scribe-implementation.md ~/projects/scribe/docs/superpowers/plans/2026-05-03-scribe-implementation.md
```

- [ ] **Step 5: Initial commit**

```bash
cd ~/projects/scribe
git add .gitignore docs/
git commit -m "Bootstrap scribe repo with design spec and implementation plan"
```

---

### Task 2: Project metadata files

**Files:**
- Create: `~/projects/scribe/README.md`
- Create: `~/projects/scribe/LICENSE`
- Create: `~/projects/scribe/VERSION`

- [ ] **Step 1: Write `VERSION`**

```
0.1.0
```

- [ ] **Step 2: Write `LICENSE`** (MIT)

```
MIT License

Copyright (c) 2026 <copyright holder>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 3: Write a stub `README.md`**

```markdown
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
```

- [ ] **Step 4: Commit**

```bash
cd ~/projects/scribe
git add VERSION LICENSE README.md
git commit -m "Add project metadata: VERSION, LICENSE, README"
```

---

### Task 3: Test infrastructure (bats helpers)

**Files:**
- Create: `~/projects/scribe/test/helpers.bash`
- Create: `~/projects/scribe/test/test_helpers.bats`

- [ ] **Step 1: Verify bats-core is available**

```bash
command -v bats || brew install bats-core
bats --version
```

Expected: bats version output. If `bats` isn't on PATH, install via Homebrew (developer machine only — runtime users never need bats).

- [ ] **Step 2: Write `test/helpers.bash`** — shared test fixtures.

```bash
#!/usr/bin/env bash
# Shared test helpers. Each test gets an isolated fake $HOME at $TEST_HOME so
# we never touch the real ~/.scribe or ~/.claude during tests.

# Path to the source tree (set per repo root, computed once).
SCRIBE_REPO="${SCRIBE_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Set up an isolated environment for one test. Call from setup() in a .bats file.
setup_isolated_env() {
  TEST_HOME="$(mktemp -d "${TMPDIR:-/tmp}/scribe-test.XXXXXX")"
  export HOME="$TEST_HOME"
  export TEST_HOME

  # Project-under-test root (a fake project directory inside TEST_HOME).
  PROJECT_DIR="$TEST_HOME/test-project"
  mkdir -p "$PROJECT_DIR"
  export PROJECT_DIR

  # Path to the scribe binary we're testing (source-tree copy).
  SCRIBE_BIN="$SCRIBE_REPO/src/bin/scribe"
  chmod +x "$SCRIBE_BIN"
  export SCRIBE_BIN

  # Templates path — the scribe CLI normally reads from ~/.scribe/templates,
  # but for source-tree tests we point it at src/templates/ via env.
  export SCRIBE_TEMPLATES_DIR="$SCRIBE_REPO/src/templates"

  # Library path inside the isolated home.
  export SCRIBE_LIBRARY_DIR="$TEST_HOME/.scribe/library"
  mkdir -p "$SCRIBE_LIBRARY_DIR"

  cd "$PROJECT_DIR"
}

# Tear down the isolated environment.
teardown_isolated_env() {
  if [ -n "${TEST_HOME:-}" ] && [ -d "$TEST_HOME" ]; then
    rm -rf "$TEST_HOME"
  fi
}

# Install a fake `claude` CLI on PATH that captures invocations to a log.
install_fake_claude() {
  local fakedir="$TEST_HOME/fakebin"
  mkdir -p "$fakedir"
  cat >"$fakedir/claude" <<'FAKE'
#!/bin/bash
echo "$@" >> "$TEST_HOME/claude.calls"
cat >> "$TEST_HOME/claude.stdin" 2>/dev/null || true
exit 0
FAKE
  chmod +x "$fakedir/claude"
  export PATH="$fakedir:$PATH"
}

# Install a fake `xdg-user-dir` that returns a configured path.
install_fake_xdg() {
  local fakedir="$TEST_HOME/fakebin"
  mkdir -p "$fakedir"
  cat >"$fakedir/xdg-user-dir" <<FAKE
#!/bin/bash
echo "$1"
FAKE
  chmod +x "$fakedir/xdg-user-dir"
  export PATH="$fakedir:$PATH"
}

# Make the journal/ directory inside PROJECT_DIR with seeds (no CLAUDE.md edit).
seed_journal() {
  mkdir -p "$PROJECT_DIR/journal/logbook" "$PROJECT_DIR/journal/decisions" "$PROJECT_DIR/journal/experiments"
  touch "$PROJECT_DIR/journal/logbook/.keep" "$PROJECT_DIR/journal/decisions/.keep" "$PROJECT_DIR/journal/experiments/.keep"
  cat >"$PROJECT_DIR/journal/lessons.md" <<EOF
---
id: lessons
type: manual
---

# Lessons
EOF
}
```

- [ ] **Step 3: Write a sanity test `test/test_helpers.bats`**

```bash
#!/usr/bin/env bats

load helpers

setup() {
  setup_isolated_env
}

teardown() {
  teardown_isolated_env
}

@test "helpers: TEST_HOME is created and isolated" {
  [ -d "$TEST_HOME" ]
  [ "$HOME" = "$TEST_HOME" ]
}

@test "helpers: PROJECT_DIR exists and is the cwd" {
  [ -d "$PROJECT_DIR" ]
  [ "$(pwd)" = "$PROJECT_DIR" ]
}

@test "helpers: seed_journal creates expected structure" {
  seed_journal
  [ -d "$PROJECT_DIR/journal/logbook" ]
  [ -d "$PROJECT_DIR/journal/decisions" ]
  [ -d "$PROJECT_DIR/journal/experiments" ]
  [ -f "$PROJECT_DIR/journal/lessons.md" ]
}

@test "helpers: install_fake_claude logs invocations" {
  install_fake_claude
  echo "test prompt" | claude -p arg1
  grep -q "arg1" "$TEST_HOME/claude.calls"
  grep -q "test prompt" "$TEST_HOME/claude.stdin"
}
```

- [ ] **Step 4: Run the helper tests**

```bash
cd ~/projects/scribe
bats test/test_helpers.bats
```

Expected: 4 passing tests.

- [ ] **Step 5: Commit**

```bash
git add test/
git commit -m "Add bats test helpers for isolated test environments"
```

---

### Task 4: scribe CLI dispatcher (version, doctor, usage)

**Files:**
- Create: `~/projects/scribe/src/bin/scribe`
- Create: `~/projects/scribe/test/test_dispatcher.bats`

- [ ] **Step 1: Write the failing test `test/test_dispatcher.bats`**

```bash
#!/usr/bin/env bats

load helpers

setup() {
  setup_isolated_env
}

teardown() {
  teardown_isolated_env
}

@test "scribe with no args prints usage and exits 1" {
  run "$SCRIBE_BIN"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"scribe init"* ]]
}

@test "scribe version prints VERSION file content" {
  # Arrange: ~/.scribe/VERSION exists.
  mkdir -p "$TEST_HOME/.scribe"
  echo "0.1.0" > "$TEST_HOME/.scribe/VERSION"

  run "$SCRIBE_BIN" version
  [ "$status" -eq 0 ]
  [ "$output" = "0.1.0" ]
}

@test "scribe version falls back when ~/.scribe/VERSION is absent" {
  # When running from source tree without an installed copy, fall back to the
  # repo's VERSION file via SCRIBE_REPO env.
  export SCRIBE_REPO="$SCRIBE_REPO"
  run "$SCRIBE_BIN" version
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "scribe unknown-command prints error and exits 2" {
  run "$SCRIBE_BIN" definitely-not-a-command
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown command"* ]]
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
bats test/test_dispatcher.bats
```

Expected: 4 failures (file not yet executable / scribe binary doesn't exist with this behavior).

- [ ] **Step 3: Write `src/bin/scribe`** — minimal dispatcher

```bash
#!/bin/bash
# scribe — auto-journal helper for Claude Code.
# Run by Claude on the user's behalf via the project's CLAUDE.md instruction
# block. Designed for bash 3.2+ (macOS-compatible).

set -u

SCRIBE_VERSION="0.1.0"

# SCRIBE_HOME is normally ~/.scribe (after install). Source-tree tests override
# it via SCRIBE_REPO and SCRIBE_TEMPLATES_DIR.
SCRIBE_HOME="${SCRIBE_HOME:-$HOME/.scribe}"

usage() {
  cat <<EOF
Usage: scribe <command> [options]

Commands:
  init [--decline]   Enable scribe in the current project (or decline once).
  off                Disable scribe in the current project (with confirmation).
  pause              Pause journaling for the current project.
  resume             Resume journaling.
  status             Report active/paused/declined state and entry counts.
  archive            Produce a single-file project archive on the user's desktop.
  link <name>        Bring a past project's summary + lessons into this project.
  unlink <name>      Remove a previously linked project.
  library            List archived past projects.
  doctor             Verify the install is healthy.
  version            Print scribe version.
  uninstall          Run the local uninstaller (~/.scribe/uninstall.sh).

Most commands are invoked by Claude on the user's behalf, not typed by hand.
EOF
}

cmd_version() {
  if [ -f "$SCRIBE_HOME/VERSION" ]; then
    cat "$SCRIBE_HOME/VERSION"
  elif [ -n "${SCRIBE_REPO:-}" ] && [ -f "$SCRIBE_REPO/VERSION" ]; then
    cat "$SCRIBE_REPO/VERSION"
  else
    echo "$SCRIBE_VERSION"
  fi
}

main() {
  if [ $# -eq 0 ]; then
    usage
    exit 1
  fi

  local cmd="$1"
  shift

  case "$cmd" in
    version|-v|--version) cmd_version "$@" ;;
    help|-h|--help)       usage ;;
    init|off|pause|resume|status|archive|link|unlink|library|doctor|uninstall)
      # Stub for now — implemented in subsequent tasks.
      echo "scribe $cmd: not implemented yet" >&2
      exit 99
      ;;
    *)
      echo "scribe: unknown command '$cmd'" >&2
      echo "Run 'scribe help' for usage." >&2
      exit 2
      ;;
  esac
}

main "$@"
```

- [ ] **Step 4: Make it executable and run tests**

```bash
chmod +x ~/projects/scribe/src/bin/scribe
cd ~/projects/scribe
bats test/test_dispatcher.bats
```

Expected: 4 passing tests.

- [ ] **Step 5: Commit**

```bash
git add src/bin/scribe test/test_dispatcher.bats
git commit -m "Add scribe CLI dispatcher with version and usage"
```

---

### Task 5: scribe init — per-project setup

**Files:**
- Modify: `~/projects/scribe/src/bin/scribe`
- Create: `~/projects/scribe/test/test_init.bats`

- [ ] **Step 1: Write the failing test `test/test_init.bats`**

```bash
#!/usr/bin/env bats

load helpers

setup() {
  setup_isolated_env
  # init reads templates from src/templates/ (via SCRIBE_TEMPLATES_DIR set in helpers).
}

teardown() {
  teardown_isolated_env
}

@test "scribe init creates journal/ structure" {
  run "$SCRIBE_BIN" init
  [ "$status" -eq 0 ]
  [ -d "$PROJECT_DIR/journal" ]
  [ -d "$PROJECT_DIR/journal/logbook" ]
  [ -d "$PROJECT_DIR/journal/decisions" ]
  [ -d "$PROJECT_DIR/journal/experiments" ]
  [ -f "$PROJECT_DIR/journal/lessons.md" ]
  [ -f "$PROJECT_DIR/journal/README.md" ]
}

@test "scribe init adds journal/ to .gitignore" {
  run "$SCRIBE_BIN" init
  [ "$status" -eq 0 ]
  grep -q "^journal/$" "$PROJECT_DIR/.gitignore"
}

@test "scribe init does not duplicate the .gitignore line on rerun" {
  "$SCRIBE_BIN" init
  "$SCRIBE_BIN" init
  count=$(grep -c "^journal/$" "$PROJECT_DIR/.gitignore")
  [ "$count" -eq 1 ]
}

@test "scribe init creates CLAUDE.md if missing and inserts the block" {
  run "$SCRIBE_BIN" init
  [ "$status" -eq 0 ]
  [ -f "$PROJECT_DIR/CLAUDE.md" ]
  grep -q "scribe-block-begin" "$PROJECT_DIR/CLAUDE.md"
  grep -q "scribe-block-end" "$PROJECT_DIR/CLAUDE.md"
}

@test "scribe init preserves existing CLAUDE.md content" {
  echo "# Existing project notes" > "$PROJECT_DIR/CLAUDE.md"
  echo "Important instruction." >> "$PROJECT_DIR/CLAUDE.md"

  run "$SCRIBE_BIN" init
  [ "$status" -eq 0 ]
  grep -q "Existing project notes" "$PROJECT_DIR/CLAUDE.md"
  grep -q "Important instruction." "$PROJECT_DIR/CLAUDE.md"
  grep -q "scribe-block-begin" "$PROJECT_DIR/CLAUDE.md"
}

@test "scribe init is idempotent (no double-block)" {
  "$SCRIBE_BIN" init
  "$SCRIBE_BIN" init
  count=$(grep -c "scribe-block-begin" "$PROJECT_DIR/CLAUDE.md")
  [ "$count" -eq 1 ]
}

@test "scribe init does not overwrite existing journal files" {
  "$SCRIBE_BIN" init
  echo "user-edited content" > "$PROJECT_DIR/journal/lessons.md"
  "$SCRIBE_BIN" init
  grep -q "user-edited content" "$PROJECT_DIR/journal/lessons.md"
}
```

- [ ] **Step 2: Add a placeholder template file so the test can run**

```bash
mkdir -p ~/projects/scribe/src/templates/journal-seed/{logbook,decisions,experiments}
touch ~/projects/scribe/src/templates/journal-seed/{logbook,decisions,experiments}/.keep

cat > ~/projects/scribe/src/templates/journal-seed/lessons.md <<'EOF'
---
id: lessons
type: manual
date: PLACEHOLDER
status: active
---

# Lessons learned

This file accrues durable lessons as the project unfolds. Bar: "would someone
joining the project in six months thank me for this entry?" Skip filler.
EOF

cat > ~/projects/scribe/src/templates/journal-seed/README.md <<'EOF'
# journal/

scribe writes here. Files in this directory are private to your local checkout
(see .gitignore at the project root).

- `logbook/YYYY-MM-DD.md` — chronological record of each session
- `decisions/NNN-slug.md` — architectural decisions
- `experiments/YYYY-MM-DD-slug.md` — hypothesis + outcome notes
- `lessons.md` — durable lessons across the project
- `glossary.md` — project vocabulary (created on demand)
EOF

cat > ~/projects/scribe/src/templates/CLAUDE-block.md <<'EOF'
<!-- scribe-block-begin -->
## Auto-journal (managed by scribe)

This project has a `journal/` directory. **Before any journal write, check whether `journal/.paused` exists. If it does, skip all journal writes for this session.**

Otherwise, as we work, extend these files in plain-English prose:

- `journal/logbook/YYYY-MM-DD.md` — chronological blow-by-blow.
- `journal/decisions/NNN-slug.md` — real architectural decisions (Context / Decision / Why / Consequences). Number sequentially.
- `journal/lessons.md` — durable lessons. Bar: "would someone joining the project in six months thank me for this?"
- `journal/experiments/YYYY-MM-DD-slug.md` — hypothesis + outcome (failures included).
- `journal/glossary.md` — project vocabulary as it emerges.
- Project-specific themed files (`bugs.md`, `ui.md`, etc.) — when a recurring topic warrants its own file.

Every file starts with YAML frontmatter: `id`, `type`, `date`, `topic`, `tags`, `status`, `related`.

Live writes are preferred. The Stop hook only catches misses.

**Reading on the user's behalf.** When the user asks "what did we decide?" / "what have we learned?" / "summarize the journal" / "what did I do yesterday?" — read the relevant journal files and report in chat. The user should never need to open files. When asked recall-style questions ("have we faced this before?"), grep `~/.scribe/library/` (the past-projects archive) too.

**Lifecycle commands the user invokes via plain English.** Run these via Bash:

- "Pause journaling" → `scribe pause`. "Resume journaling" → `scribe resume`.
- "Archive this project" / "give me a summary" / "wrap this up" → `scribe archive`. After it runs, tell the user where the file is on their desktop.
- "Bring in context from project X" → `scribe link X`.
- "Turn off journaling here" → `scribe off` (with explicit confirmation).
<!-- scribe-block-end -->
EOF
```

- [ ] **Step 3: Run the test to verify it fails**

```bash
cd ~/projects/scribe
bats test/test_init.bats
```

Expected: failures — `init` is still a stub.

- [ ] **Step 4: Implement `cmd_init` in `src/bin/scribe`**

Replace the stub case for `init` and add `cmd_init`:

```bash
# Resolve where templates live. Installed: $SCRIBE_HOME/templates/. Source-tree tests:
# $SCRIBE_TEMPLATES_DIR points at src/templates/.
templates_dir() {
  if [ -n "${SCRIBE_TEMPLATES_DIR:-}" ] && [ -d "$SCRIBE_TEMPLATES_DIR" ]; then
    echo "$SCRIBE_TEMPLATES_DIR"
  else
    echo "$SCRIBE_HOME/templates"
  fi
}

cmd_init() {
  if [ "${1:-}" = "--decline" ]; then
    : > ".scribe-declined"
    echo "scribe declined for $(pwd)"
    return 0
  fi

  local tdir
  tdir="$(templates_dir)"
  if [ ! -d "$tdir/journal-seed" ]; then
    echo "scribe: templates not found at $tdir" >&2
    return 1
  fi

  # 1. Create journal/ with seeds, never overwriting user content.
  mkdir -p journal/logbook journal/decisions journal/experiments

  # Copy seeds without overwriting existing files.
  local seed
  for seed in lessons.md README.md; do
    if [ ! -f "journal/$seed" ]; then
      # Substitute date placeholder in lessons.md.
      sed "s/PLACEHOLDER/$(date '+%Y-%m-%d')/g" "$tdir/journal-seed/$seed" > "journal/$seed"
    fi
  done

  # Empty placeholder files in subdirs.
  local sub
  for sub in logbook decisions experiments; do
    [ -f "journal/$sub/.keep" ] || touch "journal/$sub/.keep"
  done

  # 2. Add journal/ to .gitignore (idempotent).
  if [ ! -f .gitignore ] || ! grep -qx "journal/" .gitignore; then
    echo "journal/" >> .gitignore
  fi

  # 3. Inject CLAUDE.md block (idempotent).
  local block_file="$tdir/CLAUDE-block.md"
  if [ -f CLAUDE.md ]; then
    if ! grep -q "scribe-block-begin" CLAUDE.md; then
      echo "" >> CLAUDE.md
      cat "$block_file" >> CLAUDE.md
    fi
  else
    cat "$block_file" > CLAUDE.md
  fi

  echo "scribe initialized for $(pwd)"
}
```

Then in the dispatcher case, replace the `init` stub with:

```bash
    init) cmd_init "$@" ;;
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
bats test/test_init.bats
```

Expected: 7 passing tests.

- [ ] **Step 6: Commit**

```bash
git add src/bin/scribe src/templates/ test/test_init.bats
git commit -m "Implement scribe init with idempotent gitignore + CLAUDE.md injection"
```

---

### Task 6: scribe init --decline (already implemented; add focused tests)

**Files:**
- Create: `~/projects/scribe/test/test_init_decline.bats`

- [ ] **Step 1: Write the test**

```bash
#!/usr/bin/env bats

load helpers

setup() { setup_isolated_env; }
teardown() { teardown_isolated_env; }

@test "scribe init --decline creates .scribe-declined" {
  run "$SCRIBE_BIN" init --decline
  [ "$status" -eq 0 ]
  [ -f "$PROJECT_DIR/.scribe-declined" ]
}

@test "scribe init --decline does NOT create journal/" {
  run "$SCRIBE_BIN" init --decline
  [ "$status" -eq 0 ]
  [ ! -d "$PROJECT_DIR/journal" ]
}

@test "scribe init --decline does NOT touch CLAUDE.md" {
  echo "original" > "$PROJECT_DIR/CLAUDE.md"
  "$SCRIBE_BIN" init --decline
  [ "$(cat "$PROJECT_DIR/CLAUDE.md")" = "original" ]
}
```

- [ ] **Step 2: Run the test**

```bash
bats test/test_init_decline.bats
```

Expected: 3 passing tests.

- [ ] **Step 3: Commit**

```bash
git add test/test_init_decline.bats
git commit -m "Add tests for scribe init --decline"
```

---

### Task 7: scribe pause / resume / status

**Files:**
- Modify: `~/projects/scribe/src/bin/scribe`
- Create: `~/projects/scribe/test/test_pause_resume.bats`

- [ ] **Step 1: Write the test**

```bash
#!/usr/bin/env bats

load helpers

setup() {
  setup_isolated_env
  "$SCRIBE_BIN" init
}
teardown() { teardown_isolated_env; }

@test "scribe pause creates .paused sentinel" {
  run "$SCRIBE_BIN" pause
  [ "$status" -eq 0 ]
  [ -f "$PROJECT_DIR/journal/.paused" ]
}

@test "scribe resume removes .paused sentinel" {
  "$SCRIBE_BIN" pause
  run "$SCRIBE_BIN" resume
  [ "$status" -eq 0 ]
  [ ! -f "$PROJECT_DIR/journal/.paused" ]
}

@test "scribe status reports active when not paused" {
  run "$SCRIBE_BIN" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"active"* ]]
}

@test "scribe status reports paused when paused" {
  "$SCRIBE_BIN" pause
  run "$SCRIBE_BIN" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"paused"* ]]
}

@test "scribe status reports declined when .scribe-declined exists" {
  rm -rf "$PROJECT_DIR/journal" "$PROJECT_DIR/.gitignore" "$PROJECT_DIR/CLAUDE.md"
  "$SCRIBE_BIN" init --decline
  run "$SCRIBE_BIN" status
  [[ "$output" == *"declined"* ]]
}

@test "scribe status reports not-initialized when no journal and no decline" {
  rm -rf "$PROJECT_DIR/journal" "$PROJECT_DIR/CLAUDE.md" "$PROJECT_DIR/.gitignore"
  run "$SCRIBE_BIN" status
  [[ "$output" == *"not initialized"* ]] || [[ "$output" == *"not enabled"* ]]
}
```

- [ ] **Step 2: Run the test (expect failures)**

```bash
bats test/test_pause_resume.bats
```

- [ ] **Step 3: Implement in `src/bin/scribe`**

Add these functions:

```bash
cmd_pause() {
  if [ ! -d journal ]; then
    echo "scribe: journal/ does not exist; run 'scribe init' first" >&2
    return 1
  fi
  : > "journal/.paused"
  echo "scribe paused"
}

cmd_resume() {
  if [ -f "journal/.paused" ]; then
    rm -f "journal/.paused"
  fi
  echo "scribe resumed"
}

cmd_status() {
  if [ -f ".scribe-declined" ]; then
    echo "scribe is declined for this project"
    return 0
  fi
  if [ ! -d journal ]; then
    echo "scribe is not enabled for this project"
    return 0
  fi
  if [ -f journal/.paused ]; then
    echo "scribe is paused"
  else
    echo "scribe is active"
  fi

  # Counts
  local logs=0 decisions=0 experiments=0
  if [ -d journal/logbook ]; then
    logs=$(ls -1 journal/logbook/*.md 2>/dev/null | wc -l | tr -d ' ')
  fi
  if [ -d journal/decisions ]; then
    decisions=$(ls -1 journal/decisions/*.md 2>/dev/null | wc -l | tr -d ' ')
  fi
  if [ -d journal/experiments ]; then
    experiments=$(ls -1 journal/experiments/*.md 2>/dev/null | wc -l | tr -d ' ')
  fi
  echo "  logbook entries: $logs"
  echo "  decisions: $decisions"
  echo "  experiments: $experiments"

  # Most recent logbook
  local latest
  latest=$(ls -1t journal/logbook/*.md 2>/dev/null | head -1)
  if [ -n "$latest" ]; then
    echo "  last entry: $(basename "$latest" .md)"
  fi
}
```

Replace the stubs in the dispatcher:

```bash
    pause)  cmd_pause "$@" ;;
    resume) cmd_resume "$@" ;;
    status) cmd_status "$@" ;;
```

- [ ] **Step 4: Run tests**

```bash
bats test/test_pause_resume.bats
```

Expected: 6 passing tests.

- [ ] **Step 5: Commit**

```bash
git add src/bin/scribe test/test_pause_resume.bats
git commit -m "Implement scribe pause / resume / status"
```

---

### Task 8: scribe off

**Files:**
- Modify: `~/projects/scribe/src/bin/scribe`
- Create: `~/projects/scribe/test/test_off.bats`

- [ ] **Step 1: Write the test**

```bash
#!/usr/bin/env bats

load helpers

setup() {
  setup_isolated_env
  "$SCRIBE_BIN" init
}
teardown() { teardown_isolated_env; }

@test "scribe off --yes removes journal/ and CLAUDE.md block" {
  echo "Other content" > "$PROJECT_DIR/CLAUDE.md.bak"
  cat "$PROJECT_DIR/CLAUDE.md.bak" "$PROJECT_DIR/CLAUDE.md" > "$PROJECT_DIR/CLAUDE.md.new"
  mv "$PROJECT_DIR/CLAUDE.md.new" "$PROJECT_DIR/CLAUDE.md"

  run "$SCRIBE_BIN" off --yes
  [ "$status" -eq 0 ]
  [ ! -d "$PROJECT_DIR/journal" ]
  ! grep -q "scribe-block-begin" "$PROJECT_DIR/CLAUDE.md"
  grep -q "Other content" "$PROJECT_DIR/CLAUDE.md"
}

@test "scribe off --yes removes .scribe-declined too" {
  touch "$PROJECT_DIR/.scribe-declined"
  run "$SCRIBE_BIN" off --yes
  [ ! -f "$PROJECT_DIR/.scribe-declined" ]
}

@test "scribe off without --yes prompts and aborts on no input" {
  run bash -c "echo 'n' | '$SCRIBE_BIN' off"
  [ "$status" -ne 0 ]
  [ -d "$PROJECT_DIR/journal" ]
}

@test "scribe off removes journal/ line from .gitignore" {
  run "$SCRIBE_BIN" off --yes
  if [ -f "$PROJECT_DIR/.gitignore" ]; then
    ! grep -q "^journal/$" "$PROJECT_DIR/.gitignore"
  fi
}
```

- [ ] **Step 2: Run test (failure)**

```bash
bats test/test_off.bats
```

- [ ] **Step 3: Implement `cmd_off`**

```bash
cmd_off() {
  local yes=0
  if [ "${1:-}" = "--yes" ]; then yes=1; fi

  if [ $yes -eq 0 ]; then
    printf "Remove scribe from this project? (y/N) "
    read -r reply
    case "$reply" in
      y|Y|yes|YES) ;;
      *) echo "aborted"; return 1 ;;
    esac
  fi

  # 1. Remove journal/
  rm -rf journal

  # 2. Remove .scribe-declined
  rm -f .scribe-declined

  # 3. Strip the scribe block from CLAUDE.md (preserve other content).
  if [ -f CLAUDE.md ]; then
    awk '
      /<!-- scribe-block-begin -->/ { in_block = 1; next }
      /<!-- scribe-block-end -->/   { in_block = 0; next }
      !in_block { print }
    ' CLAUDE.md > CLAUDE.md.tmp && mv CLAUDE.md.tmp CLAUDE.md
    # Trim trailing blank lines.
    awk 'NR==FNR{if(NF)last=NR; next} FNR<=last' CLAUDE.md CLAUDE.md > CLAUDE.md.tmp && mv CLAUDE.md.tmp CLAUDE.md
    # Remove file entirely if empty.
    if [ ! -s CLAUDE.md ]; then rm -f CLAUDE.md; fi
  fi

  # 4. Remove journal/ line from .gitignore (if present).
  if [ -f .gitignore ]; then
    grep -v "^journal/$" .gitignore > .gitignore.tmp || true
    mv .gitignore.tmp .gitignore
    [ -s .gitignore ] || rm -f .gitignore
  fi

  echo "scribe removed from $(pwd)"
}
```

Add to dispatcher:

```bash
    off) cmd_off "$@" ;;
```

- [ ] **Step 4: Run tests**

```bash
bats test/test_off.bats
```

Expected: 4 passing tests.

- [ ] **Step 5: Commit**

```bash
git add src/bin/scribe test/test_off.bats
git commit -m "Implement scribe off with confirmation gate"
```

---

### Task 9: Desktop path resolution helper

**Files:**
- Modify: `~/projects/scribe/src/bin/scribe`
- Create: `~/projects/scribe/test/test_desktop_path.bats`

- [ ] **Step 1: Write tests**

```bash
#!/usr/bin/env bats

load helpers

setup() { setup_isolated_env; }
teardown() { teardown_isolated_env; }

@test "desktop path: ~/Desktop when it exists" {
  mkdir -p "$HOME/Desktop"
  run "$SCRIBE_BIN" __desktop_path
  [ "$status" -eq 0 ]
  [ "$output" = "$HOME/Desktop" ]
}

@test "desktop path: xdg-user-dir when ~/Desktop missing" {
  install_fake_xdg
  # The fake xdg-user-dir echoes its arg back; simulate it printing a real path.
  cat >"$TEST_HOME/fakebin/xdg-user-dir" <<EOF
#!/bin/bash
echo "$TEST_HOME/CustomDesktop"
EOF
  chmod +x "$TEST_HOME/fakebin/xdg-user-dir"
  mkdir -p "$TEST_HOME/CustomDesktop"

  run "$SCRIBE_BIN" __desktop_path
  [ "$status" -eq 0 ]
  [ "$output" = "$TEST_HOME/CustomDesktop" ]
}

@test "desktop path: fallback to HOME when nothing else" {
  # No Desktop dir, no xdg-user-dir on PATH.
  export PATH="$TEST_HOME/onlypath"
  mkdir -p "$TEST_HOME/onlypath"
  ln -s "$(command -v bash)" "$TEST_HOME/onlypath/bash"
  ln -s "$(command -v ls)" "$TEST_HOME/onlypath/ls"
  ln -s "$(command -v mkdir)" "$TEST_HOME/onlypath/mkdir"
  run "$SCRIBE_BIN" __desktop_path
  [ "$status" -eq 0 ]
  [ "$output" = "$HOME" ]
}
```

- [ ] **Step 2: Run (failure expected)**

```bash
bats test/test_desktop_path.bats
```

- [ ] **Step 3: Implement** — add a hidden `__desktop_path` helper subcommand

```bash
__desktop_path() {
  # WSL detection
  if [ -f /proc/version ] && grep -qi microsoft /proc/version 2>/dev/null; then
    if command -v wslvar >/dev/null 2>&1 && command -v wslpath >/dev/null 2>&1; then
      local winprof
      winprof="$(wslvar USERPROFILE 2>/dev/null || true)"
      if [ -n "$winprof" ]; then
        wslpath "$winprof\\Desktop" 2>/dev/null && return 0
      fi
    fi
    if [ -d "/mnt/c/Users/$USER/Desktop" ]; then
      echo "/mnt/c/Users/$USER/Desktop"
      return 0
    fi
  fi

  if command -v xdg-user-dir >/dev/null 2>&1; then
    local xdg
    xdg="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
    if [ -n "$xdg" ] && [ -d "$xdg" ]; then
      echo "$xdg"
      return 0
    fi
  fi

  if [ -d "$HOME/Desktop" ]; then
    echo "$HOME/Desktop"
    return 0
  fi

  echo "$HOME"
  echo "scribe: warning — couldn't find Desktop, falling back to home directory" >&2
}
```

Add to dispatcher (hidden command, prefixed with `__`):

```bash
    __desktop_path) __desktop_path ;;
```

- [ ] **Step 4: Run tests**

```bash
bats test/test_desktop_path.bats
```

Expected: 3 passing.

- [ ] **Step 5: Commit**

```bash
git add src/bin/scribe test/test_desktop_path.bats
git commit -m "Add desktop path resolution helper for cross-platform archive output"
```

---

### Task 10: Project name sanitization helper

**Files:**
- Modify: `~/projects/scribe/src/bin/scribe`
- Create: `~/projects/scribe/test/test_sanitize.bats`

- [ ] **Step 1: Write tests**

```bash
#!/usr/bin/env bats

load helpers

setup() { setup_isolated_env; }
teardown() { teardown_isolated_env; }

@test "sanitize: simple name passes through" {
  run "$SCRIBE_BIN" __sanitize "my-cool-app"
  [ "$status" -eq 0 ]
  [ "$output" = "my-cool-app" ]
}

@test "sanitize: spaces become underscores" {
  run "$SCRIBE_BIN" __sanitize "My Cool App"
  [ "$output" = "My_Cool_App" ]
}

@test "sanitize: special characters become underscores" {
  run "$SCRIBE_BIN" __sanitize "weird/path:name"
  [ "$output" = "weird_path_name" ]
}

@test "sanitize: collapses runs of underscores" {
  run "$SCRIBE_BIN" __sanitize "foo   bar"
  [ "$output" = "foo_bar" ]
}

@test "sanitize: preserves dots and hyphens" {
  run "$SCRIBE_BIN" __sanitize "v1.0-beta"
  [ "$output" = "v1.0-beta" ]
}
```

- [ ] **Step 2: Run (failure)**

```bash
bats test/test_sanitize.bats
```

- [ ] **Step 3: Implement**

```bash
__sanitize() {
  local input="${1:-}"
  # Replace any char not in [A-Za-z0-9._-] with _, then collapse runs.
  echo "$input" | sed 's/[^A-Za-z0-9._-]/_/g; s/__*/_/g; s/^_//; s/_$//'
}
```

Add to dispatcher:

```bash
    __sanitize) __sanitize "$@" ;;
```

- [ ] **Step 4: Run tests**

```bash
bats test/test_sanitize.bats
```

Expected: 5 passing.

- [ ] **Step 5: Commit**

```bash
git add src/bin/scribe test/test_sanitize.bats
git commit -m "Add project-name sanitization helper"
```

---

### Task 11: scribe archive

**Files:**
- Modify: `~/projects/scribe/src/bin/scribe`
- Create: `~/projects/scribe/test/test_archive.bats`

- [ ] **Step 1: Write tests**

```bash
#!/usr/bin/env bats

load helpers

setup() {
  setup_isolated_env
  install_fake_claude
  # Override desktop to a known fixture path so we can assert on it.
  mkdir -p "$TEST_HOME/Desktop"

  "$SCRIBE_BIN" init

  # Seed some content.
  cat >"$PROJECT_DIR/journal/logbook/2026-04-30.md" <<EOF
---
id: log-2026-04-30
type: logbook
date: 2026-04-30
---
# 2026-04-30
First session content.
EOF

  cat >"$PROJECT_DIR/journal/decisions/001-foo.md" <<EOF
---
id: decision-001-foo
type: decision
---
# 001 — Pick foo
Decided to pick foo.
EOF

  # Configure fake claude to write a fake summary into a known temp file.
  cat >"$TEST_HOME/fakebin/claude" <<'FAKE'
#!/bin/bash
# Read prompt from stdin so the test can inspect it.
cat > "$TEST_HOME/claude.stdin"
# Write the simulated summary to the path the prompt requests.
# The archive command tells us via env where the summary tempfile is.
if [ -n "${SCRIBE_FAKE_SUMMARY_PATH:-}" ]; then
  printf '%s\n' "Fake one-screen summary of the project. ~300 words placeholder." > "$SCRIBE_FAKE_SUMMARY_PATH"
fi
exit 0
FAKE
  chmod +x "$TEST_HOME/fakebin/claude"
}

teardown() { teardown_isolated_env; }

@test "scribe archive refuses when journal/ is empty" {
  rm -rf "$PROJECT_DIR/journal"
  run "$SCRIBE_BIN" archive
  [ "$status" -ne 0 ]
  [[ "$output" == *"nothing to archive"* ]]
}

@test "scribe archive writes to desktop and library" {
  run "$SCRIBE_BIN" archive
  [ "$status" -eq 0 ]
  local desktop="$HOME/Desktop"
  local proj="$(basename "$PROJECT_DIR")"
  [ -f "$desktop/${proj}_archive.md" ]
  [ -f "$HOME/.scribe/library/${proj}_archive.md" ]
}

@test "scribe archive output contains required sections" {
  "$SCRIBE_BIN" archive
  local desktop="$HOME/Desktop"
  local proj="$(basename "$PROJECT_DIR")"
  local f="$desktop/${proj}_archive.md"

  grep -q "^## Summary" "$f"
  grep -q "^## Lessons learned" "$f"
  grep -q "^## Decisions" "$f"
  grep -q "001 — Pick foo" "$f"
}

@test "scribe archive frontmatter has project + archived date" {
  "$SCRIBE_BIN" archive
  local desktop="$HOME/Desktop"
  local proj="$(basename "$PROJECT_DIR")"
  local f="$desktop/${proj}_archive.md"

  grep -q "^project:" "$f"
  grep -q "^archived: $(date '+%Y-%m-%d')" "$f"
}

@test "scribe archive is idempotent (rerun refreshes both copies)" {
  "$SCRIBE_BIN" archive
  local desktop="$HOME/Desktop"
  local proj="$(basename "$PROJECT_DIR")"
  local first_size
  first_size=$(wc -c < "$desktop/${proj}_archive.md")

  # Add new content, rerun.
  cat >"$PROJECT_DIR/journal/decisions/002-bar.md" <<EOF
---
id: decision-002-bar
type: decision
---
# 002 — Pick bar
EOF
  "$SCRIBE_BIN" archive
  local second_size
  second_size=$(wc -c < "$desktop/${proj}_archive.md")
  [ "$second_size" -gt "$first_size" ]
  grep -q "002 — Pick bar" "$desktop/${proj}_archive.md"
}
```

- [ ] **Step 2: Run (failure)**

```bash
bats test/test_archive.bats
```

- [ ] **Step 3: Implement `cmd_archive`**

```bash
cmd_archive() {
  if [ ! -d journal ] || [ -z "$(ls -A journal 2>/dev/null)" ]; then
    echo "scribe: nothing to archive (journal/ is empty or missing)" >&2
    return 1
  fi

  local proj_name proj_safe
  proj_name="$(basename "$(pwd)")"
  proj_safe="$(__sanitize "$proj_name")"
  local today; today="$(date '+%Y-%m-%d')"

  local desktop; desktop="$(__desktop_path)"
  local library="$HOME/.scribe/library"
  mkdir -p "$library" "$desktop"

  local out="$desktop/${proj_safe}_archive.md"
  local lib_out="$library/${proj_safe}_archive.md"
  local tmp; tmp="$(mktemp)"

  # 1. Generate the Summary section via sub-Claude.
  local summary_path; summary_path="$(mktemp)"
  local prompt
  prompt=$(cat <<EOF
You are summarizing the project "$proj_name" for an archive document. Read the journal at $(pwd)/journal/, then write a single ~300-word plain-prose summary covering:
- What the project was and who it was for.
- The key decisions made and why.
- The most important lessons learned.
- The final state of the project.

Write the summary to $summary_path. No bullets, no headers. Just prose. Do not ask questions. Do not explain what you did.
EOF
)

  if command -v claude >/dev/null 2>&1; then
    SCRIBE_FAKE_SUMMARY_PATH="$summary_path" \
    CLAUDE_JOURNAL_HOOK=1 \
    claude -p --permission-mode bypassPermissions <<<"$prompt" >/dev/null 2>&1 || true
  fi

  # If sub-Claude failed/missing, write a placeholder summary.
  if [ ! -s "$summary_path" ]; then
    echo "(Auto-summary unavailable. Read the rest of this archive for details.)" > "$summary_path"
  fi

  # 2. Build the archive.
  local sessions
  sessions=$(ls -1 journal/logbook/*.md 2>/dev/null | wc -l | tr -d ' ')

  {
    echo "---"
    echo "project: $proj_name"
    echo "archived: $today"
    echo "sessions: $sessions"
    echo "---"
    echo
    echo "# $proj_name"
    echo
    echo "## Summary"
    echo
    cat "$summary_path"
    echo

    echo "## Lessons learned"
    echo
    if [ -f journal/lessons.md ]; then
      # Skip frontmatter
      awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' journal/lessons.md
    fi
    echo

    if ls journal/decisions/*.md >/dev/null 2>&1; then
      echo "## Decisions"
      echo
      local d
      for d in $(ls journal/decisions/*.md 2>/dev/null | sort); do
        # Strip frontmatter, then de-elevate the H1 to H3.
        awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' "$d" | \
          sed '0,/^# /s/^# /### /'
        echo
      done
    fi

    if ls journal/experiments/*.md >/dev/null 2>&1; then
      echo "## Experiments"
      echo
      local e
      for e in $(ls journal/experiments/*.md 2>/dev/null | sort); do
        awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' "$e" | \
          sed '0,/^# /s/^# /### /'
        echo
      done
    fi

    if [ -f journal/glossary.md ]; then
      echo "## Glossary"
      echo
      awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' journal/glossary.md
      echo
    fi

    if ls journal/logbook/*.md >/dev/null 2>&1; then
      echo "## Recent activity"
      echo
      local l
      for l in $(ls -1t journal/logbook/*.md 2>/dev/null | head -10 | tr '\n' ' '); do
        awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' "$l" | \
          sed '0,/^# /s/^# /### /'
        echo
      done
    fi
  } > "$tmp"

  # 3. Write to both locations atomically.
  mv "$tmp" "$out"
  cp "$out" "$lib_out"

  rm -f "$summary_path"

  echo "Saved to your desktop as ${proj_safe}_archive.md"
  echo "  desktop: $out"
  echo "  library: $lib_out"
}
```

Add to dispatcher:

```bash
    archive) cmd_archive "$@" ;;
```

- [ ] **Step 4: Run tests**

```bash
bats test/test_archive.bats
```

Expected: 5 passing.

- [ ] **Step 5: Commit**

```bash
git add src/bin/scribe test/test_archive.bats
git commit -m "Implement scribe archive: single-file Markdown to desktop + library"
```

---

### Task 12: scribe link / unlink / library

**Files:**
- Modify: `~/projects/scribe/src/bin/scribe`
- Create: `~/projects/scribe/test/test_link.bats`

- [ ] **Step 1: Write tests**

```bash
#!/usr/bin/env bats

load helpers

setup() {
  setup_isolated_env
  "$SCRIBE_BIN" init

  # Seed the library with a fake archived project.
  mkdir -p "$HOME/.scribe/library"
  cat >"$HOME/.scribe/library/foo_archive.md" <<EOF
---
project: foo
archived: 2026-04-01
---
# foo

## Summary
Foo summary content.

## Lessons learned
- Foo lesson.
EOF
}
teardown() { teardown_isolated_env; }

@test "scribe link adds the project to .imports.txt" {
  run "$SCRIBE_BIN" link foo
  [ "$status" -eq 0 ]
  grep -qx "foo" "$PROJECT_DIR/journal/.imports.txt"
}

@test "scribe link is idempotent (no duplicate lines)" {
  "$SCRIBE_BIN" link foo
  "$SCRIBE_BIN" link foo
  count=$(grep -c "^foo$" "$PROJECT_DIR/journal/.imports.txt")
  [ "$count" -eq 1 ]
}

@test "scribe link rejects unknown projects" {
  run "$SCRIBE_BIN" link does-not-exist
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found in library"* ]]
}

@test "scribe unlink removes the entry" {
  "$SCRIBE_BIN" link foo
  run "$SCRIBE_BIN" unlink foo
  [ "$status" -eq 0 ]
  ! grep -qx "foo" "$PROJECT_DIR/journal/.imports.txt" 2>/dev/null
}

@test "scribe library lists archived projects" {
  run "$SCRIBE_BIN" library
  [ "$status" -eq 0 ]
  [[ "$output" == *"foo"* ]]
}

@test "scribe library when empty prints a friendly message" {
  rm -f "$HOME/.scribe/library"/*.md
  run "$SCRIBE_BIN" library
  [ "$status" -eq 0 ]
  [[ "$output" == *"no archived projects"* ]]
}
```

- [ ] **Step 2: Run (failure)**

```bash
bats test/test_link.bats
```

- [ ] **Step 3: Implement**

```bash
cmd_link() {
  local name="${1:-}"
  if [ -z "$name" ]; then
    echo "Usage: scribe link <project-name>" >&2; return 2
  fi
  local safe; safe="$(__sanitize "$name")"
  local archive="$HOME/.scribe/library/${safe}_archive.md"
  if [ ! -f "$archive" ]; then
    echo "scribe: '$name' not found in library at $archive" >&2; return 1
  fi
  if [ ! -d journal ]; then
    echo "scribe: journal/ does not exist; run 'scribe init' first" >&2; return 1
  fi
  local imports="journal/.imports.txt"
  if [ ! -f "$imports" ] || ! grep -qx "$safe" "$imports"; then
    echo "$safe" >> "$imports"
  fi
  echo "Linked $safe — its summary + lessons will load on next session."
}

cmd_unlink() {
  local name="${1:-}"
  if [ -z "$name" ]; then
    echo "Usage: scribe unlink <project-name>" >&2; return 2
  fi
  local safe; safe="$(__sanitize "$name")"
  local imports="journal/.imports.txt"
  if [ -f "$imports" ]; then
    grep -vx "$safe" "$imports" > "$imports.tmp" || true
    mv "$imports.tmp" "$imports"
    [ -s "$imports" ] || rm -f "$imports"
  fi
  echo "Unlinked $safe."
}

cmd_library() {
  local libdir="$HOME/.scribe/library"
  if [ ! -d "$libdir" ] || [ -z "$(ls -A "$libdir" 2>/dev/null)" ]; then
    echo "no archived projects yet"
    return 0
  fi
  echo "Archived projects:"
  local f
  for f in "$libdir"/*_archive.md; do
    [ -f "$f" ] || continue
    local name; name=$(basename "$f" _archive.md)
    local archived
    archived=$(awk -F': ' '/^archived:/{print $2; exit}' "$f")
    echo "  $name (archived $archived)"
  done
}
```

Add to dispatcher:

```bash
    link)    cmd_link "$@" ;;
    unlink)  cmd_unlink "$@" ;;
    library) cmd_library "$@" ;;
```

- [ ] **Step 4: Run tests**

```bash
bats test/test_link.bats
```

Expected: 6 passing.

- [ ] **Step 5: Commit**

```bash
git add src/bin/scribe test/test_link.bats
git commit -m "Implement scribe link / unlink / library"
```

---

### Task 13: scribe doctor

**Files:**
- Modify: `~/projects/scribe/src/bin/scribe`
- Create: `~/projects/scribe/test/test_doctor.bats`

- [ ] **Step 1: Write tests**

```bash
#!/usr/bin/env bats

load helpers

setup() { setup_isolated_env; }
teardown() { teardown_isolated_env; }

@test "scribe doctor reports missing install when ~/.scribe is absent" {
  run "$SCRIBE_BIN" doctor
  [[ "$output" == *"~/.scribe"* ]]
  [[ "$output" == *"missing"* ]] || [[ "$output" == *"not found"* ]]
}

@test "scribe doctor reports missing claude CLI" {
  # Strip claude from PATH.
  export PATH="/usr/bin:/bin"
  run "$SCRIBE_BIN" doctor
  [[ "$output" == *"claude"* ]]
}

@test "scribe doctor reports green on a healthy install" {
  mkdir -p "$HOME/.scribe/bin" "$HOME/.scribe/hooks" "$HOME/.scribe/templates" "$HOME/.scribe/library"
  echo "0.1.0" > "$HOME/.scribe/VERSION"
  touch "$HOME/.scribe/hooks/session-start.sh" "$HOME/.scribe/hooks/stop.sh"
  mkdir -p "$HOME/.claude"
  echo '{"hooks":{}}' > "$HOME/.claude/settings.json"

  install_fake_claude

  run "$SCRIBE_BIN" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]] || [[ "$output" == *"healthy"* ]] || [[ "$output" == *"green"* ]]
}
```

- [ ] **Step 2: Run (failure)**

```bash
bats test/test_doctor.bats
```

- [ ] **Step 3: Implement `cmd_doctor`**

```bash
cmd_doctor() {
  local issues=0
  echo "scribe doctor:"

  if [ -d "$HOME/.scribe" ]; then
    echo "  ✓ ~/.scribe exists"
  else
    echo "  ✗ ~/.scribe missing — scribe is not installed"
    issues=$((issues+1))
  fi

  if [ -f "$HOME/.scribe/hooks/session-start.sh" ] && [ -f "$HOME/.scribe/hooks/stop.sh" ]; then
    echo "  ✓ hook scripts present"
  else
    echo "  ✗ hook scripts not found at ~/.scribe/hooks/"
    issues=$((issues+1))
  fi

  if [ -f "$HOME/.claude/settings.json" ]; then
    echo "  ✓ ~/.claude/settings.json exists"
  else
    echo "  ✗ ~/.claude/settings.json missing"
    issues=$((issues+1))
  fi

  if command -v claude >/dev/null 2>&1; then
    echo "  ✓ claude CLI on PATH"
  else
    echo "  ✗ claude CLI not on PATH (install Claude Code)"
    issues=$((issues+1))
  fi

  if [ -x "$HOME/.scribe/bin/jq" ] || command -v jq >/dev/null 2>&1; then
    echo "  ✓ jq available"
  else
    echo "  ✗ jq not available (re-run installer)"
    issues=$((issues+1))
  fi

  if [ $issues -eq 0 ]; then
    echo
    echo "All checks OK. scribe install is healthy."
    return 0
  else
    echo
    echo "$issues issue(s) found."
    return 1
  fi
}
```

Add to dispatcher:

```bash
    doctor) cmd_doctor "$@" ;;
```

- [ ] **Step 4: Run tests**

```bash
bats test/test_doctor.bats
```

Expected: 3 passing.

- [ ] **Step 5: Commit**

```bash
git add src/bin/scribe test/test_doctor.bats
git commit -m "Implement scribe doctor diagnostics"
```

---

### Task 14: SessionStart hook

**Files:**
- Create: `~/projects/scribe/src/hooks/session-start.sh`
- Create: `~/projects/scribe/test/test_session_start.bats`

- [ ] **Step 1: Write tests**

```bash
#!/usr/bin/env bats

load helpers

HOOK="$SCRIBE_REPO/src/hooks/session-start.sh"

setup() {
  setup_isolated_env
  chmod +x "$HOOK"
}
teardown() { teardown_isolated_env; }

run_hook() {
  cd "$PROJECT_DIR"
  bash "$HOOK"
}

@test "session-start: silent exit when no journal and no decline marker is invalid — should emit bootstrap prompt" {
  run run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"scribe is installed"* ]] || [[ "$output" == *"Scribe is installed"* ]]
}

@test "session-start: silent exit when .scribe-declined exists" {
  : > "$PROJECT_DIR/.scribe-declined"
  run run_hook
  [ "$status" -eq 0 ]
  [ -z "$output" ] || [[ "$output" != *"Scribe"* ]]
}

@test "session-start: paused notice when journal/.paused exists" {
  "$SCRIBE_BIN" init
  : > "$PROJECT_DIR/journal/.paused"
  run run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"paused"* ]]
}

@test "session-start: active context when journal exists" {
  "$SCRIBE_BIN" init
  cat >"$PROJECT_DIR/journal/logbook/2026-04-30.md" <<EOF
---
id: log-2026-04-30
type: logbook
---
# 2026-04-30
Latest session content.
EOF

  run run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"Latest session content"* ]]
  [[ "$output" == *"Lessons"* ]] || [[ "$output" == *"lessons"* ]]
}

@test "session-start: imports load summary + lessons sections" {
  "$SCRIBE_BIN" init
  mkdir -p "$HOME/.scribe/library"
  cat >"$HOME/.scribe/library/foo_archive.md" <<EOF
---
project: foo
archived: 2026-04-01
---
# foo

## Summary
Imported foo summary.

## Lessons learned
- Imported foo lesson.

## Decisions
### 001 — should not appear
EOF
  echo "foo" > "$PROJECT_DIR/journal/.imports.txt"

  run run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"Imported foo summary"* ]]
  [[ "$output" == *"Imported foo lesson"* ]]
  [[ "$output" != *"should not appear"* ]]
}

@test "session-start: recursion guard CLAUDE_JOURNAL_HOOK=1 short-circuits" {
  "$SCRIBE_BIN" init
  CLAUDE_JOURNAL_HOOK=1 run run_hook
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
```

- [ ] **Step 2: Run (failure — hook doesn't exist)**

```bash
bats test/test_session_start.bats
```

- [ ] **Step 3: Implement `src/hooks/session-start.sh`**

```bash
#!/bin/bash
# scribe SessionStart hook — emits per-project journal context to Claude Code.
# Exit 0 always; never block the user. Logs to ~/.scribe/scribe.log on errors.

set -u

SCRIBE_HOME="${SCRIBE_HOME:-$HOME/.scribe}"
LOG="$SCRIBE_HOME/scribe.log"
mkdir -p "$SCRIBE_HOME" 2>/dev/null || true

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] session-start: $*" >>"$LOG" 2>/dev/null || true; }

# Recursion guard.
if [ "${CLAUDE_JOURNAL_HOOK:-0}" = "1" ]; then
  exit 0
fi

# Resolve project root.
project_root() {
  if command -v git >/dev/null 2>&1; then
    local root
    root=$(git rev-parse --show-toplevel 2>/dev/null || true)
    [ -n "$root" ] && { echo "$root"; return; }
  fi
  echo "$PWD"
}

ROOT="$(project_root)"
JOURNAL="$ROOT/journal"
PAUSED="$JOURNAL/.paused"
DECLINED="$ROOT/.scribe-declined"

emit_json() {
  local ctx="$1"
  if [ -x "$SCRIBE_HOME/bin/jq" ]; then
    "$SCRIBE_HOME/bin/jq" -n --arg ctx "$ctx" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
  elif command -v jq >/dev/null 2>&1; then
    jq -n --arg ctx "$ctx" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
  else
    printf '%s\n' "$ctx"
  fi
}

# Section extractor: pull a markdown section from FILE between a heading and the next H2.
# Args: file, heading-name.
extract_section() {
  local file="$1" heading="$2"
  awk -v h="$heading" '
    BEGIN { in_section = 0 }
    /^## / {
      if (in_section) exit
      if ($0 ~ "^## " h "$") in_section = 1
      next
    }
    in_section { print }
  ' "$file"
}

# State machine.
if [ -f "$PAUSED" ]; then
  emit_json "scribe is paused for this project ($ROOT). No journal writes will happen this session unless you resume."
  exit 0
fi

if [ ! -d "$JOURNAL" ]; then
  if [ -f "$DECLINED" ]; then
    log "declined for $ROOT, exiting silently"
    exit 0
  fi
  # Bootstrap prompt.
  CTX=$(cat <<EOF
Scribe is installed on this machine but not yet enabled for this project ($ROOT).

On your next response to the user, ask once whether they want to turn on auto-journaling for this project. Suggested phrasing: "You have scribe installed — want me to turn on auto-journaling for this project? (yes / no / not now)".

- If yes: run \`scribe init\` (via Bash).
- If no: run \`scribe init --decline\` (creates a marker so this prompt won't fire again).
- If "not now" or unclear: don't do anything; the prompt will re-fire next session.

Do not ask again later in this session if the user already answered.
EOF
)
  emit_json "$CTX"
  exit 0
fi

# Active context.
PROJ_NAME="$(basename "$ROOT")"
CTX="# Project: $PROJ_NAME
Directory: $ROOT
"

# Most recent logbook entry (full).
LATEST_LOG=$(ls -1t "$JOURNAL/logbook/"*.md 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ] && [ -f "$LATEST_LOG" ]; then
  CTX="$CTX

## Most recent logbook entry ($(basename "$LATEST_LOG"))

$(cat "$LATEST_LOG")
"
fi

# Lessons (full).
if [ -f "$JOURNAL/lessons.md" ]; then
  CTX="$CTX

## Lessons

$(cat "$JOURNAL/lessons.md")
"
fi

# Index of the rest.
count_md() {
  find "$1" -maxdepth 1 -name '*.md' ! -name 'README.md' 2>/dev/null | wc -l | tr -d ' '
}
DEC_COUNT=$([ -d "$JOURNAL/decisions" ] && count_md "$JOURNAL/decisions" || echo 0)
EXP_COUNT=$([ -d "$JOURNAL/experiments" ] && count_md "$JOURNAL/experiments" || echo 0)
LOG_COUNT=$([ -d "$JOURNAL/logbook" ] && count_md "$JOURNAL/logbook" || echo 0)
GLOSS_PRESENT=$([ -f "$JOURNAL/glossary.md" ] && echo 1 || echo 0)

CTX="$CTX

## Journal index (read on demand)

- \`journal/decisions/\` — $DEC_COUNT ADR(s)
- \`journal/experiments/\` — $EXP_COUNT experiment(s)
- \`journal/logbook/\` — $LOG_COUNT daily log(s)
"
[ "$GLOSS_PRESENT" = "1" ] && CTX="$CTX- \`journal/glossary.md\` — present
"

# Project-specific top-level MDs.
local_mds=$(ls -1 "$JOURNAL"/*.md 2>/dev/null | grep -v -E '/(README|lessons|glossary)\.md$' || true)
if [ -n "$local_mds" ]; then
  CTX="$CTX
- Top-level themed files:
"
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    CTX="$CTX  - \`journal/$(basename "$f")\`
"
  done <<<"$local_mds"
fi

CTX="$CTX
Read specific files only when the current question actually needs them.

The past-projects library is at \`~/.scribe/library/\`. Grep it on demand when the user asks 'have we faced this before?' or similar."

# Imported context.
IMPORTS_FILE="$JOURNAL/.imports.txt"
if [ -f "$IMPORTS_FILE" ]; then
  while IFS= read -r imp; do
    [ -z "$imp" ] && continue
    local archive="$HOME/.scribe/library/${imp}_archive.md"
    [ -f "$archive" ] || continue
    local sum lessons
    sum=$(extract_section "$archive" "Summary")
    lessons=$(extract_section "$archive" "Lessons learned")
    CTX="$CTX

## Imported context from $imp

### Summary
$sum

### Lessons learned
$lessons
"
  done < "$IMPORTS_FILE"
fi

emit_json "$CTX"
log "active context emitted for $ROOT (logs:$LOG_COUNT decisions:$DEC_COUNT experiments:$EXP_COUNT)"
exit 0
```

- [ ] **Step 4: Run tests**

```bash
chmod +x src/hooks/session-start.sh
bats test/test_session_start.bats
```

Expected: 6 passing.

- [ ] **Step 5: Commit**

```bash
git add src/hooks/session-start.sh test/test_session_start.bats
git commit -m "Implement SessionStart hook with state machine + imports"
```

---

### Task 15: Stop hook

**Files:**
- Create: `~/projects/scribe/src/hooks/stop.sh`
- Create: `~/projects/scribe/test/test_stop.bats`
- Create: `~/projects/scribe/test/fixtures/transcript.jsonl`

- [ ] **Step 1: Write the fixture transcript**

```bash
mkdir -p ~/projects/scribe/test/fixtures
# Create a transcript file > 2KB so the hook doesn't skip it.
printf '%s' '{"role":"user","content":"please refactor the auth flow to use session tokens instead of cookies because the current approach has a security issue"}' > ~/projects/scribe/test/fixtures/transcript.jsonl
echo >> ~/projects/scribe/test/fixtures/transcript.jsonl
for i in $(seq 1 30); do
  printf '%s\n' '{"role":"assistant","content":"this is filler content to push the transcript over 2KB so the rate limit doesnt skip it. doing real work here."}' >> ~/projects/scribe/test/fixtures/transcript.jsonl
done
```

- [ ] **Step 2: Write tests**

```bash
#!/usr/bin/env bats

load helpers

HOOK="$SCRIBE_REPO/src/hooks/stop.sh"

setup() {
  setup_isolated_env
  install_fake_claude
  chmod +x "$HOOK"
  "$SCRIBE_BIN" init
}
teardown() { teardown_isolated_env; }

run_hook_with() {
  local transcript="$1"
  local stdin_json="{\"transcript_path\": \"$transcript\"}"
  cd "$PROJECT_DIR"
  echo "$stdin_json" | bash "$HOOK"
}

@test "stop hook: recursion guard short-circuits" {
  CLAUDE_JOURNAL_HOOK=1 run_hook_with "$SCRIBE_REPO/test/fixtures/transcript.jsonl"
  [ ! -f "$TEST_HOME/claude.calls" ]
}

@test "stop hook: skips when journal/ missing" {
  rm -rf "$PROJECT_DIR/journal"
  run_hook_with "$SCRIBE_REPO/test/fixtures/transcript.jsonl"
  [ ! -f "$TEST_HOME/claude.calls" ]
}

@test "stop hook: skips when .paused exists" {
  : > "$PROJECT_DIR/journal/.paused"
  run_hook_with "$SCRIBE_REPO/test/fixtures/transcript.jsonl"
  [ ! -f "$TEST_HOME/claude.calls" ]
}

@test "stop hook: skips when transcript is missing" {
  run_hook_with "/tmp/does-not-exist.jsonl"
  [ ! -f "$TEST_HOME/claude.calls" ]
}

@test "stop hook: skips when transcript is too small" {
  echo "tiny" > "$TEST_HOME/tiny-transcript.jsonl"
  run_hook_with "$TEST_HOME/tiny-transcript.jsonl"
  [ ! -f "$TEST_HOME/claude.calls" ]
}

@test "stop hook: spawns sub-claude when transcript is substantial" {
  run_hook_with "$SCRIBE_REPO/test/fixtures/transcript.jsonl"
  # Wait for backgrounded sub-claude to log.
  sleep 0.5
  [ -f "$TEST_HOME/claude.calls" ]
}

@test "stop hook: rate limit blocks second invocation within 5 min" {
  run_hook_with "$SCRIBE_REPO/test/fixtures/transcript.jsonl"
  sleep 0.3
  rm -f "$TEST_HOME/claude.calls"  # reset
  run_hook_with "$SCRIBE_REPO/test/fixtures/transcript.jsonl"
  sleep 0.3
  [ ! -f "$TEST_HOME/claude.calls" ]
}
```

- [ ] **Step 3: Run (failure — hook doesn't exist)**

```bash
bats test/test_stop.bats
```

- [ ] **Step 4: Implement `src/hooks/stop.sh`**

```bash
#!/bin/bash
# scribe Stop hook — end-of-session safety net.
# Spawns a sub-Claude in the background to update the journal if live writes
# missed anything. Recursion-guarded; rate-limited; never blocks the user.

set -u

SCRIBE_HOME="${SCRIBE_HOME:-$HOME/.scribe}"
LOG_GLOBAL="$SCRIBE_HOME/scribe.log"
mkdir -p "$SCRIBE_HOME" 2>/dev/null || true

log() {
  local target="${1:-}"
  shift || true
  if [ -n "$target" ] && [ -d "$(dirname "$target")" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] stop: $*" >>"$target" 2>/dev/null || true
  fi
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] stop: $*" >>"$LOG_GLOBAL" 2>/dev/null || true
}

# Recursion guard.
if [ "${CLAUDE_JOURNAL_HOOK:-0}" = "1" ]; then
  exit 0
fi

# Resolve project root.
ROOT="$PWD"
if command -v git >/dev/null 2>&1; then
  GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
  [ -n "$GIT_ROOT" ] && ROOT="$GIT_ROOT"
fi

JOURNAL="$ROOT/journal"
LOG_LOCAL="$JOURNAL/.scribe.log"
STATE_DIR="$JOURNAL/.scribe.state.d"

# Bail if not enabled or paused.
if [ ! -d "$JOURNAL" ]; then exit 0; fi
if [ -f "$JOURNAL/.paused" ]; then
  log "$LOG_LOCAL" "paused, skipping"
  exit 0
fi

# Read stdin JSON for transcript path.
STDIN_JSON=""
if [ ! -t 0 ]; then
  STDIN_JSON=$(cat || true)
fi

TRANSCRIPT=""
if [ -n "$STDIN_JSON" ]; then
  if [ -x "$SCRIBE_HOME/bin/jq" ]; then
    TRANSCRIPT=$(printf '%s' "$STDIN_JSON" | "$SCRIBE_HOME/bin/jq" -r '.transcript_path // empty' 2>/dev/null || true)
  elif command -v jq >/dev/null 2>&1; then
    TRANSCRIPT=$(printf '%s' "$STDIN_JSON" | jq -r '.transcript_path // empty' 2>/dev/null || true)
  fi
fi

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  log "$LOG_LOCAL" "no transcript path, skipping"
  exit 0
fi

# Transcript size filter (>2KB).
SIZE=$(wc -c < "$TRANSCRIPT" 2>/dev/null || echo 0)
if [ "$SIZE" -lt 2000 ]; then
  log "$LOG_LOCAL" "transcript too small ($SIZE bytes), skipping"
  exit 0
fi

# Session id derivation.
SESSION_ID=$(basename "$TRANSCRIPT" | sed 's/\.[^.]*$//')
mkdir -p "$STATE_DIR"
STATE="$STATE_DIR/$SESSION_ID"

# Rate limit: 5 minutes.
NOW=$(date +%s)
if [ -f "$STATE" ]; then
  LAST=$(cat "$STATE" 2>/dev/null || echo 0)
  if [ -n "$LAST" ] && [ "$((NOW - LAST))" -lt 300 ]; then
    log "$LOG_LOCAL" "rate-limited (${SESSION_ID}, $((NOW - LAST))s)"
    exit 0
  fi
fi

# Build sub-Claude prompt.
TODAY=$(date '+%Y-%m-%d')
LOGBOOK="$JOURNAL/logbook/${TODAY}.md"

PROMPT_FILE=$(mktemp)
cat >"$PROMPT_FILE" <<EOF
You are the journal safety net for the project at $ROOT. A Claude Code session just ended.

Your job: read the transcript at $TRANSCRIPT and ensure today's journal captures it. Then stop.

Rules:
- Today's logbook: $LOGBOOK. If it exists and already covers today's work, append only what's missing. Do not duplicate.
- If $LOGBOOK does not exist, create it with YAML frontmatter (id, type: logbook, date: $TODAY, topic, tags, status, related) and chronological prose.
- If the session produced a real architectural decision, create a numbered ADR at $JOURNAL/decisions/NNN-slug.md (Context / Decision / Why / Consequences). Only for genuine decisions, not casual discussion.
- If a durable, generalizable lesson emerged, append to $JOURNAL/lessons.md. Bar: "would someone joining in six months thank me for this?" Skip filler.
- If the session ran an experiment with hypothesis + outcome (success OR failure), create $JOURNAL/experiments/${TODAY}-slug.md.
- Update $JOURNAL/glossary.md if project-specific vocabulary emerged.
- If a recurring topic warrants its own file (e.g. bugs.md, ui.md), create or extend it at the journal root.
- Never touch $JOURNAL/.paused, $JOURNAL/.scribe.log, or $JOURNAL/.scribe.state.d/.

Read the transcript, read existing journal files as needed, then make your writes. Do not ask questions. Do not explain what you did.
EOF

# Spawn sub-Claude in background.
LOCKFILE="$LOGBOOK.lock"
mkdir -p "$(dirname "$LOCKFILE")"

(
  export CLAUDE_JOURNAL_HOOK=1
  cd "$ROOT" || exit 0
  if command -v flock >/dev/null 2>&1; then
    flock -w 120 "$LOCKFILE" bash -c '
      claude -p --permission-mode bypassPermissions < "$1" >> "$2" 2>&1 || true
    ' _ "$PROMPT_FILE" "$LOG_LOCAL" || log "$LOG_LOCAL" "sub-claude (flock) exited nonzero"
  else
    claude -p --permission-mode bypassPermissions < "$PROMPT_FILE" >> "$LOG_LOCAL" 2>&1 || log "$LOG_LOCAL" "sub-claude exited nonzero"
  fi
  rm -f "$PROMPT_FILE"
  echo "$NOW" > "$STATE" 2>/dev/null || true
) &

log "$LOG_LOCAL" "spawned sub-claude (pid $!) for session $SESSION_ID"
exit 0
```

- [ ] **Step 5: Run tests**

```bash
chmod +x src/hooks/stop.sh
bats test/test_stop.bats
```

Expected: 7 passing. (Note: rate limit test is timing-sensitive; if flaky, increase the sleep before second invocation.)

- [ ] **Step 6: Commit**

```bash
git add src/hooks/stop.sh test/test_stop.bats test/fixtures/
git commit -m "Implement Stop hook safety net with rate limit + recursion guard"
```

---

### Task 16: Templates (CLAUDE-block + journal-seed) — finalize

**Files:**
- Modify: `~/projects/scribe/src/templates/CLAUDE-block.md` (verify content from Task 5)
- Modify: `~/projects/scribe/src/templates/journal-seed/lessons.md` (verify)
- Modify: `~/projects/scribe/src/templates/journal-seed/README.md` (verify)

- [ ] **Step 1: Read each template back and verify it matches the spec**

```bash
cat src/templates/CLAUDE-block.md
cat src/templates/journal-seed/lessons.md
cat src/templates/journal-seed/README.md
```

- [ ] **Step 2: Add a smoke test that the CLAUDE block contains all required instructions**

Create `test/test_template_block.bats`:

```bash
#!/usr/bin/env bats

load helpers

@test "CLAUDE-block.md mentions paused sentinel check" {
  grep -q "journal/.paused" "$SCRIBE_REPO/src/templates/CLAUDE-block.md"
}

@test "CLAUDE-block.md mentions logbook, decisions, lessons, experiments, glossary" {
  for keyword in logbook decisions lessons experiments glossary; do
    grep -qi "$keyword" "$SCRIBE_REPO/src/templates/CLAUDE-block.md"
  done
}

@test "CLAUDE-block.md mentions YAML frontmatter convention" {
  grep -qi "frontmatter" "$SCRIBE_REPO/src/templates/CLAUDE-block.md"
}

@test "CLAUDE-block.md mentions natural-language commands" {
  grep -q "scribe pause" "$SCRIBE_REPO/src/templates/CLAUDE-block.md"
  grep -q "scribe archive" "$SCRIBE_REPO/src/templates/CLAUDE-block.md"
  grep -q "scribe link" "$SCRIBE_REPO/src/templates/CLAUDE-block.md"
}

@test "CLAUDE-block.md begins and ends with sentinels" {
  head -1 "$SCRIBE_REPO/src/templates/CLAUDE-block.md" | grep -q "scribe-block-begin"
  tail -1 "$SCRIBE_REPO/src/templates/CLAUDE-block.md" | grep -q "scribe-block-end"
}
```

- [ ] **Step 3: Run**

```bash
bats test/test_template_block.bats
```

Expected: 5 passing. If anything fails, edit the template to fix.

- [ ] **Step 4: Commit**

```bash
git add test/test_template_block.bats
git commit -m "Verify CLAUDE.md template block has required instructions"
```

---

### Task 17: Slash command files

**Files:**
- Create: `~/projects/scribe/src/commands/journal-pause.md`
- Create: `~/projects/scribe/src/commands/journal-resume.md`
- Create: `~/projects/scribe/src/commands/journal-status.md`

- [ ] **Step 1: Write `journal-pause.md`**

```markdown
---
description: Pause auto-journaling for the current project
---

Run `scribe pause` in the project root to create the `journal/.paused` sentinel. After this command runs, do not write anything to `journal/` for the rest of this session unless `scribe resume` is run.

Confirm to the user: "Journaling paused. Run /journal-resume (or say 'resume journaling') to turn it back on."
```

- [ ] **Step 2: Write `journal-resume.md`**

```markdown
---
description: Resume auto-journaling for the current project
---

Run `scribe resume` in the project root to remove the `journal/.paused` sentinel. After this command runs, journal writes resume immediately.

Confirm to the user: "Journaling resumed."
```

- [ ] **Step 3: Write `journal-status.md`**

```markdown
---
description: Report whether auto-journaling is active for the current project
---

Run `scribe status` in the project root and relay the output to the user in plain English. The status will be one of: active, paused, declined, not-initialized.
```

- [ ] **Step 4: Commit**

```bash
git add src/commands/
git commit -m "Add slash command markdown files"
```

---

### Task 18: Acquire jq binaries

**Files:**
- Create: `~/projects/scribe/src/installer/jq-binaries/jq-macos-arm64`
- Create: `~/projects/scribe/src/installer/jq-binaries/jq-macos-x86_64`
- Create: `~/projects/scribe/src/installer/jq-binaries/jq-linux-x86_64`
- Create: `~/projects/scribe/src/installer/jq-binaries/jq-linux-arm64`
- Create: `~/projects/scribe/src/installer/jq-binaries/CHECKSUMS`
- Create: `~/projects/scribe/src/installer/jq-binaries/LICENSE-jq`

- [ ] **Step 1: Download jq 1.7.1 binaries**

```bash
cd ~/projects/scribe/src/installer/jq-binaries

# macOS arm64
curl -fsSL -o jq-macos-arm64 "https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-macos-arm64"
# macOS x86_64
curl -fsSL -o jq-macos-x86_64 "https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-macos-amd64"
# Linux x86_64
curl -fsSL -o jq-linux-x86_64 "https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64"
# Linux arm64
curl -fsSL -o jq-linux-arm64 "https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-arm64"

chmod +x jq-*
```

- [ ] **Step 2: Generate checksums**

```bash
cd ~/projects/scribe/src/installer/jq-binaries
shasum -a 256 jq-* > CHECKSUMS
cat CHECKSUMS
```

Expected: 4 lines of `<sha256>  jq-<platform>`. Save these to verify against the official jq releases page.

- [ ] **Step 3: Add jq's MIT license**

```bash
curl -fsSL -o LICENSE-jq "https://raw.githubusercontent.com/jqlang/jq/master/COPYING"
```

- [ ] **Step 4: Verify each binary works**

```bash
# Pick the binary matching the current host and run a quick test.
case "$(uname -sm)" in
  "Darwin arm64") TEST_BIN=jq-macos-arm64 ;;
  "Darwin x86_64") TEST_BIN=jq-macos-x86_64 ;;
  "Linux x86_64") TEST_BIN=jq-linux-x86_64 ;;
  "Linux aarch64"|"Linux arm64") TEST_BIN=jq-linux-arm64 ;;
  *) echo "Unsupported test platform; skip"; TEST_BIN= ;;
esac
[ -n "$TEST_BIN" ] && echo '{"foo":"bar"}' | "./$TEST_BIN" '.foo'
```

Expected: `"bar"` for the platform's binary.

- [ ] **Step 5: Commit (binaries + license + checksums)**

```bash
git add src/installer/jq-binaries/
git commit -m "Bundle jq 1.7.1 static binaries for macOS and Linux"
```

---

### Task 19: Installer template

**Files:**
- Create: `~/projects/scribe/src/installer/installer-template.sh`
- Create: `~/projects/scribe/test/test_installer.bats`

- [ ] **Step 1: Write `installer-template.sh`**

The build will substitute `__PAYLOAD__` with a base64-encoded tarball of `src/` (minus `installer/jq-binaries/`), and `__JQ_<PLATFORM>__` placeholders with each base64-encoded jq binary.

```bash
#!/bin/bash
# scribe self-extracting installer.
# Generated by build.sh from src/. Do not edit by hand.

set -u

SCRIBE_VERSION="__VERSION__"
SCRIBE_HOME="$HOME/.scribe"
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
COMMANDS_DIR="$CLAUDE_DIR/commands"

red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m\n' "$*"; }

err() { red "scribe: $*" >&2; exit 1; }

bold "Welcome to scribe."
echo

# 1. Pre-flight checks.
case "$(uname -s)" in
  Darwin) PLATFORM="macos" ;;
  Linux)
    if [ -f /proc/version ] && grep -qi microsoft /proc/version; then
      PLATFORM="wsl"
    else
      PLATFORM="linux"
    fi
    ;;
  *) err "Unsupported OS: $(uname -s). scribe supports macOS and Linux." ;;
esac

case "$(uname -m)" in
  arm64|aarch64) ARCH="arm64" ;;
  x86_64|amd64)  ARCH="x86_64" ;;
  *) err "Unsupported architecture: $(uname -m)." ;;
esac

if [ "$PLATFORM" = "wsl" ]; then PLATFORM="linux"; fi
echo "  ✓ Detected $PLATFORM ($ARCH)"

if ! command -v claude >/dev/null 2>&1; then
  red "  ✗ Claude Code is not installed."
  echo
  echo "Install it from https://claude.com/claude-code, then re-run this script."
  exit 1
fi
echo "  ✓ Found Claude Code"

if [ ! -d "$HOME" ] || [ ! -w "$HOME" ]; then
  err "Cannot write to home directory $HOME."
fi

# 2. Extract files.
TMP=$(mktemp -d "${TMPDIR:-/tmp}/scribe-install.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

# Decode the source payload.
echo "__PAYLOAD_BEGIN__" > /dev/null
PAYLOAD_B64=$(awk '/^__PAYLOAD_BEGIN__$/{flag=1; next} /^__PAYLOAD_END__$/{flag=0} flag' "$0")
echo "$PAYLOAD_B64" | base64 -d | tar xzf - -C "$TMP"

# Decode the right jq binary.
case "$PLATFORM-$ARCH" in
  macos-arm64)  JQ_KEY="JQ_MACOS_ARM64" ;;
  macos-x86_64) JQ_KEY="JQ_MACOS_X86_64" ;;
  linux-x86_64) JQ_KEY="JQ_LINUX_X86_64" ;;
  linux-arm64)  JQ_KEY="JQ_LINUX_ARM64" ;;
esac

JQ_B64=$(awk -v k="__${JQ_KEY}_BEGIN__" -v k2="__${JQ_KEY}_END__" '
  $0==k {flag=1; next} $0==k2 {flag=0} flag' "$0")
mkdir -p "$SCRIBE_HOME/bin"
echo "$JQ_B64" | base64 -d > "$SCRIBE_HOME/bin/jq"
chmod +x "$SCRIBE_HOME/bin/jq"
xattr -d com.apple.quarantine "$SCRIBE_HOME/bin/jq" 2>/dev/null || true

# 3. Move source files into place.
mkdir -p "$SCRIBE_HOME"/{hooks,templates,library}
cp "$TMP/src/bin/scribe" "$SCRIBE_HOME/bin/scribe"
chmod +x "$SCRIBE_HOME/bin/scribe"
cp "$TMP/src/hooks/"*.sh "$SCRIBE_HOME/hooks/"
chmod +x "$SCRIBE_HOME/hooks/"*.sh
cp -R "$TMP/src/templates/." "$SCRIBE_HOME/templates/"
cp "$TMP/src/installer/uninstall.sh" "$SCRIBE_HOME/uninstall.sh"
chmod +x "$SCRIBE_HOME/uninstall.sh"
echo "$SCRIBE_VERSION" > "$SCRIBE_HOME/VERSION"
echo "  ✓ Installed scribe to $SCRIBE_HOME"

# 4. Wire hooks into Claude Code via jq merge.
mkdir -p "$CLAUDE_DIR" "$COMMANDS_DIR"
JQ="$SCRIBE_HOME/bin/jq"

if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
fi

# Build the hooks blob.
SS_HOOK="$SCRIBE_HOME/hooks/session-start.sh"
ST_HOOK="$SCRIBE_HOME/hooks/stop.sh"

UPDATED=$("$JQ" \
  --arg ss "$SS_HOOK" \
  --arg st "$ST_HOOK" \
  '
  .hooks //= {}
  | .hooks.SessionStart //= []
  | .hooks.Stop //= []
  | .hooks.SessionStart |= map(select(.scribe != true))
  | .hooks.Stop |= map(select(.scribe != true))
  | .hooks.SessionStart += [{"scribe": true, "hooks": [{"type": "command", "command": $ss}]}]
  | .hooks.Stop += [{"scribe": true, "hooks": [{"type": "command", "command": $st}]}]
  ' "$SETTINGS")
echo "$UPDATED" > "$SETTINGS"
echo "  ✓ Wired hooks into $SETTINGS"

# 5. Install slash commands.
cp "$TMP/src/commands/"*.md "$COMMANDS_DIR/"
echo "  ✓ Installed slash commands to $COMMANDS_DIR"

# 6. Add to PATH.
RC=""
case "${SHELL:-}" in
  */zsh) RC="$HOME/.zshrc" ;;
  */bash) RC="$HOME/.bashrc" ;;
esac

if [ -n "$RC" ]; then
  PATH_LINE='export PATH="$HOME/.scribe/bin:$PATH"'
  if [ ! -f "$RC" ] || ! grep -qF "$PATH_LINE" "$RC"; then
    echo "" >> "$RC"
    echo "# scribe" >> "$RC"
    echo "$PATH_LINE" >> "$RC"
    echo "  ✓ Added scribe to your PATH ($RC)"
  else
    echo "  ✓ scribe already in PATH ($RC)"
  fi
fi

echo
green "Done."
echo
echo "What's next:"
echo "  1. Open Claude Code in any project (cd into your project, run \"claude\")."
echo "  2. Claude will ask once if you want to turn on auto-journaling there."
echo "  3. Say yes to enable, no to skip, \"not now\" to be asked again later."
echo
echo "To remove scribe later:"
echo "  bash ~/.scribe/uninstall.sh"
echo

exit 0

# Embedded payloads follow. Do not modify.
__PAYLOAD_BEGIN__
__PAYLOAD__
__PAYLOAD_END__
__JQ_MACOS_ARM64_BEGIN__
__JQ_MACOS_ARM64__
__JQ_MACOS_ARM64_END__
__JQ_MACOS_X86_64_BEGIN__
__JQ_MACOS_X86_64__
__JQ_MACOS_X86_64_END__
__JQ_LINUX_X86_64_BEGIN__
__JQ_LINUX_X86_64__
__JQ_LINUX_X86_64_END__
__JQ_LINUX_ARM64_BEGIN__
__JQ_LINUX_ARM64__
__JQ_LINUX_ARM64_END__
```

- [ ] **Step 2: Commit**

```bash
git add src/installer/installer-template.sh
git commit -m "Add self-extracting installer template"
```

(Tests for the installer come together with the build script in Task 21.)

---

### Task 20: Uninstaller

**Files:**
- Create: `~/projects/scribe/src/installer/uninstall.sh`

- [ ] **Step 1: Write the uninstaller**

```bash
#!/bin/bash
# scribe uninstaller. Idempotent and offline.

set -u

SCRIBE_HOME="$HOME/.scribe"
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
COMMANDS_DIR="$CLAUDE_DIR/commands"

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }

bold "Removing scribe..."
echo

# 1. Strip scribe entries from settings.json.
if [ -f "$SETTINGS" ]; then
  JQ=""
  if [ -x "$SCRIBE_HOME/bin/jq" ]; then JQ="$SCRIBE_HOME/bin/jq"
  elif command -v jq >/dev/null 2>&1; then JQ=jq; fi

  if [ -n "$JQ" ]; then
    UPDATED=$("$JQ" '
      if .hooks then
        .hooks.SessionStart? |= ((. // []) | map(select(.scribe != true))) |
        .hooks.Stop?         |= ((. // []) | map(select(.scribe != true)))
      else . end
    ' "$SETTINGS")
    echo "$UPDATED" > "$SETTINGS"
  fi
  echo "  ✓ Unwired from Claude Code"
fi

# 2. Remove slash commands.
for f in journal-pause.md journal-resume.md journal-status.md; do
  rm -f "$COMMANDS_DIR/$f"
done
echo "  ✓ Removed slash commands"

# 3. Remove PATH line from shell rc.
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  [ -f "$rc" ] || continue
  if grep -q '\.scribe/bin' "$rc"; then
    awk '/# scribe/{skip=1; next} skip && /^export PATH=.*\.scribe\/bin/{skip=0; next} {print}' "$rc" > "$rc.tmp" && mv "$rc.tmp" "$rc"
    # Trim trailing blank line if any.
    awk 'NR==FNR{if(NF)last=NR; next} FNR<=last' "$rc" "$rc" > "$rc.tmp" && mv "$rc.tmp" "$rc"
  fi
done

# 4. Ask about library.
KEEP_LIBRARY=1
if [ -d "$SCRIBE_HOME/library" ]; then
  COUNT=$(ls -1 "$SCRIBE_HOME/library"/*.md 2>/dev/null | wc -l | tr -d ' ')
  if [ "$COUNT" -gt 0 ]; then
    printf "You have %s archived past-project journal(s) at ~/.scribe/library/. Remove them too? (y/N) " "$COUNT"
    read -r reply
    case "$reply" in
      y|Y|yes|YES) KEEP_LIBRARY=0 ;;
    esac
  fi
fi

# 5. Remove ~/.scribe (preserving library if requested).
if [ -d "$SCRIBE_HOME" ]; then
  if [ "$KEEP_LIBRARY" -eq 1 ] && [ -d "$SCRIBE_HOME/library" ]; then
    # Remove everything except library/.
    find "$SCRIBE_HOME" -mindepth 1 -maxdepth 1 ! -name library -exec rm -rf {} +
    echo "  ✓ Removed ~/.scribe (library kept)"
  else
    rm -rf "$SCRIBE_HOME"
    echo "  ✓ Removed ~/.scribe"
  fi
fi

echo
green "Done. scribe has been uninstalled."
echo
echo "Note: active project journals (./journal/ folders inside your projects) are"
echo "untouched. To remove journaling from a specific project, ask Claude in that"
echo "project: \"turn off journaling here\"."
echo
```

- [ ] **Step 2: Commit**

```bash
chmod +x src/installer/uninstall.sh
git add src/installer/uninstall.sh
git commit -m "Add offline uninstaller"
```

---

### Task 21: Build script + installer integration tests

**Files:**
- Create: `~/projects/scribe/build.sh`
- Modify: `~/projects/scribe/test/test_installer.bats`

- [ ] **Step 1: Write `build.sh`**

```bash
#!/bin/bash
# Build script: assembles dist/scribe-installer.sh from src/.
set -eu

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/src"
DIST="$ROOT/dist"
TEMPLATE="$SRC/installer/installer-template.sh"
JQ_DIR="$SRC/installer/jq-binaries"
VERSION="$(cat "$ROOT/VERSION")"

mkdir -p "$DIST"

# 1. Bundle src/ (minus jq-binaries) into a tarball, then base64-encode.
PAYLOAD_TAR="$(mktemp)"
tar czf "$PAYLOAD_TAR" -C "$ROOT" \
  src/bin src/hooks src/commands src/templates src/installer/uninstall.sh
PAYLOAD_B64=$(base64 < "$PAYLOAD_TAR")

# 2. Base64-encode each jq binary.
JQ_MACOS_ARM64=$(base64 < "$JQ_DIR/jq-macos-arm64")
JQ_MACOS_X86_64=$(base64 < "$JQ_DIR/jq-macos-x86_64")
JQ_LINUX_X86_64=$(base64 < "$JQ_DIR/jq-linux-x86_64")
JQ_LINUX_ARM64=$(base64 < "$JQ_DIR/jq-linux-arm64")

# 3. Substitute placeholders in the template.
OUT="$DIST/scribe-installer.sh"

# Use awk for safe substitution (no shell-injection from base64 content).
awk -v ver="$VERSION" \
    -v payload_file="$PAYLOAD_TAR" \
    -v ma_file="$JQ_DIR/jq-macos-arm64.b64" \
    -v mx_file="$JQ_DIR/jq-macos-x86_64.b64" \
    -v lx_file="$JQ_DIR/jq-linux-x86_64.b64" \
    -v la_file="$JQ_DIR/jq-linux-arm64.b64" \
    'BEGIN{
        cmd_pl="base64 < \"" payload_file "\""; pl=""
        while ((cmd_pl|getline l)>0) pl = pl l "\n"
        close(cmd_pl)
     }
     {
        gsub(/__VERSION__/, ver)
        if ($0 == "__PAYLOAD__") { printf "%s", pl; next }
        print
     }' "$TEMPLATE" > "$OUT.partial"

# Now substitute jq blocks. Easier with sed-friendly token replacements per line.
python3 - "$OUT.partial" "$OUT" \
  "$JQ_DIR/jq-macos-arm64" \
  "$JQ_DIR/jq-macos-x86_64" \
  "$JQ_DIR/jq-linux-x86_64" \
  "$JQ_DIR/jq-linux-arm64" <<'PY'
import sys, base64

partial, out_path, ma, mx, lx, la = sys.argv[1:7]
with open(partial) as f:
    text = f.read()

def b64(p):
    with open(p, 'rb') as f:
        return base64.b64encode(f.read()).decode() + "\n"

text = text.replace("__JQ_MACOS_ARM64__",  b64(ma))
text = text.replace("__JQ_MACOS_X86_64__", b64(mx))
text = text.replace("__JQ_LINUX_X86_64__", b64(lx))
text = text.replace("__JQ_LINUX_ARM64__",  b64(la))

with open(out_path, 'w') as f:
    f.write(text)
PY

rm -f "$OUT.partial" "$PAYLOAD_TAR"

chmod +x "$OUT"

SIZE_KB=$(($(wc -c < "$OUT") / 1024))
echo "Built $OUT ($SIZE_KB KB)"
```

(Note: this uses Python 3 for safe binary base64 substitution because awk/sed can't handle multi-MB binary payloads cleanly. Python 3 is universally present on macOS and Linux.)

- [ ] **Step 2: Run the build**

```bash
cd ~/projects/scribe
chmod +x build.sh
./build.sh
ls -lh dist/scribe-installer.sh
```

Expected: `dist/scribe-installer.sh` exists, ~5–15 MB.

- [ ] **Step 3: Write installer integration tests**

```bash
cat > test/test_installer.bats <<'BATS'
#!/usr/bin/env bats

load helpers

setup() { setup_isolated_env; }
teardown() { teardown_isolated_env; }

@test "installer extracts to ~/.scribe with expected files" {
  install_fake_claude
  bash "$SCRIBE_REPO/dist/scribe-installer.sh" >/dev/null

  [ -f "$HOME/.scribe/bin/scribe" ]
  [ -x "$HOME/.scribe/bin/scribe" ]
  [ -x "$HOME/.scribe/bin/jq" ]
  [ -f "$HOME/.scribe/hooks/session-start.sh" ]
  [ -f "$HOME/.scribe/hooks/stop.sh" ]
  [ -f "$HOME/.scribe/templates/CLAUDE-block.md" ]
  [ -f "$HOME/.scribe/uninstall.sh" ]
  [ -f "$HOME/.scribe/VERSION" ]
}

@test "installer wires hooks into ~/.claude/settings.json" {
  install_fake_claude
  bash "$SCRIBE_REPO/dist/scribe-installer.sh" >/dev/null

  [ -f "$HOME/.claude/settings.json" ]
  grep -q "scribe" "$HOME/.claude/settings.json"
  grep -q "session-start.sh" "$HOME/.claude/settings.json"
  grep -q "stop.sh" "$HOME/.claude/settings.json"
}

@test "installer copies slash command files" {
  install_fake_claude
  bash "$SCRIBE_REPO/dist/scribe-installer.sh" >/dev/null

  [ -f "$HOME/.claude/commands/journal-pause.md" ]
  [ -f "$HOME/.claude/commands/journal-resume.md" ]
  [ -f "$HOME/.claude/commands/journal-status.md" ]
}

@test "installer is idempotent — second run does not duplicate hooks" {
  install_fake_claude
  bash "$SCRIBE_REPO/dist/scribe-installer.sh" >/dev/null
  bash "$SCRIBE_REPO/dist/scribe-installer.sh" >/dev/null

  count=$(grep -c '"scribe": true' "$HOME/.claude/settings.json")
  [ "$count" -eq 2 ]   # one for SessionStart, one for Stop, no duplicates
}

@test "installer fails clearly when claude is missing" {
  # No fake claude installed.
  export PATH="/usr/bin:/bin"
  run bash "$SCRIBE_REPO/dist/scribe-installer.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Claude Code"* ]]
}

@test "installer adds PATH line to .zshrc" {
  install_fake_claude
  export SHELL=/bin/zsh
  bash "$SCRIBE_REPO/dist/scribe-installer.sh" >/dev/null

  [ -f "$HOME/.zshrc" ]
  grep -q "\.scribe/bin" "$HOME/.zshrc"
}

@test "uninstaller cleanly reverses the install" {
  install_fake_claude
  bash "$SCRIBE_REPO/dist/scribe-installer.sh" >/dev/null

  # Sanity
  [ -f "$HOME/.scribe/uninstall.sh" ]
  printf 'n\n' | bash "$HOME/.scribe/uninstall.sh" >/dev/null

  [ ! -f "$HOME/.scribe/bin/scribe" ]
  [ ! -f "$HOME/.claude/commands/journal-pause.md" ]
  ! grep -q '"scribe": true' "$HOME/.claude/settings.json"
}
BATS
```

- [ ] **Step 4: Run installer tests**

```bash
bats test/test_installer.bats
```

Expected: 7 passing.

- [ ] **Step 5: Commit**

```bash
git add build.sh test/test_installer.bats
git commit -m "Add build script + end-to-end installer tests"
```

---

### Task 22: Manual end-to-end smoke test

**Files:**
- Create: `~/projects/scribe/test/SMOKE-TEST.md` (a manual checklist)

- [ ] **Step 1: Write the manual smoke test checklist**

```markdown
# scribe Manual Smoke Test

Run on a Mac (and once on Linux if available). This is the test plan from the design spec, executed by hand.

## Prerequisites
- A clean home directory (or a test machine).
- Claude Code installed and on PATH.
- A test project: `mkdir -p /tmp/scribe-smoke && cd /tmp/scribe-smoke`.

## Steps

1. **Install.** Run `bash ~/projects/scribe/dist/scribe-installer.sh`. Confirm friendly output and no prompts.
2. **doctor.** Run `~/.scribe/bin/scribe doctor`. Should report all green.
3. **Bootstrap prompt.** `cd /tmp/scribe-smoke; claude`. Within Claude's first response, it should ask about enabling journaling.
4. **Yes path.** Answer "yes". Confirm `journal/`, `.gitignore` line, and `CLAUDE.md` block all appear. Claude acknowledges.
5. **Live writing.** Have a real session — discuss a small architectural choice. Close the session. Open `journal/logbook/<today>.md`. Confirm it has prose. Open `journal/decisions/001-*.md` if a decision was made.
6. **Re-open.** `claude` again in the same project. Confirm the SessionStart context contains the latest log entry and lessons.
7. **Pause.** Tell Claude "pause journaling". Confirm `journal/.paused` exists. Do work; close. Confirm no new entries appeared.
8. **Resume.** Tell Claude "resume journaling". Confirm sentinel removed.
9. **Read on behalf.** Ask Claude "what did we decide?" Confirm Claude reads `decisions/` and replies in chat.
10. **Archive.** Tell Claude "archive this project". Confirm a `<project>_archive.md` appears on the desktop. Open it; confirm sections look right.
11. **Library.** Confirm an identical copy lands in `~/.scribe/library/`.
12. **Cross-project recall.** Make a second project, `scribe init`, ask Claude "have we made decisions about X before?" where X is in the archived project. Confirm Claude finds the excerpt.
13. **Link.** In the second project, tell Claude "use <first-project> as background context". Confirm `journal/.imports.txt` updated. Re-open the session and confirm imported summary + lessons appear in SessionStart context.
14. **Off.** Tell Claude "turn off journaling here" in one project. Answer the confirmation. Confirm the journal directory and CLAUDE.md block are gone.
15. **Decline path.** Make a fresh project. Answer "no" to the consent prompt. Confirm `.scribe-declined` is created. Re-open Claude; confirm no consent prompt re-fires.
16. **Not-now path.** Make a fresh project. Answer "not now". Confirm no marker; the prompt re-fires next session.
17. **Uninstall.** `bash ~/.scribe/uninstall.sh`. Confirm settings cleaned, slash commands removed, PATH line removed, library prompt defaulted to No.
18. **Re-install after uninstall.** Run installer again. Confirm clean re-install.
19. **Restricted-environment dry-run.** Disconnect network *after* downloading installer. Run install. Confirm success.

Record results in this file as you go.
```

- [ ] **Step 2: Run through the smoke test on the development machine**

Execute steps 1–18 manually. Step 19 requires a real disconnect, so do it last. Mark each step pass/fail in SMOKE-TEST.md.

- [ ] **Step 3: Fix any issues found**

For any failures, file them as bugs and patch in subsequent commits before tagging the release.

- [ ] **Step 4: Commit the smoke test record**

```bash
git add test/SMOKE-TEST.md
git commit -m "Add manual smoke test plan and record results"
```

---

### Task 23: Final cleanup, tag, and (optional) push

**Files:**
- Modify: `~/projects/scribe/README.md`

- [ ] **Step 1: Flesh out README with full usage**

Update `README.md` to include:
- Install (browser-download path is primary; curl path is the alternative).
- What it does in 3-4 sentences.
- A short "How to use" section.
- Uninstall.
- Link to the design spec.

(Concrete content is already drafted in Task 2; expand as needed based on what was learned during smoke testing.)

- [ ] **Step 2: Tag the release**

```bash
cd ~/projects/scribe
git tag -a v0.1.0 -m "Initial release: scribe v0.1.0"
git log --oneline | head -25  # sanity check on history
```

- [ ] **Step 3: (Optional) Create remote repo and push**

```bash
gh repo create <org>/scribe --private --source=. --remote=origin --push
git push origin v0.1.0
gh release create v0.1.0 dist/scribe-installer.sh --title "v0.1.0" --notes "Initial release."
```

If the user prefers public, swap `--private` for `--public`.

- [ ] **Step 4: Final commit (cleanup if needed)**

```bash
git add -A
git commit -m "Finalize README and release notes" || true
```

---

## Self-review notes

**Spec coverage:**
- All 23 listed sections of the spec map to a task.
- No gaps identified.

**Placeholder scan:**
- No "TBD" / "TODO" / "implement later" entries in steps.
- The installer template uses literal placeholders (`__VERSION__`, `__PAYLOAD__`, `__JQ_*__`) but these are intentional — Task 21's build.sh substitutes them.

**Type / signature consistency:**
- Sanitization helper is `__sanitize`; used consistently across `cmd_archive`, `cmd_link`, `cmd_unlink`.
- Desktop helper is `__desktop_path`; used by `cmd_archive`.
- Recursion guard env var is `CLAUDE_JOURNAL_HOOK=1` everywhere.
- Pause sentinel path is `journal/.paused` everywhere.
- Decline marker path is `.scribe-declined` (project-root-relative) everywhere.

**Risks called out:**
- Task 15 (Stop hook) tests time-sleep on background sub-Claude — flaky if machine is slow. Adjust sleep upward if needed.
- Task 21 build uses Python 3 for binary base64 substitution. Universal on macOS/Linux but document this in build.sh.
- Task 18 jq binaries: must keep CHECKSUMS in sync if jq version is bumped.

---

## Execution Handoff

Plan complete and saved to `~/.claude/plans/2026-05-03-scribe-implementation.md` (will move into the repo at `docs/superpowers/plans/2026-05-03-scribe-implementation.md` as part of Task 1).

Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration with low context churn.

**2. Inline Execution** — I execute tasks in this session using executing-plans, batch with checkpoints.

Which approach?
