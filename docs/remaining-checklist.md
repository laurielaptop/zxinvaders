# Remaining Work Checklist

This checklist consolidates the current parity and stabilization work that is still open.

## P0 - Fix current gameplay regressions

- [x] Shield degradation erosion and collision — complete (2026-03-21).
  - Draw-once architecture: shields drawn once at init/wave-start; no per-frame erase/redraw (fixes flashing).
  - `Shields_PunchChannel`: 8-row vertical channel erased directly on ZX screen bitmap per hit.  Player shots erase upward (Y_start = shot_Y − 7); enemy shots erase downward (Y_start = shot_Y).
  - Pixel-level collision check added to `Shields_CheckCollision`: after AABB match, reads screen byte at shot column; returns 0xFF (no collision) if fully eroded, allowing shots to pass through.
  - Register bugs fixed in `src/game/enemy_shot.z80`: outer-loop B clobbered by `ld b,(hl)` (fixed with push/pop around shield-check section); push/pop balanced across all three exit paths.
  - Register bug fixed in `src/game/shot.z80`: HL not preserved around `Shields_OnPlayerShotCollision` call (fixed with push/pop).
  - Primary docs: `docs/shields-logic.md`.
  - Remaining: minor visual polish; shots pass through fully-eroded columns but erosion shape may need tuning.

- [x] Fix alien-shot shield explosion freeze above shield line.
  - Evidence: same-frame explosion draw/next-frame erase ordering now runs without the previously reported stuck frame above shields.
  - Primary docs: `docs/handoff-next-chat.md`, `docs/enemy-fire-logic.md`.
  - Done when: explosion appears and clears cleanly with no stuck frame artifacts.

- [x] Re-validate enemy-shot behavior below shields after shield-impact fixes (2026-03-21).
  - Shots pass through eroded shield channels and reach the player reliably.
  - Player AABB collision confirmed working: shots kill the player.
  - Primary docs: `docs/handoff-next-chat.md`, `docs/gameplay-parity-gaps.md`.

## P1 - Live-play bugs (2026-03-22)

Six issues identified during extended play testing. All documented below with root-cause analysis.

- [x] **Alien hit blocked by active explosion — fixed (2026-03-22)** (issue 1)
  - Symptom: a player shot that killed a second alien while an explosion was animating was
    silently discarded — no score, no grid mark, hit alien remained "alive".
  - Root cause: `AlienHit_OnHit` returned NZ without acting when `ALIEN_EXPLODING ≠ 0xFF`;
    caller (`Aliens_DoHit`) skipped score and shot-consumption on NZ path.
  - Fix: removed the early-return; when an explosion is already active, `AlienHit_Erase` is
    called to clear old pixels immediately, then falls through to restart the explosion at the
    new alien position. `AlienHit_OnHit` now always returns Z. Cleaned up unreachable NZ
    branch in `Aliens_DoHit`.
  - Files: `src/game/alien_hit.z80` (`AlienHit_OnHit`), `src/game/aliens.z80` (`Aliens_DoHit`).

- [ ] **HUD digit font too heavy — replace with arcade source font** (issue 2)
  - Symptom: current score digits look visually bolder/thicker than the original arcade.
  - Root cause: `HUD_DIGITS` in `src/game/hud.z80` uses hand-crafted 8×8 bitmaps.
  - Source font location: `resources/source.z80:4483` — Characters table at ROM address 0x1E00.
    Score digits occupy character indices 0x1A–0x23 (decimal 26–35), stored as 8 bytes each.
    Address per digit: `0x1E00 + (0x1A + digit) * 8`.
    - '0' → 0x1ED0: `00 3E 45 49 51 3E 00 00`
    - '1' → 0x1ED8: `00 00 21 7F 01 00 00 00`
    - '2' → 0x1EE0: `00 23 45 49 49 31 00 00`
    - '3' → 0x1EE8: `00 42 41 49 59 66 00 00`
    - '4' → 0x1EF0: `00 0C 14 24 7F 04 00 00`
    - '5' → 0x1EF8: `00 72 51 51 51 4E 00 00`
    - '6' → 0x1F00: `00 1E 29 49 49 46 00 00`
    - '7' → 0x1F08: `00 40 47 48 50 60 00 00`
    - '8' → 0x1F10: `00 36 49 49 49 36 00 00`
    - '9' → 0x1F18: `00 31 49 49 4A 3C 00 00`
  - Storage format: bytes are columns in the arcade's 90°-rotated screen coordinate space.
    Each byte is one column of the displayed glyph, MSB = top pixel. The same `rot90cw`
    transform used for alien sprites applies here. After rotation, each byte becomes one
    display row, suitable for direct use in `HUD_DrawDigit`.
  - Fix strategy: apply rot90cw to each 8-byte column vector to produce 8-byte row vectors;
    replace the `HUD_DIGITS` table. The existing draw path (`HUD_DrawDigit`) is unchanged.
  - Files: `src/game/hud.z80` (HUD_DIGITS table only).
  - Done when: score digits visually match the arcade ROM's lighter stroke weight.

