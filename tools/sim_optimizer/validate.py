from __future__ import annotations

import csv
import json
import re
from pathlib import Path
from statistics import median
from typing import Any

from .simulate import MATCHUPS, run_batch

DEFAULT_DRIFT_THRESHOLDS: dict[str, float] = {
    "winrate_good_pct": 5.0,
    "winrate_close_pct": 10.0,
    "avg_turns_good": 2.0,
    "avg_turns_close": 4.0,
    "action_good": 0.6,
    "action_close": 1.25,
    "stun_good": 0.5,
    "stun_close": 1.0,
    "entangle_good": 0.5,
    "entangle_close": 1.0,
    "crit_good": 0.5,
    "crit_close": 1.0,
    "miss_good": 1.0,
    "miss_close": 2.0,
}


def _safe_float(value: Any) -> float | None:
    if value is None:
        return None
    if isinstance(value, str):
        text = value.strip()
        if text == "":
            return None
        value = text.rstrip("%")
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _safe_int(value: Any) -> int | None:
    f = _safe_float(value)
    if f is None:
        return None
    return int(f)


def _extract_count_map(section_lines: list[str]) -> dict[str, int]:
    out: dict[str, int] = {}
    for line in section_lines:
        m = re.match(r"\s*-\s*([^:]+):\s*(-?\d+)", line)
        if not m:
            continue
        out[m.group(1).strip()] = int(m.group(2))
    return out


def _extract_between(lines: list[str], start: str, end_markers: tuple[str, ...]) -> list[str]:
    active = False
    buf: list[str] = []
    for line in lines:
        if line.strip() == start:
            active = True
            continue
        if active and line.strip() in end_markers:
            break
        if active:
            buf.append(line)
    return buf


def _normalize_action_key(raw_key: str) -> str:
    return raw_key.strip().lower()


def _find_section_start(lines: list[str], candidates: tuple[str, ...]) -> int | None:
    candidate_set = {c.strip() for c in candidates}
    for i, line in enumerate(lines):
        if line.strip() in candidate_set:
            return i
    return None


def _slice_until_marker(lines: list[str], start_idx: int, end_markers: tuple[str, ...]) -> list[str]:
    marker_set = {m.strip() for m in end_markers}
    buf: list[str] = []
    for line in lines[start_idx + 1 :]:
        if line.strip() in marker_set:
            break
        buf.append(line)
    return buf


def _parse_fighter_block(block_lines: list[str], side_label: str | None = None) -> dict[str, Any]:
    out: dict[str, Any] = {
        "wins": None,
        "losses": None,
        "miss_count": None,
        "ability_usage_counts": {},
        "status_application_counts": {},
        "status_uptime_turns": {},
        "end_hp_in_wins": None,
    }
    for line in block_lines:
        wl = re.search(r"W/L:\s*(\d+)\s*/\s*(\d+)", line)
        if wl:
            out["wins"] = int(wl.group(1))
            out["losses"] = int(wl.group(2))
        hm = re.search(r"Hit/Miss:\s*(\d+)\s*/\s*(\d+)", line)
        if hm:
            out["miss_count"] = int(hm.group(2))
        ew = re.search(r"End state in wins \(HP/STA\):\s*([0-9.]+)\s*/\s*([0-9.]+)", line)
        if ew:
            out["end_hp_in_wins"] = float(ew.group(1))

    def _capture_subsection(title: str) -> dict[str, int]:
        rows: list[str] = []
        in_sub = False
        for line in block_lines:
            st = line.strip()
            if st == title:
                in_sub = True
                continue
            if in_sub and st.startswith("-"):
                rows.append(st)
                continue
            if in_sub and st and not st.startswith("-"):
                break
        return _extract_count_map(rows)

    out["ability_usage_counts"] = _capture_subsection("- Ability usage:")
    out["status_application_counts"] = _capture_subsection("- Status applications:")
    out["status_uptime_turns"] = _capture_subsection("- Status uptime turns:")
    return out


