# ZX Invaders

A ZX Spectrum 48K port of the Space Invaders gameplay loop, written in Z80 assembly.  The goal is arcade-authentic behaviour — movement, firing, timing, and shield erosion — adapted to the Spectrum's non-linear video memory and I/O model.

## Quick start (macOS)

```bash
git clone <repo>
cd zxinvaders
make bootstrap   # install z80asm, ZEsarUX, Python 3 via Homebrew
make check       # verify all tools are present
make dev         # build, launch emulator + timing monitor together
```

In ZEsarUX, type `LOAD ""` to load the game.  The timing monitor starts automatically in the same terminal.  Press **Ctrl+C** to stop both.

## Prerequisites

| Tool | Purpose | Install |
| --- | --- | --- |
| `z80asm` | Z80 assembler | `brew install z80asm` |
| ZEsarUX | ZX Spectrum emulator | `brew install --cask zesarux` |
| `python3` | Timing monitor (`make dev`) | `brew install python3` |
| `bin2tap` | TAP packager (optional fallback built-in) | `brew install bin2tap` |

`make bootstrap` installs all of the above.  `make check` verifies they are present without installing anything.

## Make targets

| Target | Description |
| --- | --- |
| `make assemble` | Assemble `src/main.z80` → `build/zxinvaders.bin` |
| `make package-tap` | Pack binary into `dist/zxinvaders.tap` |
| `make run-zesarux` | Build + launch ZEsarUX (ZRCP enabled) |
| `make dev` | Build + launch ZEsarUX **and** timing monitor together |
| `make monitor` | Connect timing monitor to a running ZEsarUX |
| `make check` | Verify all required tools are installed |
| `make bootstrap` | Install all tools via Homebrew (macOS) |
| `make clean` | Remove build and dist outputs |

Pass options to the monitor via `MONITOR_ARGS`:

```bash
make dev MONITOR_ARGS="--steps 40000"
```

## Development workflow

The primary loop is:

1. Edit Z80 source in `src/`
2. `make dev` — rebuilds, launches emulator and monitor in one command
3. Play the game; monitor prints timing events (march steps, shots, saucer, waves) live
4. Press Ctrl+C to stop and see the summary report

For emulator-only (no monitor):

```bash
make run-zesarux
```

## ZRCP timing monitor

`make dev` launches `tools/zrcp_monitor.py`, which connects to ZEsarUX over its Remote Control Protocol (TCP port 10000) and samples game RAM in real time.  It logs:

- **March steps** — interval between formation moves, with alien count (validates speed ramp)
- **Enemy shots** — inter-shot interval by slot
- **Saucer** — spawn/hit/expire with active duration
- **Wave transitions** — wave clear pause start and new wave detection

A summary with average/min/max intervals is printed on exit.  See `docs/zrcp-debug.md` for full protocol details and the expected timing targets.

## Current status (March 2026)

**Complete:**

- Player movement, single shot, shot–shield and shot–alien collision
- Alien formation: ROM-sourced graphics, 5-row × 11-col grid, march + descent
- March speed ramp: `delay = max(3, aliens_remaining >> 2)` — formation accelerates as aliens die
- Enemy shot system: three-family rotation (rolling / plunger / squiggly), column-driven bottom-up selection, shield erosion and pass-through on eroded columns
- Shield architecture: drawn once per wave, pixel-level erosion directly on ZX bitmap, AABB + per-pixel collision check
- Wave transitions: wave-clear pause (30 frames), `Video_ClearBitmap` fixed (was overwriting attribute memory), multiple waves playable
- Saucer: ROM-derived art, 1-pixel shifted movement, score table, dev H-key trigger
- HUD: score, lives display
- Game over state and restart flow
- ZRCP timing monitor (`make dev`)

**Remaining (see `docs/remaining-checklist.md`):**

- Enemy-shot timing/cadence polish
- Saucer timing parity
- Attribute-memory safety sweep
- ISR/vblank-synchronised timing (replace busy-wait)
- Flicker reduction
- Audio

## Source layout

```text
src/
  main.z80            Main loop, game state machine
  constants.z80       Memory map and all global constants
  platform/
    video.z80         Video_Init, Video_ClearBitmap, Video_ClearAttributes
    video_helpers.z80 Video_CalcAddress (ZX non-linear bitmap addressing)
    input.z80         Keyboard input
    timing.z80        Timing_WaitShort, frame-phase scaffold
  game/
    aliens.z80        Formation movement, draw, erase, wave init
    alien_hit.z80     Explosion animation
    enemy_shot.z80    Enemy shot lifecycle, firing, collision
    player.z80        Player movement, draw, erase
    player_hit.z80    Hit detection, blowup animation, lives
    shot.z80          Player shot lifecycle, collision
    shields.z80       Shield init, draw, erosion, collision
    saucer.z80        Saucer movement, scoring
    hud.z80           Score and lives HUD
tools/
  bootstrap_macos.sh  Install all dependencies via Homebrew
  check_tools.sh      Verify required tools are present
  dev.sh              Launch ZEsarUX + timing monitor together
  zrcp_monitor.py     ZRCP timing monitor
  bin_to_tap.sh       Binary → TAP packager
  run_fuse.sh         Emulator launcher helper
docs/
  remaining-checklist.md  Active work tracker
  zrcp-debug.md           ZRCP monitor usage and memory map reference
  porting-notes.md        Arcade-to-Spectrum porting decisions
```

## Key technical notes

- **`Video_CalcAddress`**: input `A=X, C=Y`; output `HL=screen address`; preserves `B, C, D, E`; clobbers `A, HL`.
- **ZX screen layout**: non-linear — use `Video_CalcAddress` for every row; never assume consecutive addresses are vertically adjacent.
- **Attribute memory** starts at 0x5800; game RAM at 0x5CA0.  `Video_ClearBitmap` clears only the 6144-byte bitmap (0x4000–0x57FF), not attributes.
- **Shields** are permanent screen content — never call a shield draw or erase from the main loop.
- **Z80 `jr` range**: ±127 bytes.  Use `jp` for longer branches.
