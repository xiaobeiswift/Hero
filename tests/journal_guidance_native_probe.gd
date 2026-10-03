extends SceneTree
## Native actual-scene acceptance. Genuine State; prepared retained inputs are
## explicitly separated from queued-input earned movement/progression.
const State = preload("res://scripts/game_state.gd")
const Objectives = preload("res://scripts/journal_objective_rules.gd")
var app
var out_dir: String = ""
var mode: String = "matrix"
var checks: int = 0
var failures: Array[String] = []
var captures: Array[Dictionary] = []
var inputs: Array[Dictionary] = []
var walks: Array[Dictionary] = []
var case_id: String = "startup"
var requested_size = Vector2i(1280,800)
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(case_id+": "+label); push_error(case_id+": "+label)
func frames(n: int = 3) -> void:
	for i: int in n: await process_frame
func folio(): return app.overlay.get_meta("journal_ui") if app.overlay.has_meta("journal_ui") else null
func key_event(code: int, down: bool, shift: bool = false) -> void:
	var event = InputEventKey.new(); event.physical_keycode=code; event.keycode=code; event.pressed=down; event.shift_pressed=shift
	Input.parse_input_event(event); Input.flush_buffered_events()
func tap(code: int, shift: bool = false) -> void:
	inputs.append({"kind":"queued_native_key", "key":OS.get_keycode_string(code), "shift":shift})
	key_event(code,true,shift); await frames(1); key_event(code,false,shift); await frames(2)
func pointer(control: Control, press: bool = true, wheel: int = 0) -> void:
	var point: Vector2 = root.get_final_transform()*control.get_global_rect().get_center()
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;Input.parse_input_event(motion);Input.flush_buffered_events();await frames(1)
	if not press:return
	for down: bool in [true,false]:
		var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=wheel if wheel>0 else MOUSE_BUTTON_LEFT;event.pressed=down
		Input.parse_input_event(event);Input.flush_buffered_events();await frames(1)
	inputs.append({"kind":"queued_native_mouse", "node":str(control.name) if is_instance_valid(control) else "rebuilt", "wheel":wheel, "pixel_point":[point.x,point.y]})
	await frames(2)
func focus_control(control: Control) -> void:
	for i: int in 45:
		if root.gui_get_focus_owner()==control:return
		await tap(KEY_TAB)
	check(false,"Keyboard Tab reaches requested control")
func disk(path: String = "user://") -> Dictionary:
	var result:Dictionary={}
	var dir=DirAccess.open(path)
	if dir==null:return result
	for file: String in dir.get_files():result[path+"/"+file]=FileAccess.get_sha256(path+"/"+file)
	for folder: String in dir.get_directories():result.merge(disk(path+"/"+folder))
	return result
func apply_state(s, label: String) -> void:
	app.current_screen="explore";app.active_modal=false;app._clear_overlay();app.state=s;app._apply_loaded_state("Native prepared input")
	app._refresh();await frames()
	check(app.state.get_script()==State,"Exact production HeroState")
	inputs.append({"kind":"explicit_prepared_fixture", "label":label,"canonical":app.state.to_dict(),"world_position":[app.world.player_pos.x,app.world.player_pos.y],"not_walked":true})
func from_oracle(label: String) -> void:
	var corpus=JSON.parse_string(FileAccess.get_file_as_string("res://tests/journal_guidance_frozen_oracle.json"))
	for row: Dictionary in corpus.rows:
		if row.label!=label:continue
		var result=State.new().inspect_save_bytes(JSON.stringify({"version":16,"player":row.state}).to_utf8_buffer())
		check(result.ok,"Prepared oracle accepted by actual reader: "+label)
		if result.ok:await apply_state(result.state,label)
		return
	check(false,"Known oracle label: "+label)