def _extract_fighter_blocks(lines: list[str]) -> dict[str, dict[str, Any]]:
    start_idx = _find_section_start(lines, ("Per-Fighter Diagnostics:",))
    if start_idx is None:
        return {"attacker": _parse_fighter_block([], None), "defender": _parse_fighter_block([], None)}

    section = _slice_until_marker(lines, start_idx, ("Extended Aggregate Metrics:",))
    current: str | None = None
    blocks: dict[str, list[str]] = {"attacker": [], "defender": []}

    for raw_line in section:
        line = raw_line.strip()
        if not line:
            continue
        if line == "Attacker:":
            current = "attacker"
            continue
        if line == "Defender:":
            current = "defender"
            continue
        if re.match(r"^A \(.*\):$", line):
            current = "attacker"
            continue
        if re.match(r"^B \(.*\):$", line):
            current = "defender"
            continue
        if current in blocks:
            blocks[current].append(line)

    return {
        "attacker": _parse_fighter_block(blocks.get("attacker", []), "A"),
        "defender": _parse_fighter_block(blocks.get("defender", []), "B"),
    }


def parse_godot_text_report(path: Path) -> dict[str, Any] | None:
    text = path.read_text(encoding="utf-8", errors="ignore")
    lines = text.splitlines()

    if not any("GLADIUS Batch Report" in l for l in lines):
        return None

    attacker_id = None
    defender_id = None
    total_runs = None
    avg_turns = None
    min_turns = None
    max_turns = None
    a_wins = None
    b_wins = None
    draws = None

    for line in lines:
        m_a = re.match(r"\s*-\s*A:\s*.+\(([^)]+)\)", line)
        if m_a:
            attacker_id = m_a.group(1).strip()
        m_b = re.match(r"\s*-\s*B:\s*.+\(([^)]+)\)", line)
        if m_b:
            defender_id = m_b.group(1).strip()
        m_runs = re.match(r"\s*-\s*Simulations:\s*(\d+)", line)
        if m_runs:
            total_runs = int(m_runs.group(1))
        m_aw = re.match(r"\s*-\s*A wins:\s*(\d+)\s*\(([0-9.]+)%\)", line)
        if m_aw:
            a_wins = int(m_aw.group(1))
        m_bw = re.match(r"\s*-\s*B wins:\s*(\d+)\s*\(([0-9.]+)%\)", line)
        if m_bw:
            b_wins = int(m_bw.group(1))
        m_draws = re.match(r"\s*-\s*Draws/Unresolved:\s*(\d+)", line)
        if m_draws:
            draws = int(m_draws.group(1))
        m_turns = re.match(r"\s*-\s*Turns avg/min/max:\s*([0-9.]+)\s*/\s*(\d+)\s*/\s*(\d+)", line)
        if m_turns:
            avg_turns = float(m_turns.group(1))
            min_turns = int(m_turns.group(2))
            max_turns = int(m_turns.group(3))

    if not attacker_id or not defender_id:
        return None

    action_start = _find_section_start(lines, ("Ability Usage (all fights):",))
    status_start = _find_section_start(lines, ("Status Applications (all fights):",))
    terminal_start = _find_section_start(lines, ("Terminal Conditions:",))

    action_section = []
    if action_start is not None:
        action_section = _slice_until_marker(lines, action_start, ("Status Applications (all fights):", "Per-Fighter Diagnostics:"))

    status_section = []
    if status_start is not None:
        status_section = _slice_until_marker(lines, status_start, ("Per-Fighter Diagnostics:",))

    terminal_section = []
    if terminal_start is not None:
        terminal_section = _slice_until_marker(lines, terminal_start, ("Ability Usage (all fights):", "Per-Fighter Diagnostics:"))

    actions = _extract_count_map(action_section)
    statuses = _extract_count_map(status_section)
    terminals = _extract_count_map(terminal_section)

    fighters = _extract_fighter_blocks(lines)
    fighter_a = fighters.get("attacker", _parse_fighter_block([], "A"))
    fighter_b = fighters.get("defender", _parse_fighter_block([], "B"))

    return {
        "source_file": path.name,
        "matchup_key": f"{attacker_id}_vs_{defender_id}",
        "attacker_build_id": attacker_id,
        "defender_build_id": defender_id,
        "attacker_class": attacker_id.split("_", 1)[0] if "_" in attacker_id else None,
        "defender_class": defender_id.split("_", 1)[0] if "_" in defender_id else None,
        "total_runs": total_runs,
        "wins": {"attacker": a_wins, "defender": b_wins, "draw": draws},
        "turn_stats": {"average": avg_turns, "median": None, "min": min_turns, "max": max_turns},
        "terminal_condition_counts": terminals,
        "action_usage_counts": actions,
        "status_application_counts": statuses,
        "fighters": {"attacker": fighter_a, "defender": fighter_b},
    }


