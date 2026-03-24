extends RefCounted
class_name ActionResolver

const HIT_CHANCE_SYSTEM_SCRIPT := preload("res://scripts/combat/systems/HitChanceSystem.gd")
const DAMAGE_SYSTEM_SCRIPT := preload("res://scripts/combat/systems/DamageSystem.gd")
const STAMINA_SYSTEM_SCRIPT := preload("res://scripts/combat/systems/StaminaSystem.gd")
const STATUS_SYSTEM_SCRIPT := preload("res://scripts/combat/systems/StatusSystem.gd")
const VICTORY_RESOLVER_SCRIPT := preload("res://scripts/combat/systems/VictoryResolver.gd")
const SECUTOR_AI_POLICY_SCRIPT := preload("res://scripts/combat/ai/SecutorAiPolicy.gd")

var _content_registry: ContentRegistry
var _rng_service: SeededRngService
var _hit_chance_system: HitChanceSystem
var _damage_system: DamageSystem
var _stamina_system: StaminaSystem
var _status_system: StatusSystem
var _victory_resolver: VictoryResolver
var _secutor_ai_policy: SecutorAiPolicy

func configure(content_registry: ContentRegistry, rng_service: SeededRngService) -> void:
	_content_registry = content_registry
	_rng_service = rng_service
	_hit_chance_system = HIT_CHANCE_SYSTEM_SCRIPT.new()
	_damage_system = DAMAGE_SYSTEM_SCRIPT.new()
	_stamina_system = STAMINA_SYSTEM_SCRIPT.new()
	_status_system = STATUS_SYSTEM_SCRIPT.new()
	_victory_resolver = VICTORY_RESOLVER_SCRIPT.new()
	_secutor_ai_policy = SECUTOR_AI_POLICY_SCRIPT.new()
	_secutor_ai_policy.configure(content_registry)

func resolve_turn(runtime_state: CombatRuntimeState, actor_id: String) -> void:
	if runtime_state.result_state != "PENDING":
		return
	var controls: Dictionary = _content_registry.combat_rules.get("entries", {}).get("COMBAT_CONTROLS", {})
	var statuses: Dictionary = _content_registry.status_effects.get("entries", {})
	var skills: Dictionary = _content_registry.skills.get("entries", {})

	var actor: CombatantRuntimeState = runtime_state.combatant_states.get(actor_id)
	var target: CombatantRuntimeState = _other_combatant(runtime_state, actor_id)
	if actor == null or target == null or not actor.is_alive() or not target.is_alive():
		_victory_resolver.resolve_if_decided(runtime_state)
		return

	actor.temporary_defense_bonus = 0
	var actor_statuses_before: String = actor.status_labels(statuses)
	var actor_hp_before: int = actor.current_hp
	var actor_sta_before: int = actor.current_sta
	var target_statuses_before: String = target.status_labels(statuses)
	var target_hp_before: int = target.current_hp
	var target_sta_before: int = target.current_sta
	var regen: int = _stamina_system.apply_turn_regen(actor, controls, statuses)
	runtime_state.append_log("%s regenerates %d STA -> %d/%d." % [actor.display_name, regen, actor.current_sta, actor.max_sta])
	_status_system.update_exhausted(actor)
	_tick_cooldowns(actor)
	runtime_state.append_event("TURN_TELEMETRY", {
		"phase": "START_OF_TURN",
		"actor_side_id": actor.combatant_id,
		"actor_build_id": actor.build_id,
		"actor_hp_before": actor_hp_before,
		"actor_sta_before": actor_sta_before,
		"actor_hp_after": actor.current_hp,
		"actor_sta_after": actor.current_sta,
		"actor_statuses_before": actor_statuses_before,
		"actor_statuses_after": actor.status_labels(statuses),
		"actor_active_status_ids": _active_status_ids(actor),
		"target_side_id": target.combatant_id,
		"target_build_id": target.build_id,
		"target_hp_before": target_hp_before,
		"target_sta_before": target_sta_before,
		"target_hp_after": target.current_hp,
		"target_sta_after": target.current_sta,
		"target_statuses_before": target_statuses_before,
		"target_statuses_after": target.status_labels(statuses),
		"target_active_status_ids": _active_status_ids(target),
		"stamina_regen": regen,
	})

	if not _status_system.can_act(actor, statuses):
		runtime_state.append_log("%s is stunned and loses the turn." % actor.display_name)
		_status_system.tick_status_durations(actor)
		var skip_dot: int = _status_system.apply_end_of_turn_effects(actor, statuses)
		if skip_dot > 0:
			runtime_state.append_log("%s takes %d DOT damage." % [actor.display_name, skip_dot])
		_victory_resolver.resolve_if_decided(runtime_state)
		_append_end_of_turn_telemetry(runtime_state, actor, target, statuses, skip_dot)
		return

	var skill_id: String = _choose_action(actor, target, runtime_state)
	var skill: Dictionary = skills.get(skill_id, skills.get("BASIC_ATTACK", {}))
	if int(skill.get("sta_cost", 999)) > actor.current_sta:
		skill = skills.get("RECOVER", {})
		skill_id = "RECOVER"

	_execute_action(runtime_state, actor, target, skill_id, skill, controls, statuses)
	if runtime_state.result_state != "PENDING":
		_append_end_of_turn_telemetry(runtime_state, actor, target, statuses, 0)
		return
	_status_system.tick_status_durations(actor)
	_status_system.update_exhausted(actor)
	var dot: int = _status_system.apply_end_of_turn_effects(actor, statuses)
	if dot > 0:
		runtime_state.append_log("%s takes %d DOT damage." % [actor.display_name, dot])
	_victory_resolver.resolve_if_decided(runtime_state)
	_append_end_of_turn_telemetry(runtime_state, actor, target, statuses, dot)

