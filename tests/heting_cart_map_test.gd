extends "res://tests/audit_heting_current_test.gd"
const Routes=preload("res://scripts/heting_cart_routes.gd")
func _map_bounds(control:Control,relative:Control)->Rect2:
	return (relative.get_global_transform().affine_inverse()*control.get_global_transform())*Rect2(Vector2.ZERO,control.size)
func _run()->void:
	fixture="user://heting-chart-%d-%d"%[OS.get_process_id(),Time.get_ticks_usec()]
	_check(DirAccess.make_dir_recursive_absolute(fixture)==OK,"Create isolated map fixture")
	store=Slots.new(fixture);state_probe=RoutedState.new();state_probe.directory=fixture
	game=CloseProbe.new();game.state=state_probe;root.add_child(game);game.save_slots.store=store
	await process_frame;game.world.set_process(false);game._stop_audio();game.audio_on=false
	for side in ["west","east"]:
		for cargo in ["","meal","sealed"]:
			for window_size in [Vector2i(1280,800),Vector2i(1180,737)]:
				for zoom in range(3):
					_port(1,cargo,"",side);root.size=window_size;game.view_preferences.zoom_index=zoom;game._apply_view_zoom()
					var before=state_probe.to_dict();var writes=state_probe.writes
					await _key(KEY_M);await process_frame
					var page=game.overlay.find_child("DialogueSheet",true,false)
					var chart=page.find_child("RegionChart",true,false);var close=page.find_child("DialogueChoice1",true,false)
					_check(chart.heting_bridge==side and chart.heting_cargo==cargo,"Map receives actual current bridge and cargo")
					var chart_bounds=_map_bounds(chart,page);var close_bounds=_map_bounds(close,page)
					_check(Rect2(Vector2.ZERO,page.size).encloses(chart_bounds) and not chart_bounds.intersects(close_bounds),"Transformed route chart fits paper without hiding its close action")
					if cargo.is_empty():
						_check(chart.cart_route.is_empty(),"Walking map does not advertise a cart route")
					else:
						var target=chart.markers[chart.current_target].pos
						_check(not chart.cart_route.is_empty() and chart.cart_route[0]==game.world.player_pos and chart.cart_route[-1]==target,"Displayed route joins actual player and current cargo receiver")
						for i in range(chart.cart_route.size()):
							_check(chart.MAP_RECT.has_point(chart._point(chart.cart_route[i])),"Every route vertex stays inside map viewport")
							if i>0:_check(Port.can_step(chart.cart_route[i-1],chart.cart_route[i],side,true),"Actual chart never crosses closed water or walking-only pier")
					await _mouse(chart.get_global_rect().get_center(),true);await _mouse(chart.get_global_rect().get_center(),false)
					_check(state_probe.to_dict()==before and state_probe.writes==writes and game.active_modal,"Clicking route does not teleport, deliver, adjust bridge or save")
					await _key(KEY_1);_check(not game.active_modal,"Original numbered map close remains available")
	# Reopen after a real free bridge adjustment, not just injected chart values.
	_port(1,"meal","","east");await _talk("heting_winch");_press("改接西岸")
	await _key(KEY_M);await process_frame
	var chart=game.overlay.find_child("RegionChart",true,false)
	_check(chart.heting_bridge=="west" and chart.cart_route==Routes.route(game.world.player_pos,Port.points().heting_relief.pos,"west"),"Reopened chart recomputes actual adjusted bridge connectivity")
	await _key(KEY_ESCAPE)
	_check(state_probe.heting_cargo=="meal" and state_probe.heting_bridge=="west","Map Escape keeps cargo and free bridge choice")
	game._stop_audio();game.queue_free();await process_frame;_remove_fixture(fixture)
	if failures==0:print("PASS: %d loaded-cart chart/input/viewport checks"%checks)
	else:push_error("FAIL: %d of%d loaded-cart chart checks"%[failures,checks])
	quit(0 if failures==0 else 1)
