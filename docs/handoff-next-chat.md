# Handoff for New Chat: Player Sprite Parity Follow-up

## Why this handoff exists
Alien parity is complete, but player sprite parity is still not visually correct.
This note records what is already verified so the next session can continue from facts, not re-try random transforms.

## Confirmed complete (March 2026)
- Alien graphics are now visually correct in emulator.
- Alien tables are sourced from original ROM bytes (`1C00..1C50`) and transformed with a deterministic pipeline.
- Transform mode currently locked in code: `rot90cw+bitrev`.
- Implementation files:
  - `tools/sprite_transform.py`
  - `src/game/alien_sprites_rom_rotated.z80`
  - `src/game/aliens.z80`

## Current blocker
- Player sprite still appears corrupted/wrong orientation in-game.
- Multiple deterministic transform variants were tried (including GIF-derived extraction), but visible output remains incorrect.
- Build/run command is confirmed correct: `make run-zesarux` rebuilds and regenerates TAP before launch.

## Current repository state
Working tree is dirty (not committed):
- `src/constants.z80` (modified)
- `src/game/enemy_shot.z80` (modified)
- `src/game/player.z80` (modified)
- `src/game/player_hit.z80` (modified)
- `src/game/shot.z80` (modified)
- `src/game/player_sprite_rom_rotated.z80` (new)

Recent commit on `main`:
- `e75701b` Add ROM-derived rotated alien sprites and document parity completion

## What was attempted for player sprite
1. Converted player to both `8x16` and `16x8` render geometries.
2. Tried deterministic modes: `bitrev`, `rot90cw+bitrev`, `rot90ccw+bitrev`, and order variants.
3. Extracted player bitmap directly from `resources/gameplay.gif` and used emitted bytes.
4. Fixed an actual renderer bug where row stepping could spill into attribute RAM for tall sprites.
5. Verified `make run-zesarux` path and artifact timestamps (`build/zxinvaders.bin`, `dist/zxinvaders.tap`).

## Current known issue
Player sprite shape is still visually wrong/corrupted despite deterministic table changes.

## Important technical facts confirmed
1. Original player source bytes at `resources/source.z80:1C60` draw as a 16-row simple sprite in arcade code.
2. ZX player renderer currently uses shifted compositing and can be sensitive to byte-order interpretation for 16-bit rows.
3. `Player_NextScanline` / `PlayerHit_NextScanline` fixes are required to avoid writing into `0x58xx` attribute RAM.
4. The unresolved mismatch is likely in renderer byte interpretation/compositing order, not toolchain rebuild flow.

## Recommendation for next chat (safe sequence)
1. **Freeze on one geometry**
- Keep player as `16x8` for now (to match current renderer path) and avoid switching between `8x16`/`16x8` mid-debug.

2. **Isolate renderer from transform**
- Add a temporary debug mode that forces byte-aligned player X (no shift path).
- If sprite looks correct when aligned but corrupts when shifted, bug is in shift/compositing code.

3. **A/B table debug in-code**
- Keep two hardcoded candidate tables (same shape, different byte orders) and toggle by a constant.
- Choose visually correct table first, then regenerate final table with the script.

4. **Only then finalize docs and commit**
- Update `docs/graphics-animation-parity.md` player section with locked mode and geometry.

## Suggested first prompt for the new chat
"Use `docs/handoff-next-chat.md` as the starting context. Focus only on player sprite parity. Keep current alien implementation unchanged. Add a temporary byte-aligned player draw mode to isolate shift-path corruption, then lock final player table/byte order before committing." 
