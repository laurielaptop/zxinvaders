# Protective Shields Logic

## Overview

The original 8080 Space Invaders features **4 protective shields** positioned between the player and the descending alien formation. Each shield is 22 rows tall × 2 bytes wide, displayed on screen and maintained in a player-data buffer.

The shield system:
- Renders 4 shields across the screen (spaced  23 rows apart)
- Stores shield state in RAM per player (multi-player memory persistence)
- Allows shields to be "eaten away" by alien shots and player shots hitting them
- Restores shields at game reset or player switch

## Original 8080 Implementation

### Draw Shield Pattern (0x01EF–0x0208)

```asm
DrawShieldPl1:
; Draw the shields for player 1 (draws it in the buffer in the player's data area).
01EF: 21 42 21        LD      HL,$2142            ; Player 1 shield buffer
01F2: C3 F8 01        JP      $01F8               ; Common draw point

DrawShieldPl2:
; Draw the shields for player 2 (draws it in the buffer in the player's data area).
01F5: 21 42 22        LD      HL,$2242            ; Player 2 shield buffer

; Common code for both players
01F8: 0E 04           LD      C,$04               ; Going to draw 4 shields
01FA: 11 20 1D        LD      DE,$1D20            ; Shield pixel pattern
01FD: D5              PUSH    DE                  ; Hold the start for the next shield
01FE: 06 2C           LD      B,$2C               ; 44 bytes to copy (22 rows x 2 bytes)
0200: CD 32 1A        CALL    BlockCopy           ; Block copy DE to HL (B bytes)
0203: D1              POP     DE                  ; Restore start of shield pattern
0204: 0D              DEC     C                   ; Drawn all shields?
0205: C2 FD 01        JP      NZ,$01FD            ; No ... go draw them all
0208: C9              RET                         ; Done
```

### Copy / Restore Shields (0x021E–0x0245)

```asm
CopyShields:
; A is 1 for screen-to-buffer (remove), 0 for buffer-to-screen (restore)
; HL is screen coordinates of first shield. There are 23 rows between shields.
; DE is sprite buffer in memory.
021E: 32 81 20        LD      (tmp2081),A         ; Remember copy/restore flag
0221: 01 02 16        LD      BC,$1602            ; 22 rows, 2 bytes/row (for 1 shield pattern)
0224: 21 06 28        LD      HL,$2806            ; Screen coordinates (first shield position)
0227: 3E 04           LD      A,$04               ; Four shields to process
0229: F5              PUSH    AF                  ; Hold shield count
022A: C5              PUSH    BC                  ; Hold sprite-size (22 rows x 2 bytes)
022B: 3A 81 20        LD      A,(tmp2081)         ; Get back copy/restore flag
022E: A7              AND     A                   ; Not zero ...
022F: C2 42 02        JP      NZ,$0242            ; ... means remember shields (copy screen -> buffer)
0232: CD 69 1A        CALL    RestoreShields      ; Restore player's shields (copy buffer -> screen)
```

**Screen Layout**:
- First shield at `0x2806` 
- Spacing: `0x02E0` bytes = 23 rows
- 22 rows high, 2 bytes wide per shield

**Restore Operation** (`RememberShields`, 0x1A7C):
```asm
RememberShields:
; In a multi-player game the player's shields are block-copied to and from RAM between turns.
; HL = screen pointer
; DE = memory buffer
; B = number of rows
; C = number of columns
147C: C5              PUSH    BC                  ; Hold counter
147D: E5              PUSH    HL                  ; Hold start
147E: 7E              LD      A,(HL)              ; From sprite
147F: 12              LD      (DE),A              ; ... to buffer
1480: 13              INC     DE                  ; Next in buffer
1481: 23              INC     HL                  ; Next on screen
1482: 0D              DEC     C                   ; All columns done?
1483: C2 7E 14        JP      NZ,$147E            ; No ... do multi columns
1486: E1              POP     HL                  ; Restore screen start
1487: 01 20 00        LD      BC,$0020            ; Add 32 (screen row offset)
148A: 09              ADD     HL,BC               ; ... to get to next row
148B: C1              POP     BC                  ; Pop the counters
148C: 05              DEC     B                   ; All rows done?
148D: C2 7C 14        JP      NZ,RememberShields  ; No ... do multi rows
1490: C9              RET                         ; Done
```

## Key State Variables

```
P1 shield buffer: 0x2142–0x217F (62 bytes)
P2 shield buffer: 0x2242–0x227F (62 bytes)
Screen shields:   0x2806 (and +0x02E0 for each of 4 shields)
```

## ZX Spectrum Adaptation

### Current Status (March 2026)

- Shield placement and erase/draw cadence are implemented.
- Intact shield artwork now uses ROM-derived `ShieldImage` bytes from `resources/source.z80:1D20`.
- Current in-game intact shield geometry: 24x16 pixels (3 bytes/row), matching the validated emulator silhouette.
- Orientation is locked in `ShieldImageZX` and should not be reworked unless new visual evidence appears.
- Player and enemy shots are blocked by shields (pre-draw collision gate).
- Collision bounds are aligned to the same byte boundary used by shield rendering to avoid left-edge pass-through.
- Shield impact wiring now applies projectile footprint masks into the shield buffer (`Shields_OnPlayerShotCollision` / `Shields_OnEnemyShotCollision`).
- Remaining issue: erosion output is still corrupted (horizontal line/banding artifacts after repeated hits), so parity is not complete yet.

### Collision & Degradation Algorithm (Authentic Arcade Behavior)

**From original DrawSprCollision routine (0x1491 in source.z80):**

The arcade uses a **unified collision/rendering algorithm** for all sprites (player shots, enemy shots, shields):

