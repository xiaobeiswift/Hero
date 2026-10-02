extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
const Prefs=preload("res://scripts/view_preferences.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
class NoPrefs extends Prefs:
	func load_settings(_path:String=PATH)->Error:return OK
	func save_settings(_path:String=PATH)->Error:return OK
func _initialize()->void:run.call_deferred()
func run()->void:
	var app=Scene.instantiate();app.state=NoSave.new();app.view_preferences=NoPrefs.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false;app.world.set_process(false)
	app.toast_time=0;app.hud.quest_notice_time=0;app._process(0)
	for zoom in range(3):
		app.view_preferences.zoom_index=zoom;app._apply_view_zoom();app._sync_hud_navigation(true)
		var scale:float=app.view_zoom
		assert(app.world._navigation_target_visible(Vector2(640,715)/scale))
		assert(app.world._navigation_target_visible(Vector2(832,704)/scale))
		assert(not app.world._navigation_target_visible(Vector2(640,790)/scale))
		assert(not app.world._navigation_target_visible(Vector2(-10,400)/scale))
		for button:Button in app.hud.nav_buttons:
			assert(not app.world._navigation_target_visible(button.get_rect().get_center()/scale))
		for button in app.hud.system_bar.get_children():
			if button is Button:assert(not app.world._navigation_target_visible(button.get_rect().get_center()/scale))
		assert(not app.world._navigation_target_visible(app.hud.interaction.get_rect().get_center()/scale))
		for point in [Vector2(-100,-100),Vector2(640,900),Vector2(1280,900),Vector2(50,900)]:
			var arrow:Vector2=app.world._compass_edge(point/scale)
			var bubble=Rect2(arrow-Vector2(58,21)/scale,Vector2(116,72)/scale)
			for rect:Rect2 in app.world.hud_exclusion_rects:assert(not bubble.intersects(rect))
	app.world.teleport(Vector2(300,185));app._sync_hud_navigation(true)
	var npc:Vector2=app.world.interactables.elder.pos-app.world.camera_pos
	assert((npc*app.view_zoom).distance_to(Vector2(832,704))<.01)
	assert(app.world._quest_target_id()=="elder" and app.world._navigation_target_visible(npc))
	app.world.teleport(Vector2(900,695));npc=app.world.interactables.elder.pos-app.world.camera_pos
	assert(not app.world._navigation_target_visible(npc))
	app._toast("手记已写入");app._process(0)
	assert(not app.world._navigation_target_visible(Vector2(520,220)/app.view_zoom))
	app.toast_time=0;app._process(0);assert(app.world._navigation_target_visible(Vector2(520,220)/app.view_zoom))
	app.queue_free();await create_timer(.25).timeout
	print("PASS: visible quest target needs no duplicate compass, actual HUD control avoidance at all zooms and transient toast recovery");quit()
