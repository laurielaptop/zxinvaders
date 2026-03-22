#!/usr/bin/env sh
set -eu

missing=0

check_tool() {
  name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    printf "[ok] %s -> %s\n" "$name" "$(command -v "$name")"
  else
    printf "[missing] %s\n" "$name"
    missing=1
  fi
}

check_tool z80asm

# Python 3 is required by tools/zrcp_monitor.py and tools/dev.sh
if command -v python3 >/dev/null 2>&1; then
  printf "[ok] python3 -> %s\n" "$(command -v python3)"
else
  printf "[missing] python3 (required for make dev / make monitor)\n"
  missing=1
fi

if [ -x /Applications/ZEsarUX.app/Contents/MacOS/zesarux ]; then
  printf "[ok] zesarux -> %s\n" "/Applications/ZEsarUX.app/Contents/MacOS/zesarux"
elif command -v zesarux >/dev/null 2>&1; then
  printf "[ok] zesarux -> %s\n" "$(command -v zesarux)"
else
  printf "[warn] zesarux not found. Emulator run target may fail until installed.\n"
fi

if command -v bin2tap >/dev/null 2>&1; then
  printf "[ok] bin2tap -> %s\n" "$(command -v bin2tap)"
else
  printf "[warn] bin2tap not found. Using built-in tools/bin_to_tap.sh fallback.\n"
fi

if [ "$missing" -ne 0 ]; then
  echo "One or more required tools are missing. Run: make bootstrap"
  exit 1
fi

echo "Required tools are present"
