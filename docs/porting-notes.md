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
- **Shields are fully working** with proper erase/draw cycle and spacing (4 shields at Y=144, spaced 48 pixels horizontally).
- **Saucer/UFO is fully implemented** with tuned ZX timing (256 game-loop countdown under current busy-wait pacing), horizontal movement, direction determination based on shot count, score table advancement (50/100/150/300 points), hit detection, and explosion sequence.
- **Player and alien explosion systems are implemented** (timed animation, hit-triggered state machines, and cleanup).
- **Alien renderer scanline stepping is corrected for ZX screen layout** to avoid split sprites across memory boundaries.
- **Source-first graphics parity analysis is complete** for player/aliens/saucer/shields/shots and animation frame behavior.
- **Alien sprite parity is complete** (ROM-derived A/B/C row families, 2-frame animation, deterministic transform pipeline).
- **Player sprite parity is still open** despite deterministic table tests; current blocker is renderer/table interpretation.
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
   - `Video_CalcAttrAddress`: Attribute address calculation for color blocks (character-aligned 8x8 areas)
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
- Saucer bring-up diagnostics have been removed from the main loop after render/timing validation.
- Player sprite path still needs final table/byte-order lock to match arcade silhouette.

### Gameplay Parity Gaps (Confirmed)
- Saucer/UFO bonus target is now implemented (timed top-row flyby + score award based on arcade behavior, with timing currently calibrated for busy-wait frame pacing).
- Alien shot system is currently simplified and does not yet implement three arcade shot families.
- Alien rendering now uses row-specific arcade-derived sprite families and frame toggling.
- Player sprite currently does not match the original silhouette in-game; further renderer-isolation is required.
- Sprite source mapping and render/animation behavior are now documented in `docs/graphics-animation-parity.md`.
- Explosion animation parity is partial: player and alien explosions are in place; remaining parity gaps are secondary shot/saucer side-effect details.

### Source-First Rule For Remaining Features
For each missing gameplay element, we must complete a short 8080 behavior note before writing ZX code:
1. Identify original routines and state bytes in `resources/source.z80`.
2. Document control flow and timing assumptions (ISR/frame coupling, counters, flags).
3. Define ZX adaptation contract: what must remain behaviorally identical, and what is platform-adjusted.
4. Implement only after steps 1-3 are documented and reviewed.

Target documents to produce/extend next:
- `docs/gameplay-parity-gaps.md`
- `docs/lives-and-game-over-logic.md`
- `docs/shields-logic.md`
- `docs/saucer-ufo-logic.md`
- `docs/alien-shot-types-logic.md`
- `docs/alien-graphics-animation-logic.md`
- `docs/graphics-animation-parity.md`
- `docs/explosions-logic.md`

### Remaining Steps
1. Implement full lives UX: HUD lives display, hit/respawn behavior polish.
2. Add game over state and restart flow when lives reach zero.
3. Add wave-clear detection and next-wave setup.
4. Implement bases/shields with damage and collision behavior.
5. Revisit saucer/UFO spawn timing once ISR/vblank pacing replaces busy-wait timing.
6. Expand enemy fire to arcade-like shot families and reload/timing parity.
7. Resolve player sprite parity by isolating shifted-draw interpretation (byte-aligned A/B candidate tables), then lock final player table.
8. Replace placeholder saucer/shield/shot graphics with source-derived monochrome sprite tables.
9. Refine collision parity against original framebuffer overlap behavior (current version uses robust swept slot checks).
10. End-phase optimization: ISR-synchronized rendering to reduce flicker.
11. Audio pass: fire, hit, and alien movement sound effects.

## Build/Run Verification Note
- `make run-zesarux` is the correct command and does rebuild/package before launch.
- Artifact timestamps in `build/zxinvaders.bin` and `dist/zxinvaders.tap` were verified to refresh during iteration.

## Input Mapping
- Left: `O` (row DFFE, bit 1)
- Right: `P` (row DFFE, bit 0)
- Fire: `Space` (row 7FFE, bit 0)

Keys validated working in both KLIVE and ZEsarUX emulator

This mapping is temporary and can be replaced by configurable key/joystick maps.
