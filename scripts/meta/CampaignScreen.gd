extends Control
class_name CampaignScreen

const COMBAT_ADAPTER_SCRIPT: GDScript = preload("res://scripts/combat/bridge/CampaignCombatAdapter.gd")
const CONTENT_LOADER_SCRIPT: GDScript = preload("res://scripts/data/loaders/ContentLoader.gd")
const COMBAT_BATCH_SIMULATOR_SCRIPT: GDScript = preload("res://scripts/combat/analysis/CombatBatchSimulator.gd")
const BATCH_REPORTS_DIR: String = "user://batch_reports"

@onready var _gold_value: Label = %GoldValue
@onready var _fame_value: Label = %FameValue
@onready var _day_value: Label = %DayValue
@onready var _today_event_title: Label = %TodayEventTitle
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
@onready var _advance_turn_button: Button = %AdvanceDayButton
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
@onready var _batch_toggle_button: Button = %BatchToggleButton
@onready var _batch_panel_body: VBoxContainer = %BatchPanelBody
@onready var _batch_attacker_selector: OptionButton = %BatchAttackerSelector
@onready var _batch_defender_selector: OptionButton = %BatchDefenderSelector
@onready var _batch_seed_input: LineEdit = %BatchSeedInput
@onready var _batch_count_input: LineEdit = %BatchCountInput
@onready var _batch_max_turns_input: LineEdit = %BatchMaxTurnsInput
@onready var _batch_status_label: Label = %BatchStatusLabel
@onready var _batch_saved_path_label: Label = %BatchSavedPathLabel
@onready var _batch_report_dir_label: Label = %BatchReportDirLabel

var _combat_adapter: CampaignCombatAdapter
var _batch_content_loader: ContentLoader
var _batch_content_registry: ContentRegistry
var _batch_simulator: CombatBatchSimulator
var _last_batch_result: Dictionary = {}
var _is_fight_flow_active: bool = false
var _campaign_controls_enabled: bool = true
var _narrative_choice_ids: Array[String] = []
var _narrative_event_resolving: bool = false
var _is_refreshing_roster: bool = false
var _pending_roster_refresh: bool = false
var _suppress_selection_callbacks: bool = false
var _pending_roster_refresh_source: String = ""

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
	_setup_batch_harness()
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
	if not GameManager.can_advance_turn():
		return
	GameManager.advance_turn()
	GameManager.add_recent_event("Advanced Phase.")
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
	if _suppress_selection_callbacks:
		print("[SELECTION] callback_ignored source=programmatic_refresh index=%d suppressed=true" % index)
		return
	if _is_refreshing_roster:
		print("[SELECTION] callback_ignored source=refresh_in_progress index=%d suppressed=false" % index)
		return
	if not _campaign_controls_enabled:
		return
	var gladiator_id: String = _gladiator_id_for_row(index)
	if gladiator_id == "":
		GameManager.add_recent_event("Selection invalid: stale roster row.")
		_refresh_recent_events()
		_request_roster_refresh("user_selection_stale_row")
		return
	var locked_tournament_gladiator_id: String = GameManager.get_locked_tournament_gladiator_id()
	if locked_tournament_gladiator_id != "" and gladiator_id != locked_tournament_gladiator_id:
		GameManager.add_recent_event("Tournament lock active: continue with the locked gladiator.")
		_refresh_recent_events()
		_request_roster_refresh("user_selection_rejected_tournament_lock")
		return
	var eligibility: Dictionary = GameManager.get_gladiator_action_eligibility(
		gladiator_id,
		GameManager.ACTION_CONTEXT_NORMAL_FIGHT,
		locked_tournament_gladiator_id != ""
	)
	if not bool(eligibility.get("eligible", false)):
		var rejected_name: String = str(eligibility.get("gladiator_name", gladiator_id))
		GameManager.add_recent_event("%s %s." % [rejected_name, str(eligibility.get("reason", "is not eligible"))])
		_refresh_recent_events()
		_request_roster_refresh("user_selection_rejected_ineligible")
		return
	if not GameManager.set_selected_gladiator(gladiator_id):
		GameManager.add_recent_event("Selezione non valida: %s." % gladiator_id)
		_refresh_recent_events()
		_request_roster_refresh("user_selection_set_failed")
		return
	print("[SELECTION] user_selected id=%s index=%d source=user_input" % [gladiator_id, index])
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

func _on_batch_toggle_pressed() -> void:
	_batch_panel_body.visible = not _batch_panel_body.visible
	_batch_toggle_button.text = "Hide Batch Simulator" if _batch_panel_body.visible else "Show Batch Simulator"

