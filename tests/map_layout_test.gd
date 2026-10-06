extends SceneTree
const UnifiedUI = preload("res://tests/unified_ui_test_driver.gd")
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
func _initialize()->void:run.call_deferred()
func key(code:int)->void:
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event);await process_frame
	event=InputEventKey.new();event.physical_keycode=code;event.pressed=false;Input.parse_input_event(event);await process_frame
func click(point:Vector2)->void:
	var motion=InputEventMouseMotion.new();motion.position=point;root.push_input(motion,true);await process_frame
	for pressed in [true,false]:
		var event=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;root.push_input(event,true);await process_frame
func bounds(control:Control,relative:Control)->Rect2:
	return (relative.get_global_transform().affine_inverse()*control.get_global_transform())*Rect2(Vector2.ZERO,control.size)
func run()->void:
	var app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame;app._new_game();app._stop_audio();app.audio_on=false
	for region in ["qingwei","sluice","frostbridge","mistwood"]:
		app.state.map_id=region;app.world.change_map(region,Vector2(600,480));app.state.bridge_repaired=region=="frostbridge";app._sync_world_state()
		for window in [Vector2i(1280,800),Vector2i(1180,737)]:
			root.size=window;await process_frame;await key(KEY_M);await process_frame
			var page=app.overlay.find_child("DialogueSheet",true,false);var chart=page.find_child("RegionChart",true,false);var close=page.find_child("DialogueChoice1",true,false)
			assert(chart!=null and chart.map_id==region)
			var caption=page.find_child("MapGuidanceCaption",true,false)
			assert(caption!=null and caption.visible and not caption.text.is_empty())
			assert(chart.size==Vector2(780,330) and is_equal_approx(chart.scale.x,chart.scale.y) and chart.scale.x>1.0)
			var chart_bounds=bounds(chart,page);var caption_bounds=bounds(caption,page);var close_bounds=bounds(close,page)
			var title_bounds=bounds(page.find_child("DialogueTitle",true,false),page)
			assert(caption_bounds.end.y<chart_bounds.position.y and caption_bounds.position.y>title_bounds.end.y)
			assert(Rect2(Vector2.ZERO,page.size).encloses(caption_bounds) and Rect2(Vector2.ZERO,page.size).encloses(close_bounds))
			assert(not caption_bounds.intersects(chart_bounds) and not caption_bounds.intersects(close_bounds))
			assert(Rect2(Vector2.ZERO,app.overlay.size).encloses(bounds(page,app.overlay)))
			assert(Rect2(Vector2.ZERO,page.size).encloses(chart_bounds))
			assert(chart_bounds.position.y>=title_bounds.end.y+20)
			assert(not chart_bounds.intersects(close_bounds) and chart_bounds.end.y+10<close_bounds.position.y)
			assert(page.find_child("DialogueBody",true,false)==null)
			assert(chart.markers==app.world.interactables and chart.player_position==app.world.player_pos and chart.current_target==app.world._quest_target_id())
			assert(chart.bridge_repaired==app.state.bridge_repaired)
			var before=app.state.to_dict();var player:Vector2=app.world.player_pos
			await click(chart.get_global_rect().get_center());assert(app.active_modal and app.world.player_pos==player and app.state.to_dict()==before)
			var stale:Callable=app.modal_actions[0]
			await key(KEY_ESCAPE);assert(not app.active_modal)
			await key(KEY_M);await process_frame
			stale.call();assert(app.active_modal)
			await key(KEY_ENTER);assert(not app.active_modal)
			await key(KEY_M);await key(KEY_1);assert(not app.active_modal)
	root.size=Vector2i(1280,800);await process_frame;await key(KEY_M);await process_frame
	var close=app.overlay.find_child("DialogueChoice1",true,false);await click(close.get_global_rect().get_center());assert(not app.active_modal)
	app._modal("短句测试","对话 / 保留紧凑阅读","山水有相逢。")
	await process_frame;assert(app.overlay.find_child("DialogueSheet",true,false).size.y==365)
	app._close_modal();UnifiedUI.open_training(app);await key(KEY_M);assert(UnifiedUI.active(app) and app.current_screen=="party_battle")
	app.battle_presentation_enabled=false;UnifiedUI.leave(app);app._close_modal();app._stop_audio();app.queue_free();await create_timer(.25).timeout
	print("PASS: four region charts fit their paper at both window sizes, controls remain unobstructed, real mouse/keyboard and stale callbacks preserve read-only behavior");quit()
