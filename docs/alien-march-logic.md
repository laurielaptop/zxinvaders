# Alien March Logic Reference

## Overview
The original Space Invaders uses a "reference alien" system where one alien (bottom-left, the last to be destroyed) serves as the anchor point, and all other aliens are drawn relative to it. The rack moves horizontally until hitting edges, then steps down.

## Original 8080 Implementation

### Key Routines from `source.z80`

#### InitRack: Initialize Alien Formation (00B1-00D6)
```asm
InitRack:
; Initialize the player's rack of aliens. Copy the reference-location and deltas from the
; player's data bank.
;
00B1: CD 86 08        CALL    GetAlRefPtr         ; Get current player's ref-alien position pointer
00B4: E5              PUSH    HL                  ; Hold pointer
00B5: 7E              LD      A,(HL)              ; Get player's ...
00B6: 23              INC     HL                  ; ... ref-alien ...
00B7: 66              LD      H,(HL)              ; ...
00B8: 6F              LD      L,A                 ; ... coordinates
00B9: 22 09 20        LD      (refAlienYr),HL     ; Set game's reference alien's X,Y
00BC: 22 0B 20        LD      (alienPosLSB),HL    ; Set game's alien cursor bit position
00BF: E1              POP     HL                  ; Restore pointer
00C0: 2B              DEC     HL                  ; Point to ref alien's delta (left or right)
00C1: 7E              LD      A,(HL)              ; Get ref alien's delta X
00C2: FE 03           CP      $03                 ; If there is one alien it will move right at 3
00C4: C2 C8 00        JP      NZ,$00C8            ; Not 3 ... keep it
00C7: 3D              DEC     A                   ; If it is 3, back it down to 2 until it switches again
00C8: 32 08 20        LD      (refAlienDXr),A     ; Store alien deltaY
00CB: FE FE           CP      $FE                 ; Moving left?
00CD: 3E 00           LD      A,$00               ; Value of 0 for rack-moving-right
00CF: C2 D3 00        JP      NZ,$00D3            ; Not FE ... keep the value 0 for right
00D2: 3C              INC     A                   ; It IS FE ... use 1 for left
00D3: 32 0D 20        LD      (rackDirection),A   ; Store rack direction
00D6: C9              RET                         ; Done
```

#### CursorNextAlien: Advance Alien Cursor (0141-0179)
```asm
CursorNextAlien:
; This is called from the mid-screen ISR to set the cursor for the next alien to draw.
; When the cursor moves over all aliens then it is reset to the beginning and the reference
; alien is moved to its next position.
;
; The flag at 2000 keeps this in sync with the alien-draw routine called from the end-screen ISR.
; When the cursor is moved here then the flag at 2000 is set to 1. This routine will not change
; the cursor until the alien-draw routine at 100 clears the flag. Thus no alien is skipped.
;
0141: 3A 68 20        LD      A,(playerOK)        ; Is the player ...
0144: A7              AND     A                   ; ... blowing up?
0145: C8              RET     Z                   ; Yes ... ignore the aliens
0146: 3A 00 20        LD      A,(waitOnDraw)      ; Still waiting on ...
0149: A7              AND     A                   ; ... this alien to be drawn?
014A: C0              RET     NZ                  ; Yes ... leave cursor in place
014B: 3A 67 20        LD      A,(playerDataMSB)   ; Load alien-data ...
014E: 67              LD      H,A                 ; ... MSB (either 21xx or 22xx)
014F: 3A 06 20        LD      A,(alienCurIndex)   ; Load the xx part of the alien flag pointer
0152: 16 02           LD      D,$02               ; When all are gone this triggers 1A1 to return from stack
0154: 3C              INC     A                   ; Have we drawn all aliens ...
0155: FE 37           CP      $37                 ; ... at last position (55 aliens = 0x37)?
0157: CC A1 01        CALL    Z,MoveRefAlien      ; Yes ... move the ref alien and reset index to 0
015A: 6F              LD      L,A                 ; HL now points to alien flag
015B: 46              LD      B,(HL)              ; Is alien ...
015C: 05              DEC     B                   ; ... alive?
015D: C2 54 01        JP      NZ,$0154            ; No ... skip to next alien
0160: 32 06 20        LD      (alienCurIndex),A   ; New alien index
0163: CD 7A 01        CALL    GetAlienCoords      ; Calculate bit position and type for index
0166: 61              LD      H,C                 ; MSB in C
0167: 22 0B 20        LD      (alienPosLSB),HL    ; Store new bit position
016A: 7D              LD      A,L                 ; Has this alien ...
016B: FE 28           CP      $28                 ; ... reached the end of screen?
016D: DA 71 19        JP      C,$1971             ; Yes ... kill the player
0170: 7A              LD      A,D                 ; This alien's ...
0171: 32 04 20        LD      (alienRow),A        ; ... row index
0174: 3E 01           LD      A,$01               ; Set the wait-flag for the ...
0176: 32 00 20        LD      (waitOnDraw),A      ; ... draw-alien routine to clear
0179: C9              RET                         ; Done
```

