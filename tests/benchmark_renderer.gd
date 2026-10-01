extends SceneTree
## Same cloud/editor/viewport diagnostic. Not a promise for other machines.
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
var app
var measuring=false
var deltas:Array[float]=[]
var calls:Array[float]=[]
var process_cost:Array[float]=[]
func _initialize()->void:run.call_deferred()
func _process(delta:float)->bool:
	if measuring:
		deltas.append(delta)
		calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		process_cost.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
	return false
func mean(values:Array[float])->float:
	var total=0.0
	for x in values:total+=x
	return total/maxi(1,values.size())
func run()->void:
	if DisplayServer.get_name()=="headless":
		push_error("Renderer benchmark requires an actual graphical display");quit(1);return
	app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false
	await create_timer(1.5).timeout
	var has_cache=app.world.has_method("terrain_cache_ready")
	var cases=[[false,false],[true,false],[true,true],[false,true],[true,true]] if has_cache else [[false,false],[false,false]]
	for setting in cases:
		var enabled:bool=setting[0]
		app.world.teleport(Vector2(435,650))
		if has_cache:
			app.world.terrain_cache_enabled=enabled
			app.world.render_culling_enabled=setting[1]
		await create_timer(.3).timeout
		deltas.clear();calls.clear();process_cost.clear();measuring=true
		var start=Time.get_ticks_usec();var count=Engine.get_process_frames()
		Input.action_press("move_up");await create_timer(1.4).timeout;Input.action_release("move_up")
		var top:Vector2=app.world.player_pos
		Input.action_press("move_down");await create_timer(1.4).timeout;Input.action_release("move_down")
		measuring=false
		var elapsed=(Time.get_ticks_usec()-start)/1000000.0
		deltas.sort()
		print(JSON.stringify({"case":OS.get_environment("HERO_PERF_CASE"),"cache":enabled and has_cache,"culling":setting[1] and has_cache,"cache_ready":app.world.terrain_cache_ready() if has_cache else false,"elapsed_real_seconds":elapsed,"frames":Engine.get_process_frames()-count,"observed_fps":(Engine.get_process_frames()-count)/elapsed,"frame_delta_p95_ms":deltas[mini(deltas.size()-1,int(deltas.size()*.95))]*1000,"frame_delta_max_ms":deltas[-1]*1000,"draw_calls_mean":mean(calls),"main_process_ms_mean":mean(process_cost),"texture_memory_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"renderer":RenderingServer.get_video_adapter_name(),"method":ProjectSettings.get_setting("rendering/renderer/rendering_method"),"viewport":str(root.size),"editor_binary":OS.has_feature("editor"),"up_position":str(top),"end_position":str(app.world.player_pos)}))
	app._stop_audio();app.queue_free();await create_timer(.25).timeout;quit()
