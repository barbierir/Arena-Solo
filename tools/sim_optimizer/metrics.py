from __future__ import annotations

from collections import defaultdict
from typing import Any

from .models import CombatRuntime


def make_initial_result(attacker: str, defender: str, start_seed: int, runs: int, max_turns: int, seeds: list[int]) -> dict[str, Any]:
    return {
        "inputs": {
            "attacker_build_id": attacker,
            "defender_build_id": defender,
            "start_seed": start_seed,
            "simulation_count": runs,
            "max_turns": max_turns,
        },
        "seeds_used": seeds,
        "total_runs": runs,
        "wins": {"attacker": 0, "defender": 0, "draws_or_unresolved": 0},
        "win_rates": {"attacker_pct": 0.0, "defender_pct": 0.0},
        "turn_stats": {"average": 0.0, "min": 0, "max": 0},
        "terminal_condition_counts": {},
        "action_usage_counts": {},
        "status_application_counts": {},
    }


def finalize_result(result: dict[str, Any], runtimes: list[CombatRuntime]) -> dict[str, Any]:
    if not runtimes:
        return result
    turns = [r.turn_index for r in runtimes]
    result["turn_stats"] = {"average": sum(turns) / len(turns), "min": min(turns), "max": max(turns)}

    action_counts = defaultdict(int)
    status_counts = defaultdict(int)
    terminal_counts = defaultdict(int)

    for r in runtimes:
        if r.result_state == "VICTORY":
            result["wins"]["attacker"] += 1
        elif r.result_state == "DEFEAT":
            result["wins"]["defender"] += 1
        else:
            result["wins"]["draws_or_unresolved"] += 1

        for ev in r.combat_events:
            if ev["type"] == "ACTION_USED":
                action_counts[ev.get("skill_id", "UNKNOWN")] += 1
            elif ev["type"] == "STATUS_APPLIED":
                status_counts[ev.get("status_id", "UNKNOWN")] += 1
            elif ev["type"] == "COMBAT_ENDED":
                terminal_counts[ev.get("terminal_condition", "UNKNOWN")] += 1

    runs = len(runtimes)
    result["win_rates"]["attacker_pct"] = (result["wins"]["attacker"] * 100.0) / runs
    result["win_rates"]["defender_pct"] = (result["wins"]["defender"] * 100.0) / runs
    result["action_usage_counts"] = dict(sorted(action_counts.items()))
    result["status_application_counts"] = dict(sorted(status_counts.items()))
    result["terminal_condition_counts"] = dict(sorted(terminal_counts.items()))
    return result


def matchup_key(attacker: str, defender: str) -> str:
    return f"{attacker}_vs_{defender}"
