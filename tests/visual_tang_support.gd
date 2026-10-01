extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
var app
func _initialize()->void:run.call_deferred()
func settle()->void:
	for tween in app._battle_health_tweens.values():
		if tween.is_valid():tween.custom_step(.25)
func run()->void:
	root.size=Vector2i(1280,800);app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false;app.state.gain_xp(200);app.state.quest_stage=6;app.state.choose_sect("听潮阁")
	app.state.tangqi_unlocked=true;app.state.select_companion("唐栖");app._start_battle("training");app.battle_art.set_process(false)
	await capture("197-painted-tang-duel")
	app.state.qi=0;app.state._companion_attack_count=1;app._refresh_battle();app._battle_action("attack");app.battle_art._process(.49);settle();await capture("198-painted-tang-assist")
	app.battle_art._process(.20);settle();await capture("199-painted-tang-recover")
	app.battle_art._process(2);app._battle_action("flee");app.battle_art._process(2);app._close_modal();app.state.set_formation("护后");app._start_battle("training");app.state.turn=1;app._refresh_battle()
	app._battle_action("guard");app.battle_art._process(.9);settle();await capture("200-painted-tang-cover")
	app.battle_art._process(2);app.queue_free();await create_timer(.25).timeout;print("PASS: four actual engine Tang support key-pose captures");quit()
func capture(name:String)->void:
	app.battle_art.queue_redraw();await create_timer(.12).timeout;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/"+name+".png")==OK)
