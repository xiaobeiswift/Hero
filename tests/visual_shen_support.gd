extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
var app
func _initialize()->void:run.call_deferred()
func run()->void:
	root.size=Vector2i(1280,800);app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false
	app.state.gain_xp(200);app.state.quest_stage=6;app.state.choose_sect("听潮阁");app.state.recruit_companion()
	app.state.side_stage=3;app.state.shen_care_stage=5;app.state.shen_care_choice="mobile";app.state.hp=70;app.state.qi=6
	app._start_battle("training");await capture("142-painted-shen-duel")
	app._battle_action("attack");await app.battle_art.presentation_finished
	app._battle_action("attack");await create_timer(.46).timeout;await capture("143-painted-shen-assist",false)
	while app.battle_art.action_time<.565:await process_frame
	await capture("144-painted-shen-heal",false)
	if app.battle_busy:await app.battle_art.presentation_finished
	app._battle_action("flee");if app.battle_busy:await app.battle_art.presentation_finished
	app._close_modal();app.state.set_formation("护后");app._start_battle("training")
	app._battle_action("attack");while app.battle_art.action_time<.89:await process_frame
	await capture("145-painted-shen-cover",false)
	if app.battle_busy:await app.battle_art.presentation_finished
	app.queue_free();await create_timer(.25).timeout;print("PASS: actual painted Shen support action frames");quit()
func capture(name:String,idle:bool=true)->void:
	if idle:await create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/"+name+".png")==OK)
