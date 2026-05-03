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
  # Save PATH so we can restore it before bats teardown.
  local saved_path="$PATH"

  mkdir -p "$TEST_HOME/onlypath"
  ln -s "$(command -v bash)" "$TEST_HOME/onlypath/bash"

  PATH="$TEST_HOME/onlypath" run "$SCRIBE_BIN" __desktop_path

  # Restore PATH so teardown can find rm, etc.
  export PATH="$saved_path"

  [ "$status" -eq 0 ]
  # The fallback prints the path on stdout and a warning on stderr; bats's `run`
  # merges them into $output, so check the first line.
  [ "${lines[0]}" = "$HOME" ]
}