```asm
; Read sprite pattern byte (shifted)
LD A, (sprite_pattern)          ; Get byte
OUT (SHFT_DATA), A              ; Shift register
IN A, (SHFT_IN)                 ; Read shifted result

; Test collision: sprite AND screen content
AND (HL)                        ; Collision if any bits overlap
JP Z, next                      ; No collision? Skip flag
LD A, 01
LD (collision), A              ; Flag collision detected

; Always OR sprite onto screen (automatic erosion)
LD A, (sprite_pattern)
OR (HL)                         ; Merge bits: sprite OR screen
LD (HL), A                      ; Store degraded bitmap
```

**Key insights:**
- **Shields are not special**: They're ordinary screen bitmap content (0x2806 area)
- **Collision detection**: Pixel-perfect bitwise AND between sprite pattern and screen content
- **Degradation**: Automatic via continuous OR operation during sprite rendering
- **No discrete damage stages**: Arcade uses continuous erosion—bits accumulate as 1s whenever any sprite ORs on top
- **Same routine for all sprites**: Player shots, enemy shots, and even saucer all use DrawSprCollision
- **Result**: Natural "bite mark" appearance emerges from persistent OR operations, without needing pre-defined damage variants

### Constraints

1. **Memory**: ZX bitmap is non-linear; screen row offset is 0x0100 (256), not 0x0020 (32) as in arcade.
2. **Sprite Format**: Instead of arcade byte-oriented bitmap, use ZX bit-shifted rendering.
3. **Damage Integration**: Wire `Shields_CheckCollision` into shot draw paths to test AND collision; erosion then happens naturally when shots render over shields.

### Current ZX Approach

1. Keep one mutable 24x16 bitmap buffer per shield (`SHIELD_BUFFER_BASE`).
2. Initialize/reset each shield from the ROM-derived intact template.
3. On collision, apply the projectile's actual 8-row mask footprint to clear matching pixels in the shield buffer.
4. Draw the shield from buffer every frame in the main erase/update/draw cadence.
5. Keep collision checks byte-aligned to the same shield-left alignment used by draw.

### Active Gap

- The footprint-clearing path still produces horizontal striping corruption in gameplay captures.
- Next debugging focus is row/mask addressing correctness inside `Shields_ApplyProjectileMask` and `Shields_ClearLocalPixel` so only intended local pixels are cleared.

### Proposed ZX Addition to `src/constants.z80`

```z80
; Shields
SHIELD_COUNT: equ 4
SHIELD_ROWS: equ 16
SHIELD_COLS: equ 3
SHIELD_HEIGHT: equ 16      ; Intact shield silhouette height on ZX
SHIELD_WIDTH: equ 24       ; Intact shield silhouette width on ZX
SHIELD_BASE_Y: equ 144     ; Y position (above player, below aliens)
SHIELD_BASE_X: equ 28      ; Start X position (center alignment after widening)

; Shield collision/animation state: one byte per shield
; Tracks collision detection state; degradation is automatic via screen bitmap ORing
SHIELD_STATE: equ GAME_RAM_BASE + 165    ; 4 bytes (collision flags or animation counter)
```

**Note on SHIELD_STATE usage:**
Unlike early designs proposing 4 discrete damage stages (0–3), the arcade uses **continuous bitmap erosion**. The SHIELD_STATE byte per shield can track:
- Collision event flags (for sound/animation effects)
- Animation/redraw cycles
- Hit counter (for gameplay events)

The actual visual degradation is **automatic**: shots rendering over shield pixels naturally degrade them via OR operations on the screen bitmap.

### ZX Implementation File

`src/game/shields.z80` currently provides:
- `Shields_Init`: Initialize 4 shields to full state (copy intact template into per-shield buffers)
- `Shields_Draw`: Draw all 4 shields from their mutable buffers each frame
- `Shields_Erase`: Erase shield draw rectangles before redraw
- `Shields_OnPlayerShotCollision`: Apply player-shot footprint mask on hit
- `Shields_OnEnemyShotCollision`: Apply active enemy-shot frame footprint mask on hit
- `Shields_CheckCollision`: AABB collision test with byte-aligned shield X bounds (INPUT: B=X, C=Y, A=width; OUTPUT: A=shield_index or 0xFF if no hit)
- `Shields_Reset`: Restore all shields to full state (level/game reset)

## Integration Points

1. **Player shot draw path** (`src/game/shot.z80`):
   - Test shield collision during shot update before rendering
   - If collision detected (A ≠ 0xFF): call `Shields_OnPlayerShotCollision`, move shot to one-frame explosion state
   - Result: player shots are blocked by shields from below

2. **Enemy shot draw path** (`src/game/enemy_shot.z80`):
   - Test shield collision during enemy-shot update
   - If hit: call `EnemyShot_GetRenderFramePtrForSlot` and then `Shields_OnEnemyShotCollision` so erosion uses the active animated frame
   - Result: enemy shots are blocked by shields from above

3. **Shields_CheckCollision implementation**:
   - Input: B = X coordinate, C = Y coordinate, A = projectile width
   - Uses AABB overlap checks against per-shield bounds
   - Shield X bounds are byte-aligned to mirror renderer behavior (`Video_CalcAddress` uses `X >> 3`)
   - Return A = shield_index (0–3) if collision found, or 0xFF if no collision

4. **Game init** (`src/main.z80`):
   - Call `Shields_Init` at wave/game start (restores intact artwork from ROM to screen)

5. **Draw loop** (`src/main.z80`):
   - Call `Shields_Erase` and `Shields_Draw` in standard erase-update-draw cadence
   - Note: Shields are drawn EVERY frame; degradation visible because screen bitmap persists from shot ORing

---

*Reference: Original Space Invaders arcade 8080 assembly, addresses 0x01EF–0x0245, 0x021E–0x0245, 0x1A7C–0x1490*
