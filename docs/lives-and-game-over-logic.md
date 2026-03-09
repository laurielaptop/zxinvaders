# Lives, Hit Detection, and Game-Over Logic

## Overview

The original Space Invaders arcade tracks player lives, handles hit detection when aliens or their shots strike the player, manages player explosion animation, and controls the game-over / player-switch flow. This document outlines the original 8080 behavior for faithful porting to ZX Spectrum.

## Original 8080 Implementation

### Player Blowup State Machine (0x028E–0x0345)

```asm
GameObj0:
; Game object 0: Move/draw the player
; This task is only called at the mid-screen ISR.
;
028E: E1              POP     HL                  ; Get player object structure (0x2014)
028F: 23              INC     HL                  ; Point to blow-up status (0x2015)
0290: 7E              LD      A,(HL)              ; Get player blow-up status
0291: FE FF           CP      $FF                 ; Player is blowing up?
0293: CA 3B 03        JP      Z,$033B             ; No ... go do normal movement
;
; Handle blowing up player
0296: 23              INC     HL                  ; Point to blow-up delay count (0x2016)
0297: 35              DEC     (HL)                ; Decrement the blow-up delay
0298: C0              RET     NZ                  ; Not time for a new blow-up sprite ... out
0299: 47              LD      B,A                 ; Hold sprite image number
029A: AF              XOR     A                   ; 0
029B: 32 68 20        LD      (playerOK),A        ; Player is NOT OK ... player is blowing up
029E: 32 69 20        LD      (enableAlienFire),A ; Alien fire is disabled
02A1: 3E 30           LD      A,$30               ; Reset count ...
02A3: 32 6A 20        LD      (alienFireDelay),A  ; ... till alien shots are enabled
02A6: 78              LD      A,B                 ; Restore sprite image number
02A7: 36 05           LD      (HL),$05            ; Reload time between blow-up changes
02A9: 23              INC     HL                  ; Point to number of blow-up changes (0x2017)
02AA: 35              DEC     (HL)                ; Count down blow-up changes
02AB: C2 9B 03        JP      NZ,DrawPlayerDie    ; Still blowing up ... go draw next sprite
;
; Blow up finished
02AE: 2A 1A 20        LD      HL,(playerYr)       ; Player's coordinates
02B1: 06 10           LD      B,$10               ; 16 Bytes
02B3: CD 24 14        CALL    EraseSimpleSprite   ; Erase simple sprite (the player)
02B6: 21 10 20        LD      HL,$2010            ; Restore player ...
02B9: 11 10 1B        LD      DE,$1B10            ; ... structure ...
02BC: 06 10           LD      B,$10               ; ... from ...
02BE: CD 32 1A        CALL    BlockCopy           ; ... ROM mirror
02C1: 06 00           LD      B,$00               ; Turn off ...
02C3: CD DC 19        CALL    SoundBits3Off       ; ... all sounds
```

### Blowup Sequence Details

**State bytes in player structure (starting at 0x2014)**:
- `+0x00` : Player status (0xFF = not blowing, else = blowing)
- `+0x02` : Blow-up delay counter (timer between sprite frame changes; reload = 5)
- `+0x03` : Number of blow-up changes remaining (reload = ?? frames)

**Blowup sequence**:
1. When player gets hit: set status byte to non-$FF value
2. Each frame: decrement delay counter
3. When delay = 0: toggle sprite (frames 0 ↔ 1), reload delay=5, decrement "changes" counter
4. When "changes" counter reaches 0: exploding animation done

**After explosion complete**:
- Erase sprite from screen
- Restore player structure from ROM mirror
- Turn off all sounds
- Check `invaded` flag (aliens reached bottom) and `gameMode` flag
- If invaded: don't continue (aliens won)
- If not in game mode: return (still in splash screen)

### Lives Decrement and Respawn (0x02C6–0x032F)

