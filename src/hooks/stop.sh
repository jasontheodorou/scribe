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
