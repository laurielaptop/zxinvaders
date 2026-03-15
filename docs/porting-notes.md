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
- **Task 1 (lives + game-over/restart) is complete**: HUD lives digit renders correctly, lives decrement on hit, game-over mode triggers at zero lives, screen clears and "GAME OVER" banner is shown, and restart is available via fire key or auto-timeout (180 frames).
- **Task 2 (wave-clear detection) is complete**: when all 55 aliens are killed, the screen clears and a full new wave spawns with shields regenerated and the formation starting 8 pixels lower each wave (cycling over 8 waves). Lives and score carry over. See `docs/wave-clear-logic.md`.
- **Task 3 (enemy-shot families, Slices 1–8) is functionally complete**: enemy fire now runs as three dedicated families (rolling/plunger/squiggly) with round-robin scheduling, score-based reload gating, plunger one-alien-left suppression, rolling player-column targeting, squiggly independent table wrap, family-specific 4-frame row-mask animation, and interleaved family motion in the current renderer. Alien scoring updates the full 16-bit score total. Two implementation regressions (TryFire stack corruption and Update loop stack leak) were fixed; gameplay is stable.
- **Gameplay pacing has been tuned up slightly** for iteration: shorter main-loop wait (`Timing_WaitShort`) and faster player shot speed (`SHOT_SPEED=5`).
- **Gameplay pacing has been tuned up again** for broader responsiveness: `Timing_WaitShort` loop reduced to 2800, alien march delay reduced to 7, player shot speed increased to 6, enemy shot speed increased to 3, and enemy family fire delay reduced to 18.
- **Player sprite corruption root cause identified**: `Player_Draw` was clobbering the sprite-table pointer by reusing `DE` for both pointer state and row bytes, producing random dot/line output regardless of table choice. The draw path now keeps the pointer separate.
- **Player sprite parity is now complete**: the final player sprite is locked to the ROM-derived `PlayerSprite` data from `resources/source.z80:1C60`, using the `rot90cw` transform for the current ZX renderer.
- **Alien renderer scanline stepping is corrected for ZX screen layout** to avoid split sprites across memory boundaries.
- **Source-first graphics parity analysis is complete** for player/aliens/saucer/shields/shots and animation frame behavior.
- **Alien sprite parity is complete** (ROM-derived A/B/C row families, 2-frame animation, deterministic transform pipeline).
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
   - HUD: score state init, score rendering, lives digit, and wave number tracking
   - Wave progression: wave-clear detection, formation reinit, wave-specific starting Y (8-wave table from 8080 `AlienStartTable`)

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
- Lives/game-over flow could benefit from a polish pass (arcade-authentic respawn delay suppressing enemy fire, improved messaging/UI).
- Wave progression is implemented, but still needs parity tuning against original pacing and transition timing.
- Saucer bring-up diagnostics have been removed from the main loop after render/timing validation.

### Known Issues
- **Intermittent random colored attribute squares still appear on screen in gameplay.**
   - Symptom: occasional non-gameplay color blocks appear in the bitmap/attribute area.
   - Current understanding: this indicates unintended writes into attribute memory (`0x5800-0x5AFF`).
   - Current primary suspect: legacy sprite scanline stepping using raw `inc h` in draw/erase loops.
   - Progress (2026-03-15): player-shot and saucer draw/erase paths now use ZX-correct scanline stepping and include temporary bitmap write guards (`H < 0x58`).
   - Status: partially mitigated; still unresolved until gameplay confirms no remaining attribute corruption.

### Immediate Stabilization Plan (Short)
1. Remove all remaining unsafe bitmap scanline stepping (`inc h`-only loops) from active gameplay render paths.
2. Add temporary write guards/instrumentation to flag any attempted bitmap write where `HL >= 0x5800`.
3. Re-verify wave transitions and player/enemy shot lifecycles under accelerated pacing (`Timing_WaitShort`, `SHOT_SPEED=6`).
4. Once stable, continue with remaining graphics parity targets (shots, shields, saucer).