```asm
02C6: 3A 6D 20        LD      A,(invaded)         ; Has rack reached bottom of screen?
02C9: A7              AND     A                   ; Check
02CA: C0              RET     NZ                  ; Yes ... done here
02CB: 3A EF 20        LD      A,(gameMode)        ; Are we in ...
02CE: A7              AND     A                   ; ... game mode?
02CF: C8              RET     Z                   ; No ... return to splash screens
02D0: 31 00 24        LD      SP,$2400            ; Drop to main loop
02D3: FB              EI                          ; Enable interrupts
02D4: CD D7 19        CALL    DsableGameTasks     ; Disable game tasks
02D7: CD 2E 09        CALL    $092E               ; Get number of ships for active player
02DA: A7              AND     A                   ; Any left?
02DB: CA 6D 16        JP      Z,$166D             ; No ... handle game over for player
02DE: CD E7 18        CALL    $18E7               ; Get player-alive status pointer
02E1: 7E              LD      A,(HL)              ; Is player ...
02E2: A7              AND     A                   ; ... alive?
02E3: CA 2C 03        JP      Z,$032C             ; Yes, already alive marker set ... remove a ship and reenter
02E6: 3A CE 20        LD      A,(twoPlayers)      ; Multi-player game?
02E9: A7              AND     A                   ; Only one player?
02EA: CA 2C 03        JP      Z,$032C             ; Yes ... remove a ship and reenter
;
; ** Multi-player player switch - store shields and restore other player's data **
02ED: 3A 67 20        LD      A,(playerDataMSB)   ; Player data MSB (0x21 or 0x22)
02F0: F5              PUSH    AF                  ; Hold it
02F1: 0F              RRCA                        ; Player 1 active?
02F2: DA 32 03        JP      C,$0332             ; Yes ... store P1 shields, then switch
02F5: CD 0E 02        CALL    RememberShields2    ; No ... store P2 shields
;
02F8: CD 78 08        CALL    $0878               ; Get ref-alien info and storage pointer
02FB: 73              LD      (HL),E              ; Store alien X
02FC: 23              INC     HL   
02FD: 72              LD      (HL),D              ; Store alien Y
02FE: 2B              DEC     HL
02FF: 2B              DEC     HL
0300: 70              LD      (HL),B              ; Store delta/direction
0302: CD E4 01        CALL    CopyRAMMirror       ; Copy ROM mirror to RAM (init for next player)
0305: F1              POP     AF                  ; Restore active player MSB
0306: 0F              RRCA                        ; Was player 1?
0307: 3E 21           LD      A,$21               ; Player 1 data pointer
0309: 06 00           LD      B,$00               ; Cocktail bit=0 (player 1)
030B: D2 12 03        JP      NC,$0312            ; It was player 1 ... keep as player 2
030E: 06 20           LD      B,$20               ; Cocktail bit=1 (player 2)
0310: 3E 22           LD      A,$22               ; Player 2 data pointer
0312: 32 67 20        LD      (playerDataMSB),A   ; Change active player MSB
0315: CD B6 0A        CALL    TwoSecDelay         ; Two second delay
0318: AF              XOR     A                   ; Clear player-object timer
0319: 32 11 20        LD      (obj0TimerLSB),A    ; Player can move instantly
031C: 78              LD      A,B                 ; Cocktail bit to A
031D: D3 05           OUT     (SOUND2),A          ; Set the cocktail mode
031F: 3C              INC     A                   ; Fleet sound
0320: 32 98 20        LD      (soundPort5),A      ; Set port 5 hold
0323: CD D6 09        CALL    ClearPlayField      ; Clear center window
0326: CD 7F 1A        CALL    RemoveShip          ; Remove a ship and update HUD
0329: C3 F9 07        JP      $07F9               ; Tell players that switch was made
;
; Single-player: just remove ship and re-enter
032C: CD 7F 1A        CALL    RemoveShip          ; Remove a ship and update HUD
032F: C3 17 08        JP      $0817               ; Continue into game loop
;
; Store shields before switching
0332: CD 09 02        CALL    RememberShields1    ; Store P1 shields
0335: C3 F8 02        JP      $02F8               ; Continue with switch
```

### Key State Variables & Flags

