extends "res://scripts/game_state.gd"
## Observation only: every operation reaches production unchanged.
## This fixture supplies no substitute errors, paths, storage, or reset behavior.
var save_attempts: Array[Dictionary] = []
var load_attempts: Array[Dictionary] = []
var reset_attempts: Array[Dictionary] = []

func reset_game() -> void:
	var before: Dictionary = to_dict().duplicate(true)
	super.reset_game()
	reset_attempts.append({"before":before,"after":to_dict().duplicate(true)})

func save_game(path: String = SAVE_PATH) -> Error:
	var before: Dictionary = to_dict().duplicate(true)
	var error: Error = super.save_game(path)
	save_attempts.append({"path":path,"error":error,"before":before})
	return error

func load_game(path: String = SAVE_PATH) -> Error:
	var before: Dictionary = to_dict().duplicate(true)
	var error: Error = super.load_game(path)
	load_attempts.append({"path":path,"error":error,"before":before,"after":to_dict().duplicate(true)})
	return error
