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
  [ "$(cd "$PROJECT_DIR" && pwd)" = "$(pwd)" ]
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
  printf "test prompt" | claude -p arg1
  [ -s "$TEST_HOME/claude.calls" ]
  [ -s "$TEST_HOME/claude.stdin" ]
}
