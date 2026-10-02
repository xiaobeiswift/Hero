extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
var app
func _initialize()->void:run.call_deferred()
func key(code:int)->void:
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event);await process_frame
	event=InputEventKey.new();event.physical_keycode=code;event.pressed=false;Input.parse_input_event(event);await process_frame
func run()->void:
	root.size=Vector2i(1280,800);app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame;app._new_game();app._stop_audio();app.audio_on=false
	app.state.quest_stage=1;app._sync_world_state();app.world.teleport(Vector2(1240,370));await process_frame;await key(KEY_E);await key(KEY_1);await capture("219-harvested-herb-view-prompt")
	app.state.quest_stage=6;app.state.side_stage=3;app.state.choose_sect("听潮阁");app.state.begin_chapter_two();app.state.map_id="frostbridge";app.world.change_map("frostbridge",Vector2(1400,425));app._sync_world_state();app._refresh();await process_frame
	await key(KEY_E);await key(KEY_1);await key(KEY_E);await capture("220-depleted-material-explanation")
	app.queue_free();await create_timer(.25).timeout;print("PASS: state-aware collection prompt and depleted material page captures");quit()
func capture(name:String)->void:
	await create_timer(.3).timeout;await RenderingServer.frame_post_draw;assert(root.get_texture().get_image().save_png("res://screenshots/"+name+".png")==OK)
