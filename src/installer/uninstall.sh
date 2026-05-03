#!/bin/bash
# scribe uninstaller. Idempotent and offline.

set -u

SCRIBE_HOME="$HOME/.scribe"
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
COMMANDS_DIR="$CLAUDE_DIR/commands"

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }

bold "Removing scribe..."
echo

# 1. Strip scribe entries from settings.json.
if [ -f "$SETTINGS" ]; then
  JQ=""
  if [ -x "$SCRIBE_HOME/bin/jq" ]; then JQ="$SCRIBE_HOME/bin/jq"
  elif command -v jq >/dev/null 2>&1; then JQ=jq; fi

  if [ -n "$JQ" ]; then
    UPDATED=$("$JQ" '
      if .hooks then
        .hooks.SessionStart? |= ((. // []) | map(select(.scribe != true))) |
        .hooks.Stop?         |= ((. // []) | map(select(.scribe != true)))
      else . end
    ' "$SETTINGS")
    echo "$UPDATED" > "$SETTINGS"
  fi
  echo "  ✓ Unwired from Claude Code"
fi

# 2. Remove slash commands.
for f in journal-pause.md journal-resume.md journal-status.md; do
  rm -f "$COMMANDS_DIR/$f"
done
echo "  ✓ Removed slash commands"

# 3. Remove PATH line from shell rc.
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  [ -f "$rc" ] || continue
  if grep -q '\.scribe/bin' "$rc"; then
    awk '/# scribe/{skip=1; next} skip && /^export PATH=.*\.scribe\/bin/{skip=0; next} {print}' "$rc" > "$rc.tmp" && mv "$rc.tmp" "$rc"
    # Trim trailing blank line if any.
    awk 'NR==FNR{if(NF)last=NR; next} FNR<=last' "$rc" "$rc" > "$rc.tmp" && mv "$rc.tmp" "$rc"
  fi
done

# 4. Ask about library.
KEEP_LIBRARY=1
if [ -d "$SCRIBE_HOME/library" ]; then
  COUNT=$(ls -1 "$SCRIBE_HOME/library"/*.md 2>/dev/null | wc -l | tr -d ' ')
  if [ "$COUNT" -gt 0 ]; then
    printf "You have %s archived past-project journal(s) at ~/.scribe/library/. Remove them too? (y/N) " "$COUNT"
    read -r reply
    case "$reply" in
      y|Y|yes|YES) KEEP_LIBRARY=0 ;;
    esac
  fi
fi

# 5. Remove ~/.scribe (preserving library if requested).
if [ -d "$SCRIBE_HOME" ]; then
  if [ "$KEEP_LIBRARY" -eq 1 ] && [ -d "$SCRIBE_HOME/library" ]; then
    # Remove everything except library/.
    find "$SCRIBE_HOME" -mindepth 1 -maxdepth 1 ! -name library -exec rm -rf {} +
    echo "  ✓ Removed ~/.scribe (library kept)"
  else
    rm -rf "$SCRIBE_HOME"
    echo "  ✓ Removed ~/.scribe"
  fi
fi

echo
green "Done. scribe has been uninstalled."
echo
echo "Note: active project journals (./journal/ folders inside your projects) are"
echo "untouched. To remove journaling from a specific project, ask Claude in that"
echo "project: \"turn off journaling here\"."
echo
