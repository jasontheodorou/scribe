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
