from __future__ import annotations

from pathlib import Path
from typing import Any

from .engine import CombatEngine
from .loader import load_definitions
from .matchup_modifiers import get_matchup_modifiers
from .metrics import finalize_result, make_initial_result

PRESETS: dict[str, dict[str, int]] = {
    "smoke": {"runs": 100, "max_turns": 96},
    "standard": {"runs": 1000, "max_turns": 128},
    "deep": {"runs": 10000, "max_turns": 192},
}

DEFAULT_PATHOLOGY_THRESHOLDS: dict[str, float] = {
    "long_fight_turns": 70,
    "quick_fight_turns": 8,
    "stun_turns_threshold": 3,
    "high_hp_win_ratio": 0.6,
    "consecutive_stun_loss_threshold": 2,
}


MATCHUPS = [
    ("RET_STARTER", "RET_STARTER", 1000),
    ("SEC_STARTER", "SEC_STARTER", 0),
    ("RET_STARTER", "SEC_STARTER", 3000),
    ("SEC_STARTER", "RET_STARTER", 2000),
]


def progressive_seeds(start_seed: int, count: int) -> list[int]:
    return [start_seed + i for i in range(max(0, count))]


def run_batch(
    definitions_dir: Path,
    attacker_build_id: str,
    defender_build_id: str,
    start_seed: int,
    simulation_count: int,
    max_turns: int = 128,
    enable_matchup_modifiers: bool = True,
    matchup_modifier_overrides: dict[str, Any] | None = None,
    pathology_thresholds: dict[str, float] | None = None,
    verbose: bool = False,
) -> dict[str, Any]:
    defs = load_definitions(definitions_dir)
    base_modifiers = {}
    if enable_matchup_modifiers:
        base_modifiers = get_matchup_modifiers(attacker_build_id, defender_build_id, definitions_dir / "matchup_modifiers.json")
    matchup_modifiers = dict(base_modifiers)
    if matchup_modifier_overrides:
        matchup_modifiers.update(matchup_modifier_overrides)

    thresholds = dict(DEFAULT_PATHOLOGY_THRESHOLDS)
    if pathology_thresholds:
        thresholds.update(pathology_thresholds)

    if verbose:
        print(f"[matchup_modifiers] {attacker_build_id}_vs_{defender_build_id}: {matchup_modifiers or '{}'}")

    seed_list = progressive_seeds(start_seed, simulation_count)
    result = make_initial_result(
        attacker_build_id,
        defender_build_id,
        start_seed,
        simulation_count,
        max_turns,
        seed_list,
        matchup_modifiers,
        thresholds,
    )
    runtimes = []
    for seed in seed_list:
        engine = CombatEngine(defs, seed=seed, matchup_modifiers=matchup_modifiers)
        runtime = engine.initialize_fight(attacker_build_id, defender_build_id)
        runtimes.append(engine.run_to_completion(runtime, max_turns=max_turns))
    return finalize_result(result, runtimes, thresholds)


def run_suite(
    definitions_dir: Path,
    runs: int,
    max_turns: int,
    base_seed: int = 6100,
    enable_matchup_modifiers: bool = True,
    matchup_modifier_overrides: dict[str, Any] | None = None,
    pathology_thresholds: dict[str, float] | None = None,
    verbose: bool = False,
) -> dict[str, Any]:
    out = {}
    for attacker, defender, seed_offset in MATCHUPS:
        seed = base_seed + seed_offset
        out[f"{attacker}_vs_{defender}"] = run_batch(
            definitions_dir,
            attacker,
            defender,
            seed,
            runs,
            max_turns,
            enable_matchup_modifiers=enable_matchup_modifiers,
            matchup_modifier_overrides=matchup_modifier_overrides,
            pathology_thresholds=pathology_thresholds,
            verbose=verbose,
        )
    return out


def compare_variants(
    definitions_dir: Path,
    variants: list[dict[str, Any]],
    runs: int,
    max_turns: int,
    base_seed: int,
    pathology_thresholds: dict[str, float] | None,
    verbose: bool = False,
) -> dict[str, Any]:
    output: dict[str, Any] = {"variants": {}}
    for idx, variant in enumerate(variants):
        name = str(variant.get("name", f"variant_{idx + 1}"))
        variant_defs = Path(variant.get("definitions_dir", definitions_dir))
        seed_offset = int(variant.get("seed_offset", 0))
        variant_thresholds = dict(pathology_thresholds or {})
        variant_thresholds.update(variant.get("pathology_thresholds", {}))
        output["variants"][name] = run_suite(
            definitions_dir=variant_defs,
            runs=runs,
            max_turns=max_turns,
            base_seed=base_seed + seed_offset,
            enable_matchup_modifiers=not bool(variant.get("no_matchup_modifiers", False)),
            matchup_modifier_overrides=variant.get("matchup_modifier_overrides", {}),
            pathology_thresholds=variant_thresholds,
            verbose=verbose,
        )

    names = list(output["variants"].keys())
    baseline_name = names[0] if names else ""
    output["comparison"] = {"baseline": baseline_name, "deltas": {}}

    if baseline_name:
        baseline = output["variants"][baseline_name]
        for other_name in names[1:]:
            other = output["variants"][other_name]
            by_matchup: dict[str, Any] = {}
            for matchup_key, base_result in baseline.items():
                alt_result = other.get(matchup_key, {})
                by_matchup[matchup_key] = {
                    "attacker_winrate_shift": float(alt_result.get("win_rates", {}).get("attacker_pct", 0.0)) - float(base_result.get("win_rates", {}).get("attacker_pct", 0.0)),
                    "avg_turn_shift": float(alt_result.get("turn_stats", {}).get("average", 0.0)) - float(base_result.get("turn_stats", {}).get("average", 0.0)),
                    "stun_lock_shift": float(alt_result.get("pathology", {}).get("fights_with_2plus_consecutive_stun_losses_pct", 0.0)) - float(base_result.get("pathology", {}).get("fights_with_2plus_consecutive_stun_losses_pct", 0.0)),
                }
            output["comparison"]["deltas"][f"{baseline_name}_to_{other_name}"] = by_matchup

    return output
