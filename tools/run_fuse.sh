#!/usr/bin/env sh
set -eu

EMULATOR="auto"

if [ "$#" -eq 2 ]; then
  case "$1" in
    --klive)
      EMULATOR="klive"
      ;;
    --zesarux)
      EMULATOR="zesarux"
      ;;
    --fuse)
      EMULATOR="fuse"
      ;;
    *)
      echo "Usage: $0 [--klive|--zesarux|--fuse] <tap-file>"
      exit 1
      ;;
  esac
  shift
fi

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 [--klive|--zesarux|--fuse] <tap-file>"
  exit 1
fi

TAP_FILE="$1"

# Resolve to absolute path if relative
if [ ! "/" = "${TAP_FILE%/}" ]; then
  TAP_FILE="$(pwd)/$TAP_FILE"
fi

if [ ! -f "$TAP_FILE" ]; then
  echo "TAP file not found: $TAP_FILE"
  exit 1
fi

# Try KLIVE first in auto mode (known working)
if [ "$EMULATOR" = "auto" ] || [ "$EMULATOR" = "klive" ]; then
if [ -x "/Applications/Klive IDE.app/Contents/MacOS/Klive IDE" ]; then
  echo "Launching KLIVE IDE..."
  echo "Note: Please manually load the TAP file: $TAP_FILE"
  exec open -a "Klive IDE"
fi
fi

if [ "$EMULATOR" = "auto" ] || [ "$EMULATOR" = "zesarux" ]; then
if [ -x /Applications/ZEsarUX.app/Contents/MacOS/zesarux ]; then
  echo "Launching ZEsarUX with tape inserted: $TAP_FILE"
  echo "In Spectrum BASIC, type exactly:"
  echo "  LOAD \"\""
  echo "(TAP now contains a BASIC loader that runs the CODE block automatically.)"
  exec /Applications/ZEsarUX.app/Contents/MacOS/zesarux --enable-remoteprotocol --tape "$TAP_FILE"
fi

if command -v zesarux >/dev/null 2>&1; then
  echo "Launching ZEsarUX with tape inserted: $TAP_FILE"
  echo "In Spectrum BASIC, type exactly:"
  echo "  LOAD \"\""
  echo "(TAP now contains a BASIC loader that runs the CODE block automatically.)"
  exec zesarux --enable-remoteprotocol --tape "$TAP_FILE"
fi
fi

if [ "$EMULATOR" = "auto" ] || [ "$EMULATOR" = "fuse" ]; then
if command -v fuse >/dev/null 2>&1; then
  # Keep invocation simple for broad Fuse compatibility.
  exec fuse --machine 48 --tape "$TAP_FILE"
fi
fi

echo "No compatible ZX Spectrum emulator found for selection: $EMULATOR"
echo "Install one, then re-run: make run"
exit 1
