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
- Latest relevant commit on `main`: `022af87` — ignore local VS Code settings.
- Working tree should be clean apart from any local editor metadata such as `.vscode/`.

## Highest-value remaining work
1. Continue monitoring the historical attribute-memory corruption issue; it was not reproduced during the latest player-parity and shield-art session.
2. Replace remaining placeholder shot/saucer graphics with source-derived monochrome sprite tables and complete shield degradation parity.
3. Tighten enemy-shot parity from functional to visual/timing polish (source-matched shot art, ISR-timed precision later).

## Important technical facts confirmed
1. `make run-zesarux` rebuilds/package-runs the latest TAP correctly.
2. `Player_NextScanline` / `PlayerHit_NextScanline` fixes are required to avoid attribute RAM spill during tall sprite stepping.
3. Player parity is solved; do not reopen table-orientation experiments unless new evidence appears.
4. Shields now use source-derived intact art; remaining shield work is degradation/collision parity.

## Recommended next chat focus
Continue with source-derived shot or saucer graphics, while keeping an eye out for any recurrence of attribute-memory corruption during testing.

## Suggested first prompt for the new chat
"Use `docs/handoff-next-chat.md` as the starting context. Player sprite parity is complete and intact shield art is now ROM-derived; continue with source-derived shot or saucer graphics and keep monitoring for any attribute-memory corruption recurrence." 
