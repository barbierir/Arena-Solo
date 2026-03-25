extends Node

signal game_state_changed(new_state: String)
signal roster_updated()
signal resources_updated(gold: int, fame: int, day: int)
signal fight_started(payload: Dictionary)
signal fight_resolved(result: Dictionary)
signal save_completed(success: bool)
signal recent_events_updated(events: Array[String])

const SAVE_PATH: String = "user://savegame.json"

const STATE_IDLE: String = "idle"
const STATE_PREPARING_FIGHT: String = "preparing_fight"
const STATE_IN_FIGHT: String = "in_fight"
const STATE_RESOLVING_FIGHT: String = "resolving_fight"

const STARTING_GOLD: int = 100
const STARTING_FAME: int = 0
const STARTING_DAY: int = 1

const RECRUIT_COST_RET: int = 30
const RECRUIT_COST_SEC: int = 30
const DAILY_UPKEEP_PER_ALIVE: int = 2

const REWARD_GOLD_PER_FIGHT: int = 20
const REWARD_FAME_PER_WIN: int = 5
const REWARD_EXP_WINNER: int = 10
const REWARD_EXP_SURVIVOR_LOSER: int = 3

const INJURY_DAYS_STANDARD_LOSS: int = 2
const INJURY_DAYS_SEVERE_LOSS: int = 3

const LEVEL_CAP: int = 5
const RECENT_EVENTS_MAX: int = 10

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
var roster: Array[Dictionary] = []
var battle_history: Array[Dictionary] = []
var recent_events: Array[String] = []
var game_state: String = STATE_IDLE

var _content_registry: ContentRegistry
var _stats_resolver: BuildStatsResolver

func _ready() -> void:
	_bootstrap_content()

func new_game() -> void:
	gold = STARTING_GOLD
	fame = STARTING_FAME
	day = STARTING_DAY
	next_gladiator_index = 1
	roster.clear()
	battle_history.clear()
	recent_events.clear()
	_set_game_state(STATE_IDLE)
	recruit_gladiator("RET")
	recruit_gladiator("SEC")
	add_recent_event("Nuova campagna avviata (giorno %d)." % day)
	var saved: bool = save_game()
	save_completed.emit(saved)
	roster_updated.emit()
	_emit_resources_updated()
	_emit_recent_events_updated()

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
	_set_game_state(str(data.get("game_state", STATE_IDLE)))
	roster_updated.emit()
	_emit_resources_updated()
	_emit_recent_events_updated()
	return true