func _on_run_batch_pressed() -> void:
	if _batch_simulator == null:
		_set_batch_status("Batch simulator unavailable.", false)
		return
	var attacker_build_id: String = _selected_batch_build_id(_batch_attacker_selector)
	var defender_build_id: String = _selected_batch_build_id(_batch_defender_selector)
	if attacker_build_id == "" or defender_build_id == "":
		_set_batch_status("Pick attacker and defender builds.", false)
		return
	var result: Dictionary = _batch_simulator.run_batch(
		attacker_build_id,
		defender_build_id,
		_parse_positive_int(_batch_seed_input.text, 1001, 0),
		_parse_positive_int(_batch_count_input.text, 1000, 1),
		_parse_positive_int(_batch_max_turns_input.text, 128, 1)
	)
	_last_batch_result = result
	var wins: Dictionary = result.get("wins", {})
	var total_runs: int = int(result.get("total_runs", 0))
	_set_batch_status("Batch complete: A wins %d, B wins %d, draws %d (runs %d)." % [
		int(wins.get("attacker", 0)),
		int(wins.get("defender", 0)),
		int(wins.get("draws_or_unresolved", 0)),
		total_runs,
	], true)

func _on_save_batch_report_pressed() -> void:
	if _batch_simulator == null:
		_set_batch_status("Batch simulator unavailable.", false)
		return
	if _last_batch_result.is_empty():
		_set_batch_status("Run a batch before saving.", false)
		return
	var save_outcome: Dictionary = _batch_simulator.save_batch_report(_last_batch_result, _batch_build_entries())
	if not bool(save_outcome.get("ok", false)):
		_set_batch_status("Save failed: %s" % str(save_outcome.get("error", "unknown error")), false)
		return
	var txt_path: String = str(save_outcome.get("txt_path", ""))
	var json_path: String = str(save_outcome.get("json_path", ""))
	_set_batch_status("Batch report saved.", true)
	_batch_saved_path_label.text = "Last Saved: %s | %s" % [txt_path, json_path]

func _on_run_canonical_suite_pressed() -> void:
	if _batch_simulator == null:
		_set_batch_status("Batch simulator unavailable.", false)
		return
	var suite_outcome: Dictionary = _batch_simulator.save_standard_suite_reports(
		_parse_positive_int(_batch_seed_input.text, 6100, 0),
		_parse_positive_int(_batch_count_input.text, 1000, 1),
		_parse_positive_int(_batch_max_turns_input.text, 128, 1),
		_batch_build_entries()
	)
	if not bool(suite_outcome.get("ok", false)):
		_set_batch_status("Suite failed: %s" % str(suite_outcome.get("error", "unknown error")), false)
		return
	_set_batch_status("Canonical suite saved (RET/SEC mirror + cross matchups).", true)
	_batch_saved_path_label.text = "Suite Summary: %s" % str(suite_outcome.get("summary_path", ""))

func _on_resources_updated(gold: int, fame: int, day: int) -> void:
	_gold_value.text = str(gold)
	_fame_value.text = str(fame)
	_day_value.text = GameManager.format_phase_progress(day)

func _setup_batch_harness() -> void:
	_batch_panel_body.visible = false
	_batch_toggle_button.text = "Show Batch Simulator"
	_batch_report_dir_label.text = "Reports Dir: %s" % ProjectSettings.globalize_path(BATCH_REPORTS_DIR)
	_batch_saved_path_label.text = "Last Saved: (none)"
	_batch_content_loader = CONTENT_LOADER_SCRIPT.new()
	_batch_content_registry = _batch_content_loader.load_all_definitions()
	_batch_simulator = COMBAT_BATCH_SIMULATOR_SCRIPT.new()
	_batch_simulator.configure(_batch_content_registry)
	_populate_batch_build_selectors(_batch_build_entries())
	_set_batch_status("Ready. Batch simulator is isolated from campaign saves.", true)

func _populate_batch_build_selectors(build_entries: Dictionary) -> void:
	_batch_attacker_selector.clear()
	_batch_defender_selector.clear()
	var build_ids: Array[String] = []
	for build_id_variant in build_entries.keys():
		build_ids.append(str(build_id_variant))
	build_ids.sort()
	for build_id in build_ids:
		var entry: Dictionary = build_entries.get(build_id, {})
		var label: String = "%s (%s)" % [str(entry.get("display_name", build_id)), build_id]
		_batch_attacker_selector.add_item(label)
		_batch_attacker_selector.set_item_metadata(_batch_attacker_selector.item_count - 1, build_id)
		_batch_defender_selector.add_item(label)
		_batch_defender_selector.set_item_metadata(_batch_defender_selector.item_count - 1, build_id)
	_select_batch_build(_batch_attacker_selector, "RET_STARTER")
	_select_batch_build(_batch_defender_selector, "SEC_STARTER")

