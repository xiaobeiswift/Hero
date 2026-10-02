extends "res://tests/audit_second_region_test.gd"
const UnifiedUI = preload("res://tests/unified_ui_test_driver.gd")
const Prefs=preload("res://scripts/view_preferences.gd")
class LocalPrefs extends Prefs:
	var writes=0
	var fail=false
	func load_settings(_path:String=PATH)->Error:return OK
	func save_settings(_path:String=PATH)->Error:
		writes+=1;return ERR_CANT_CREATE if fail else OK
func _run()->void:
	var path="user://test-detail-settings.cfg"
	for quality in [false,true]:
		for zoom in range(3):
			var p=Prefs.new();p.full_resolution=quality;p.zoom_index=zoom
			_check(p.save_settings(path)==OK,"Save both display choices")
			var loaded=Prefs.new();_check(loaded.load_settings(path)==OK and loaded.full_resolution==quality and loaded.zoom_index==zoom,"Restore quality and zoom independently of character saves")
			_check(loaded.render_size()==(Vector2i(1280,800) if quality else loaded.canvas_size()),"Render target follows quality without changing logical view")
	var old=ConfigFile.new();old.set_value("display","zoom_index",2);old.save(path)
	var p=Prefs.new();_check(p.load_settings(path)==OK and p.full_resolution and p.zoom_index==2,"Old zoom-only settings use clear mode without losing zoom")
	old.set_value("display","zoom_index",0);old.set_value("display","full_resolution","invalid");old.save(path)
	_check(p.load_settings(path)==ERR_INVALID_DATA and p.full_resolution and p.zoom_index==2,"Invalid quality cannot partially overwrite existing settings")
	game=load("res://scenes/main.tscn").instantiate();game.view_preferences=LocalPrefs.new();root.add_child(game);await process_frame;game.state=AuditState.new()
	game._toggle_view_detail();_check(game.view_preferences.writes==0,"Title blocks display mutation")
	game._new_game();game._stop_audio();game.audio_on=false
	for map in ["qingwei","sluice","frostbridge","mistwood"]:
		game.state.map_id=map;game.world.change_map(map,Vector2(600,480));await process_frame
		for zoom in range(3):
			game.view_preferences.zoom_index=zoom;game.view_preferences.full_resolution=false;game._apply_view_zoom()
			var camera:Vector2=game.world.camera_pos;var logical:Rect2=game.world.viewport_rect;var before=game.state.to_dict().duplicate(true)
			var position:Vector2=game.world.player_pos
			Input.action_press("move_right");game.world._process(.1);Input.action_release("move_right");var expected:Vector2=game.world.player_pos;game.world.teleport(position)
			game._toggle_view_detail()
			_check(game.world_view.size==Vector2i(1280,800) and game.world.viewport_rect==logical,"Clear mode keeps logical camera and full design canvas")
			_check(game.world.camera_pos==camera and game.state.to_dict()==before,"Quality change leaves progress and camera position intact")
			_check(game.world.scale*game.world_view.get_parent().scale==Vector2.ONE*game.view_zoom,"World-to-screen projection remains identical")
			_check(game.world.ui_font==game.world_detail_font and game.font.oversampling==0.0,"Only world lettering uses the cached oversampled font")
			Input.action_press("move_right");game.world._process(.1);Input.action_release("move_right");_check(game.world.player_pos.distance_to(expected)<.001,"Movement and collision are independent of pixel resolution");game.world.teleport(position)
	game.state.map_id="qingwei";game.world.change_map("qingwei",Vector2(715,540));await process_frame
	await _key(KEY_E);_check(game.active_modal,"Clear mode preserves real nearby interaction");var writes:int=game.view_preferences.writes;game._toggle_view_detail();_check(game.view_preferences.writes==writes,"Dialogue blocks quality shortcut calls");await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE);var quality=game.overlay.find_child("PauseQuality",true,false);_check(quality!=null and quality.text.contains("清晰"),"Rest menu exposes current quality")
	var stale:Callable=quality.pressed.get_connections()[0].callable
	var motion=InputEventMouseMotion.new();motion.position=quality.get_global_rect().get_center();root.push_input(motion,true);await process_frame
	for pressed in [true,false]:
		var event=InputEventMouseButton.new();event.position=motion.position;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;root.push_input(event,true);await process_frame
	_check(not game.view_preferences.full_resolution and game.world_view.size==game.view_preferences.canvas_size(),"Actual rest-menu click returns to lower-cost render target")
	stale.call();_check(not game.view_preferences.full_resolution,"Replaced menu callback cannot toggle again")
	game.view_preferences.fail=true;game.overlay.find_child("PauseQuality",true,false).pressed.emit();await process_frame
	_check(game.view_preferences.full_resolution and game.overlay.find_child("PauseDisplayStatus",true,false).text.contains("未能保存"),"Failed preference write remains visible inside the rest menu")
	game.view_preferences.fail=false;game.overlay.find_child("PauseQuality",true,false).pressed.emit();await process_frame
	_check(game.display_settings_warning.is_empty(),"Successful preference write clears display warning")
	await _key(KEY_ESCAPE);UnifiedUI.open_training(game);writes=game.view_preferences.writes;game._toggle_view_detail();_check(game.view_preferences.writes==writes,"Battle blocks quality changes")
	game.battle_presentation_enabled=false;UnifiedUI.leave(game);game._close_modal();game._stop_audio();await create_timer(.25).timeout;game.queue_free();await process_frame
	if failures==0:print("PASS: %d clear/light settings, camera, input, persistence and menu lifecycle checks"%checks)
	else:push_error("FAIL: view detail checks")
	quit(0 if failures==0 else 1)
