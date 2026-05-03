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
