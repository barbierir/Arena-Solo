extends Control
class_name CampaignScreen

const COMBAT_ADAPTER_SCRIPT: GDScript = preload("res://scripts/combat/bridge/CampaignCombatAdapter.gd")

@onready var _gold_value: Label = %GoldValue
@onready var _fame_value: Label = %FameValue
@onready var _day_value: Label = %DayValue
@onready var _state_value: Label = %StateValue
@onready var _today_event_name_value: Label = %TodayEventNameValue
@onready var _today_event_type_value: Label = %TodayEventTypeValue
@onready var _today_event_description_value: Label = %TodayEventDescriptionValue
@onready var _today_event_reward_value: Label = %TodayEventRewardValue
@onready var _today_event_risk_value: Label = %TodayEventRiskValue
@onready var _roster_list: ItemList = %RosterList
@onready var _selected_fighter_value: Label = %SelectedFighterValue
@onready var _event_log: RichTextLabel = %EventLog
@onready var _start_fight_button: Button = %StartFightButton
@onready var _new_game_button: Button = %NewGameButton
@onready var _recruit_ret_button: Button = %RecruitRetButton
@onready var _recruit_sec_button: Button = %RecruitSecButton
@onready var _advance_day_button: Button = %AdvanceDayButton
@onready var _save_button: Button = %SaveButton
@onready var _load_button: Button = %LoadButton
@onready var _last_fight_result: RichTextLabel = %LastFightResult
@onready var _combat_viewer: CampaignCombatViewer = %CampaignCombatViewer
@onready var _end_game_overlay: Control = %EndGameOverlay
@onready var _end_game_title: Label = %EndGameTitle
@onready var _end_game_stats: Label = %EndGameStats
@onready var _narrative_overlay: Control = %NarrativeEventOverlay
@onready var _narrative_title: Label = %NarrativeTitle
@onready var _narrative_description: Label = %NarrativeDescription
@onready var _narrative_choice_a_button: Button = %NarrativeChoiceAButton
@onready var _narrative_choice_b_button: Button = %NarrativeChoiceBButton
@onready var _narrative_hint: Label = %NarrativeHint

var _combat_adapter: CampaignCombatAdapter
var _is_fight_flow_active: bool = false
var _campaign_controls_enabled: bool = true
var _roster_ids_by_index: Array[String] = []
var _narrative_choice_ids: Array[String] = []

func _ready() -> void:
	_combat_adapter = COMBAT_ADAPTER_SCRIPT.new()
	add_child(_combat_adapter)
	_combat_viewer.playback_finished.connect(_on_fight_playback_finished)
	GameManager.resources_updated.connect(_on_resources_updated)
	GameManager.roster_updated.connect(_on_roster_updated)
	GameManager.game_state_changed.connect(_on_state_changed)
	GameManager.fight_started.connect(_on_fight_started)
	GameManager.fight_resolved.connect(_on_fight_resolved)
	GameManager.recent_events_updated.connect(_on_recent_events_updated)
	GameManager.daily_event_updated.connect(_on_daily_event_updated)
	GameManager.narrative_event_updated.connect(_on_narrative_event_updated)
	if not GameManager.load_game():
		GameManager.new_game()
	_refresh_all()

func _on_new_game_pressed() -> void:
	GameManager.new_game()
	GameManager.add_recent_event("Nuova partita avviata.")
	_refresh_recent_events()

func _on_recruit_ret_pressed() -> void:
	if not _can_use_campaign_actions():
		return
	var result: Dictionary = GameManager.recruit_gladiator("RET")
	if result.has("error"):
		GameManager.add_recent_event("Recruit RET fallito: %s" % str(result.get("error", "")))
		_refresh_recent_events()
		return

func _on_recruit_sec_pressed() -> void:
	if not _can_use_campaign_actions():
		return
	var result: Dictionary = GameManager.recruit_gladiator("SEC")
	if result.has("error"):
		GameManager.add_recent_event("Recruit SEC fallito: %s" % str(result.get("error", "")))
		_refresh_recent_events()
		return

func _on_advance_day_pressed() -> void:
	if not GameManager.can_advance_day():
		return
	GameManager.advance_day()
	GameManager.add_recent_event("Giorno avanzato.")
	_refresh_recent_events()

