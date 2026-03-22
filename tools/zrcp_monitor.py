#!/usr/bin/env python3
"""
zrcp_monitor.py — ZEsarUX ZRCP timing monitor for ZX Invaders.

Connects to a running ZEsarUX instance via the Remote Control Protocol,
samples game RAM periodically, and logs timing events with precise
emulated-cycle counts (T-states).

Events reported
---------------
  March step     — alien formation moved; shows X position and alien count
  Enemy shot     — a new enemy shot became active; shows slot and alien count
  Saucer         — saucer state change (spawn / hit / expire)
  Wave clear     — pause timer started; shows wave number
  New wave       — alien count reset to 55

Usage
-----
  # In one terminal — launch ZEsarUX and load the game:
  make run-zesarux

  # In another terminal — start the monitor:
  python3 tools/zrcp_monitor.py

  # Or with custom options:
  python3 tools/zrcp_monitor.py --host 127.0.0.1 --port 10000 --steps 100000

Prerequisites
-------------
  ZEsarUX must be launched with --enable-remoteprotocol (run_fuse.sh does
  this automatically).  If connecting fails, enable it manually in ZEsarUX
  via Settings → Enable remote protocol, then restart.

Protocol notes
--------------
  ZRCP is a text-based TCP protocol on port 10000.  Commands are newline-
  terminated; responses end with the configured prompt ("command> ").
  We use:
    run limit N         — run N opcodes then return control (non-blocking burst)
    read-memory A L     — read L bytes from address A (hex, no separator)
    get-tstates-partial — T-states since last reset-tstates-partial
    reset-tstates-partial
"""

import socket
import sys
import time
import argparse
from dataclasses import dataclass, field

# ---------------------------------------------------------------------------
# Memory map (mirrors src/constants.z80)
# ---------------------------------------------------------------------------
GAME_RAM_BASE = 23808                          # 0x5CA0

ALIEN_REF_X          = GAME_RAM_BASE + 120    # 23928
ALIEN_REF_Y          = GAME_RAM_BASE + 121    # 23929
ALIEN_ANIM_FRAME     = GAME_RAM_BASE + 124    # 23932
ALIEN_MOVE_COUNTER   = GAME_RAM_BASE + 125    # 23933

ENEMY_SHOT_COUNTER   = GAME_RAM_BASE + 128    # 23936
TIMING_FRAME_PHASE   = GAME_RAM_BASE + 133    # 23941

STATE_GAME_MODE      = GAME_RAM_BASE + 164    # 23972
SAUCER_STATE         = GAME_RAM_BASE + 175    # 23983
SAUCER_X             = GAME_RAM_BASE + 179    # 23987

ALIEN_COUNT_REMAINING = GAME_RAM_BASE + 192   # 24000
WAVE_NUMBER           = GAME_RAM_BASE + 193   # 24001

SHOT_LIST_BASE        = GAME_RAM_BASE + 200   # 24008  (4 bytes: X Y PREV_Y ACTIVE)
ENEMY_SHOT_LIST_BASE  = GAME_RAM_BASE + 210   # 24018  (3 × 4 bytes)
WAVE_CLEAR_TIMER      = GAME_RAM_BASE + 222   # 24030

# Read one contiguous block: ALIEN_REF_X .. WAVE_CLEAR_TIMER inclusive
BLOCK_START = ALIEN_REF_X                     # 23928
BLOCK_END   = WAVE_CLEAR_TIMER + 1            # 24031 (exclusive)
BLOCK_LEN   = BLOCK_END - BLOCK_START         # 103 bytes

def _off(addr):
    """Byte offset of `addr` within our sample block."""
    return addr - BLOCK_START

# ---------------------------------------------------------------------------
# ZRCP client
# ---------------------------------------------------------------------------
PROMPT = b"command> "

class ZRCPClient:
    def __init__(self, host="127.0.0.1", port=10000, timeout=10.0):
        self.host = host
        self.port = port
        self.timeout = timeout
        self._sock = None
        self._buf = b""

    def connect(self):
        self._sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self._sock.settimeout(self.timeout)
        self._sock.connect((self.host, self.port))
        self._recv_until_prompt()   # consume initial "command> "

    def _recv_until_prompt(self):
        """Block until the ZRCP prompt arrives; return everything before it."""
        while PROMPT not in self._buf:
            chunk = self._sock.recv(4096)
            if not chunk:
                raise ConnectionError("ZEsarUX closed the connection")
            self._buf += chunk
        idx = self._buf.index(PROMPT)
        data, self._buf = self._buf[:idx], self._buf[idx + len(PROMPT):]
        return data.strip()

    def cmd(self, command):
        """Send one command; return the text response (stripped)."""
        self._sock.sendall((command + "\n").encode())
        return self._recv_until_prompt().decode(errors="replace").strip()

    def read_memory(self, address, length):
        """Return `length` bytes starting at `address` (decimal)."""
        resp = self.cmd(f"read-memory {address} {length}").strip()
        if resp.startswith("Error") or len(resp) < length * 2:
            return None
        try:
            return bytes.fromhex(resp[:length * 2])
        except ValueError:
            return None

    def get_tstates(self):
        """T-states elapsed since last reset-tstates-partial (or start)."""
        try:
            return int(self.cmd("get-tstates-partial"))
        except ValueError:
            return 0

    def reset_tstates(self):
        self.cmd("reset-tstates-partial")

    def run_burst(self, opcodes):
        """Run `opcodes` instructions then return."""
        self.cmd(f"run limit {opcodes}")

    def close(self):
        if self._sock:
            try:
                self._sock.close()
            except Exception:
                pass

