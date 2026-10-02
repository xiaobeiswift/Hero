extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
const Prefs=preload("res://scripts/view_preferences.gd")
const TEST_PATH="user://audio-preference-audit.cfg"
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
class LocalPrefs extends Prefs:
	var fail=false
	func load_settings(_path:String=PATH)->Error:return super.load_settings(TEST_PATH)
	func save_settings(_path:String=PATH)->Error:return ERR_CANT_CREATE if fail else super.save_settings(TEST_PATH)
var app
func _initialize()->void:run.call_deferred()
func key(code:int)->void:
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event);await process_frame
	event=InputEventKey.new();event.physical_keycode=code;event.pressed=false;Input.parse_input_event(event);await process_frame
func create_app()->void:
	app=Scene.instantiate();app.state=NoSave.new();app.view_preferences=LocalPrefs.new();root.add_child(app);await process_frame
func run()->void:
	var selected=Prefs.new();selected.sound_enabled=false;selected.zoom_index=1;selected.full_resolution=false
	assert(selected.save_settings(TEST_PATH)==OK)
	var restored=Prefs.new();assert(restored.load_settings(TEST_PATH)==OK and not restored.sound_enabled and not restored.full_resolution and restored.zoom_index==1)
	var invalid=ConfigFile.new();invalid.set_value("display","zoom_index",2);invalid.set_value("audio","enabled","false");assert(invalid.save(TEST_PATH)==OK)
	assert(restored.load_settings(TEST_PATH)==ERR_INVALID_DATA and not restored.sound_enabled and restored.zoom_index==1 and not restored.full_resolution)
	var old=ConfigFile.new();old.set_value("display","zoom_index",2);assert(old.save(TEST_PATH)==OK)
	assert(restored.load_settings(TEST_PATH)==OK and restored.sound_enabled and restored.full_resolution and restored.zoom_index==2)
	assert(selected.save_settings(TEST_PATH)==OK);await create_app()
	assert(not app.audio_on and not app.music.playing and app.view_zoom==1.25)
	app._new_game();var progress=app.state.to_dict();await key(KEY_ESCAPE)
	assert(app.overlay.find_child("PauseSound",true,false).text.contains("关"))
	# Silent PCM exercises actual playback start/pause without requiring an audio device.
	var silence=AudioStreamWAV.new();silence.format=AudioStreamWAV.FORMAT_16_BITS;silence.mix_rate=22050
	var samples=PackedByteArray();samples.resize(88200);silence.data=samples;app.music.stream=silence
	app.overlay.find_child("PauseSound",true,false).pressed.emit();await process_frame
	assert(app.audio_on and app.music.playing and not app.music.stream_paused and app.overlay.find_child("PauseSound",true,false).text.contains("开"))
	assert(restored.load_settings(TEST_PATH)==OK and restored.sound_enabled and restored.zoom_index==1 and not restored.full_resolution)
	var stale:Callable=app.overlay.find_child("PauseSound",true,false).pressed.get_connections()[0].callable
	app.sfx.stream=silence;app.sfx.play();assert(app.sfx.playing)
	app.overlay.find_child("PauseSound",true,false).pressed.emit();await process_frame
	assert(not app.audio_on and app.music.stream_paused and not app.sfx.playing and app.state.to_dict()==progress)
	stale.call();assert(not app.audio_on)
	assert(restored.load_settings(TEST_PATH)==OK and not restored.sound_enabled)
	app.view_preferences.fail=true;app.overlay.find_child("PauseSound",true,false).pressed.emit();await process_frame
	assert(app.audio_on and app.overlay.find_child("PauseDisplayStatus",true,false).text.contains("未能保存"))
	assert(restored.load_settings(TEST_PATH)==OK and not restored.sound_enabled)
	app.view_preferences.fail=false;app.overlay.find_child("PauseSound",true,false).pressed.emit();await process_frame
	assert(not app.audio_on and app.display_settings_warning.is_empty())
	await key(KEY_ESCAPE);app.hud.music_button.pressed.emit();await process_frame
	assert(app.audio_on and restored.load_settings(TEST_PATH)==OK and restored.sound_enabled)
	app.hud.music_button.pressed.emit();await process_frame;assert(not app.audio_on)
	app._stop_audio();app.queue_free();await create_timer(.25).timeout;silence=null
	await create_app();assert(not app.audio_on and not app.music.playing and app.view_zoom==1.25 and not app.view_preferences.full_resolution)
	app._new_game();assert(not app.audio_on)
	app._stop_audio();app.queue_free();await create_timer(.25).timeout
	print("PASS: persisted audio choice, legacy/invalid settings, silent playback resume/pause, failure/retry UI, stale callbacks and restart");quit()
