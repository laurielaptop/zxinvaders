# Gameplay Parity Gaps (8080 -> ZX)

This note captures missing gameplay elements that must be documented from `resources/source.z80` before ZX implementation.

## Scope Confirmed

1. Protective bases/shields ✅ COMPLETE
2. Saucer/UFO bonus ship ✅ COMPLETE
3. Multiple alien shot families
4. Alien row-specific graphics and animation
5. Explosion animations

## Current ZX Status (March 2026)

- Shields: COMPLETE (4 shields with erase/draw cycle, proper 48-pixel spacing)
- Saucer/UFO: COMPLETE (tuned 256-loop countdown for current busy-wait pacing, horizontal movement with direction logic, score table 50/100/150/300, hit detection, explosion sequence)
- Alien shot families: partial (single simplified system exists)
- Alien row graphics/animation: partial (movement animation state exists, row art parity incomplete)
- Explosions: partial
  - Player explosion: implemented and arcade-style timed.
  - Alien explosion: implemented and positioned from hit slot coordinates.
  - Shot/saucer side effects: still simplified vs original.

## Original 8080 References

### 1) Shields
- Init/draw shield buffers: `resources/source.z80:346` (`DrawShieldPl1`), `resources/source.z80:352` (`DrawShieldPl2`)
- Copy/restore shield buffers: `resources/source.z80:392` (`CopyShields`)
- Shield memory transfer helpers: `resources/source.z80:2835` (`RememberShields`), `resources/source.z80:3906` (`RestoreShields`)
- Collision context mentions shields in shot blowup path: `resources/source.z80:710`

Note: original logic initializes **4 shields** (`LD C,$04` at `resources/source.z80:357`).

### 2) Saucer/UFO
- Time-to-saucer countdown: `resources/source.z80:1487` (`TimeToSaucer`)
- Shared game object with squiggly shot: `resources/source.z80:1127`
- Saucer movement/hit/state handling around `0x0689..0x0762`
- Saucer score table: `resources/source.z80:4354` (`SaucerScrTab`)
- Saucer sprites: `resources/source.z80:4363` (`SpriteSaucer`), `resources/source.z80:4390` (`SpriteSaucerExp`)

### 3) Alien Shot Families
- Rolling shot object: around `resources/source.z80:824` (`GameObj2`)
- Plunger shot object: around `resources/source.z80:863` (`GameObj3`)
- Squiggly shot path: around `resources/source.z80:901` (`GameObj4` shot branch)
- Shared shot engine: `resources/source.z80:956` (`HandleAlienShot`)
- Shot blowing-up sequence: `resources/source.z80:1089` (`ShotBlowingUp`)

### 4) Alien Graphics and Animation
- Alien draw pipeline: `resources/source.z80:153` (`DrawAlien`)
- Cursor/one-alien-at-a-time draw cadence: `resources/source.z80:203` (`CursorNextAlien`)
- Frame toggle in reference movement: `resources/source.z80:276` (`MoveRefAlien`)
- Row/type mapping in draw path: around `0x0119..0x0121`

### 5) Explosions
- Player blowup state machine: `resources/source.z80:513` (`GameObj0` hit/blowup)
- Player blowup render toggle: `resources/source.z80:662` (`DrawPlayerDie`)
- Alien exploding lifecycle: `resources/source.z80:2992` (`AExplodeTime`)
- Saucer explosion sprite hook: `resources/source.z80:1248`
- Sprite data blocks: player/alien/shot exploding sprites near `resources/source.z80:4137`, `resources/source.z80:4216`, `resources/source.z80:4253`

## Implementation Order (Source-First)

1. Document lives/game-over and shields together (shared collision/gameflow dependencies).
2. Implement shields and shield collision degradation.
3. Document and implement saucer/UFO timing + score behavior.
4. Document and implement alien shot family expansion on top of existing column-fire base.
5. Add row-specific alien art + animation parity.
6. Integrate explosion state machines and sprite sequences.

## Open Decision

- Strict arcade parity uses 4 shields. If we intentionally want 3 for ZX design reasons, decide now and note deviation in docs.
