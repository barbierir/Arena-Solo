extends RefCounted
class_name SeededRngService

var _seed: int
var _rng: RandomNumberGenerator

func _init(seed_value: int = 1) -> void:
	_seed = seed_value
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value

func reseed(seed_value: int) -> void:
	_seed = seed_value
	_rng.seed = seed_value

func get_seed() -> int:
	return _seed

func randf() -> float:
	return _rng.randf()

func randi_range(min_value: int, max_value: int) -> int:
	return _rng.randi_range(min_value, max_value)
