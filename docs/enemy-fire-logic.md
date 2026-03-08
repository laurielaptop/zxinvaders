# Enemy Fire System - Original Arcade Logic

This document extracts and explains the enemy shot system from the original Space Invaders arcade game (8080 assembly from `resources/source.z80`).

## Overview

The arcade game has **three independent alien shot types**, each with different behaviors:
1. **Rolling shot** (Object 2) - Targets player specifically, animated spiral pattern
2. **Plunger shot** (Object 3) - Fires from column table, straight drop, disabled when 1 alien left
3. **Squiggly shot** (Object 4) - Fires from column table, zigzag pattern

All three shots are synchronized using a timer system to prevent all firing simultaneously.

## Original 8080 Assembly - Rolling Shot (Game Object 2)

```asm
; Game object 2: Alien rolling-shot (targets player specifically)
;
; The 2-byte value at 2038 is where the firing-column-table-pointer would be (see other
; shots ... next game objects). This shot doesn't use that table. It targets the player
; specifically. Instead the value is used as a flag to have the shot skip its first
; attempt at firing every time it is reinitialized (when it blows up).
;
; The task-timer at 2032 is copied to 2080 in the game loop. The flag is used as a
; synchronization flag to keep all the shots processed on separate interrupt ticks. This
; has the main effect of slowing the shots down.
;
; When the timer is 2 the squiggly-shot/saucer (object 4 ) runs.
; When the timer is 1 the plunger-shot (object 3) runs.
; When the timer is 0 this object, the rolling-shot, runs.
;
0476: E1              POP     HL                  ; Game object data
0477: 3A 32 1B        LD      A,($1B32)           ; Restore delay from ...
047A: 32 32 20        LD      (obj2TimerExtra),A  ; ... ROM mirror (value 2)
047D: 2A 38 20        LD      HL,(rolShotCFirLSB) ; Get pointer to ...
0480: 7D              LD      A,L                 ; ... column-firing table.
0481: B4              OR      H                   ; All zeros?
0482: C2 8A 04        JP      NZ,$048A            ; No ... must be a valid column. Go fire.
0485: 2B              DEC     HL                  ; Decrement the counter
0486: 22 38 20        LD      (rolShotCFirLSB),HL ; Store new counter value (run the shot next time)
0489: C9              RET                         ; And out

048A: 11 35 20        LD      DE,$2035            ; Rolling-shot data structure
048D: 3E F9           LD      A,$F9               ; Last picture of "rolling" alien shot
048F: CD 50 05        CALL    ToShotStruct        ; Set code to handle rolling-shot
0492: 3A 46 20        LD      A,(pluShotStepCnt)  ; Get the plunger-shot step count
0495: 32 70 20        LD      (otherShot1),A      ; Hold it
0498: 3A 56 20        LD      A,(squShotStepCnt)  ; Get the squiggly-shot step count
049B: 32 71 20        LD      (otherShot2),A      ; Hold it
049E: CD 63 05        CALL    HandleAlienShot     ; Handle active shot structure
04A1: 3A 78 20        LD      A,(aShotBlowCnt)    ; Blow up counter
04A4: A7              AND     A                   ; Test if shot has cycled through blowing up
04A5: 21 35 20        LD      HL,$2035            ; Rolling-shot data structure
04A8: C2 5B 05        JP      NZ,FromShotStruct   ; If shot is still running, copy the updated data and out

ResetShot:
; The rolling-shot has blown up. Reset the data structure.
04AB: 11 30 1B        LD      DE,$1B30            ; Reload ...
04AE: 21 30 20        LD      HL,$2030            ; ... object ...
04B1: 06 10           LD      B,$10               ; ... structure ...
04B3: C3 32 1A        JP      BlockCopy           ; ... from ROM mirror and out
```

## HandleAlienShot Function (0x0563)

