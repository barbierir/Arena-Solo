extends SceneTree

const CONTENT_LOADER_SCRIPT := preload("res://scripts/data/loaders/ContentLoader.gd")
const RNG_SERVICE_SCRIPT := preload("res://scripts/utilities/SeededRngService.gd")
const COMBAT_SIMULATION_SCRIPT := preload("res://scripts/combat/CombatSimulation.gd")
const HIT_CHANCE_SYSTEM_SCRIPT := preload("res://scripts/combat/systems/HitChanceSystem.gd")
const DAMAGE_SYSTEM_SCRIPT := preload("res://scripts/combat/systems/DamageSystem.gd")
const STAMINA_SYSTEM_SCRIPT := preload("res://scripts/combat/systems/StaminaSystem.gd")
const STATUS_SYSTEM_SCRIPT := preload("res://scripts/combat/systems/StatusSystem.gd")
const BUILD_STATS_RESOLVER_SCRIPT := preload("res://scripts/combat/systems/BuildStatsResolver.gd")

func _initialize() -> void:
	var loader := CONTENT_LOADER_SCRIPT.new()
	var registry: ContentRegistry = loader.load_all_definitions()
	_test_build_stats(registry)
	_test_hit_and_damage_formula(registry)
	_test_stamina_and_status_tick(registry)
	_test_deterministic_replay(registry)
	print("All vertical-slice tests passed")
	quit(0)

func _test_build_stats(registry: ContentRegistry) -> void:
	var resolver := BUILD_STATS_RESOLVER_SCRIPT.new()
	resolver.configure(registry)
	var ret := resolver.resolve_build_stats("RET_STARTER")
	assert(ret.max_hp == 22 and ret.max_sta == 10 and ret.atk == 8 and ret.def == 4 and ret.spd == 8 and ret.skl == 9)
	var sec := resolver.resolve_build_stats("SEC_STARTER")
	assert(sec.max_hp == 26 and sec.max_sta == 9 and sec.atk == 9 and sec.def == 10 and sec.spd == 3 and sec.skl == 5)

func _test_hit_and_damage_formula(registry: ContentRegistry) -> void:
	var rng := RNG_SERVICE_SCRIPT.new(5)
	var sim := COMBAT_SIMULATION_SCRIPT.new()
	sim.configure(registry, rng)
	sim.bootstrap_default_encounter("RET_STARTER", "SEC_STARTER")
	var attacker: CombatantRuntimeState = sim.runtime_state.combatant_states["RET_STARTER"]
	var defender: CombatantRuntimeState = sim.runtime_state.combatant_states["SEC_STARTER"]
	var controls: Dictionary = registry.combat_rules.entries.COMBAT_CONTROLS
	var hit_sys := HIT_CHANCE_SYSTEM_SCRIPT.new()
	var hit := hit_sys.calculate(attacker, defender, registry.skills.entries.BASIC_ATTACK, controls, registry.status_effects.entries)
	assert(abs(hit - 0.8) < 0.001)
	var dmg_sys := DAMAGE_SYSTEM_SCRIPT.new()
	var base_damage := dmg_sys.calculate_base_damage(attacker, defender, registry.skills.entries.BASIC_ATTACK, controls, registry.status_effects.entries)
	assert(base_damage == 1)

func _test_stamina_and_status_tick(registry: ContentRegistry) -> void:
	var resolver := BUILD_STATS_RESOLVER_SCRIPT.new()
	resolver.configure(registry)
	var stats := resolver.resolve_build_stats("RET_STARTER")
	var actor := CombatantRuntimeState.new()
	actor.max_sta = stats.max_sta
	actor.current_sta = 0
	actor.active_statuses.append({"status_id":"EXHAUSTED","remaining_turns":1})
	var stamina := STAMINA_SYSTEM_SCRIPT.new()
	var regen := stamina.apply_turn_regen(actor, registry.combat_rules.entries.COMBAT_CONTROLS, registry.status_effects.entries)
	assert(regen == 1)
	var status := STATUS_SYSTEM_SCRIPT.new()
	status.tick_status_durations(actor)
	assert(actor.active_statuses.is_empty())

func _test_deterministic_replay(registry: ContentRegistry) -> void:
	var sim_a := COMBAT_SIMULATION_SCRIPT.new()
	sim_a.configure(registry, RNG_SERVICE_SCRIPT.new(1234))
	sim_a.bootstrap_default_encounter("RET_STARTER", "SEC_STARTER")
	sim_a.simulate_to_completion()

	var sim_b := COMBAT_SIMULATION_SCRIPT.new()
	sim_b.configure(registry, RNG_SERVICE_SCRIPT.new(1234))
	sim_b.bootstrap_default_encounter("RET_STARTER", "SEC_STARTER")
	sim_b.simulate_to_completion()

	assert(sim_a.runtime_state.result_state == sim_b.runtime_state.result_state)
	assert(sim_a.runtime_state.combat_log == sim_b.runtime_state.combat_log)
