extends Control
class_name CampaignCombatViewer

signal playback_finished(result: Dictionary)

const FALLBACK_PLAYBACK_INTERVAL_SEC: float = 0.35

@onready var _header_label: Label = %HeaderLabel
@onready var _turn_label: Label = %TurnLabel
@onready var _fighter_a_name: Label = %FighterAName
@onready var _fighter_a_class: Label = %FighterAClass
@onready var _fighter_a_hp: Label = %FighterAHp
@onready var _fighter_b_name: Label = %FighterBName
@onready var _fighter_b_class: Label = %FighterBClass
@onready var _fighter_b_hp: Label = %FighterBHp
@onready var _log_label: RichTextLabel = %CombatLog
@onready var _result_panel: PanelContainer = %ResultPanel
@onready var _result_text: RichTextLabel = %ResultText
@onready var _next_button: Button = %NextButton
@onready var _play_all_button: Button = %PlayAllButton
@onready var _close_button: Button = %CloseButton
@onready var _playback_timer: Timer = %PlaybackTimer

var _fight_payload: Dictionary = {}
var _fight_result: Dictionary = {}
var _timeline: Array[Dictionary] = []
var _timeline_index: int = 0
var _is_complete: bool = false
var _finalized_once: bool = false

func _ready() -> void:
	visible = false
	_result_panel.visible = false
	_close_button.disabled = true
	_playback_timer.wait_time = FALLBACK_PLAYBACK_INTERVAL_SEC
	_playback_timer.timeout.connect(_on_playback_tick)

func show_fight(payload: Dictionary, result: Dictionary) -> void:
	_reset_viewer()
	_fight_payload = payload.duplicate(true)
	_fight_result = result.duplicate(true)
	visible = true
	_prepare_fighters(payload)
	_build_timeline(result)
	call_deferred("_focus_primary_action")
	if _timeline.is_empty():
		_log_label.append_text("Nessun evento disponibile.\n")
		_finalize_playback()

func is_complete() -> bool:
	return _is_complete

func _on_next_button_pressed() -> void:
	_step_once()

func _on_play_all_button_pressed() -> void:
	if _is_complete:
		return
	if _timeline.is_empty():
		_finalize_playback()
		return
	_play_all_button.disabled = true
	_next_button.disabled = true
	if _playback_timer.is_stopped():
		_playback_timer.start()

func _on_playback_tick() -> void:
	if _is_complete:
		_playback_timer.stop()
		return
	var progressed: bool = _step_once()
	if not progressed:
		_playback_timer.stop()

func _on_close_button_pressed() -> void:
	if not _is_complete:
		return
	visible = false
	if not _finalized_once:
		return
	playback_finished.emit(_fight_result.duplicate(true))

func _step_once() -> bool:
	if _is_complete:
		return false
	if _timeline_index >= _timeline.size():
		_finalize_playback()
		return false
	var entry: Dictionary = _timeline[_timeline_index]
	_timeline_index += 1
	_apply_timeline_entry(entry)
	if _timeline_index >= _timeline.size():
		_finalize_playback()
	return true

func _reset_viewer() -> void:
	_playback_timer.stop()
	_timeline.clear()
	_timeline_index = 0
	_is_complete = false
	_finalized_once = false
	_header_label.text = "Arena Fight"
	_turn_label.text = "Turno: -"
	_log_label.clear()
	_result_panel.visible = false
	_result_text.clear()
	_next_button.disabled = false
	_play_all_button.disabled = false
	_close_button.disabled = true

func _focus_primary_action() -> void:
	_ensure_button_focusable(_play_all_button)
	_ensure_button_focusable(_next_button)
	_ensure_button_focusable(_close_button)
	if _play_all_button.visible and not _play_all_button.disabled:
		_play_all_button.grab_focus()
		return
	if _next_button.visible and not _next_button.disabled:
		_next_button.grab_focus()
		return
	if _close_button.visible and not _close_button.disabled:
		_close_button.grab_focus()

func _ensure_button_focusable(button: Button) -> void:
	if button.focus_mode == Control.FOCUS_NONE:
		button.focus_mode = Control.FOCUS_ALL

func _prepare_fighters(payload: Dictionary) -> void:
	var fighter_a: Dictionary = payload.get("fighter_a", {})
	var fighter_b: Dictionary = payload.get("fighter_b", {})
	var encounter_label: String = str(payload.get("encounter_label", "Arena Fight"))
	var match_index: int = int(payload.get("tournament_match_index", 0))
	var total_matches: int = int(payload.get("tournament_total_matches", 0))
	_set_fighter_labels(fighter_a, _fighter_a_name, _fighter_a_class, _fighter_a_hp)
	_set_fighter_labels(fighter_b, _fighter_b_name, _fighter_b_class, _fighter_b_hp)
	if match_index > 0 and total_matches > 0:
		encounter_label = "Match %d/%d" % [match_index, total_matches]
		if match_index >= total_matches:
			encounter_label = "Final Match"
	_header_label.text = "%s - %s vs %s" % [
		encounter_label,
		str(fighter_a.get("nome", "Fighter A")),
		str(fighter_b.get("nome", "Fighter B")),
	]

func _set_fighter_labels(fighter: Dictionary, name_label: Label, class_label: Label, hp_label: Label) -> void:
	name_label.text = str(fighter.get("nome", "Sconosciuto"))
	var class_name: String = str(fighter.get("class", "?"))
	if bool(fighter.get("is_beast", false)):
		class_name = "BEAST (%s)" % str(fighter.get("subtype", ""))
	class_label.text = "Classe: %s" % class_name
	var max_hp: int = int(fighter.get("max_hp", fighter.get("hp", 0)))
	hp_label.text = "HP: %d/%d" % [max_hp, max_hp]