```asm
HandleAlienShot:
; Handle the active alien shot (copy data to temp structure, fire/move it, copy back)
0563: 21 73 20        LD      HL,$2073            ; Alien shot temp structure
0566: 06 0D           LD      B,$0D               ; 13 bytes to copy
0568: CD 32 1A        CALL    BlockCopy           ; Copy to temp structure
;
056B: 21 73 20        LD      HL,$2073            ; Temp structure
056E: 7E              LD      A,(HL)              ; Get shot status
056F: E6 80           AND     $80                 ; Is shot active (bit 7)?
0571: C2 C1 05        JP      NZ,MoveAS           ; Yes ... go move the shot
;
; Shot is not active ... try to fire a new one
0574: FE 00           CP      $00                 ; Is shot reloading?
0576: C0              RET     NZ                  ; Yes ... wait till reload done
;
; Make sure it isn't too soon to fire another shot
057C: 3A 70 20        LD      A,(otherShot1)      ; Get the step count of the 1st "other shot"
057F: A7              AND     A                   ; Any steps made?
0580: CA 89 05        JP      Z,$0589             ; No ... ignore this count
0583: 47              LD      B,A                 ; Shuffle off step count
0584: 3A CF 20        LD      A,(aShotReloadRate) ; Get the reload rate (based on MSB of score)
0587: B8              CP      B                   ; Too soon to fire again?
0588: D0              RET     NC                  ; Yes ... don't fire
0589: 3A 71 20        LD      A,(otherShot2)      ; Get the step count of the 2nd "other shot"
058C: A7              AND     A                   ; Any steps made?
058D: CA 96 05        JP      Z,$0596             ; No steps on any shot ... we are clear to fire
0590: 47              LD      B,A                 ; Shuffle off step count
0591: 3A CF 20        LD      A,(aShotReloadRate) ; Get the reload rate (based on MSB of score)
0594: B8              CP      B                   ; Too soon to fire again?
0595: D0              RET     NC                  ; Yes ... don't fire
```

## Column-Firing System

```asm
; Non-tracking shot uses column-firing table
0596: 23              INC     HL                  ; 2075
0597: 7E              LD      A,(HL)              ; Get tracking flag
0598: A7              AND     A                   ; Does this shot track the player?
0599: CA 1B 06        JP      Z,$061B             ; Yes ... go make a tracking shot
059C: 2A 76 20        LD      HL,(aShotCFirLSB)   ; Column-firing table
059F: 4E              LD      C,(HL)              ; Get next column to fire from
05A0: 23              INC     HL                  ; Bump the ...
05A1: 00              NOP                         ; % WHY?
05A2: 22 76 20        LD      (aShotCFirLSB),HL   ; ... pointer into column table
05A5: CD 2F 06        CALL    FindInColumn        ; Find alien in target column
05A8: D0              RET     NC                  ; No alien is alive in target column ... out
;
05A9: CD 7A 01        CALL    GetAlienCoords      ; Get coordinates of alien (lowest alien in firing column)
05AC: 79              LD      A,C                 ; Offset ...
05AD: C6 07           ADD     A,$07               ; ... Y by 7
05AF: 67              LD      H,A                 ; To H
05B0: 7D              LD      A,L                 ; Offset ...
05B1: D6 0A           SUB     $0A                 ; ... X down 10
05B3: 6F              LD      L,A                 ; To L
05B4: 22 7B 20        LD      (alienShotYr),HL    ; Set shot coordinates below alien
;
05B7: 21 73 20        LD      HL,$2073            ; Alien shot status
05BA: 7E              LD      A,(HL)              ; Get the status
05BB: F6 80           OR      $80                 ; Mark this shot ...
05BD: 77              LD      (HL),A              ; ... as actively running
05BE: 23              INC     HL                  ; 2074 step count
05BF: 34              INC     (HL)                ; Give this shot 1 step (it just started)
05C0: C9              RET                         ; Out
```

## FindInColumn Function (0x062F)

