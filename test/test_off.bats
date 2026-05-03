#!/usr/bin/env bats

load helpers

setup() {
  setup_isolated_env
  "$SCRIBE_BIN" init
}
teardown() { teardown_isolated_env; }

@test "scribe off --yes removes journal/ and CLAUDE.md block" {
  echo "Other content" > "$PROJECT_DIR/CLAUDE.md.bak"
  cat "$PROJECT_DIR/CLAUDE.md.bak" "$PROJECT_DIR/CLAUDE.md" > "$PROJECT_DIR/CLAUDE.md.new"
  mv "$PROJECT_DIR/CLAUDE.md.new" "$PROJECT_DIR/CLAUDE.md"

  run "$SCRIBE_BIN" off --yes
  [ "$status" -eq 0 ]
  [ ! -d "$PROJECT_DIR/journal" ]
  ! grep -q "scribe-block-begin" "$PROJECT_DIR/CLAUDE.md"
  grep -q "Other content" "$PROJECT_DIR/CLAUDE.md"
}

@test "scribe off --yes removes .scribe-declined too" {
  touch "$PROJECT_DIR/.scribe-declined"
  run "$SCRIBE_BIN" off --yes
  [ ! -f "$PROJECT_DIR/.scribe-declined" ]
}

@test "scribe off without --yes prompts and aborts on no input" {
  run bash -c "echo 'n' | '$SCRIBE_BIN' off"
  [ "$status" -ne 0 ]
  [ -d "$PROJECT_DIR/journal" ]
}

@test "scribe off removes journal/ line from .gitignore" {
  run "$SCRIBE_BIN" off --yes
  if [ -f "$PROJECT_DIR/.gitignore" ]; then
    ! grep -q "^journal/$" "$PROJECT_DIR/.gitignore"
  fi
}
