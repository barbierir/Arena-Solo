extends RefCounted
class_name StaminaSystem

func apply_turn_regen(actor: CombatantRuntimeState, controls: Dictionary, status_defs: Dictionary) -> int:
	var regen_mod := actor.status_mod("sta_regen_mod", status_defs)
	var regen := int(controls.get("base_stamina_regen", 2)) + regen_mod
	actor.current_sta = clampi(actor.current_sta + regen, 0, actor.max_sta)
	return regen

func spend(actor: CombatantRuntimeState, amount: int) -> void:
	actor.current_sta = maxi(0, actor.current_sta - amount)

func recover(actor: CombatantRuntimeState, controls: Dictionary) -> int:
	var gain := int(controls.get("recover_bonus_stamina", 2))
	actor.current_sta = mini(actor.max_sta, actor.current_sta + gain)
	return gain