```asm
FindInColumn:
; C contains the target column. Look for a live alien in the column starting with
; the lowest position. Return C=1 if found ... HL points to found slot.
062F: 0D              DEC     C                   ; Column that is firing
0630: 3A 67 20        LD      A,(playerDataMSB)   ; Player's MSB (21xx or 22xx)
0633: 67              LD      H,A                 ; To MSB of HL
0634: 69              LD      L,C                 ; Column to L
0635: 16 05           LD      D,$05               ; 5 rows of aliens
0637: 7E              LD      A,(HL)              ; Get alien's status
0638: A7              AND     A                   ; 0 means dead
0639: 37              SCF                         ; In case not 0
063A: C0              RET     NZ                  ; Alien is alive? Yes ... return
063B: 7D              LD      A,L                 ; Get the flag pointer LSB
063C: C6 0B           ADD     A,$0B               ; Jump to same column on next row of rack (+11 aliens per row)
063E: 6F              LD      L,A                 ; New alien index
063F: 15              DEC     D                   ; Tested all rows?
0640: C2 37 06        JP      NZ,$0637            ; No ... keep looking for a live alien up the rack
0643: C9              RET                         ; Didn't find a live alien. Return with C=0.
```

## Tracking Shot (Targets Player)

```asm
; Start a shot right over the player
061B: 3A 1B 20        LD      A,(playerXr)        ; Player's X coordinate
061E: C6 08           ADD     A,$08               ; Center of player
0620: 67              LD      H,A                 ; To H for routine
0621: CD 6F 15        CALL    FindColumn          ; Find the column
0624: 79              LD      A,C                 ; Get the column right over player
0625: FE 0C           CP      $0C                 ; Is it a valid column?
0627: DA A5 05        JP      C,$05A5             ; Yes ... use what we found
062A: 0E 0B           LD      C,$0B               ; Else use ...
062C: C3 A5 05        JP      $05A5               ; ... as far over as we can
```

## Key Concepts

### 1. Three Independent Shot Types
- **Rolling**: Tracks player position, fires at player's column
- **Plunger**: Follows column-firing table, straight drop
- **Squiggly**: Follows column-firing table, zigzag animation

### 2. Synchronization System
- Timer value (`obj2TimerExtra`) cycles 0→1→2
- Each shot type runs on its assigned timer value
- Prevents all three shots firing simultaneously
- Slows down overall fire rate

### 3. Reload Rate System
```
aShotReloadRate (0x20CF) - Based on score MSB
otherShot1/2 (0x2070/0x2071) - Step counts from other two shots
```
- Checks step counts of other active shots
- If either `otherShot` step count < reload rate → don't fire
- Creates spacing between shots based on game difficulty

### 4. Column-Firing Tables
Each non-tracking shot has a firing column table:
- Plunger: 16 entries starting at ROM address determined by `$1B48`
- Squiggly: 21 entries starting at ROM address determined by `$1B58`
- Tables wrap around when exhausted
- Each entry specifies which column (0-10) should fire next

### 5. Shot Selection Algorithm
For column-based shots:
1. Read next column index from firing table
2. Advance table pointer (with wrap-around)
3. Call `FindInColumn` to locate lowest alive alien in that column
4. If found: calculate position below alien (+7 Y, -10 X)
5. If not found: skip this firing attempt

For tracking shot (rolling):
1. Get player X coordinate (+8 to center)
2. Call `FindColumn` to determine which column player is in
3. Find lowest alive alien in that column
4. Fire from below that alien

### 6. Alien Selection Strategy
**Always fires from LOWEST alive alien in column (bottom-up search)**

```asm
; Start at bottom row (column base)
; Search upward through 5 rows
; Return first alive alien found
; This creates "leading edge" effect - shots come from aliens closest to player
```

## ZX Spectrum Adaptation

### Implementation Details

Our Spectrum port uses a **simplified single-shot-type system** with the core column-firing logic from the original:

1. **Column-firing table** (like plunger/squiggly shots)
   - 16-entry table cycling through columns 1-11
   - Table pointer advances each firing attempt
   - Wraparound when reaching end
   
2. **Bottom-up alien selection** (FindInColumn algorithm)
   - For each fire attempt, read next column from table
   - Search that column from bottom row to top row
   - Fire from lowest alive alien found
   - Skip if no alien alive in that column

