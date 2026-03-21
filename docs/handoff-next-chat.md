# Handoff for New Chat: Shield Erosion Complete — Polish Phase

## Why this handoff exists

The shield system is now functionally correct. This handoff captures the end state of the shield work and the next sensible tasks.

Primary task tracker: `docs/remaining-checklist.md`.

## Confirmed complete (March 2026)

- Alien graphics visually correct in emulator (ROM-sourced, locked transform).
- Player sprite parity complete (ROM-sourced, locked transform).
- Saucer: ROM-derived art, 1-pixel shifted movement, dev-only `H` key hit simulation.
- Shield architecture redesigned to match arcade: drawn once at init/wave-start, never erased/redrawn.
- Shield erosion: `Shields_PunchChannel` clears an 8-row vertical channel directly on the ZX screen bitmap per hit.
- Shield collision: AABB fast-reject + pixel-level screen-byte read; shots pass through fully-eroded columns.
- Player shots correctly blocked and stopped at shields (HL preservation fix in `shot.z80`).
- Enemy shots correctly spawn and continue firing after first volley (outer-loop B register fix in `enemy_shot.z80`).
- Enemy shots blocked by shields; shot passes through when shield column is fully eroded.

## Current repository state

- Latest commit on `main`: see `git log -1`.
- Working tree clean after this session's commit.

## Confirmed complete (March 2026, continued)

- Enemy shots pass through eroded shield channels: `Shields_CheckCollision` now tests the specific bit at shot_X (not the whole byte), preventing false collisions from adjacent intact pixels in the same screen byte.
- Erosion channels widened to match arcade shot pattern widths: enemy 5 px (0xF8), player 6 px (0xFC).
- Player AABB collision confirmed: enemy shots reliably kill the player after passing through/below shields.

## P1 priorities for next session

1. **Wave/march parity timing** — pre-wave pause, march speed ramp, late-wave cadence.
2. **Enemy-shot timing/cadence polish** — source-trace validation of fire delay and volley density.
3. **Saucer timing parity** — busy-wait → ISR-aligned spawn; source-like score glyph.
4. **Attribute-memory safety sweep** — write-guard instrumentation if corruption recurs.

## P2 (end-phase)

- ISR/vblank-synchronized timing (replace busy-wait pacing).
- Flicker reduction via render optimization.
- Audio: shot/fire/hit/march cues.

## Important technical facts

1. `make run-zesarux` rebuilds and runs the latest TAP correctly.
2. `Video_CalcAddress`: input A=X, C=Y; output HL=screen address; preserves B, C, D, E; clobbers A and HL.
3. Shields are permanent screen content — never call `Shields_Erase` or `Shields_Draw` from the main loop.
4. `Shields_PunchChannel` signature: `B=shot_X, C=Y_start, D=row_count, E=mask_byte`.
5. `Shields_CheckCollision` signature: `B=X, C=Y, A=width`; returns A=shield_index or 0xFF.
6. Z80 constraint: `ld (nn), r` is only valid for A — other registers must go through the accumulator.
7. Player sprite parity and shield art are locked; do not reopen unless new visual evidence appears.

## Suggested first prompt for the new chat

"Use `docs/handoff-next-chat.md` and `docs/remaining-checklist.md` as starting context. Shield erosion and collision are complete. Focus next on enemy-shot timing/cadence polish and wave/march parity, while monitoring for attribute-memory corruption."
