from __future__ import annotations

import json
from pathlib import Path
from typing import Any


def load_matchup_modifiers(path: Path) -> dict[str, dict[str, Any]]:
    if not path.exists():
        return {}
    with path.open("r", encoding="utf-8") as f:
        payload = json.load(f)
    if not isinstance(payload, dict):
        return {}

    entries = payload.get("entries", payload)
    if not isinstance(entries, dict):
        return {}

    out: dict[str, dict[str, Any]] = {}
    for matchup_key, modifiers in entries.items():
        if isinstance(matchup_key, str) and isinstance(modifiers, dict):
            out[matchup_key] = dict(modifiers)
    return out


def get_matchup_modifiers(attacker_id: str, defender_id: str, path: Path) -> dict[str, Any]:
    key = f"{attacker_id}_vs_{defender_id}"
    return dict(load_matchup_modifiers(path).get(key, {}))