- [x] **Alien type order inverted vertically — fixed (2026-03-22)** (issue 3)
  - Symptom: the heaviest/most complex alien sprite appeared at the bottom rows; simplest at top.
  - Root cause: thresholds in `Aliens_SelectValidationSprite` were inverted relative to arcade.
  - Fix: changed `cp 2 / jr c TypeA` to `cp 1 / jr c TypeC` (top row → TypeC), then
    `cp 3 / jr c TypeB` (next 2 rows → TypeB), fallthrough → TypeA (bottom 2 rows).
  - Files: `src/game/aliens.z80` (`Aliens_SelectValidationSprite`).

- [ ] **Enemy shot pixel remnants after movement** (issue 4)
  - Symptom: faint pixel trails or partial shot sprites remain on screen after enemy shots
    pass through an area.
  - Root cause: `EnemyShot_EraseSpriteRow` is implemented as `jp EnemyShot_DrawSpriteRow`
    (line 929) — it uses XOR to "undo" the draw. XOR erasure is only correct if the SAME
    sprite data is used for both draw and erase. The shot animation frame is selected via
    `step_counter & 0x03` (`EnemyShot_GetSpriteFramePtrForSlot`), and `step_counter`
    increments every update cycle. If the counter changes between the Draw and the following
    Erase, a DIFFERENT frame pattern is XOR'd onto the screen, leaving residual pixels.
  - Fix strategy: replace XOR erase with a zero-write erase: compute the OR-mask of all
    possible row bytes for the 3-pixel-wide shot footprint and clear those bits, regardless
    of animation frame. Alternatively, cache the last-drawn frame index in the shot slot
    (adds 1 byte per slot) and always erase with the same data that was drawn.
  - Files: `src/game/enemy_shot.z80` (`EnemyShot_EraseSpriteRow`, `EnemyShot_ErasePixelLoop`).
  - Done when: no pixel trails remain after shots move or expire.

- [ ] **Shields wiped by descending dead alien slots** (issue 5)
  - Symptom: shield pixels disappear even when the bottom alien row is entirely dead and no
    live alien is visible near the shield zone.
  - Root cause: `Aliens_Draw` iterates all 55 alien slots unconditionally. For dead slots it
    calls `Aliens_DrawDead`, which writes 16×8 pixels of zeros at the grid position. When
    the formation descends far enough that the bottom row's Y coordinate overlaps the shield
    area (shield Y = 144–159), dead slot clears erase shield pixels every frame.
    Trigger threshold: REF_Y ≥ 96 causes the bottom row (REF_Y + 4 × ALIEN_SPACING_Y = REF_Y + 48)
    to reach Y = 144.
  - Fix strategy: in `Aliens_Draw`, skip writing zeros for dead slots whose computed Y falls
    within the shield zone (Y range 144–(SHIELD_BASE_Y + SHIELD_HEIGHT − 1) = 144–159).
    Alternatively: only clear a dead slot's position on the frame it DIES (one-shot erase),
    then leave it alone. The simplest guard: add `ld a, c / cp SHIELD_BASE_Y / jr nc,
    Aliens_DrawSlotDone` before `Aliens_DrawDead` to suppress shield-zone erasure.
  - Files: `src/game/aliens.z80` (`Aliens_Draw`, `Aliens_DrawDead` branch).
  - Done when: shields are not erased by alien descent when the bottom row is empty.

