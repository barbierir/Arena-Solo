from __future__ import annotations

from pathlib import Path
from typing import Any

from .engine import CombatEngine
from .loader import load_definitions
from .matchup_modifiers import get_matchup_modifiers
from .metrics import finalize_result, make_initial_result


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
    verbose: bool = False,
) -> dict[str, Any]:
    defs = load_definitions(definitions_dir)
    matchup_modifiers = get_matchup_modifiers(attacker_build_id, defender_build_id) if enable_matchup_modifiers else {}
    if verbose:
        print(f"[matchup_modifiers] {attacker_build_id}_vs_{defender_build_id}: {matchup_modifiers or '{}'}")
    seed_list = progressive_seeds(start_seed, simulation_count)
    result = make_initial_result(attacker_build_id, defender_build_id, start_seed, simulation_count, max_turns, seed_list)
    runtimes = []
    for seed in seed_list:
        engine = CombatEngine(defs, seed=seed, matchup_modifiers=matchup_modifiers)
        runtime = engine.initialize_fight(attacker_build_id, defender_build_id)
        runtimes.append(engine.run_to_completion(runtime, max_turns=max_turns))
    return finalize_result(result, runtimes)


def run_suite(
    definitions_dir: Path,
    runs: int,
    max_turns: int,
    base_seed: int = 6100,
    enable_matchup_modifiers: bool = True,
    verbose: bool = False,
) -> dict[str, Any]:
    scenarios = [
        ("RET_STARTER", "RET_STARTER", base_seed + 1000),
        ("SEC_STARTER", "SEC_STARTER", base_seed + 0),
        ("RET_STARTER", "SEC_STARTER", base_seed + 3000),
        ("SEC_STARTER", "RET_STARTER", base_seed + 2000),
    ]
    out = {}
    for attacker, defender, seed in scenarios:
        out[f"{attacker}_vs_{defender}"] = run_batch(
            definitions_dir,
            attacker,
            defender,
            seed,
            runs,
            max_turns,
            enable_matchup_modifiers=enable_matchup_modifiers,
            verbose=verbose,
        )
    return out
