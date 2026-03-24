extends AiActionSelector
class_name SecutorAiPolicy

var _content_registry: ContentRegistry

func configure(content_registry: ContentRegistry) -> void:
	_content_registry = content_registry

func choose_action(_actor_build_id: String, _runtime_state: CombatRuntimeState) -> String:
	if _content_registry == null:
		return "BASIC_ATTACK"
	return "SHIELD_BASH"