func from_retained(label: String) -> void:
	var bundle=JSON.parse_string(FileAccess.get_file_as_string("res://tests/journal_guidance_baseline_inputs.json"))
	for row: Dictionary in bundle.fixtures:
		if row.label!=label:continue
		var bytes: PackedByteArray=String(row.input_utf8).to_utf8_buffer()
		check(bytes.size()==int(row.input_bytes) and String(row.input_utf8).sha256_text()==row.input_sha256,"Exact API-earned/PCK-accepted fixture bytes")
		var result=State.new().inspect_save_bytes(bytes)
		check(result.ok,"Actual production reader accepts retained earned fixture")
		if result.ok:await apply_state(result.state,"retained exact baseline "+label)
		return
	check(false,"Known retained fixture")
func agree(target: String) -> void:
	var snap:Dictionary=app.journal_guidance_snapshot
	check(snap.next_target_id.is_empty() or not String(snap.route_note).contains("暂无可标出的下一处"),"Valid local target never carries contradictory no-target prose")
	check(snap.next_target_id==target and app.world._quest_target_id()==target,"Literal expected local target on host/world: "+target)
	check(app.hud.journal_guidance_snapshot==snap and app.world.journal_guidance_snapshot==snap,"HUD/world receive coherent exact snapshot")
	if is_instance_valid(folio()):check(folio().guidance_snapshot==snap,"J current strip equals exact snapshot")
func rect_array(rect: Rect2) -> Array:return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
func node_record(node: Control) -> Dictionary:
	var visible_rect:Rect2=node.get_global_rect()
	var ancestor:Node=node.get_parent()
	while ancestor!=null:
		if ancestor is Control and ancestor.clip_contents:visible_rect=visible_rect.intersection(ancestor.get_global_rect())
		ancestor=ancestor.get_parent()
	var r:Dictionary={"name":str(node.name),"logical_rect":rect_array(node.get_global_rect()),"pixel_rect":rect_array(root.get_final_transform()*node.get_global_rect()),"visible_pixel_rect":rect_array(root.get_final_transform()*visible_rect),"focus":node.has_focus(),"visible":node.is_visible_in_tree() and visible_rect.has_area()}
	if node is Label:r.text=node.text;r.ink=node.get_theme_color("font_color").to_html(false);r.font_size=node.get_theme_font_size("font_size")
	if node is RichTextLabel:r.text=node.text;r.ink=node.get_theme_color("default_color").to_html(false);r.font_size=node.get_theme_font_size("normal_font_size");r.scroll=node.get_v_scroll_bar().value;r.scroll_max=node.get_v_scroll_bar().max_value;r.scroll_page=node.get_v_scroll_bar().page;r.selected_text=node.get_selected_text();r.selected_ink=node.get_theme_color("font_selected_color").to_html(false)
	if node is Button:r.text=node.text;r.disabled=node.disabled;r.ink=node.get_theme_color("font_disabled_color" if node.disabled else "font_color").to_html(false);r.font_size=node.get_theme_font_size("font_size")
	return r
func controls_under(node:Node) -> Array[Dictionary]:
	var rows:Array[Dictionary]=[]
	if node is Control:rows.append(node_record(node))
	for child:Node in node.get_children():rows.append_array(controls_under(child))
	return rows
func geometry() -> void:
	var j=folio()
	if not is_instance_valid(j):return
	var frame=j.find_child("JournalFrame",true,false)
	check(Rect2(0,0,1280,800).encloses(frame.get_global_rect()),"Folio and fixed close/footer are inside UI canvas")
	for key:String in j.action_buttons:
		var b:Button=j.action_buttons[key]
		if key=="completed":continue
		check(frame.get_global_rect().encloses(b.get_global_rect()),"Accessible footer/header hit rect: "+key)
		check(b.get_minimum_size().x<=b.size.x and b.get_minimum_size().y<=b.size.y,"Action caption fits: "+key)
	var body_rect:Rect2=j.body.get_global_rect()
	check(not body_rect.intersects(j.action_buttons.close.get_global_rect()),"Scrollable body never covers fixed close")
	var focus:Control=root.gui_get_focus_owner()
	check(focus!=null and j.is_ancestor_of(focus),"Visible J-owned keyboard focus")
	if focus!=null and focus.has_meta("journal_row"):
		check(j._list_scroll.get_global_rect().grow(1.0).encloses(focus.get_global_rect()),"Focused row scrolls fully into visible list")
