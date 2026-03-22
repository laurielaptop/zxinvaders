# Remaining Work Checklist

This checklist consolidates the current parity and stabilization work that is still open.

## P0 - Fix current gameplay regressions

- [x] Shield degradation erosion and collision — complete (2026-03-21).
  - Draw-once architecture: shields drawn once at init/wave-start; no per-frame erase/redraw (fixes flashing).
  - `Shields_PunchChannel`: 8-row vertical channel erased directly on ZX screen bitmap per hit.  Player shots erase upward (Y_start = shot_Y − 7); enemy shots erase downward (Y_start = shot_Y).
  - Pixel-level collision check added to `Shields_CheckCollision`: after AABB match, reads screen byte at shot column; returns 0xFF (no collision) if fully eroded, allowing shots to pass through.
  - Register bugs fixed in `src/game/enemy_shot.z80`: outer-loop B clobbered by `ld b,(hl)` (fixed with push/pop around shield-check section); push/pop balanced across all three exit paths.
  - Register bug fixed in `src/game/shot.z80`: HL not preserved around `Shields_OnPlayerShotCollision` call (fixed with push/pop).
  - Primary docs: `docs/shields-logic.md`.
  - Remaining: minor visual polish; shots pass through fully-eroded columns but erosion shape may need tuning.

- [x] Fix alien-shot shield explosion freeze above shield line.
  - Evidence: same-frame explosion draw/next-frame erase ordering now runs without the previously reported stuck frame above shields.
  - Primary docs: `docs/handoff-next-chat.md`, `docs/enemy-fire-logic.md`.
  - Done when: explosion appears and clears cleanly with no stuck frame artifacts.

- [x] Re-validate enemy-shot behavior below shields after shield-impact fixes (2026-03-21).
  - Shots pass through eroded shield channels and reach the player reliably.
  - Player AABB collision confirmed working: shots kill the player.
  - Primary docs: `docs/handoff-next-chat.md`, `docs/gameplay-parity-gaps.md`.

## P1 - Parity polish and timing correctness

- [x] Enemy-shot cadence: initial reload-rate guard halved (2026-03-22).
  - Root cause: `RELOAD_RATE = 0x30` (48 frames) combined with 54-frame per-family rotation caused 3–4 s dry spells at score ≤ 200.
  - Fix: reduced `.rate30` threshold from `0x30` to `0x18` (24 frames), producing ~36-frame shot intervals (0.72 s) in early game.
  - Validated via ZRCP timing monitor: typical intervals 1000–1200 ms; gaps >3 s were the anomaly being addressed.
  - Primary docs: `docs/enemy-fire-logic.md`, `docs/zrcp-debug.md`.
  - Remaining: further cadence tuning if live-play feel still seems too sparse or too dense.

- [ ] Continue monitoring attribute-memory corruption risk.
  - Scope: repeated gameplay sessions with write-guard instrumentation where needed.
  - Primary docs: `docs/porting-notes.md`.
  - Done when: no random attribute squares across repeated long runs.

- [x] Complete wave/march parity timing gaps (2026-03-22).
  - March speed ramp: `delay = max(3, ALIEN_COUNT_REMAINING >> 2)` — formation accelerates as aliens die, matching arcade natural cadence.
  - Pre-wave pause: 30-frame countdown before `Aliens_NewWave`, matching arcade inter-wave delay.
  - Wave transition: fixed `Video_ClearBitmap` bug (was clearing 6912 bytes into attribute area; now correctly clears only the 6144-byte bitmap). Attributes (white-on-black) are preserved across wave transitions.
  - Primary docs: `docs/wave-clear-logic.md`, `docs/alien-march-logic.md`.

- [x] Saucer timing parity pass (2026-03-22).
  - Speed doubled (1→2 px/frame): traversal time ~7 s vs prior ~14.5 s at measured 16 fps game-loop rate.
  - Spawn interval increased (256→400 frames): ~25 s between appearances, matching arcade cadence.
  - Alien-count gate implemented: saucer now suppressed when < 8 aliens remain (was TODO, always allowed).
  - Remaining: ISR-aligned spawn (P2); score glyph visual treatment is functionally correct via HUD digits.

## P2 - End-phase improvements

- [ ] Move from busy-wait pacing to ISR/vblank-synchronized timing.
  - Primary docs: `docs/porting-notes.md`, `docs/alien-march-logic.md`.
  - Done when: frame pacing and scheduler hooks are ISR-driven and stable.

- [ ] Reduce flicker with end-phase render optimization.
  - Primary docs: `docs/porting-notes.md`.
  - Done when: acceptable visual stability under full gameplay load.

- [ ] Audio pass for shot/fire/hit/march cues.
  - Primary docs: `docs/porting-notes.md`.
  - Done when: core gameplay sound events are implemented and balanced.

## Documentation hygiene

- [x] Reconcile docs that disagree on shot-art completion status.
  - Conflict: some notes still say shot art is placeholder while other notes say source-derived shot assets are integrated.
  - Primary docs: `docs/porting-notes.md`, `docs/graphics-animation-parity.md`, `docs/enemy-fire-logic.md`.
  - Done when: all docs present one consistent status and next step.

- [ ] Add missing source-first behavior notes if still needed.
  - Candidates listed in `docs/porting-notes.md`: saucer/alien-shot-types/explosions specific logic notes.
  - Done when: missing behavior docs are either created or explicitly retired as no longer needed.

## Execution Breakdown (File-Targeted)

Use this section to turn P0/P1 items into concrete code-edit sessions.

- [x] Shield degradation + player-shot wiring + enemy-shot wiring + main-loop cadence — complete (2026-03-21).
  - All four sub-items resolved in the same architecture redesign session (see P0 above).

- [x] Lower-field enemy-shot validation pass (2026-03-21).
  - Shot pass-through: fixed `Shields_CheckCollision` to test the specific bit at shot_X (not the whole byte), so eroded channels flanked by intact pixels are correctly treated as gaps.
  - Erosion widened: enemy 3→5 px (0xF8), player 4→6 px (0xFC), matching arcade shot pattern widths.
  - Player AABB collision (from prior session) confirmed: shots kill the player reliably.

- [ ] Attribute-memory safety sweep
  - Files: `src/game/player.z80`, `src/game/player_hit.z80`, `src/game/saucer.z80`, `src/game/shot.z80`, `src/game/enemy_shot.z80`.
  - Deliverables: no unsafe scanline stepping in active draw/erase paths; temporary guards retained or documented.

- [x] Timing parity pass — wave/march portion complete (2026-03-22).
  - Files: `src/platform/video.z80`, `src/game/aliens.z80`, `src/main.z80`, `src/constants.z80`, `src/game/hud.z80`.
  - March speed ramp and pre-wave pause implemented; wave transition stable across multiple waves.

- [ ] Documentation sync pass after each major fix
  - Files: `docs/porting-notes.md`, `docs/gameplay-parity-gaps.md`, `docs/enemy-fire-logic.md`, `docs/remaining-checklist.md`.
  - Deliverables: status, known issues, and checklist checkboxes updated in the same commit as code changes.
