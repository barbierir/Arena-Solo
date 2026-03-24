# GLADIUS Starter Duel Vertical Slice

This prototype implements a deterministic, data-driven 1v1 combat slice for:

- Player: `RET_STARTER`
- Enemy AI: `SEC_STARTER`

## How to run

1. Open the Unity project.
2. Open scene: `Assets/Gladius/_Project/Scenes/Combat_Test.unity`.
3. Press Play.
4. Use the on-screen action buttons to play the duel.

## Where combat data lives

All combat content is loaded from `Resources/Data/Definitions`:

- `combat_rules.json`
- `classes.json`
- `builds.json`
- `equipment.json`
- `skills.json`
- `status_effects.json`
- `ai_profiles.json`
- `encounters.json`

## Architecture notes

- Combat formulas are resolved in systems (`HitChanceSystem`, `DamageSystem`, `StaminaSystem`, `StatusSystem`).
- `ActionResolver` orchestrates turn actions and delegates calculations.
- RNG is centralized through `IRngService` and seeded with `SeededRngService` in `CombatManager`.
- `GladiatorActor` remains a bridge-only MonoBehaviour with no gameplay logic.

## Assumptions made

- `NET_START` hit bonus (`+0.10`) is applied only for `NET_THROW`, per workbook/schema notes.
- The existing project did not contain a dedicated campaign/save layer, so this slice keeps runtime state in-memory only.
- Starter content includes only required classes/builds/assets for the RET vs SEC duel.
