extends Control
class_name CombatViewer

@onready var attacker_name_label: Label = %AttackerNameLabel
@onready var attacker_hp_label: Label = %AttackerHpLabel
@onready var attacker_sta_label: Label = %AttackerStaLabel
@onready var attacker_status_label: Label = %AttackerStatusLabel

@onready var defender_name_label: Label = %DefenderNameLabel
@onready var defender_hp_label: Label = %DefenderHpLabel
@onready var defender_sta_label: Label = %DefenderStaLabel
@onready var defender_status_label: Label = %DefenderStatusLabel

@onready var combat_log_box: RichTextLabel = %CombatLogLabel
@onready var result_label: Label = %ResultLabel

func render_placeholder() -> void:
	attacker_name_label.text = "RET_STARTER"
	attacker_hp_label.text = "HP: --"
	attacker_sta_label.text = "STA: --"
	attacker_status_label.text = "Statuses: none"

	defender_name_label.text = "SEC_STARTER"
	defender_hp_label.text = "HP: --"
	defender_sta_label.text = "STA: --"
	defender_status_label.text = "Statuses: none"

	combat_log_box.text = "Combat log initialized..."
	result_label.text = "Result: PENDING"
