#!/usr/bin/env bats

load helpers

@test "CLAUDE-block.md mentions paused sentinel check" {
  grep -q "journal/.paused" "$SCRIBE_REPO/src/templates/CLAUDE-block.md"
}

@test "CLAUDE-block.md mentions logbook, decisions, lessons, experiments, glossary" {
  for keyword in logbook decisions lessons experiments glossary; do
    grep -qi "$keyword" "$SCRIBE_REPO/src/templates/CLAUDE-block.md"
  done
}

@test "CLAUDE-block.md mentions YAML frontmatter convention" {
  grep -qi "frontmatter" "$SCRIBE_REPO/src/templates/CLAUDE-block.md"
}

@test "CLAUDE-block.md mentions natural-language commands" {
  grep -q "scribe pause" "$SCRIBE_REPO/src/templates/CLAUDE-block.md"
  grep -q "scribe archive" "$SCRIBE_REPO/src/templates/CLAUDE-block.md"
  grep -q "scribe link" "$SCRIBE_REPO/src/templates/CLAUDE-block.md"
}

@test "CLAUDE-block.md begins and ends with sentinels" {
  head -1 "$SCRIBE_REPO/src/templates/CLAUDE-block.md" | grep -q "scribe-block-begin"
  tail -1 "$SCRIBE_REPO/src/templates/CLAUDE-block.md" | grep -q "scribe-block-end"
}
