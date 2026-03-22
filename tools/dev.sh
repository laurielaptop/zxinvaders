#!/usr/bin/env sh
# dev.sh — launch ZEsarUX + ZRCP monitor together.
#
# Usage:
#   ./tools/dev.sh [monitor-args...]
#   make dev
#   make dev MONITOR_ARGS="--steps 40000"
#
# What it does:
#   1. Starts ZEsarUX in the background with --enable-remoteprotocol
#   2. Waits until ZRCP port 10000 accepts connections
#   3. Starts the timing monitor in the foreground
#   4. On exit (Ctrl+C or monitor quit), kills ZEsarUX cleanly
#
# The TAP file must already be built (make package-tap / make dev handles this).

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TAP="$PROJECT_DIR/dist/zxinvaders.tap"
MONITOR="$PROJECT_DIR/tools/zrcp_monitor.py"
PORT=10000
WAIT_MAX=20   # seconds to wait for ZRCP before giving up

# --- Locate ZEsarUX ---
ZESARUX=""
if [ -x "/Applications/ZEsarUX.app/Contents/MacOS/zesarux" ]; then
    ZESARUX="/Applications/ZEsarUX.app/Contents/MacOS/zesarux"
elif command -v zesarux >/dev/null 2>&1; then
    ZESARUX="zesarux"
else
    echo "ERROR: ZEsarUX not found." >&2
    echo "Install it at /Applications/ZEsarUX.app or ensure 'zesarux' is on PATH." >&2
    exit 1
fi

if [ ! -f "$TAP" ]; then
    echo "ERROR: TAP file not found: $TAP" >&2
    echo "Run 'make package-tap' first." >&2
    exit 1
fi

# --- Start ZEsarUX in background ---
echo "Starting ZEsarUX ..."
"$ZESARUX" --enable-remoteprotocol --tape "$TAP" &
ZESARUX_PID=$!

# --- Ensure ZEsarUX is killed when this script exits ---
cleanup() {
    echo ""
    echo "Stopping ZEsarUX (pid $ZESARUX_PID) ..."
    kill "$ZESARUX_PID" 2>/dev/null || true
    wait "$ZESARUX_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# --- Wait for ZRCP port to open ---
echo "Waiting for ZRCP on port $PORT ..."
elapsed=0
while true; do
    # Use Python for portability (avoids nc flag differences across macOS/Linux)
    if python3 - <<'EOF' 2>/dev/null
import socket, sys
s = socket.socket()
s.settimeout(0.5)
sys.exit(0 if s.connect_ex(('127.0.0.1', 10000)) == 0 else 1)
EOF
    then
        break
    fi

    sleep 0.5
    elapsed=$((elapsed + 1))

    # Check ZEsarUX didn't crash
    if ! kill -0 "$ZESARUX_PID" 2>/dev/null; then
        echo "ERROR: ZEsarUX exited unexpectedly." >&2
        exit 1
    fi

    if [ "$elapsed" -ge "$((WAIT_MAX * 2))" ]; then
        echo "ERROR: Timed out waiting for ZRCP after ${WAIT_MAX}s." >&2
        echo "Make sure ZEsarUX has 'Enable remote protocol' turned on." >&2
        exit 1
    fi
done

echo "ZRCP ready. Starting monitor ..."
echo "  In ZEsarUX: type  LOAD \"\"  to load the game, then play normally."
echo "  Press Ctrl+C here to stop both the monitor and ZEsarUX."
echo ""

# --- Run monitor in foreground (pass any extra args through) ---
python3 "$MONITOR" "$@"
