# Wave-Clear Logic: 8080 Source Analysis

## Overview

When all 55 aliens are killed the 8080 arcade engine immediately transitions to the
next wave (the original calls it a "rack").  Lives and score are preserved; the
formation is reinitialised at a lower (harder) starting Y and new shields are drawn.

---

## 8080 Source References (`resources/source.z80`)

### Live-alien count: `CountAliens` (`0x15F3`)

```
15F3  CALL GetPlayerDataPtr  ; HL = alien data pointer (0x2100 p1 / 0x2200 p2)
15F6  LD   BC, 0x3700        ; B = 55 (aliens to scan), C = 0 (running count)
15F9  LD   A, (HL)           ; load alien live/dead flag
15FA  AND  A
15FB  JP   Z, 0x15FF         ; 0 = dead, skip
15FE  INC  C                 ; count live alien
15FF  INC  HL
1600  DEC  B
1601  JP   NZ, 0x15F9        ; loop all 55
1604  LD   A, C
1605  LD   (numAliens), A    ; write refreshed count to 0x2082
1608  CP   0x01
160A  RET  NZ
160B  LD   (0x206B), 0x01    ; flag "only 1 alien left" (disables plunger shot)
```

`CountAliens` is called **every game-loop iteration** from the main loop at `0x0825`.
`numAliens` is therefore always a fresh full-scan count, not an incremental counter.

### Wave-clear check in the game loop (`0x082B`)

```
082B  LD   A, (numAliens)    ; freshly written by CountAliens above
082E  AND  A
082F  JP   Z, 0x09EF         ; all gone → wave-clear handler
```

### Wave-clear handler (`0x09EF`)

```
09EF  CALL 0x0A3C            ; optional half-second delay if player still alive
09F2  XOR  A
09F3  LD   (suspendPlay), A  ; pause ISR game tasks
09F6  CALL ClearPlayField    ; blank the screen
09FD  CALL CopyRAMMirror     ; reset alien data from ROM mirror for new wave
; --- advance rack counter ---
0A09  LD   L, 0xFE           ; rackCnt address (within player data page)
0A0B  LD   A, (HL)           ; get number of racks beaten so far
0A0C  AND  0x07              ; clamp 0-7
0A0E  INC  A                 ; 1-8
0A0F  LD   (HL), A           ; save updated count
; --- look up starting Y from table ---
0A10  LD   HL, 0x1DA2        ; AlienStartTable (one-indexed via loop below)
0A13  INC  HL                ; advance pointer
0A14  DEC  A
0A15  JP   NZ, 0x0A13        ; loop: walk HL to the right table entry
0A18  LD   A, (HL)           ; A = starting Y for this rack
; --- store starting Y+X in player data ---
0A1A  LD   L, 0xFC           ; refAlienYr (within player data page)
0A1C  LD   (HL), A           ; set starting Y
0A1D  INC  HL
0A1E  LD   (HL), 0x38        ; set starting X always = 0x38
; --- reinitialise per-player sub-systems ---
0A2A  CALL DrawShieldPl2     ; (or DrawShieldPl1 for player 1 branch)
0A2D  CALL InitAliensP2      ; (or InitAliens for player 1 branch)
0A30  JP   0x0804            ; back to top of game loop
```

### Wave starting-Y table at `0x1DA3` (`AlienStartTable`)

The **first** wave is hard-coded to Y=`0x78` (120 in decimal, arcade raster units)
at `0x07EA`.  After that, the table at `0x1DA3` drives subsequent waves:

| Wave | Table entry | 8080 Y (arcade) | ZX Y (pixels) |
|------|-------------|-----------------|---------------|
| 1    | (hard-code) | 0x78            | 24            |
| 2    | 0x1DA3: 60  | 0x60            | 32            |
| 3    | 0x1DA4: 50  | 0x50            | 40            |
| 4    | 0x1DA5: 48  | 0x48            | 48            |
| 5    | 0x1DA6: 48  | 0x48            | 48            |
| 6    | 0x1DA7: 48  | 0x48            | 48            |
| 7    | 0x1DA8: 40  | 0x40            | 56            |
| 8    | 0x1DA9: 40  | 0x40            | 56            |

After 8 waves the counter wraps back to the start of the table (clamp AND 0x07).

> **Coordinate note:** The arcade Y axis runs top-down in raster scanline units
> (256 visible lines). The ZX Spectrum screen is 192 pixels tall. The mapping used
> in this port divides the arcade values proportionally and clamps to the ZX range.

---

## ZX Port Adaptation

### What stays the same
- All-aliens-dead triggers an immediate new wave.
- Lives and score carry over unchanged.
- Shields regenerate to full at the start of each new wave.
- Wave counter cycles 0-7 (maps to displayed waves 1-8), then wraps.
- Formation starting-Y advances each wave to give a harder game.

### ZX-specific differences
- **Count method:** The ZX port now mirrors the original behavior and scans the
  55-byte alien live grid each frame (`Aliens_HasLive`) to decide whether the
  wave is clear. A helper byte (`ALIEN_COUNT_REMAINING`) is still maintained for
  diagnostics/future tuning, but it is no longer the wave-clear trigger source.
- **Starting X:** Always reset to `ALIEN_INIT_X` (40 px). The arcade fixes X to
  0x38; ZX uses a constant with the same intent.
- **Player pause delay:** The 8080 inserts a ~0.5 s pause at `0x0A3C` (only if the
  player is alive) before clearing the field. The ZX port currently omits this;
  the transition is instant. This is a known parity gap and can be added later.
- **Multi-player data pages:** The 8080 maintains separate alien data for player 1
  and player 2. This port is single-player only and has one shared data set.

### Key RAM locations

| Purpose              | 8080 address      | ZX constant              |
|----------------------|-------------------|--------------------------|
| Live alien count     | `0x2082` numAliens | Grid scan via `Aliens_HasLive` (from `ALIEN_GRID_BASE`) |
| Wave/rack counter    | player-page +0xFE | `WAVE_NUMBER`            = `GAME_RAM_BASE + 193` |
| Alien ref Y          | player-page +0xFC | `ALIEN_REF_Y`            = `GAME_RAM_BASE + 121` |
| Alien ref X          | player-page +0xFD | `ALIEN_REF_X`            = `GAME_RAM_BASE + 120` |

### Implementation files
- `src/constants.z80` — `WAVE_NUMBER` and optional `ALIEN_COUNT_REMAINING` helper byte
- `src/game/alien_hit.z80` — `AlienHit_Update` updates `ALIEN_COUNT_REMAINING` helper
- `src/game/aliens.z80` — `Aliens_Init` sets count=55; `Aliens_NewWave` advances
  wave, clears screen, reinitialises all sub-systems, sets wave-specific Y;
  `Aliens_HasLive` scans the grid for wave-clear checks
- `src/game/hud.z80` — `GameState_Init` resets `WAVE_NUMBER = 0` on new game
- `src/main.z80` — wave-clear check after `AlienHit_Update`; `MAIN_LOOP_WAVE_CLEAR`
  label calls `Aliens_NewWave` and falls through to `MAIN_LOOP_EARLY_EXIT`

---

## Known Parity Gaps

1. **Pre-wave pause:** ~0.5 s delay when player is alive (arcade `0x0A3C`) — not yet implemented.
2. **Single-alien plunger-shot disable:** When only 1 alien remains the arcade disables the plunger shot type (`0x206B` flag). Not ported; low priority.
3. **Fleet-sound speed increase:** `numAliens` also drives alien march pace (fewer aliens → faster, louder fleet sound). Sound is deferred; march speed increase is a future task.
