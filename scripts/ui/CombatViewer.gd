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
@onready var attacker_selector: OptionButton = %AttackerSelector
@onready var defender_selector: OptionButton = %DefenderSelector
@onready var step_turn_button: Button = %StepTurnButton
@onready var run_fight_button: Button = %RunFightButton
@onready var replay_button: Button = %ReplayButton

func connect_actions(on_run: Callable, on_step_turn: Callable, on_replay: Callable) -> void:
	run_fight_button.pressed.connect(on_run)
	step_turn_button.pressed.connect(on_step_turn)
	replay_button.pressed.connect(on_replay)

func seed_value() -> int:
	return int(seed_input.text)

func set_seed_value(value: int) -> void:
	seed_input.text = str(value)

func set_status_definitions(definitions: Dictionary) -> void:
	status_defs = definitions

func set_fighter_options(build_entries: Dictionary, default_attacker_id: String, default_defender_id: String) -> void:
	attacker_selector.clear()
	defender_selector.clear()
	var build_ids: Array[String] = []
	for build_id_variant in build_entries.keys():
		build_ids.append(str(build_id_variant))
	build_ids.sort()
	for build_id in build_ids:
		var entry: Dictionary = build_entries.get(build_id, {})
		var label: String = "%s (%s)" % [str(entry.get("display_name", build_id)), build_id]
		attacker_selector.add_item(label)
		attacker_selector.set_item_metadata(attacker_selector.item_count - 1, build_id)
		defender_selector.add_item(label)
		defender_selector.set_item_metadata(defender_selector.item_count - 1, build_id)
	_set_selector_to_build(attacker_selector, default_attacker_id)
	_set_selector_to_build(defender_selector, default_defender_id)

func selected_attacker_build_id() -> String:
	return _selected_build_id(attacker_selector)

func selected_defender_build_id() -> String:
	return _selected_build_id(defender_selector)

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
	step_turn_button.disabled = runtime_state.result_state != "PENDING"

func _selected_build_id(selector: OptionButton) -> String:
	var selected_index: int = selector.selected
	if selected_index < 0:
		return ""
	return str(selector.get_item_metadata(selected_index))

func _set_selector_to_build(selector: OptionButton, build_id: String) -> void:
	for idx in range(selector.item_count):
		var option_build_id: String = str(selector.get_item_metadata(idx))
		if option_build_id == build_id:
			selector.select(idx)
			return
