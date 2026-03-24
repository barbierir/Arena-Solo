extends RefCounted
class_name ActionResolver

const HIT_CHANCE_SYSTEM_SCRIPT := preload("res://scripts/combat/systems/HitChanceSystem.gd")
const DAMAGE_SYSTEM_SCRIPT := preload("res://scripts/combat/systems/DamageSystem.gd")
const STAMINA_SYSTEM_SCRIPT := preload("res://scripts/combat/systems/StaminaSystem.gd")
const STATUS_SYSTEM_SCRIPT := preload("res://scripts/combat/systems/StatusSystem.gd")
const VICTORY_RESOLVER_SCRIPT := preload("res://scripts/combat/systems/VictoryResolver.gd")
const SECUTOR_AI_POLICY_SCRIPT := preload("res://scripts/combat/ai/SecutorAiPolicy.gd")

var _hit_chance_system: HitChanceSystem
var _damage_system: DamageSystem
var _stamina_system: StaminaSystem
var _status_system: StatusSystem
var _victory_resolver: VictoryResolver
var _secutor_ai_policy: SecutorAiPolicy

func configure(content_registry: ContentRegistry, rng_service: SeededRngService) -> void:
	_hit_chance_system = HIT_CHANCE_SYSTEM_SCRIPT.new()
	_damage_system = DAMAGE_SYSTEM_SCRIPT.new()
	_stamina_system = STAMINA_SYSTEM_SCRIPT.new()
	_status_system = STATUS_SYSTEM_SCRIPT.new()
	_victory_resolver = VICTORY_RESOLVER_SCRIPT.new()
	_secutor_ai_policy = SECUTOR_AI_POLICY_SCRIPT.new()
	_secutor_ai_policy.configure(content_registry)

func resolve_turn(runtime_state: CombatRuntimeState) -> void:
	var skill_id := _secutor_ai_policy.choose_action(runtime_state.defender_build_id, runtime_state)
	var hit_chance := _hit_chance_system.calculate_placeholder_hit_chance(skill_id)
	var damage := _damage_system.calculate_placeholder_damage(skill_id)
	_stamina_system.apply_turn_regen(runtime_state)
	_status_system.tick_statuses(runtime_state)
	runtime_state.append_log("Auto action selected: %s (hit %.2f, dmg %d)" % [skill_id, hit_chance, damage])
	_victory_resolver.resolve_if_decided(runtime_state)
