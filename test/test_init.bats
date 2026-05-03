#!/usr/bin/env bats

load helpers

setup() {
  setup_isolated_env
  # init reads templates from src/templates/ (via SCRIBE_TEMPLATES_DIR set in helpers).
}

teardown() {
  teardown_isolated_env
}

@test "scribe init creates journal/ structure" {
  run "$SCRIBE_BIN" init
  [ "$status" -eq 0 ]
  [ -d "$PROJECT_DIR/journal" ]
  [ -d "$PROJECT_DIR/journal/logbook" ]
  [ -d "$PROJECT_DIR/journal/decisions" ]
  [ -d "$PROJECT_DIR/journal/experiments" ]
  [ -f "$PROJECT_DIR/journal/lessons.md" ]
  [ -f "$PROJECT_DIR/journal/README.md" ]
}

@test "scribe init adds journal/ to .gitignore" {
  run "$SCRIBE_BIN" init
  [ "$status" -eq 0 ]
  grep -q "^journal/$" "$PROJECT_DIR/.gitignore"
}

@test "scribe init does not duplicate the .gitignore line on rerun" {
  "$SCRIBE_BIN" init
  "$SCRIBE_BIN" init
  count=$(grep -c "^journal/$" "$PROJECT_DIR/.gitignore")
  [ "$count" -eq 1 ]
}

@test "scribe init creates CLAUDE.md if missing and inserts the block" {
  run "$SCRIBE_BIN" init
  [ "$status" -eq 0 ]
  [ -f "$PROJECT_DIR/CLAUDE.md" ]
  grep -q "scribe-block-begin" "$PROJECT_DIR/CLAUDE.md"
  grep -q "scribe-block-end" "$PROJECT_DIR/CLAUDE.md"
}

@test "scribe init preserves existing CLAUDE.md content" {
  echo "# Existing project notes" > "$PROJECT_DIR/CLAUDE.md"
  echo "Important instruction." >> "$PROJECT_DIR/CLAUDE.md"

  run "$SCRIBE_BIN" init
  [ "$status" -eq 0 ]
  grep -q "Existing project notes" "$PROJECT_DIR/CLAUDE.md"
  grep -q "Important instruction." "$PROJECT_DIR/CLAUDE.md"
  grep -q "scribe-block-begin" "$PROJECT_DIR/CLAUDE.md"
}

@test "scribe init is idempotent (no double-block)" {
  "$SCRIBE_BIN" init
  "$SCRIBE_BIN" init
  count=$(grep -c "scribe-block-begin" "$PROJECT_DIR/CLAUDE.md")
  [ "$count" -eq 1 ]
}

@test "scribe init does not overwrite existing journal files" {
  "$SCRIBE_BIN" init
  echo "user-edited content" > "$PROJECT_DIR/journal/lessons.md"
  "$SCRIBE_BIN" init
  grep -q "user-edited content" "$PROJECT_DIR/journal/lessons.md"
}

@test "scribe init handles .gitignore without trailing newline" {
  printf "*.swp" > "$PROJECT_DIR/.gitignore"  # No trailing newline
  run "$SCRIBE_BIN" init
  [ "$status" -eq 0 ]
  grep -qx "journal/" "$PROJECT_DIR/.gitignore"
  grep -qx "\\*\\.swp" "$PROJECT_DIR/.gitignore"
  # And rerun should still be idempotent
  "$SCRIBE_BIN" init
  count=$(grep -c "^journal/$" "$PROJECT_DIR/.gitignore")
  [ "$count" -eq 1 ]
}
