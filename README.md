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
   - Select fighter builds for side **A** and **B**
   - Click **Step Turn** to initialize (if needed) and advance exactly one turn
   - Click **Run Fight** to execute the duel to completion
   - Click **Replay Same Seed** to rerun the same matchup and seed deterministically

The UI shows HP, stamina, statuses, active turn actor, combat log, and final result.

### Step Turn behavior

- Stepped and full-run combat both use the same simulation API (`initialize_fight`, `step_turn`, `run_to_completion`).
- `Step Turn` does nothing once a fight has reached a terminal result.
- `Replay Same Seed` recreates the last matchup with the same seed; if no active fight exists yet, it initializes from the current selectors and seed input.

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

Coverage includes deterministic replay, terminal resolution, stepped-vs-full parity, status duration behavior, stamina interactions, and fight end conditions.