func _choose_action(actor: CombatantRuntimeState, target: CombatantRuntimeState, runtime_state: CombatRuntimeState) -> String:
	if actor.class_id == "SECUTOR":
		return _secutor_ai_policy.choose_action(actor, target, runtime_state)
	if actor.current_sta <= 2:
		return "RECOVER"
	if int(actor.cooldowns.get("NET_THROW", 0)) <= 0 and actor.current_sta >= 3 and not target.has_status("ENTANGLED"):
		return "NET_THROW"
	if actor.current_sta >= 2:
		return "BASIC_ATTACK"
	return "RECOVER"

func _execute_action(runtime_state: CombatRuntimeState, actor: CombatantRuntimeState, target: CombatantRuntimeState, skill_id: String, skill: Dictionary, controls: Dictionary, status_defs: Dictionary) -> void:
	var sta_cost: int = int(skill.get("sta_cost", 0))
	_stamina_system.spend(actor, sta_cost)
	_status_system.update_exhausted(actor)

	if skill_id == "RECOVER":
		var recovered: int = _stamina_system.recover(actor, controls)
		runtime_state.append_log("%s uses Recover and restores %d STA." % [actor.display_name, recovered])
		runtime_state.append_event("ACTION_USED", {
			"actor_side_id": actor.combatant_id,
			"actor_build_id": actor.build_id,
			"target_side_id": target.combatant_id,
			"target_build_id": target.build_id,
			"skill_id": skill_id,
			"hit": false,
			"damage": 0,
		})
		return

	if skill_id == "DEFEND":
		actor.temporary_defense_bonus = int(controls.get("defend_bonus_def", 2))
		runtime_state.append_log("%s uses Defend (+%d DEF until next action)." % [actor.display_name, actor.temporary_defense_bonus])
		runtime_state.append_event("ACTION_USED", {
			"actor_side_id": actor.combatant_id,
			"actor_build_id": actor.build_id,
			"target_side_id": target.combatant_id,
			"target_build_id": target.build_id,
			"skill_id": skill_id,
			"hit": false,
			"damage": 0,
		})
		return

	var conditional_hit_bonus: float = _conditional_equipment_hit_bonus(actor, skill_id)
	var hit_chance: float = _hit_chance_system.calculate(actor, target, skill, controls, status_defs, conditional_hit_bonus)
	var hit_roll: float = _rng_service.randf()
	if hit_roll > hit_chance:
		runtime_state.append_log("%s uses %s: miss (%.2f > %.2f)." % [actor.display_name, skill.get("display_name", skill_id), hit_roll, hit_chance])
		runtime_state.append_event("ACTION_USED", {
			"actor_side_id": actor.combatant_id,
			"actor_build_id": actor.build_id,
			"target_side_id": target.combatant_id,
			"target_build_id": target.build_id,
			"skill_id": skill_id,
			"hit": false,
			"damage": 0,
		})
		_set_cooldown(actor, skill_id, skill)
		return

	var base_damage: int = _damage_system.calculate_base_damage(actor, target, skill, controls, status_defs)
	var crit_chance: float = _hit_chance_system.calculate_crit(actor, skill, controls)
	var resolved: Dictionary = _damage_system.resolve_damage(base_damage, crit_chance, float(controls.get("crit_multiplier", 2.0)), _rng_service)
	var damage: int = int(resolved.damage)
	target.current_hp = maxi(0, target.current_hp - damage)
	var crit_tag: String = ""
	if bool(resolved.is_crit):
		crit_tag = " CRIT"
	runtime_state.append_log("%s uses %s and hits for %d%s damage. %s HP: %d/%d." % [actor.display_name, skill.get("display_name", skill_id), damage, crit_tag, target.display_name, target.current_hp, target.max_hp])
	runtime_state.append_event("ACTION_USED", {
		"actor_side_id": actor.combatant_id,
		"actor_build_id": actor.build_id,
		"target_side_id": target.combatant_id,
		"target_build_id": target.build_id,
		"skill_id": skill_id,
		"hit": true,
		"damage": damage,
		"is_crit": bool(resolved.is_crit),
	})
	_victory_resolver.resolve_if_decided(runtime_state)
	if runtime_state.result_state != "PENDING":
		runtime_state.append_event("TURN_TELEMETRY", {
			"phase": "POST_LETHAL_CHECK",
			"actor_side_id": actor.combatant_id,
			"actor_build_id": actor.build_id,
			"target_side_id": target.combatant_id,
			"target_build_id": target.build_id,
			"target_hp_after_action": target.current_hp,
			"combat_ended_immediately": true,
			"terminal_result_state": runtime_state.result_state,
		})
		return

	var status_id: String = str(skill.get("apply_status_id", ""))
	if status_id != "":
		_status_system.apply_status(target, status_id, int(skill.get("status_turns", 0)), skill_id, status_defs)
		runtime_state.append_log("%s is afflicted with %s (%d turns)." % [target.display_name, status_id, int(skill.get("status_turns", 0))])
		runtime_state.append_event("STATUS_APPLIED", {
			"target_side_id": target.combatant_id,
			"target_build_id": target.build_id,
			"status_id": status_id,
			"source_skill_id": skill_id,
			"duration_turns": int(skill.get("status_turns", 0)),
		})

	_set_cooldown(actor, skill_id, skill)