3. **Fixed firing delay**
   - Fire attempt every 60 frames
   - 2 concurrent shots maximum (MAX_ENEMY_SHOTS)
   - Simpler than three-shot synchronization system

4. **Single shot type**
   - Straight vertical drop (no animation patterns)
   - Can add multiple types later for variety

### Current Implementation
```z80
EnemyShot_TryFire:
    ; Check counter (every 60 frames)
    ld hl, ENEMY_SHOT_COUNTER
    inc (hl)
    cp ENEMY_SHOT_FIRE_DELAY (60)
    ret c
    
    ; Find available shot slot (2 slots max)
    ; Get next column from firing table
    ; Search column bottom-to-top for alive alien
    ; Calculate position below alien
    ; Activate shot
    
EnemyShot_PickAlien:
    ; Use column-firing table
    ; Search specific column from bottom to top
    ; Return first alive alien found
```

### Differences from Original

| Feature | Original Arcade | ZX Spectrum Port |
|---------|----------------|------------------|
| Shot types | 3 (rolling, plunger, squiggly) | 1 (straight drop) |
| Synchronization | Timer cycle 0→1→2, ISR-based | Simple frame counter |
| Reload rate | Score-based dynamic rate | Fixed 60-frame delay |
| Column tables | Two tables, 16/21 entries | One table, 16 entries |
| Alien selection | FindInColumn per shot type | Single FindInColumn |
| Animation | 4-frame sprite cycles | Static single pixel |
| Max shots | 3 (one per type) | 2 (simplified) |

### Development Debug Visualizer

During bring-up, a lightweight visualizer was added to show enemy-shot lifecycle events
using color attributes in the top-right corner. This is intentionally simple and does not
depend on text rendering.

Implementation files:
- `src/debug.z80`
- `src/main.z80` (calls debug routines)
- `src/game/enemy_shot.z80` (event hooks)

Display method:
- Writes directly to `SCREEN_ATTRS` cells (paper colors for high visibility)
- Uses top-row cells 28-31 (rightmost 4 attribute cells)

Indicators (left to right):
- Cell 28: fire counter heartbeat (`Debug_ShowFireCounter`)
- Cell 29: fire attempt reached delay threshold (`Debug_ShowFireAttempt`)
- Cell 30: shot successfully created (`Debug_ShowShotCreated`)
- Cell 31: at least one enemy shot active (`Debug_UpdateShotActive`)

Typical diagnosis patterns:
- Only cell 28 changing: counter path runs, but threshold/attempt path not reached
- Cells 28+29 only: fire attempt runs, but shot spawn fails (alien select or spawn guard)
- Cells 28+29+30 but no 31: shot creation flag set but active state not persisting
- All 4 active but no visible projectile: draw/erase path issue

Important implementation note:
- Debug helper routines must preserve registers used by game logic. In particular,
  `Debug_ShowFireCounter` must preserve `A`, because `EnemyShot_TryFire` compares
  `A` against `ENEMY_SHOT_FIRE_DELAY` immediately after the debug call.

### Future Enhancements
1. **Add additional shot types** for variety (zigzag, animated sprites)
2. **Implement targeting shot** that aims at player position
3. **Add reload rate** based on score (difficulty scaling)
4. **Four-frame sprite animation** to match arcade visual style
5. **Increase max shots** to 3 when adding multiple types
6. **Sync with ISR** to match arcade timing precision

## Constants from Original

```asm
; Shot synchronization
obj2TimerExtra: 0x2032  ; Timer cycles 0→1→2
shotSync:       0x2080  ; Copied from obj2TimerExtra each frame

; Reload rate (difficulty)
aShotReloadRate: 0x20CF ; Based on score MSB, controls fire frequency

; Step counts (spacing)
rolShotStepCnt: 0x2036  ; Rolling shot movement counter
pluShotStepCnt: 0x2046  ; Plunger shot movement counter  
squShotStepCnt: 0x2056  ; Squiggly shot movement counter

; Column firing tables
plungerTable: starts at address in $1B48, 16 entries
squigglyTable: starts at address in $1B58, 21 entries
```

