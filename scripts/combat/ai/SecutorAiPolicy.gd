extends AiActionSelector
class_name SecutorAiPolicy

var _content_registry: ContentRegistry

func configure(content_registry: ContentRegistry) -> void:
	_content_registry = content_registry

func choose_action(actor: CombatantRuntimeState, target: CombatantRuntimeState, _runtime_state: CombatRuntimeState) -> String:
	if actor.current_sta <= 2:
		return "RECOVER"

	var shield_bash_ready := int(actor.cooldowns.get("SHIELD_BASH", 0)) <= 0 and actor.current_sta >= 2
	if shield_bash_ready and not target.has_status("STUNNED"):
		return "SHIELD_BASH"

	if actor.current_sta >= 2:
		return "BASIC_ATTACK"
	return "RECOVER"