# ---------------------------------------------------------------------------
# Game state snapshot
# ---------------------------------------------------------------------------
@dataclass
class Snap:
    alien_ref_x:   int = 0
    alien_ref_y:   int = 0
    alien_count:   int = 0
    wave_number:   int = 0
    wave_timer:    int = 0
    saucer_state:  int = 0
    saucer_x:      int = 0
    game_mode:     int = 0
    shot_active:   tuple = (0, 0, 0)   # enemy shot slots 0-2
    player_shot:   int = 0             # player shot active flag

def parse_snap(block: bytes) -> Snap:
    b = block
    def at(addr):
        i = _off(addr)
        return b[i] if 0 <= i < len(b) else 0

    return Snap(
        alien_ref_x  = at(ALIEN_REF_X),
        alien_ref_y  = at(ALIEN_REF_Y),
        alien_count  = at(ALIEN_COUNT_REMAINING),
        wave_number  = at(WAVE_NUMBER),
        wave_timer   = at(WAVE_CLEAR_TIMER),
        saucer_state = at(SAUCER_STATE),
        saucer_x     = at(SAUCER_X),
        game_mode    = at(STATE_GAME_MODE),
        shot_active  = (
            at(ENEMY_SHOT_LIST_BASE + 3),
            at(ENEMY_SHOT_LIST_BASE + 7),
            at(ENEMY_SHOT_LIST_BASE + 11),
        ),
        player_shot  = at(SHOT_LIST_BASE + 3),
    )

# ---------------------------------------------------------------------------
# Stats accumulator
# ---------------------------------------------------------------------------
@dataclass
class Stats:
    march_ts:     list = field(default_factory=list)   # T-states between march steps
    shot_ts:      list = field(default_factory=list)   # T-states between shot fires
    saucer_spans: list = field(default_factory=list)   # T-states saucer was active
    waves:        list = field(default_factory=list)   # (wave_num, ts_at_clear)

def summarise(stats: Stats, cpu_hz: int):
    def ms(ts):
        return ts / cpu_hz * 1000 if cpu_hz else 0

    print()
    print("=" * 70)
    print("TIMING SUMMARY")
    print("=" * 70)
    print(f"CPU frequency: {cpu_hz:,} Hz")

    if stats.march_ts:
        avg = sum(stats.march_ts) / len(stats.march_ts)
        print(f"\nMarch steps logged : {len(stats.march_ts)}")
        print(f"  Avg interval     : {ms(avg):.1f} ms  ({avg:,.0f} T-states)")
        print(f"  Min / Max        : {ms(min(stats.march_ts)):.1f} / {ms(max(stats.march_ts)):.1f} ms")
    else:
        print("\nNo march steps detected.")

    if stats.shot_ts:
        avg = sum(stats.shot_ts) / len(stats.shot_ts)
        print(f"\nEnemy shots logged : {len(stats.shot_ts) + 1}")
        print(f"  Avg inter-shot   : {ms(avg):.1f} ms  ({avg:,.0f} T-states)")
        print(f"  Min / Max        : {ms(min(stats.shot_ts)):.1f} / {ms(max(stats.shot_ts)):.1f} ms")
    else:
        print("\nNo enemy shots detected.")

    if stats.saucer_spans:
        avg = sum(stats.saucer_spans) / len(stats.saucer_spans)
        print(f"\nSaucer appearances : {len(stats.saucer_spans)}")
        print(f"  Avg active time  : {ms(avg):.1f} ms")
    else:
        print("\nNo complete saucer flights detected.")

    if stats.waves:
        print(f"\nWaves cleared      : {len(stats.waves)}")
        for wn, ts in stats.waves:
            print(f"  Wave {wn+1} cleared at T+{ts:,}")

