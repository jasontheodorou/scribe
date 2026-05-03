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
  read -r -d '' CTX <<EOF || true
Scribe is installed on this machine but not yet enabled for this project ($ROOT).

On your next response to the user, ask once whether they want to turn on auto-journaling for this project. Suggested phrasing: "You have scribe installed — want me to turn on auto-journaling for this project? (yes / no / not now)".

- If yes: run \`scribe init\` (via Bash).
- If no: run \`scribe init --decline\` (creates a marker so this prompt won't fire again).
- If "not now" or unclear: don't do anything; the prompt will re-fire next session.

Do not ask again later in this session if the user already answered.
EOF
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
    archive="$HOME/.scribe/library/${imp}_archive.md"
    [ -f "$archive" ] || continue
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
