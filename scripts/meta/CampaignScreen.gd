extends Control
class_name CampaignScreen

const COMBAT_ADAPTER_SCRIPT: GDScript = preload("res://scripts/combat/bridge/CampaignCombatAdapter.gd")

@onready var _gold_value: Label = %GoldValue
@onready var _fame_value: Label = %FameValue
@onready var _day_value: Label = %DayValue
@onready var _state_value: Label = %StateValue
@onready var _roster_list: ItemList = %RosterList
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

func _ready() -> void:
	_combat_adapter = COMBAT_ADAPTER_SCRIPT.new()
	add_child(_combat_adapter)
	_combat_viewer.playback_finished.connect(_on_fight_playback_finished)
	GameManager.resources_updated.connect(_on_resources_updated)
	GameManager.roster_updated.connect(_on_roster_updated)
	GameManager.game_state_changed.connect(_on_state_changed)
	GameManager.fight_started.connect(_on_fight_started)
	GameManager.fight_resolved.connect(_on_fight_resolved)
	if not GameManager.load_game():
		GameManager.new_game()
	_refresh_all()

func _on_new_game_pressed() -> void:
	GameManager.new_game()
	_append_log("Nuova partita avviata.")

func _on_recruit_ret_pressed() -> void:
	var result: Dictionary = GameManager.recruit_gladiator("RET")
	if result.has("error"):
		_append_log("Recruit RET fallito: %s" % str(result.get("error", "")))
		return
	_append_log("Reclutato %s." % str(result.get("nome", "RET")))

func _on_recruit_sec_pressed() -> void:
	var result: Dictionary = GameManager.recruit_gladiator("SEC")
	if result.has("error"):
		_append_log("Recruit SEC fallito: %s" % str(result.get("error", "")))
		return
	_append_log("Reclutato %s." % str(result.get("nome", "SEC")))

func _on_advance_day_pressed() -> void:
	GameManager.advance_day()
	_append_log("Giorno avanzato.")

func _on_start_fight_pressed() -> void:
	if _is_fight_flow_active:
		return
	var payload: Dictionary = GameManager.start_next_fight()
	if payload.has("error"):
		_append_log("Impossibile avviare incontro: %s" % str(payload.get("error", "")))

func _on_save_pressed() -> void:
	var saved: bool = GameManager.save_game()
	_append_log("Salvataggio %s." % ("ok" if saved else "fallito"))

func _on_load_pressed() -> void:
	if GameManager.load_game():
		_append_log("Caricamento completato.")
	else:
		_append_log("Nessun save valido. Creo una nuova partita.")
		GameManager.new_game()

func _on_resources_updated(gold: int, fame: int, day: int) -> void:
	_gold_value.text = str(gold)
	_fame_value.text = str(fame)
	_day_value.text = str(day)

func _on_roster_updated() -> void:
	_render_roster()
	if not _is_fight_flow_active:
		_start_fight_button.disabled = not GameManager.can_start_fight()

func _on_state_changed(new_state: String) -> void:
	_state_value.text = new_state

func _on_fight_started(payload: Dictionary) -> void:
	_set_campaign_controls_enabled(false)
	_is_fight_flow_active = true
	var fighter_a: Dictionary = payload.get("fighter_a", {})
	var fighter_b: Dictionary = payload.get("fighter_b", {})
	_append_log("Incontro avviato: %s vs %s" % [
		str(fighter_a.get("nome", "A")),
		str(fighter_b.get("nome", "B")),
	])
	var result: Dictionary = _combat_adapter.run_payload(payload)
	if result.has("error"):
		_append_log("Errore adapter combat: %s" % str(result.get("error", "")))
		GameManager.abort_active_fight("adapter_error")
		_is_fight_flow_active = false
		_set_campaign_controls_enabled(true)
		return
	_combat_viewer.show_fight(payload, result)

func _on_fight_playback_finished(result: Dictionary) -> void:
	if not _is_fight_flow_active:
		return
	if result.has("error"):
		_append_log("Combattimento non risolto: %s" % str(result.get("error", "Errore sconosciuto")))
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
	_append_log("Incontro risolto. Vincitore ID: %s, Turni: %d" % [winner_id, int(result.get("turns", 0))])
	_last_fight_result.text = "Vincitore: %s | Sconfitto: %s | Turni: %d | HP Vincitore: %d | Morte: %s" % [
		winner_id if winner_id != "" else "N/A",
		loser_id if loser_id != "" else "N/A",
		int(result.get("turns", 0)),
		int(result.get("winner_remaining_hp", 0)),
		"SI" if bool(result.get("loser_dead", false)) else "NO",
	]
	_refresh_all()

func _refresh_all() -> void:
	_on_resources_updated(GameManager.gold, GameManager.fame, GameManager.day)
	_on_state_changed(GameManager.game_state)
	_render_roster()
	if not _is_fight_flow_active:
		_start_fight_button.disabled = not GameManager.can_start_fight()

func _render_roster() -> void:
	_roster_list.clear()
	var roster: Array[Dictionary] = GameManager.get_roster()
	for gladiator: Dictionary in roster:
		var row: String = "%s | %s | Lv%d EXP:%d | HP:%d ATK:%d DEF:%d | %s | Inj:%d | W:%d L:%d" % [
			str(gladiator.get("nome", "")),
			str(gladiator.get("class", "")),
			int(gladiator.get("livello", 1)),
			int(gladiator.get("esperienza", 0)),
			int(gladiator.get("max_hp", 1)),
			int(gladiator.get("atk", 1)),
			int(gladiator.get("def", 1)),
			"ALIVE" if bool(gladiator.get("alive", false)) else "DEAD",
			int(gladiator.get("injured_days", 0)),
			int(gladiator.get("wins", 0)),
			int(gladiator.get("losses", 0)),
		]
		_roster_list.add_item(row)

func _set_campaign_controls_enabled(enabled: bool) -> void:
	_new_game_button.disabled = not enabled
	_recruit_ret_button.disabled = not enabled
	_recruit_sec_button.disabled = not enabled
	_advance_day_button.disabled = not enabled
	_start_fight_button.disabled = (not enabled) or (not GameManager.can_start_fight())
	_save_button.disabled = not enabled
	_load_button.disabled = not enabled

func _append_log(text: String) -> void:
	_event_log.append_text("%s\n" % text)
