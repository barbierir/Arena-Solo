from __future__ import annotations

import itertools
import json
import tempfile
import shutil
import random
from pathlib import Path
from typing import Any
from math import prod

from .loader import load_definitions
from .simulate import run_batch


def load_param_config(path: Path | None) -> dict[str, list[float | int]]:
    if path is None:
        return {
            "SHIELD_BASH.cooldown_turns": [1, 2, 3],
            "NET_THROW.flat_damage": [0, 1, 2],
            "NET_THROW.sta_cost": [4, 5, 6],
            "NET_THROW.cooldown_turns": [2, 3, 4],
            "RECOVER.sta_cost": [0, 1, 2],
            "COMBAT_CONTROLS.recover_bonus_stamina": [2, 3, 4],
            "COMBAT_CONTROLS.recover_focus_hit_bonus_pct": [8, 10, 12],
            "COMBAT_CONTROLS.entangled_target_hit_bonus_pct": [10, 12, 14],
            "COMBAT_CONTROLS.net_throw_off_balance_damage_penalty": [25, 30, 35],
            "COMBAT_CONTROLS.finisher_pressure_bonus_damage": [1, 2, 3],
            "RETIARIUS.base_atk": [5, 6, 7],
            "RETIARIUS.base_spd": [7, 8, 9],
            "SECUTOR.base_atk": [6, 7, 8],
        }
    with path.open("r", encoding="utf-8") as f:
        payload = json.load(f)
    return {str(k): list(v) for k, v in payload.items()}


def _split_param_key(key: str) -> tuple[str, str]:
    try:
        entity_id, field = key.split(".", 1)
    except ValueError as exc:
        raise ValueError(
            f"Invalid optimizer parameter key '{key}'. Expected format '<ID>.<field>' or "
            "'MATCHUP.<ATTACKER_vs_DEFENDER>.<field>'."
        ) from exc
    if not entity_id or not field:
        raise ValueError(
            f"Invalid optimizer parameter key '{key}'. Expected non-empty '<ID>.<field>'."
        )
    return entity_id, field