```
playerStatus (0x2015)     : 0xFF = not blowing; else = blowing
blowupDelay (0x2016)      : Countdown timer (reload=5)
blowupChanges (0x2017)    : Number of sprite toggles left (reload=?)
playerOK (0x2068)         : 0 = blowing; 1 = alive
enableAlienFire (0x2069)  : 0 = disabled during respawn; 1 = enabled
alienFireDelay (0x206A)   : Countdown until alien fire re-enables (reload=0x30)
invaded (0x206D)          : 1 = aliens reached bottom
gameMode (0x20EF)         : 0 = splash screen; 1 = gameplay
twoPlayers (0x20CE)       : 1 = multi-player; 0 = single-player
playerDataMSB (0x2067)    : 0x21 (P1) or 0x22 (P2)
```

### Game Over Detection (0x166D)

The routine at 0x166D handles game-over when lives reach zero.

**Flow**:
1. Get number of ships remaining (`$092E`)
2. If 0: go to 0x166D (game over)
3. If > 0: continue with respawn/switch logic

## ZX Spectrum Adaptation

### Constraints

1. **ISR vs Frame Loop**: Original timing is tied to ISR mid-screen/vblank. ZX uses frame-based main loop.
2. **Multi-player Support**: Defer for now; single-player only in initial implementation.
3. **Player Lives Display**: HUD already tracks score; extend with lives counter.

### Implementation Plan

1. **Player Hit Detection**:
   - Enemy shot collision at Y < player Y position → trigger hit
   - Alien descent to Y >= player Y position → trigger invasion (game over immediately)

2. **Blowup State Machine**:
   - `PLAYER_STATUS` byte: 0xFF (normal) vs 1 (blowing)
   - `PLAYER_BLOWUP_DELAY`: countdown timer
   - `PLAYER_BLOWUP_FRAMES`: number of sprite toggles
   - Each frame: decrement timer; at 0, toggle sprite and decrement frames counter
   - At 0 frames, clear blowup state

3. **Lives Management**:
   - `PLAYER_LIVES_REMAINING` (RAM): decrement on hit
   - HUD displays current lives (top-left or HUD area)
   - If lives = 0 → game over screen / level restart

4. **Game Over / Restart**:
   - Display "GAME OVER" at screen center
   - Wait for START (or delay 2–3 seconds)
   - Reset wave / re-init aliens / restore shields / reset lives to 3

### Proposed ZX Additions

**In `src/constants.z80`**:
```z80
; Player hit/lives
PLAYER_LIVES_START: equ 3
PLAYER_STATUS: equ GAME_RAM_BASE + 32
PLAYER_BLOWUP_DELAY: equ GAME_RAM_BASE + 33     ; Timer (reload=5)
PLAYER_BLOWUP_FRAMES: equ GAME_RAM_BASE + 34    ; Sprite toggles left
PLAYER_LIVES_REMAINING: equ GAME_RAM_BASE + 35  ; Current lives
PLAYER_HIT_FLAG: equ GAME_RAM_BASE + 36         ; 1 = hit this frame
```

**New file: `src/game/player_hit.z80`**:
- `PlayerHit_Init`: Initialize lives to 3, status to normal
- `PlayerHit_OnHit`: Trigger blowup sequence, decrement lives
- `PlayerHit_Update`: Update blowup animation each frame
- `PlayerHit_Erase`: Erase explosion sprite
- `PlayerHit_Draw`: Draw explosion sprite

**New file: `src/game/game_over.z80`**:
- `GameOver_Trigger`: Display "GAME OVER", wait for input
- `GameOver_Restart`: Reset wave, lives, shields, aliens

## Integration Points

1. **Enemy shot collision** (`src/game/enemy_shot.z80`):
   - If collision with player: call `PlayerHit_OnHit`

2. **Alien invasion** (`src/game/aliens.z80`):
   - If alien Y >= player Y: trigger game over immediately

3. **Draw loop** (`src/main.z80`):
   - Call `PlayerHit_Update`, `PlayerHit_Erase`, `PlayerHit_Draw` in standard cadence
   - Call `HUD_Draw` to show current lives

4. **Main loop** (`src/main.z80`):
   - After checking lives=0, call `GameOver_Trigger` if needed

---

*Reference: Original Space Invaders arcade 8080 assembly, addresses 0x028E–0x0345, 0x02C6–0x032F, 0x166D; game object structure layout and state variable locations*