## Shot Movement (0x05C1)

```asm
MoveAS:
; Move the alien shot
05C1: 11 7C 20        LD      DE,$207C            ; Alien-shot Y coordinate
05C4: CD 06 1A        CALL    CompYToBeam         ; Compare to beam position
05C7: D0              RET     NC                  ; Not the right ISR for this shot
;
05C8: 23              INC     HL                  ; 2073 status
05C9: 7E              LD      A,(HL)              ; Get shot status
05CA: E6 01           AND     $01                 ; Bit 0 is 1 if blowing up
05CC: C2 44 06        JP      NZ,ShotBlowingUp    ; Go do shot-is-blowing-up sequence
05CF: 23              INC     HL                  ; 2074 step count
05D0: 34              INC     (HL)                ; Count the steps (used for fire rate)
05D1: CD 75 06        CALL    $0675               ; Erase shot
05D4: 3A 79 20        LD      A,(aShotImageLSB)   ; Get LSB of the image pointer
05D7: C6 03           ADD     A,$03               ; Next set of images (animation)
05D9: 21 7F 20        LD      HL,$207F            ; End of image
05DC: BE              CP      (HL)                ; Have we reached the end of the set?
05DD: DA E2 05        JP      C,$05E2             ; No ... keep it
05E0: D6 0C           SUB     $0C                 ; Back up to the 1st image in the set
05E2: 32 79 20        LD      (aShotImageLSB),A   ; New LSB image pointer
05E5: 3A 7B 20        LD      A,(alienShotYr)     ; Get shot's Y coordinate
05E8: 47              LD      B,A                 ; Hold it
05E9: 3A 7E 20        LD      A,(alienShotDelta)  ; Get alien shot delta
05EC: 80              ADD     A,B                 ; Add to shots coordinate
05ED: 32 7B 20        LD      (alienShotYr),A     ; New shot Y coordinate
05F0: CD 6C 06        CALL    $066C               ; Draw the alien shot
05F3: 3A 7B 20        LD      A,(alienShotYr)     ; Shot's Y coordinate
05F6: FE 15           CP      $15                 ; Still in the active playfield?
05F8: DA 12 06        JP      C,$0612             ; No ... end it
; Check for collision with player
05FB: 3A 61 20        LD      A,(collision)       ; Did shot collide ...
05FE: A7              AND     A                   ; ... with something?
05FF: C8              RET     Z                   ; No ... we are done here
0600: 3A 7B 20        LD      A,(alienShotYr)     ; Shot's Y coordinate
0603: FE 1E           CP      $1E                 ; Is it below player's area?
0605: DA 12 06        JP      C,$0612             ; Yes ... end it
0608: FE 27           CP      $27                 ; Is it above player's area?
060A: 00              NOP                         ; ** WHY?
060B: D2 12 06        JP      NC,$0612            ; Yes ... end it
060E: 97              SUB     A                   ; Flag that player ...
060F: 32 15 20        LD      (playerAlive),A     ; ... has been struck
;
0612: 3A 73 20        LD      A,(aShotStatus)     ; Flag to ...
0615: F6 01           OR      $01                 ; ... start shot ...
0617: 32 73 20        LD      (aShotStatus),A     ; ... blowing up
061A: C9              RET                         ; Out
```

Key details:
- **Animation**: Image pointer advances +3 each frame, wraps after 4 frames (12 bytes)
- **Collision detection**: Y coordinate must be in player area (0x1E to 0x27)
- **Player hit**: Sets `playerAlive` to 0

## Summary

The arcade uses a sophisticated multi-shot system with:
- Three simultaneous shots with different behaviors
- Synchronized timing to prevent overlap
- Column-firing tables for strategic placement
- Score-based reload rate (difficulty scaling)
- Bottom-up alien selection (leading edge)
- Animated sprites with 4-frame cycles

Our simplified implementation captures the core mechanics while being easier to implement and debug on the Spectrum.
