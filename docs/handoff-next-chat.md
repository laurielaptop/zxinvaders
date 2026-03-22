# Handoff: Presentation Pass in Progress

Primary task tracker: `docs/remaining-checklist.md`.

## Confirmed complete (2026-03-22, this session)

- **Player left-edge clamping** fixed (`cp 0` after `sub 3` was clearing carry; removed it).
- **Wave transition** fixed (`Video_ClearBitmap` was overwriting attribute area; now clears bitmap only).
- **March speed ramp**: `delay = max(3, ALIEN_COUNT_REMAINING >> 2)`.
- **Pre-wave pause**: 30-frame `WAVE_CLEAR_TIMER` countdown before `Aliens_NewWave`.
- **Enemy-shot cadence**: initial reload-rate guard halved (0x30 → 0x18); eliminates 3–4 s dry spells at score ≤ 200.
- **Saucer timing parity**: speed 1→2 px/frame (~7 s traversal), init delay 256→400 frames (~25 s interval), alien-count gate (≥8 required to spawn).
- **Colour — green zone**: `Video_SetGreenZone` sets attribute rows 18–23 (Y=144–191) to green ink on black paper at game start. Covers shields, the gap, and the player row. Persists across waves.
- **ZRCP remote debugging**: `tools/zrcp_monitor.py`, `make dev`, `make monitor`. Measured loop rate ~16 fps.
- All timing constants calibrated to ~16 fps measured game-loop rate.

## Open — P2 presentation items (next up)

1. **Game Over screen** — show "GAME OVER" when player exhausts lives; return to attract loop after a short delay. Files: `src/main.z80`.
2. **In-game HUD** — score + hi-score at top of screen, remaining lives as player-ship sprite icons at bottom. Files: `src/game/hud.z80`, `src/main.z80`.
3. **Start/attract screen** — title, hi-score table, alien score table, 1P/2P selection (no credit count). Files: new `src/game/attract.z80`, `src/main.z80`.

## Open — P3 technical

- ISR/vblank-synchronized timing (replace busy-wait ~16 fps pacing).
- Flicker reduction (post-ISR).
- Audio: shot/fire/hit/march/saucer cues.

## Important technical facts

1. `make run-zesarux` rebuilds and runs the latest TAP.
2. `Video_CalcAddress`: input A=X, C=Y; output HL=screen address; preserves B,C,D,E; clobbers A,HL.
3. `Video_SetGreenZone` sets rows 18–23 green; `Video_ClearBitmap` does NOT touch attributes.
4. `SCREEN_ATTRS = 0x5800`; attribute for row r, col c = `0x5800 + r*32 + c`.
5. `ATTR_GREEN = 0x04` (ink green, paper black); `ATTR_WHITE = 0x07` (ink white, paper black).
6. Shields are permanent screen content — never erase/redraw from the main loop.
7. `Shields_PunchChannel`: B=shot_X, C=Y_start, D=row_count, E=mask_byte.
8. `Shields_CheckCollision`: B=X, C=Y, A=width; returns A=shield_index or 0xFF.
9. Z80: `ld (nn), r` only valid for A — other registers need accumulator.
10. Game loop runs at ~16 fps (busy-wait). All cadence constants reflect this.

## Suggested first prompt for the new chat

"Use `docs/handoff-next-chat.md` and `docs/remaining-checklist.md` as starting context. Green colour zone is complete. Next: Game Over screen, then in-game HUD, then start/attract screen."
