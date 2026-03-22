# Handoff: Six Live-Play Bugs Documented, Ready for Fixes

Primary task tracker: `docs/remaining-checklist.md` — six new P1 items at the top.

## Six live-play bugs documented (2026-03-22)

All root-cause analysis is in the P1 section of `docs/remaining-checklist.md`.
Short summary for quick orientation:

1. **Alien hit blocked by active explosion** — `AlienHit_OnHit` drops new hits silently when
   `ALIEN_EXPLODING ≠ 0xFF`. Fix: accept new hit, restart explosion from new position.
   File: `src/game/alien_hit.z80`.

2. **HUD digit font too heavy** — replace `HUD_DIGITS` table with digits extracted from the
   arcade ROM font at `source.z80` 0x1ED0–0x1F18; apply `rot90cw` transform (same as alien
   sprites). File: `src/game/hud.z80`.

3. **Alien type order inverted** — `Aliens_SelectValidationSprite` maps TypeA to top rows,
   TypeC to bottom. Arcade has TypeC (octopus, 30pts) at top, TypeA (squid, 10pts) at bottom.
   Invert the threshold. File: `src/game/aliens.z80`.

4. **Enemy shot XOR-erase leaves remnants** — `EnemyShot_EraseSpriteRow` XORs the CURRENT
   animation frame, which may differ from the drawn frame (step_counter advances each frame).
   Fix: erase with zero-write rather than XOR. File: `src/game/enemy_shot.z80`.

5. **Shields erased by dead alien slots during descent** — `Aliens_DrawDead` writes zeros for
   ALL dead slots every frame, including those in the shield Y zone (Y=144–159).
   Fix: skip dead-slot zeroing when the slot's Y falls within the shield zone.
   File: `src/game/aliens.z80`.

6. **Edge detection ignores dead outer columns** — `Aliens_Move` checks raw `ALIEN_REF_X`
   against fixed constants derived from a full formation. When outer columns die, the formation
   reverses too early. Fix: scan for leftmost/rightmost live column and use actual live-edge X
   for comparison. File: `src/game/aliens.z80`.

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

"Use `docs/handoff-next-chat.md` and `docs/remaining-checklist.md` as starting context. Six live-play bugs are documented in the P1 section of the checklist. Fix them one at a time, starting with issue 3 (alien type order) as it is the smallest change, then issue 1 (explosion blocks hit), issue 4 (shot remnants), issue 5 (shields erased by dead slots), issue 6 (edge detection), and finally issue 2 (font replacement)."
