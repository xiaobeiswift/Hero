extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
var app
func _initialize()->void:run.call_deferred()
func run()->void:
	root.size=Vector2i(1280,800);app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame;app._new_game();app._stop_audio();app.audio_on=false
	app._show_map();await capture("211-paper-village-map");app._close_modal()
	root.size=Vector2i(1180,737);app.state.quest_stage=6;app.state.side_stage=3;app.state.choose_sect("听潮阁");assert(app.state.begin_chapter_two());app.state.map_id="frostbridge";app.state.resources.timber=2;assert(app.state.repair_bridge());app.world.change_map("frostbridge",Vector2(1000,800));app._sync_world_state();app._refresh();app._show_map();await capture("212-paper-frostbridge-map-compact")
	app.queue_free();await create_timer(.25).timeout;print("PASS: fitted paper map captures");quit()
func capture(name:String)->void:
	await create_timer(.4).timeout;await RenderingServer.frame_post_draw;assert(root.get_texture().get_image().save_png("res://screenshots/"+name+".png")==OK)