# ---------------------------------------------------------------------------
# Main monitor loop
# ---------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description="ZX Invaders ZRCP timing monitor")
    ap.add_argument("--host",     default="127.0.0.1")
    ap.add_argument("--port",     type=int, default=10000)
    ap.add_argument("--steps",    type=int, default=80000,
                    help="Opcodes per burst (default 80000 ≈ 3-5 game frames)")
    ap.add_argument("--timeout",  type=float, default=10.0,
                    help="Socket timeout in seconds")
    args = ap.parse_args()

    client = ZRCPClient(args.host, args.port, args.timeout)

    try:
        client.connect()
    except ConnectionRefusedError:
        print("ERROR: Cannot connect to ZEsarUX on "
              f"{args.host}:{args.port}.")
        print()
        print("Make sure:")
        print("  1. ZEsarUX is running  (make run-zesarux)")
        print("  2. ZRCP is enabled     (run_fuse.sh adds --enable-remoteprotocol)")
        print("  3. Port matches        (Settings → Remote protocol port = 10000)")
        sys.exit(1)
    except OSError as e:
        print(f"ERROR: {e}")
        sys.exit(1)

    print(f"Connected to ZEsarUX ZRCP at {args.host}:{args.port}")

    # Query CPU frequency for T-state → ms conversion
    try:
        cpu_hz = int(client.cmd("get-cpu-frequency"))
    except ValueError:
        cpu_hz = 3_500_000   # ZX Spectrum 48k default
        print(f"Warning: could not read CPU frequency; assuming {cpu_hz:,} Hz")

    client.reset_tstates()

    print(f"CPU: {cpu_hz:,} Hz  |  Burst: {args.steps:,} opcodes")
    print("Press Ctrl+C to stop and print summary.\n")

    hdr = f"{'T-STATES':>12}  {'MS':>7}  {'EVENT':<35}  DETAIL"
    print(hdr)
    print("-" * len(hdr))

    def log(ts, label, detail=""):
        ms_str = f"{ts / cpu_hz * 1000:7.1f}" if cpu_hz else "    ---"
        print(f"{ts:12,}  {ms_str}  {label:<35}  {detail}")

    stats    = Stats()
    prev     = None
    total_ts = 0

    last_march_ts  = None
    last_shot_ts   = None
    saucer_span_ts = None   # T-states when saucer became active

    try:
        while True:
            client.run_burst(args.steps)

            block = client.read_memory(BLOCK_START, BLOCK_LEN)
            if block is None:
                continue

            ts = client.get_tstates()
            total_ts += ts
            client.reset_tstates()

            snap = parse_snap(block)

            if prev is None:
                prev = snap
                continue

            # --- March step (alien_ref_x changed) ---
            if snap.alien_ref_x != prev.alien_ref_x:
                detail = (f"X={snap.alien_ref_x:3d}  Y={snap.alien_ref_y:3d}"
                          f"  aliens={snap.alien_count:2d}")
                if last_march_ts is not None:
                    delta = total_ts - last_march_ts
                    stats.march_ts.append(delta)
                    detail += f"  Δ={delta/cpu_hz*1000:.0f}ms"
                log(total_ts, "March step", detail)
                last_march_ts = total_ts

            # --- Enemy shot fired (active: 0 → 1 or 2) ---
            for i in range(3):
                was = prev.shot_active[i]
                now = snap.shot_active[i]
                if was == 0 and now != 0:
                    detail = f"slot {i}  aliens={snap.alien_count:2d}"
                    if last_shot_ts is not None:
                        delta = total_ts - last_shot_ts
                        stats.shot_ts.append(delta)
                        detail += f"  Δ={delta/cpu_hz*1000:.0f}ms"
                    log(total_ts, f"Enemy shot fired (slot {i})", detail)
                    last_shot_ts = total_ts

            # --- Saucer state changes ---
            if snap.saucer_state != prev.saucer_state:
                labels = {0: "→ inactive", 1: "→ flying", 2: "→ hit"}
                label = labels.get(snap.saucer_state,
                                   f"→ state {snap.saucer_state}")
                if snap.saucer_state == 1:
                    saucer_span_ts = total_ts
                    log(total_ts, f"Saucer {label}", f"X={snap.saucer_x}")
                elif snap.saucer_state == 0 and saucer_span_ts is not None:
                    span = total_ts - saucer_span_ts
                    stats.saucer_spans.append(span)
                    log(total_ts, f"Saucer {label}",
                        f"active={span/cpu_hz*1000:.0f}ms")
                    saucer_span_ts = None
                else:
                    log(total_ts, f"Saucer {label}")

            # --- Wave clear pause starts ---
            if snap.wave_timer > 0 and prev.wave_timer == 0:
                log(total_ts, "Wave clear pause",
                    f"wave={snap.wave_number+1}  aliens_left={snap.alien_count}")
                stats.waves.append((snap.wave_number, total_ts))

            # --- New wave (alien count jumps back to 55) ---
            if snap.alien_count == 55 and prev.alien_count < 55:
                log(total_ts, "New wave started",
                    f"wave={snap.wave_number+1}")

            prev = snap

    except KeyboardInterrupt:
        pass
    finally:
        client.close()

    summarise(stats, cpu_hz)


if __name__ == "__main__":
    main()
