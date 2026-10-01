extends SceneTree
## Actual runtime battle images. State preparation is in-memory and saves are disabled.
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
var app
func _initialize()->void:run.call_deferred()
func run()->void:
	root.size=Vector2i(1280,800);app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false;app._start_battle("training")
	app.state.enemy_max_hp=350;app.state.enemy_hp=350;app.state.max_hp=250;app.state.hp=170;app.state.qi=6;app._refresh_battle();app.toast_time=0
	await create_timer(.4).timeout;await capture("116-painted-battle-ready")
	app._battle_action("attack");await create_timer(.12).timeout;await capture("117-painted-battle-windup")
	await create_timer(.20).timeout;await capture("118-painted-battle-strike")
	if app.battle_busy:await app.battle_art.presentation_finished
	app._battle_action("guard");await create_timer(.35).timeout;await capture("119-painted-battle-guard")
	if app.battle_busy:await app.battle_art.presentation_finished
	app._battle_action("item");await create_timer(.30).timeout;await capture("120-painted-battle-heal")
	if app.battle_busy:await app.battle_art.presentation_finished
	await create_timer(.3).timeout;app.queue_free();await create_timer(.25).timeout
	print("PASS: painted hero actual-engine action captures");quit()
func capture(name:String)->void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/"+name+".png")==OK)
