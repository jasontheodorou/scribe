#!/usr/bin/env bats

load helpers

setup() {
  setup_isolated_env
}

teardown() {
  teardown_isolated_env
}

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
