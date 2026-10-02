extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
const Prefs=preload("res://scripts/view_preferences.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
class LocalPrefs extends Prefs:
	var writes=0
	var fail=false
	func load_settings(_path:String=PATH)->Error:return OK
	func save_settings(_path:String=PATH)->Error:
		writes+=1;return ERR_CANT_CREATE if fail else OK
var app
func _initialize()->void:run.call_deferred()
func key(code:int)->void:
	var e=InputEventKey.new();e.physical_keycode=code;e.pressed=true;Input.parse_input_event(e);await process_frame
	e=InputEventKey.new();e.physical_keycode=code;e.pressed=false;Input.parse_input_event(e);await process_frame
func run()->void:
	var prefs=Prefs.new();var path="user://test-view-settings.cfg"
	for i in range(3):
		prefs.zoom_index=i;assert(prefs.save_settings(path)==OK)
		var loaded=Prefs.new();assert(loaded.load_settings(path)==OK and loaded.zoom_index==i)
		assert(Vector2(loaded.canvas_size())*loaded.zoom()==Vector2(1280,800))
	var malformed=ConfigFile.new();malformed.set_value("display","zoom_index","huge");assert(malformed.save(path)==OK)
	prefs.zoom_index=1;assert(prefs.load_settings(path)==ERR_INVALID_DATA and prefs.zoom_index==1)
	assert(prefs.save_settings("user://missing-directory/view.cfg")!=OK)
	app=Scene.instantiate();app.state=NoSave.new();app.view_preferences=LocalPrefs.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false
	var before=app.state.to_dict();var initial:Vector2=app.world.player_pos
	await key(KEY_EQUAL)
	assert(app.view_zoom==1.25 and app.world.viewport_rect.size==Vector2(1024,640) and app.world_view.size==Vector2i(1280,800))
	assert(app.world_view.get_parent().size*app.world_view.get_parent().scale==Vector2(1280,800))
	assert(app.state.to_dict()==before and app.world.player_pos==initial)
	await key(KEY_E);assert(app.active_modal)
	var dialogue=""
	for label in app.overlay.find_children("*","Label",true,false):dialogue+=label.text
	assert(dialogue.contains("陆伯"));await key(KEY_ESCAPE)
	await key(KEY_EQUAL);assert(app.view_zoom==1.6 and app.world.viewport_rect.size==Vector2(800,500))
	assert(app.hud.identity_wash.position==Vector2(20,23) and app.hud.nav_buttons[0].size==Vector2(80,73))
	var writes:int=app.view_preferences.writes;await key(KEY_EQUAL);assert(app.view_preferences.writes==writes)
	for region in ["qingwei","sluice","frostbridge","mistwood"]:
		app.world.change_map(region,Vector2(460,430));app._apply_view_zoom()
		assert(app.world.camera_pos.x>=0 and app.world.camera_pos.y>=0)
		assert(app.world.camera_pos.x<=app.world.WORLD_SIZE.x-800 and app.world.camera_pos.y<=app.world.WORLD_SIZE.y-500)
		assert(app.world._can_walk(app.world.player_pos))
	app.world.change_map("qingwei",Vector2(460,430));app.world.teleport(Vector2(70,160));app.hud.tick(1)
	assert(app.hud.identity_wash.modulate.a<.3)
	app._sync_hud_navigation(true)
	assert(app.world._navigation_target_covered(Vector2(40,50)))
	var arrow:Vector2=app.world._compass_edge(Vector2(-100,-100))*app.view_zoom
	assert(not app.hud.identity_wash.get_rect().has_point(arrow))
	var bubble=Rect2(arrow-Vector2(58,21),Vector2(116,72))
	for reserved in app.world.hud_exclusion_rects:
		assert(not bubble.intersects(Rect2(reserved.position*app.view_zoom,reserved.size*app.view_zoom)))
	await key(KEY_ESCAPE);assert(app.overlay.get_meta("pause_menu",false))
	writes=app.view_preferences.writes
	await key(KEY_MINUS);assert(app.view_zoom==1.25 and app.active_modal and app.overlay.get_meta("pause_menu",false))
	assert(app.view_preferences.writes==writes+1 and app.overlay.find_child("PauseView",true,false).text.contains("125%"))
	await key(KEY_EQUAL);assert(app.view_zoom==1.6 and app.active_modal)
	await key(KEY_KP_SUBTRACT);assert(app.view_zoom==1.25 and app.active_modal)
	await key(KEY_KP_ADD);assert(app.view_zoom==1.6 and app.active_modal)
	app.view_preferences.fail=true;await key(KEY_MINUS)
	assert(app.view_zoom==1.25 and app.overlay.find_child("PauseDisplayStatus",true,false).text.contains("未能保存"))
	app.view_preferences.fail=false;await key(KEY_PLUS)
	assert(app.view_zoom==1.6 and app.display_settings_warning.is_empty())
	var button=app.overlay.find_child("PauseView",true,false);assert(button!=null and button.text.contains("160%"))
	button.pressed.emit();await process_frame;assert(app.view_zoom==1.0 and app.overlay.find_child("PauseView",true,false).text.contains("100%"))
	await key(KEY_ESCAPE);await key(KEY_I);writes=app.view_preferences.writes
	await key(KEY_EQUAL);assert(app.view_preferences.writes==writes and app.view_zoom==1.0)
	await key(KEY_ESCAPE);app.view_preferences.fail=true;await key(KEY_EQUAL)
	assert(app.view_zoom==1.25 and app.status_label.text.contains("未能保存"))
	app._start_battle("training");writes=app.view_preferences.writes;await key(KEY_EQUAL);app._change_view_zoom(1)
	assert(app.view_zoom==1.25 and app.view_preferences.writes==writes and app.battle_art.scale==Vector2.ONE and app.hud.duel_hud.active)
	app.battle_presentation_enabled=false;app._battle_action("flee");app._close_modal();app.view_preferences.fail=false
	await key(KEY_MINUS);assert(app.view_zoom==1.0 and app.world_view.size==Vector2i(1280,800))
	app.queue_free();await create_timer(.25).timeout
	print("PASS: persisted view choice, keyboard/menu zoom, fixed HUD, camera bounds and modal/battle gates");quit()
