# Graphics and Animation Parity (8080 -> ZX)

This document captures how the original 8080 code generates game graphics and animations, and defines the ZX adaptation contract used during and after migration from placeholder art.

Scope for this pass:
- Player sprite
- Alien sprites (3 types, 2 animation frames)
- Saucer sprite and saucer explosion
- Shields
- Player shot and alien shots (rolling, plunger, squiggly)

Color is intentionally out of scope for now. All parity work here is monochrome bitmap behavior.

## Orientation Note (Portrait Arcade vs ZX)

Yes, the original comments explicitly warn about rotated coordinates due to portrait hardware orientation.

Reference:
- `resources/source.z80:3`

Important distinction:
- Coordinate-space rotation (`Xr/Yr` vs `Xn/Yn`) affects movement/collision math and timing logic interpretation.
- Bitmap orientation affects how sprite bytes should be imported (row order, bit order, and possible 90-degree transform).

Current project status:
- Coordinate-space rotation has been considered in movement/logic docs.
- Alien bitmap orientation is validated in-game and now uses ROM-derived rotated tables.
- Player bitmap orientation is validated in-game and now uses ROM-derived `PlayerSprite` data.
- Remaining visual parity work is focused on shield degradation behavior and secondary sprite-side effects (for example saucer score glyph parity), not the core sprite family imports.

### Orientation Verification Gate (Required)

Before replacing any ZX placeholder art, each source sprite set must pass this checklist:

1. Confirm if source bytes are already in gameplay orientation (as commented ASCII art) or need 90-degree transform.
2. Confirm bit significance mapping per row (MSB-left vs LSB-left) against ZX renderer expectations.
3. Validate one known frame in emulator using a test draw at fixed coordinates.
4. If transformed, record exact transform used (`none`, `bit-reverse`, `rotate90cw`, `rotate90ccw`, or combined).
5. Keep collision box and erase path consistent with the final visible orientation.

No sprite table is considered parity-ready until this gate is complete.

## Historical As-Is Audit (Superseded Snapshot)

This section is preserved for implementation traceability. For current authoritative status, use Section 3 ("Current ZX State vs Required Parity") below.

### Summary

- This snapshot captured an earlier state before later parity migrations.
- Most core gameplay sprite families listed here have since been replaced with source-derived assets.
- The most likely required transform is byte-level bit-order conversion, not a universal 90-degree rotate.

### Evidence Snapshot

1. Aliens: placeholder 8x8 pattern in `src/game/aliens.z80:393`, not original type/frame tables.
2. Player ship: simplified 8x8 shape in `src/game/player.z80:209`, not original 16-row `PlayerSprite`.
3. Player explosion: custom 8x8 debris frames in `src/game/player_hit.z80:199`, not original `PlrBlowupSprites`.
4. Saucer: custom compact 16x8 art in `src/game/saucer.z80:511`; source saucer block is 24 rows.
5. Shields: currently solid fill blocks in `src/game/shields.z80:50`, not `ShieldImage` pattern.
6. Shots: player/enemy shots are line primitives in `src/game/shot.z80` and `src/game/enemy_shot.z80`, not sprite-frame families.

### Rotation vs Bit-Order Conclusion (Pre-Implementation)

From source comments and data examples:
- The disassembly warns about rotated coordinate systems (`Xr/Yr`), but this does not automatically imply each bitmap must be rotated 90 degrees.
- Sprite byte comments indicate low-bit-first visual interpretation in several places (for example player shot byte `0x0F` commented as left-side pixels), while ZX rendering paths conventionally treat bit 7 (`0x80`) as the leftmost pixel.

Practical consequence:
- First transform to test for imported sprite bytes is **bit-reversal per byte**.
- Only if visual validation still fails should we test 90-degree transforms.

## Decision Path Before Sprite Replacement

1. For each sprite family, test `direct` vs `bit-reversed-byte` import with fixed-position render.
2. If neither matches expected silhouette, test `rotate90` variants.
3. Lock one transform rule per family and document it inline with the table.
4. Then integrate into gameplay modules.

This keeps us faithful to the source while avoiding over-rotating data that only needed bit-order correction.

## Alien Parity Status (Complete)

Alien graphics are now sourced from original ROM bytes and transformed deterministically.