func _batch_build_entries() -> Dictionary:
	if _batch_content_registry == null:
		return {}
	return _batch_content_registry.builds.get("entries", {})

func _set_batch_status(message: String, success: bool) -> void:
	_batch_status_label.text = "Batch Status: %s" % message
	_batch_status_label.modulate = Color(0.6, 0.95, 0.6) if success else Color(1.0, 0.65, 0.65)

func _selected_batch_build_id(selector: OptionButton) -> String:
	if selector.selected < 0:
		return ""
	return str(selector.get_item_metadata(selector.selected))

func _select_batch_build(selector: OptionButton, build_id: String) -> void:
	for idx in range(selector.item_count):
		if str(selector.get_item_metadata(idx)) == build_id:
			selector.select(idx)
			return

func _parse_positive_int(value: String, fallback: int, minimum: int) -> int:
	var parsed: int = int(value)
	if parsed < minimum:
		return fallback
	return parsed

func _on_roster_updated() -> void:
	_request_roster_refresh("signal:roster_updated")

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
	var encounter_label: String = str(payload.get("encounter_label", "Phase 1 - Arena Match"))
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
	_request_roster_refresh("refresh_all")
	_refresh_recent_events()
	_refresh_campaign_end_overlay()
	_refresh_today_event()
	_refresh_narrative_overlay()
	_refresh_campaign_actions_state()
	if not _is_fight_flow_active:
		_refresh_start_fight_button_state()

func _request_roster_refresh(source: String) -> void:
	var normalized_source: String = source.strip_edges()
	if normalized_source == "":
		normalized_source = "unspecified"
	if _is_refreshing_roster:
		_pending_roster_refresh = true
		_pending_roster_refresh_source = normalized_source
		print("[ROSTER_REFRESH] skipped source=%s reason=refresh_in_progress pending=true" % normalized_source)
		return
	_pending_roster_refresh = true
	_pending_roster_refresh_source = normalized_source
	var pass_index: int = 0
	while _pending_roster_refresh:
		pass_index += 1
		_pending_roster_refresh = false
		var active_source: String = _pending_roster_refresh_source
		print("[ROSTER_REFRESH] enter source=%s pass=%d" % [active_source, pass_index])
		_is_refreshing_roster = true
		_render_roster(active_source)
		_refresh_selected_fighter(active_source)
		if not _is_fight_flow_active:
			_refresh_start_fight_button_state()
		_is_refreshing_roster = false
		print("[ROSTER_REFRESH] exit source=%s pass=%d pending=%s" % [active_source, pass_index, str(_pending_roster_refresh)])

