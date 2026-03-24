extends RefCounted
class_name StatusSystem

func can_act(actor: CombatantRuntimeState, status_defs: Dictionary) -> bool:
	for status in actor.active_statuses:
		var definition: Dictionary = status_defs.get(status.get("status_id", ""), {})
		if bool(definition.get("skip_turn", false)):
			return false
	return true

func apply_status(target: CombatantRuntimeState, status_id: String, turns: int, source_skill_id: String, status_defs: Dictionary) -> void:
	if status_id == "" or turns <= 0:
		return
	var definition: Dictionary = status_defs.get(status_id, {})
	var stack_rule: String = str(definition.get("stack_rule", "Refresh"))
	for idx in range(target.active_statuses.size()):
		var existing: Dictionary = target.active_statuses[idx]
		if existing.get("status_id", "") != status_id:
			continue
		if stack_rule == "Replace" or stack_rule == "Refresh":
			existing["remaining_turns"] = turns
			existing["applied_by_skill_id"] = source_skill_id
			target.active_statuses[idx] = existing
			return
	target.active_statuses.append({
		"status_id": status_id,
		"remaining_turns": turns,
		"applied_by_skill_id": source_skill_id,
	})

func apply_end_of_turn_effects(actor: CombatantRuntimeState, status_defs: Dictionary) -> int:
	var dot_total := 0
	for status in actor.active_statuses:
		var definition: Dictionary = status_defs.get(status.get("status_id", ""), {})
		dot_total += int(definition.get("dot_damage", 0))
	if dot_total > 0:
		actor.current_hp = maxi(0, actor.current_hp - dot_total)
	return dot_total

func tick_status_durations(actor: CombatantRuntimeState) -> void:
	var updated: Array[Dictionary] = []
	for status in actor.active_statuses:
		var remain := int(status.get("remaining_turns", 0)) - 1
		if remain > 0:
			status["remaining_turns"] = remain
			updated.append(status)
	actor.active_statuses = updated

func update_exhausted(actor: CombatantRuntimeState) -> void:
	if actor.current_sta == 0:
		if not actor.has_status("EXHAUSTED"):
			actor.active_statuses.append({"status_id": "EXHAUSTED", "remaining_turns": 1, "applied_by_skill_id": "RUNTIME"})
	else:
		var next_statuses: Array[Dictionary] = []
		for entry in actor.active_statuses:
			if entry.get("status_id", "") != "EXHAUSTED":
				next_statuses.append(entry)
		actor.active_statuses = next_statuses
