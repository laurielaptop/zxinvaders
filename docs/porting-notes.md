# ZX Invaders Porting Notes

## Goal
Port the original 8080 Space Invaders logic to ZX Spectrum 48K while replacing hardware-specific layers.

## Current Toolchain (macOS CLI)
- Assembler: `z80asm` v1.8 (Homebrew)
- Emulators: 
  - Primary: KLIVE IDE (`/Applications/Klive IDE.app`) - working with TAP loader
  - Secondary: ZEsarUX v12.0 (`/Applications/ZEsarUX.app`) - working with BASIC loader
- Build automation: `make` with targets: `assemble`, `package-tap`, `run`, `run-klive`, `run-zesarux`
- TAP packaging: Custom `tools/bin_to_tap.sh` (Perl script with BASIC auto-loader)

## Iteration 1 Scope
- In scope: build system, emulator loop, graphics primitives, keyboard input, timing scaffold, first game loop slices
- Out of scope: audio implementation (stubs only)

## Hardware Migration Ledger
| 8080 dependency | Original assumption | ZX Spectrum replacement |
|---|---|---|
| ISR at `0x0008` / `0x0010` | Mid-screen and vblank split work | Software frame phases in main loop (later IRQ-backed) |
| Screen base `0x2400` | Linear arcade bitmap assumptions | ZX bitmap at `0x4000`, attrs at `0x5800` |
| Port `INP1` (`IN A,(01h)`) | Coin/start/fire/left/right | Keyboard scan via `IN A,(0xFE)` rows |
| Port `SOUND1/SOUND2` (`OUT 03h/05h`) | Arcade sound hardware | Deferred for iteration 1 |
| PImplementation Status

### ✅ Completed (Iteration 1 - Player Movement)
1. **Build System**
   - `z80asm` assembly working with `-I src` include paths
   - TAP generation with BASIC auto-loader: `10 LOAD "" CODE : RANDOMIZE USR 32768`
   - Entry point jump at `org 32768` to avoid RET-to-BASIC issue
   - Makefile targets for assembly, packaging, and emulator launch

2. **Video System**
   - `Video_Init`: Clear bitmap + attributes, set border black
   - `Video_CalcAddress`: ZX Spectrum non-linear screen address calculation (Y[7:6], Y[2:0], Y[5:3] bit routing)
   - Bit-shifted sprite rendering for pixel-precise horizontal movement (not byte-aligned)
   - Efficient sprite erase at previous position (not full-screen clear per frame)

3. **Input System**
   - Keyboard scanning via port `0xFE` with row masks
   - O key (left): Row `DFFE`, bit 1
   - P key (right): Row `DFFE`, bit 0  
   - Space (fire): Row `7FFE`, bit 0
   - Returns bitfield: bit0=left, bit1=right, bit2=fire

4. **Player Module**
   - State: X, Y, status, fire_ctrl, prev_X (5 bytes at `GAME_RAM_BASE`)
   - Movement: 3px/frame with boundary clamping (0-247)
   - Rendering: 8×8 sprite with bit-shift support for smooth sub-byte positioning
   - Sprite data: Simple ship shape (0x3C, 0x7E, 0xFF×4, 0x7E, 0x3C)

5. **Timing**
   - `Timing_WaitShort`: 5000-cycle busy-wait per frame (temporary, suitable for testing)
   - Main loop: erase old sprite → update → draw → wait

6. **Emulator Compatibility**
   - KLIVE: Manual TAP load working
   - ZEsarUX: BASIC auto-loader working (`LOAD ""` → auto-execute)

### 🚧 Known Issues & Technical Debt
- Screen address calculation via `inc h` assumes no character-row boundary crossing (valid for 8-line sprites)
- Busy-wait timing instead of interrupt-driven frame sync
- No collision detection yet
- Fire button detected but no shot spawning
- Diagnostic test files (`test_border*.z80`, `test_minimal.z80`) left in tree

### 📋 Next Steps (Iteration 2 - Shots & Aliens)
1. Implement shot system (spawn on fire, move upward, boundary checks)
2. Add alien grid rendering (5 rows × 11 columns)
3. Basic collision: shot vs alien
4. Score tracking and display

## Input Mapping
- Left: `O` (row DFFE, bit 1)
- Right: `P` (row DFFE, bit 0)
- Fire: `Space` (row 7FFE, bit 0)

Keys validated working in both KLIVE and ZEsarUX emulator

This mapping is temporary and can be replaced by configurable key/joystick maps.
