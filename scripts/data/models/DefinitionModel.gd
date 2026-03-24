extends RefCounted
class_name DefinitionModel

var id: String
var display_name: String

func _init(definition_id: String = "", name: String = "") -> void:
	id = definition_id
	display_name = name
