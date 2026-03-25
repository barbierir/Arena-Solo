from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .simulate import run_suite


def _extract_reference_metrics(payload: dict[str, Any]) -> dict[str, float]:
    return {
        "attacker_win_rate": float(payload.get("win_rates", {}).get("attacker_pct", 0.0)),
        "avg_turns": float(payload.get("turn_stats", {}).get("average", 0.0)),
    }


def load_reference_reports(reference_dir: Path) -> dict[str, dict[str, Any]]:
    reports = {}
    if not reference_dir.exists():
        return reports
    for p in sorted(reference_dir.glob("*.json")):
        with p.open("r", encoding="utf-8") as f:
            payload = json.load(f)
        key = f"{payload.get('inputs', {}).get('attacker_build_id', '')}_vs_{payload.get('inputs', {}).get('defender_build_id', '')}"
        if "_vs_" in key:
            reports[key] = payload
    return reports


def compare_suite_to_references(definitions_dir: Path, reference_dir: Path, runs: int, max_turns: int, seed: int) -> dict[str, Any]:
    suite = run_suite(definitions_dir, runs=runs, max_turns=max_turns, base_seed=seed)
    references = load_reference_reports(reference_dir)
    comparisons = {}

    for matchup_key, py_result in suite.items():
        py_metrics = _extract_reference_metrics(py_result)
        ref_payload = references.get(matchup_key)
        if ref_payload:
            ref_metrics = _extract_reference_metrics(ref_payload)
            comparisons[matchup_key] = {
                "python": py_metrics,
                "reference": ref_metrics,
                "delta": {
                    "attacker_win_rate": py_metrics["attacker_win_rate"] - ref_metrics["attacker_win_rate"],
                    "avg_turns": py_metrics["avg_turns"] - ref_metrics["avg_turns"],
                },
            }
        else:
            comparisons[matchup_key] = {
                "python": py_metrics,
                "reference": None,
                "delta": None,
                "note": "No reference report JSON found for this matchup.",
            }

    return {
        "reference_dir": str(reference_dir),
        "references_found": len(references),
        "comparisons": comparisons,
    }
