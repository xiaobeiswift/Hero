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
	app._new_game();app._stop_audio();app.audio_on=false
	app.state.gain_xp(200);app.state.quest_stage=6;app.state.choose_sect("听潮阁");app.state.hp=70;app.state.qi=6
	app._start_battle("training");app._refresh_battle();app.toast_time=0
	await create_timer(.4).timeout;await capture("121-painted-duel-ready")
	app._battle_action("attack");await create_timer(.12).timeout;await capture("122-painted-duel-windup")
	await create_timer(.20).timeout;await capture("123-painted-duel-contact")
	while app.battle_busy and app.battle_art.action_time<.9:await process_frame
	assert(app.battle_busy and app.battle_art.enemy_visual_pose()=="strike")
	await capture("128-painted-duel-counter")
	if app.battle_busy:await app.battle_art.presentation_finished
	app._battle_action("guard");await create_timer(.35).timeout;await capture("124-painted-duel-guard")
	if app.battle_busy:await app.battle_art.presentation_finished
	app._battle_action("item");await create_timer(.30).timeout;await capture("125-painted-duel-heal")
	if app.battle_busy:await app.battle_art.presentation_finished
	app._battle_action("skill")
	await create_timer(.90).timeout;await capture("126-painted-duel-kneel")
	if app.battle_busy:await app.battle_art.presentation_finished
	await create_timer(.3).timeout;await capture("127-painted-duel-result")
	app.queue_free();await create_timer(.25).timeout
	print("PASS: painted paired duel actual-engine action captures");quit()
func capture(name:String)->void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/"+name+".png")==OK)
