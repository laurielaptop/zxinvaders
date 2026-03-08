# ZX Invaders Porting Notes

## Goal
Port the original 8080 Space Invaders logic to ZX Spectrum 48K while replacing hardware-specific layers.

## Project Recap (Current State)
- Core game loop is in place: erase -> update -> draw -> frame wait.
- Player movement and single player shot are working.
- Alien formation movement is working (march + edge descent).
- Enemy shots are now working with column-table-driven firing and bottom-up alien selection.
- Basic scoring and HUD score rendering are working.
- A reusable on-screen debug visualizer exists for enemy-shot lifecycle debugging.

## Current Toolchain (macOS CLI)
- Assembler: `z80asm` v1.8 (Homebrew)
- Emulators: 
  - Primary: KLIVE IDE (`/Applications/Klive IDE.app`) - working with TAP loader
  - Secondary: ZEsarUX v12.0 (`/Applications/ZEsarUX.app`) - working with BASIC loader
- Build automation: `make` with targets: `assemble`, `package-tap`, `run`, `run-klive`, `run-zesarux`
- TAP packaging: Custom `tools/bin_to_tap.sh` (Perl script with BASIC auto-loader)

## Scope Baseline
- In scope: faithful gameplay behavior, maintainable Z80 modules, emulator-first iteration loop.
- Out of scope (for now): arcade-accurate ISR scheduling and full sound implementation.

## Hardware Migration Ledger
| 8080 dependency | Original assumption | ZX Spectrum replacement |
|---|---|---|
| ISR at `0x0008` / `0x0010` | Mid-screen and vblank split work | Software frame phases in main loop (later IRQ-backed) |
| Screen base `0x2400` | Linear arcade bitmap assumptions | ZX bitmap at `0x4000`, attrs at `0x5800` |
| Port `INP1` (`IN A,(01h)`) | Coin/start/fire/left/right | Keyboard scan via `IN A,(0xFE)` rows |
| Port `SOUND1/SOUND2` (`OUT 03h/05h`) | Arcade sound hardware | Deferred (future iteration) |

## Implementation Status

### Completed
1. **Build System**
   - `z80asm` assembly working with `-I src` include paths
   - TAP generation with BASIC auto-loader: `10 LOAD "" CODE : RANDOMIZE USR 32768`
   - Entry point at `org 32768`
   - Makefile targets for assembly, packaging, and emulator launch

2. **Video System**
   - `Video_Init`: Clear bitmap + attributes, set border black
   - `Video_CalcAddress`: ZX Spectrum non-linear screen address calculation
   - Bit-shifted sprite rendering for pixel-precise horizontal movement (not byte-aligned)
   - Per-object erase/draw flow (no full-screen clear per frame)

3. **Input System**
   - Keyboard scanning via port `0xFE` with row masks
   - Returns bitfield: bit0=left, bit1=right, bit2=fire

4. **Gameplay Modules**
   - Player: movement, fire edge-detect, position helper
   - Player shot: spawn, update, erase/draw, alien collision
   - Aliens: grid state, formation movement, edge descent, draw/erase
   - Enemy shots: periodic fire, column table, bottom-up selection, movement, erase/draw, player collision
   - HUD: score state init and score rendering

5. **Timing**
   - Busy-wait frame pacing in main loop (temporary)

6. **Debugging Support**
   - Attribute-cell enemy-shot visualizer (`src/debug.z80`)
   - Lifecycle indicators for counter/attempt/create/active stages

7. **Emulator Compatibility**
   - KLIVE: Manual TAP load working
   - ZEsarUX: BASIC auto-loader working (`LOAD ""` → auto-execute)

### Known Technical Debt
- Frame pacing still uses busy-wait timing rather than ISR/vblank sync.
- Rendering still shows expected Spectrum flicker under full redraw load.
- Player lives are tracked but not yet fully represented in HUD/game state flow.
- Game over and wave progression flow are not yet implemented.
- Diagnostic helper sources remain in tree and should be curated before release packaging.

### Remaining Steps
1. Implement full lives UX: HUD lives display, hit/respawn behavior polish.
2. Add game over state and restart flow when lives reach zero.
3. Add wave-clear detection and next-wave setup.
4. Optional parity improvements: additional enemy shot types/reload tuning.
5. End-phase optimization: ISR-synchronized rendering to reduce flicker.
6. Audio pass: fire, hit, and alien movement sound effects.

## Input Mapping
- Left: `O` (row DFFE, bit 1)
- Right: `P` (row DFFE, bit 0)
- Fire: `Space` (row 7FFE, bit 0)

Keys validated working in both KLIVE and ZEsarUX emulator

This mapping is temporary and can be replaced by configurable key/joystick maps.
