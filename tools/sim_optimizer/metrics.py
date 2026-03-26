from __future__ import annotations

from collections import defaultdict
from statistics import median
from typing import Any

from .models import CombatRuntime


def make_initial_result(
    attacker: str,
    defender: str,
    start_seed: int,
    runs: int,
    max_turns: int,
    seeds: list[int],
    matchup_modifiers: dict[str, Any],
    pathology_thresholds: dict[str, float],
) -> dict[str, Any]:
    return {
        "inputs": {
            "attacker_build_id": attacker,
            "defender_build_id": defender,
            "start_seed": start_seed,
            "simulation_count": runs,
            "max_turns": max_turns,
        },
        "configuration": {
            "matchup_modifiers": dict(matchup_modifiers),
            "pathology_thresholds": dict(pathology_thresholds),
        },
        "seeds_used": seeds,
        "total_runs": runs,
        "wins": {"attacker": 0, "defender": 0, "draws_or_unresolved": 0},
        "win_rates": {"attacker_pct": 0.0, "defender_pct": 0.0, "draw_pct": 0.0},
        "turn_stats": {"average": 0.0, "median": 0.0, "min": 0, "max": 0},
        "terminal_condition_counts": {},
        "action_usage_counts": {},
        "status_application_counts": {},
        "action_usage_per_fighter": {},
        "combat_pattern_metrics": {},
        "pathology": {},
    }


def _max_consecutive_stun_losses(runtime: CombatRuntime) -> dict[str, int]:
    streaks = {"A": 0, "B": 0}
    max_streaks = {"A": 0, "B": 0}
    for ev in runtime.combat_events:
        if ev.get("type") != "TURN_SKIPPED":
            continue
        actor = str(ev.get("actor_side_id", ""))
        active = set(ev.get("active_status_ids", []))
        if actor in streaks and "STUNNED" in active:
            streaks[actor] += 1
            max_streaks[actor] = max(max_streaks[actor], streaks[actor])
    return max_streaks


