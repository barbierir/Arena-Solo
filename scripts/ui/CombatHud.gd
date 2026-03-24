extends VBoxContainer
class_name CombatHud

func set_title(title: String) -> void:
	if has_node("Title"):
		$Title.text = title