func capture(name: String, note: String) -> void:
	await frames(3)
	await RenderingServer.frame_post_draw
	geometry()
	var image:Image=root.get_texture().get_image()
	check(image.save_png(out_dir+"/screenshots/"+name+".png")==OK,"Native framebuffer PNG: "+name)
	var row:Dictionary={"name":name,"note":note,"requested_window":[requested_size.x,requested_size.y],"actual_framebuffer":[image.get_width(),image.get_height()],"actual_window":[root.size.x,root.size.y],"zoom":app.view_zoom,"full_resolution":app.view_preferences.full_resolution,"state":app.state.to_dict(),"snapshot":app.journal_guidance_snapshot.duplicate(true),"world_target":app.world._quest_target_id(),"world_position":[app.world.player_pos.x,app.world.player_pos.y],"controls":controls_under(app.overlay),"userdata":disk()}
	if is_instance_valid(folio()):row.page=folio().page;row.browse=folio().browse_arc_id;row.tracked=app.journal_session.tracked_arc_id;row.catalog=app.journal_catalog();row.focus_path=str(root.gui_get_focus_owner().get_path())
	captures.append(row);report(false)
func view(size:Vector2i, zoom_index:int, full:bool) -> void:
	requested_size=size;root.size=size;app.view_preferences.full_resolution=full;app.view_preferences.zoom_index=zoom_index;app._apply_view_zoom();await frames(4)
