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
  sleep 1
  [ -f "$TEST_HOME/claude.calls" ]
}

@test "stop hook: rate limit blocks second invocation within 5 min" {
  run_hook_with "$SCRIBE_REPO/test/fixtures/transcript.jsonl"
  sleep 1
  rm -f "$TEST_HOME/claude.calls"  # reset
  run_hook_with "$SCRIBE_REPO/test/fixtures/transcript.jsonl"
  sleep 0.5
  [ ! -f "$TEST_HOME/claude.calls" ]
}