def finalize_result(result: dict[str, Any], runtimes: list[CombatRuntime], thresholds: dict[str, float]) -> dict[str, Any]:
    if not runtimes:
        return result
    turns = [r.turn_index for r in runtimes]
    result["turn_stats"] = {
        "average": sum(turns) / len(turns),
        "median": float(median(turns)),
        "min": min(turns),
        "max": max(turns),
    }

    action_counts = defaultdict(int)
    action_counts_by_side = {"A": defaultdict(int), "B": defaultdict(int)}
    status_counts = defaultdict(int)
    terminal_counts = defaultdict(int)

    stuns_applied = 0
    turns_lost_to_stun = 0
    entangled_applied = 0
    off_balance_consumed = 0
    focused_consumed = 0
    crit_count = 0
    miss_count = 0

    fights_two_plus_consecutive_stun = 0
    fights_stun_heavy = 0
    long_fights = 0
    quick_fights = 0
    high_hp_decisive = 0

    for r in runtimes:
        if r.result_state == "VICTORY":
            result["wins"]["attacker"] += 1
        elif r.result_state == "DEFEAT":
            result["wins"]["defender"] += 1
        else:
            result["wins"]["draws_or_unresolved"] += 1

        if r.turn_index >= int(thresholds.get("long_fight_turns", 70)):
            long_fights += 1
        if r.turn_index <= int(thresholds.get("quick_fight_turns", 8)):
            quick_fights += 1

        stun_turn_counts = {"A": 0, "B": 0}
        for ev in r.combat_events:
            etype = ev.get("type")
            if etype == "ACTION_USED":
                skill_id = ev.get("skill_id", "UNKNOWN")
                action_counts[skill_id] += 1
                actor_side = str(ev.get("actor_side_id", ""))
                if actor_side in action_counts_by_side:
                    action_counts_by_side[actor_side][skill_id] += 1
                if not bool(ev.get("hit", False)):
                    miss_count += 1
                if bool(ev.get("is_crit", False)):
                    crit_count += 1
            elif etype == "STATUS_APPLIED":
                status_id = ev.get("status_id", "UNKNOWN")
                status_counts[status_id] += 1
                if status_id == "STUNNED":
                    stuns_applied += 1
                if status_id == "ENTANGLED":
                    entangled_applied += 1
            elif etype == "COMBAT_ENDED":
                terminal_counts[ev.get("terminal_condition", "UNKNOWN")] += 1
            elif etype == "TURN_SKIPPED":
                active = set(ev.get("active_status_ids", []))
                actor_side = str(ev.get("actor_side_id", ""))
                if "STUNNED" in active:
                    turns_lost_to_stun += 1
                    if actor_side in stun_turn_counts:
                        stun_turn_counts[actor_side] += 1
            elif etype == "STATUS_CONSUMED":
                status_id = ev.get("status_id")
                if status_id == "OFF_BALANCE":
                    off_balance_consumed += 1
                if status_id == "FOCUSED":
                    focused_consumed += 1

        max_stun_streak = _max_consecutive_stun_losses(r)
        if max(max_stun_streak.values()) >= int(thresholds.get("consecutive_stun_loss_threshold", 2)):
            fights_two_plus_consecutive_stun += 1
        if max(stun_turn_counts.values()) >= int(thresholds.get("stun_turns_threshold", 3)):
            fights_stun_heavy += 1

        winner_side = r.winner_combatant_id
        if winner_side in {"A", "B"}:
            winner = r.combatant_states[winner_side]
            if winner.max_hp > 0 and (float(winner.current_hp) / float(winner.max_hp)) >= float(thresholds.get("high_hp_win_ratio", 0.6)):
                high_hp_decisive += 1

    runs = len(runtimes)
    result["win_rates"]["attacker_pct"] = (result["wins"]["attacker"] * 100.0) / runs
    result["win_rates"]["defender_pct"] = (result["wins"]["defender"] * 100.0) / runs
    result["win_rates"]["draw_pct"] = (result["wins"]["draws_or_unresolved"] * 100.0) / runs
    result["action_usage_counts"] = dict(sorted(action_counts.items()))
    result["status_application_counts"] = dict(sorted(status_counts.items()))
    result["terminal_condition_counts"] = dict(sorted(terminal_counts.items()))

    result["action_usage_per_fighter"] = {
        "attacker": {
            "shield_bash": action_counts_by_side["A"].get("SHIELD_BASH", 0) / runs,
            "net_throw": action_counts_by_side["A"].get("NET_THROW", 0) / runs,
            "recover": action_counts_by_side["A"].get("RECOVER", 0) / runs,
        },
        "defender": {
            "shield_bash": action_counts_by_side["B"].get("SHIELD_BASH", 0) / runs,
            "net_throw": action_counts_by_side["B"].get("NET_THROW", 0) / runs,
            "recover": action_counts_by_side["B"].get("RECOVER", 0) / runs,
        },
    }

    result["combat_pattern_metrics"] = {
        "avg_stuns_applied": stuns_applied / runs,
        "avg_turns_lost_to_stun": turns_lost_to_stun / runs,
        "avg_entangled_applications": entangled_applied / runs,
        "avg_off_balance_consumptions": off_balance_consumed / runs,
        "avg_focused_consumptions": focused_consumed / runs,
        "avg_crit_count": crit_count / runs,
        "avg_miss_count": miss_count / runs,
    }

    result["pathology"] = {
        "fights_with_2plus_consecutive_stun_losses_pct": (fights_two_plus_consecutive_stun * 100.0) / runs,
        "fights_with_stun_heavy_side_pct": (fights_stun_heavy * 100.0) / runs,
        "fights_exceeding_long_threshold_pct": (long_fights * 100.0) / runs,
        "fights_at_or_below_quick_threshold_pct": (quick_fights * 100.0) / runs,
        "fights_with_high_hp_winner_pct": (high_hp_decisive * 100.0) / runs,
    }

    return result


def matchup_key(attacker: str, defender: str) -> str:
    return f"{attacker}_vs_{defender}"