func matrix() -> void:
	case_id="prepared_native_matrix"
	await view(Vector2i(1280,800),0,true)
	await from_retained("preaccept_open_records_release_water")
	check(app.state.save_game()==OK,"Preparation baseline saved through genuine writer")
	await tap(KEY_J);agree("mist_rain_gauge")
	var before:Dictionary=app.state.to_dict().duplicate(true);var files:Dictionary=disk();var anchor:Vector2=app.world.player_pos
	await tap(KEY_ENTER)
	check(app.active_modal and app.journal_session.tracked_arc_id.is_empty(),"Initial row Enter browses without track/close")
	await pointer(folio().row_buttons.tang_notes)
	check(folio().browse_arc_id=="tang_notes" and app.journal_session.tracked_arc_id.is_empty(),"Mouse browse Tang leaves auto Qin")
	await capture("01-auto-qin-browse-tang","Prepared API-earned input; current automatic Qin differs explicitly from browsed Tang. Actual pointer input.")
	await pointer(folio().row_buttons.qin_rope)
	await focus_control(folio().action_buttons.track);await tap(KEY_ENTER)
	check(app.journal_session.tracked_arc_id=="qin_rope","Keyboard Track activates exactly selected Qin")
	await pointer(folio().row_buttons.tang_notes)
	for size:Vector2i in [Vector2i(1280,800),Vector2i(1180,737)]:
		for z:int in 3:
			for quality:bool in [true,false]:
				await view(size,z,quality);await focus_control(folio().action_buttons.track)
				await capture("matrix-%dx%d-z%d-%s"%[size.x,size.y,z,"full" if quality else "scaled"],"Prepared genuine-State native scene: Qin explicitly tracked, Tang only browsed; focus on explicit Track action. Fixed-step scripted inputs, no manual/realtime/browser claim.")
	await view(Vector2i(1280,800),0,true)
	await focus_control(folio().action_buttons.track);await tap(KEY_SPACE)
	check(app.journal_session.tracked_arc_id=="tang_notes","Space on Track selects Tang once and retains J")
	agree("return_frostbridge")
	await capture("02-manual-tang-disabled-track","Explicit Track selected Tang; Track is now disabled, focus moved to enabled Auto; diamond and text identify tracking")
	for code:int in [KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_E,KEY_M,KEY_F5,KEY_F9,KEY_F6,KEY_F10,KEY_B,KEY_I,KEY_K,KEY_EQUAL,KEY_MINUS]:await tap(code)
	check(is_instance_valid(folio()) and folio().page=="journal" and app.journal_session.tracked_arc_id=="tang_notes","All global/numeric shortcuts consumed inert")
	check(app.view_zoom==1.0 and app.view_preferences.full_resolution,"Zoom/quality keys cannot leak")
	await focus_control(folio().action_buttons.history);await tap(KEY_ENTER)
	check(folio().page=="history","Keyboard history opens once")
	var sections:Array[String]=[]
	for row:Dictionary in app.journal_catalog():
		if not String(row.earned_history).is_empty():sections.append(String(row.display_title)+" · "+String(folio().STATUS_NAMES[row.status])+"\n"+String(row.earned_history))
	check(folio().body.text=="\n\n────────────────\n\n".join(sections),"Actual history text contains exactly known earned catalog histories")
	var history_before:float=folio().body.get_v_scroll_bar().value
	await tap(KEY_PAGEDOWN)
	check(folio().body.get_v_scroll_bar().value>history_before,"Actual PageDown scrolls earned history")
	await pointer(folio().body,true,MOUSE_BUTTON_WHEEL_DOWN)
	await capture("03-history-scroll","All-earned history after keyboard PageDown and actual mouse wheel; no future/locked rows")
	await tap(KEY_END);var end_scroll:float=folio().body.get_v_scroll_bar().value;await tap(KEY_HOME)
	check(end_scroll>folio().body.get_v_scroll_bar().value,"End/Home scroll history independently")
	folio().body.select_all() # Prepared rendering-only selection; actual keyboard/wheel already exercised.
	await capture("03b-history-selected-text","Prepared select-all visual treatment on genuine native RichTextLabel, distinct from actual keyboard and wheel scroll evidence")
	await tap(KEY_ESCAPE);check(folio().page=="journal","History Esc returns exactly once")
	for i:int in 28:
		await tap(KEY_TAB,i%2==0);check(folio().is_ancestor_of(root.gui_get_focus_owner()),"Tab/ShiftTab trapped "+str(i))
	await focus_control(folio().action_buttons.auto);await tap(KEY_ENTER);agree("mist_rain_gauge")
	check(app.journal_session.tracked_arc_id.is_empty(),"Explicit Auto restores Qin")
	check(app.state.to_dict()==before and disk()==files and app.world.player_pos==anchor,"All browsing/input/matrix actions preserve complete canonical state, position and every real userdata byte")
	await tap(KEY_ESCAPE);await tap(KEY_M)
	var chart=app.overlay.find_child("RegionChart",true,false)
	check(chart!=null and chart.current_target=="mist_rain_gauge" and chart.journal_guidance_snapshot==app.journal_guidance_snapshot,"M agrees with Qin host/HUD/world snapshot")
	await capture("04-map-coherent-auto-qin","Read-only M current target equals automatic Qin. Existing map owns its ordinary close input.")
	await tap(KEY_1)
	await expanded_cases()
