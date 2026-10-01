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
	_test_health_impact_beats()
	game._stop_audio();game.queue_free()
	await process_frame
	print("%s: %d battle presentation UI checks" % ["PASS" if failures==0 else "FAIL",checks])
	quit(0 if failures==0 else 1)


func _settle_health_tweens(seconds: float = 0.25) -> void:
	# Drive real Godot Tweens deterministically without wall-clock timing races.
	for tween: Tween in game._battle_health_tweens.values():
		if tween.is_valid():
			tween.pause()
			tween.custom_step(seconds)

func _fresh_health_battle(hp: int = 100) -> void:
	game._close_modal()
	game.state=NoSaveState.new()
	game.state.hp=hp
	game._start_battle("training")

func _test_health_impact_beats() -> void:
	_fresh_health_battle(50)
	game._battle_action("attack")
	_check(game.battle_hp.value==64 and game.battle_player_hp.value==50, "Presentation snapshots real pre-action health instead of already-resolved model values")
	game.battle_art._process(0.31)
	_check(game.battle_hp.value==64 and game._battle_health_tweens.is_empty(), "Enemy bar remains untouched before sword contact")
	game.battle_art._process(0.02)
	_check(game._battle_health_values.enemy==48 and game._battle_health_tweens.has("enemy"), "Sword impact starts a tween to exact reported direct damage")
	_settle_health_tweens(0.04)
	_check(game.battle_hp.value>48 and game.battle_hp.value<64, "Enemy health visibly interpolates rather than snapping")
	_settle_health_tweens()
	_check(game.battle_hp.value==48 and game.battle_player_hp.value==50, "Player bar stays unchanged while outgoing damage finishes")
	game.battle_art._process(0.53)
	_check(game.battle_player_hp.value==50, "Player bar remains untouched before enemy contact")
	game.battle_art._process(0.03)
	_settle_health_tweens()
	_check(game.battle_player_hp.value==45, "Counter contact applies its actual incoming amount")
	_finish()
	_check(game._battle_health_tweens.is_empty() and game._battle_health_values.is_empty(), "Final reconciliation kills and clears completed presentation tweens")

	_fresh_health_battle()
	game.state.recruit_companion();game.state._companion_attack_count=1
	game._battle_action("attack")
	game.battle_art._process(0.33)
	var direct_tween: Tween=game._battle_health_tweens.enemy
	_settle_health_tweens(0.025)
	_check(game.battle_hp.value>48, "Companion fixture interrupts a still-interpolating direct hit")
	game.battle_art._process(0.17)
	_check(not direct_tween.is_valid(), "Support impact kills the superseded enemy-bar tween")
	_check(game._battle_health_values.enemy==41, "Support damage accumulates from the exact direct-hit target, not partially animated health")
	_settle_health_tweens()
	_check(game.battle_hp.value==41 and game.state.enemy_hp==41, "Direct and companion impacts arrive at truthful combined health")
	_finish()

	_fresh_health_battle(40)
	game._battle_action("item")
	_check(game.state.hp==80 and game.battle_player_hp.value==40, "Resolved medicine and retaliation do not leak into pre-healing presentation")
	game.battle_art._process(0.24)
	_check(game.battle_player_hp.value==40, "Recovery bar waits for the healing beat")
	game.battle_art._process(0.02);_settle_health_tweens()
	_check(game.battle_player_hp.value==85, "Medicine first visibly restores its full actual 45 health")
	game.battle_art._process(0.63);_settle_health_tweens()
	_check(game.battle_player_hp.value==80, "Later counter independently subtracts five instead of presenting a false net heal")
	_finish()

	_fresh_health_battle(95)
	game._battle_action("item")
	game.battle_art._process(0.26);_settle_health_tweens()
	_check(game.battle_player_hp.value==100 and game._battle_health_values.player==100, "Capped healing uses the actual five-point recovery and never exceeds maximum health")
	_finish()

	_fresh_health_battle(1)
	game._battle_action("guard")
	_check(game.state.hp==100 and game.battle_player_hp.value==1, "Automatic defeat recovery does not conceal the lethal blow")
	game.battle_art._process(0.89);_settle_health_tweens()
	_check(game.battle_player_hp.value==0 and not game.active_modal, "Defeat reaches zero during its presentation before the recovery result")
	_finish()
	_check(game.battle_player_hp.value==100 and game.active_modal, "Final defeat reconciliation applies the real recovery state")

	_fresh_health_battle(7)
	game.state.xp=50;game.state.enemy_hp=1
	game._battle_action("attack")
	_check(game.state.max_hp==112 and game.battle_player_hp.max_value==100 and game.battle_player_hp.value==7, "Level-up maximum and recovery wait until the finishing exchange ends")
	game.battle_art._process(0.33);_settle_health_tweens()
	_check(game.battle_hp.value==0 and game.battle_player_hp.value==7, "Finishing damage clamps to zero without inventing a combat heal from level-up")
	_finish()
	_check(game.battle_player_hp.value==112 and game.battle_player_hp.max_value==112, "Final reconciliation shows exact new level and full health")

	_fresh_health_battle(65)
	game._battle_action("attack")
	game.battle_art._process(0.33)
	var cancelled_tween: Tween=game._battle_health_tweens.enemy
	_settle_health_tweens(0.04)
	_fresh_health_battle(82)
	_check(not cancelled_tween.is_valid(), "Replacing a battle kills a still-running old bar tween")
	_check(game._battle_health_tweens.is_empty() and game._battle_health_generation==-1, "New encounter invalidates old health presentation generation")
	_check(game.battle_hp.value==64 and game.battle_player_hp.value==82, "New encounter bars cannot inherit interpolated old health")
	game._present_battle_health_impact("player",50)
	_check(game.battle_player_hp.value==82 and game._battle_health_tweens.is_empty(), "A late impact outside an active exchange cannot alter refreshed bars")
	game._battle_action("guard")
	game.battle_art._process(0.89)
	_settle_health_tweens()
	_check(game.battle_player_hp.value==80 and game.battle_hp.value==64, "Fresh encounter receives only its own guarded hit after cancellation")
	_finish()
	_check(game.battle_player_hp.value==game.state.hp and game._battle_health_tweens.is_empty(), "Final state stays exact after cancellation followed by a new exchange")

	# A single slow frame may cross healing, outgoing damage and incoming damage.
	# Final authoritative refresh wins over every outstanding visual tween.
	_fresh_health_battle(20)
	game._battle_action("item")
	_finish()
	_check(game.battle_player_hp.value==game.state.hp and game.battle_hp.value==game.state.enemy_hp and game._battle_health_tweens.is_empty(), "Oversized frame finishes with exact model health and no stale pending tweens")
	game._battle_action("flee");_finish()