func _build_timeline(result: Dictionary) -> void:
	var log_entries: Array = result.get("combat_log", [])
	for entry_variant in log_entries:
		_timeline.append({
			"type": "LOG",
			"text": str(entry_variant),
		})
	var events: Array = result.get("combat_events", [])
	for event_variant in events:
		if typeof(event_variant) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_variant
		if str(event.get("type", "")) != "TURN_TELEMETRY":
			continue
		if str(event.get("phase", "")) != "END_OF_TURN":
			continue
		_timeline.append({
			"type": "TELEMETRY",
			"turn": int(event.get("turn_index", 0)),
			"actor_side_id": str(event.get("actor_side_id", "")),
			"actor_hp": int(event.get("actor_hp_after", -1)),
			"target_side_id": str(event.get("target_side_id", "")),
			"target_hp": int(event.get("target_hp_after", -1)),
		})

func _apply_timeline_entry(entry: Dictionary) -> void:
	var entry_type: String = str(entry.get("type", "LOG"))
	if entry_type == "LOG":
		var text: String = str(entry.get("text", ""))
		_log_label.append_text("%s\n" % text)
		if text.begins_with("-- Turn"):
			_turn_label.text = text.replace("-- ", "").replace(" --", "")
		return
	if entry_type == "TELEMETRY":
		_turn_label.text = "Turno: %d" % int(entry.get("turn", 0))
		_apply_hp_snapshot(str(entry.get("actor_side_id", "")), int(entry.get("actor_hp", -1)))
		_apply_hp_snapshot(str(entry.get("target_side_id", "")), int(entry.get("target_hp", -1)))

func _apply_hp_snapshot(side_id: String, hp_value: int) -> void:
	if hp_value < 0:
		return
	if side_id == "A":
		var max_hp_a: int = _extract_max_hp(_fighter_a_hp.text)
		_fighter_a_hp.text = "HP: %d/%d" % [hp_value, max_hp_a]
		return
	if side_id == "B":
		var max_hp_b: int = _extract_max_hp(_fighter_b_hp.text)
		_fighter_b_hp.text = "HP: %d/%d" % [hp_value, max_hp_b]

func _extract_max_hp(label_text: String) -> int:
	var parts: PackedStringArray = label_text.split("/")
	if parts.size() < 2:
		return 1
	return maxi(1, int(parts[1]))

func _finalize_playback() -> void:
	if _is_complete:
		return
	_is_complete = true
	_finalized_once = true
	_playback_timer.stop()
	_next_button.disabled = true
	_play_all_button.disabled = true
	_close_button.disabled = false
	_result_panel.visible = true
	_result_text.text = _build_result_text(_fight_result)

func _build_result_text(result: Dictionary) -> String:
	if result.has("error"):
		return "[b]Errore combattimento[/b]\n%s" % str(result.get("error", "Errore sconosciuto"))
	var winner_id: String = str(result.get("winner_id", ""))
	var loser_id: String = str(result.get("loser_id", ""))
	var winner_name: String = _fighter_name_from_id(winner_id)
	var loser_name: String = _fighter_name_from_id(loser_id)
	var lines: Array[String] = []
	lines.append("[b]Risultato Finale[/b]")
	lines.append("Vincitore: %s" % winner_name)
	lines.append("Sconfitto: %s" % loser_name)
	lines.append("Turni totali: %d" % int(result.get("turns", 0)))
	lines.append("HP residui vincitore: %d" % int(result.get("winner_remaining_hp", 0)))
	lines.append("Esito combattimento: KO (morte decisa nel post-fight)")
	var player_outcome: String = str(result.get("player_outcome", ""))
	if player_outcome != "":
		lines.append("Outcome: %s" % player_outcome)
	var reward: Dictionary = result.get("reward_summary", {})
	if not reward.is_empty():
		lines.append("Reward: +%d Gold, +%d Fame" % [
			int(reward.get("gold", 0)),
			int(reward.get("fame", 0)),
		])
		var progression: Dictionary = reward.get("progression", {})
		_append_progression_line(lines, progression, winner_id, winner_name)
		_append_progression_line(lines, progression, loser_id, loser_name)
	return "\n".join(lines)

func _append_progression_line(lines: Array[String], progression: Dictionary, gladiator_id: String, fallback_name: String) -> void:
	if gladiator_id == "":
		return
	if not progression.has(gladiator_id):
		return
	var info: Dictionary = progression.get(gladiator_id, {})
	var gained_xp: int = int(info.get("xp_gained", 0))
	var text: String = "%s: +%d XP" % [fallback_name, gained_xp]
	var events_variant: Variant = info.get("events", [])
	if typeof(events_variant) == TYPE_ARRAY:
		var events: Array = events_variant as Array
		for event_variant in events:
			if typeof(event_variant) != TYPE_DICTIONARY:
				continue
			var event: Dictionary = event_variant
			if str(event.get("type", "")) == "LEVEL_UP":
				text += " | Level Up -> %d" % int(event.get("new_level", 0))
				break
	lines.append(text)

func _fighter_name_from_id(gladiator_id: String) -> String:
	if gladiator_id == "":
		return "N/A"
	var fighter_a: Dictionary = _fight_payload.get("fighter_a", {})
	if str(fighter_a.get("id", "")) == gladiator_id:
		return str(fighter_a.get("nome", gladiator_id))
	var fighter_b: Dictionary = _fight_payload.get("fighter_b", {})
	if str(fighter_b.get("id", "")) == gladiator_id:
		return str(fighter_b.get("nome", gladiator_id))
	return gladiator_id