func _on_start_fight_pressed() -> void:
	if _is_fight_flow_active:
		return
	if not _can_use_campaign_actions():
		return
	var payload: Dictionary = GameManager.start_next_fight()
	if payload.has("error"):
		GameManager.add_recent_event("Impossibile avviare incontro: %s" % str(payload.get("error", "")))
		_refresh_recent_events()

func _on_roster_list_item_selected(index: int) -> void:
	if not _campaign_controls_enabled:
		return
	if index < 0 or index >= _roster_ids_by_index.size():
		return
	var gladiator_id: String = _roster_ids_by_index[index]
	var locked_tournament_gladiator_id: String = GameManager.get_locked_tournament_gladiator_id()
	if locked_tournament_gladiator_id != "" and gladiator_id != locked_tournament_gladiator_id:
		GameManager.add_recent_event("Tournament lock active: continue with the locked gladiator.")
		_refresh_recent_events()
		_refresh_selected_fighter()
		return
	if not GameManager.set_selected_gladiator(gladiator_id):
		GameManager.add_recent_event("Selezione non valida: %s." % gladiator_id)
		_refresh_recent_events()
		return
	_refresh_selected_fighter()

func _on_save_pressed() -> void:
	var saved: bool = GameManager.save_game()
	GameManager.add_recent_event("Salvataggio %s." % ("ok" if saved else "fallito"))
	_refresh_recent_events()

func _on_load_pressed() -> void:
	if GameManager.load_game():
		GameManager.add_recent_event("Caricamento completato.")
		_refresh_recent_events()
	else:
		GameManager.new_game()
		GameManager.add_recent_event("Nessun save valido. Creata una nuova partita.")
		_refresh_recent_events()

func _on_resources_updated(gold: int, fame: int, day: int) -> void:
	_gold_value.text = str(gold)
	_fame_value.text = str(fame)
	_day_value.text = str(day)

func _on_roster_updated() -> void:
	_render_roster()
	_refresh_selected_fighter()
	if not _is_fight_flow_active:
		_refresh_start_fight_button_state()

func _on_state_changed(new_state: String) -> void:
	_state_value.text = new_state
	_refresh_campaign_end_overlay()
	_refresh_campaign_actions_state()
	_refresh_selected_fighter()
	if not _is_fight_flow_active:
		_refresh_start_fight_button_state()

func _on_recent_events_updated(_events: Array[String]) -> void:
	_refresh_recent_events()

func _on_daily_event_updated(_event_data: Dictionary) -> void:
	_refresh_today_event()
	_refresh_start_fight_button_state()

func _on_narrative_event_updated(_event_data: Dictionary) -> void:
	_refresh_narrative_overlay()
	_refresh_campaign_actions_state()

func _on_fight_started(payload: Dictionary) -> void:
	_set_campaign_controls_enabled(false)
	_is_fight_flow_active = true
	var fighter_a: Dictionary = payload.get("fighter_a", {})
	var fighter_b: Dictionary = payload.get("fighter_b", {})
	var encounter_label: String = str(payload.get("encounter_label", "Arena Fight"))
	GameManager.add_recent_event("%s: %s vs %s" % [
		encounter_label,
		str(fighter_a.get("nome", "A")),
		str(fighter_b.get("nome", "B")),
	])
	_refresh_recent_events()
	var result: Dictionary = _combat_adapter.run_payload(payload)
	if result.has("error"):
		GameManager.add_recent_event("Errore adapter combat: %s" % str(result.get("error", "")))
		_refresh_recent_events()
		GameManager.abort_active_fight("adapter_error")
		_is_fight_flow_active = false
		_set_campaign_controls_enabled(true)
		return
	_combat_viewer.show_fight(payload, result)

func _on_fight_playback_finished(result: Dictionary) -> void:
	if not _is_fight_flow_active:
		return
	if result.has("error"):
		GameManager.add_recent_event("Combattimento non risolto: %s" % str(result.get("error", "Errore sconosciuto")))
		_refresh_recent_events()
		GameManager.abort_active_fight("viewer_error")
		_is_fight_flow_active = false
		_set_campaign_controls_enabled(true)
		return
	GameManager.resolve_fight(result)

