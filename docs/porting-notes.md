# ZX Invaders Porting Notes

## Goal
Port the original 8080 Space Invaders logic to ZX Spectrum 48K while replacing hardware-specific layers.

## Current Toolchain (macOS CLI)
- Assembler: `z80asm`
- Emulator: `ZEsarUX` (`/Applications/ZEsarUX.app/Contents/MacOS/zesarux`) or `fuse` fallback
- Build automation: `make`
- Optional packaging helper: `bin2tap` (required for `make package-tap`)

## Iteration 1 Scope
- In scope: build system, emulator loop, graphics primitives, keyboard input, timing scaffold, first game loop slices
- Out of scope: audio implementation (stubs only)

## Hardware Migration Ledger
| 8080 dependency | Original assumption | ZX Spectrum replacement |
|---|---|---|
| ISR at `0x0008` / `0x0010` | Mid-screen and vblank split work | Software frame phases in main loop (later IRQ-backed) |
| Screen base `0x2400` | Linear arcade bitmap assumptions | ZX bitmap at `0x4000`, attrs at `0x5800` |
| Port `INP1` (`IN A,(01h)`) | Coin/start/fire/left/right | Keyboard scan via `IN A,(0xFE)` rows |
| Port `SOUND1/SOUND2` (`OUT 03h/05h`) | Arcade sound hardware | Deferred for iteration 1 |
| Port `WATCHDOG` (`OUT 06h`) | Hardware watchdog feed | No-op/software health counter |

## First Milestones
1. Assemble `src/main.z80` into `build/zxinvaders.bin`.
2. Convert to TAP when `bin2tap` is available.
3. Boot in Fuse and confirm:
   - Border color changes with input bits.
   - Test sprite persists on screen.
4. Start migrating game-state structures from `resources/source.z80` into `src/game/` modules.

## Input Mapping (Initial)
- Left: `O`
- Right: `P`
- Fire: `Space`

This mapping is temporary and can be replaced by configurable key/joystick maps.
