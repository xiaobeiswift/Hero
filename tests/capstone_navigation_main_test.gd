extends SceneTree
## Prepared canonical main-scene navigation matrix. No earned progress or pixel claim.
const Scene=preload("res://scenes/main.tscn")
const State=preload("res://scripts/game_state.gd")
const Prefs=preload("res://scripts/view_preferences.gd")
const Fixture=preload("res://tests/capstone_world_fixture.gd")
const Nav=preload("res://scripts/volume_one_capstone_navigation.gd")
class NoSave extends State:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
class NoPrefs extends Prefs:
	func load_settings(_path:String=PATH)->Error:return OK
	func save_settings(_path:String=PATH)->Error:return OK
var checks:int=0
var failures:int=0
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures+=1;push_error(label)
func run()->void:
	if OS.get_environment("XDG_DATA_HOME").is_empty():quit(2);return
	var app=Scene.instantiate();app.state=NoSave.new();app.view_preferences=NoPrefs.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false;app.set_process(false);app.world.set_process(false)
	for stage:int in range(8):
		for map:String in Nav.MAPS:
			app.state=Fixture.state(stage);app.state.map_id=map
			app._sync_world_state();app.world.change_map(map,Vector2(500,450));app.state.position=app.world.player_pos
			var before:Dictionary=app.state.to_dict();var goal:Dictionary=State.Capstone.goal(app.state)
			var expected:String=Nav.target_id(goal,map)
			for full:bool in [true,false]:
				for zoom:int in range(3):
					app.view_preferences.full_resolution=full;app.view_preferences.zoom_index=zoom;app._apply_view_zoom();app._refresh()
					app.toast_time=0;app.hud.quest_notice_time=0;app._process(0)
					check(app.world.capstone_goal==goal and app.world.capstone_orders==State.Capstone.order_rows(app.state),"main sync projects model values")
					if stage<7:
						check(app.world._quest_target_id()==expected,"main world uses shared resolver at every map/zoom")
						check(app.quest_label.text==State.Capstone.TITLE and app.hint_label.text.contains(goal.objective),"HUD uses same objective")
						if map!=goal.map_id:check(app.hint_label.text.contains(app.world.get_npc_name(expected)),"cross-map HUD names same existing exit")
						if stage>0:check(app.chapter_header.text.contains("第一卷终章"),"active cross-map chapter heading")
					else:
						check(app.world.capstone_navigation().is_empty() and app.quest_label.text!=State.Capstone.TITLE,"completion restores ordinary tracking")
					app._show_map();var chart=app.overlay.find_child("RegionChart",true,false)
					check(chart!=null and chart.current_target==app.world._quest_target_id(),"real chart uses same world target")
					if chart!=null and not chart.current_target.is_empty():check(chart.markers.has(chart.current_target),"real chart contains marker")
					if map=="sluice":check(chart.markers.has("capstone_order_desk")==bool(stage>0),"real map desk presence correct")
					if map=="frostbridge":check(chart.markers.chapter_archive.name==app.world.get_npc_name("chapter_archive"),"real map archive occupant agrees")
					check(not app.modal_autosave_on_close,"map remains read-only")
					app._close_modal();check(app.state.to_dict()==before,"HUD/map repeated open/close changes no canonical fields")
					await process_frame
	# Completed goal must also leave real unstarted optional receipt available.
	app.state=Fixture.state(7);app.state.map_id="heting";app._sync_world_state();app.world.change_map("heting",Vector2(535,400));app._refresh()
	check(app.world._quest_target_id()==app.heting_story.target_id(),"completion returns actual Heting optional target")
	app._stop_audio();app.queue_free();await process_frame
	print("%s capstone_navigation_main: %d checks;8stages x5maps x3zooms x2render qualities, prepared main/HUD/map consumers"%["PASS" if failures==0 else "FAIL",checks]);quit(0 if failures==0 else 1)
