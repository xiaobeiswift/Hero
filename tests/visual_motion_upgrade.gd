extends SceneTree
## Deterministic actual-engine movie. Prepared scenario; not a fresh full playthrough.
## No normal saves: all progression and combat preparation is in memory only.
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class VisualState extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
var app
func _initialize()->void:_run.call_deferred()
func _run()->void:
	app=Scene.instantiate();app.state=VisualState.new();root.add_child(app)
	await process_frame
	app._new_game();app._stop_audio();app.audio_on=false
	app.state.quest_stage=6;app.state.choose_sect("听潮阁");app.state.recruit_companion()
	app._refresh();app.world.teleport(Vector2(460,430))
	app._toast("青苇渡 · 环境与动作演示（准备场景）")
	await create_timer(.45).timeout
	await _walk("move_left",.62)
	await _walk("move_up",.33)
	await _walk("move_right",1.10)
	await _walk("move_down",.62)
	await _capture("73-painted-travellers")
	await create_timer(.4).timeout
	app._start_battle("training")
	# Long rehearsal opponent permits guard/healing/skills in one concise clip.
	app.state.enemy_max_hp=350;app.state.enemy_hp=350
	app.state.max_hp=250;app.state.hp=170;app.state.qi=6
	app._refresh_battle()
	await create_timer(.5).timeout
	for pair in [["attack","74-sword-impact"],["skill","75-jade-skill"],["guard","76-guard-impact"],["item","77-healing-motion"]]:
		app._battle_action(pair[0])
		await create_timer(.91 if pair[0]=="guard" else .345).timeout
		await _capture(pair[1])
		if app.battle_busy:await app.battle_art.presentation_finished
		await create_timer(.28).timeout
	# Show finishing choreography before the real victory modal replaces the stage.
	app.state.enemy_hp=1
	app._battle_action("attack")
	await create_timer(.42).timeout
	await _capture("78-finishing-blow")
	if app.battle_busy:await app.battle_art.presentation_finished
	await create_timer(.6).timeout
	app._stop_audio();app.queue_free();await create_timer(.25).timeout
	print("PASS: actual engine walking and accepted battle-action movie");quit()
func _walk(action:String,seconds:float)->void:
	Input.action_press(action);await create_timer(seconds).timeout;Input.action_release(action)
	await process_frame
func _capture(id:String)->void:
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png("res://screenshots/"+id+".png")!=OK:
		push_error("Capture failed");quit(1)
