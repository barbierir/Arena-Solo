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

## Batch balance harness (developer tool)

The combat viewer now includes a **Batch Balance Harness** panel that runs many deterministic fights and reports aggregate metrics for tuning.

### Batch workflow in UI

1. Choose fighter **A** and **B** in the main selectors.
2. In **Batch Balance Harness**, set:
   - `Start Seed`
   - `Runs` (number of simulations)
   - `Max Turns` safeguard per fight
3. Click **Run Batch**.
4. Click **Save Batch Report** to export the latest batch report.
5. Optional: click **Run Standard Suite + Save** to run and export:
   - `SEC_STARTER` vs `SEC_STARTER`
   - `RET_STARTER` vs `RET_STARTER`
   - `SEC_STARTER` vs `RET_STARTER`
   - `RET_STARTER` vs `SEC_STARTER`

### Batch metrics reported

- Total runs
- A/B wins and win rates
- Draw/unresolved count
- Average/min/max turns
- Average end-of-fight HP and STA for both fighters
- Terminal condition counts (`HP_ZERO`, `MAX_TURNS_ABORT`, etc.)
- Ability usage frequency (per skill/action)
- Status application frequency (per status ID)
- Per-fighter diagnostic telemetry:
  - avg damage dealt/taken per match
  - avg stamina spent per match
  - avg turns survived
  - avg low/zero stamina turns
  - hit/miss totals
  - per-fighter ability usage
  - per-fighter status applications and uptime turns
  - remaining HP/STA split by wins vs losses

### Batch report export files

- Reports are saved under `user://batch_reports/`.
- Each manual save writes both:
  - JSON report (`.json`)
  - readable text report (`.txt`)
- File names are timestamped and matchup-aware, for example:
  - `2026-03-24_184210_SEC_STARTER_vs_RET_STARTER_seed1000_runs1000.json`
  - `2026-03-24_184210_SEC_STARTER_vs_RET_STARTER_seed1000_runs1000.txt`
- If the same file name would collide, a numeric suffix is added.
- The debug UI shows an export status line and last-saved path.
- If no batch has been run yet, **Save Batch Report** fails gracefully with a clear message.

### Determinism and safeguards

- The batch harness reuses the same `CombatSimulation` path as single-fight debug.
- For `N` runs, seeds are progressive: `S`, `S+1`, ..., `S+N-1`.
- If a fight exceeds `Max Turns`, it is marked as `ABORTED` and counted as unresolved (not silently reassigned as a win).

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

Batch harness tests are included in the same script, covering deterministic batch outputs, progressive seeding, accounting consistency, turn-stat validity, and parity against a manual seeded loop.

To run the standard 1000-run matchup set for tuning (if Godot CLI is available):

```bash
godot4 --headless --script res://tests/combat/run_standard_batches.gd
```

This headless helper now also saves JSON/TXT reports for each matchup plus a suite summary text file under `user://batch_reports/`.
