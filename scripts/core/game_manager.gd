extends Node

signal game_state_changed(new_state: String)
signal roster_updated()
signal resources_updated(gold: int, fame: int, day: int)
signal fight_started(payload: Dictionary)
signal fight_resolved(result: Dictionary)
signal save_completed(success: bool)
signal recent_events_updated(events: Array[String])
signal daily_event_updated(event_data: Dictionary)
signal narrative_event_updated(event_data: Dictionary)

const SAVE_PATH: String = "user://savegame.json"
const CAMPAIGN_RUNS_ROOT_DIR: String = "user://campaign_runs"
const FIGHT_REPORTS_SUBDIR: String = "fight_reports"

const STATE_RUNNING: String = "running"
const STATE_VICTORY: String = "victory"
const STATE_DEFEAT: String = "defeat"

const STATE_IDLE: String = "idle"
const STATE_PREPARING_FIGHT: String = "preparing_fight"
const STATE_IN_FIGHT: String = "in_fight"
const STATE_RESOLVING_FIGHT: String = "resolving_fight"

const STARTING_GOLD: int = 100
const STARTING_FAME: int = 0
const STARTING_DAY: int = 1
const DEFAULT_CAMPAIGN_LENGTH_TURNS: int = 30
const STANDARD_CAMPAIGN_VICTORY_MODE: String = "TURN_COUNT_ONLY"
const ALTERNATE_VICTORY_MODE_TURN_OR_FAME: String = "TURN_OR_FAME"
const VICTORY_FAME_TARGET: int = 50

const RECRUIT_COST_RET: int = 30
const RECRUIT_COST_SEC: int = 30
const DAILY_UPKEEP_PER_ALIVE: int = 2

const REWARD_GOLD_VICTORY: int = 20
const REWARD_GOLD_DEFEAT_SURVIVED: int = 5
const REWARD_FAME_PER_WIN: int = 5
const REWARD_EXP_WINNER: int = 10
const REWARD_EXP_SURVIVOR_LOSER: int = 3
const LOSS_DEATH_CHANCE: float = 0.20
const LOSS_DEATH_CHANCE_MAX: float = 0.75

const INJURY_DAYS_STANDARD_LOSS: int = 7
const INJURY_DAYS_SEVERE_LOSS: int = 10
const INJURY_DAYS_LIGHT_LOSS_MIN: int = 5
const INJURY_DAYS_LIGHT_LOSS_MAX: int = 7
const INJURY_DAYS_HEAVY_LOSS_MIN: int = 7
const INJURY_DAYS_HEAVY_LOSS_MAX: int = 10
const DOCTOR_HEAL_AMOUNT_DAYS: int = 3
const DOCTOR_VISIT_COST_GOLD: int = 10
const CROWD_FAVOR_COST_GOLD: int = 5
const CROWD_FAVOR_FAME_REWARD: int = 3
const CROWD_FAVOR_REFUSE_FAME_PENALTY: int = 2
const CROWD_FAVOR_NEXT_FIGHT_FAME_BONUS: int = 2
const CROWD_FAVOR_NEXT_FIGHT_GOLD_BONUS: int = 5
const HARSH_TRAINING_XP_REWARD: int = 3
const HARSH_TRAINING_INJURY_CHANCE: float = 0.25
const RIVALRY_FAME_WIN_BONUS: int = 4
const RIVALRY_NEXT_FIGHT_LEVEL_BONUS: int = 1
const PATRON_OFFER_GOLD_REWARD: int = 20
const PATRON_NEXT_FIGHT_LEVEL_BONUS: int = 1
const WAGER_STAKE_GOLD: int = 10
const WAGER_PAYOUT_GOLD: int = 25

const LEVEL_CAP: int = 5
const RECENT_EVENTS_MAX: int = 10
const EVENT_TYPE_FIGHT: String = "FIGHT"
const EVENT_TYPE_HARD_FIGHT: String = "HARD_FIGHT"
const EVENT_TYPE_REST: String = "REST"
const EVENT_TYPE_TOURNAMENT: String = "TOURNAMENT"
const EVENT_TYPE_BEAST_FIGHT: String = "BEAST_FIGHT"

const EVENT_FIGHT_WEIGHT: float = 0.50
const EVENT_HARD_FIGHT_WEIGHT: float = 0.20
const EVENT_REST_WEIGHT: float = 0.10
const EVENT_TOURNAMENT_WEIGHT: float = 0.10
const EVENT_BEAST_FIGHT_WEIGHT: float = 0.10

const EVENT_FIGHT_REWARD_MULTIPLIER: float = 1.0
const EVENT_FIGHT_RISK_MODIFIER: float = 1.0
const EVENT_HARD_FIGHT_REWARD_MULTIPLIER: float = 1.5
const EVENT_HARD_FIGHT_RISK_MODIFIER: float = 1.5
const EVENT_REST_REWARD_MULTIPLIER: float = 0.0
const EVENT_REST_RISK_MODIFIER: float = 0.0
const EVENT_TOURNAMENT_REWARD_MULTIPLIER: float = 1.0
const EVENT_TOURNAMENT_RISK_MODIFIER: float = 1.2
const EVENT_BEAST_REWARD_MULTIPLIER: float = 1.5
const EVENT_BEAST_RISK_MODIFIER: float = 1.3
const EVENT_BEAST_FAME_BONUS: int = 2
const TOURNAMENT_MATCH_COUNT: int = 2
const TOURNAMENT_FINAL_GOLD_BONUS: int = 30
const TOURNAMENT_FINAL_FAME_BONUS: int = 10
const TOURNAMENT_FINAL_RISK_MULTIPLIER: float = 1.25
const TOURNAMENT_BETWEEN_MATCH_RECOVERY_HP: int = 0

const BEAST_TYPE_WOLF: String = "WOLF"
const BEAST_TYPE_BOAR: String = "BOAR"
const BEAST_TYPE_LION: String = "LION"
const NARRATIVE_EVENT_CHANCE: float = 0.25

const NARRATIVE_EVENT_DOCTOR_VISIT: String = "DOCTOR_VISIT"
const NARRATIVE_EVENT_CROWD_FAVOR: String = "CROWD_FAVOR"
const NARRATIVE_EVENT_HARSH_TRAINING: String = "HARSH_TRAINING"
const NARRATIVE_EVENT_RIVALRY: String = "RIVALRY"
const NARRATIVE_EVENT_AMBITIOUS_GLADIATOR: String = "AMBITIOUS_GLADIATOR"
const NARRATIVE_EVENT_PATRON_OFFER: String = "PATRON_OFFER"
const NARRATIVE_EVENT_SPECIALIZED_TRAINING: String = "SPECIALIZED_TRAINING"
const NARRATIVE_EVENT_WAGER: String = "WAGER"

const STATUS_AVAILABLE: String = "AVAILABLE"
const STATUS_INJURED: String = "INJURED"
const STATUS_DEAD: String = "DEAD"

const RET_BUILD_ID: String = "RET_STARTER"
const SEC_BUILD_ID: String = "SEC_STARTER"

const CONTENT_LOADER_SCRIPT: GDScript = preload("res://scripts/data/loaders/ContentLoader.gd")
const BUILD_STATS_RESOLVER_SCRIPT: GDScript = preload("res://scripts/combat/systems/BuildStatsResolver.gd")

var gold: int = STARTING_GOLD
var fame: int = STARTING_FAME
var day: int = STARTING_DAY
var next_gladiator_index: int = 1
var next_enemy_index: int = 1
var roster: Array[Dictionary] = []
var battle_history: Array[Dictionary] = []
var recent_events: Array[String] = []
var game_state: String = STATE_RUNNING
var selected_gladiator_id: String = ""
var locked_tournament_gladiator_id: String = ""
var current_event: Dictionary = {}
var current_narrative_event: Dictionary = {}
var active_tournament: Dictionary = {}
var current_fight_payload: Dictionary = {}
var active_encounter: Dictionary = {}
var pending_match: Dictionary = {}
var fight_in_progress: bool = false
var next_fight_enemy_level_bonus: int = 0
var next_fight_bonus_fame: int = 0
var next_fight_bonus_gold: int = 0
var next_fight_risk_modifier_mult: float = 1.0
var pending_wager_stake: int = 0
var campaign_length_turns: int = DEFAULT_CAMPAIGN_LENGTH_TURNS
var campaign_victory_mode: String = STANDARD_CAMPAIGN_VICTORY_MODE
var campaign_run_id: String = ""

var _content_registry: ContentRegistry
var _stats_resolver: BuildStatsResolver

func get_current_phase() -> int:
	return day

func format_phase_label(phase_value: int = -1) -> String:
	var normalized_phase: int = phase_value if phase_value > 0 else day
	return "Phase %d" % normalized_phase

func format_phase_progress(phase_value: int = -1, total_phases: int = -1) -> String:
	var normalized_phase: int = phase_value if phase_value > 0 else day
	var normalized_total: int = total_phases if total_phases > 0 else campaign_length_turns
	return "Phase %d / %d" % [normalized_phase, normalized_total]

func format_event_during_phase(phase_value: int = -1) -> String:
	var normalized_phase: int = phase_value if phase_value > 0 else day
	return "Event during Phase %d" % normalized_phase

func format_advance_phase_log(previous_phase: int, next_phase: int) -> String:
	return "%s - Advanced to Phase %d." % [format_phase_label(previous_phase), next_phase]

func format_injury_duration_phrasing(value: int) -> String:
	var clamped_value: int = maxi(0, value)
	var suffix: String = "phase" if clamped_value == 1 else "phases"
	return "%d %s" % [clamped_value, suffix]

func format_injury_recovering_label(value: int) -> String:
	return "Recovering (%s remaining)" % format_injury_duration_phrasing(value)

func _ready() -> void:
	_bootstrap_content()
	ensure_log_directories()

