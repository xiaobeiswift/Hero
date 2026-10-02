extends "res://tests/visual_heting_chapter.gd"
## Prepared loaded/unloaded maps; actual geometry computes each displayed route.
func run()->void:
	root.size=Vector2i(1280,800);app=Scene.instantiate();app.state=NoSave.new();app.view_preferences=NoWritePrefs.new()
	root.add_child(app);await process_frame;app._new_game();app._stop_audio();app.audio_on=false
	var s=app.state;s.quest_stage=6;s.ending="守望";s.choose_sect("听潮阁");s.gain_xp(600)
	s.mist_stage=4;s.mist_ending="warn_ferries";s.mist_gauges.assign(["rain","stone","basin"])
	s.bridge_repaired=true;s.tangqi_stage=3;s.tangqi_choice="teach";s.tangqi_unlocked=true;s.active_companion="唐栖"
	assert(s.begin_heting());app._travel("heting",Vector2(820,665));assert(s.take_heting_cargo("meal"))
	await chart_capture("260-heting-cart-map-west-connected")
	assert(s.set_heting_bridge("east"));await chart_capture("261-heting-cart-map-north-bypass")
	assert(s.park_heting_cargo());await chart_capture("262-heting-cart-map-walking-pier")
	assert(s.take_heting_cargo("sealed"));assert(s.set_heting_bridge("west"))
	root.size=Vector2i(1180,737);app.view_preferences.zoom_index=2;app._apply_view_zoom()
	await chart_capture("263-heting-cart-map-compact-east-target")
	app._stop_audio();app.queue_free();await create_timer(.25).timeout
	print("PASS: four actual-engine map captures; connected bridge, north bypass, walking-only pier and compact route");quit()

func chart_capture(name:String)->void:
	app._sync_world_state();app._process(0);app._refresh();app._show_map();await process_frame
	var chart=app.overlay.find_child("RegionChart",true,false)
	assert(chart!=null and chart.heting_cargo==app.state.heting_cargo)
	assert(chart.cart_route.is_empty()==app.state.heting_cargo.is_empty())
	var before=app.state.to_dict();await capture(name);assert(app.state.to_dict()==before)
	app._close_modal()
