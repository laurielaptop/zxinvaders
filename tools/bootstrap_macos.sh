#!/usr/bin/env sh
set -eu

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required. Install it from https://brew.sh/ and re-run this script."
  exit 1
fi

echo "Installing z80asm..."
brew install z80asm

echo "Checking Python 3..."
if ! command -v python3 >/dev/null 2>&1; then
  echo "Installing python3..."
  brew install python3
else
  echo "python3 already available: $(command -v python3)"
fi

echo "Trying to install ZEsarUX emulator (cask)."
if ! brew install --cask zesarux; then
  echo "Could not install ZEsarUX cask automatically."
  echo "If ZEsarUX is already installed in /Applications, you can ignore this warning."
fi

echo "Trying to install bin2tap (formula name may vary by tap)."
if ! brew install bin2tap; then
  echo "bin2tap formula was not found in current taps."
  echo "Install a bin->tap converter manually to enable 'make package-tap'."
fi

echo "Bootstrap completed. Run 'make check' next."
