#!/usr/bin/env bats

load helpers

setup() {
  setup_isolated_env
  "$SCRIBE_BIN" init

  # Seed the library with a fake archived project.
  mkdir -p "$HOME/.scribe/library"
  cat >"$HOME/.scribe/library/foo_archive.md" <<EOF
---
project: foo
archived: 2026-04-01
---
# foo

## Summary
Foo summary content.

## Lessons learned
- Foo lesson.
EOF
}
teardown() { teardown_isolated_env; }

@test "scribe link adds the project to .imports.txt" {
  run "$SCRIBE_BIN" link foo
  [ "$status" -eq 0 ]
  grep -qx "foo" "$PROJECT_DIR/journal/.imports.txt"
}

@test "scribe link is idempotent (no duplicate lines)" {
  "$SCRIBE_BIN" link foo
  "$SCRIBE_BIN" link foo
  count=$(grep -c "^foo$" "$PROJECT_DIR/journal/.imports.txt")
  [ "$count" -eq 1 ]
}

@test "scribe link rejects unknown projects" {
  run "$SCRIBE_BIN" link does-not-exist
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found in library"* ]]
}

@test "scribe unlink removes the entry" {
  "$SCRIBE_BIN" link foo
  run "$SCRIBE_BIN" unlink foo
  [ "$status" -eq 0 ]
  ! grep -qx "foo" "$PROJECT_DIR/journal/.imports.txt" 2>/dev/null
}

@test "scribe library lists archived projects" {
  run "$SCRIBE_BIN" library
  [ "$status" -eq 0 ]
  [[ "$output" == *"foo"* ]]
}

@test "scribe library when empty prints a friendly message" {
  rm -f "$HOME/.scribe/library"/*.md
  run "$SCRIBE_BIN" library
  [ "$status" -eq 0 ]
  [[ "$output" == *"no archived projects"* ]]
}
