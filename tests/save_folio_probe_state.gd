extends "res://scripts/game_state.gd"
## Test-only observation adapter. Every I/O request reaches the production
## writer/reader unchanged. There is no path routing and no injected error.
var save_attempts: Array[Dictionary] = []
var load_attempts: Array[Dictionary] = []

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
