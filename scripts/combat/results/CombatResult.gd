extends RefCounted
class_name CombatResult

var winner_build_id: String = ""
var loser_build_id: String = ""
var reason: String = ""

func is_decided() -> bool:
	return winner_build_id != ""
