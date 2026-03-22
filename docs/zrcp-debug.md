# ZRCP Timing Monitor

ZEsarUX exposes a text-based TCP debugging interface called the **Z80 Remote Control Protocol (ZRCP)** on port 10000.  We use it to sample game RAM from a Python script while the game is running — no modifications to the Z80 source required.

## Quick start

```
# Terminal 1 — build and run the game
make run-zesarux

# Terminal 2 — start the monitor (after the game has loaded)
make monitor
# or directly:
python3 tools/zrcp_monitor.py
```

Press **Ctrl+C** in terminal 2 to stop the monitor and print a summary.

## What it detects

| Event | How detected |
|---|---|
| **March step** | `ALIEN_REF_X` byte changed between samples |
| **Enemy shot fired** | Any `ENEMY_SHOT_ACTIVE` slot changed 0 → 1 |
| **Saucer spawned / hit** | `SAUCER_STATE` changed |
| **Wave clear pause** | `WAVE_CLEAR_TIMER` changed 0 → >0 |
| **New wave** | `ALIEN_COUNT_REMAINING` jumped to 55 |

## Output format

```
    T-STATES       MS  EVENT                               DETAIL
------------------------------------------------------------------------
   1,234,567   352.7  March step                          X= 42  Y= 36  aliens=55  Δ=353ms
   1,512,890   432.3  Enemy shot fired (slot 0)           slot 0  aliens=50  Δ=80ms
   2,100,000   600.0  Saucer → flying                     X=0
```

- **T-STATES** — total emulated Z80 cycles since monitor start (precise, independent of Python/socket overhead)
- **MS** — wall-clock equivalent at 3.5 MHz
- **Δ** — interval since the previous event of the same type

A summary is printed on Ctrl+C showing average/min/max intervals for march steps and enemy shots.

## How it works

The monitor uses the ZRCP `run limit N` command to let the emulator execute `N` opcodes (default 80,000 ≈ 3–5 game frames), then reads a 103-byte block of game RAM covering all timing-relevant variables in one round trip.  T-state counts from `get-tstates-partial` / `reset-tstates-partial` give emulated-cycle precision regardless of Python scheduling jitter.

Key ZRCP commands used:

| Command | Purpose |
|---|---|
| `run limit N` | Execute N opcodes, then return control |
| `read-memory ADDR LEN` | Read LEN bytes at ADDR (hex, no spaces) |
| `get-tstates-partial` | T-states since last `reset-tstates-partial` |
| `reset-tstates-partial` | Reset the partial T-state counter |
| `get-cpu-frequency` | CPU Hz (for T-state → ms conversion) |

## Enabling ZRCP

`run_fuse.sh` (and therefore `make run-zesarux`) already passes `--enable-remoteprotocol` to ZEsarUX.  The port (10000) and prompt string are configured in `~/.zesaruxrc`:

```
--remoteprotocol-port 10000
--remoteprotocol-prompt "command"
```

If you launch ZEsarUX manually, enable it via **Settings → Enable remote protocol** before connecting.

## Options

```
python3 tools/zrcp_monitor.py --help

  --host HOST      ZEsarUX host (default: 127.0.0.1)
  --port PORT      ZRCP port (default: 10000)
  --steps N        Opcodes per burst (default: 80000)
  --timeout SEC    Socket timeout (default: 10.0)
```

You can also pass options via the Makefile:

```
make monitor MONITOR_ARGS="--steps 40000"
```

## Memory map reference (from src/constants.z80)

| Address | Symbol | Description |
|---|---|---|
| 23928 | `ALIEN_REF_X` | Formation reference X |
| 23929 | `ALIEN_REF_Y` | Formation reference Y |
| 23932 | `ALIEN_ANIM_FRAME` | Animation frame (0/1) |
| 23933 | `ALIEN_MOVE_COUNTER` | Frames since last march step |
| 23936 | `ENEMY_SHOT_COUNTER` | Enemy shot fire frame counter |
| 23972 | `STATE_GAME_MODE` | 0=title 1=playing 2=game_over |
| 23983 | `SAUCER_STATE` | 0=inactive 1=flying 2=hit |
| 24000 | `ALIEN_COUNT_REMAINING` | Live aliens (0 = wave clear) |
| 24001 | `WAVE_NUMBER` | Current wave index 0–7 |
| 24018 | `ENEMY_SHOT_LIST_BASE` | 3 × 4-byte shot records |
| 24021 | `ENEMY_SHOT_LIST_BASE+3` | Slot 0 active flag |
| 24025 | `ENEMY_SHOT_LIST_BASE+7` | Slot 1 active flag |
| 24029 | `ENEMY_SHOT_LIST_BASE+11` | Slot 2 active flag |
| 24030 | `WAVE_CLEAR_TIMER` | Inter-wave pause countdown |

## Interpreting march timing

The current march formula is `delay = max(3, ALIEN_COUNT_REMAINING >> 2)`.  With `Timing_WaitShort` = ~2800 iterations × ~26 T-states ≈ 72,800 T-states per "frame", expected march intervals are:

| Aliens | Delay frames | Expected interval |
|---|---|---|
| 55 (full) | 13 | ~947 ms |
| 40 | 10 | ~728 ms |
| 20 | 5 | ~364 ms |
| 8 | 3 | ~218 ms |
| 1 | 3 | ~218 ms (floor) |

Compare the **Avg interval** in the monitor summary against these targets to validate the ramp.