- [ ] **Alien edge detection ignores dead columns** (issue 6)
  - Symptom: the formation reverses direction sooner than it should when outer columns have
    been killed, so live aliens in surviving inner columns never travel as far as they should
    toward the screen edge.
  - Current code (`Aliens_Move`, line ~418): checks raw `ALIEN_REF_X` against `ALIEN_EDGE_LEFT`
    (8) and `ALIEN_EDGE_RIGHT` (72). These constants assume a full 11-column formation.
  - Original arcade behaviour (from `resources/source.z80:153`, `CursorNextAlien` at 0x0141):
    aliens are drawn one per frame in sequential order; the edge check fires when the CURRENT
    alien being drawn hits the screen boundary. This naturally uses the position of the
    LIVE alien nearest the edge, because dead aliens are skipped in the cursor advance loop
    (`JP NZ,$0154` skips dead slots). The reversal therefore triggers only when a LIVE alien
    at the outermost surviving column reaches the boundary.
  - Fix strategy: before applying the horizontal delta in `Aliens_Move`, scan the grid to find
    the leftmost and rightmost column that still contains at least one alive alien. Compute
    actual edge positions: `left_live_x = ALIEN_REF_X + leftmost_live_col × ALIEN_SPACING_X`
    and `right_live_x = ALIEN_REF_X + rightmost_live_col × ALIEN_SPACING_X + ALIEN_WIDTH`.
    Compare these against the screen boundaries instead of raw `ALIEN_REF_X`.
    Edge constants may need recalibrating: ALIEN_EDGE_LEFT should be the pixel left-margin;
    ALIEN_EDGE_RIGHT should be `256 − ALIEN_WIDTH − right_margin` (right pixel boundary for a
    single alien, not the full formation).
  - Files: `src/game/aliens.z80` (`Aliens_Move`, possibly new helper `Aliens_FindLiveBounds`).
  - Done when: live aliens at the outermost surviving column travel all the way to the
    screen edge before reversing, matching arcade behaviour as columns are depleted.

## P1 - Parity polish and timing correctness (earlier)

- [x] Enemy-shot cadence: initial reload-rate guard halved (2026-03-22).
  - Root cause: `RELOAD_RATE = 0x30` (48 frames) combined with 54-frame per-family rotation caused 3–4 s dry spells at score ≤ 200.
  - Fix: reduced `.rate30` threshold from `0x30` to `0x18` (24 frames), producing ~36-frame shot intervals (0.72 s) in early game.
  - Validated via ZRCP timing monitor: typical intervals 1000–1200 ms; gaps >3 s were the anomaly being addressed.
  - Primary docs: `docs/enemy-fire-logic.md`, `docs/zrcp-debug.md`.
  - Remaining: further cadence tuning if live-play feel still seems too sparse or too dense.

- [x] Attribute-memory corruption — closed (2026-03-22).
  - No stray coloured squares observed across extended play sessions. Risk considered resolved.

- [x] Complete wave/march parity timing gaps (2026-03-22).
  - March speed ramp: `delay = max(3, ALIEN_COUNT_REMAINING >> 2)` — formation accelerates as aliens die, matching arcade natural cadence.
  - Pre-wave pause: 30-frame countdown before `Aliens_NewWave`, matching arcade inter-wave delay.
  - Wave transition: fixed `Video_ClearBitmap` bug (was clearing 6912 bytes into attribute area; now correctly clears only the 6144-byte bitmap). Attributes (white-on-black) are preserved across wave transitions.
  - Primary docs: `docs/wave-clear-logic.md`, `docs/alien-march-logic.md`.

- [x] Saucer timing parity pass (2026-03-22).
  - Speed doubled (1→2 px/frame): traversal time ~7 s vs prior ~14.5 s at measured 16 fps game-loop rate.
  - Spawn interval increased (256→400 frames): ~25 s between appearances, matching arcade cadence.
  - Alien-count gate implemented: saucer now suppressed when < 8 aliens remain (was TODO, always allowed).
  - Remaining: ISR-aligned spawn (P2); score glyph visual treatment is functionally correct via HUD digits.

## P2 - Presentation and parity improvements

- [ ] Start/attract screen.
  - Scope: game title, hi-score table, score-per-alien-type table, 1-player / 2-player selection. Credit count not required.
  - Files: new `src/game/attract.z80`, `src/main.z80` (game-state machine).
  - Done when: player can see the title screen on launch, select 1 or 2 players, and the game starts correctly.

- [x] In-game HUD: score, hi-score, lives counter with player graphics (2026-03-22).
  - 4-digit score (16-bit) at top-left X=8, Y=8; hi-score at center X=104, Y=8; P2 score (0000) at X=200, Y=8.
  - Score header labels: "SCORE<1>" at X=0, "HI-SCORE" at X=88, "SCORE<2>" at X=192 — all at Y=0 using GameOver glyph renderer.
  - `HUD_Draw4Digits`: 16-bit → 4 decimal digits via repeated `sbc hl, de`; uses 4-byte `HUD_SCRATCH` buffer.
  - `STATE_HI_SCORE` (GAME_RAM_BASE+227) zeroed once by `HUD_Init` at program start; updated each frame when score beats it.
  - Life icons: `HUD_DrawLifeIcon`/`HUD_EraseLifeIcon` draw `PLAYER_SHIP_CW` (16×8) at Y=184 (green zone); all slots redrawn each frame. Lives count digit drawn at X=0, Y=184 before icons.
  - Defense line: solid green pixel line at Y=183 (separates play field from life-icon area). Drawn once after each `Video_ClearBitmap`.
  - Player moved to Y=168 (was 176): 8px gap to shield bottom (Y=160), matching arcade spacing.