func expanded_cases() -> void:
	case_id="prepared_catalog_histories"
	await from_oracle("capstone_5_heting")
	await tap(KEY_J);await pointer(folio().row_buttons.capstone);await view(Vector2i(1180,737),2,false)
	await capture("05-capstone-long-compact","Prepared long capstone instructions; actual compact window, zoom1.6, scaled quality, scrollable detail")
	await tap(KEY_ESCAPE)
	await from_oracle("capstone_7_heting")
	var s=app.state
	s.bridge_repaired=true;s.receipt_stage=3;s.level=3;s.sect="听潮阁";s.sect_rank=2;s.sect_trial_won=true;s.lightness_unlocked=true;s.lightness_relics.assign(["reed_islet"])
	if not s.companion_unlocked:check(s.recruit_companion(),"Prepared complete catalog canonical Shen recruitment")
	s.shen_care_stage=5;s.shen_care_choice="shore";s.tangqi_stage=3;s.tangqi_choice="teach"
	if not s.tangqi_unlocked:check(s.recruit_tangqi(),"Prepared complete catalog canonical Tang recruitment")
	s.map_id="mistwood";s.qin_stage=3
	if not s.qin_unlocked:check(s.recruit_qin(),"Prepared complete catalog canonical Qin recruitment")
	var valid=State.new().inspect_save_bytes(JSON.stringify({"version":16,"player":s.to_dict()}).to_utf8_buffer())
	check(valid.ok,"Prepared 14-earned-row/four-actor state passes unchanged production reader")
	if not valid.ok:return
	await apply_state(valid.state,"explicit prepared full catalog via canonical recruit APIs, not organic journey")
	check(app.journal_catalog().size()==14,"Exactly14 known earned topics")
	await tap(KEY_J);await pointer(folio().action_buttons.completed)
	check(folio().row_buttons.size()==14,"Expanded completed group exposes all14 known rows")
	await pointer(folio().row_buttons.opening);await tap(KEY_END)
	check(folio().browse_arc_id=="mentor_reward","List End selects final earned row and scrolls it into view")
	check(folio().action_buttons.track.disabled,"Completed row cannot Track")
	await capture("06-fourteen-earned-rows-completed","Prepared all14 earned catalog; End scrolls final completed row into view; Track disabled; no hidden denominator")
	await focus_control(folio().action_buttons.history);await tap(KEY_ENTER);await tap(KEY_END)
	await capture("07-all-history-bottom","Prepared all14 earned histories; last lines reachable with keyboard End; completed permanent record")
	await tap(KEY_ESCAPE);await tap(KEY_ESCAPE)
	await view(Vector2i(1280,800),0,true)
	await capture("08-four-deployed-actors","Prepared canonical recruit APIs produce four deployed actors; free-exploration guidance does not falsely track a completed row")
	for branch:String in ["preaccept_open_records_release_water","preaccept_protect_witness_warn_ferries"]:
		await from_retained(branch);await tap(KEY_J);await pointer(folio().action_buttons.history)
		await capture("history-"+branch,"Exact retained API-earned branch histories, no invented completion or reward content")
		await tap(KEY_ESCAPE);await tap(KEY_ESCAPE)
	await from_oracle("harbor_overlap_1_4")
	await tap(KEY_J);await pointer(folio().row_buttons.qin_rope);await focus_control(folio().action_buttons.track);await tap(KEY_ENTER)
	check(folio().guidance_snapshot.route_status=="departure_confirmation","Loaded remote target shows explicit parking requirement")
	await capture("09-loaded-cart-parking-note","Prepared loaded cart, explicit available Qin tracking: departure confirmation note is readable; J has not moved or parked cargo")
	await tap(KEY_ESCAPE);await tap(KEY_M);await view(Vector2i(1180,737),2,false)
	await capture("10-loaded-cart-map-compact","Loaded route and explicit parking caption, compact client; M shares physical target and path")
	await tap(KEY_ESCAPE)
	await from_oracle("opening_0");await tap(KEY_J)
	check(folio().row_buttons.keys()==["opening"] and app.journal_catalog().size()==1,"Fresh opening shows only earned opening row, no locked placeholders")
	await capture("11-fresh-no-spoilers","Fresh opening: only known story, no hidden future quest names or denominator")
	await tap(KEY_ESCAPE)
	case_id="genuine_save_warning"
	check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(State.SAVE_PATH+".tmp"))==OK,"Create explicit isolated writer-failure fixture")
	app._save()
	check(app.save_warning,"Real production writer failure creates save warning")
	var warning_state:Dictionary=app.state.to_dict().duplicate(true);var warning_files:Dictionary=disk()
	await tap(KEY_J);await tap(KEY_ENTER);await tap(KEY_ESCAPE)
	check(app.save_warning and app.state.to_dict()==warning_state and disk()==warning_files,"Read-only J preserves real save warning and original disk/state")
	await view(Vector2i(1280,800),0,true)
	await capture("12-preserved-real-save-warning","Actual production save failure caused by explicitly prepared temporary-path directory; warning remains after J browse/close. Fresh isolated userdata only.")
	check(DirAccess.rename_absolute(ProjectSettings.globalize_path(State.SAVE_PATH+".tmp"),ProjectSettings.globalize_path("user://native-retained-save-blocker"))==OK,"Retain blocker fixture under another name")
	app._save();check(not app.save_warning,"Actual explicit retry succeeds after retaining isolated blocker elsewhere")
