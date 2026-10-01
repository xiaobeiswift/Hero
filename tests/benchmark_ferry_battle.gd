extends SceneTree
## Native wall-clock A/B, same actors/HUD/viewport. Not Movie Maker or user hardware.
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
var app
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
	app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false;app._start_battle("training")
	await create_timer(1).timeout
	var rows=[]
	for painted in [false,true,true,false]:
		app.battle_art.painted_backdrop_enabled=painted
		await create_timer(.5).timeout
		samples.clear();calls.clear();var start=Time.get_ticks_usec();var count=Engine.get_process_frames();measuring=true
		await create_timer(4.0).timeout
		measuring=false;var duration=(Time.get_ticks_usec()-start)/1000000.0;samples.sort()
		var row={"painted_backdrop":painted,"window":str(root.size),"stage":str(app.battle_art.size),"editor_binary":OS.has_feature("editor"),"renderer":RenderingServer.get_video_adapter_name(),"method":ProjectSettings.get_setting("rendering/renderer/rendering_method"),"frames":Engine.get_process_frames()-count,"seconds":duration,"wall_fps":(Engine.get_process_frames()-count)/duration,"p95_ms":samples[mini(samples.size()-1,int(samples.size()*.95))],"max_ms":samples[-1],"draw_calls_mean":mean(calls),"texture_memory_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)}
		rows.append(row);print(JSON.stringify(row))
	var f=FileAccess.open("res://builds/wuxia-hud/ferry-performance.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"source_base":"9ab9b7a + ferry helper","cases":rows,"scope":"Idle duel with identical painted actors, HUD and viewport. Background only toggled in ABBA order. Real wall clock, no Movie Maker. Short shared-host llvmpipe diagnostic, not stable hardware performance or action/input latency."},"\t"));f.close()
	app.queue_free();await create_timer(.25).timeout;quit()