func _render_roster(source: String = "unspecified") -> void:
	_suppress_selection_callbacks = true
	print("[ROSTER_REFRESH] redraw_begin source=%s suppress_selection_callbacks=true" % source)
	_roster_list.clear()
	var roster: Array[Dictionary] = GameManager.get_roster()
	var locked_tournament_gladiator_id: String = GameManager.get_locked_tournament_gladiator_id()
	for row_index in range(roster.size()):
		var gladiator: Dictionary = roster[row_index]
		var gladiator_id: String = str(gladiator.get("id", "")).strip_edges()
		var status: String = GameManager.get_gladiator_status(gladiator)
		var level: int = int(gladiator.get("level", gladiator.get("livello", 1)))
		var experience: int = int(gladiator.get("experience", gladiator.get("esperienza", 0)))
		var exp_required: int = GameManager.required_exp_for_level(level)
		var exp_segment: String = "MAX" if exp_required <= 0 else "%d/%d" % [experience, exp_required]
		var injury_label: String = ""
		if status == GameManager.STATUS_INJURED:
			injury_label = " (%s)" % GameManager.format_injury_recovering_label(int(gladiator.get("injured_days", 0)))
		var acted_label: String = ""
		var is_locked_tournament_fighter: bool = locked_tournament_gladiator_id != "" and gladiator_id == locked_tournament_gladiator_id
		var action_context: String = GameManager.ACTION_CONTEXT_TOURNAMENT_CONTINUATION if is_locked_tournament_fighter else GameManager.ACTION_CONTEXT_NORMAL_FIGHT
		var eligibility: Dictionary = GameManager.get_gladiator_action_eligibility(gladiator_id, action_context, is_locked_tournament_fighter)
		if bool(eligibility.get("has_acted_this_phase", false)):
			acted_label = " [ACTED THIS PHASE]"
		var row: String = "%s | %s | Lv %d XP %s | HP:%d ATK:%d DEF:%d | %s%s | W:%d L:%d" % [
			GameManager.get_gladiator_display_name(gladiator),
			str(gladiator.get("class", "")),
			level,
			exp_segment,
			int(gladiator.get("max_hp", 1)),
			int(gladiator.get("atk", 1)),
			int(gladiator.get("def", 1)),
			status + acted_label,
			injury_label,
			int(gladiator.get("wins", 0)),
			int(gladiator.get("losses", 0)),
		]
		_roster_list.add_item(row)
		_roster_list.set_item_metadata(row_index, gladiator_id)
		_roster_list.set_item_disabled(row_index, not bool(eligibility.get("eligible", false)))
	var selected_id: String = GameManager.get_selected_gladiator_id()
	if selected_id == "":
		for index in range(_roster_list.item_count):
			_roster_list.deselect(index)
		_suppress_selection_callbacks = false
		print("[ROSTER_REFRESH] redraw_end source=%s suppress_selection_callbacks=false restored_selection=none" % source)
		return
	var selected_index: int = -1
	for index in range(_roster_list.item_count):
		if str(_roster_list.get_item_metadata(index)) == selected_id:
			selected_index = index
			break
	if selected_index >= 0 and not _roster_list.is_item_disabled(selected_index):
		_roster_list.select(selected_index)
		print("[SELECTION] programmatic_restore source=%s id=%s index=%d suppressed=%s" % [
			source,
			selected_id,
			selected_index,
			str(_suppress_selection_callbacks),
		])
	else:
		for index in range(_roster_list.item_count):
			_roster_list.deselect(index)
	_suppress_selection_callbacks = false
	print("[ROSTER_REFRESH] redraw_end source=%s suppress_selection_callbacks=false restored_selection=%s" % [source, selected_id if selected_index >= 0 else "none"])

func _gladiator_id_for_row(index: int) -> String:
	if index < 0 or index >= _roster_list.item_count:
		return ""
	return str(_roster_list.get_item_metadata(index)).strip_edges()

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
	var can_advance_turn_now: bool = _campaign_controls_enabled and GameManager.can_advance_turn()
	_new_game_button.disabled = not _campaign_controls_enabled
	_recruit_ret_button.disabled = not controls_enabled
	_recruit_sec_button.disabled = not controls_enabled
	_advance_turn_button.disabled = not can_advance_turn_now
	_advance_turn_button.tooltip_text = _build_advance_turn_block_reason() if not can_advance_turn_now else "Advance to next phase."
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
		_start_fight_button.text = "No Fights This Phase" if is_rest_day else "Enter Arena"

func _refresh_narrative_overlay() -> void:
	var event_data: Dictionary = GameManager.get_current_narrative_event()
	_narrative_choice_ids.clear()
	if event_data.is_empty():
		if _narrative_overlay.visible:
			print("[NarrativeUI] Closing narrative popup")
		_finish_narrative_event_ui()
		return
	if not _narrative_overlay.visible:
		print("[NarrativeUI] Narrative popup opened id=%s" % str(event_data.get("id", "")))
	_narrative_overlay.visible = true
	_narrative_event_resolving = false
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
	_resolve_narrative_choice_at(0, "A")

func _on_narrative_choice_b_pressed() -> void:
	_resolve_narrative_choice_at(1, "B")

func _resolve_narrative_choice_at(index: int, button_label: String) -> void:
	if _narrative_event_resolving:
		print("[NarrativeUI] Ignored duplicate narrative click button=%s" % button_label)
		return
	if index < 0 or index >= _narrative_choice_ids.size():
		return
	var choice_id: String = _narrative_choice_ids[index]
	_resolve_narrative_event(choice_id)