def _apply_params(defs_dir: Path, params: dict[str, float | int], tmp_dir: Path) -> Path:
    src = defs_dir
    dst = tmp_dir
    dst.mkdir(parents=True, exist_ok=True)
    for p in src.glob("*.json"):
        dst.joinpath(p.name).write_text(p.read_text(encoding="utf-8"), encoding="utf-8")

    def read(name: str) -> dict[str, Any]:
        return json.loads(dst.joinpath(name).read_text(encoding="utf-8"))

    def write(name: str, payload: dict[str, Any]) -> None:
        dst.joinpath(name).write_text(json.dumps(payload, indent=2), encoding="utf-8")

    definitions = {
        "classes.json": read("classes.json"),
        "skills.json": read("skills.json"),
        "combat_rules.json": read("combat_rules.json"),
        "matchup_modifiers.json": read("matchup_modifiers.json"),
    }
    entries_by_file: dict[str, dict[str, Any]] = {}
    for name, payload in definitions.items():
        entries = payload.get("entries")
        if not isinstance(entries, dict):
            raise ValueError(f"Definition file '{name}' is missing top-level 'entries' map.")
        entries_by_file[name] = entries

    for key, value in params.items():
        if key.startswith("MATCHUP."):
            parts = key.split(".", 2)
            if len(parts) != 3 or not parts[1] or not parts[2]:
                raise ValueError(
                    f"Invalid MATCHUP key '{key}'. Expected 'MATCHUP.<ATTACKER_vs_DEFENDER>.<field>'."
                )
            matchup_key, field = parts[1], parts[2]
            matchup_entries = entries_by_file["matchup_modifiers.json"]
            if matchup_key not in matchup_entries:
                raise ValueError(
                    f"Unknown matchup key '{matchup_key}' in optimizer key '{key}'. "
                    f"Available keys: {sorted(matchup_entries.keys())}"
                )
            target = matchup_entries[matchup_key]
            if field not in target:
                raise ValueError(
                    f"Unknown field '{field}' for matchup '{matchup_key}' in key '{key}'. "
                    f"Available fields: {sorted(target.keys())}"
                )
            target[field] = value
            continue

        entity_id, field = _split_param_key(key)
        candidate_files = [
            file_name
            for file_name in ("classes.json", "skills.json", "combat_rules.json")
            if entity_id in entries_by_file[file_name]
        ]
        if not candidate_files:
            raise ValueError(
                f"Unknown optimizer parameter target '{entity_id}' in key '{key}'. "
                "Expected a class ID, skill ID, COMBAT_CONTROLS, or MATCHUP.* key."
            )
        if len(candidate_files) > 1:
            raise ValueError(
                f"Ambiguous optimizer key '{key}'. Target '{entity_id}' exists in multiple definition files: "
                f"{candidate_files}"
            )
        target_file = candidate_files[0]
        target_entry = entries_by_file[target_file][entity_id]
        if field not in target_entry:
            raise ValueError(
                f"Unknown field '{field}' for '{entity_id}' in key '{key}' ({target_file}). "
                f"Available fields: {sorted(target_entry.keys())}"
            )
        target_entry[field] = value

    for name, payload in definitions.items():
        write(name, payload)
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
    enable_matchup_modifiers: bool = True,
    verbose: bool = False,
) -> dict[str, Any]:
    param_space = load_param_config(param_config)
    rng = random.Random(seed)

    keys = list(param_space.keys())
    values_per_key = [param_space[k] for k in keys]
    total_combos = prod(len(values) for values in values_per_key)
    if total_combos == 0:
        raise ValueError("Parameter config must provide at least one candidate value for each key.")

    if trials > 0:
        combos = [tuple(rng.choice(values) for values in values_per_key) for _ in range(trials)]
    else:
        max_exhaustive = 500_000
        if total_combos > max_exhaustive:
            raise ValueError(
                f"Exhaustive search requires {total_combos} combinations, which exceeds safe limit "
                f"({max_exhaustive}). Use --trials with random sampling or narrow the parameter ranges."
            )
        combos = list(itertools.product(*values_per_key))

    candidates = []
    tmp_base = Path(tempfile.mkdtemp(prefix="sim_optimizer_"))

    for idx, combo in enumerate(combos):
        params = {k: v for k, v in zip(keys, combo)}
        candidate_defs = _apply_params(definitions_dir, params, tmp_base / f"cand_{idx}")
        matchups = {
            "RET_STARTER_vs_RET_STARTER": run_batch(
                candidate_defs,
                "RET_STARTER",
                "RET_STARTER",
                7100,
                runs_per_matchup,
                max_turns,
                enable_matchup_modifiers=enable_matchup_modifiers,
                verbose=verbose,
            ),
            "SEC_STARTER_vs_SEC_STARTER": run_batch(
                candidate_defs,
                "SEC_STARTER",
                "SEC_STARTER",
                6100,
                runs_per_matchup,
                max_turns,
                enable_matchup_modifiers=enable_matchup_modifiers,
                verbose=verbose,
            ),
            "RET_STARTER_vs_SEC_STARTER": run_batch(
                candidate_defs,
                "RET_STARTER",
                "SEC_STARTER",
                9100,
                runs_per_matchup,
                max_turns,
                enable_matchup_modifiers=enable_matchup_modifiers,
                verbose=verbose,
            ),
            "SEC_STARTER_vs_RET_STARTER": run_batch(
                candidate_defs,
                "SEC_STARTER",
                "RET_STARTER",
                8100,
                runs_per_matchup,
                max_turns,
                enable_matchup_modifiers=enable_matchup_modifiers,
                verbose=verbose,
            ),
        }
        candidates.append({"params": params, "score": _score(matchups), "matchups": matchups})

    candidates.sort(key=lambda x: x["score"])
    shutil.rmtree(tmp_base, ignore_errors=True)
    return {
        "trial_count": len(combos),
        "search_space_size": total_combos,
        "runs_per_matchup": runs_per_matchup,
        "max_turns": max_turns,
        "seed": seed,
        "best": candidates[:20],
    }
