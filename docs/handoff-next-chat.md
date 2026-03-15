# Handoff for New Chat: Post-Player-Parity Next Steps

## Why this handoff exists
Player sprite parity is now complete. This handoff captures the verified end state and the most sensible next tasks so a future session can resume without re-opening solved work.

## Confirmed complete (March 2026)
- Alien graphics are visually correct in emulator.
- Alien tables are sourced from original ROM bytes (`1C00..1C50`) and use locked transform `rot90cw+bitrev`.
- Player sprite parity is complete.
- Player source bytes come from `resources/source.z80:1C60`.
- Locked player transform for the current ZX renderer: `rot90cw`.
- Root cause of prior player corruption was a renderer bug: `Player_Draw` reused `DE` as both sprite-table pointer and row-data storage.

## Current repository state
- Latest relevant commit on `main`: `170e324` — lock final player sprite parity implementation.
- Working tree should be clean apart from any local editor metadata such as `.vscode/`.

## Highest-value remaining work
1. Resolve intermittent attribute-memory corruption (`0x5800..0x5AFF` writes causing random colored squares).
2. Replace placeholder shot/shield/saucer graphics with source-derived monochrome sprite tables.
3. Tighten enemy-shot parity from functional to visual/timing polish (source-matched shot art, ISR-timed precision later).

## Important technical facts confirmed
1. `make run-zesarux` rebuilds/package-runs the latest TAP correctly.
2. `Player_NextScanline` / `PlayerHit_NextScanline` fixes are required to avoid attribute RAM spill during tall sprite stepping.
3. Player parity is solved; do not reopen table-orientation experiments unless new evidence appears.
4. The main unresolved cross-cutting graphics bug is attribute-memory corruption elsewhere in active render paths.

## Recommended next chat focus
Start with the attribute-square issue. Audit remaining sprite draw/erase loops for raw `inc h` stepping or missing `H < 0x58` guards, then verify in gameplay.

## Suggested first prompt for the new chat
"Use `docs/handoff-next-chat.md` as the starting context. Player sprite parity is complete; focus next on the remaining attribute-memory corruption issue, then move to source-derived shot/shield/saucer graphics." 