func _resolve_narrative_event(choice_id: String) -> void:
	var normalized_choice: String = choice_id.strip_edges()
	if normalized_choice == "":
		return
	var event_data: Dictionary = GameManager.get_current_narrative_event()
	if event_data.is_empty():
		print("[NarrativeUI] Ignored narrative choice with no active event choice=%s" % normalized_choice)
		return
	_narrative_event_resolving = true
	print("[NarrativeUI] Narrative choice clicked id=%s event=%s" % [normalized_choice, str(event_data.get("id", ""))])
	_set_narrative_buttons_disabled(true)
	print("[Narrative] Resolving %s with choice=%s" % [str(event_data.get("id", "")), normalized_choice])
	GameManager.resolve_narrative_event(normalized_choice)
	if not GameManager.has_active_narrative_event():
		print("[NarrativeUI] Closing narrative popup after resolve")
		_finish_narrative_event_ui()
		return
	_narrative_event_resolving = false
	_set_narrative_buttons_disabled(false)
	print("[NarrativeUI] Narrative event still active after resolve event=%s" % str(event_data.get("id", "")))

func _set_narrative_buttons_disabled(disabled: bool) -> void:
	if _narrative_choice_a_button.visible:
		_narrative_choice_a_button.disabled = disabled
	if _narrative_choice_b_button.visible:
		_narrative_choice_b_button.disabled = disabled

func _finish_narrative_event_ui() -> void:
	_narrative_overlay.visible = false
	_narrative_choice_ids.clear()
	_narrative_event_resolving = false

func _can_use_campaign_actions() -> bool:
	return GameManager.is_campaign_running() and not GameManager.has_active_narrative_event()

func _build_advance_turn_block_reason() -> String:
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
	return "Advance Phase is not available right now."

func _refresh_today_event() -> void:
	var event_data: Dictionary = GameManager.get_current_event()
	var event_name: String = str(event_data.get("name", "Arena Match"))
	var event_type: String = str(event_data.get("type", "FIGHT"))
	var event_description: String = str(event_data.get("description", "No event details available."))
	var reward_multiplier: float = float(event_data.get("reward_multiplier", 1.0))
	var reward_bonus_percent: int = int(round((reward_multiplier - 1.0) * 100.0))
	var risk_text: String = "Standard risk of death"
	var type_label: String = event_type
	if GameManager.has_active_tournament():
		type_label = "Tournament Match"
		event_description = "Tournament in progress. 2 matches required."
		risk_text = "Escalating risk (final match is deadlier)"
	if event_type == GameManager.EVENT_TYPE_HARD_FIGHT:
		risk_text = "High risk of death"
	elif event_type == GameManager.EVENT_TYPE_REST:
		risk_text = "No arena death risk this phase"
	elif event_type == GameManager.EVENT_TYPE_TOURNAMENT:
		type_label = "Tournament Match"
		event_description = "%s 2 matches required." % event_description
		risk_text = "High sustained risk across two matches"
	elif event_type == GameManager.EVENT_TYPE_BEAST_FIGHT:
		type_label = "Beast Hunt"
		event_description = "%s Dangerous animal encounter." % event_description
		risk_text = "Dangerous animal encounter"
	_today_event_title.text = GameManager.format_event_during_phase()
	_today_event_name_value.text = event_name
	_today_event_type_value.text = type_label
	_today_event_description_value.text = event_description
	_today_event_reward_value.text = "%+d%% rewards" % reward_bonus_percent
	_today_event_risk_value.text = risk_text

func _refresh_selected_fighter(source: String = "unspecified") -> void:
	var locked_tournament_gladiator_id: String = GameManager.get_locked_tournament_gladiator_id()
	if locked_tournament_gladiator_id != "":
		if GameManager.set_selected_gladiator(locked_tournament_gladiator_id):
			print("[SELECTION] lock_enforced source=%s id=%s" % [source, locked_tournament_gladiator_id])
	var selected: Dictionary = GameManager.get_selected_gladiator()
	if selected.is_empty():
		var available: Array[Dictionary] = GameManager.get_available_gladiators()
		if not available.is_empty():
			var fallback_id: String = str(available[0].get("id", ""))
			if GameManager.set_selected_gladiator(fallback_id):
				print("[SELECTION] fallback_selected source=%s id=%s" % [source, fallback_id])
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
		_end_game_title.text = "You survived all 30 Phases."
		_end_game_stats.text = "Current Phase: %d / %d\nFame: %d\nSurviving gladiators: %d" % [
			GameManager.get_current_phase(),
			GameManager.campaign_length_turns,
			GameManager.fame,
			GameManager.get_surviving_gladiators_count(),
		]
		return
	_end_game_title.text = "Your school has fallen"
	_end_game_stats.text = "Current Phase: %d / %d\nFame: %d" % [GameManager.get_current_phase(), GameManager.campaign_length_turns, GameManager.fame]
