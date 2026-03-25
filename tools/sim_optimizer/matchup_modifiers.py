from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path
from typing import Any

MATCHUP_MODIFIERS_FILE = Path(__file__).with_name("matchup_modifiers.json")


@lru_cache(maxsize=1)
def load_matchup_modifiers(path: Path = MATCHUP_MODIFIERS_FILE) -> dict[str, dict[str, Any]]:
    if not path.exists():
        return {}
    with path.open("r", encoding="utf-8") as f:
        payload = json.load(f)
    if not isinstance(payload, dict):
        return {}
    out: dict[str, dict[str, Any]] = {}
    for matchup_key, modifiers in payload.items():
        if isinstance(matchup_key, str) and isinstance(modifiers, dict):
            out[matchup_key] = modifiers
    return out


def get_matchup_modifiers(attacker_id: str, defender_id: str, path: Path = MATCHUP_MODIFIERS_FILE) -> dict[str, Any]:
    key = f"{attacker_id}_vs_{defender_id}"
    return dict(load_matchup_modifiers(path).get(key, {}))
