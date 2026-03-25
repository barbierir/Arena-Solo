from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .simulate import run_suite


def _extract_reference_metrics(payload: dict[str, Any]) -> dict[str, float]:
    batch_result = payload.get("batch_result", payload)
    return {
        "attacker_win_rate": float(batch_result.get("win_rates", {}).get("attacker_pct", 0.0)),
        "avg_turns": float(batch_result.get("turn_stats", {}).get("average", 0.0)),
    }


def _reference_key(payload: dict[str, Any]) -> str | None:
    batch_result = payload.get("batch_result", payload)
    inputs = batch_result.get("inputs", {})
    attacker = str(inputs.get("attacker_build_id", "")).strip()
    defender = str(inputs.get("defender_build_id", "")).strip()
    if not attacker or not defender:
        return None
    return f"{attacker}_vs_{defender}"


def load_reference_reports(reference_dir: Path) -> tuple[dict[str, dict[str, Any]], list[str]]:
    reports = {}
    notes: list[str] = []
    if not reference_dir.exists():
        return reports, notes
    for p in sorted(reference_dir.glob("*.json")):
        try:
            with p.open("r", encoding="utf-8") as f:
                payload = json.load(f)
        except json.JSONDecodeError as exc:
            notes.append(f"Skipped malformed JSON: {p.name} ({exc.msg})")
            continue

        key = _reference_key(payload)
        if not key:
            notes.append(
                f"Skipped unreadable report: {p.name} (missing batch_result.inputs.attacker_build_id/defender_build_id)"
            )
            continue
        reports[key] = payload
    return reports, notes


def compare_suite_to_references(definitions_dir: Path, reference_dir: Path, runs: int, max_turns: int, seed: int) -> dict[str, Any]:
    suite = run_suite(definitions_dir, runs=runs, max_turns=max_turns, base_seed=seed)
    references, reference_notes = load_reference_reports(reference_dir)
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
        "reference_notes": reference_notes,
        "comparisons": comparisons,
    }
