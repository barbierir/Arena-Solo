# GLADIUS (Godot 4) - Deterministic Starter Duel Vertical Slice

This repository now contains a playable **auto-combat 1v1 prototype** for:

- `RET_STARTER` (player-side Retiarius)
- `SEC_STARTER` (enemy Secutor)

The slice is simulation-first and data-driven.

## How to run the prototype

1. Open in Godot 4.x.
2. Run the default scene (`scenes/app/App.tscn`).
3. In the combat viewer:
   - Enter a seed (defaults to `1001`)
   - Click **Run Fight** to execute the duel
   - Click **Replay Same Seed** to verify deterministic replay

The UI shows HP, stamina, statuses, active turn actor, combat log, and final result.

## Where combat data lives

Combat content is loaded from modular JSON files in:

- `data/definitions/combat_rules.json`
- `data/definitions/classes.json`
- `data/definitions/builds.json`
- `data/definitions/equipment.json`
- `data/definitions/skills.json`
- `data/definitions/status_effects.json`
- `data/definitions/ai_profiles.json`
- `data/definitions/encounters.json`

## Deterministic seeding model

- All randomness flows through `SeededRngService.gd`.
- The simulation uses this service for hit/crit/random tie-break paths.
- Re-running with the same seed yields the same turn log and result.

## Assumptions made

- Status durations tick at the end of the acting combatant's turn.
- `EXHAUSTED` is applied when STA reaches 0 and removed once STA is above 0.
- `NET_START` hit bonus is conditional and only applied for `NET_THROW`.
- The player-side actor is automated in this slice to keep combat simulation-first.

## Tests

A lightweight headless test script is included:

- `tests/combat/test_vertical_slice.gd`

Run (if Godot CLI is available):

```bash
godot4 --headless --script res://tests/combat/test_vertical_slice.gd
```
