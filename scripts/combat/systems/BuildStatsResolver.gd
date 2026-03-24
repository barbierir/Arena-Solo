extends RefCounted
class_name BuildStatsResolver

var _content_registry: ContentRegistry

func configure(content_registry: ContentRegistry) -> void:
	_content_registry = content_registry

func resolve_build_stats(build_id: String) -> Dictionary:
	var build: Dictionary = _content_registry.builds.get("entries", {}).get(build_id, {})
	var class_def: Dictionary = _content_registry.classes.get("entries", {}).get(build.get("class_id", ""), {})

	var stats := {
		"max_hp": int(class_def.get("base_hp", 0)) + int(build.get("bonus_hp", 0)),
		"max_sta": int(class_def.get("base_sta", 0)) + int(build.get("bonus_sta", 0)),
		"atk": int(class_def.get("base_atk", 0)) + int(build.get("bonus_atk", 0)),
		"def": int(class_def.get("base_def", 0)) + int(build.get("bonus_def", 0)),
		"spd": int(class_def.get("base_spd", 0)) + int(build.get("bonus_spd", 0)),
		"skl": int(class_def.get("base_skl", 0)) + int(build.get("bonus_skl", 0)),
		"total_hit_mod_pct": 0.0,
		"total_crit_mod_pct": 0.0,
	}

	for item_id: String in [
		str(build.get("weapon_item_id", "")),
		str(build.get("offhand_item_id", "")),
		str(build.get("armor_item_id", "")),
		str(build.get("accessory_item_id", "")),
	]:
		if item_id == "":
			continue
		var item: Dictionary = _content_registry.equipment.get("entries", {}).get(item_id, {})
		stats.max_hp += int(item.get("hp_mod", 0))
		stats.max_sta += int(item.get("sta_mod", 0))
		stats.atk += int(item.get("atk_mod", 0))
		stats.def += int(item.get("def_mod", 0))
		stats.spd += int(item.get("spd_mod", 0))
		stats.skl += int(item.get("skl_mod", 0))
		stats.total_hit_mod_pct += float(item.get("hit_mod_pct", 0.0))
		stats.total_crit_mod_pct += float(item.get("crit_mod_pct", 0.0))

	return stats
