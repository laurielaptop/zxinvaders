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

### Constraints

1. **Memory**: ZX bitmap is non-linear; screen row offset is 0x0100 (256), not 0x0020 (32) as in arcade.
2. **Sprite Format**: Instead of arcade byte-oriented bitmap, use ZX bit-shifted rendering.
3. **Damage Model**: Arcade uses OR with collision data; ZX will use AND-NOT to degrade shields.

### Implementation Plan

1. Define 4 shield initial patterns (bite-damaged variants for degradation).
2. Maintain shield states in RAM (one byte per shield tracking degradation level 0–3).
3. Draw shields based on current degradation state + reference alien offset (like aliens).
4. On shot collision with shield: increment degradation, redraw shield sprite.
5. On player wipe/level reset: restore shields to full state.

### Proposed ZX Addition to `src/constants.z80`

```z80
; Shields
SHIELD_COUNT: equ 4
SHIELD_ROWS: equ 22
SHIELD_COLS: equ 2
SHIELD_HEIGHT: equ 16      ; Visual representation on ZX
SHIELD_WIDTH: equ 16       ; Visual representation on ZX
SHIELD_DAMAGE_STAGES: equ 4 ; 0=intact, 1=1bite, 2=2bites, 3=destroyed
SHIELD_BASE_Y: equ 144     ; Y position (above player, below aliens)
SHIELD_BASE_X: equ 32      ; Start X position

; Shield state: one byte per shield (damage level)
SHIELD_STATE: equ GAME_RAM_BASE + 240    ; 4 bytes
```

### Proposed ZX Implementation File

Create `src/game/shields.z80`:
- `Shields_Init`: Initialize 4 shields to full state
- `Shields_Draw`: Draw all 4 shields based on damage state
- `Shields_Erase`: Erase shields before redraw
- `Shields_OnCollision`: Increment damage when shot hits shield
- `Shields_CheckCollision`: Test if projectile collides with shields
- `Shields_Reset`: Restore all shields to full state (level/game reset)

## Integration Points

1. **Player shot collision** (`src/game/player_shot.z80`):
   - After collision check, also test shield collision.
   - If collision: call `Shields_OnCollision`, increment damage, create visual feedback.

2. **Enemy shot collision** (`src/game/enemy_shot.z80`):
   - Similar integration: test shield collision, increment damage if hit.

3. **Game init** (`src/main.z80`):
   - Call `Shields_Init` at wave/game start.

4. **Draw loop** (`src/main.z80`):
   - Call `Shields_Erase` and `Shields_Draw` in standard erase-update-draw cadence.

---

*Reference: Original Space Invaders arcade 8080 assembly, addresses 0x01EF–0x0245, 0x021E–0x0245, 0x1A7C–0x1490*