func _on_fight_resolved(result: Dictionary) -> void:
	_is_fight_flow_active = false
	_set_campaign_controls_enabled(true)
	var winner_id: String = str(result.get("winner_id", ""))
	var loser_id: String = str(result.get("loser_id", ""))
	var player_outcome: String = str(result.get("player_outcome", "UNKNOWN"))
	var outcome_label: String = _build_outcome_label(player_outcome)
	_last_fight_result.text = "Outcome: %s | Vincitore: %s | Sconfitto: %s | Turni: %d | HP Vincitore: %d | Morte: %s" % [
		outcome_label,
		winner_id if winner_id != "" else "N/A",
		loser_id if loser_id != "" else "N/A",
		int(result.get("turns", 0)),
		int(result.get("winner_remaining_hp", 0)),
		"SI" if bool(result.get("loser_dead", false)) else "NO",
	]
	_refresh_all()

func _build_outcome_label(player_outcome: String) -> String:
	if player_outcome == "VICTORY":
		return "Victory"
	if player_outcome == "DEFEAT_SURVIVED":
		return "Defeat - Survived"
	if player_outcome == "DEFEAT_KILLED":
		return "Defeat - Killed"
	return "Unknown"

func _refresh_all() -> void:
	_on_resources_updated(GameManager.gold, GameManager.fame, GameManager.day)
	_on_state_changed(GameManager.game_state)
	_render_roster()
	_refresh_selected_fighter()
	_refresh_recent_events()
	_refresh_campaign_end_overlay()
	_refresh_today_event()
	_refresh_narrative_overlay()
	_refresh_campaign_actions_state()
	if not _is_fight_flow_active:
		_refresh_start_fight_button_state()

func _render_roster() -> void:
	_roster_list.clear()
	_roster_ids_by_index.clear()
	var roster: Array[Dictionary] = GameManager.get_roster()
	for gladiator: Dictionary in roster:
		var status: String = GameManager.get_gladiator_status(gladiator)
		var level: int = int(gladiator.get("level", gladiator.get("livello", 1)))
		var experience: int = int(gladiator.get("experience", gladiator.get("esperienza", 0)))
		var exp_required: int = GameManager.required_exp_for_level(level)
		var exp_segment: String = "MAX" if exp_required <= 0 else "%d/%d" % [experience, exp_required]
		var injury_label: String = ""
		if status == GameManager.STATUS_INJURED:
			injury_label = " (%dg)" % int(gladiator.get("injured_days", 0))
		var row: String = "%s | %s | Lv %d XP %s | HP:%d ATK:%d DEF:%d | %s%s | W:%d L:%d" % [
			GameManager.get_gladiator_display_name(gladiator),
			str(gladiator.get("class", "")),
			level,
			exp_segment,
			int(gladiator.get("max_hp", 1)),
			int(gladiator.get("atk", 1)),
			int(gladiator.get("def", 1)),
			status,
			injury_label,
			int(gladiator.get("wins", 0)),
			int(gladiator.get("losses", 0)),
		]
		_roster_list.add_item(row)
		_roster_ids_by_index.append(str(gladiator.get("id", "")))
	var selected_id: String = GameManager.get_selected_gladiator_id()
	if selected_id == "":
		return
	var selected_index: int = _roster_ids_by_index.find(selected_id)
	if selected_index >= 0:
		_roster_list.select(selected_index)

func _refresh_recent_events() -> void:
	_event_log.clear()
	var events: Array[String] = GameManager.get_recent_events()
	for event_text: String in events:
		_event_log.append_text("%s\n" % event_text)

func _set_campaign_controls_enabled(enabled: bool) -> void:
	_campaign_controls_enabled = enabled
	_refresh_campaign_actions_state()
	_refresh_campaign_end_overlay()
	_refresh_start_fight_button_state()

