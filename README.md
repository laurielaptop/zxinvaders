# ZX Invaders

ZX Invaders is a ZX Spectrum 48K remake/port of the original Space Invaders gameplay loop, written in Z80 assembly.

The project aims to keep the arcade feel while adapting hardware-specific behavior (video, input, timing, sound) to the Spectrum platform in a clear, maintainable codebase.

## Project Goals

- Recreate the core Space Invaders gameplay loop on ZX Spectrum 48K.
- Preserve recognizable alien movement and firing behavior from the original logic.
- Keep modules small and readable for long-term iteration in assembly.
- Use an emulator-first workflow so features can be tested quickly.

## Key Technical Challenges

- Porting from original arcade assumptions (8080-era hardware) to ZX Spectrum memory layout and I/O.
- Rendering on the Spectrum's non-linear bitmap and separate attribute memory without introducing corruption.
- Maintaining stable projectile lifecycles (spawn, move, collide, erase) in a constrained frame loop.
- Balancing visual correctness with temporary busy-wait timing before ISR-synced updates are added.

## Current Status (March 2026)

Completed and verified:

- Main loop architecture in place (`erase -> update -> draw -> frame wait`).
- Player movement and single player shot working.
- Alien formation movement working (march and edge descent).
- Enemy shot system working (column-driven firing and bottom-up alien selection).
- Score tracking and HUD score rendering working.
- On-screen debug visualizer available for enemy-shot lifecycle events.

In progress / next up:

- Lives HUD display and hit/respawn flow polish.
- Game over state and restart flow.
- Wave clear detection and next-wave setup.
- Optional enemy fire parity tuning.
- ISR-synced rendering/timing pass.
- Audio pass (fire/hit/movement cues).

## Development Workflow

Primary loop:

1. Assemble with `z80asm`.
2. Package/load TAP.
3. Run in emulator (KLIVE or ZEsarUX).
4. Validate behavior and iterate.

Common commands:

```bash
make assemble
make package-tap
make run-klive
make run-zesarux
```

## Notes

- Internal porting and architecture details: `docs/porting-notes.md`
- Remaining implementation checklist: `docs/remaining-checklist.md`
- Enemy fire behavior notes: `docs/enemy-fire-logic.md`
- Sprite/animation parity analysis before graphics replacement: `docs/graphics-animation-parity.md`

## Project Tracking

Active implementation checklist for Phase 2 work is tracked in the repository issues:

- `Phase 2 Checklist: Lives, Game Over, Waves, and Polish`
