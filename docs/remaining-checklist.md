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

- [ ] Re-validate enemy-shot behavior below shields after shield-impact fixes.
  - Evidence: lower-field traversal/state has been flagged as inconsistent.
  - Primary docs: `docs/handoff-next-chat.md`, `docs/gameplay-parity-gaps.md`.
  - Done when: all families consistently continue to player zone unless consumed by valid collisions.

## P1 - Parity polish and timing correctness

- [ ] Finalize enemy-shot parity polish.
  - Scope: tighter timing precision, shot cleanup consistency, and source-trace validation in edge cases.
  - Primary docs: `docs/porting-notes.md`, `docs/enemy-fire-logic.md`.
  - Done when: visuals and cadence are accepted against source notes and emulator captures.

- [ ] Continue monitoring attribute-memory corruption risk.
  - Scope: repeated gameplay sessions with write-guard instrumentation where needed.
  - Primary docs: `docs/porting-notes.md`.
  - Done when: no random attribute squares across repeated long runs.

- [ ] Complete wave/march parity timing gaps.
  - Scope: pre-wave pause, optional one-alien plunger suppression parity check, march speed ramp behavior.
  - Primary docs: `docs/wave-clear-logic.md`, `docs/alien-march-logic.md`.
  - Done when: transition timing and late-wave cadence match documented source behavior.

- [ ] Revisit saucer timing/glyph parity.
  - Scope: busy-wait to ISR-aligned spawn timing later; source-like score glyph treatment.
  - Primary docs: `docs/porting-notes.md`, `docs/graphics-animation-parity.md`.
  - Done when: saucer behavior no longer listed as a parity gap.

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

- [ ] Lower-field enemy-shot validation pass
  - Files: `src/game/enemy_shot.z80`, `src/game/player_hit.z80`.
  - Deliverables: verified shot traversal into player zone and stable player-hit behavior after shield fixes.

- [ ] Attribute-memory safety sweep
  - Files: `src/game/player.z80`, `src/game/player_hit.z80`, `src/game/saucer.z80`, `src/game/shot.z80`, `src/game/enemy_shot.z80`.
  - Deliverables: no unsafe scanline stepping in active draw/erase paths; temporary guards retained or documented.

- [ ] Timing parity pass (post-stabilization)
  - Files: `src/platform/timing.z80`, `src/game/aliens.z80`, `src/game/enemy_shot.z80`.
  - Deliverables: improved phase/cadence parity with regression tests on wave transitions and enemy fire density.

- [ ] Documentation sync pass after each major fix
  - Files: `docs/porting-notes.md`, `docs/gameplay-parity-gaps.md`, `docs/enemy-fire-logic.md`, `docs/remaining-checklist.md`.
  - Deliverables: status, known issues, and checklist checkboxes updated in the same commit as code changes.
