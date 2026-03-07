#!/usr/bin/env sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <tap-file>"
  exit 1
fi

TAP_FILE="$1"

if [ ! -f "$TAP_FILE" ]; then
  echo "TAP file not found: $TAP_FILE"
  exit 1
fi

if [ -x /Applications/ZEsarUX.app/Contents/MacOS/zesarux ]; then
  exec /Applications/ZEsarUX.app/Contents/MacOS/zesarux --tape "$TAP_FILE"
fi

if command -v zesarux >/dev/null 2>&1; then
  exec zesarux --tape "$TAP_FILE"
fi

if command -v fuse >/dev/null 2>&1; then
  # Keep invocation simple for broad Fuse compatibility.
  exec fuse --machine 48 --tape "$TAP_FILE"
fi

echo "No compatible ZX Spectrum emulator found (tried zesarux and fuse)."
echo "Install one, then re-run: make run"
exit 1