### Gameplay Parity Gaps (Confirmed)
- Saucer/UFO bonus target is now implemented (timed top-row flyby + score award based on arcade behavior, with timing currently calibrated for busy-wait frame pacing).
- Alien shot system now implements three-family scheduling and gameplay behavior, but still uses simplified pixel art rather than fully source-matched shot sprites.
- Alien rendering now uses row-specific arcade-derived sprite families and frame toggling.
- Player sprite now matches the original silhouette in-game using ROM-derived data with the locked `rot90cw` transform.
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
- `docs/wave-clear-logic.md` ✅ complete
- `docs/shields-logic.md`
- `docs/saucer-ufo-logic.md`
- `docs/alien-shot-types-logic.md`
- `docs/alien-graphics-animation-logic.md`
- `docs/graphics-animation-parity.md`
- `docs/explosions-logic.md`

### Remaining Steps
1. **Enemy-shot parity polish**: keep the current family scheduler, but replace simplified projectile graphics with source-matched shot pixel art and tighten ISR-timed scheduling precision (see `docs/enemy-fire-logic.md`).
   - Source analysis refresh completed (2026-03-15): scheduler gating (`shotSync`), reload-rate lookup tables (`1CB8`/`1AA1`/`1AA5`), and plunger/squiggly table wrap points are now documented for implementation.
   - Implementation slice 1 completed: scheduler/reload parity state scaffolding (`ENEMY_SHOT_SYNC_PHASE`, `ENEMY_SHOT_RELOAD_RATE`) added without changing current firing behavior.
   - Implementation slice 2 completed: enemy-shot runtime is now split into three dedicated family slots with round-robin family selection, while projectile visuals and firing-source logic remain intentionally simplified.
   - Implementation slice 3 completed: score-based reload-rate gating is now active using arcade-equivalent score thresholds, backed by per-family shot step counters and 16-bit alien score updates.
   - Bug fix (2026-03-15): stack corruption in `EnemyShot_TryFire` — missing `push hl` before `call EnemyShot_PickAlienForFamily` caused a blackout/lockup ~6s into each game. Fixed.
   - Bug fix (2026-03-15): stack leak in `EnemyShot_Update` — per-frame unbalanced push/pop for step-counter wiring caused all aliens to reset when any alien was hit. Rewrote update loop with clean balanced push/pop. Fixed.
   - Slices 1–3 are stable and gameplay-verified.
   - Slices 4–7 implemented: plunger suppression, rolling targeting, squiggly independent table, family-specific 4-frame row-mask animation.
   - Cadence tune (2026-03-15): global family fire-attempt gate reduced from 60 to 20 frames to better match three-family scheduling density while retaining stable guard logic.
   - ISR timing scaffold (2026-03-15): `TIMING_FRAME_PHASE` now ticks 0->1->2 each frame in `Timing_WaitShort`, and `EnemyShot_TryFire` now samples that phase for family selection while retaining the stable 20-frame global fire gate.
   - Slice 8 (2026-03-15): `EnemyShot_Update` now advances only the family matching `TIMING_FRAME_PHASE` each frame (rolling/plunger/squiggly interleave), moving shot motion closer to original staggered scheduler behavior.
   - Follow-up parity polish remains: ISR-timed scheduling precision and fully source-matched shot pixel art in a wider shifted-sprite renderer path.
2. Resolve the **attribute-square known issue** (unexpected writes into attribute RAM during gameplay).
3. Revisit/complete shields parity details (damage/collision behavior remains simplified).
4. Revisit saucer/UFO spawn timing once ISR/vblank pacing replaces busy-wait timing.
5. Replace placeholder saucer/shield/shot graphics with source-derived monochrome sprite tables.
6. Refine collision parity against original framebuffer overlap behavior (current version uses robust swept slot checks).
7. End-phase optimization: ISR-synchronized rendering to reduce flicker.
8. Audio pass: fire, hit, and alien movement sound effects.

## Build/Run Verification Note
- `make run-zesarux` is the correct command and does rebuild/package before launch.
- Artifact timestamps in `build/zxinvaders.bin` and `dist/zxinvaders.tap` were verified to refresh during iteration.

## Input Mapping
- Left: `O` (row DFFE, bit 1)
- Right: `P` (row DFFE, bit 0)
- Fire: `Space` (row 7FFE, bit 0)

Keys validated working in both KLIVE and ZEsarUX emulator

This mapping is temporary and can be replaced by configurable key/joystick maps.
