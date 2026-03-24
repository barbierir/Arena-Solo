extends RefCounted
class_name DamageSystem

func calculate_base_damage(attacker: CombatantRuntimeState, defender: CombatantRuntimeState, skill: Dictionary, controls: Dictionary, status_defs: Dictionary) -> int:
	var defense_effectiveness: float = float(controls.get("defense_effectiveness", 1.0))
	var scaled_defense: int = int(round(float(defender.effective_def(status_defs)) * defense_effectiveness))
	var raw: int = attacker.effective_atk(status_defs) + int(skill.get("flat_damage", 0)) - scaled_defense
	return maxi(int(controls.get("min_damage", 1)), raw)

func resolve_damage(base_damage: int, crit_chance: float, crit_multiplier: float, rng: SeededRngService) -> Dictionary:
	var is_crit: bool = rng.randf() <= crit_chance
	var damage: int = base_damage
	if is_crit:
		damage = int(round(base_damage * crit_multiplier))
	return {"damage": damage, "is_crit": is_crit}
