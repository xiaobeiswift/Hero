extends SceneTree
## Actual graphical accepted-action captures for the health presentation increment.
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class VisualState extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
var app
func _initialize()->void:run.call_deferred()
func run()->void:
	app=Scene.instantiate();app.state=VisualState.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false
	app._start_battle("training");app.state.enemy_hp=160;app.state.enemy_max_hp=160
	app.state.max_hp=180;app.state.hp=120;app._refresh_battle()
	app._toast("剑锋与气血 · 接触时刻准备场景")
	app._battle_action("attack");await create_timer(.47).timeout
	await capture("88-health-sword-contact")
	if app.battle_busy:await app.battle_art.presentation_finished
	app._battle_action("guard");await create_timer(.98).timeout
	await capture("89-health-guard-contact")
	if app.battle_busy:await app.battle_art.presentation_finished
	app._battle_action("item");await create_timer(.44).timeout
	await capture("90-health-healing-contact")
	if app.battle_busy:await app.battle_art.presentation_finished
	app._stop_audio();app.queue_free();await create_timer(.25).timeout
	print("PASS: actual accepted-action health-beat captures");quit()
func capture(id:String)->void:
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png("res://screenshots/"+id+".png")!=OK:push_error("Capture failed");quit(1)
