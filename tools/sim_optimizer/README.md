# GLADIUS Python Simulator + Optimizer

Standalone local tool for fast combat-balance iteration without launching Godot.

## What it does

- Loads runtime data from `data/definitions/*.json`.
- Replays duel rules used by the current vertical slice (`CombatSimulation`, `TurnController`, `ActionResolver`, related systems).
- Runs batch simulations for the canonical matchups:
  - `RET_STARTER vs RET_STARTER`
  - `SEC_STARTER vs SEC_STARTER`
  - `RET_STARTER vs SEC_STARTER`
  - `SEC_STARTER vs RET_STARTER`
- Aggregates batch metrics (wins, win rates, turns, action and status counts).
- Searches a bounded parameter space and ranks balance candidates.

## Module layout

- `loader.py` – definition loading + build stat resolution
- `models.py` – immutable definitions + mutable runtime model dataclasses
- `ai.py` – class-specific action policies mirroring current behavior
- `engine.py` – combat execution (turn flow, stamina, hit/crit, damage, statuses, cooldowns, victory)
- `simulate.py` – single matchup and suite batch runners
- `metrics.py` – aggregate result shaping
- `validate.py` – compare Python suite outputs to Godot batch report JSONs
- `optimize.py` – bounded grid/random candidate search and scoring
- `cli.py` – argparse entrypoint

## Install / run

No external dependencies; uses Python 3 standard library.

From repo root:

```bash
python -m tools.sim_optimizer.cli simulate --attacker RET_STARTER --defender SEC_STARTER --runs 1000 --seed 1001
```

Optional output file:

```bash
python -m tools.sim_optimizer.cli simulate --attacker RET_STARTER --defender SEC_STARTER --runs 1000 --seed 1001 --output out/sim.json
```

## Validation against Godot batch reports

If existing Godot report JSON files are available (one JSON per matchup, each with `inputs.attacker_build_id` and `inputs.defender_build_id`), place them in a folder (default: `batch_reports/`) and run:

```bash
python -m tools.sim_optimizer.cli validate --reference-dir batch_reports --runs 1000 --seed 6100
```

Output includes per-matchup Python metrics, reference metrics, and deltas.

If no reference files are present, the command still runs and reports `No reference report JSON found for this matchup.`

## Optimizer

Default parameter space (bounded, SEC-focused):

- `SECUTOR.base_def`
- `SECUTOR.base_sta`
- `SHIELD_BASH.sta_cost`
- `SHIELD_BASH.flat_damage`
- `RECOVER.sta_cost`

Run exhaustive grid (default with `--trials 0`):

```bash
python -m tools.sim_optimizer.cli optimize --trials 0 --runs 500 --seed 4242
```

Run sampled random subset:

```bash
python -m tools.sim_optimizer.cli optimize --trials 5000 --runs 200 --seed 4242
```

Use custom parameter space:

```bash
python -m tools.sim_optimizer.cli optimize --param-config tools/sim_optimizer/example_param_config.json --trials 500 --runs 250
```

Score objectives (explicit):

- RET vs RET attacker win rate close to 50%
- RET vs RET average turns not too high
- SEC vs SEC average turns targeted to ~35–50
- SEC vs RET attacker win rate targeted to ~60–65%
- penalties for very long fights and matchup blowouts

## Fidelity notes and assumptions

Mirrors current Godot logic for:

- seat-based runtime (`A`/`B`) and first actor by speed (random tie-break)
- per-turn stamina regen and exhausted status updates
- AI action choices (`SecutorAiPolicy` and retiarius logic in `ActionResolver`)
- hit/crit formulas, defense scaling, damage floor
- cooldown ticking and application
- status apply/refresh/replace handling
- skip-turn statuses (`STUNNED`), `ENTANGLED`, `EXHAUSTED`, DOT support
- immediate victory resolution after lethal action
- max-turn abort handling

Known differences:

1. RNG generator is Python `random.Random`, not Godot `RandomNumberGenerator`; exact per-seed event stream will differ.
2. Validation references are external runtime artifacts; this repo currently does not include historical Godot batch JSON outputs by default.
3. Current aggregate metrics are intentionally lighter than full Godot `CombatBatchSimulator` fighter telemetry, but preserve high-signal balance KPIs.

## Example artifacts

- `sample_simulation_output.json`
- `sample_validation_output.json`
- `sample_optimizer_output.json`

Generated with small run counts for quick inspection.
