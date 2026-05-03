#!/usr/bin/env bats

load helpers

setup() { setup_isolated_env; }
teardown() { teardown_isolated_env; }

@test "installer extracts to ~/.scribe with expected files" {
  install_fake_claude
  bash "$SCRIBE_REPO/dist/scribe-installer.sh" >/dev/null

  [ -f "$HOME/.scribe/bin/scribe" ]
  [ -x "$HOME/.scribe/bin/scribe" ]
  [ -x "$HOME/.scribe/bin/jq" ]
  [ -f "$HOME/.scribe/hooks/session-start.sh" ]
  [ -f "$HOME/.scribe/hooks/stop.sh" ]
  [ -f "$HOME/.scribe/templates/CLAUDE-block.md" ]
  [ -f "$HOME/.scribe/uninstall.sh" ]
  [ -f "$HOME/.scribe/VERSION" ]
}

@test "installer wires hooks into ~/.claude/settings.json" {
  install_fake_claude
  bash "$SCRIBE_REPO/dist/scribe-installer.sh" >/dev/null

  [ -f "$HOME/.claude/settings.json" ]
  grep -q "scribe" "$HOME/.claude/settings.json"
  grep -q "session-start.sh" "$HOME/.claude/settings.json"
  grep -q "stop.sh" "$HOME/.claude/settings.json"
}

@test "installer copies slash command files" {
  install_fake_claude
  bash "$SCRIBE_REPO/dist/scribe-installer.sh" >/dev/null

  [ -f "$HOME/.claude/commands/journal-pause.md" ]
  [ -f "$HOME/.claude/commands/journal-resume.md" ]
  [ -f "$HOME/.claude/commands/journal-status.md" ]
}

@test "installer is idempotent — second run does not duplicate hooks" {
  install_fake_claude
  bash "$SCRIBE_REPO/dist/scribe-installer.sh" >/dev/null
  bash "$SCRIBE_REPO/dist/scribe-installer.sh" >/dev/null

  count=$(grep -c '"scribe": true' "$HOME/.claude/settings.json")
  [ "$count" -eq 2 ]   # one for SessionStart, one for Stop, no duplicates
}

@test "installer fails clearly when claude is missing" {
  # No fake claude installed.
  saved="$PATH"
  export PATH="/usr/bin:/bin"
  run bash "$SCRIBE_REPO/dist/scribe-installer.sh"
  export PATH="$saved"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Claude Code"* ]]
}

@test "installer adds PATH line to .zshrc" {
  install_fake_claude
  export SHELL=/bin/zsh
  bash "$SCRIBE_REPO/dist/scribe-installer.sh" >/dev/null

  [ -f "$HOME/.zshrc" ]
  grep -q "\.scribe/bin" "$HOME/.zshrc"
}

@test "uninstaller cleanly reverses the install" {
  install_fake_claude
  bash "$SCRIBE_REPO/dist/scribe-installer.sh" >/dev/null

  # Sanity
  [ -f "$HOME/.scribe/uninstall.sh" ]
  printf 'n\n' | bash "$HOME/.scribe/uninstall.sh" >/dev/null

  [ ! -f "$HOME/.scribe/bin/scribe" ]
  [ ! -f "$HOME/.claude/commands/journal-pause.md" ]
  ! grep -q '"scribe": true' "$HOME/.claude/settings.json"
}