Implementation:
- ROM source blocks: `resources/source.z80` at `0x1C00..0x1C50`.
- Deterministic conversion utility: `tools/sprite_transform.py`.
- Locked transform pipeline for current renderer: `rot90cw+bitrev`.
- Generated tables committed at: `src/game/alien_sprites_rom_rotated.z80`.
- Runtime selection by row type and frame toggle: `src/game/aliens.z80`.

Validation result:
- In-emulator visual check confirms alien silhouettes now match expected arcade shapes.

## 1. Original 8080 Sprite Generation Pipeline

### 1.1 Descriptor-driven rendering

The 8080 code generally renders from a 5-byte descriptor (`ReadDesc`) containing:
- sprite data pointer (`DE`)
- pixel coordinate (`HL` after load)
- row count in bytes (`B`)

Reference:
- `resources/source.z80:3808` (`ReadDesc`)

### 1.2 Pixel coordinate conversion and horizontal shift

Core routines:
- `CnvtPixNumber`: extracts pixel shift (`x & 7`) and sends it to hardware shifter
- `ConvToScr`: converts pixel number to linear screen byte address (`0x2000` bitmap model)

References:
- `resources/source.z80:2826` (`CnvtPixNumber`)
- `resources/source.z80:3872` (`ConvToScr`)

### 1.3 Draw modes used by game objects

The original uses different compositing modes depending on object type:
- `DrawSprite`: shifted overwrite draw (writes two bytes per row)
- `DrawShiftedSprite`: shifted OR draw (preserves existing bits)
- `EraseShifted`: shifted erase using inverted mask and AND
- `DrawSprCollision`: draw + collision detect side effect

References:
- `resources/source.z80:3131` (`DrawSprite`)
- `resources/source.z80:2730` (`DrawShiftedSprite`)
- `resources/source.z80:2801` (`EraseShifted`)
- `resources/source.z80:2858` (`DrawSprCollision`)

Parity implication for ZX:
- We must preserve per-object blend semantics, not just bitmap bytes.
- Shot and explosion behavior depends on OR/AND style compositing and collision-time draw.

## 2. Bitmap Sources in Original ROM Data

### 2.1 Aliens

Data blocks:
- First pose set at `0x1C00..0x1C2F`
- Second pose set at `0x1C30..0x1C5F`
- 3 alien types, 16 rows per type, 1 byte per row

Reference:
- `resources/source.z80:4091`

Frame selection logic:
- `DrawAlien` maps row to alien type offset.
- If animation flag is non-zero, add `0x30` to switch pose set.

Reference:
- `resources/source.z80:151` (`DrawAlien`)

### 2.2 Player ship and player explosion

Data blocks:
- `PlayerSprite` at `0x1C60` (16 rows)
- `PlrBlowupSprites` at `0x1C70` (two 16-row debris frames)

References:
- `resources/source.z80:4117`
- `resources/source.z80:4137`

Frame toggle behavior:
- Player blowup alternates between two frames by toggling bit 0 and adding 16-byte offset.

Reference:
- `resources/source.z80:663`

### 2.3 Saucer and saucer explosion

Data blocks:
- `SpriteSaucer` at `0x1D64` (24 rows)
- `SpriteSaucerExp` immediately after (24 rows)

Reference:
- `resources/source.z80:4363`

### 2.4 Shields

Data block:
- `ShieldImage` at `0x1D20` (44 bytes = 22 rows x 2 bytes)

Reference:
- `resources/source.z80:4317`

Behavior:
- Four shields are initialized from this pattern.
- Shields are copied/restored between screen and per-player buffers.

References:
- `resources/source.z80:345` (`DrawShieldPl1/Pl2`)
- `resources/source.z80:392` (`CopyShields`)

### 2.5 Shots

Data blocks:
- Player shot sprite and shot explosion blocks around `0x1C9x`
- `SquiglyShot` at `0x1CD0` (4 frames, 3 rows each)
- `PlungerShot` at `0x1CE2` (4 frames, 3 rows each)
- `RollShot` at `0x1CEE` (4 frames, 3 rows each)
- `AShotExplo` at `0x1CDC` (6-byte explosion)

Reference:
- `resources/source.z80:4234`

Frame stepping behavior:
- Active alien shot increments image pointer by 3 bytes each movement step.
- If pointer reaches end-of-set marker, wraps back by 12 bytes to frame 0.

Reference:
- `resources/source.z80:1018` (`MoveAS`)

## 3. Current ZX State vs Required Parity

