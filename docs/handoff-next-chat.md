# Handoff for New Chat: Post-Player-Parity Next Steps

## Why this handoff exists
Player sprite parity is now complete. This handoff captures the verified end state and the most sensible next tasks so a future session can resume without re-opening solved work.

Primary task tracker for follow-up work: `docs/remaining-checklist.md`.

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
2. Complete shield degradation parity and fix shield-impact regressions (including frozen alien-shot shield explosions).
3. Tighten enemy-shot parity from functional to visual/timing polish (cadence/cleanup/source-trace validation).

## Current known regressions at wrap-up
- Shield hits from both player and alien shots currently show explosion visuals but do not damage the shield bitmap.
- Alien-shot shield explosions can freeze just above the shield line.
- Enemy-shot behavior below the shields still needs a source-trace/debug pass before more parity work.

## Important technical facts confirmed
1. `make run-zesarux` rebuilds/package-runs the latest TAP correctly.
2. `Player_NextScanline` / `PlayerHit_NextScanline` fixes are required to avoid attribute RAM spill during tall sprite stepping.
3. Player parity is solved; do not reopen table-orientation experiments unless new evidence appears.
4. Shields now use source-derived intact art; remaining shield work is degradation/collision parity.
5. Saucer visuals now use ROM-derived ship/explosion art with shifted 1-pixel movement; temporary `H` key hit simulation exists for development-only testing.

## Recommended next chat focus
Start from the documented shield-impact regressions, trace the original 8080 shot blow-up/shield logic, and then fix shield degradation plus the frozen alien-shot explosion path while keeping an eye out for any recurrence of attribute-memory corruption during testing.

## Suggested first prompt for the new chat
"Use `docs/handoff-next-chat.md` and `docs/remaining-checklist.md` as the starting context. Player sprite parity, shield intact art, and saucer visuals are locked; continue with shield degradation/regression fixes and enemy-shot timing polish while monitoring for any attribute-memory corruption recurrence." 
