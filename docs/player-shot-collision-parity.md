# Player Shot vs Alien Collision Parity

## Why This Exists

Collision was unreliable because the port used one geometric sample (`shot Y` only) instead of the original arcade's pixel-overlap flow. This document captures the original behavior and the matching implementation in this port.

## Original Arcade Flow (8080)

Relevant routines in `resources/source.z80`:

- `MovePlyShot` (`0x040A`): draws the shot using `DrawSprCollision`.
- `DrawSprCollision` (`0x1491`): for each shot pixel row, it tests overlap with existing screen bits:
  - shifted sprite byte `AND` screen byte
  - if non-zero, sets `collision=1`
- `PlayerShotHit` (`0x14D8`): only runs meaningful alien hit logic when `collision != 0` and `alienIsExploding != 0`.
- `FindRow` / `FindColumn` (`0x1562` / `0x156F`): map shot coordinates to rack row/column.
- Alive check at computed row/column:
  - alive -> alien explodes and scores
  - dead -> treat as other-hit (bullet/shield/miss path)

Key property: collision is pixel-overlap driven, not a single bounding-box sample.

## Ported Behavior (Current)

Implemented in `src/game/aliens.z80`:

- `Aliens_Move` runs before collision so checks use the same positions that are rendered.
- `Aliens_CheckShotCollision` performs swept rectangle checks against all live alien slots:
  - X overlap against each alien's rendered slot X
  - Y overlap using `[currentY .. previousY + SHOT_HEIGHT - 1]`
  - alive-flag validation in `ALIEN_GRID_BASE`
- On hit:
  - explosion position uses the exact scanned slot coordinates
  - alien index uses row/column mapping (`row*11 + col`)
  - shot is consumed even if an explosion is already active (prevents column pass-through)

## Intentional Differences vs Original

- Original uses rendered framebuffer overlap (`DrawSprCollision`).
- Port uses swept slot-overlap checks against live grid state.

This is robust for current engine architecture, but not yet a byte-for-byte clone of the original overlap path.

## Debug Checklist

If collisions still feel wrong, check:

1. `SHOT_SPEED` and `SHOT_HEIGHT` relation in `src/constants.z80`.
2. Rack reference coords (`ALIEN_REF_X`, `ALIEN_REF_Y`) update timing vs collision call order.
3. `ALIEN_SPRITE_DATA` silhouette (sparse pixels can make shots pass through visual holes, which is authentic).
4. Explosion drawing path passes `A=X` and `C=Y` into `Video_CalcAddress` (critical for correct column placement).
5. Whether an active explosion is intentionally consuming additional overlapping shots (current behavior: yes).