### 3.1 Player
- Current: complete. The live player sprite now uses ROM-derived `PlayerSprite` bytes from `resources/source.z80:1C60`.
- Locked transform for the current ZX renderer: `rot90cw`.
- Root cause of prior corruption: `Player_Draw` reused `DE` as both the sprite-table pointer and row data storage, self-corrupting the pointer and producing random dot/line output.
- Supporting fix retained: ZX-correct `NextScanline` stepping prevents row writes from spilling into attribute RAM.

Reference:
- `src/game/player.z80:209`

### 3.2 Aliens
- Current: complete for row-specific art and 2-frame animation (3 families x 2 poses).
- Next: keep this transform locked while migrating remaining sprite families.

Reference:
- `src/game/aliens.z80:393`

### 3.3 Saucer
- Current: saucer and saucer-explosion art now use ROM-derived source bytes from `resources/source.z80:1D64` and `resources/source.z80:1D7C`, adapted as 24x8 sprites for the current ZX renderer.
- Motion now uses shifted drawing for 1-pixel horizontal movement rather than byte-step movement.
- Temporary dev hook: `H` simulates a saucer hit while the saucer is flying so the explosion/score path can be tested quickly.
- Remaining gap: score text uses the existing HUD digit font rather than source-matched saucer score glyphs.

Reference:
- `src/game/saucer.z80:511`

### 3.4 Shields
- Current: intact shield art now uses ROM-derived `ShieldImage` source bytes from `resources/source.z80:1D20`, adapted to a 24x16 ZX silhouette for the current renderer.
- Locked orientation: `rot90cw+vflip` source transform, centered in 24px, with final in-game row-orientation adjustment validated against emulator screenshots.
- Shield-impact update: erosion now uses projectile-footprint buffer mutation for player and enemy shots.
- Remaining gap: repeated shield hits still show horizontal striping/corruption, so degradation parity and visual correctness are not yet complete.

Reference:
- `src/game/shields.z80:49`

### 3.5 Shots
- Current:
  - Enemy shots are source-derived, family-specific animated sprites (rolling/plunger/squiggly), rendered as 3x8 monochrome masks with per-family 4-frame cycling.
  - Player shot now uses source-derived `PlayerShotSpr` row pattern from `resources/source.z80:1C90`.
  - Player-shot explosion now uses source-derived `ShotExploding` bytes from `resources/source.z80:1C91`.
  - Alien-shot explosion now uses source-derived `AShotExplo` bytes from `resources/source.z80:1CDC` (padded to the ZX 8-row shot renderer loop).
- Needed:
  - continued late-wave validation that shot source selection only uses live visible aliens

References:
- `src/game/shot.z80:158`
- `src/game/enemy_shot.z80:1`

## 4. ZX Adaptation Contract (Monochrome)

### 4.1 Data ownership
- Create a dedicated sprite data module containing direct 8080-derived bitmaps.
- Keep source labels grouped by object and frame set.
- Include per-table orientation metadata comment (`source orientation`, `transform applied`).

### 4.2 Rendering behavior
- Preserve shifted draw support for pixel X precision.
- Preserve erase semantics to avoid trails and false collisions.
- Keep collision checks tied to actual rendered shape for shots where practical.

### 4.3 Animation behavior
- Aliens: global 2-frame toggle already exists; map to row-specific sprite banks.
- Alien shots: per-family 4-frame cycles, frame advance on each movement step.
- Player blowup and saucer explosion: keep timer-driven toggles from current state machines, swap in authentic bitmaps.

### 4.4 Geometry and timing constraints
- Stick to existing gameplay coordinate system for now (no color pass changes).
- If canonical source dimensions differ from current ZX dimensions (for example saucer height), document explicit adaptation and keep collision boxes consistent with visible sprite.

## 5. Implementation Plan (After This Document)

1. Add `src/game/sprites_arcade.z80` with imported bitmap tables for player, aliens, saucer, shields, and all shot families.
2. Update player and saucer modules to reference arcade bitmap tables.
4. Replace shield block fill with pattern-based shield draw and damage masks.
5. Integrate parity explosion assets for alien-shot blowup paths (`AShotExplo`).
6. Re-run collision tuning after shot/explosion-shape updates.

## 6. Open Decisions Before Coding

1. Saucer height on ZX: keep current compact version or adopt full-height arcade profile.
2. Shield damage model: strict bitmask erosion parity vs staged precomputed masks.
3. Shot collision strategy: exact bitmap overlap vs conservative bounding for performance.

These decisions should be locked before implementation to avoid churn.