#### MoveRefAlien: Move Reference Alien (01A1-01BE)
```asm
MoveRefAlien:
; The "reference alien" is the bottom left. All other aliens are drawn relative to this
; reference. This routine moves the reference alien (the delta is set elsewhere) and toggles
; the animation frame number between 0 and 1.
;
01A1: 15              DEC     D                   ; This decrements with each call to move
01A2: CA CD 01        JP      Z,ReturnTwo         ; Return out of TWO call frames (only if no aliens left)
01A5: 21 06 20        LD      HL,$2006            ; Set current alien ...
01A8: 36 00           LD      (HL),$00            ; ... index to 0
01AA: 23              INC     HL                  ; Point to DeltaX
01AB: 4E              LD      C,(HL)              ; Load DX into C
01AC: 36 00           LD      (HL),$00            ; Set DX to 0
01AE: CD D9 01        CALL    AddDelta            ; Move alien
01B1: 21 05 20        LD      HL,$2005            ; Alien animation frame number
01B4: 7E              LD      A,(HL)              ; Toggle ...
01B5: 3C              INC     A                   ; ... animation ...
01B6: E6 01           AND     $01                 ; ... number between ...
01B8: 77              LD      (HL),A              ; ... 0 and 1
01B9: AF              XOR     A                   ; Alien index in A is now 0
01BA: 21 67 20        LD      HL,$2067            ; Restore H ...
01BD: 66              LD      H,(HL)              ; ... to player data MSB (21 or 22)
01BE: C9              RET                         ; Done
```

## Pseudo-Code Translation

### High-Level Behavior
```
EVERY_FRAME:
    cursor = nextAliveAlien(cursor)
    
    IF cursor wrapped around (all 55 aliens processed):
        CALL MoveReferenceAlien()
        cursor = 0
    
    drawAlien(cursor)

MoveReferenceAlien():
    refAlien.x += deltaX  // deltaX is +2 or -2 (or +3 for last alien)
    refAlien.y += deltaY  // deltaY is usually 0, except during descent
    
    animationFrame = (animationFrame + 1) & 1  // Toggle 0 <-> 1
    
    IF refAlien hits left edge:
        deltaX = +2  // Start moving right
        deltaY = +8  // Step down one row
    
    IF refAlien hits right edge:
        deltaX = -2  // Start moving left
        deltaY = +8  // Step down one row
    
    AFTER descent complete:
        deltaY = 0   // Stop vertical movement
```

### Key State Variables
```
refAlienX, refAlienY      // Reference alien (bottom-left) position
alienCursorIndex          // Which alien (0-54) to process this frame
deltaX                    // Horizontal movement: +2 (right) or -2 (left)
deltaY                    // Vertical movement: 0 (normal) or +8 (descent)
rackDirection             // 0=right, 1=left
animationFrame            // 0 or 1 (toggled each move)
waitOnDraw                // Sync flag between ISR and draw routine
```

### Movement Rules
1. **One alien per frame**: The cursor advances through alive aliens, drawing one per frame
2. **After full sweep**: When all 55 aliens have been visited, the reference alien moves
3. **Edge detection**: When reference alien hits screen edge:
   - Reverse horizontal direction
   - Add vertical descent (+8 pixels)
4. **Animation**: Sprite alternates between two frames on each move
5. **Speed**: Movement speed increases as aliens are destroyed (fewer aliens = faster iteration)

## Adaptation Notes for ZX Spectrum

### What We're Keeping
- Reference alien system (bottom-left anchor)
- One-alien-per-frame update pattern
- Edge detection triggers direction reversal + descent
- Animation frame toggle on movement
- Speed increases naturally as aliens die

### What We're Adapting
- **Coordinate system**: Original uses rotated screen, we use standard X/Y
- **Timing**: Original tied to ISR mid-screen refresh, we use frame-based loop
- **Screen bounds**: Adjust edge detection for Spectrum screen dimensions
- **Drawing**: Use Spectrum bitmap addressing instead of original hardware

### Implementation Strategy
1. Add `refAlienX`, `refAlienY`, `deltaX`, `deltaY` to game state
2. Change `Aliens_Draw` to draw relative to reference alien
3. Add `Aliens_Move` function called after drawing all aliens:
   - Apply delta to reference alien
   - Check edge bounds
   - Toggle direction/descent on edge hit
   - Toggle animation frame
4. Natural speed-up: fewer alive aliens = faster iteration = faster apparent movement

## Constants from Original
```
ALIEN_COUNT = 55 (0x37)
ALIEN_ROWS = 5
ALIEN_COLS = 11
DELTA_RIGHT = +2
DELTA_LEFT = -2 (0xFE in two's complement)
DELTA_DOWN = +8
LAST_ALIEN_DELTA = +3  // When only one alien left, moves faster
```

## Implementation Status In Project
Current project code already implements the core behavior described above:
1. `Aliens_Move` updates reference position with edge reversal and descent.
2. `Aliens_Draw` and `Aliens_Erase` use reference-relative positions across the 5x11 grid.
3. Movement state bytes (`ALIEN_REF_*`, `ALIEN_DELTA_*`, `ALIEN_MOVE_COUNTER`) are integrated.
4. Edge descent behavior has been validated during gameplay testing.

## Remaining March-Related Improvements
1. Add optional speed ramp parity as alien count drops (closer to arcade pacing).
2. Integrate game-over boundary logic when formation reaches player zone.
3. Migrate movement/render cadence to ISR-driven timing near end-of-project optimization phase.

---
*Reference extracted from `resources/source.z80` - Original Space Invaders arcade ROM disassembly*
