extends Control
class_name CombatViewer

var status_defs: Dictionary = {}

@onready var attacker_name_label: Label = %AttackerNameLabel
@onready var attacker_hp_label: Label = %AttackerHpLabel
@onready var attacker_sta_label: Label = %AttackerStaLabel
@onready var attacker_status_label: Label = %AttackerStatusLabel

@onready var defender_name_label: Label = %DefenderNameLabel
@onready var defender_hp_label: Label = %DefenderHpLabel
@onready var defender_sta_label: Label = %DefenderStaLabel
@onready var defender_status_label: Label = %DefenderStatusLabel

@onready var turn_label: Label = %TurnLabel
@onready var actor_label: Label = %ActorLabel
@onready var combat_log_box: RichTextLabel = %CombatLogLabel
@onready var result_label: Label = %ResultLabel
@onready var seed_input: LineEdit = %SeedInput
@onready var run_fight_button: Button = %RunFightButton
@onready var replay_button: Button = %ReplayButton

func connect_actions(on_run: Callable, on_replay: Callable) -> void:
	run_fight_button.pressed.connect(on_run)
	replay_button.pressed.connect(on_replay)

func seed_value() -> int:
	return int(seed_input.text)

func set_seed_value(value: int) -> void:
	seed_input.text = str(value)

func set_status_definitions(definitions: Dictionary) -> void:
	status_defs = definitions

func render_state(runtime_state: CombatRuntimeState) -> void:
	if runtime_state == null:
		return
	var attacker: CombatantRuntimeState = runtime_state.combatant_states.get(runtime_state.attacker_build_id)
	var defender: CombatantRuntimeState = runtime_state.combatant_states.get(runtime_state.defender_build_id)

	attacker_name_label.text = attacker.display_name
	attacker_hp_label.text = "HP: %d/%d" % [attacker.current_hp, attacker.max_hp]
	attacker_sta_label.text = "STA: %d/%d" % [attacker.current_sta, attacker.max_sta]
	attacker_status_label.text = "Statuses: %s" % attacker.status_labels(status_defs)

	defender_name_label.text = defender.display_name
	defender_hp_label.text = "HP: %d/%d" % [defender.current_hp, defender.max_hp]
	defender_sta_label.text = "STA: %d/%d" % [defender.current_sta, defender.max_sta]
	defender_status_label.text = "Statuses: %s" % defender.status_labels(status_defs)

	turn_label.text = "Turn: %d" % runtime_state.turn_index
	actor_label.text = "Current Actor: %s" % runtime_state.current_actor_id
	result_label.text = "Result: %s" % runtime_state.result_state
	combat_log_box.text = "\n".join(runtime_state.combat_log)
