#!/bin/bash
# Build script: assembles dist/scribe-installer.sh from src/.
# Uses Python 3 (universally present on macOS/Linux) to safely splice base64-encoded
# binary payloads and source tarball into the installer template.

set -eu

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/src"
DIST="$ROOT/dist"
TEMPLATE="$SRC/installer/installer-template.sh"
JQ_DIR="$SRC/installer/jq-binaries"
VERSION="$(cat "$ROOT/VERSION")"

mkdir -p "$DIST"

# 1. Bundle src/ (minus jq-binaries) into a tarball.
PAYLOAD_TAR="$(mktemp)"
tar czf "$PAYLOAD_TAR" -C "$ROOT" \
  src/bin src/hooks src/commands src/templates src/installer/uninstall.sh

OUT="$DIST/scribe-installer.sh"

python3 - "$TEMPLATE" "$PAYLOAD_TAR" "$JQ_DIR" "$VERSION" "$OUT" <<'PY'
import sys, base64, os

template_path, payload_tar, jq_dir, version, out_path = sys.argv[1:6]

with open(template_path) as f:
    text = f.read()

def b64_file(path):
    with open(path, 'rb') as f:
        return base64.b64encode(f.read()).decode() + "\n"

text = text.replace("__VERSION__", version)
text = text.replace("__PAYLOAD__", b64_file(payload_tar))
text = text.replace("__JQ_MACOS_ARM64__",  b64_file(os.path.join(jq_dir, "jq-macos-arm64")))
text = text.replace("__JQ_MACOS_X86_64__", b64_file(os.path.join(jq_dir, "jq-macos-x86_64")))
text = text.replace("__JQ_LINUX_X86_64__", b64_file(os.path.join(jq_dir, "jq-linux-x86_64")))
text = text.replace("__JQ_LINUX_ARM64__",  b64_file(os.path.join(jq_dir, "jq-linux-arm64")))

with open(out_path, 'w') as f:
    f.write(text)
PY

rm -f "$PAYLOAD_TAR"
chmod +x "$OUT"

SIZE_KB=$(($(wc -c < "$OUT") / 1024))
echo "Built $OUT (${SIZE_KB} KB)"
