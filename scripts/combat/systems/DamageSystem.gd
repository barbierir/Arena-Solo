extends RefCounted
class_name DamageSystem

func calculate_base_damage(attacker: CombatantRuntimeState, defender: CombatantRuntimeState, skill: Dictionary, controls: Dictionary, status_defs: Dictionary) -> int:
	var raw := attacker.effective_atk(status_defs) + int(skill.get("flat_damage", 0)) - defender.effective_def(status_defs)
	return maxi(int(controls.get("min_damage", 1)), raw)

func resolve_damage(base_damage: int, crit_chance: float, crit_multiplier: float, rng: SeededRngService) -> Dictionary:
	var is_crit := rng.randf() <= crit_chance
	var damage := base_damage
	if is_crit:
		damage = int(round(base_damage * crit_multiplier))
	return {"damage": damage, "is_crit": is_crit}
