#!/usr/bin/env bats

load helpers

setup() { setup_isolated_env; }
teardown() { teardown_isolated_env; }

@test "scribe doctor reports missing install when ~/.scribe is absent" {
  rm -rf "$HOME/.scribe"
  run "$SCRIBE_BIN" doctor
  [[ "$output" == *"~/.scribe"* ]]
  [[ "$output" == *"missing"* ]] || [[ "$output" == *"not found"* ]]
}

@test "scribe doctor reports missing claude CLI" {
  # Strip claude from PATH.
  saved="$PATH"
  export PATH="/usr/bin:/bin"
  run "$SCRIBE_BIN" doctor
  export PATH="$saved"
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
