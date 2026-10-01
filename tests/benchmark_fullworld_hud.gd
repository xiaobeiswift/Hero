extends SceneTree
## Graphical wall-clock diagnostic; reduced canvas is an isolation probe, not an old build.
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
var app
var measuring=false
var samples:Array[float]=[]
var calls:Array[float]=[]
var cpu:Array[float]=[]
var first_motion_msec:float=-1
var input_tick:int=0
var before:Vector2
func _initialize()->void:run.call_deferred()
func _process(delta:float)->bool:
	if measuring:
		samples.append(delta*1000)
		calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
		if first_motion_msec<0 and app.world.player_pos.distance_to(before)>1:
			first_motion_msec=(Time.get_ticks_usec()-input_tick)/1000.0
	return false
func mean(xs:Array[float])->float:
	var total=0.0
	for x in xs:total+=x
	return total/maxi(1,xs.size())
func run()->void:
	if DisplayServer.get_name()=="headless":push_error("Needs native graphical renderer");quit(1);return
	app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false
	await create_timer(1.5).timeout
	var rows=[]
	for setting in [["stationary",Vector2i(1280,800)],["stationary",Vector2i(938,568)],["stationary",Vector2i(1280,800)],["stationary",Vector2i(938,568)],["moving",Vector2i(1280,800)]]:
		var mode:String=setting[0]
		var canvas:Vector2i=setting[1]
		app.world_view.size=canvas;app.world.viewport_rect=Rect2(Vector2.ZERO,Vector2(canvas))
		app.world.teleport(Vector2(435,650));app.world.terrain_cache_enabled=true;app.world.render_culling_enabled=true
		await create_timer(.5).timeout
		samples.clear();calls.clear();cpu.clear();first_motion_msec=-1
		before=app.world.player_pos;input_tick=Time.get_ticks_usec();var count=Engine.get_process_frames();measuring=true
		if mode=="moving":Input.action_press("move_up")
		await create_timer(2.0).timeout;Input.action_release("move_up")
		var up=app.world.player_pos
		if mode=="moving":Input.action_press("move_down")
		await create_timer(2.0).timeout;Input.action_release("move_down")
		measuring=false
		var duration=(Time.get_ticks_usec()-input_tick)/1000000.0
		samples.sort()
		var row={"mode":mode,"world_canvas":str(canvas),"window":str(root.size),"editor_binary":OS.has_feature("editor"),"renderer":RenderingServer.get_video_adapter_name(),"method":ProjectSettings.get_setting("rendering/renderer/rendering_method"),"frames":Engine.get_process_frames()-count,"seconds":duration,"wall_fps":(Engine.get_process_frames()-count)/duration,"p95_ms":samples[mini(samples.size()-1,int(samples.size()*.95))],"max_ms":samples[-1],"draw_calls_mean":mean(calls),"process_ms_mean":mean(cpu),"first_motion_observed_ms":first_motion_msec,"up_position":str(up),"end_position":str(app.world.player_pos),"cache_ready":app.world.terrain_cache_ready(),"texture_memory_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)}
		rows.append(row);print(JSON.stringify(row))
	var f=FileAccess.open("res://builds/wuxia-hud/fullworld-performance.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"source_base":"956c31e","cases":rows,"scope":"Current HUD stays unchanged. Reduced world canvas isolates visible-world cost, not an equivalent older build. Synthetic engine input timing is not physical keyboard latency. Shared llvmpipe cloud renderer; no user hardware claim."},"\t"));f.close()
	app.queue_free();await create_timer(.25).timeout;quit()
