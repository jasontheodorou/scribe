#!/usr/bin/env bash
# Shared test helpers. Each test gets an isolated fake $HOME at $TEST_HOME so
# we never touch the real ~/.scribe or ~/.claude during tests.

# Path to the source tree (set per repo root, computed once).
SCRIBE_REPO="${SCRIBE_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Set up an isolated environment for one test. Call from setup() in a .bats file.
setup_isolated_env() {
  TEST_HOME="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/scribe-test.XXXXXX")" && pwd)"
  export HOME="$TEST_HOME"
  export TEST_HOME

  # Project-under-test root (a fake project directory inside TEST_HOME).
  PROJECT_DIR="$TEST_HOME/test-project"
  mkdir -p "$PROJECT_DIR"
  export PROJECT_DIR

  # Path to the scribe binary we're testing (source-tree copy).
  SCRIBE_BIN="$SCRIBE_REPO/src/bin/scribe"
  [ -f "$SCRIBE_BIN" ] && chmod +x "$SCRIBE_BIN" || true
  export SCRIBE_BIN

  # Templates path — the scribe CLI normally reads from ~/.scribe/templates,
  # but for source-tree tests we point it at src/templates/ via env.
  export SCRIBE_TEMPLATES_DIR="$SCRIBE_REPO/src/templates"

  # Library path inside the isolated home.
  export SCRIBE_LIBRARY_DIR="$TEST_HOME/.scribe/library"
  mkdir -p "$SCRIBE_LIBRARY_DIR"

  cd "$PROJECT_DIR"
}

# Tear down the isolated environment.
teardown_isolated_env() {
  if [ -n "${TEST_HOME:-}" ] && [ -d "$TEST_HOME" ]; then
    rm -rf "$TEST_HOME"
  fi
}

# Install a fake `claude` CLI on PATH that captures invocations to a log.
install_fake_claude() {
  local fakedir="$TEST_HOME/fakebin"
  mkdir -p "$fakedir"
  cat >"$fakedir/claude" <<'FAKE'
#!/bin/bash
echo "$@" >> "$TEST_HOME/claude.calls"
cat >> "$TEST_HOME/claude.stdin" 2>/dev/null || true
exit 0
FAKE
  chmod +x "$fakedir/claude"
  export PATH="$fakedir:$PATH"
}

# Install a fake `xdg-user-dir` that returns a configured path.
install_fake_xdg() {
  local fakedir="$TEST_HOME/fakebin"
  mkdir -p "$fakedir"
  cat >"$fakedir/xdg-user-dir" <<'FAKE'
#!/bin/bash
echo "$1"
FAKE
  chmod +x "$fakedir/xdg-user-dir"
  export PATH="$fakedir:$PATH"
}

# Make the journal/ directory inside PROJECT_DIR with seeds (no CLAUDE.md edit).
seed_journal() {
  mkdir -p "$PROJECT_DIR/journal/logbook" "$PROJECT_DIR/journal/decisions" "$PROJECT_DIR/journal/experiments"
  touch "$PROJECT_DIR/journal/logbook/.keep" "$PROJECT_DIR/journal/decisions/.keep" "$PROJECT_DIR/journal/experiments/.keep"
  cat >"$PROJECT_DIR/journal/lessons.md" <<EOF
---
id: lessons
type: manual
---

# Lessons
EOF
}
