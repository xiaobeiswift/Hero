extends SceneTree
## Real main scene, presentation enabled even headlessly, isolated no-save state.
const Scene = preload("res://scenes/main.tscn")
const Model = preload("res://scripts/game_state.gd")
class NoSaveState extends Model:
	func save_game(_path: String=SAVE_PATH) -> Error: return OK
	func has_save() -> bool: return false
var checks: int = 0
var failures: int = 0
var game

func _initialize() -> void: _run.call_deferred()
func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
func _all_disabled() -> bool:
	for button in game.battle_buttons:
		if not button.disabled: return false
	return true
func _finish() -> void:
	game.battle_art._process(game.battle_art.get_presentation_duration()+0.1)

func _run() -> void:
	game=Scene.instantiate()
	game.state=NoSaveState.new()
	root.add_child(game)
	await process_frame
	game._new_game()
	game._stop_audio(); game.audio_on=false
	game.battle_presentation_enabled=true
	game.battle_art.set_process(false)
	game._start_battle("training")
	_check(not game.battle_busy and not game.battle_art.is_presenting(), "New battle starts with no stale presentation")
	game.state.qi=0
	game._battle_action("skill")
	_check(not game.battle_busy and game.state.turn==0, "Rejected skills neither await nor lock input")
	var enemy_before: int = game.state.enemy_hp
	game._battle_action("attack")
	_check(game.battle_busy and game.battle_art.is_presenting(), "Accepted attack starts visible presentation")
	_check(_all_disabled(), "All action buttons are disabled during the exchange")
	_check(game.state.turn==1 and game.state.enemy_hp<enemy_before, "One accepted input resolves exactly one model turn")
	var snapshot: Dictionary = game.state.to_dict().duplicate(true)
	var enemy_after: int = game.state.enemy_hp
	game._battle_action("attack")
	game._battle_action("guard")
	var key=InputEventKey.new();key.pressed=true;key.physical_keycode=KEY_1
	Input.parse_input_event(key)
	await process_frame
	_check(game.state.turn==1 and game.state.enemy_hp==enemy_after and game.state.to_dict()==snapshot, "Repeated clicks and keyboard input cannot spend duplicate turns")
	game.battle_art._process(0.35)
	_check(game.battle_busy and game.battle_layer.visible and not game.active_modal, "Contact stays on the battle stage instead of immediately closing")
	_finish()
	_check(not game.battle_busy and not game.battle_art.is_presenting(), "Completion signal releases the input lock")
	_check(not game.battle_buttons[0].disabled and not game.battle_buttons[2].disabled, "Normal actions are restored after the exchange")
	_check(game.battle_hp.value==game.state.enemy_hp and game.battle_player_hp.value==game.state.hp, "Completed exchange synchronizes HUD with actual rules")

	game.state.enemy_hp=1
	game._battle_action("attack")
	_check(not game.state.battle_active and game.battle_busy, "Finishing hit can resolve rules while its motion is still playing")
	_check(game.current_screen=="battle" and game.battle_layer.visible and not game.active_modal, "Victory modal waits for the finishing blow")
	game._battle_action("attack")
	_check(game.state.turn==2, "No duplicate input can repeat victory rewards")
	game.battle_art._process(0.78)
	_check(game.battle_layer.visible and not game.active_modal, "Finisher recoil remains visible during the result delay")
	_finish()
	_check(game.current_screen=="explore" and not game.battle_layer.visible and game.active_modal, "Victory modal appears only after the final animation")
	game._close_modal()

	game._start_battle("training")
	_check(not game.battle_busy and game.battle_art.action.is_empty(), "Restart clears the old finishing pose and busy flag")
	game._battle_action("flee")
	_check(game.battle_busy and game.battle_layer.visible, "Escape is visibly presented before returning to exploration")
	_finish()
	_check(not game.battle_busy and game.current_screen=="explore" and not game.battle_layer.visible, "Escape completion never strands the caller")

	game._start_battle("training")
	game.state.hp=1
	game._battle_action("guard")
	_check(game.battle_art.presentation_details.player_defeated and game.battle_layer.visible and not game.active_modal, "Player defeat is presented before recovery dialogue")
	_finish()
	_check(game.active_modal and not game.battle_busy and not game.battle_layer.visible, "Defeat completes into the existing recovery flow")
	game._close_modal()

	# Replace an unfinished finishing blow. The old waiter must be released and
	# ignored immediately; it must not return later to close the next encounter.
	game._start_battle("training")
	game.state.enemy_hp=1
	game._battle_action("attack")
	_check(game.battle_busy and not game.state.battle_active, "Interruption fixture has an unfinished winning presentation")
	game._start_battle("training")
	_check(not game.battle_busy and not game.battle_art.is_presenting() and not game.active_modal, "New encounter cancels old finisher without its result modal")
	_check(game.state.turn==0 and game.state.battle_active and game.current_screen=="battle", "Cancelled waiter cannot alter new battle state")
	game._battle_action("guard")
	_finish()
	_check(game.state.turn==1 and game.state.battle_active and game.battle_layer.visible and not game.active_modal, "Next completion cannot replay a stale victory callback")
	_check(not game.battle_busy and not game.battle_buttons[0].disabled, "Input is usable after interruption and a fresh completed turn")
	game._battle_action("flee");_finish()
	game._stop_audio();game.queue_free()
	await process_frame
	print("%s: %d battle presentation UI checks" % ["PASS" if failures==0 else "FAIL",checks])
	quit(0 if failures==0 else 1)