func _refresh_campaign_actions_state() -> void:
	var campaign_running: bool = GameManager.is_campaign_running()
	var narrative_blocked: bool = GameManager.has_active_narrative_event()
	var controls_enabled: bool = _campaign_controls_enabled and campaign_running and not narrative_blocked
	var can_fight_now: bool = controls_enabled and GameManager.can_start_fight()
	var can_advance_day_now: bool = _campaign_controls_enabled and GameManager.can_advance_day()
	_new_game_button.disabled = not _campaign_controls_enabled
	_recruit_ret_button.disabled = not controls_enabled
	_recruit_sec_button.disabled = not controls_enabled
	_advance_day_button.disabled = not can_advance_day_now
	_advance_day_button.tooltip_text = _build_advance_day_block_reason() if not can_advance_day_now else "Passa al giorno successivo."
	_start_fight_button.disabled = not can_fight_now
	_save_button.disabled = not controls_enabled
	_load_button.disabled = not controls_enabled
	_roster_list.select_mode = ItemList.SELECT_SINGLE
	var roster_select_enabled: bool = controls_enabled and not GameManager.is_tournament_fighter_locked()
	_roster_list.mouse_filter = Control.MOUSE_FILTER_STOP if roster_select_enabled else Control.MOUSE_FILTER_IGNORE

func _refresh_start_fight_button_state() -> void:
	var event_data: Dictionary = GameManager.get_current_event()
	var is_rest_day: bool = str(event_data.get("type", "FIGHT")) == GameManager.EVENT_TYPE_REST
	var has_tournament: bool = GameManager.has_active_tournament()
	if has_tournament and not GameManager.can_continue_active_tournament():
		GameManager.invalidate_active_tournament("no_gladiator_can_continue")
		has_tournament = false
	var can_continue_tournament: bool = has_tournament and GameManager.can_continue_active_tournament()
	if has_tournament:
		has_tournament = can_continue_tournament
	if has_tournament:
		is_rest_day = false
	var can_fight_now: bool = _campaign_controls_enabled and GameManager.is_campaign_running() and not GameManager.has_active_narrative_event() and GameManager.can_start_fight() and not _is_fight_flow_active
	_start_fight_button.disabled = not can_fight_now
	if has_tournament:
		_start_fight_button.text = "Continue Tournament"
	else:
		_start_fight_button.text = "No Fights Today" if is_rest_day else "Enter Arena"

func _refresh_narrative_overlay() -> void:
	var event_data: Dictionary = GameManager.get_current_narrative_event()
	_narrative_choice_ids.clear()
	if event_data.is_empty():
		_narrative_overlay.visible = false
		return
	_narrative_overlay.visible = true
	_narrative_title.text = str(event_data.get("title", "Narrative Event"))
	_narrative_description.text = str(event_data.get("description", ""))
	_narrative_hint.text = "Resolve this event to continue the campaign."
	var choices: Variant = event_data.get("choices", [])
	var first_choice: Dictionary = {}
	var second_choice: Dictionary = {}
	if typeof(choices) == TYPE_ARRAY:
		var choice_array: Array = choices as Array
		if choice_array.size() > 0 and typeof(choice_array[0]) == TYPE_DICTIONARY:
			first_choice = choice_array[0] as Dictionary
		if choice_array.size() > 1 and typeof(choice_array[1]) == TYPE_DICTIONARY:
			second_choice = choice_array[1] as Dictionary
	_configure_narrative_choice_button(_narrative_choice_a_button, first_choice)
	_configure_narrative_choice_button(_narrative_choice_b_button, second_choice)

func _configure_narrative_choice_button(button: Button, choice_data: Dictionary) -> void:
	if choice_data.is_empty():
		button.visible = false
		button.disabled = true
		return
	button.visible = true
	var choice_id: String = str(choice_data.get("id", "")).strip_edges()
	button.text = str(choice_data.get("text", "Choice"))
	button.disabled = not GameManager.can_resolve_narrative_choice(choice_id)
	_narrative_choice_ids.append(choice_id)

func _on_narrative_choice_a_pressed() -> void:
	_resolve_narrative_choice_at(0)

func _on_narrative_choice_b_pressed() -> void:
	_resolve_narrative_choice_at(1)

func _resolve_narrative_choice_at(index: int) -> void:
	if index < 0 or index >= _narrative_choice_ids.size():
		return
	var choice_id: String = _narrative_choice_ids[index]
	GameManager.resolve_narrative_event(choice_id)