func walk_to(point:Vector2, label:String) -> void:
	var start:Vector2=app.world.player_pos;var segments:Array=[];var stuck:int=0
	for i:int in 1000:
		var pos:Vector2=app.world.player_pos;var diff:Vector2=point-pos
		if diff.length()<10.0:break
		var right=diff.x>5.0;var left=diff.x< -5.0;var down=diff.y>5.0;var up=diff.y< -5.0
		for pair:Array in [[KEY_D,right],[KEY_A,left],[KEY_S,down],[KEY_W,up]]:key_event(pair[0],pair[1])
		await frames(1)
		var next:Vector2=app.world.player_pos
		if next==pos:stuck+=1
		else:stuck=0
		check(app.world._can_step(pos,next),"Actual collision-legal movement segment")
		segments.append({"from":[pos.x,pos.y],"to":[next.x,next.y],"legal":app.world._can_step(pos,next)})
		if stuck>25:check(false,"Actual queued movement blocked: "+label);break
	for code:int in [KEY_D,KEY_A,KEY_S,KEY_W]:key_event(code,false)
	await frames(2)
	check(app.world.player_pos.distance_to(point)<10.0,"Actual walk reaches bounded waypoint: "+label)
	walks.append({"label":label,"map":app.state.map_id,"start":[start.x,start.y],"requested":[point.x,point.y],"finish":[app.world.player_pos.x,app.world.player_pos.y],"segments":segments,"input":"queued physical WASD, normal World._process at fixed30fps; no position assignment/teleport"})
	report(false)
