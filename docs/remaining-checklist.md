# Remaining Work Checklist

This checklist consolidates the current parity and stabilization work that is still open.

## P0 - Fix current gameplay regressions

- [ ] Implement shield degradation on impact for both player and enemy shots.
  - Evidence: impacts currently explode but do not consume shield pixels.
  - Primary docs: `docs/handoff-next-chat.md`, `docs/gameplay-parity-gaps.md`, `docs/shields-logic.md`.
  - Done when: repeated shield hits visibly erode shield shape and update collision behavior.

- [ ] Fix alien-shot shield explosion freeze above shield line.
  - Evidence: explosion can remain visually frozen one row above shields.
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

- [ ] Shield degradation implementation pass
  - Files: `src/game/shields.z80`, `src/constants.z80`.
  - Deliverables: impact/degradation state model, deterministic mask consumption, and stable redraw/erase behavior.

- [ ] Player-shot shield impact wiring
  - Files: `src/game/shot.z80`, `src/game/shields.z80`.
  - Deliverables: collision consume path that triggers shield damage and uses the correct explosion/cleanup ordering.

- [ ] Enemy-shot shield impact wiring and freeze fix
  - Files: `src/game/enemy_shot.z80`, `src/game/shields.z80`.
  - Deliverables: same-frame explosion draw plus next-frame erase consistency; no frozen frame above shields.

- [ ] Main-loop shield cadence verification
  - Files: `src/main.z80`.
  - Deliverables: shield init/erase/draw/update calls enabled and ordered consistently with shot erase/update/draw cadence.

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
