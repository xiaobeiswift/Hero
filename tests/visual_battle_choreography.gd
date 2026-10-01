extends SceneTree
## Deterministic actual-engine combat stills. Run graphically; uses a no-save state.
const Scene = preload("res://scenes/main.tscn")
const Model = preload("res://scripts/game_state.gd")
class NoSaveState extends Model:
	func save_game(_path: String=SAVE_PATH) -> Error: return OK
	func has_save() -> bool: return false
var app
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	app=Scene.instantiate();app.state=NoSaveState.new();root.add_child(app)
	await process_frame
	app._new_game();app._stop_audio();app.audio_on=false
	app.state.recruit_companion();app.state.heal_rest()
	app._start_battle("training")
	app.battle_art.set_process(false)
	await _capture("80-combat-ready")
	app.battle_art.hit("attack",app.state.battle_action("attack"))
	app.battle_art.action_time=0.12
	await _capture("81-combat-windup")
	app.battle_art.action_time=0.345
	await _capture("82-combat-sword-contact")
	app.battle_art.action_time=0.91
	await _capture("83-combat-counter")
	app.state.qi=6;app.state.skill_cooldown=0
	app.battle_art.hit("skill",app.state.battle_action("skill"))
	app.battle_art.action_time=0.35
	await _capture("84-combat-jade-skill")
	app.battle_art.action_time=0.50
	await _capture("85-combat-companion-assist")
	app.state.start_battle("training")
	app.battle_art.hit("guard",app.state.battle_action("guard"))
	app.battle_art.action_time=0.91
	await _capture("86-combat-guard-contact")
	app.state.hp=28
	app.battle_art.hit("item",app.state.battle_action("item"))
	app.battle_art.action_time=0.34
	await _capture("87-combat-medicine")
	app.battle_art.reset_presentation();app._stop_audio();app.queue_free()
	await process_frame
	print("PASS: 8 deterministic combat choreography captures")
	quit()
func _capture(id: String) -> void:
	app.battle_art.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	var error: Error = root.get_texture().get_image().save_png("res://screenshots/"+id+".png")
	if error!=OK:
		push_error("Combat capture failed: "+str(error));quit(1)
