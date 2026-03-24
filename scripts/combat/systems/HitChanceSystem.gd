extends RefCounted
class_name HitChanceSystem

func calculate(attacker: CombatantRuntimeState, defender: CombatantRuntimeState, skill: Dictionary, controls: Dictionary, status_defs: Dictionary, conditional_hit_bonus: float = 0.0) -> float:
	var hit := float(controls.get("base_hit_chance", 0.7))
	hit += float(attacker.effective_atk(status_defs) - defender.effective_spd(status_defs)) * float(controls.get("hit_delta_per_point", 0.02))
	hit += float(skill.get("accuracy_mod_pct", 0.0)) + conditional_hit_bonus
	if defender.effective_spd(status_defs) - attacker.effective_spd(status_defs) >= 5:
		hit -= float(controls.get("dodge_bonus_if_defender_spd_lead_gte5", 0.15))
	return clampf(hit, float(controls.get("min_hit_chance", 0.1)), float(controls.get("max_hit_chance", 0.95)))

func calculate_crit(attacker: CombatantRuntimeState, skill: Dictionary, controls: Dictionary) -> float:
	var crit := float(controls.get("base_crit_chance", 0.05))
	crit += float(attacker.effective_skl()) * float(controls.get("crit_per_skl", 0.01))
	crit += float(skill.get("crit_bonus_pct", 0.0))
	crit += float(attacker.total_crit_mod_pct)
	return minf(float(controls.get("crit_chance_cap", 0.5)), crit)
