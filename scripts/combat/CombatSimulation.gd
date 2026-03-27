extends RefCounted
class_name CombatSimulation

const COMBAT_RUNTIME_STATE_SCRIPT := preload("res://scripts/combat/runtime/CombatRuntimeState.gd")
const COMBATANT_RUNTIME_STATE_SCRIPT := preload("res://scripts/combat/runtime/CombatantRuntimeState.gd")
const TURN_CONTROLLER_SCRIPT := preload("res://scripts/combat/TurnController.gd")
const BUILD_STATS_RESOLVER_SCRIPT := preload("res://scripts/combat/systems/BuildStatsResolver.gd")
const MATCHUP_MODIFIER_RESOLVER_SCRIPT := preload("res://scripts/combat/systems/MatchupModifierResolver.gd")

var content_registry: ContentRegistry
var rng_service: SeededRngService
var runtime_state: CombatRuntimeState
var turn_controller: TurnController
var build_stats_resolver: BuildStatsResolver
var matchup_modifier_resolver: MatchupModifierResolver

func configure(registry: ContentRegistry, rng: SeededRngService) -> void:
	content_registry = registry
	rng_service = rng
	turn_controller = TURN_CONTROLLER_SCRIPT.new()
	turn_controller.configure(registry, rng)
	build_stats_resolver = BUILD_STATS_RESOLVER_SCRIPT.new()
	build_stats_resolver.configure(registry)
	matchup_modifier_resolver = MATCHUP_MODIFIER_RESOLVER_SCRIPT.new()

func bootstrap_default_encounter(attacker_build_id: String, defender_build_id: String) -> void:
	initialize_fight(attacker_build_id, defender_build_id)

func initialize_fight(attacker_build_id: String, defender_build_id: String, attacker_label: String = "", defender_label: String = "") -> void:
	runtime_state = COMBAT_RUNTIME_STATE_SCRIPT.new()
	runtime_state.attacker_build_id = attacker_build_id
	runtime_state.defender_build_id = defender_build_id
	runtime_state.combatant_states[CombatRuntimeState.ATTACKER_SIDE_ID] = _make_combatant_state(attacker_build_id, CombatRuntimeState.ATTACKER_SIDE_ID)
	runtime_state.combatant_states[CombatRuntimeState.DEFENDER_SIDE_ID] = _make_combatant_state(defender_build_id, CombatRuntimeState.DEFENDER_SIDE_ID)
	# Matchup modifiers are resolved once at encounter start and then consumed by
	# downstream systems (HP initialization here, damage multiplier in DamageSystem).
	runtime_state.matchup_modifiers = matchup_modifier_resolver.resolve(attacker_build_id, defender_build_id, content_registry)
	_apply_matchup_hp_modifiers(runtime_state)
	runtime_state.next_actor_id = _resolve_first_actor()
	var log_attacker: String = attacker_build_id if attacker_label.strip_edges() == "" else attacker_label
	var log_defender: String = defender_build_id if defender_label.strip_edges() == "" else defender_label
	runtime_state.attacker_state().display_name = log_attacker
	runtime_state.defender_state().display_name = log_defender
	runtime_state.append_log("Encounter initialized: %s vs %s (seed=%d)" % [log_attacker, log_defender, rng_service.get_seed()])
	if not runtime_state.matchup_modifiers.is_empty():
		runtime_state.append_log("Matchup modifiers active: %s" % JSON.stringify(runtime_state.matchup_modifiers))

func simulate_single_turn() -> void:
	if runtime_state == null or is_finished():
		return
	turn_controller.execute_turn(runtime_state)

func simulate_to_completion(max_turns: int = 64) -> CombatRuntimeState:
	for _i in range(max_turns):
		if is_finished():
			break
		simulate_single_turn()
	if runtime_state != null and runtime_state.result_state == "PENDING":
		runtime_state.result_state = "ABORTED"
		runtime_state.append_log("Combat aborted after max turns (%d)." % max_turns)
		runtime_state.append_event("COMBAT_ENDED", {
			"terminal_condition": "MAX_TURNS_ABORT",
			"winner_build_id": "",
			"winner_combatant_id": "",
		})
	return runtime_state

func run_to_completion(max_turns: int = 64) -> CombatRuntimeState:
	return simulate_to_completion(max_turns)

func step_turn() -> void:
	simulate_single_turn()

func is_finished() -> bool:
	return runtime_state != null and runtime_state.result_state != "PENDING"

func get_runtime_state() -> CombatRuntimeState:
	return runtime_state

func get_log() -> Array[String]:
	if runtime_state == null:
		return []
	return runtime_state.combat_log

func _make_combatant_state(build_id: String, combatant_id: String) -> CombatantRuntimeState:
	var state: CombatantRuntimeState = COMBATANT_RUNTIME_STATE_SCRIPT.new()
	var build: Dictionary = content_registry.builds.get("entries", {}).get(build_id, {})
	var stats: Dictionary = build_stats_resolver.resolve_build_stats(build_id)
	state.combatant_id = combatant_id
	state.build_id = build_id
	state.class_id = str(build.get("class_id", ""))
	state.display_name = str(build.get("display_name", build_id))
	state.max_hp = int(stats.max_hp)
	state.max_sta = int(stats.max_sta)
	state.current_hp = state.max_hp
	state.current_sta = state.max_sta
	state.base_atk = int(stats.atk)
	state.base_def = int(stats.def)
	state.base_spd = int(stats.spd)
	state.base_skl = int(stats.skl)
	state.total_hit_mod_pct = float(stats.total_hit_mod_pct)
	state.total_crit_mod_pct = float(stats.total_crit_mod_pct)
	return state

func _apply_matchup_hp_modifiers(state: CombatRuntimeState) -> void:
	var modifiers: Dictionary = state.matchup_modifiers
	if modifiers.is_empty():
		return
	# HP-only matchup fields are applied during encounter bootstrap before turn 1.
	# "both_bonus_hp" stacks with side-specific bonus fields when present.
	var attacker_bonus: int = int(modifiers.get("attacker_bonus_hp", 0)) + int(modifiers.get("both_bonus_hp", 0))
	var defender_bonus: int = int(modifiers.get("defender_bonus_hp", 0)) + int(modifiers.get("both_bonus_hp", 0))
	if attacker_bonus != 0:
		_apply_hp_bonus(state.attacker_state(), attacker_bonus)
	if defender_bonus != 0:
		_apply_hp_bonus(state.defender_state(), defender_bonus)

func _apply_hp_bonus(combatant: CombatantRuntimeState, bonus_hp: int) -> void:
	if combatant == null or bonus_hp == 0:
		return
	combatant.max_hp = maxi(1, combatant.max_hp + bonus_hp)
	combatant.current_hp = combatant.max_hp

func _resolve_first_actor() -> String:
	var attacker: CombatantRuntimeState = runtime_state.attacker_state()
	var defender: CombatantRuntimeState = runtime_state.defender_state()
	if attacker.base_spd > defender.base_spd:
		return CombatRuntimeState.ATTACKER_SIDE_ID
	if defender.base_spd > attacker.base_spd:
		return CombatRuntimeState.DEFENDER_SIDE_ID
	return CombatRuntimeState.ATTACKER_SIDE_ID if rng_service.randf() <= 0.5 else CombatRuntimeState.DEFENDER_SIDE_ID