func new_game() -> void:
	campaign_run_id = _generate_campaign_run_id()
	ensure_log_directories()
	_initialize_campaign_log()
	gold = STARTING_GOLD
	fame = STARTING_FAME
	day = STARTING_DAY
	campaign_length_turns = DEFAULT_CAMPAIGN_LENGTH_TURNS
	campaign_victory_mode = STANDARD_CAMPAIGN_VICTORY_MODE
	next_gladiator_index = 1
	next_enemy_index = 1
	selected_gladiator_id = ""
	locked_tournament_gladiator_id = ""
	roster.clear()
	battle_history.clear()
	recent_events.clear()
	current_event = generate_daily_event()
	current_narrative_event = {}
	active_tournament = {}
	next_fight_enemy_level_bonus = 0
	next_fight_bonus_fame = 0
	next_fight_bonus_gold = 0
	next_fight_risk_modifier_mult = 1.0
	pending_wager_stake = 0
	clear_active_encounter_state(false)
	_set_game_state(STATE_RUNNING)
	recruit_gladiator("RET")
	recruit_gladiator("SEC")
	add_recent_event("New campaign started (%s)." % format_phase_label())
	append_campaign_log("%s - New campaign started." % format_phase_label())
	var saved: bool = save_game()
	save_completed.emit(saved)
	roster_updated.emit()
	_emit_resources_updated()
	_emit_recent_events_updated()
	_emit_daily_event_updated()
	_emit_narrative_event_updated()

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("GameManager.load_game: failed to open save file for reading.")
		return false
	var raw_json: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_error: int = json.parse(raw_json)
	if parse_error != OK:
		push_error("GameManager.load_game: invalid save JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return false
	var parsed: Variant = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("GameManager.load_game: save root must be a Dictionary.")
		return false

	var data: Dictionary = parsed as Dictionary
	_apply_loaded_data(data)
	_set_game_state(_sanitize_game_state(data.get("game_state", STATE_RUNNING)))
	check_end_conditions()
	roster_updated.emit()
	_emit_resources_updated()
	_emit_recent_events_updated()
	_emit_daily_event_updated()
	_emit_narrative_event_updated()
	return true

func save_game() -> bool:
	var payload: Dictionary = {
		"gold": gold,
		"fame": fame,
		"day": day,
		"turn": day,
		"campaign_length_turns": campaign_length_turns,
		"campaign_victory_mode": campaign_victory_mode,
		"next_gladiator_index": next_gladiator_index,
		"next_enemy_index": next_enemy_index,
		"game_state": game_state,
		"selected_gladiator_id": selected_gladiator_id,
		"locked_tournament_gladiator_id": locked_tournament_gladiator_id,
		"roster": roster,
		"battle_history": battle_history,
		"recent_events": recent_events,
		"current_event": current_event,
		"current_narrative_event": current_narrative_event,
		"active_tournament": active_tournament,
		"next_fight_enemy_level_bonus": next_fight_enemy_level_bonus,
		"next_fight_bonus_fame": next_fight_bonus_fame,
		"next_fight_bonus_gold": next_fight_bonus_gold,
		"next_fight_risk_modifier_mult": next_fight_risk_modifier_mult,
		"pending_wager_stake": pending_wager_stake,
		"campaign_run_id": campaign_run_id,
	}
	var serialized: String = JSON.stringify(payload, "\t", false)
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameManager.save_game: failed to open save file for writing.")
		save_completed.emit(false)
		return false
	file.store_string(serialized)
	file.close()
	save_completed.emit(true)
	return true

func advance_turn() -> void:
	if not can_advance_turn():
		return
	day += 1
	append_campaign_log(format_advance_phase_log(day - 1, day))
	current_event = generate_daily_event()
	current_narrative_event = generate_narrative_event()
	heal_and_update_injuries()
	if _is_rest_event(current_event):
		apply_rest_day_recovery_bonus()
	apply_daily_upkeep()
	check_end_conditions()
	save_game()
	roster_updated.emit()
	_emit_resources_updated()
	_emit_recent_events_updated()
	_emit_daily_event_updated()
	_emit_narrative_event_updated()

func advance_day() -> void:
	advance_turn()

func can_advance_turn() -> bool:
	return can_advance_day()

func can_advance_day() -> bool:
	if game_state != STATE_RUNNING:
		return false
	if has_active_narrative_event():
		return false
	if has_active_tournament():
		if not can_continue_active_tournament():
			invalidate_active_tournament("no_gladiator_can_continue")
			return true
		return false
	return true

func is_tournament_fighter_locked() -> bool:
	return has_active_tournament() and can_continue_active_tournament() and locked_tournament_gladiator_id != ""

func get_locked_tournament_gladiator_id() -> String:
	if not is_tournament_fighter_locked():
		return ""
	return locked_tournament_gladiator_id

func get_roster() -> Array[Dictionary]:
	return roster.duplicate(true)

func get_recent_events() -> Array[String]:
	return recent_events.duplicate()

func get_available_gladiators() -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for gladiator: Dictionary in roster:
		if get_gladiator_status(gladiator) == STATUS_AVAILABLE:
			available.append(gladiator.duplicate(true))
	return available

func get_injured_gladiators() -> Array[Dictionary]:
	var injured: Array[Dictionary] = []
	for gladiator: Dictionary in roster:
		if not bool(gladiator.get("alive", true)):
			continue
		if int(gladiator.get("injured_days", 0)) > 0:
			injured.append(gladiator.duplicate(true))
	return injured

func get_available_alive_gladiators() -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for gladiator: Dictionary in roster:
		if get_gladiator_status(gladiator) == STATUS_AVAILABLE:
			available.append(gladiator.duplicate(true))
	return available

func set_selected_gladiator(gladiator_id: String) -> bool:
	var normalized_id: String = gladiator_id.strip_edges()
	if normalized_id == "":
		selected_gladiator_id = ""
		return true
	var fighter: Dictionary = _find_gladiator_by_id(normalized_id)
	if fighter.is_empty():
		return false
	if get_gladiator_status(fighter) != STATUS_AVAILABLE:
		return false
	selected_gladiator_id = normalized_id
	return true

func get_selected_gladiator() -> Dictionary:
	if selected_gladiator_id == "":
		return {}
	var fighter: Dictionary = _find_gladiator_by_id(selected_gladiator_id)
	if fighter.is_empty():
		selected_gladiator_id = ""
		return {}
	if get_gladiator_status(fighter) != STATUS_AVAILABLE:
		selected_gladiator_id = ""
		return {}
	return fighter.duplicate(true)

func get_selected_gladiator_id() -> String:
	if get_selected_gladiator().is_empty():
		return ""
	return selected_gladiator_id

func has_living_gladiators() -> bool:
	for gladiator: Dictionary in roster:
		if bool(gladiator.get("alive", false)):
			return true
	return false

func is_game_over() -> bool:
	return game_state == STATE_DEFEAT or not has_living_gladiators()

func is_campaign_running() -> bool:
	return game_state == STATE_RUNNING

func get_surviving_gladiators_count() -> int:
	var alive_count: int = 0
	for gladiator: Dictionary in roster:
		if bool(gladiator.get("alive", false)):
			alive_count += 1
	return alive_count

func recruit_gladiator(gladiator_class: String) -> Dictionary:
	if not is_campaign_running():
		return {"error": "Campaign has already ended"}
	if has_active_narrative_event():
		return {"error": "Resolve the active narrative event first"}
	var normalized_class: String = gladiator_class.strip_edges().to_upper()
	var recruit_cost: int = _recruit_cost_for_class(normalized_class)
	if recruit_cost <= 0:
		return {"error": "Unsupported class: %s" % gladiator_class}
	if gold < recruit_cost:
		return {"error": "Not enough gold"}

	var gladiator: Dictionary = _create_gladiator(normalized_class)
	gold -= recruit_cost
	roster.append(gladiator)
	next_gladiator_index += 1
	add_recent_event("Reclutato %s." % get_gladiator_display_name(gladiator))
	append_campaign_log("%s - Recruited %s (%s) for %d gold." % [format_phase_label(), get_gladiator_display_name(gladiator), str(gladiator.get("class", "")), recruit_cost])
	save_game()
	roster_updated.emit()
	_emit_resources_updated()
	return gladiator.duplicate(true)

func can_start_fight() -> bool:
	if not is_campaign_running():
		return false
	if has_active_narrative_event():
		return false
	if has_active_tournament():
		return can_continue_active_tournament()
	if _is_rest_event(get_current_event()):
		return false
	return get_available_gladiators().size() >= 1

func has_active_tournament() -> bool:
	return not active_tournament.is_empty()

func can_continue_active_tournament() -> bool:
	if not has_active_tournament():
		return false
	var gladiator_id: String = locked_tournament_gladiator_id.strip_edges()
	if gladiator_id == "":
		gladiator_id = str(active_tournament.get("gladiator_id", "")).strip_edges()
	if gladiator_id == "":
		return false
	if locked_tournament_gladiator_id != gladiator_id:
		locked_tournament_gladiator_id = gladiator_id
	var total_matches: int = int(active_tournament.get("total_matches", TOURNAMENT_MATCH_COUNT))
	var current_match: int = int(active_tournament.get("current_match", 1))
	if total_matches <= 0:
		return false
	if current_match < 1 or current_match > total_matches:
		return false
	var selected: Dictionary = _find_gladiator_by_id(gladiator_id)
	if selected.is_empty():
		return false
	if not bool(selected.get("alive", false)):
		return false
	if int(selected.get("injured_days", 0)) > 0:
		return false
	if get_available_gladiators().is_empty():
		return false
	return true

func invalidate_active_tournament(reason: String = "invalid_state") -> void:
	if not has_active_tournament():
		return
	var normalized_reason: String = reason.strip_edges()
	if normalized_reason == "":
		normalized_reason = "invalid_state"
	active_tournament = {}
	locked_tournament_gladiator_id = ""
	if _event_type(current_event) == EVENT_TYPE_TOURNAMENT:
		current_event = _build_fight_event()
	var reason_message: String = "The tournament was forfeited because no gladiator could continue."
	if normalized_reason == "missing_gladiator":
		reason_message = "The tournament was forfeited because the selected gladiator was missing."
	elif normalized_reason == "gladiator_dead":
		reason_message = "The tournament was forfeited because your gladiator died."
	elif normalized_reason == "gladiator_unavailable":
		reason_message = "The tournament was forfeited because your gladiator became unavailable."
	elif normalized_reason == "no_gladiator_can_continue":
		reason_message = "The tournament was forfeited because no gladiator could continue."
	elif normalized_reason == "inconsistent_state":
		reason_message = "The tournament was forfeited because tournament data was inconsistent."
	add_recent_event(reason_message)
	append_campaign_log("%s - Tournament forfeited: %s" % [format_phase_label(), normalized_reason])
	save_game()
	roster_updated.emit()
	_emit_resources_updated()
	_emit_recent_events_updated()
	_emit_daily_event_updated()

func has_active_narrative_event() -> bool:
	return not current_narrative_event.is_empty()

func get_current_narrative_event() -> Dictionary:
	if not has_active_narrative_event():
		return {}
	return _sanitize_narrative_event(current_narrative_event)

func can_offer_doctor_visit() -> bool:
	return not get_injured_gladiators().is_empty()

func can_offer_crowd_favor() -> bool:
	return gold >= CROWD_FAVOR_COST_GOLD

func can_offer_harsh_training() -> bool:
	return not get_available_alive_gladiators().is_empty()

func can_offer_ambitious_gladiator() -> bool:
	return not get_injured_gladiators().is_empty()

func can_offer_specialized_training() -> bool:
	return not get_available_alive_gladiators().is_empty()

func can_offer_wager() -> bool:
	return pending_wager_stake <= 0 and gold >= WAGER_STAKE_GOLD

func generate_narrative_event() -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(hash("narrative-event-%d-%d-%d" % [day, next_gladiator_index, roster.size()]))
	if rng.randf() >= NARRATIVE_EVENT_CHANCE:
		return {}
	var eligible_ids: Array[String] = []
	if can_offer_doctor_visit():
		eligible_ids.append(NARRATIVE_EVENT_DOCTOR_VISIT)
	if can_offer_crowd_favor():
		eligible_ids.append(NARRATIVE_EVENT_CROWD_FAVOR)
	if can_offer_harsh_training():
		eligible_ids.append(NARRATIVE_EVENT_HARSH_TRAINING)
	if can_offer_ambitious_gladiator():
		eligible_ids.append(NARRATIVE_EVENT_AMBITIOUS_GLADIATOR)
	eligible_ids.append(NARRATIVE_EVENT_RIVALRY)
	eligible_ids.append(NARRATIVE_EVENT_PATRON_OFFER)
	if can_offer_specialized_training():
		eligible_ids.append(NARRATIVE_EVENT_SPECIALIZED_TRAINING)
	if can_offer_wager():
		eligible_ids.append(NARRATIVE_EVENT_WAGER)
	if eligible_ids.is_empty():
		return {}
	var selected_index: int = rng.randi_range(0, eligible_ids.size() - 1)
	var selected_event_id: String = eligible_ids[selected_index]
	if selected_event_id == NARRATIVE_EVENT_DOCTOR_VISIT:
		return _build_doctor_visit_event()
	if selected_event_id == NARRATIVE_EVENT_CROWD_FAVOR:
		return _build_crowd_favor_event()
	if selected_event_id == NARRATIVE_EVENT_HARSH_TRAINING:
		return _build_harsh_training_event()
	if selected_event_id == NARRATIVE_EVENT_RIVALRY:
		return _build_rivalry_event()
	if selected_event_id == NARRATIVE_EVENT_AMBITIOUS_GLADIATOR:
		return _build_ambitious_gladiator_event()
	if selected_event_id == NARRATIVE_EVENT_PATRON_OFFER:
		return _build_patron_offer_event()
	if selected_event_id == NARRATIVE_EVENT_SPECIALIZED_TRAINING:
		return _build_specialized_training_event()
	return _build_wager_event()

func can_resolve_narrative_choice(choice_id: String) -> bool:
	if not has_active_narrative_event():
		return false
	var normalized_choice: String = choice_id.strip_edges()
	if normalized_choice == "":
		return false
	var event_id: String = str(current_narrative_event.get("id", ""))
	if event_id == NARRATIVE_EVENT_DOCTOR_VISIT and normalized_choice == "PAY":
		return gold >= DOCTOR_VISIT_COST_GOLD
	if event_id == NARRATIVE_EVENT_CROWD_FAVOR and normalized_choice == "EXHIBITION":
		return gold >= CROWD_FAVOR_COST_GOLD
	if event_id == NARRATIVE_EVENT_WAGER and normalized_choice == "BET":
		return gold >= WAGER_STAKE_GOLD and pending_wager_stake <= 0
	return _choice_exists(current_narrative_event, normalized_choice)

func resolve_narrative_event(choice_id: String) -> void:
	if not has_active_narrative_event():
		add_recent_event("No active narrative event to resolve.")
		_emit_recent_events_updated()
		return
	var event_data: Dictionary = _sanitize_narrative_event(current_narrative_event)
	var event_id: String = str(event_data.get("id", ""))
	var normalized_choice: String = choice_id.strip_edges()
	if not _choice_exists(event_data, normalized_choice):
		add_recent_event("Invalid narrative choice for %s." % event_id)
		_emit_recent_events_updated()
		return

	var result_message: String = ""
	var resolution_completed: bool = true
	if event_id == NARRATIVE_EVENT_DOCTOR_VISIT:
		result_message = _resolve_doctor_visit_choice(normalized_choice)
		if result_message == "":
			resolution_completed = false
	elif event_id == NARRATIVE_EVENT_CROWD_FAVOR:
		result_message = _resolve_crowd_favor_choice(normalized_choice)
		if result_message == "":
			resolution_completed = false
	elif event_id == NARRATIVE_EVENT_HARSH_TRAINING:
		result_message = _resolve_harsh_training_choice(normalized_choice)
	elif event_id == NARRATIVE_EVENT_RIVALRY:
		result_message = _resolve_rivalry_choice(normalized_choice)
	elif event_id == NARRATIVE_EVENT_AMBITIOUS_GLADIATOR:
		result_message = _resolve_ambitious_gladiator_choice(normalized_choice)
	elif event_id == NARRATIVE_EVENT_PATRON_OFFER:
		result_message = _resolve_patron_offer_choice(normalized_choice)
	elif event_id == NARRATIVE_EVENT_SPECIALIZED_TRAINING:
		result_message = _resolve_specialized_training_choice(normalized_choice)
	elif event_id == NARRATIVE_EVENT_WAGER:
		result_message = _resolve_wager_choice(normalized_choice)
	else:
		result_message = "The moment passes without consequence."

	if not resolution_completed:
		add_recent_event("Choice unavailable: requirements not met.")
		save_game()
		_emit_resources_updated()
		_emit_recent_events_updated()
		_emit_narrative_event_updated()
		return

	add_recent_event("%s — %s" % [str(event_data.get("title", "Narrative Event")), result_message])
	append_campaign_log("%s - Narrative event %s resolved: %s" % [format_event_during_phase(), event_id, result_message])
	current_narrative_event = {}
	save_game()
	roster_updated.emit()
	_emit_resources_updated()
	_emit_recent_events_updated()
	_emit_narrative_event_updated()

func generate_daily_event() -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(hash("daily-event-%d-%d-%d" % [day, next_enemy_index, roster.size()]))
	var roll: float = rng.randf()
	var selected_event: Dictionary = _build_fight_event()
	if roll < EVENT_FIGHT_WEIGHT:
		selected_event = _build_fight_event()
	elif roll < EVENT_FIGHT_WEIGHT + EVENT_HARD_FIGHT_WEIGHT:
		selected_event = _build_hard_fight_event()
	elif roll < EVENT_FIGHT_WEIGHT + EVENT_HARD_FIGHT_WEIGHT + EVENT_REST_WEIGHT:
		selected_event = _build_rest_event()
	elif roll < EVENT_FIGHT_WEIGHT + EVENT_HARD_FIGHT_WEIGHT + EVENT_REST_WEIGHT + EVENT_TOURNAMENT_WEIGHT:
		selected_event = _build_tournament_event()
	elif roll < EVENT_FIGHT_WEIGHT + EVENT_HARD_FIGHT_WEIGHT + EVENT_REST_WEIGHT + EVENT_TOURNAMENT_WEIGHT + EVENT_BEAST_FIGHT_WEIGHT:
		selected_event = _build_beast_fight_event()
	else:
		selected_event = _build_fight_event()
	if _event_type(selected_event) == EVENT_TYPE_HARD_FIGHT:
		add_recent_event("A dangerous arena phase increased the stakes.")
	elif _event_type(selected_event) == EVENT_TYPE_REST:
		add_recent_event("The arena was closed for rest.")
	elif _event_type(selected_event) == EVENT_TYPE_TOURNAMENT:
		add_recent_event("A two-match tournament has been announced.")
	elif _event_type(selected_event) == EVENT_TYPE_BEAST_FIGHT:
		add_recent_event("A beast hunt has been posted in the arena.")
	return selected_event

func get_current_event() -> Dictionary:
	if current_event.is_empty():
		current_event = _build_fight_event()
	return _sanitize_event(current_event)

func start_next_fight() -> Dictionary:
	if not is_campaign_running():
		return {"error": "Campaign has already ended"}
	if has_active_narrative_event():
		return {"error": "Resolve the active narrative event first"}
	if has_active_tournament() and not can_continue_active_tournament():
		invalidate_active_tournament("no_gladiator_can_continue")
		return {"error": "Tournament could not continue and was forfeited"}
	var today_event: Dictionary = get_current_event()
	if not has_active_tournament() and _is_rest_event(today_event):
		return {"error": "The arena is closed this phase. Your gladiators recover."}
	if not can_start_fight():
		return {"error": "No available gladiators"}

	var player_fighter: Dictionary = get_selected_gladiator()
	if has_active_tournament() and can_continue_active_tournament():
		player_fighter = _find_gladiator_by_id(locked_tournament_gladiator_id).duplicate(true)
	if player_fighter.is_empty():
		var available: Array[Dictionary] = get_available_gladiators()
		if available.is_empty():
			return {"error": "No valid player gladiator found"}
		player_fighter = available[0]
		selected_gladiator_id = str(player_fighter.get("id", ""))
	var active_event_type: String = _event_type(today_event)
	if has_active_tournament():
		active_event_type = EVENT_TYPE_TOURNAMENT
	elif active_event_type == EVENT_TYPE_TOURNAMENT:
		var tournament_start: Dictionary = start_tournament(player_fighter)
		if tournament_start.has("error"):
			return tournament_start
	var enemy_fighter: Dictionary = {}
	if active_event_type == EVENT_TYPE_BEAST_FIGHT:
		enemy_fighter = generate_beast_enemy(player_fighter)
	else:
		enemy_fighter = generate_enemy_for(player_fighter)
		if active_event_type == EVENT_TYPE_TOURNAMENT and has_active_tournament():
			var match_index: int = int(active_tournament.get("current_match", 1))
			if match_index >= TOURNAMENT_MATCH_COUNT:
				enemy_fighter["level"] = clampi(int(enemy_fighter.get("level", 1)) + 1, 1, LEVEL_CAP)
				enemy_fighter["livello"] = int(enemy_fighter.get("level", 1))
				enemy_fighter["nome"] = "Arena Champion %s" % _to_roman(next_enemy_index)
	if enemy_fighter.is_empty():
		return {"error": "Enemy generation failed"}
	if next_fight_enemy_level_bonus > 0 and not bool(enemy_fighter.get("is_beast", false)):
		enemy_fighter["level"] = clampi(int(enemy_fighter.get("level", 1)) + next_fight_enemy_level_bonus, 1, LEVEL_CAP)
		enemy_fighter["livello"] = int(enemy_fighter.get("level", 1))
		enemy_fighter["max_hp"] = maxi(1, int(enemy_fighter.get("max_hp", 1)) + next_fight_enemy_level_bonus)
		enemy_fighter["atk"] = maxi(1, int(enemy_fighter.get("atk", 1)) + next_fight_enemy_level_bonus)
		enemy_fighter["def"] = maxi(1, int(enemy_fighter.get("def", 1)) + int(round(float(next_fight_enemy_level_bonus) / 2.0)))
		add_recent_event("The next opponent is reinforced (rivalry/patron effect, +%d level)." % next_fight_enemy_level_bonus)

	var tournament_match_index: int = 0
	if has_active_tournament():
		tournament_match_index = int(active_tournament.get("current_match", 1))
	_set_game_state(STATE_PREPARING_FIGHT)
	fight_in_progress = true
	var payload: Dictionary = {
		"day": day,
		"seed": _build_match_seed(player_fighter, enemy_fighter),
		"fighter_a": player_fighter,
		"fighter_b": enemy_fighter,
		"player_gladiator_id": str(player_fighter.get("id", "")),
		"enemy_gladiator_id": str(enemy_fighter.get("id", "")),
		"attacker_build_id": _build_id_for_class(str(player_fighter.get("class", ""))),
		"defender_build_id": _build_enemy_build_id(enemy_fighter),
		"attacker_label": _build_combatant_identity_label(player_fighter),
		"defender_label": _build_combatant_identity_label(enemy_fighter),
		"event_type": active_event_type,
		"encounter_label": _build_encounter_label(active_event_type, enemy_fighter),
		"enemy_kind": "BEAST" if bool(enemy_fighter.get("is_beast", false)) else "GLADIATOR",
		"tournament_match_index": tournament_match_index,
		"tournament_total_matches": TOURNAMENT_MATCH_COUNT if has_active_tournament() else 0,
		"next_fight_bonus_fame": next_fight_bonus_fame,
		"next_fight_bonus_gold": next_fight_bonus_gold,
		"next_fight_risk_modifier_mult": next_fight_risk_modifier_mult,
		"pending_wager_stake": pending_wager_stake,
	}
	current_fight_payload = payload.duplicate(true)
	active_encounter = {
		"event_type": active_event_type,
		"player_gladiator_id": str(player_fighter.get("id", "")),
		"enemy_gladiator_id": str(enemy_fighter.get("id", "")),
	}
	pending_match = {
		"event_type": active_event_type,
		"tournament_match_index": tournament_match_index,
	}
	fight_started.emit(payload)
	_set_game_state(STATE_IN_FIGHT)
	return payload

func generate_enemy_for(player_gladiator: Dictionary) -> Dictionary:
	_bootstrap_content()
	if player_gladiator.is_empty():
		return {}
	var player_level: int = clampi(int(player_gladiator.get("level", player_gladiator.get("livello", 1))), 1, LEVEL_CAP)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(hash("%s-%d-%d" % [str(player_gladiator.get("id", "")), day, next_enemy_index]))
	var enemy_class: String = "RET" if rng.randi_range(0, 1) == 0 else "SEC"
	var level_delta: int = rng.randi_range(-1, 1)
	var enemy_level: int = clampi(player_level + level_delta, 1, LEVEL_CAP)
	var base_stats: Dictionary = _stats_resolver.resolve_build_stats(_build_id_for_class(enemy_class))
	var enemy: Dictionary = {
		"id": "enemy_%04d" % next_enemy_index,
		"nome": _build_enemy_name(enemy_class, next_enemy_index),
		"class": enemy_class,
		"level": enemy_level,
		"experience": 0,
		"livello": enemy_level,
		"esperienza": 0,
		"max_hp": maxi(1, int(base_stats.get("max_hp", 1))),
		"atk": maxi(1, int(base_stats.get("atk", 1))),
		"def": maxi(1, int(base_stats.get("def", 1))),
		"alive": true,
		"injured_days": 0,
		"is_enemy": true,
	}
	for reached_level: int in range(2, enemy_level + 1):
		_apply_level_growth(enemy, reached_level)
	next_enemy_index += 1
	return enemy

func generate_beast_enemy(player_gladiator: Dictionary) -> Dictionary:
	if player_gladiator.is_empty():
		return {}
	var player_level: int = clampi(int(player_gladiator.get("level", player_gladiator.get("livello", 1))), 1, LEVEL_CAP)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(hash("beast-%s-%d-%d" % [str(player_gladiator.get("id", "")), day, next_enemy_index]))
	var beast_roll: int = rng.randi_range(0, 2)
	var beast_type: String = BEAST_TYPE_WOLF
	if beast_roll == 1:
		beast_type = BEAST_TYPE_BOAR
	elif beast_roll == 2:
		beast_type = BEAST_TYPE_LION
	var level_delta: int = rng.randi_range(0, 1)
	var beast_level: int = clampi(player_level + level_delta, 1, LEVEL_CAP)
	var stats: Dictionary = _build_beast_stats(beast_type, beast_level)
	var beast: Dictionary = {
		"id": "beast_%04d" % next_enemy_index,
		"name": "Arena %s" % _beast_display_name(beast_type),
		"nome": "Arena %s" % _beast_display_name(beast_type),
		"class": "BEAST",
		"subtype": beast_type,
		"level": beast_level,
		"max_hp": int(stats.get("max_hp", 1)),
		"atk": int(stats.get("atk", 1)),
		"def": int(stats.get("def", 1)),
		"alive": true,
		"is_enemy": true,
		"is_beast": true,
	}
	next_enemy_index += 1
	return beast

func start_tournament(gladiator: Dictionary) -> Dictionary:
	if gladiator.is_empty():
		return {"error": "No valid gladiator for tournament"}
	var gladiator_id: String = str(gladiator.get("id", ""))
	if gladiator_id == "":
		return {"error": "Tournament gladiator is missing id"}
	active_tournament = {
		"gladiator_id": gladiator_id,
		"current_match": 1,
		"total_matches": TOURNAMENT_MATCH_COUNT,
		"wins": 0,
		"carry_over_hp": int(gladiator.get("max_hp", 1)),
	}
	locked_tournament_gladiator_id = gladiator_id
	add_recent_event("Tournament started for %s (Match 1/%d)." % [get_gladiator_display_name(gladiator), TOURNAMENT_MATCH_COUNT])
	return active_tournament.duplicate(true)

func process_tournament_step(result: Dictionary) -> Dictionary:
	if not has_active_tournament():
		return {}
	var gladiator_id: String = str(active_tournament.get("gladiator_id", ""))
	var winner_id: String = str(result.get("winner_id", ""))
	var player_won: bool = winner_id == gladiator_id
	var current_match: int = int(active_tournament.get("current_match", 1))
	if not player_won:
		add_recent_event("Tournament ended: your gladiator lost at match %d." % current_match)
		append_campaign_log("%s - Tournament ended with defeat at match %d." % [format_phase_label(), current_match])
		active_tournament = {}
		locked_tournament_gladiator_id = ""
		return {"tournament_completed": false, "player_won": false}
	var carried_hp: int = maxi(0, int(result.get("winner_remaining_hp", 0)) + TOURNAMENT_BETWEEN_MATCH_RECOVERY_HP)
	active_tournament["carry_over_hp"] = carried_hp
	active_tournament["wins"] = int(active_tournament.get("wins", 0)) + 1
	if current_match >= TOURNAMENT_MATCH_COUNT:
		gold += TOURNAMENT_FINAL_GOLD_BONUS
		fame += TOURNAMENT_FINAL_FAME_BONUS
		add_recent_event("Tournament complete! Bonus: +%d gold, +%d fame." % [TOURNAMENT_FINAL_GOLD_BONUS, TOURNAMENT_FINAL_FAME_BONUS])
		append_campaign_log("%s - Tournament completed: +%d gold, +%d fame." % [format_phase_label(), TOURNAMENT_FINAL_GOLD_BONUS, TOURNAMENT_FINAL_FAME_BONUS])
		active_tournament = {}
		locked_tournament_gladiator_id = ""
		return {"tournament_completed": true, "player_won": true}
	active_tournament["current_match"] = current_match + 1
	add_recent_event("Tournament progress: Final Match unlocked (Match %d/%d)." % [int(active_tournament.get("current_match", 2)), TOURNAMENT_MATCH_COUNT])
	return {"tournament_completed": false, "player_won": true}

func abort_active_fight(reason: String = "") -> void:
	if game_state == STATE_RUNNING:
		return
	if reason != "":
		push_warning("GameManager.abort_active_fight called: %s" % reason)
	clear_active_encounter_state(true)
	_set_game_state(STATE_RUNNING)

func resolve_fight(result: Dictionary) -> void:
	if has_active_tournament() and not can_continue_active_tournament():
		invalidate_active_tournament("no_gladiator_can_continue")
	if not _result_has_required_fields(result):
		push_error("GameManager.resolve_fight: incomplete result payload: %s" % JSON.stringify(result))
		clear_active_encounter_state(true)
		_set_game_state(STATE_RUNNING)
		return

	_set_game_state(STATE_RESOLVING_FIGHT)
	var active_event: Dictionary = _get_effective_fight_event()
	var winner_id: String = str(result.get("winner_id", ""))
	var loser_id: String = str(result.get("loser_id", ""))
	var loser_dead: bool = _roll_loser_death(winner_id, loser_id, result)
	result["loser_dead"] = loser_dead
	result["player_gladiator_id"] = _resolve_player_gladiator_id(winner_id, loser_id)

	var winner: Dictionary = _find_gladiator_by_id(winner_id)
	var loser: Dictionary = _find_gladiator_by_id(loser_id)
	var injury_applied_days: int = 0
	if not winner.is_empty():
		winner["wins"] = int(winner.get("wins", 0)) + 1
	if not loser.is_empty():
		loser["losses"] = int(loser.get("losses", 0)) + 1
		if loser_dead:
			loser["alive"] = false
			loser["injured_days"] = 0
			add_recent_event("%s was slain in the arena." % get_gladiator_display_name(loser))
			append_campaign_log("%s - Death: %s was slain in the arena." % [format_phase_label(), get_gladiator_display_name(loser)])
		else:
			injury_applied_days = apply_injury_from_fight(loser_id, result)
	result["injury_applied_days"] = injury_applied_days

	var reward_summary: Dictionary = award_post_fight_rewards(winner_id, loser_id, result, active_event)
	result["reward_summary"] = reward_summary
	result["player_outcome"] = str(reward_summary.get("player_outcome", "UNKNOWN"))
	_consume_next_fight_flags()

	battle_history.append({
		"day": day,
		"winner_id": winner_id,
		"loser_id": loser_id,
		"turns": int(result.get("turns", 0)),
		"winner_remaining_hp": int(result.get("winner_remaining_hp", 0)),
		"loser_dead": loser_dead,
		"combat_log": result.get("combat_log", []),
	})
	add_recent_event("Combattimento concluso: %s ha sconfitto %s in %d turni." % [
		get_gladiator_display_name(winner) if not winner.is_empty() else winner_id,
		get_gladiator_display_name(loser) if not loser.is_empty() else loser_id,
		int(result.get("turns", 0)),
	])
	_add_player_outcome_event(winner_id, loser_id, loser_dead, reward_summary)
	append_campaign_log("%s - Fight result: %s defeated %s in %d turns (%s)." % [
		_format_fight_context_prefix(active_event),
		get_gladiator_display_name(winner) if not winner.is_empty() else winner_id,
		get_gladiator_display_name(loser) if not loser.is_empty() else loser_id,
		int(result.get("turns", 0)),
		str(result.get("player_outcome", "UNKNOWN")),
	])
	write_battle_report(result, active_event)
	if _event_type(active_event) == EVENT_TYPE_TOURNAMENT:
		var tournament_step: Dictionary = process_tournament_step(result)
		result["tournament_step"] = tournament_step
		if has_active_tournament() and not can_continue_active_tournament():
			invalidate_active_tournament("gladiator_unavailable")
	var keep_tournament_lock: bool = has_active_tournament() and can_continue_active_tournament()
	clear_active_encounter_state(keep_tournament_lock)
	check_end_conditions()

	save_game()
	roster_updated.emit()
	_emit_resources_updated()
	_emit_recent_events_updated()
	if game_state == STATE_RESOLVING_FIGHT:
		_set_game_state(STATE_RUNNING)
	fight_resolved.emit(result)

func check_end_conditions() -> void:
	if game_state == STATE_VICTORY or game_state == STATE_DEFEAT:
		return
	if not has_living_gladiators():
		_set_game_state(STATE_DEFEAT)
		add_recent_event("All your gladiators are dead.")
		append_campaign_log("%s - Campaign defeat: all gladiators are dead." % format_phase_label())
		append_campaign_log("=== CAMPAIGN END (%s): DEFEAT ===" % campaign_run_id)
		return
	var victory_status: Dictionary = _evaluate_campaign_victory_status()
	if bool(victory_status.get("achieved", false)):
		_set_game_state(STATE_VICTORY)
		add_recent_event("You survived all 30 Phases.")
		append_campaign_log("%s - Campaign victory achieved: %s" % [format_phase_label(), str(victory_status.get("reason", "unknown reason"))])
		append_campaign_log("=== CAMPAIGN END (%s): VICTORY ===" % campaign_run_id)

func _evaluate_campaign_victory_status() -> Dictionary:
	var turn_value: int = day
	var target_turn: int = maxi(1, campaign_length_turns)
	var mode: String = campaign_victory_mode
	if mode != STANDARD_CAMPAIGN_VICTORY_MODE and mode != ALTERNATE_VICTORY_MODE_TURN_OR_FAME:
		mode = STANDARD_CAMPAIGN_VICTORY_MODE
	var reached_turn_target: bool = turn_value >= target_turn
	if mode == STANDARD_CAMPAIGN_VICTORY_MODE:
		append_campaign_log("Campaign victory check: phase %d/%d, %s." % [turn_value, target_turn, "victory achieved" if reached_turn_target else "continue campaign"])
		append_campaign_log("Campaign victory check: alternate fame victory disabled in standard mode.")
		if reached_turn_target:
			return {"achieved": true, "reason": "reached final phase (%d/%d)." % [turn_value, target_turn]}
		return {"achieved": false}
	var fame_value: int = fame
	var reached_fame_target: bool = fame_value >= VICTORY_FAME_TARGET
	append_campaign_log("Campaign victory check: phase %d/%d, %s." % [turn_value, target_turn, "victory achieved" if reached_turn_target else "continue campaign"])
	append_campaign_log("Campaign victory check: fame target %d/%d, %s." % [fame_value, VICTORY_FAME_TARGET, "victory achieved" if reached_fame_target else "continue campaign"])
	if reached_turn_target:
		return {"achieved": true, "reason": "reached final phase (%d/%d)." % [turn_value, target_turn]}
	if reached_fame_target:
		return {"achieved": true, "reason": "reached fame target (%d/%d)." % [fame_value, VICTORY_FAME_TARGET]}
	return {"achieved": false}

func award_post_fight_rewards(winner_id: String, loser_id: String, result: Dictionary, event_data: Dictionary = {}) -> Dictionary:
	var player_id: String = str(result.get("player_gladiator_id", _resolve_player_gladiator_id(winner_id, loser_id)))
	var loser_dead: bool = bool(result.get("loser_dead", false))
	var winner_is_player: bool = winner_id != "" and winner_id == player_id
	var loser_is_player: bool = loser_id != "" and loser_id == player_id
	var gold_reward: int = 0
	var fame_reward: int = 0
	var player_outcome: String = "UNKNOWN"
	var effective_event: Dictionary = event_data if not event_data.is_empty() else _get_effective_fight_event()
	var event_type: String = _event_type(effective_event)
	var reward_multiplier: float = _safe_reward_multiplier(effective_event)

	if winner_is_player:
		gold_reward = int(round(float(REWARD_GOLD_VICTORY) * reward_multiplier))
		fame_reward = REWARD_FAME_PER_WIN
		if event_type == EVENT_TYPE_BEAST_FIGHT:
			fame_reward += EVENT_BEAST_FAME_BONUS
		player_outcome = "VICTORY"
	elif loser_is_player and not loser_dead:
		gold_reward = int(round(float(REWARD_GOLD_DEFEAT_SURVIVED) * reward_multiplier))
		player_outcome = "DEFEAT_SURVIVED"
	elif loser_is_player and loser_dead:
		player_outcome = "DEFEAT_KILLED"

	if winner_is_player and next_fight_bonus_fame > 0:
		fame_reward += next_fight_bonus_fame
		add_recent_event("Special stakes paid off: +%d bonus fame." % next_fight_bonus_fame)
	if winner_is_player and next_fight_bonus_gold > 0:
		gold_reward += next_fight_bonus_gold
		add_recent_event("Special stakes paid off: +%d bonus gold." % next_fight_bonus_gold)
	if winner_is_player and pending_wager_stake > 0:
		gold_reward += WAGER_PAYOUT_GOLD
		add_recent_event("Wager won! Payout +%d gold." % WAGER_PAYOUT_GOLD)
	elif loser_is_player and pending_wager_stake > 0:
		add_recent_event("Wager lost. Stake forfeited (%d gold)." % pending_wager_stake)

	gold += gold_reward
	fame += fame_reward
	var progression_summary: Dictionary = {}
	if winner_is_player and not _find_gladiator_by_id(winner_id).is_empty():
		progression_summary[winner_id] = {
			"xp_gained": REWARD_EXP_WINNER,
			"events": grant_experience(winner_id, REWARD_EXP_WINNER),
		}

	if loser_is_player and not _find_gladiator_by_id(loser_id).is_empty():
		var loser_xp: int = 0 if loser_dead else REWARD_EXP_SURVIVOR_LOSER
		progression_summary[loser_id] = {
			"xp_gained": loser_xp,
			"events": [] if loser_xp <= 0 else grant_experience(loser_id, loser_xp),
		}

	return {
		"gold": gold_reward,
		"fame": fame_reward,
		"player_outcome": player_outcome,
		"progression": progression_summary,
	}

func apply_daily_upkeep() -> void:
	var alive_count: int = 0
	for gladiator: Dictionary in roster:
		if bool(gladiator.get("alive", false)):
			alive_count += 1
	gold = maxi(0, gold - alive_count * DAILY_UPKEEP_PER_ALIVE)

func heal_and_update_injuries() -> void:
	for gladiator: Dictionary in roster:
		if not bool(gladiator.get("alive", true)):
			gladiator["injured_days"] = 0
			continue
		var current_injury_days: int = maxi(0, int(gladiator.get("injured_days", 0)))
		if current_injury_days > 0:
			current_injury_days -= 1
			gladiator["injured_days"] = current_injury_days
			if current_injury_days == 0:
				add_recent_event("%s ha recuperato dalle ferite." % get_gladiator_display_name(gladiator))

func get_gladiator_status(gladiator: Dictionary) -> String:
	if not bool(gladiator.get("alive", true)):
		return STATUS_DEAD
	if int(gladiator.get("injured_days", 0)) > 0:
		return STATUS_INJURED
	return STATUS_AVAILABLE

func get_gladiator_display_name(gladiator: Dictionary) -> String:
	return str(gladiator.get("nome", str(gladiator.get("id", "Unknown"))))

func required_exp_for_level(level: int) -> int:
	if level >= LEVEL_CAP:
		return 0
	return 10 + maxi(0, level - 1) * 5

func grant_experience(gladiator_id: String, amount: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if amount <= 0:
		return events
	var gladiator: Dictionary = _find_gladiator_by_id(gladiator_id)
	if gladiator.is_empty():
		push_warning("GameManager.grant_experience: gladiator not found for id=%s" % gladiator_id)
		return events
	if not bool(gladiator.get("alive", true)):
		return events
	gladiator["experience"] = maxi(0, int(gladiator.get("experience", 0)) + amount)
	gladiator["esperienza"] = int(gladiator.get("experience", 0))
	events = process_level_ups(gladiator)
	return events

func process_level_ups(gladiator: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if gladiator.is_empty() or not bool(gladiator.get("alive", true)):
		return events
	var current_level: int = clampi(int(gladiator.get("level", gladiator.get("livello", 1))), 1, LEVEL_CAP)
	var current_exp: int = maxi(0, int(gladiator.get("experience", gladiator.get("esperienza", 0))))
	while current_level < LEVEL_CAP:
		var needed_exp: int = required_exp_for_level(current_level)
		if current_exp < needed_exp:
			break
		current_exp -= needed_exp
		current_level += 1
		_apply_level_growth(gladiator, current_level)
		var message: String = "%s ha raggiunto il livello %d." % [get_gladiator_display_name(gladiator), current_level]
		add_recent_event(message)
		append_campaign_log("%s - Level up: %s reached level %d." % [format_phase_label(), get_gladiator_display_name(gladiator), current_level])
		events.append({
			"type": "LEVEL_UP",
			"message": message,
			"new_level": current_level,
		})
	gladiator["level"] = current_level
	gladiator["livello"] = current_level
	gladiator["experience"] = current_exp
	gladiator["esperienza"] = current_exp
	return events

func apply_injury_from_fight(gladiator_id: String, result: Dictionary) -> int:
	var gladiator: Dictionary = _find_gladiator_by_id(gladiator_id)
	if gladiator.is_empty() or not bool(gladiator.get("alive", true)):
		return 0
	var injury_days: int = INJURY_DAYS_STANDARD_LOSS
	var fight_turns: int = int(result.get("turns", 0))
	var winner_remaining_hp: int = int(result.get("winner_remaining_hp", 0))
	var seed_source: String = "injury-%s-%d-%d-%d" % [gladiator_id, day, fight_turns, winner_remaining_hp]
	var injury_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	injury_rng.seed = int(hash(seed_source))
	if fight_turns >= 14 or winner_remaining_hp <= 2 or _event_type(_get_effective_fight_event()) == EVENT_TYPE_BEAST_FIGHT:
		injury_days = injury_rng.randi_range(INJURY_DAYS_HEAVY_LOSS_MIN, INJURY_DAYS_HEAVY_LOSS_MAX)
	else:
		injury_days = injury_rng.randi_range(INJURY_DAYS_LIGHT_LOSS_MIN, INJURY_DAYS_LIGHT_LOSS_MAX)
	gladiator["injured_days"] = maxi(1, injury_days)
	add_recent_event("%s injured for %s." % [get_gladiator_display_name(gladiator), format_injury_duration_phrasing(injury_days)])
	return injury_days

func add_recent_event(event_text: String) -> void:
	var normalized: String = event_text.strip_edges()
	if normalized == "":
		return
	recent_events.append("%s - %s" % [format_phase_label(), normalized])
	while recent_events.size() > RECENT_EVENTS_MAX:
		recent_events.remove_at(0)

func ensure_log_directories() -> void:
	var root_error: int = DirAccess.make_dir_absolute(CAMPAIGN_RUNS_ROOT_DIR)
	if root_error != OK and root_error != ERR_ALREADY_EXISTS:
		push_warning("GameManager.ensure_log_directories: failed to create %s (error %d)." % [CAMPAIGN_RUNS_ROOT_DIR, root_error])
		return
	if campaign_run_id == "":
		return
	var run_error: int = DirAccess.make_dir_absolute(_campaign_run_dir_path())
	if run_error != OK and run_error != ERR_ALREADY_EXISTS:
		push_warning("GameManager.ensure_log_directories: failed to create %s (error %d)." % [_campaign_run_dir_path(), run_error])
		return
	var reports_error: int = DirAccess.make_dir_absolute(_campaign_fight_reports_dir_path())
	if reports_error != OK and reports_error != ERR_ALREADY_EXISTS:
		push_warning("GameManager.ensure_log_directories: failed to create %s (error %d)." % [_campaign_fight_reports_dir_path(), reports_error])

func append_campaign_log(message: String) -> void:
	var normalized: String = message.strip_edges()
	if normalized == "":
		return
	if campaign_run_id == "":
		campaign_run_id = _generate_campaign_run_id()
	ensure_log_directories()
	var file: FileAccess = null
	if FileAccess.file_exists(_campaign_log_path()):
		file = FileAccess.open(_campaign_log_path(), FileAccess.READ_WRITE)
	else:
		file = FileAccess.open(_campaign_log_path(), FileAccess.WRITE)
	if file == null:
		push_warning("GameManager.append_campaign_log: failed to open %s." % _campaign_log_path())
		return
	if file.get_length() > 0:
		file.seek_end()
	file.store_line(normalized)
	file.close()

func write_battle_report(result: Dictionary, event_data: Dictionary = {}) -> void:
	if campaign_run_id == "":
		campaign_run_id = _generate_campaign_run_id()
	ensure_log_directories()
	var payload: Dictionary = current_fight_payload.duplicate(true)
	var player_fighter: Dictionary = payload.get("fighter_a", {}) as Dictionary
	var enemy_fighter: Dictionary = payload.get("fighter_b", {}) as Dictionary
	var event_type: String = str(payload.get("event_type", _event_type(event_data)))
	var event_name: String = str(event_data.get("name", str(payload.get("encounter_label", "Arena Match"))))
	var battle_index: int = battle_history.size()
	var player_name_part: String = _sanitize_filename_component(get_gladiator_display_name(player_fighter))
	var enemy_name_part: String = _sanitize_filename_component(get_gladiator_display_name(enemy_fighter))
	var filename: String = "%s/day_%03d_fight_%03d_%s_vs_%s.txt" % [
		_campaign_fight_reports_dir_path(),
		day,
		battle_index,
		player_name_part,
		enemy_name_part,
	]
	var file: FileAccess = FileAccess.open(filename, FileAccess.WRITE)
	if file == null:
		push_warning("GameManager.write_battle_report: failed to open %s." % filename)
		return
	var lines: PackedStringArray = []
	lines.append("Phase: %d" % day)
	lines.append("Event Type: %s" % event_type)
	lines.append("Event Name: %s" % event_name)
	lines.append("Campaign Run ID: %s" % campaign_run_id)
	lines.append("Matchup Label: %s vs %s" % [
		str(payload.get("attacker_label", str(payload.get("attacker_build_id", "")))),
		str(payload.get("defender_label", str(payload.get("defender_build_id", "")))),
	])
	lines.append("Player Gladiator: id=%s, name=%s, class=%s, level=%d" % [
		str(player_fighter.get("id", "")),
		get_gladiator_display_name(player_fighter),
		str(player_fighter.get("class", "")),
		int(player_fighter.get("level", player_fighter.get("livello", 1))),
	])
	lines.append("Enemy: id=%s, name=%s, class=%s, level=%d" % [
		str(enemy_fighter.get("id", "")),
		get_gladiator_display_name(enemy_fighter),
		str(enemy_fighter.get("subtype", enemy_fighter.get("class", ""))),
		int(enemy_fighter.get("level", enemy_fighter.get("livello", 1))),
	])
	lines.append("Outcome: %s" % str(result.get("player_outcome", "UNKNOWN")))
	lines.append("Winner ID: %s" % str(result.get("winner_id", "")))
	lines.append("Loser ID: %s" % str(result.get("loser_id", "")))
	lines.append("Turns: %d" % int(result.get("turns", 0)))
	lines.append("Winner Remaining HP: %d" % int(result.get("winner_remaining_hp", 0)))
	lines.append("Loser Dead: %s" % str(bool(result.get("loser_dead", false))))
	var reward_summary: Dictionary = result.get("reward_summary", {}) as Dictionary
	var progression_summary: Dictionary = reward_summary.get("progression", {}) as Dictionary
	var player_id: String = str(payload.get("player_gladiator_id", str(result.get("player_gladiator_id", ""))))
	var player_progression: Dictionary = progression_summary.get(player_id, {}) as Dictionary
	lines.append("Gold Reward: %d" % int(reward_summary.get("gold", 0)))
	lines.append("Fame Reward: %d" % int(reward_summary.get("fame", 0)))
	lines.append("XP Reward Player: %d" % int(player_progression.get("xp_gained", 0)))
	lines.append("Injury Applied Phases: %d" % int(result.get("injury_applied_days", 0)))
	if event_type == EVENT_TYPE_TOURNAMENT:
		lines.append("Tournament Match Index: %d" % int(payload.get("tournament_match_index", 0)))
		lines.append("Tournament Total Matches: %d" % int(payload.get("tournament_total_matches", 0)))
	if event_type == EVENT_TYPE_BEAST_FIGHT:
		lines.append("Beast Subtype: %s" % str(enemy_fighter.get("subtype", "")))
	lines.append("")
	lines.append("Combat Log:")
	lines.append(_combat_log_to_text(result.get("combat_log", [])))
	file.store_string("\n".join(lines))
	file.close()

func _combat_log_to_text(raw_log: Variant) -> String:
	if typeof(raw_log) != TYPE_ARRAY:
		return "(combat log unavailable)"
	var log_lines: PackedStringArray = []
	var raw_entries: Array = raw_log as Array
	for entry: Variant in raw_entries:
		if typeof(entry) == TYPE_STRING:
			log_lines.append(str(entry))
		elif typeof(entry) == TYPE_DICTIONARY:
			var row: Dictionary = entry as Dictionary
			if row.has("text"):
				log_lines.append(str(row.get("text", "")))
			elif row.has("message"):
				log_lines.append(str(row.get("message", "")))
			else:
				log_lines.append(JSON.stringify(row))
		else:
			log_lines.append(str(entry))
	if log_lines.is_empty():
		return "(combat log empty)"
	return "\n".join(log_lines)

func _sanitize_filename_component(value: String) -> String:
	var normalized: String = value.strip_edges().to_lower().replace(" ", "_")
	var output: String = ""
	for i: int in range(normalized.length()):
		var ch: String = normalized.substr(i, 1)
		var code: int = ch.unicode_at(0)
		var is_lowercase: bool = code >= 97 and code <= 122
		var is_digit: bool = code >= 48 and code <= 57
		if is_lowercase or is_digit or ch == "_":
			output += ch
	if output == "":
		return "unknown"
	return output

func _sanitize_run_id(value: String) -> String:
	var normalized: String = value.strip_edges()
	var output: String = ""
	for i: int in range(normalized.length()):
		var ch: String = normalized.substr(i, 1)
		var code: int = ch.unicode_at(0)
		var is_lowercase: bool = code >= 97 and code <= 122
		var is_uppercase: bool = code >= 65 and code <= 90
		var is_digit: bool = code >= 48 and code <= 57
		if is_lowercase or is_uppercase or is_digit or ch == "_" or ch == "-":
			output += ch
	return output

func _bootstrap_content() -> void:
	if _content_registry != null and _stats_resolver != null:
		return
	var loader: ContentLoader = CONTENT_LOADER_SCRIPT.new()
	_content_registry = loader.load_all_definitions()
	_stats_resolver = BUILD_STATS_RESOLVER_SCRIPT.new()
	_stats_resolver.configure(_content_registry)

func _create_gladiator(gladiator_class: String) -> Dictionary:
	_bootstrap_content()
	var build_id: String = _build_id_for_class(gladiator_class)
	var base_stats: Dictionary = _stats_resolver.resolve_build_stats(build_id)
	var variation_seed: int = next_gladiator_index * 11 + day
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = variation_seed
	var hp_delta: int = rng.randi_range(-1, 1)
	var atk_delta: int = rng.randi_range(0, 1)
	var def_delta: int = rng.randi_range(0, 1)
	var gladiator_name: String = _build_gladiator_name(gladiator_class, next_gladiator_index)
	return {
		"id": "GLAD_%04d" % next_gladiator_index,
		"nome": gladiator_name,
		"class": gladiator_class,
		"level": 1,
		"experience": 0,
		"livello": 1,
		"esperienza": 0,
		"max_hp": maxi(1, int(base_stats.get("max_hp", 1)) + hp_delta),
		"atk": maxi(1, int(base_stats.get("atk", 1)) + atk_delta),
		"def": maxi(1, int(base_stats.get("def", 1)) + def_delta),
		"alive": true,
		"injured_days": 0,
		"wins": 0,
		"losses": 0,
	}

func _apply_level_growth(gladiator: Dictionary, reached_level: int) -> void:
	gladiator["max_hp"] = maxi(1, int(gladiator.get("max_hp", 1)) + 1)
	if reached_level == 2 or reached_level == 4:
		gladiator["atk"] = maxi(1, int(gladiator.get("atk", 1)) + 1)
	if reached_level == 3 or reached_level == 5:
		gladiator["def"] = maxi(1, int(gladiator.get("def", 1)) + 1)

func _build_gladiator_name(gladiator_class: String, gladiator_number: int) -> String:
	var class_label: String = "Retiarius" if gladiator_class == "RET" else "Secutor"
	return "%s %s" % [class_label, _to_roman(gladiator_number)]

func _build_enemy_name(gladiator_class: String, enemy_number: int) -> String:
	var class_label: String = "Retiarius" if gladiator_class == "RET" else "Secutor"
	return "Arena %s %s" % [class_label, _to_roman(enemy_number)]

func _build_beast_stats(beast_type: String, beast_level: int) -> Dictionary:
	var clamped_level: int = clampi(beast_level, 1, LEVEL_CAP)
	if beast_type == BEAST_TYPE_WOLF:
		return {
			"max_hp": 13 + clamped_level,
			"atk": 5 + clamped_level,
			"def": 2 + int(clamped_level / 2.0),
		}
	if beast_type == BEAST_TYPE_BOAR:
		return {
			"max_hp": 18 + clamped_level * 2,
			"atk": 5 + clamped_level,
			"def": 4 + int(clamped_level / 2.0),
		}
	return {
		"max_hp": 16 + clamped_level,
		"atk": 7 + clamped_level,
		"def": 4 + int(clamped_level / 2.0),
	}

func _beast_display_name(beast_type: String) -> String:
	if beast_type == BEAST_TYPE_WOLF:
		return "Wolf"
	if beast_type == BEAST_TYPE_BOAR:
		return "Boar"
	return "Lion"

func _to_roman(value: int) -> String:
	var numerals: Array[Dictionary] = [
		{"value": 1000, "symbol": "M"},
		{"value": 900, "symbol": "CM"},
		{"value": 500, "symbol": "D"},
		{"value": 400, "symbol": "CD"},
		{"value": 100, "symbol": "C"},
		{"value": 90, "symbol": "XC"},
		{"value": 50, "symbol": "L"},
		{"value": 40, "symbol": "XL"},
		{"value": 10, "symbol": "X"},
		{"value": 9, "symbol": "IX"},
		{"value": 5, "symbol": "V"},
		{"value": 4, "symbol": "IV"},
		{"value": 1, "symbol": "I"},
	]
	var remaining: int = maxi(1, value)
	var output: String = ""
	for entry: Dictionary in numerals:
		var unit_value: int = int(entry.get("value", 0))
		var symbol: String = str(entry.get("symbol", ""))
		while remaining >= unit_value:
			output += symbol
			remaining -= unit_value
	return output

func _recruit_cost_for_class(gladiator_class: String) -> int:
	if gladiator_class == "RET":
		return RECRUIT_COST_RET
	if gladiator_class == "SEC":
		return RECRUIT_COST_SEC
	return -1

func _build_id_for_class(gladiator_class: String) -> String:
	if gladiator_class == "RET":
		return RET_BUILD_ID
	if gladiator_class == "SEC":
		return SEC_BUILD_ID
	return RET_BUILD_ID

func _build_enemy_build_id(enemy_fighter: Dictionary) -> String:
	if bool(enemy_fighter.get("is_beast", false)):
		var subtype: String = str(enemy_fighter.get("subtype", BEAST_TYPE_WOLF))
		if subtype == BEAST_TYPE_LION:
			return SEC_BUILD_ID
		if subtype == BEAST_TYPE_BOAR:
			return RET_BUILD_ID
		return RET_BUILD_ID
	return _build_id_for_class(str(enemy_fighter.get("class", "")))

func _build_combatant_identity_label(fighter: Dictionary) -> String:
	if bool(fighter.get("is_beast", false)):
		return str(fighter.get("subtype", BEAST_TYPE_WOLF))
	var fighter_class: String = str(fighter.get("class", ""))
	return _build_id_for_class(fighter_class)

func _format_fight_context_prefix(event_data: Dictionary) -> String:
	var base: String = format_phase_label()
	var event_type: String = _event_type(event_data)
	if event_type == EVENT_TYPE_TOURNAMENT:
		var match_index: int = int(current_fight_payload.get("tournament_match_index", 0))
		var total_matches: int = int(current_fight_payload.get("tournament_total_matches", 0))
		if match_index > 0 and total_matches > 0:
			return "%s - Tournament fight %d/%d" % [base, match_index, total_matches]
	return base

func _campaign_run_dir_path() -> String:
	return "%s/%s" % [CAMPAIGN_RUNS_ROOT_DIR, campaign_run_id]

func _campaign_fight_reports_dir_path() -> String:
	return "%s/%s" % [_campaign_run_dir_path(), FIGHT_REPORTS_SUBDIR]

func _campaign_log_path() -> String:
	return "%s/campaign_log.txt" % _campaign_run_dir_path()

func _initialize_campaign_log() -> void:
	if campaign_run_id == "":
		return
	ensure_log_directories()
	var file: FileAccess = FileAccess.open(_campaign_log_path(), FileAccess.WRITE)
	if file == null:
		push_warning("GameManager._initialize_campaign_log: failed to open %s." % _campaign_log_path())
		return
	file.store_line("=== CAMPAIGN RUN START ===")
	file.store_line("Run ID: %s" % campaign_run_id)
	file.store_line("Started UTC: %s" % Time.get_datetime_string_from_system(true, true))
	file.store_line("")
	file.close()

func _generate_campaign_run_id() -> String:
	var datetime: Dictionary = Time.get_datetime_dict_from_system(true)
	return "%04d-%02d-%02d_%02d-%02d-%02d" % [
		int(datetime.get("year", 1970)),
		int(datetime.get("month", 1)),
		int(datetime.get("day", 1)),
		int(datetime.get("hour", 0)),
		int(datetime.get("minute", 0)),
		int(datetime.get("second", 0)),
	]

func _build_encounter_label(event_type: String, enemy_fighter: Dictionary) -> String:
	if event_type == EVENT_TYPE_TOURNAMENT:
		var match_number: int = int(active_tournament.get("current_match", 1))
		if match_number >= TOURNAMENT_MATCH_COUNT:
			return "%s - Final Games" % format_phase_label()
		return "%s - Tournament Match %d/%d" % [format_phase_label(), match_number, TOURNAMENT_MATCH_COUNT]
	if event_type == EVENT_TYPE_BEAST_FIGHT:
		var beast_subtype: String = str(enemy_fighter.get("subtype", BEAST_TYPE_WOLF))
		return "%s - Beast Hunt (%s)" % [format_phase_label(), _beast_display_name(beast_subtype)]
	return "%s - Arena Match" % format_phase_label()

func _build_match_seed(fighter_a: Dictionary, fighter_b: Dictionary) -> int:
	var id_a: String = str(fighter_a.get("id", "A"))
	var id_b: String = str(fighter_b.get("id", "B"))
	return int(hash("%s-%s-%d" % [id_a, id_b, day]))

func _result_has_required_fields(result: Dictionary) -> bool:
	return result.has("winner_id") and result.has("loser_id") and result.has("turns") and result.has("winner_remaining_hp") and result.has("combat_log")

func _roll_loser_death(winner_id: String, loser_id: String, result: Dictionary) -> bool:
	if winner_id == "" or loser_id == "":
		return false
	var seeded_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var seed_source: String = "%d-%d-%s-%s-%d" % [
		day,
		int(result.get("turns", 0)),
		winner_id,
		loser_id,
		int(result.get("winner_remaining_hp", 0)),
	]
	seeded_rng.seed = int(hash(seed_source))
	var risk_modifier: float = _safe_risk_modifier(_get_effective_fight_event())
	risk_modifier *= maxf(0.0, next_fight_risk_modifier_mult)
	if has_active_tournament() and int(active_tournament.get("current_match", 1)) >= TOURNAMENT_MATCH_COUNT:
		risk_modifier *= TOURNAMENT_FINAL_RISK_MULTIPLIER
	var final_death_chance: float = minf(LOSS_DEATH_CHANCE_MAX, LOSS_DEATH_CHANCE * risk_modifier)
	return seeded_rng.randf() < final_death_chance

func _resolve_player_gladiator_id(winner_id: String, loser_id: String) -> String:
	var winner_exists: bool = not _find_gladiator_by_id(winner_id).is_empty()
	var loser_exists: bool = not _find_gladiator_by_id(loser_id).is_empty()
	if winner_exists and not loser_exists:
		return winner_id
	if loser_exists and not winner_exists:
		return loser_id
	if selected_gladiator_id != "" and not _find_gladiator_by_id(selected_gladiator_id).is_empty():
		return selected_gladiator_id
	if winner_exists:
		return winner_id
	if loser_exists:
		return loser_id
	return ""

func _add_player_outcome_event(winner_id: String, loser_id: String, loser_dead: bool, reward_summary: Dictionary) -> void:
	var player_id: String = _resolve_player_gladiator_id(winner_id, loser_id)
	if player_id == "":
		return
	var player_gladiator: Dictionary = _find_gladiator_by_id(player_id)
	var player_name: String = get_gladiator_display_name(player_gladiator) if not player_gladiator.is_empty() else player_id
	if winner_id == player_id:
		add_recent_event("%s won the bout and earned %d gold." % [player_name, int(reward_summary.get("gold", 0))])
	elif loser_id == player_id and loser_dead:
		add_recent_event("%s was slain in the arena." % player_name)
	else:
		add_recent_event("%s was defeated but survived the arena." % player_name)

func _find_gladiator_by_id(gladiator_id: String) -> Dictionary:
	for gladiator: Dictionary in roster:
		if str(gladiator.get("id", "")) == gladiator_id:
			return gladiator
	return {}

func _apply_loaded_data(data: Dictionary) -> void:
	gold = int(data.get("gold", STARTING_GOLD))
	fame = int(data.get("fame", STARTING_FAME))
	day = int(data.get("turn", data.get("day", STARTING_DAY)))
	campaign_length_turns = maxi(1, int(data.get("campaign_length_turns", DEFAULT_CAMPAIGN_LENGTH_TURNS)))
	campaign_victory_mode = str(data.get("campaign_victory_mode", STANDARD_CAMPAIGN_VICTORY_MODE))
	next_gladiator_index = int(data.get("next_gladiator_index", 1))
	next_enemy_index = int(data.get("next_enemy_index", 1))
	selected_gladiator_id = str(data.get("selected_gladiator_id", ""))
	locked_tournament_gladiator_id = str(data.get("locked_tournament_gladiator_id", ""))
	roster = _sanitize_roster(data.get("roster", []))
	if not _find_gladiator_by_id(selected_gladiator_id).is_empty():
		var selected: Dictionary = _find_gladiator_by_id(selected_gladiator_id)
		if get_gladiator_status(selected) != STATUS_AVAILABLE:
			selected_gladiator_id = ""
	else:
		selected_gladiator_id = ""
	battle_history = _sanitize_battle_history(data.get("battle_history", []))
	recent_events = _sanitize_recent_events(data.get("recent_events", []))
	current_event = _sanitize_event(data.get("current_event", {}))
	current_narrative_event = _sanitize_narrative_event(data.get("current_narrative_event", {}))
	active_tournament = _sanitize_tournament_state(data.get("active_tournament", {}))
	next_fight_enemy_level_bonus = maxi(0, int(data.get("next_fight_enemy_level_bonus", 0)))
	next_fight_bonus_fame = maxi(0, int(data.get("next_fight_bonus_fame", 0)))
	next_fight_bonus_gold = maxi(0, int(data.get("next_fight_bonus_gold", 0)))
	next_fight_risk_modifier_mult = _sanitize_multiplier(data.get("next_fight_risk_modifier_mult", 1.0), 1.0)
	pending_wager_stake = maxi(0, int(data.get("pending_wager_stake", 0)))
	campaign_run_id = _sanitize_run_id(str(data.get("campaign_run_id", "")))
	if campaign_run_id == "":
		campaign_run_id = _generate_campaign_run_id()
		_initialize_campaign_log()
	else:
		ensure_log_directories()
	if has_active_tournament() and locked_tournament_gladiator_id == "":
		locked_tournament_gladiator_id = str(active_tournament.get("gladiator_id", ""))
	if has_active_tournament() and not can_continue_active_tournament():
		invalidate_active_tournament("inconsistent_state")
	clear_active_encounter_state(has_active_tournament())
	game_state = _sanitize_game_state(data.get("game_state", STATE_RUNNING))
	if current_event.is_empty():
		current_event = generate_daily_event()

func _sanitize_game_state(raw_value: Variant) -> String:
	var state: String = str(raw_value).to_lower()
	if state == STATE_RUNNING or state == STATE_VICTORY or state == STATE_DEFEAT:
		return state
	if state == STATE_IDLE or state == STATE_PREPARING_FIGHT or state == STATE_IN_FIGHT or state == STATE_RESOLVING_FIGHT:
		return STATE_RUNNING
	return STATE_RUNNING

func _sanitize_roster(raw_value: Variant) -> Array[Dictionary]:
	var sanitized: Array[Dictionary] = []
	if typeof(raw_value) != TYPE_ARRAY:
		return sanitized
	var raw_array: Array = raw_value as Array
	for item: Variant in raw_array:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var source: Dictionary = item as Dictionary
		var level_value: int = clampi(int(source.get("level", source.get("livello", 1))), 1, LEVEL_CAP)
		var experience_value: int = maxi(0, int(source.get("experience", source.get("esperienza", 0))) )
		var alive_value: bool = bool(source.get("alive", true))
		var injured_days_value: int = maxi(0, int(source.get("injured_days", 0)))
		if not alive_value:
			injured_days_value = 0
		sanitized.append({
			"id": str(source.get("id", "")),
			"nome": str(source.get("nome", "Unknown")),
			"class": str(source.get("class", "RET")),
			"level": level_value,
			"experience": experience_value,
			"livello": level_value,
			"esperienza": experience_value,
			"max_hp": maxi(1, int(source.get("max_hp", 1))),
			"atk": maxi(1, int(source.get("atk", 1))),
			"def": maxi(1, int(source.get("def", 1))),
			"alive": alive_value,
			"injured_days": injured_days_value,
			"wins": maxi(0, int(source.get("wins", 0))),
			"losses": maxi(0, int(source.get("losses", 0))),
		})
	return sanitized

func _sanitize_battle_history(raw_value: Variant) -> Array[Dictionary]:
	var sanitized: Array[Dictionary] = []
	if typeof(raw_value) != TYPE_ARRAY:
		return sanitized
	var raw_array: Array = raw_value as Array
	for item: Variant in raw_array:
		if typeof(item) == TYPE_DICTIONARY:
			sanitized.append((item as Dictionary).duplicate(true))
	return sanitized

func _sanitize_recent_events(raw_value: Variant) -> Array[String]:
	var sanitized: Array[String] = []
	if typeof(raw_value) != TYPE_ARRAY:
		return sanitized
	var raw_array: Array = raw_value as Array
	for item: Variant in raw_array:
		sanitized.append(str(item))
	while sanitized.size() > RECENT_EVENTS_MAX:
		sanitized.remove_at(0)
	return sanitized

func _build_fight_event() -> Dictionary:
	return {
		"type": EVENT_TYPE_FIGHT,
		"name": "Arena Match",
		"description": "A standard arena phase with balanced rewards and danger.",
		"reward_multiplier": EVENT_FIGHT_REWARD_MULTIPLIER,
		"risk_modifier": EVENT_FIGHT_RISK_MODIFIER,
	}

func _build_hard_fight_event() -> Dictionary:
	return {
		"type": EVENT_TYPE_HARD_FIGHT,
		"name": "Bloodstakes Clash",
		"description": "A more dangerous arena card with higher rewards and lethal risk.",
		"reward_multiplier": EVENT_HARD_FIGHT_REWARD_MULTIPLIER,
		"risk_modifier": EVENT_HARD_FIGHT_RISK_MODIFIER,
	}

func _build_rest_event() -> Dictionary:
	return {
		"type": EVENT_TYPE_REST,
		"name": "Closed Gates",
		"description": "The arena is closed this phase. Your gladiators recover.",
		"reward_multiplier": EVENT_REST_REWARD_MULTIPLIER,
		"risk_modifier": EVENT_REST_RISK_MODIFIER,
	}

func _build_tournament_event() -> Dictionary:
	return {
		"type": EVENT_TYPE_TOURNAMENT,
		"name": "Tournament of the Arena",
		"description": "Two consecutive matches with no recovery between rounds.",
		"reward_multiplier": EVENT_TOURNAMENT_REWARD_MULTIPLIER,
		"risk_modifier": EVENT_TOURNAMENT_RISK_MODIFIER,
	}

func _build_beast_fight_event() -> Dictionary:
	return {
		"type": EVENT_TYPE_BEAST_FIGHT,
		"name": "Beast Hunt",
		"description": "Dangerous animal encounter with high reward and risk.",
		"reward_multiplier": EVENT_BEAST_REWARD_MULTIPLIER,
		"risk_modifier": EVENT_BEAST_RISK_MODIFIER,
	}

func _sanitize_event(raw_event: Variant) -> Dictionary:
	if typeof(raw_event) != TYPE_DICTIONARY:
		return {}
	var source: Dictionary = raw_event as Dictionary
	var event_type: String = str(source.get("type", EVENT_TYPE_FIGHT)).to_upper()
	if event_type != EVENT_TYPE_FIGHT and event_type != EVENT_TYPE_HARD_FIGHT and event_type != EVENT_TYPE_REST and event_type != EVENT_TYPE_TOURNAMENT and event_type != EVENT_TYPE_BEAST_FIGHT:
		event_type = EVENT_TYPE_FIGHT
	var fallback: Dictionary = _build_fight_event()
	if event_type == EVENT_TYPE_HARD_FIGHT:
		fallback = _build_hard_fight_event()
	elif event_type == EVENT_TYPE_REST:
		fallback = _build_rest_event()
	elif event_type == EVENT_TYPE_TOURNAMENT:
		fallback = _build_tournament_event()
	elif event_type == EVENT_TYPE_BEAST_FIGHT:
		fallback = _build_beast_fight_event()
	return {
		"type": event_type,
		"name": str(source.get("name", str(fallback.get("name", "")))),
		"description": str(source.get("description", str(fallback.get("description", "")))),
		"reward_multiplier": _sanitize_multiplier(source.get("reward_multiplier", fallback.get("reward_multiplier", 1.0)), float(fallback.get("reward_multiplier", 1.0))),
		"risk_modifier": _sanitize_multiplier(source.get("risk_modifier", fallback.get("risk_modifier", 1.0)), float(fallback.get("risk_modifier", 1.0))),
	}

func _sanitize_tournament_state(raw_value: Variant) -> Dictionary:
	if typeof(raw_value) != TYPE_DICTIONARY:
		return {}
	var source: Dictionary = raw_value as Dictionary
	var gladiator_id: String = str(source.get("gladiator_id", ""))
	if gladiator_id == "":
		return {}
	var selected: Dictionary = _find_gladiator_by_id(gladiator_id)
	if selected.is_empty():
		return {}
	var total_matches: int = int(source.get("total_matches", TOURNAMENT_MATCH_COUNT))
	var current_match: int = int(source.get("current_match", 1))
	if total_matches <= 0 or current_match < 1 or current_match > total_matches:
		return {}
	return {
		"gladiator_id": gladiator_id,
		"current_match": current_match,
		"total_matches": total_matches,
		"wins": maxi(0, int(source.get("wins", 0))),
		"carry_over_hp": maxi(0, int(source.get("carry_over_hp", int(selected.get("max_hp", 1))))),
	}

func _build_doctor_visit_event() -> Dictionary:
	return {
		"id": NARRATIVE_EVENT_DOCTOR_VISIT,
		"title": "A Physician Offers His Services",
		"description": "A physician offers targeted treatment for your worst injury case.",
		"choices": [
			{"id": "PAY", "text": "Pay 10 gold to treat one injured gladiator (-3 injury phases)"},
			{"id": "REFUSE", "text": "Refuse the physician"},
		],
	}

func _build_crowd_favor_event() -> Dictionary:
	return {
		"id": NARRATIVE_EVENT_CROWD_FAVOR,
		"title": "The Crowd Hungers for Spectacle",
		"description": "The crowd demands a short exhibition before the official fights begin.",
		"choices": [
			{"id": "EXHIBITION", "text": "Stage an exhibition (-5 gold, +3 fame now, next-fight bonuses)"},
			{"id": "SAVE", "text": "Refuse the request (-2 fame)"},
		],
	}

func _build_harsh_training_event() -> Dictionary:
	return {
		"id": NARRATIVE_EVENT_HARSH_TRAINING,
		"title": "A Brutal Training Regimen",
		"description": "Your trainers propose a punishing routine to force rapid improvement.",
		"choices": [
			{"id": "PUSH", "text": "Push the men harder (+3 XP to one available gladiator, 25% chance of +1 injury phase)"},
			{"id": "NORMAL", "text": "Keep training normal (no effect)"},
		],
	}

func _build_rivalry_event() -> Dictionary:
	return {
		"id": NARRATIVE_EVENT_RIVALRY,
		"title": "A Rivalry Ignites",
		"description": "A loudmouthed rival challenges your school. The crowd expects blood.",
		"choices": [
			{"id": "ACCEPT", "text": "Accept the rivalry bout (next fight harder, +4 fame if won)"},
			{"id": "IGNORE", "text": "Ignore the provocation (no effect)"},
		],
	}

func _build_ambitious_gladiator_event() -> Dictionary:
	return {
		"id": NARRATIVE_EVENT_AMBITIOUS_GLADIATOR,
		"title": "An Ambitious Gladiator Pleads",
		"description": "An injured gladiator asks to return early to prove worth.",
		"choices": [
			{"id": "ALLOW", "text": "Allow an early return (-2 injury phases, next fight riskier)"},
			{"id": "DENY", "text": "Refuse and keep recovery plan"},
		],
	}

func _build_patron_offer_event() -> Dictionary:
	return {
		"id": NARRATIVE_EVENT_PATRON_OFFER,
		"title": "A Patron's Offer",
		"description": "A wealthy patron offers immediate coin in exchange for a tougher upcoming match.",
		"choices": [
			{"id": "ACCEPT", "text": "Accept (+20 gold now, next fight harder)"},
			{"id": "REFUSE", "text": "Refuse politely (no effect)"},
		],
	}

func _build_specialized_training_event() -> Dictionary:
	return {
		"id": NARRATIVE_EVENT_SPECIALIZED_TRAINING,
		"title": "Specialized Drills",
		"description": "A coach can sharpen offense at the expense of defense, or vice versa.",
		"choices": [
			{"id": "ATK_UP", "text": "Offensive focus (+1 ATK, -1 DEF)"},
			{"id": "DEF_UP", "text": "Defensive focus (+1 DEF, -1 ATK)"},
			{"id": "SKIP", "text": "Skip specialized training"},
		],
	}

func _build_wager_event() -> Dictionary:
	return {
		"id": NARRATIVE_EVENT_WAGER,
		"title": "Bookmaker's Wager",
		"description": "A bookmaker offers odds on your next fight.",
		"choices": [
			{"id": "BET", "text": "Place a 10 gold wager (win next fight: +25 gold payout)"},
			{"id": "PASS", "text": "No bet this time"},
		],
	}

func _sanitize_narrative_event(raw_event: Variant) -> Dictionary:
	if typeof(raw_event) != TYPE_DICTIONARY:
		return {}
	var source: Dictionary = raw_event as Dictionary
	var event_id: String = str(source.get("id", "")).strip_edges()
	var fallback: Dictionary = {}
	if event_id == NARRATIVE_EVENT_DOCTOR_VISIT:
		fallback = _build_doctor_visit_event()
	elif event_id == NARRATIVE_EVENT_CROWD_FAVOR:
		fallback = _build_crowd_favor_event()
	elif event_id == NARRATIVE_EVENT_HARSH_TRAINING:
		fallback = _build_harsh_training_event()
	elif event_id == NARRATIVE_EVENT_RIVALRY:
		fallback = _build_rivalry_event()
	elif event_id == NARRATIVE_EVENT_AMBITIOUS_GLADIATOR:
		fallback = _build_ambitious_gladiator_event()
	elif event_id == NARRATIVE_EVENT_PATRON_OFFER:
		fallback = _build_patron_offer_event()
	elif event_id == NARRATIVE_EVENT_SPECIALIZED_TRAINING:
		fallback = _build_specialized_training_event()
	elif event_id == NARRATIVE_EVENT_WAGER:
		fallback = _build_wager_event()
	else:
		return {}
	var raw_choices: Variant = source.get("choices", fallback.get("choices", []))
	if typeof(raw_choices) != TYPE_ARRAY:
		raw_choices = fallback.get("choices", [])
	var choices: Array[Dictionary] = []
	for item: Variant in raw_choices:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = item as Dictionary
		var choice_id: String = str(choice.get("id", "")).strip_edges()
		var choice_text: String = str(choice.get("text", "")).strip_edges()
		if choice_id == "" or choice_text == "":
			continue
		choices.append({"id": choice_id, "text": choice_text})
	if choices.is_empty():
		var fallback_choices_raw: Variant = fallback.get("choices", [])
		if typeof(fallback_choices_raw) == TYPE_ARRAY:
			var fallback_choices: Array = fallback_choices_raw as Array
			for item: Variant in fallback_choices:
				if typeof(item) != TYPE_DICTIONARY:
					continue
				choices.append((item as Dictionary).duplicate(true))
	return {
		"id": event_id,
		"title": str(source.get("title", str(fallback.get("title", "Narrative Event")))),
		"description": str(source.get("description", str(fallback.get("description", "")))),
		"choices": choices,
	}

func _choice_exists(event_data: Dictionary, choice_id: String) -> bool:
	var choices: Variant = event_data.get("choices", [])
	if typeof(choices) != TYPE_ARRAY:
		return false
	for item: Variant in choices:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = item as Dictionary
		if str(choice.get("id", "")) == choice_id:
			return true
	return false

func _resolve_doctor_visit_choice(choice_id: String) -> String:
	if choice_id == "REFUSE":
		return "You refused the physician."
	if choice_id != "PAY":
		return "Nothing changes."
	if gold < DOCTOR_VISIT_COST_GOLD:
		return ""
	var target: Dictionary = _most_injured_gladiator()
	if target.is_empty():
		return ""
	gold -= DOCTOR_VISIT_COST_GOLD
	var before_days: int = maxi(0, int(target.get("injured_days", 0)))
	target["injured_days"] = maxi(0, before_days - DOCTOR_HEAL_AMOUNT_DAYS)
	return "You paid the physician. %s was treated (%d -> %d injury phases, -%d)." % [get_gladiator_display_name(target), before_days, int(target.get("injured_days", 0)), DOCTOR_HEAL_AMOUNT_DAYS]

func _resolve_crowd_favor_choice(choice_id: String) -> String:
	if choice_id == "SAVE":
		fame = maxi(0, fame - CROWD_FAVOR_REFUSE_FAME_PENALTY)
		return "You refused the crowd's request. Crowd mood sours (-%d fame)." % CROWD_FAVOR_REFUSE_FAME_PENALTY
	if choice_id != "EXHIBITION":
		return "Nothing changes."
	if gold < CROWD_FAVOR_COST_GOLD:
		return ""
	gold -= CROWD_FAVOR_COST_GOLD
	fame += CROWD_FAVOR_FAME_REWARD
	next_fight_bonus_fame += CROWD_FAVOR_NEXT_FIGHT_FAME_BONUS
	next_fight_bonus_gold += CROWD_FAVOR_NEXT_FIGHT_GOLD_BONUS
	return "You staged a flashy exhibition (+%d fame now). Next fight gains +%d fame and +%d gold if won." % [CROWD_FAVOR_FAME_REWARD, CROWD_FAVOR_NEXT_FIGHT_FAME_BONUS, CROWD_FAVOR_NEXT_FIGHT_GOLD_BONUS]

func _resolve_harsh_training_choice(choice_id: String) -> String:
	if choice_id == "NORMAL":
		return "You keep training steady and avoid unnecessary risk."
	if choice_id != "PUSH":
		return "Nothing changes."
	var candidates: Array[Dictionary] = []
	for gladiator: Dictionary in roster:
		if get_gladiator_status(gladiator) == STATUS_AVAILABLE:
			candidates.append(gladiator)
	if candidates.is_empty():
		return "No gladiator was fit for brutal training."
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(hash("harsh-training-%d-%d-%d" % [day, roster.size(), next_enemy_index]))
	var selected_index: int = rng.randi_range(0, candidates.size() - 1)
	var target: Dictionary = candidates[selected_index]
	grant_experience(str(target.get("id", "")), HARSH_TRAINING_XP_REWARD)
	var injury_applied: bool = false
	if rng.randf() < HARSH_TRAINING_INJURY_CHANCE:
		target["injured_days"] = maxi(1, int(target.get("injured_days", 0)) + 1)
		injury_applied = true
	if injury_applied:
		return "Harsh training improved %s, but left them battered (+3 XP, +1 injury phase)." % get_gladiator_display_name(target)
	return "Harsh training improved %s (+3 XP, no injury)." % get_gladiator_display_name(target)

func _resolve_rivalry_choice(choice_id: String) -> String:
	if choice_id == "IGNORE":
		return "You ignored the rival's challenge."
	if choice_id != "ACCEPT":
		return "Nothing changes."
	next_fight_enemy_level_bonus += RIVALRY_NEXT_FIGHT_LEVEL_BONUS
	next_fight_bonus_fame += RIVALRY_FAME_WIN_BONUS
	return "Rivalry accepted: next fight enemy +%d level, and +%d fame if you win." % [RIVALRY_NEXT_FIGHT_LEVEL_BONUS, RIVALRY_FAME_WIN_BONUS]

func _resolve_ambitious_gladiator_choice(choice_id: String) -> String:
	if choice_id == "DENY":
		return "You refused. The injured gladiator remains sidelined."
	if choice_id != "ALLOW":
		return "Nothing changes."
	var target: Dictionary = _most_injured_gladiator()
	if target.is_empty():
		return ""
	var before_days: int = int(target.get("injured_days", 0))
	target["injured_days"] = maxi(0, before_days - 2)
	next_fight_risk_modifier_mult = maxf(next_fight_risk_modifier_mult, 1.2)
	return "%s returns earlier (%d -> %d injury phases). Next fight is riskier." % [get_gladiator_display_name(target), before_days, int(target.get("injured_days", 0))]

func _resolve_patron_offer_choice(choice_id: String) -> String:
	if choice_id == "REFUSE":
		return "You declined the patron's conditions."
	if choice_id != "ACCEPT":
		return "Nothing changes."
	gold += PATRON_OFFER_GOLD_REWARD
	next_fight_enemy_level_bonus += PATRON_NEXT_FIGHT_LEVEL_BONUS
	return "You accepted the patron deal (+%d gold). Next fight enemy +%d level." % [PATRON_OFFER_GOLD_REWARD, PATRON_NEXT_FIGHT_LEVEL_BONUS]

func _resolve_specialized_training_choice(choice_id: String) -> String:
	if choice_id == "SKIP":
		return "You skipped specialized drills."
	var target: Dictionary = _first_available_gladiator()
	if target.is_empty():
		return "No available gladiator for specialized drills."
	if choice_id == "ATK_UP":
		target["atk"] = maxi(1, int(target.get("atk", 1)) + 1)
		target["def"] = maxi(1, int(target.get("def", 1)) - 1)
		return "%s completed offensive drills (+1 ATK, -1 DEF)." % get_gladiator_display_name(target)
	if choice_id == "DEF_UP":
		target["def"] = maxi(1, int(target.get("def", 1)) + 1)
		target["atk"] = maxi(1, int(target.get("atk", 1)) - 1)
		return "%s completed defensive drills (+1 DEF, -1 ATK)." % get_gladiator_display_name(target)
	return "Nothing changes."

func _resolve_wager_choice(choice_id: String) -> String:
	if choice_id == "PASS":
		return "You pass on the wager."
	if choice_id != "BET":
		return "Nothing changes."
	if pending_wager_stake > 0 or gold < WAGER_STAKE_GOLD:
		return ""
	gold -= WAGER_STAKE_GOLD
	pending_wager_stake = WAGER_STAKE_GOLD
	return "Wager placed: -%d gold now, +%d payout on next victory." % [WAGER_STAKE_GOLD, WAGER_PAYOUT_GOLD]

func _most_injured_gladiator() -> Dictionary:
	var target: Dictionary = {}
	var max_days: int = 0
	for gladiator: Dictionary in roster:
		if not bool(gladiator.get("alive", true)):
			continue
		var days: int = maxi(0, int(gladiator.get("injured_days", 0)))
		if days <= 0:
			continue
		if days > max_days:
			max_days = days
			target = gladiator
	return target

func _first_available_gladiator() -> Dictionary:
	for gladiator: Dictionary in roster:
		if get_gladiator_status(gladiator) == STATUS_AVAILABLE:
			return gladiator
	return {}

func _consume_next_fight_flags() -> void:
	next_fight_enemy_level_bonus = 0
	next_fight_bonus_fame = 0
	next_fight_bonus_gold = 0
	next_fight_risk_modifier_mult = 1.0
	pending_wager_stake = 0

func _sanitize_multiplier(value: Variant, fallback: float) -> float:
	var parsed: float = float(value)
	if is_nan(parsed) or is_inf(parsed) or parsed < 0.0:
		return fallback
	return parsed

func _event_type(event_data: Dictionary) -> String:
	return str(event_data.get("type", EVENT_TYPE_FIGHT)).to_upper()

func _get_effective_fight_event() -> Dictionary:
	if has_active_tournament():
		return _build_tournament_event()
	return get_current_event()

func clear_active_encounter_state(keep_tournament_lock: bool = false) -> void:
	current_fight_payload = {}
	active_encounter = {}
	pending_match = {}
	fight_in_progress = false
	if not keep_tournament_lock:
		locked_tournament_gladiator_id = ""
		if _event_type(current_event) == EVENT_TYPE_TOURNAMENT:
			current_event = _build_fight_event()

func _is_rest_event(event_data: Dictionary) -> bool:
	return _event_type(event_data) == EVENT_TYPE_REST

func _safe_reward_multiplier(event_data: Dictionary) -> float:
	var reward_multiplier: float = _sanitize_multiplier(event_data.get("reward_multiplier", 1.0), 1.0)
	return reward_multiplier

func _safe_risk_modifier(event_data: Dictionary) -> float:
	return _sanitize_multiplier(event_data.get("risk_modifier", 1.0), 1.0)

func apply_rest_day_recovery_bonus() -> void:
	for gladiator: Dictionary in roster:
		if not bool(gladiator.get("alive", true)):
			continue
		var current_injury_days: int = maxi(0, int(gladiator.get("injured_days", 0)))
		if current_injury_days <= 0:
			continue
		current_injury_days -= 1
		gladiator["injured_days"] = current_injury_days
		if current_injury_days == 0:
			add_recent_event("%s fully recovered during the arena rest phase." % get_gladiator_display_name(gladiator))

func _set_game_state(new_state: String) -> void:
	if game_state == new_state:
		return
	game_state = new_state
	game_state_changed.emit(game_state)

func _emit_resources_updated() -> void:
	resources_updated.emit(gold, fame, day)

func _emit_recent_events_updated() -> void:
	recent_events_updated.emit(get_recent_events())

func _emit_daily_event_updated() -> void:
	daily_event_updated.emit(get_current_event())

func _emit_narrative_event_updated() -> void:
	narrative_event_updated.emit(get_current_narrative_event())
