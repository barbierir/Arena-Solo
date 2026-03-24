extends SceneTree

const CONTENT_LOADER_SCRIPT := preload("res://scripts/data/loaders/ContentLoader.gd")
const COMBAT_BATCH_SIMULATOR_SCRIPT := preload("res://scripts/combat/analysis/CombatBatchSimulator.gd")

const RUN_COUNT: int = 1000
const MAX_TURNS: int = 128

func _initialize() -> void:
	var loader: ContentLoader = CONTENT_LOADER_SCRIPT.new()
	var registry: ContentRegistry = loader.load_all_definitions()
	var simulator: CombatBatchSimulator = COMBAT_BATCH_SIMULATOR_SCRIPT.new()
	simulator.configure(registry)
	var build_entries: Dictionary = registry.builds.get("entries", {})

	var scenarios: Array[Dictionary] = [
		{"label": "SEC vs SEC", "a": "SEC_STARTER", "b": "SEC_STARTER", "seed": 6100},
		{"label": "RET vs RET", "a": "RET_STARTER", "b": "RET_STARTER", "seed": 7100},
		{"label": "SEC vs RET", "a": "SEC_STARTER", "b": "RET_STARTER", "seed": 8100},
		{"label": "RET vs SEC", "a": "RET_STARTER", "b": "SEC_STARTER", "seed": 9100},
	]

	for scenario in scenarios:
		var result: Dictionary = simulator.run_batch(
			str(scenario.get("a", "")),
			str(scenario.get("b", "")),
			int(scenario.get("seed", 0)),
			RUN_COUNT,
			MAX_TURNS
		)
		_print_scenario(str(scenario.get("label", "")), result)
		var save_outcome: Dictionary = simulator.save_batch_report(result, build_entries)
		if bool(save_outcome.get("ok", false)):
			print("Saved report: %s | %s" % [str(save_outcome.get("json_path", "")), str(save_outcome.get("txt_path", ""))])
		else:
			print("Failed to save report for %s: %s" % [str(scenario.get("label", "")), str(save_outcome.get("error", ""))])

	var suite_outcome: Dictionary = simulator.save_standard_suite_reports(6100, RUN_COUNT, MAX_TURNS, build_entries)
	if bool(suite_outcome.get("ok", false)):
		print("Suite summary saved: %s" % str(suite_outcome.get("summary_path", "")))
	else:
		print("Suite summary save failed: %s" % str(suite_outcome.get("error", "")))

	quit(0)

func _print_scenario(label: String, result: Dictionary) -> void:
	var wins: Dictionary = result.get("wins", {})
	var win_rates: Dictionary = result.get("win_rates", {})
	var turns: Dictionary = result.get("turn_stats", {})
	var fighters: Dictionary = result.get("fighters", {})
	print("--- %s ---" % label)
	print("A wins: %d (%.2f%%) | B wins: %d (%.2f%%) | unresolved: %d" % [
		int(wins.get("attacker", 0)),
		float(win_rates.get("attacker_pct", 0.0)),
		int(wins.get("defender", 0)),
		float(win_rates.get("defender_pct", 0.0)),
		int(wins.get("draws_or_unresolved", 0)),
	])
	print("Turns avg/min/max: %.2f / %d / %d" % [
		float(turns.get("average", 0.0)),
		int(turns.get("min", 0)),
		int(turns.get("max", 0)),
	])
	_print_fighter("A", fighters.get("attacker", {}))
	_print_fighter("B", fighters.get("defender", {}))
	print("")

func _print_fighter(side: String, metrics: Dictionary) -> void:
	var per_match: Dictionary = metrics.get("per_match", {})
	print("%s avg dmg dealt/taken: %.2f / %.2f | avg sta spent: %.2f | hits/misses: %d/%d" % [
		side,
		float(per_match.get("avg_damage_dealt", 0.0)),
		float(per_match.get("avg_damage_taken", 0.0)),
		float(per_match.get("avg_sta_spent", 0.0)),
		int(metrics.get("hit_count", 0)),
		int(metrics.get("miss_count", 0)),
	])
	print("%s avg turns survived: %.2f | low sta turns: %.2f | zero sta turns: %.2f" % [
		side,
		float(per_match.get("avg_turns_survived", 0.0)),
		float(per_match.get("avg_low_sta_turns", 0.0)),
		float(per_match.get("avg_zero_sta_turns", 0.0)),
	])