func earned_route() -> void:
	case_id="bounded_earned_route"
	await view(Vector2i(1280,800),0,true);await from_retained("preaccept_open_records_release_water")
	var original:Dictionary=app.state.to_dict().duplicate(true)
	check(app.state.qin_stage==1 and app.state.tangqi_stage==1 and not app.state.qin_unlocked and not app.state.tangqi_unlocked,"Exact initial API-earned pending overlap")
	agree("mist_rain_gauge")
	await tap(KEY_J);await pointer(folio().row_buttons.tang_notes)
	check(app.journal_session.tracked_arc_id.is_empty(),"Earned journey Tang browse leaves Qin auto")
	await tap(KEY_ESCAPE)
	for p:Vector2 in [Vector2(380,470),Vector2(488,423),Vector2(550,347),Vector2(550,280)]:await walk_to(p,"Qin rain approach")
	check(app.world.nearby_id=="mist_rain_gauge","Actual walking reaches Qin rain interaction")
	await capture("route-01-walked-qin-target","Actual collision-checked WASD walk from retained prepared guide position to automatic Qin target; no route teleport")
	await tap(KEY_E);check(app.active_modal,"Actual E opens Qin rope dialogue")
	await tap(KEY_1)
	check(app.state.qin_stage==2 and app.state.tangqi_stage==1 and not app.state.qin_unlocked and not app.state.tangqi_unlocked,"Actual existing story choice earns Qin1→2, no recruit/Tang progress")
	agree("mist_camp")
	await tap(KEY_J);await pointer(folio().row_buttons.tang_notes);await focus_control(folio().action_buttons.track);await tap(KEY_ENTER);agree("return_frostbridge")
	await capture("route-02-earned-qin-manual-tang","Qin rope action now genuinely earned through E/1; explicit Tang tracking changes all consumers to legal Frost exit")
	await tap(KEY_ESCAPE)
	for p:Vector2 in [Vector2(550,347),Vector2(488,423),Vector2(380,470),Vector2(288,550),Vector2(190,550)]:await walk_to(p,"Tang tracked exit approach")
	check(app.world.nearby_id=="return_frostbridge","Actual walking reaches manually tracked exit")
	await tap(KEY_E);await frames(5)
	check(app.state.map_id=="frostbridge" and app.world.map_id=="frostbridge" and app.journal_session.tracked_arc_id=="tang_notes","Actual E travel preserves same manual Tang identity")
	agree("return_sluice")
	await tap(KEY_J);await focus_control(folio().action_buttons.auto);await tap(KEY_ENTER)
	check(app.journal_session.tracked_arc_id.is_empty() and app.journal_guidance_snapshot.mode=="auto" and app.journal_guidance_snapshot.arc_id=="tang_notes","Auto on Frost restores original local policy Tang, not a global Qin override")
	agree("return_sluice")
	await capture("route-03-frost-auto-restored","Actual exit travel applied; restoring Auto follows retained Frost HUD authority (Tang→Sluice), while Qin remains earned and selectable")
	await tap(KEY_ESCAPE);await tap(KEY_M)
	var chart=app.overlay.find_child("RegionChart",true,false)
	check(chart.current_target=="return_sluice" and chart.journal_guidance_snapshot==app.journal_guidance_snapshot,"Post-travel M equals new auto snapshot")
	await tap(KEY_ESCAPE)
	var final:Dictionary=app.state.to_dict();var changed:Array=[]
	for key:String in original:
		if original[key]!=final[key]:changed.append(key)
	check(changed.size()==3 and changed.has("position") and changed.has("map_id") and changed.has("qin_stage"),"Complete state delta limited to actual Qin progress, movement and map transfer")
	inputs.append({"kind":"earned_route_state_delta","changed_fields":changed,"before":original,"after":final,"userdata":disk(),"initial_history":"exact retained API-earned/PCK-accepted fixture","walked_this_run":true})
func report(final:bool) -> void:
	var file=FileAccess.open(out_dir+("/NATIVE-TRACE.json" if final else "/progress.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"Actual native Linux Godot Main+production HeroState. Explicit prepared retained state matrix; separate bounded WASD/E/1 earned route. Fresh HOME/XDG, fixed30fps, synthetic input; no full-new-game/manual/browser/Windows/package/audio/performance claim.","mode":mode,"checks":checks,"failures":failures,"engine":Engine.get_version_info(),"display_server":DisplayServer.get_name(),"captures":captures,"inputs":inputs,"walks":walks,"main_and_world_processing":[app.is_processing(),app.world.is_processing()]},"\t"));file.close()
func run() -> void:
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):out_dir=arg.trim_prefix("--out=")
		if arg.begins_with("--mode="):mode=arg.trim_prefix("--mode=")
	if out_dir.is_empty() or OS.get_environment("HOME").is_empty() or OS.get_environment("XDG_DATA_HOME").is_empty() or DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(out_dir+"/screenshots")
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await frames();app._stop_audio();app.audio_on=false
	check(app.get_script()==load("res://scripts/main.gd"),"Exact actual Main scene, no override or NoSave substitute")
	if mode=="matrix":await matrix()
	else:await earned_route()
	check(app.is_processing() and app.world.is_processing(),"Main and World normal processing stayed enabled")
	report(true);print("NATIVE ",mode,": ",checks," checks, ",failures.size()," failures, ",captures.size()," images")
	app._stop_audio();app.queue_free();await frames(2);quit(0 if failures.is_empty() else 1)
