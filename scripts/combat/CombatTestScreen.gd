extends Node2D
class_name CombatTestScreen

@onready var viewer: CombatViewer = %CombatViewer

func _ready() -> void:
	viewer.render_placeholder()
