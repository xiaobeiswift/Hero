extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
var app
func _initialize()->void:run.call_deferred()
func run()->void:
	root.size=Vector2i(1280,800)
	app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false;app.world.teleport(Vector2(435,650));app.toast_time=0;app.hud.quest_notice_time=0
	app._show_inventory();await capture("113-inventory-paper-new")
	app.state.quest_stage=6;app.state.gain_xp(200);app.state.choose_sect("听潮阁");app.state.recruit_companion();app.state.coins=130
	app.state.buy_equipment();app.state.resources={"iron":3,"timber":2,"cloth":5,"herb":4};app._refresh();app._show_inventory();await capture("114-inventory-equipped-party")
	root.size=Vector2i(1180,737);app.state.set_formation("护后");app._show_inventory();await capture("115-inventory-compact")
	app.queue_free();await create_timer(.25).timeout;print("PASS: three actual-engine paper inventory captures");quit()
func capture(name:String)->void:
	await create_timer(.6).timeout;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/"+name+".png")==OK)