func _can_use_campaign_actions() -> bool:
	return GameManager.is_campaign_running() and not GameManager.has_active_narrative_event()

func _build_advance_day_block_reason() -> String:
	if not _campaign_controls_enabled:
		return "Attendi la fine del fight in corso."
	if not GameManager.is_campaign_running():
		return "La campagna non è in stato RUNNING."
	if GameManager.has_active_narrative_event():
		return "Risolvi prima l'evento narrativo attivo."
	if GameManager.has_active_tournament():
		if GameManager.can_continue_active_tournament():
			return "Concludi prima il torneo attivo."
		return "Il torneo non e' continuabile e verra' chiuso automaticamente."
	return "Advance Day non disponibile in questo momento."

func _refresh_today_event() -> void:
	var event_data: Dictionary = GameManager.get_current_event()
	var event_name: String = str(event_data.get("name", "Arena Bout"))
	var event_type: String = str(event_data.get("type", "FIGHT"))
	var event_description: String = str(event_data.get("description", "No event details available."))
	var reward_multiplier: float = float(event_data.get("reward_multiplier", 1.0))
	var reward_bonus_percent: int = int(round((reward_multiplier - 1.0) * 100.0))
	var risk_text: String = "Standard risk of death"
	var type_label: String = event_type
	if GameManager.has_active_tournament():
		type_label = "Tournament Day"
		event_description = "Tournament in progress. 2 matches required."
		risk_text = "Escalating risk (final match is deadlier)"
	if event_type == GameManager.EVENT_TYPE_HARD_FIGHT:
		risk_text = "High risk of death"
	elif event_type == GameManager.EVENT_TYPE_REST:
		risk_text = "No arena death risk today"
	elif event_type == GameManager.EVENT_TYPE_TOURNAMENT:
		type_label = "Tournament Day"
		event_description = "%s 2 matches required." % event_description
		risk_text = "High sustained risk across two matches"
	elif event_type == GameManager.EVENT_TYPE_BEAST_FIGHT:
		type_label = "Beast Hunt"
		event_description = "%s Dangerous animal encounter." % event_description
		risk_text = "Dangerous animal encounter"
	_today_event_name_value.text = event_name
	_today_event_type_value.text = type_label
	_today_event_description_value.text = event_description
	_today_event_reward_value.text = "%+d%% rewards" % reward_bonus_percent
	_today_event_risk_value.text = risk_text

func _refresh_selected_fighter() -> void:
	var locked_tournament_gladiator_id: String = GameManager.get_locked_tournament_gladiator_id()
	if locked_tournament_gladiator_id != "":
		GameManager.set_selected_gladiator(locked_tournament_gladiator_id)
	var selected: Dictionary = GameManager.get_selected_gladiator()
	if selected.is_empty():
		var available: Array[Dictionary] = GameManager.get_available_gladiators()
		if not available.is_empty():
			var fallback_id: String = str(available[0].get("id", ""))
			GameManager.set_selected_gladiator(fallback_id)
			selected = GameManager.get_selected_gladiator()
	if selected.is_empty():
		_selected_fighter_value.text = "None"
		return
	_selected_fighter_value.text = "%s (%s, Lv %d)" % [
		GameManager.get_gladiator_display_name(selected),
		str(selected.get("class", "")),
		int(selected.get("level", selected.get("livello", 1))),
	]

func _refresh_campaign_end_overlay() -> void:
	var state: String = GameManager.game_state
	var is_final_state: bool = state == GameManager.STATE_VICTORY or state == GameManager.STATE_DEFEAT
	_end_game_overlay.visible = is_final_state
	if not is_final_state:
		return
	if state == GameManager.STATE_VICTORY:
		_end_game_title.text = "You have become a legendary Lanista"
		_end_game_stats.text = "Days: %d\nFame: %d\nSurviving gladiators: %d" % [
			GameManager.day,
			GameManager.fame,
			GameManager.get_surviving_gladiators_count(),
		]
		return
	_end_game_title.text = "Your school has fallen"
	_end_game_stats.text = "Days: %d\nFame: %d" % [GameManager.day, GameManager.fame]