func save_game() -> bool:
	var payload: Dictionary = {
		"gold": gold,
		"fame": fame,
		"day": day,
		"next_gladiator_index": next_gladiator_index,
		"game_state": game_state,
		"roster": roster,
		"battle_history": battle_history,
		"recent_events": recent_events,
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

func advance_day() -> void:
	day += 1
	heal_and_update_injuries()
	apply_daily_upkeep()
	save_game()
	roster_updated.emit()
	_emit_resources_updated()
	_emit_recent_events_updated()

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

func recruit_gladiator(gladiator_class: String) -> Dictionary:
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
	save_game()
	roster_updated.emit()
	_emit_resources_updated()
	return gladiator.duplicate(true)

func can_start_fight() -> bool:
	return get_available_gladiators().size() >= 2

func start_next_fight() -> Dictionary:
	if not can_start_fight():
		return {"error": "Not enough available gladiators"}

	var pair: Array[Dictionary] = _select_match_pair()
	if pair.size() < 2:
		return {"error": "No valid match pair found"}

	var fighter_a: Dictionary = pair[0]
	var fighter_b: Dictionary = pair[1]
	_set_game_state(STATE_PREPARING_FIGHT)
	var payload: Dictionary = {
		"day": day,
		"seed": _build_match_seed(fighter_a, fighter_b),
		"fighter_a": fighter_a,
		"fighter_b": fighter_b,
		"attacker_build_id": _build_id_for_class(str(fighter_a.get("class", ""))),
		"defender_build_id": _build_id_for_class(str(fighter_b.get("class", ""))),
	}
	fight_started.emit(payload)
	_set_game_state(STATE_IN_FIGHT)
	return payload

func abort_active_fight(reason: String = "") -> void:
	if game_state == STATE_IDLE:
		return
	if reason != "":
		push_warning("GameManager.abort_active_fight called: %s" % reason)
	_set_game_state(STATE_IDLE)

func resolve_fight(result: Dictionary) -> void:
	if not _result_has_required_fields(result):
		push_error("GameManager.resolve_fight: incomplete result payload: %s" % JSON.stringify(result))
		_set_game_state(STATE_IDLE)
		return

	_set_game_state(STATE_RESOLVING_FIGHT)
	var winner_id: String = str(result.get("winner_id", ""))
	var loser_id: String = str(result.get("loser_id", ""))
	var loser_dead: bool = bool(result.get("loser_dead", false))

	var winner: Dictionary = _find_gladiator_by_id(winner_id)
	var loser: Dictionary = _find_gladiator_by_id(loser_id)
	if not winner.is_empty():
		winner["wins"] = int(winner.get("wins", 0)) + 1
	if not loser.is_empty():
		loser["losses"] = int(loser.get("losses", 0)) + 1
		if loser_dead:
			loser["alive"] = false
			loser["injured_days"] = 0
			add_recent_event("%s e' MORTO in arena." % get_gladiator_display_name(loser))
		else:
			apply_injury_from_fight(loser_id, result)

	var reward_summary: Dictionary = award_post_fight_rewards(winner_id, loser_id, result)
	result["reward_summary"] = reward_summary

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

	save_game()
	roster_updated.emit()
	_emit_resources_updated()
	_emit_recent_events_updated()
	fight_resolved.emit(result)
	_set_game_state(STATE_IDLE)

func award_post_fight_rewards(winner_id: String, loser_id: String, result: Dictionary) -> Dictionary:
	gold += REWARD_GOLD_PER_FIGHT
	fame += REWARD_FAME_PER_WIN

	var progression_summary: Dictionary = {}
	progression_summary[winner_id] = {
		"xp_gained": REWARD_EXP_WINNER,
		"events": grant_experience(winner_id, REWARD_EXP_WINNER),
	}

	var loser_dead: bool = bool(result.get("loser_dead", false))
	if loser_dead:
		progression_summary[loser_id] = {
			"xp_gained": 0,
			"events": [],
		}
	else:
		progression_summary[loser_id] = {
			"xp_gained": REWARD_EXP_SURVIVOR_LOSER,
			"events": grant_experience(loser_id, REWARD_EXP_SURVIVOR_LOSER),
		}

	return {
		"gold": REWARD_GOLD_PER_FIGHT,
		"fame": REWARD_FAME_PER_WIN,
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

func apply_injury_from_fight(gladiator_id: String, result: Dictionary) -> void:
	var gladiator: Dictionary = _find_gladiator_by_id(gladiator_id)
	if gladiator.is_empty() or not bool(gladiator.get("alive", true)):
		return
	var injury_days: int = INJURY_DAYS_STANDARD_LOSS
	var fight_turns: int = int(result.get("turns", 0))
	var winner_remaining_hp: int = int(result.get("winner_remaining_hp", 0))
	if fight_turns >= 14 or winner_remaining_hp <= 2:
		injury_days = INJURY_DAYS_SEVERE_LOSS
	gladiator["injured_days"] = maxi(1, injury_days)
	add_recent_event("%s e' ferito per %d giorni." % [get_gladiator_display_name(gladiator), injury_days])

func add_recent_event(event_text: String) -> void:
	var normalized: String = event_text.strip_edges()
	if normalized == "":
		return
	recent_events.append("Day %d - %s" % [day, normalized])
	while recent_events.size() > RECENT_EVENTS_MAX:
		recent_events.remove_at(0)

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

func _select_match_pair() -> Array[Dictionary]:
	var available: Array[Dictionary] = get_available_gladiators()
	if available.size() < 2:
		return []
	var ret_fighter: Dictionary = {}
	var sec_fighter: Dictionary = {}
	for fighter: Dictionary in available:
		var fighter_class: String = str(fighter.get("class", ""))
		if ret_fighter.is_empty() and fighter_class == "RET":
			ret_fighter = fighter
		elif sec_fighter.is_empty() and fighter_class == "SEC":
			sec_fighter = fighter
	if not ret_fighter.is_empty() and not sec_fighter.is_empty():
		return [ret_fighter, sec_fighter]
	return [available[0], available[1]]

func _build_match_seed(fighter_a: Dictionary, fighter_b: Dictionary) -> int:
	var id_a: String = str(fighter_a.get("id", "A"))
	var id_b: String = str(fighter_b.get("id", "B"))
	return int(hash("%s-%s-%d" % [id_a, id_b, day]))

func _result_has_required_fields(result: Dictionary) -> bool:
	return result.has("winner_id") and result.has("loser_id") and result.has("turns") and result.has("winner_remaining_hp") and result.has("loser_dead") and result.has("combat_log")

func _find_gladiator_by_id(gladiator_id: String) -> Dictionary:
	for gladiator: Dictionary in roster:
		if str(gladiator.get("id", "")) == gladiator_id:
			return gladiator
	return {}

func _apply_loaded_data(data: Dictionary) -> void:
	gold = int(data.get("gold", STARTING_GOLD))
	fame = int(data.get("fame", STARTING_FAME))
	day = int(data.get("day", STARTING_DAY))
	next_gladiator_index = int(data.get("next_gladiator_index", 1))
	roster = _sanitize_roster(data.get("roster", []))
	battle_history = _sanitize_battle_history(data.get("battle_history", []))
	recent_events = _sanitize_recent_events(data.get("recent_events", []))

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

func _set_game_state(new_state: String) -> void:
	game_state = new_state
	game_state_changed.emit(game_state)

func _emit_resources_updated() -> void:
	resources_updated.emit(gold, fame, day)

func _emit_recent_events_updated() -> void:
	recent_events_updated.emit(get_recent_events())
