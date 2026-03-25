from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .models import BuildStats, Definitions


DEF_FILES = {
    "classes": "classes.json",
    "builds": "builds.json",
    "equipment": "equipment.json",
    "skills": "skills.json",
    "status_effects": "status_effects.json",
    "combat_rules": "combat_rules.json",
}


def _load_entries(path: Path) -> dict[str, dict[str, Any]]:
    with path.open("r", encoding="utf-8") as f:
        payload = json.load(f)
    return payload.get("entries", {})


def load_definitions(definitions_dir: Path) -> Definitions:
    entries = {k: _load_entries(definitions_dir / filename) for k, filename in DEF_FILES.items()}
    controls = entries["combat_rules"].get("COMBAT_CONTROLS", {})
    return Definitions(
        classes=entries["classes"],
        builds=entries["builds"],
        equipment=entries["equipment"],
        skills=entries["skills"],
        status_effects=entries["status_effects"],
        combat_controls=controls,
    )


def resolve_build_stats(defs: Definitions, build_id: str) -> BuildStats:
    build = defs.builds[build_id]
    class_def = defs.classes[build["class_id"]]

    max_hp = int(class_def.get("base_hp", 0)) + int(build.get("bonus_hp", 0))
    max_sta = int(class_def.get("base_sta", 0)) + int(build.get("bonus_sta", 0))
    atk = int(class_def.get("base_atk", 0)) + int(build.get("bonus_atk", 0))
    defense = int(class_def.get("base_def", 0)) + int(build.get("bonus_def", 0))
    spd = int(class_def.get("base_spd", 0)) + int(build.get("bonus_spd", 0))
    skl = int(class_def.get("base_skl", 0)) + int(build.get("bonus_skl", 0))
    hit_mod = 0.0
    crit_mod = 0.0

    for key in ["weapon_item_id", "offhand_item_id", "armor_item_id", "accessory_item_id"]:
        item_id = build.get(key, "")
        if not item_id:
            continue
        item = defs.equipment.get(item_id, {})
        max_hp += int(item.get("hp_mod", 0))
        max_sta += int(item.get("sta_mod", 0))
        atk += int(item.get("atk_mod", 0))
        defense += int(item.get("def_mod", 0))
        spd += int(item.get("spd_mod", 0))
        skl += int(item.get("skl_mod", 0))
        hit_mod += float(item.get("hit_mod_pct", 0.0))
        crit_mod += float(item.get("crit_mod_pct", 0.0))

    return BuildStats(max_hp, max_sta, atk, defense, spd, skl, hit_mod, crit_mod)
