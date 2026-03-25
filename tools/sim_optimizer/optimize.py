from __future__ import annotations

import itertools
import json
import tempfile
import shutil
import random
from pathlib import Path
from typing import Any

from .loader import load_definitions
from .simulate import run_batch


def load_param_config(path: Path | None) -> dict[str, list[int]]:
    if path is None:
        return {
            "SECUTOR.base_def": [5, 6, 7],
            "SECUTOR.base_sta": [7, 8, 9],
            "SHIELD_BASH.sta_cost": [3, 4, 5],
            "SHIELD_BASH.flat_damage": [0, 1, 2],
            "RECOVER.sta_cost": [0, 1],
        }
    with path.open("r", encoding="utf-8") as f:
        payload = json.load(f)
    return {str(k): list(v) for k, v in payload.items()}


def _apply_params(defs_dir: Path, params: dict[str, int], tmp_dir: Path) -> Path:
    src = defs_dir
    dst = tmp_dir
    dst.mkdir(parents=True, exist_ok=True)
    for p in src.glob("*.json"):
        dst.joinpath(p.name).write_text(p.read_text(encoding="utf-8"), encoding="utf-8")

    def read(name: str) -> dict[str, Any]:
        return json.loads(dst.joinpath(name).read_text(encoding="utf-8"))

    def write(name: str, payload: dict[str, Any]) -> None:
        dst.joinpath(name).write_text(json.dumps(payload, indent=2), encoding="utf-8")

    classes = read("classes.json")
    skills = read("skills.json")

    for key, value in params.items():
        if key.startswith("SECUTOR."):
            field = key.split(".", 1)[1]
            classes["entries"]["SECUTOR"][field] = value
        elif key.startswith("SHIELD_BASH."):
            field = key.split(".", 1)[1]
            skills["entries"]["SHIELD_BASH"][field] = value
        elif key.startswith("RECOVER."):
            field = key.split(".", 1)[1]
            skills["entries"]["RECOVER"][field] = value

    write("classes.json", classes)
    write("skills.json", skills)
    return dst


def _score(matchups: dict[str, dict[str, Any]]) -> float:
    score = 0.0

    ret_ret = matchups["RET_STARTER_vs_RET_STARTER"]
    sec_sec = matchups["SEC_STARTER_vs_SEC_STARTER"]
    sec_ret = matchups["SEC_STARTER_vs_RET_STARTER"]

    score += abs(ret_ret["win_rates"]["attacker_pct"] - 50.0) * 4.0
    score += max(0.0, ret_ret["turn_stats"]["average"] - 70.0) * 2.0

    sec_turns = sec_sec["turn_stats"]["average"]
    if sec_turns < 35.0:
        score += (35.0 - sec_turns) * 2.0
    elif sec_turns > 50.0:
        score += (sec_turns - 50.0) * 2.0

    sec_wr = sec_ret["win_rates"]["attacker_pct"]
    if sec_wr < 60.0:
        score += (60.0 - sec_wr) * 3.0
    elif sec_wr > 65.0:
        score += (sec_wr - 65.0) * 3.0

    for m in matchups.values():
        if m["turn_stats"]["average"] > 90.0:
            score += 100.0
        blowout = max(m["win_rates"]["attacker_pct"], m["win_rates"]["defender_pct"])
        if blowout > 95.0:
            score += (blowout - 95.0) * 10.0
    return score


def optimize(
    definitions_dir: Path,
    trials: int,
    runs_per_matchup: int,
    max_turns: int,
    seed: int,
    param_config: Path | None,
) -> dict[str, Any]:
    param_space = load_param_config(param_config)
    rng = random.Random(seed)

    keys = list(param_space.keys())
    all_combos = list(itertools.product(*(param_space[k] for k in keys)))
    if trials > 0 and trials < len(all_combos):
        combos = rng.sample(all_combos, trials)
    else:
        combos = all_combos

    candidates = []
    tmp_base = Path(tempfile.mkdtemp(prefix="sim_optimizer_"))

    for idx, combo in enumerate(combos):
        params = {k: int(v) for k, v in zip(keys, combo)}
        candidate_defs = _apply_params(definitions_dir, params, tmp_base / f"cand_{idx}")
        matchups = {
            "RET_STARTER_vs_RET_STARTER": run_batch(candidate_defs, "RET_STARTER", "RET_STARTER", 7100, runs_per_matchup, max_turns),
            "SEC_STARTER_vs_SEC_STARTER": run_batch(candidate_defs, "SEC_STARTER", "SEC_STARTER", 6100, runs_per_matchup, max_turns),
            "RET_STARTER_vs_SEC_STARTER": run_batch(candidate_defs, "RET_STARTER", "SEC_STARTER", 9100, runs_per_matchup, max_turns),
            "SEC_STARTER_vs_RET_STARTER": run_batch(candidate_defs, "SEC_STARTER", "RET_STARTER", 8100, runs_per_matchup, max_turns),
        }
        candidates.append({"params": params, "score": _score(matchups), "matchups": matchups})

    candidates.sort(key=lambda x: x["score"])
    shutil.rmtree(tmp_base, ignore_errors=True)
    return {
        "trial_count": len(combos),
        "runs_per_matchup": runs_per_matchup,
        "max_turns": max_turns,
        "seed": seed,
        "best": candidates[:20],
    }
