extends SceneTree
## Native wall-clock A/B, same actors/HUD/viewport. Not Movie Maker or user hardware.
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
const Prefs=preload("res://scripts/view_preferences.gd")
class NoWritePrefs extends Prefs:
	func load_settings(_path:String=PATH)->Error:return OK
	func save_settings(_path:String=PATH)->Error:return OK
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
var app
var world_font:FontFile
var measuring=false
var samples:Array[float]=[]
var calls:Array[float]=[]
func _initialize()->void:run.call_deferred()
func _process(delta:float)->bool:
	if measuring:
		samples.append(delta*1000)
		calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	return false
func mean(xs:Array[float])->float:
	var sum=0.0
	for x in xs:sum+=x
	return sum/maxi(1,xs.size())
func run()->void:
	if DisplayServer.get_name()=="headless":push_error("Needs graphical renderer");quit(1);return
	app=Scene.instantiate();app.state=NoSave.new();app.view_preferences=NoWritePrefs.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false;root.size=Vector2i(1280,800);app.state.quest_stage=1;app._sync_world_state();app._refresh();app.view_preferences.zoom_index=2;app._apply_view_zoom();app.world.teleport(Vector2(610,440));app.toast_time=0;app.hud.quest_notice_time=0;world_font=app.font.duplicate();world_font.oversampling=2.0
	await create_timer(1).timeout
	var rows=[]
	for full in [false,true,true,false]:
		if app.view_preferences.has_method("render_size"):
			app.view_preferences.full_resolution=full;app._apply_view_zoom()
		else:
			app.world.scale=Vector2.ONE;app.world.ui_font=app.font;app._apply_view_zoom()
			if full:
				app.world_view.size=Vector2i(1280,800)
				var container:SubViewportContainer=app.world_view.get_parent();container.size=Vector2(1280,800);container.scale=Vector2.ONE
				app.world.scale=Vector2.ONE*app.view_zoom;app.world.ui_font=world_font
		await create_timer(.5).timeout
		samples.clear();calls.clear();var start=Time.get_ticks_usec();var count=Engine.get_process_frames();measuring=true
		await create_timer(5.0).timeout
		measuring=false;var duration=(Time.get_ticks_usec()-start)/1000000.0;samples.sort()
		var row={"native_canvas":full,"world_font_oversampling":app.world.ui_font.oversampling,"logical_world":str(app.world.viewport_rect.size),"window":str(root.size),"world_view":str(app.world_view.size),"editor_binary":OS.has_feature("editor"),"renderer":RenderingServer.get_video_adapter_name(),"method":ProjectSettings.get_setting("rendering/renderer/rendering_method"),"frames":Engine.get_process_frames()-count,"seconds":duration,"wall_fps":(Engine.get_process_frames()-count)/duration,"p95_ms":samples[mini(samples.size()-1,int(samples.size()*.95))],"max_ms":samples[-1],"draw_calls_mean":mean(calls),"texture_memory_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)}
		rows.append(row);print(JSON.stringify(row))
	DirAccess.make_dir_recursive_absolute("res://builds")
	var f=FileAccess.open("res://builds/view-clarity-performance.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"source_git_commit":OS.get_environment("HERO_PERF_COMMIT"),"source_base":"Current source; saved preference path when available, external canvas switch on older7fbc1be","cases":rows,"scope":"Stationary village view at(610,440), same160percent logical view/HUD/camera. ABBA compares existing scaled800x500 buffer with1280x800 world canvas and2x world-font oversampling. Real wall clock, no Movie Maker. Short shared-host llvmpipe diagnostic, not stable hardware performance or action/input latency."},"\t"));f.close()
	app.queue_free();await create_timer(.25).timeout;quit()