func _conditional_equipment_hit_bonus(actor: CombatantRuntimeState, skill_id: String) -> float:
	if skill_id != "NET_THROW":
		return 0.0
	var build: Dictionary = _content_registry.builds.get("entries", {}).get(actor.build_id, {})
	var offhand_id: String = str(build.get("offhand_item_id", ""))
	var item: Dictionary = _content_registry.equipment.get("entries", {}).get(offhand_id, {})
	return float(item.get("hit_mod_pct", 0.0))

func _set_cooldown(actor: CombatantRuntimeState, skill_id: String, skill: Dictionary) -> void:
	var cooldown: int = int(skill.get("cooldown_turns", 0))
	if cooldown > 0:
		actor.cooldowns[skill_id] = cooldown

func _tick_cooldowns(actor: CombatantRuntimeState) -> void:
	var next: Dictionary = {}
	for skill_id in actor.cooldowns.keys():
		var remaining: int = int(actor.cooldowns[skill_id]) - 1
		if remaining > 0:
			next[skill_id] = remaining
	actor.cooldowns = next

func _other_combatant(runtime_state: CombatRuntimeState, actor_id: String) -> CombatantRuntimeState:
	return runtime_state.combatant_states.get(runtime_state.other_side_id(actor_id))

func _append_end_of_turn_telemetry(runtime_state: CombatRuntimeState, actor: CombatantRuntimeState, target: CombatantRuntimeState, status_defs: Dictionary, dot_damage: int) -> void:
	runtime_state.append_event("TURN_TELEMETRY", {
		"phase": "END_OF_TURN",
		"actor_side_id": actor.combatant_id,
		"actor_build_id": actor.build_id,
		"actor_hp_after": actor.current_hp,
		"actor_sta_after": actor.current_sta,
		"actor_statuses_after": actor.status_labels(status_defs),
		"actor_active_status_ids": _active_status_ids(actor),
		"target_side_id": target.combatant_id,
		"target_build_id": target.build_id,
		"target_hp_after": target.current_hp,
		"target_sta_after": target.current_sta,
		"target_statuses_after": target.status_labels(status_defs),
		"target_active_status_ids": _active_status_ids(target),
		"dot_damage_applied": dot_damage,
		"terminal_result_state": runtime_state.result_state,
	})

func _active_status_ids(combatant: CombatantRuntimeState) -> Array[String]:
	var status_ids: Array[String] = []
	for entry in combatant.active_statuses:
		var status_id: String = str(entry.get("status_id", ""))
		if status_id == "":
			continue
		status_ids.append(status_id)
	return status_ids