- [x] Colour: green zone for shields and player area (2026-03-22).
  - `Video_SetGreenZone` fills attribute rows 18–23 (Y=144–191) with `ATTR_GREEN` (0x04).
  - Called once from `Video_Init`; persists across waves since `Video_ClearBitmap` does not touch attributes.
  - New constants: `ATTR_WHITE` (0x07), `ATTR_GREEN` (0x04), `ATTR_GREEN_ROW` (18), `ATTR_GREEN_COUNT` (6).

- [x] Game Over screen (2026-03-22).
  - Fixed `GameOver_DrawGlyph` bug: `Video_CalcAddress` was overwriting HL (glyph ptr); nothing rendered.
  - "GAME OVER" centred at Y=80; "PRESS FIRE" centred at Y=100.
  - Auto-restart timer tuned to `GAME_OVER_DELAY = 80` (~5 s at 16 fps; was 180 calibrated for 60 fps).
  - `GameOver_Restart` now calls `Video_SetGreenZone` so green zone survives the bitmap clear.

## P3 - End-phase improvements

- [ ] Move from busy-wait pacing to ISR/vblank-synchronized timing.
  - Primary docs: `docs/porting-notes.md`, `docs/alien-march-logic.md`.
  - Done when: frame pacing and scheduler hooks are ISR-driven and stable.

- [ ] Reduce flicker with end-phase render optimization.
  - Primary docs: `docs/porting-notes.md`.
  - Done when: acceptable visual stability under full gameplay load.

- [ ] Audio pass for shot/fire/hit/march cues.
  - Primary docs: `docs/porting-notes.md`.
  - Done when: core gameplay sound events are implemented and balanced.

## Documentation hygiene

- [x] Reconcile docs that disagree on shot-art completion status.
  - Conflict: some notes still say shot art is placeholder while other notes say source-derived shot assets are integrated.
  - Primary docs: `docs/porting-notes.md`, `docs/graphics-animation-parity.md`, `docs/enemy-fire-logic.md`.
  - Done when: all docs present one consistent status and next step.

- [ ] Add missing source-first behavior notes if still needed.
  - Candidates listed in `docs/porting-notes.md`: saucer/alien-shot-types/explosions specific logic notes.
  - Done when: missing behavior docs are either created or explicitly retired as no longer needed.

## Execution Breakdown (File-Targeted)

Use this section to turn P0/P1 items into concrete code-edit sessions.

- [x] Shield degradation + player-shot wiring + enemy-shot wiring + main-loop cadence — complete (2026-03-21).
  - All four sub-items resolved in the same architecture redesign session (see P0 above).

- [x] Lower-field enemy-shot validation pass (2026-03-21).
  - Shot pass-through: fixed `Shields_CheckCollision` to test the specific bit at shot_X (not the whole byte), so eroded channels flanked by intact pixels are correctly treated as gaps.
  - Erosion widened: enemy 3→5 px (0xF8), player 4→6 px (0xFC), matching arcade shot pattern widths.
  - Player AABB collision (from prior session) confirmed: shots kill the player reliably.

- [ ] Attribute-memory safety sweep
  - Files: `src/game/player.z80`, `src/game/player_hit.z80`, `src/game/saucer.z80`, `src/game/shot.z80`, `src/game/enemy_shot.z80`.
  - Deliverables: no unsafe scanline stepping in active draw/erase paths; temporary guards retained or documented.

- [x] Timing parity pass — wave/march portion complete (2026-03-22).
  - Files: `src/platform/video.z80`, `src/game/aliens.z80`, `src/main.z80`, `src/constants.z80`, `src/game/hud.z80`.
  - March speed ramp and pre-wave pause implemented; wave transition stable across multiple waves.

- [ ] Documentation sync pass after each major fix
  - Files: `docs/porting-notes.md`, `docs/gameplay-parity-gaps.md`, `docs/enemy-fire-logic.md`, `docs/remaining-checklist.md`.
  - Deliverables: status, known issues, and checklist checkboxes updated in the same commit as code changes.
