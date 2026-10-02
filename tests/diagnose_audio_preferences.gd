extends SceneTree
## Native source-runtime diagnostic. Uses an isolated profile and DummyAudio.
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
const Prefs=preload("res://scripts/view_preferences.gd")
const CONFIG="user://native-audio-preference-check.cfg"
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
class CheckPrefs extends Prefs:
	func load_settings(_path:String=PATH)->Error:return super.load_settings(CONFIG)
	func save_settings(_path:String=PATH)->Error:return super.save_settings(CONFIG)
var app
var failures:Array[String]=[]
var steps:Array=[]
func _initialize()->void:run.call_deferred()
func verify(ok:bool,message:String)->void:
	if not ok:failures.append(message);push_error(message)
func record(label:String)->void:
	steps.append({"step":label,"sound_enabled":app.audio_on,"music_loaded":app.music.stream!=null,"music_playing":app.music.playing,"music_paused":app.music.stream_paused})
func start()->void:
	app=Scene.instantiate();app.state=NoSave.new();app.view_preferences=CheckPrefs.new();root.add_child(app);await process_frame
func dispose()->void:
	app._stop_audio();app.queue_free();await create_timer(.25).timeout
func run()->void:
	if DisplayServer.get_name()=="headless":push_error("Run this diagnostic in a graphical source session");quit(2);return
	var prefs=Prefs.new();prefs.sound_enabled=false
	verify(prefs.save_settings(CONFIG)==OK,"Write isolated muted preference")
	await start();record("muted-title-startup")
	verify(app.music.stream!=null and not app.audio_on and not app.music.playing,"Real imported music remains stopped on muted startup")
	app._new_game();app.hud.music_button.pressed.emit();await process_frame;record("enable-from-hud")
	verify(app.audio_on and app.music.playing and not app.music.stream_paused,"Enabling a previously stopped imported stream starts playback")
	app._show_pause();app.overlay.find_child("PauseSound",true,false).pressed.emit();await process_frame;record("mute-from-rest")
	verify(not app.audio_on and app.music.stream_paused,"Rest menu pauses existing music")
	verify(app.overlay.find_child("PauseSound",true,false).text.contains("关"),"Rest label reports muted state")
	await dispose();await start();record("muted-after-restart")
	verify(not app.audio_on and app.music.stream!=null and not app.music.playing,"Muted preference survives a new scene startup without starting playback")
	var report={"utc":Time.get_datetime_string_from_system(true),"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"audio_driver":AudioServer.get_driver_name(),"scope":"Native source runtime, actual imported streams and scripted UI signals; Dummy audio, no listening or exported-binary claim","source_sha256":{"scripts/main.gd":FileAccess.get_sha256("res://scripts/main.gd"),"scripts/view_preferences.gd":FileAccess.get_sha256("res://scripts/view_preferences.gd")},"steps":steps,"failures":failures}
	var file=FileAccess.open("res://tests/audio_preferences_native.json",FileAccess.WRITE)
	if file==null:push_error("Cannot save audio diagnostic report");await dispose();quit(1);return
	file.store_string(JSON.stringify(report,"  ")+"\n");file.close();await dispose()
	print("PASS: native muted startup, actual stream activation/pause and restart" if failures.is_empty() else "FAIL: native audio preference diagnostic");quit(0 if failures.is_empty() else 1)