def load_godot_text_reports(log_dir: Path) -> tuple[list[dict[str, Any]], list[str]]:
    reports: list[dict[str, Any]] = []
    notes: list[str] = []
    if not log_dir.exists():
        return reports, notes
    for p in sorted(log_dir.glob("*.txt")):
        try:
            parsed = parse_godot_text_report(p)
        except Exception as exc:  # noqa: BLE001
            notes.append(f"Skipped malformed text report: {p.name} ({exc})")
            continue
        if not parsed:
            notes.append(f"Skipped unrecognized text report: {p.name}")
            continue
        reports.append(parsed)
    return reports, notes


def _aggregate_real_metrics(reports: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    grouped: dict[str, list[dict[str, Any]]] = {}
    for r in reports:
        grouped.setdefault(r["matchup_key"], []).append(r)

    out: dict[str, dict[str, Any]] = {}
    for matchup, items in grouped.items():
        total_fights = sum(_safe_int(i.get("total_runs")) or 0 for i in items)
        if total_fights <= 0:
            total_fights = len(items)

        a_wins = sum((_safe_int(i.get("wins", {}).get("attacker")) or 0) for i in items)
        b_wins = sum((_safe_int(i.get("wins", {}).get("defender")) or 0) for i in items)
        draws = sum((_safe_int(i.get("wins", {}).get("draw")) or 0) for i in items)

        turn_avg_num = 0.0
        turn_avg_den = 0
        turn_median_values: list[float] = []

        combined_action_counts: dict[str, int] = {}
        status_counts: dict[str, int] = {}
        misses = 0
        winner_hp_num = 0.0
        winner_hp_den = 0
        per_side_action_counts: dict[str, dict[str, int]] = {"attacker": {}, "defender": {}}
        fights_with_per_fighter_actions = 0
        fights_with_legacy_combined_only = 0

        for i in items:
            runs = _safe_int(i.get("total_runs")) or 1
            avg = _safe_float(i.get("turn_stats", {}).get("average"))
            med = _safe_float(i.get("turn_stats", {}).get("median"))
            if avg is not None:
                turn_avg_num += avg * runs
                turn_avg_den += runs
            if med is not None:
                turn_median_values.extend([med] * runs)

            for k, v in i.get("action_usage_counts", {}).items():
                combined_action_counts[k] = combined_action_counts.get(k, 0) + int(v)
            for k, v in i.get("status_application_counts", {}).items():
                status_counts[k] = status_counts.get(k, 0) + int(v)

            attacker_counts = i.get("fighters", {}).get("attacker", {}).get("ability_usage_counts", {}) or {}
            defender_counts = i.get("fighters", {}).get("defender", {}).get("ability_usage_counts", {}) or {}
            has_per_fighter = bool(attacker_counts) and bool(defender_counts)
            if has_per_fighter:
                fights_with_per_fighter_actions += runs
                for key, value in attacker_counts.items():
                    norm_key = _normalize_action_key(str(key))
                    per_side_action_counts["attacker"][norm_key] = per_side_action_counts["attacker"].get(norm_key, 0) + int(value)
                for key, value in defender_counts.items():
                    norm_key = _normalize_action_key(str(key))
                    per_side_action_counts["defender"][norm_key] = per_side_action_counts["defender"].get(norm_key, 0) + int(value)
            elif i.get("action_usage_counts"):
                fights_with_legacy_combined_only += runs

            a_miss = _safe_int(i.get("fighters", {}).get("attacker", {}).get("miss_count")) or 0
            b_miss = _safe_int(i.get("fighters", {}).get("defender", {}).get("miss_count")) or 0
            misses += a_miss + b_miss

            a_win_count = _safe_int(i.get("fighters", {}).get("attacker", {}).get("wins")) or 0
            b_win_count = _safe_int(i.get("fighters", {}).get("defender", {}).get("wins")) or 0
            a_win_hp = _safe_float(i.get("fighters", {}).get("attacker", {}).get("end_hp_in_wins"))
            b_win_hp = _safe_float(i.get("fighters", {}).get("defender", {}).get("end_hp_in_wins"))
            if a_win_hp is not None and a_win_count > 0:
                winner_hp_num += a_win_hp * a_win_count
                winner_hp_den += a_win_count
            if b_win_hp is not None and b_win_count > 0:
                winner_hp_num += b_win_hp * b_win_count
                winner_hp_den += b_win_count

        avg_turns = (turn_avg_num / turn_avg_den) if turn_avg_den else None
        med_turns = float(median(turn_median_values)) if turn_median_values else None

        attacker_actions: dict[str, float | None]
        defender_actions: dict[str, float | None]
        action_source: str
        action_notes: list[str] = []
        if fights_with_per_fighter_actions > 0:
            denom = max(1, fights_with_per_fighter_actions)
            attacker_actions = {
                "shield_bash": per_side_action_counts["attacker"].get("shield_bash", 0) / denom,
                "net_throw": per_side_action_counts["attacker"].get("net_throw", 0) / denom,
                "recover": per_side_action_counts["attacker"].get("recover", 0) / denom,
            }
            defender_actions = {
                "shield_bash": per_side_action_counts["defender"].get("shield_bash", 0) / denom,
                "net_throw": per_side_action_counts["defender"].get("net_throw", 0) / denom,
                "recover": per_side_action_counts["defender"].get("recover", 0) / denom,
            }
            action_source = "per_fighter"
            if fights_with_legacy_combined_only > 0:
                action_notes.append("Some reports only had legacy combined action fields; excluded from per-fighter drift metrics.")
        elif fights_with_legacy_combined_only > 0:
            attacker_actions = {"shield_bash": None, "net_throw": None, "recover": None}
            defender_actions = {"shield_bash": None, "net_throw": None, "recover": None}
            action_source = "legacy_combined_only"
            action_notes.append("Per-fighter action usage unavailable (legacy combined-only report format).")
        else:
            attacker_actions = {"shield_bash": None, "net_throw": None, "recover": None}
            defender_actions = {"shield_bash": None, "net_throw": None, "recover": None}
            action_source = "unavailable"
            action_notes.append("Per-fighter action usage missing from parsed reports.")

        avg_recover_usage = None
        if attacker_actions.get("recover") is not None and defender_actions.get("recover") is not None:
            avg_recover_usage = float(attacker_actions["recover"] or 0.0) + float(defender_actions["recover"] or 0.0)

        out[matchup] = {
            "total_fights": total_fights,
            "win_rates": {
                "attacker_pct": (a_wins * 100.0 / total_fights) if total_fights else 0.0,
                "defender_pct": (b_wins * 100.0 / total_fights) if total_fights else 0.0,
                "draw_pct": (draws * 100.0 / total_fights) if total_fights else 0.0,
            },
            "turn_stats": {"average": avg_turns, "median": med_turns},
            "action_usage_per_fighter": {
                "attacker": attacker_actions,
                "defender": defender_actions,
            },
            "combat_pattern_metrics": {
                "avg_stuns_applied": status_counts.get("STUNNED", 0) / total_fights,
                "avg_turns_lost_to_stun": None,
                "avg_entangled_applications": status_counts.get("ENTANGLED", 0) / total_fights,
                "avg_recover_usage": avg_recover_usage,
                "avg_off_balance_consumptions": None,
                "avg_focused_consumptions": None,
                "avg_crit_count": None,
                "avg_miss_count": misses / total_fights,
            },
            "action_usage_data_quality": {
                "source": action_source,
                "reports_with_per_fighter_actions": fights_with_per_fighter_actions,
                "reports_with_legacy_combined_only": fights_with_legacy_combined_only,
                "notes": action_notes,
            },
            "winner_remaining_hp_avg": (winner_hp_num / winner_hp_den) if winner_hp_den else None,
            "outcome_type_counts": {
                "victory": a_wins + b_wins,
                "defeat_survived": 0,
                "defeat_killed": 0,
                "draw_or_unresolved": draws,
            },
            "source_reports": [i.get("source_file", "") for i in items],
        }
    return out


def _sim_metrics_subset(payload: dict[str, Any]) -> dict[str, Any]:
    cpm = payload.get("combat_pattern_metrics", {})
    return {
        "total_fights": int(payload.get("total_runs", 0)),
        "win_rates": payload.get("win_rates", {}),
        "turn_stats": {
            "average": payload.get("turn_stats", {}).get("average"),
            "median": payload.get("turn_stats", {}).get("median"),
        },
        "action_usage_per_fighter": payload.get("action_usage_per_fighter", {}),
        "combat_pattern_metrics": {
            "avg_stuns_applied": cpm.get("avg_stuns_applied"),
            "avg_turns_lost_to_stun": cpm.get("avg_turns_lost_to_stun"),
            "avg_entangled_applications": cpm.get("avg_entangled_applications"),
            "avg_recover_usage": (
                payload.get("action_usage_per_fighter", {}).get("attacker", {}).get("recover", 0.0)
                + payload.get("action_usage_per_fighter", {}).get("defender", {}).get("recover", 0.0)
            ),
            "avg_off_balance_consumptions": cpm.get("avg_off_balance_consumptions"),
            "avg_focused_consumptions": cpm.get("avg_focused_consumptions"),
            "avg_crit_count": cpm.get("avg_crit_count"),
            "avg_miss_count": cpm.get("avg_miss_count"),
        },
        "winner_remaining_hp_avg": None,
    }


def _delta(a: float | None, b: float | None) -> float | None:
    if a is None or b is None:
        return None
    return a - b


def _action_drift(sim: dict[str, Any], real: dict[str, Any]) -> float | None:
    keys = ("shield_bash", "net_throw", "recover")
    diffs: list[float] = []
    for side in ("attacker", "defender"):
        sa = sim.get("action_usage_per_fighter", {}).get(side, {})
        ra = real.get("action_usage_per_fighter", {}).get(side, {})
        for key in keys:
            sim_v = _safe_float(sa.get(key))
            real_v = _safe_float(ra.get(key))
            if sim_v is None or real_v is None:
                continue
            diffs.append(abs(sim_v - real_v))
    if not diffs:
        return None
    return sum(diffs) / len(diffs)


def _score_component(delta_abs: float | None, scale: float) -> float | None:
    if delta_abs is None:
        return None
    return max(0.0, 1.0 - min(1.0, delta_abs / max(0.001, scale)))


def _calibration_score(sim: dict[str, Any], real: dict[str, Any]) -> tuple[float, dict[str, float]]:
    win_delta = abs(_delta(sim.get("win_rates", {}).get("attacker_pct"), real.get("win_rates", {}).get("attacker_pct")) or 0.0)
    avg_turn_delta = abs(_delta(sim.get("turn_stats", {}).get("average"), real.get("turn_stats", {}).get("average")) or 0.0)
    med_turn_delta = abs(_delta(sim.get("turn_stats", {}).get("median"), real.get("turn_stats", {}).get("median")) or 0.0)
    stun_delta = abs(_delta(sim.get("combat_pattern_metrics", {}).get("avg_turns_lost_to_stun"), real.get("combat_pattern_metrics", {}).get("avg_turns_lost_to_stun")) or 0.0)
    entangle_delta = abs(_delta(sim.get("combat_pattern_metrics", {}).get("avg_entangled_applications"), real.get("combat_pattern_metrics", {}).get("avg_entangled_applications")) or 0.0)
    recover_delta = abs(_delta(sim.get("combat_pattern_metrics", {}).get("avg_recover_usage"), real.get("combat_pattern_metrics", {}).get("avg_recover_usage")) or 0.0)
    action_delta = _action_drift(sim, real)

    raw_components = {
        "winrate": _score_component(win_delta, 20.0),
        "avg_turns": _score_component(avg_turn_delta, 8.0),
        "median_turns": _score_component(med_turn_delta, 8.0),
        "action_distribution": _score_component(action_delta, 2.0),
        "stun_pattern": _score_component(stun_delta, 2.0),
        "recover_pattern": _score_component(recover_delta, 2.5),
        "entangle_pattern": _score_component(entangle_delta, 2.5),
    }
    weights = {
        "winrate": 0.35,
        "avg_turns": 0.2,
        "median_turns": 0.1,
        "action_distribution": 0.15,
        "stun_pattern": 0.08,
        "recover_pattern": 0.06,
        "entangle_pattern": 0.06,
    }
    active = {k: v for k, v in raw_components.items() if v is not None}
    if not active:
        return 0.0, {k: 0.0 for k in weights}
    active_weight_total = sum(weights[k] for k in active)
    weighted = sum(float(active[k]) * weights[k] for k in active) / max(active_weight_total, 1e-9)
    return round(weighted * 100.0, 2), {k: float(raw_components[k]) if raw_components[k] is not None else 0.0 for k in weights}


def _severity(deltas: dict[str, float | None], thresholds: dict[str, float]) -> str:
    checks: list[tuple[float, float, float]] = []
    metric_defs = [
        ("winrate_delta", "winrate_good_pct", "winrate_close_pct"),
        ("avg_turn_delta", "avg_turns_good", "avg_turns_close"),
        ("action_drift", "action_good", "action_close"),
        ("stun_turn_delta", "stun_good", "stun_close"),
        ("entangle_delta", "entangle_good", "entangle_close"),
        ("crit_delta", "crit_good", "crit_close"),
        ("miss_delta", "miss_good", "miss_close"),
    ]
    for key, good_key, close_key in metric_defs:
        value = _safe_float(deltas.get(key))
        if value is None:
            continue
        checks.append((abs(value), thresholds[good_key], thresholds[close_key]))
    if not checks:
        return "NO COMPARABLE METRICS"
    if all(v <= good for v, good, _ in checks):
        return "GOOD"
    if all(v <= close for v, _, close in checks):
        return "CLOSE"
    if any(v > close * 1.75 for v, _, close in checks):
        return "HIGH DRIFT"
    return "NEEDS REVIEW"


def _representative_samples(samples: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    if not samples:
        return {}
    sorted_samples = sorted(samples, key=lambda s: (int(s.get("turn_count", 0)), int(s.get("seed", 0))))
    shortest = sorted_samples[0]
    longest = sorted_samples[-1]
    median_sample = sorted_samples[len(sorted_samples) // 2]
    return {"shortest": shortest, "median": median_sample, "longest": longest}


def validate_against_godot_logs(
    definitions_dir: Path,
    godot_log_dir: Path,
    runs: int,
    max_turns: int,
    seed: int,
    enable_matchup_modifiers: bool = True,
    verbose: bool = False,
    min_sample_size: int = 1,
    top_drift_count: int = 5,
    sample_logs: bool = False,
    drift_thresholds: dict[str, float] | None = None,
) -> dict[str, Any]:
    reports, notes = load_godot_text_reports(godot_log_dir)
    godot_metrics = _aggregate_real_metrics(reports)

    if godot_metrics:
        ordered_matchups = sorted(godot_metrics.keys())
    else:
        ordered_matchups = [f"{a}_vs_{b}" for a, b, _ in MATCHUPS]

    thresholds = dict(DEFAULT_DRIFT_THRESHOLDS)
    if drift_thresholds:
        thresholds.update(drift_thresholds)

    comparisons: dict[str, Any] = {}
    weighted_score_num = 0.0
    weighted_score_den = 0

    for i, matchup_key in enumerate(ordered_matchups):
        attacker, defender = matchup_key.split("_vs_", 1)
        sim_payload = run_batch(
            definitions_dir,
            attacker,
            defender,
            start_seed=seed + (i * 1000),
            simulation_count=runs,
            max_turns=max_turns,
            enable_matchup_modifiers=enable_matchup_modifiers,
            verbose=verbose,
        )
        sim_metrics = _sim_metrics_subset(sim_payload)
        real_metrics = godot_metrics.get(matchup_key)

        if real_metrics:
            action_data_quality = real_metrics.get("action_usage_data_quality", {})
            action_source = action_data_quality.get("source", "unknown")
            deltas = {
                "winrate_delta": _delta(sim_metrics["win_rates"].get("attacker_pct"), real_metrics["win_rates"].get("attacker_pct")),
                "avg_turn_delta": _delta(sim_metrics["turn_stats"].get("average"), real_metrics["turn_stats"].get("average")),
                "median_turn_delta": _delta(sim_metrics["turn_stats"].get("median"), real_metrics["turn_stats"].get("median")),
                "shield_bash_delta": _delta(sim_metrics["action_usage_per_fighter"]["attacker"].get("shield_bash"), real_metrics["action_usage_per_fighter"]["attacker"].get("shield_bash")),
                "net_throw_delta": _delta(sim_metrics["action_usage_per_fighter"]["attacker"].get("net_throw"), real_metrics["action_usage_per_fighter"]["attacker"].get("net_throw")),
                "recover_delta": _delta(sim_metrics["combat_pattern_metrics"].get("avg_recover_usage"), real_metrics["combat_pattern_metrics"].get("avg_recover_usage")),
                "stun_turn_delta": _delta(sim_metrics["combat_pattern_metrics"].get("avg_turns_lost_to_stun"), real_metrics["combat_pattern_metrics"].get("avg_turns_lost_to_stun")),
                "entangle_delta": _delta(sim_metrics["combat_pattern_metrics"].get("avg_entangled_applications"), real_metrics["combat_pattern_metrics"].get("avg_entangled_applications")),
                "crit_delta": _delta(sim_metrics["combat_pattern_metrics"].get("avg_crit_count"), real_metrics["combat_pattern_metrics"].get("avg_crit_count")),
                "miss_delta": _delta(sim_metrics["combat_pattern_metrics"].get("avg_miss_count"), real_metrics["combat_pattern_metrics"].get("avg_miss_count")),
                "action_drift": _action_drift(sim_metrics, real_metrics),
            }
            if deltas["action_drift"] is None:
                deltas["action_drift_note"] = f"skipped ({action_source})"
            calibration_score, component_scores = _calibration_score(sim_metrics, real_metrics)
            severity = _severity(deltas, thresholds)
            weight = int(real_metrics.get("total_fights", 0))
            weighted_score_num += calibration_score * weight
            weighted_score_den += weight
        else:
            deltas = {}
            calibration_score = None
            component_scores = {}
            severity = "NO GODOT DATA"

        comp: dict[str, Any] = {
            "godot": real_metrics,
            "simulator": sim_metrics,
            "deltas": deltas,
            "calibration_score": calibration_score,
            "calibration_components": component_scores,
            "drift_severity": severity,
            "parser_diagnostics": {
                "action_usage_source": (real_metrics or {}).get("action_usage_data_quality", {}).get("source"),
                "action_usage_notes": (real_metrics or {}).get("action_usage_data_quality", {}).get("notes", []),
            },
        }

        if sample_logs:
            runs_payload = []
            for s in range(3):
                sample_seed = seed + (i * 1000) + s
                sample = run_batch(
                    definitions_dir,
                    attacker,
                    defender,
                    start_seed=sample_seed,
                    simulation_count=1,
                    max_turns=max_turns,
                    enable_matchup_modifiers=enable_matchup_modifiers,
                    verbose=False,
                )
                runs_payload.append(
                    {
                        "seed": sample_seed,
                        "turn_count": int(sample.get("turn_stats", {}).get("average", 0)),
                        "winner_attacker_pct": sample.get("win_rates", {}).get("attacker_pct", 0.0),
                    }
                )
            comp["representative_sim_samples"] = _representative_samples(runs_payload)

        comparisons[matchup_key] = comp

    filtered = {
        k: v
        for k, v in comparisons.items()
        if int((v.get("godot") or {}).get("total_fights", 0)) >= min_sample_size
    }

    ranked = sorted(
        filtered.items(),
        key=lambda kv: float(kv[1].get("calibration_score") or -1.0),
    )

    return {
        "godot_log_dir": str(godot_log_dir),
        "parsed_reports": len(reports),
        "notes": notes,
        "drift_thresholds": thresholds,
        "matchups": comparisons,
        "top_drift_matchups": [
            {
                "matchup": k,
                "calibration_score": v.get("calibration_score"),
                "drift_severity": v.get("drift_severity"),
                "total_fights": (v.get("godot") or {}).get("total_fights", 0),
            }
            for k, v in ranked[:top_drift_count]
        ],
        "overall_calibration_score": (round(weighted_score_num / weighted_score_den, 2) if weighted_score_den else None),
    }


def export_validation_csv(payload: dict[str, Any], output_csv: Path) -> None:
    output_csv.parent.mkdir(parents=True, exist_ok=True)
    with output_csv.open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(
            [
                "matchup",
                "total_fights",
                "godot_attacker_win_pct",
                "sim_attacker_win_pct",
                "winrate_delta",
                "godot_avg_turns",
                "sim_avg_turns",
                "avg_turn_delta",
                "godot_median_turns",
                "sim_median_turns",
                "median_turn_delta",
                "shield_bash_delta",
                "net_throw_delta",
                "recover_delta",
                "stun_turn_delta",
                "entangle_delta",
                "crit_delta",
                "miss_delta",
                "action_drift",
                "calibration_score",
                "drift_severity",
            ]
        )
        for matchup, data in sorted(payload.get("matchups", {}).items()):
            g = data.get("godot") or {}
            s = data.get("simulator") or {}
            d = data.get("deltas") or {}
            writer.writerow(
                [
                    matchup,
                    g.get("total_fights"),
                    g.get("win_rates", {}).get("attacker_pct"),
                    s.get("win_rates", {}).get("attacker_pct"),
                    d.get("winrate_delta"),
                    g.get("turn_stats", {}).get("average"),
                    s.get("turn_stats", {}).get("average"),
                    d.get("avg_turn_delta"),
                    g.get("turn_stats", {}).get("median"),
                    s.get("turn_stats", {}).get("median"),
                    d.get("median_turn_delta"),
                    d.get("shield_bash_delta"),
                    d.get("net_throw_delta"),
                    d.get("recover_delta"),
                    d.get("stun_turn_delta"),
                    d.get("entangle_delta"),
                    d.get("crit_delta"),
                    d.get("miss_delta"),
                    d.get("action_drift"),
                    data.get("calibration_score"),
                    data.get("drift_severity"),
                ]
            )


def export_validation_json(payload: dict[str, Any], output_json: Path) -> None:
    output_json.parent.mkdir(parents=True, exist_ok=True)
    output_json.write_text(json.dumps(payload, indent=2), encoding="utf-8")
