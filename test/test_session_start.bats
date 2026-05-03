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

@test "session-start: bootstrap prompt when no journal and no decline marker" {
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
