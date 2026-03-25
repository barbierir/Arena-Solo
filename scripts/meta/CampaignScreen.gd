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
@onready var _game_over_label: Label = %GameOverLabel
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

var _combat_adapter: CampaignCombatAdapter
var _is_fight_flow_active: bool = false
var _campaign_controls_enabled: bool = true
var _roster_ids_by_index: Array[String] = []

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
	if not GameManager.load_game():
		GameManager.new_game()
	_refresh_all()

func _on_new_game_pressed() -> void:
	GameManager.new_game()
	GameManager.add_recent_event("Nuova partita avviata.")
	_refresh_recent_events()

func _on_recruit_ret_pressed() -> void:
	var result: Dictionary = GameManager.recruit_gladiator("RET")
	if result.has("error"):
		GameManager.add_recent_event("Recruit RET fallito: %s" % str(result.get("error", "")))
		_refresh_recent_events()
		return

func _on_recruit_sec_pressed() -> void:
	var result: Dictionary = GameManager.recruit_gladiator("SEC")
	if result.has("error"):
		GameManager.add_recent_event("Recruit SEC fallito: %s" % str(result.get("error", "")))
		_refresh_recent_events()
		return

func _on_advance_day_pressed() -> void:
	GameManager.advance_day()
	GameManager.add_recent_event("Giorno avanzato.")
	_refresh_recent_events()

func _on_start_fight_pressed() -> void:
	if _is_fight_flow_active:
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

func _on_recent_events_updated(_events: Array[String]) -> void:
	_refresh_recent_events()

func _on_daily_event_updated(_event_data: Dictionary) -> void:
	_refresh_today_event()
	_refresh_start_fight_button_state()

func _on_fight_started(payload: Dictionary) -> void:
	_set_campaign_controls_enabled(false)
	_is_fight_flow_active = true
	var fighter_a: Dictionary = payload.get("fighter_a", {})
	var fighter_b: Dictionary = payload.get("fighter_b", {})
	GameManager.add_recent_event("Incontro avviato: %s vs %s" % [
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
	_refresh_game_over_state()
	_refresh_today_event()
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
	var is_game_over: bool = GameManager.is_game_over()
	var can_fight_now: bool = enabled and GameManager.can_start_fight() and not is_game_over
	_new_game_button.disabled = not enabled
	_recruit_ret_button.disabled = not enabled
	_recruit_sec_button.disabled = not enabled
	_advance_day_button.disabled = not enabled
	_start_fight_button.disabled = not can_fight_now
	_save_button.disabled = not enabled
	_load_button.disabled = not enabled
	_roster_list.select_mode = ItemList.SELECT_SINGLE
	_roster_list.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	_refresh_game_over_state()
	_refresh_start_fight_button_state()

func _refresh_start_fight_button_state() -> void:
	var event_data: Dictionary = GameManager.get_current_event()
	var is_rest_day: bool = str(event_data.get("type", "FIGHT")) == GameManager.EVENT_TYPE_REST
	var is_game_over: bool = GameManager.is_game_over()
	var can_fight_now: bool = _campaign_controls_enabled and GameManager.can_start_fight() and not is_game_over and not _is_fight_flow_active
	_start_fight_button.disabled = not can_fight_now
	_start_fight_button.text = "No Fights Today" if is_rest_day else "Enter Arena"

func _refresh_today_event() -> void:
	var event_data: Dictionary = GameManager.get_current_event()
	var event_name: String = str(event_data.get("name", "Arena Bout"))
	var event_type: String = str(event_data.get("type", "FIGHT"))
	var event_description: String = str(event_data.get("description", "No event details available."))
	var reward_multiplier: float = float(event_data.get("reward_multiplier", 1.0))
	var reward_bonus_percent: int = int(round((reward_multiplier - 1.0) * 100.0))
	var risk_text: String = "Standard risk of death"
	if event_type == GameManager.EVENT_TYPE_HARD_FIGHT:
		risk_text = "High risk of death"
	elif event_type == GameManager.EVENT_TYPE_REST:
		risk_text = "No arena death risk today"
	_today_event_name_value.text = event_name
	_today_event_type_value.text = event_type
	_today_event_description_value.text = event_description
	_today_event_reward_value.text = "%+d%% rewards" % reward_bonus_percent
	_today_event_risk_value.text = risk_text

func _refresh_selected_fighter() -> void:
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

func _refresh_game_over_state() -> void:
	if GameManager.is_game_over():
		_game_over_label.visible = true
		_game_over_label.text = "GAME OVER: Nessun gladiatore vivo nel roster."
		return
	_game_over_label.visible = false
