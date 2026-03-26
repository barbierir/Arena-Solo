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
- `validate.py` – parse Godot text reports, aggregate matchup metrics, and compare drift vs simulator
- `optimize.py` – bounded grid/random candidate search and scoring
- `cli.py` – argparse entrypoint
- `matchup_modifiers.py` – centralized matchup-specific modifier loading

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

Show active matchup modifiers while running:

```bash
python -m tools.sim_optimizer.cli simulate --attacker RET_STARTER --defender SEC_STARTER --runs 1000 --seed 1001 --verbose
```

Disable matchup modifiers (baseline behavior):

```bash
python -m tools.sim_optimizer.cli simulate --attacker RET_STARTER --defender SEC_STARTER --runs 1000 --seed 1001 --no-matchup-modifiers
```

## Matchup Modifiers

Purpose:

- Apply small, explicit context tweaks per `ATTACKER_vs_DEFENDER` pairing without editing base class/build data.
- Keep all such tweaks in one centralized file.

File location:

- `data/definitions/matchup_modifiers.json` (shared with Godot runtime)

Supported modifiers (current scope only):

- `attacker_bonus_hp` – applied to attacker's starting HP only
- `defender_bonus_hp` – applied to defender's starting HP only
- `both_bonus_hp` – applied to both combatants' starting HP
- `global_damage_multiplier` – multiplies final damage after normal damage/crit math

If a matchup key is missing, no modifiers are applied for that matchup.

Example config:

```json
{
  "RET_STARTER_vs_RET_STARTER": {
    "global_damage_multiplier": 0.9
  },
  "RET_STARTER_vs_SEC_STARTER": {
    "attacker_bonus_hp": 1
  },
  "SEC_STARTER_vs_RET_STARTER": {
    "defender_bonus_hp": 1
  }
}
```

How to tweak:

1. Edit/add matchup keys in `data/definitions/matchup_modifiers.json`.
2. Re-run `simulate`, `optimize`, or `validate` normally (modifiers apply automatically).
3. Use `--verbose` to print active modifiers and confirm the applied map.

How to disable:

- Add `--no-matchup-modifiers` to `simulate`, `optimize`, or `validate`.
- This is useful for validation baselines against historical Godot reports.

## Validation against Godot text batch logs

Expected folder contents:

- one or more `*.txt` files exported by `CombatBatchSimulator.save_batch_report(...)`
- each file should include the standard `GLADIUS Batch Report` text sections (`Inputs`, `Summary`, `Ability Usage`, `Status Applications`, `Per-Fighter Diagnostics`)

Run validation:

```bash
python -m tools.sim_optimizer.cli validate --godot-log-dir batch_reports --runs 1000 --seed 6100
```

Export for spreadsheet/manual balancing review:

```bash
python -m tools.sim_optimizer.cli validate --godot-log-dir batch_reports --runs 1500 --export-csv out/validation.csv --export-json out/validation.json
```

Drift-focused view with sample-size filter and representative simulator samples:

```bash
python -m tools.sim_optimizer.cli validate --godot-log-dir batch_reports --min-sample-size 100 --top-drift 3 --sample-logs
```

Compared metrics include matchup-level:

- win tendency (`attacker_pct` delta)
- pacing (`avg turns` and `median turns` deltas)
- action pattern deltas (`shield_bash`, `net_throw`, `recover`)
- control pattern deltas (`stun`, `entangle`, `recover`, misses, crits when available)
- drift severity classification (`GOOD`, `CLOSE`, `NEEDS REVIEW`, `HIGH DRIFT`)

### Calibration score (per matchup and overall)

The validator reports a `calibration_score` in `[0, 100]`.

It is a weighted sum of closeness components:

- winrate closeness (35%)
- average turns closeness (20%)
- median turns closeness (10%)
- action distribution closeness across shield bash / net throw / recover (15%)
- stun pattern closeness (8%)
- recover pattern closeness (6%)
- entangle pattern closeness (6%)

Each component uses `1 - min(1, abs(delta)/scale)` and is then weighted.
Overall score is a fight-count-weighted average over matchup scores.

Recommended balancing loop:

1. collect fresh Godot batch text logs from current build
2. run `validate` and inspect top drift matchups + CSV
3. tune data/rules in simulator only when drift is acceptable
4. confirm tuned changes in Godot and refresh logs

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
2. Validation references are external runtime artifacts; this repo currently does not include historical Godot batch text outputs by default.
3. The simulator now emits richer aggregate metrics and pathology indicators, but it still does not emulate Godot RNG internals exactly.

## Example artifacts

- `sample_simulation_output.json`
- `sample_validation_output.json`
- `sample_optimizer_output.json`

Generated with small run counts for quick inspection.


## New reporting and workflow commands

Run full suite:

```bash
python -m tools.sim_optimizer.cli suite --preset standard --seed 6100
```

Run a single matchup with thresholds/overrides:

```bash
python -m tools.sim_optimizer.cli simulate --attacker SEC_STARTER --defender RET_STARTER --preset deep --long-fight-threshold 80 --stun-lock-threshold 4 --modifier-overrides my_modifier_overrides.json
```

Compare multiple variants (baseline + tweaks):

```bash
python -m tools.sim_optimizer.cli compare --config tools/sim_optimizer/example_compare_config.json --preset standard
```

Presets:

- `smoke`: fast check
- `standard`: balance iteration default
- `deep`: high sample size

Key metrics include:

- win rates (attacker/defender/draw)
- turns (average/median/min/max)
- per-fighter action usage (`SHIELD_BASH`, `NET_THROW`, `RECOVER`)
- stun/entangle/off-balance/focused consumptions
- crit and miss rates
- pathology indicators (stun chains, stun-heavy fights, long fights, quick fights, high-HP winners)
