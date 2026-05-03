#!/usr/bin/env bats

load helpers

setup() {
  setup_isolated_env
  install_fake_claude
  # Override desktop to a known fixture path so we can assert on it.
  mkdir -p "$TEST_HOME/Desktop"

  "$SCRIBE_BIN" init

  # Seed some content.
  cat >"$PROJECT_DIR/journal/logbook/2026-04-30.md" <<EOF
---
id: log-2026-04-30
type: logbook
date: 2026-04-30
---
# 2026-04-30
First session content.
EOF

  cat >"$PROJECT_DIR/journal/decisions/001-foo.md" <<EOF
---
id: decision-001-foo
type: decision
---
# 001 — Pick foo
Decided to pick foo.
EOF

  # Configure fake claude to write a fake summary into a known temp file.
  cat >"$TEST_HOME/fakebin/claude" <<'FAKE'
#!/bin/bash
# Read prompt from stdin so the test can inspect it.
cat > "$TEST_HOME/claude.stdin"
# Write the simulated summary to the path the prompt requests.
# The archive command tells us via env where the summary tempfile is.
if [ -n "${SCRIBE_FAKE_SUMMARY_PATH:-}" ]; then
  printf '%s\n' "Fake one-screen summary of the project. ~300 words placeholder." > "$SCRIBE_FAKE_SUMMARY_PATH"
fi
exit 0
FAKE
  chmod +x "$TEST_HOME/fakebin/claude"
}

teardown() { teardown_isolated_env; }

@test "scribe archive refuses when journal/ is empty" {
  rm -rf "$PROJECT_DIR/journal"
  run "$SCRIBE_BIN" archive
  [ "$status" -ne 0 ]
  [[ "$output" == *"nothing to archive"* ]]
}

@test "scribe archive writes to desktop and library" {
  run "$SCRIBE_BIN" archive
  [ "$status" -eq 0 ]
  local desktop="$HOME/Desktop"
  local proj="$(basename "$PROJECT_DIR")"
  [ -f "$desktop/${proj}_archive.md" ]
  [ -f "$HOME/.scribe/library/${proj}_archive.md" ]
}

@test "scribe archive output contains required sections" {
  "$SCRIBE_BIN" archive
  local desktop="$HOME/Desktop"
  local proj="$(basename "$PROJECT_DIR")"
  local f="$desktop/${proj}_archive.md"

  grep -q "^## Summary" "$f"
  grep -q "^## Lessons learned" "$f"
  grep -q "^## Decisions" "$f"
  grep -q "001 — Pick foo" "$f"
}

@test "scribe archive frontmatter has project + archived date" {
  "$SCRIBE_BIN" archive
  local desktop="$HOME/Desktop"
  local proj="$(basename "$PROJECT_DIR")"
  local f="$desktop/${proj}_archive.md"

  grep -q "^project:" "$f"
  grep -q "^archived: $(date '+%Y-%m-%d')" "$f"
}

@test "scribe archive is idempotent (rerun refreshes both copies)" {
  "$SCRIBE_BIN" archive
  local desktop="$HOME/Desktop"
  local proj="$(basename "$PROJECT_DIR")"
  local first_size
  first_size=$(wc -c < "$desktop/${proj}_archive.md")

  # Add new content, rerun.
  cat >"$PROJECT_DIR/journal/decisions/002-bar.md" <<EOF
---
id: decision-002-bar
type: decision
---
# 002 — Pick bar
EOF
  "$SCRIBE_BIN" archive
  local second_size
  second_size=$(wc -c < "$desktop/${proj}_archive.md")
  [ "$second_size" -gt "$first_size" ]
  grep -q "002 — Pick bar" "$desktop/${proj}_archive.md"
}
