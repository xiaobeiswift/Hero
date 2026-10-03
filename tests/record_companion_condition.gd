extends "res://tests/unified_combat_ui_test.gd"
## Eight actual full-game framebuffer captures. Explicit recruited/resource fixture,
## real Godot input events, immutable HUD projection checks, isolated save bytes.
## No follower cache/pose assignments, generated images, manual-play or FPS claims.
var evidence_dir := ""
var source_manifest := ""
var source_identity := ""
var capture_mode := "validate"
var runtime_hashes: Dictionary = {}
var captures: Array[Dictionary] = []
var input_trace: Array[Dictionary] = []
var checkpoints: Array[Dictionary] = []
var saved_bytes: PackedByteArray
var saved_write_count := 0
var baseline: Dictionary = {}
var initial_resources: Dictionary = {}
var strip

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): evidence_dir=argument.trim_prefix("--out=")
		if argument.begins_with("--manifest="): source_manifest=argument.trim_prefix("--manifest=")
		if argument.begins_with("--source="): source_identity=argument.trim_prefix("--source=")
		if argument.begins_with("--mode="): capture_mode=argument.trim_prefix("--mode=")
	if evidence_dir.is_empty() or source_manifest.is_empty() or source_identity.is_empty() or OS.get_environment("XDG_DATA_HOME").is_empty():
		push_error("Explicit isolated paths and source identity required"); quit(2); return
	runtime_hashes=JSON.parse_string(FileAccess.get_file_as_string(source_manifest))
	_verify_source()
	DirAccess.make_dir_recursive_absolute(evidence_dir+"/screenshots")
	fixture="user://condition-%d"%OS.get_process_id();DirAccess.make_dir_recursive_absolute(fixture)
	s=State.new();s.fixture=fixture
	app=load("res://scenes/main.tscn").instantiate();app.set_script(CloseProbe);app.state=s
	root.add_child(app);await process_frame
	app._stop_audio();app.audio_on=false;app.set_process(false);app.world.set_process(false)
	_setup("heting_receipt",4)
	strip=app.hud.companion_condition
	check(is_instance_valid(strip),"Integrated compact condition component exists")
	if not is_instance_valid(strip):quit(2);return
	# Prepared low-resource state only. Displayed numbers/statuses are read from
	# GameState.party_resource_snapshot(), never supplied to the presentation.
	var original:Dictionary=s.party_resource_snapshot()
	var shen:Dictionary=_actor(original,"shen")
	var tang:Dictionary=_actor(original,"tang")
	var qin:Dictionary=_actor(original,"qin")
	s.party_resources.shen={"hp":maxi(1,floori(float(shen.max_hp)*.18)),"qi":int(shen.max_qi)}
	s.party_resources.tang={"hp":int(tang.max_hp),"qi":1}
	s.party_resources.qin={"hp":0,"qi":maxi(1,floori(float(qin.max_qi)*.5))}
	check(s._stage_save_data(s.to_dict(),s.SAVE_VERSION).ok,"Explicit lowHP/lowQi/downed fixture is canonical")
	root.size=Vector2i(1280,800)
	_relocate(Vector2(600,455))
	app._refresh();await _settle()
	initial_resources=s.party_resource_snapshot().duplicate(true)
	check(s.save_game()==OK,"Explicit isolated baseline save written")
	saved_bytes=FileAccess.get_file_as_bytes(fixture+"/save.json");saved_write_count=s.writes
	baseline=s.to_dict().duplicate(true)
	await _move_mouse(Vector2(760,450))
	root.gui_release_focus();await _settle()
	_check_projection(["shen","tang","qin"],"full selected three")
	check(strip.cards.qin.status.text.contains("倒下"),"Zero HP has explicit 倒下 text")
	await _capture("01-prepared-full-lowhp-lowqi-downed-1280x800")

	await _hover(strip.cards.shen.button)
	check(strip.detail_panel.visible,"Actual mouse motion opens companion detail")
	_check_detail("shen")
	await _capture("02-prepared-hover-lowhp-detail-1280x800")
	_check_read_only("hover full roster")

	await _move_mouse(Vector2(760,450));root.gui_release_focus();await _settle()
	await _tab_to(strip.cards.qin.button)
	check(strip.cards.qin.button.has_focus(),"Actual Tab navigation reaches downed companion")
	check(strip.detail_panel.visible,"Keyboard focus shows readable companion detail")
	_check_detail("qin")
	await _capture("03-prepared-keyboard-downed-detail-1280x800")
	_check_read_only("keyboard focus full roster")

	await _move_mouse(Vector2(760,450));root.gui_release_focus();await _settle()
	await _click_event(strip.roster_button)
	check(app.current_screen=="explore" and app.active_modal and app.overlay.has_meta("party_roster"),"Actual strip entry click opens existing roster")
	await _settle()
	await _capture("04-prepared-direct-roster-1280x800")
	_check_read_only("direct roster opened")
	await _send_key(KEY_ESCAPE)
	check(app.current_screen=="explore" and not app.active_modal and not app.overlay.has_meta("party_roster"),"Esc returns directly to exploration")
	await _move_mouse(Vector2(760,450));root.gui_release_focus();await _settle()
	_check_projection(["shen","tang","qin"],"returned roster")
	await _capture("05-prepared-roster-escape-exploration-1280x800")
	_check_read_only("direct roster Escape")

	check(s.set_party_roster(["hero"]),"Actual roster API selects solo hero")
	app._sync_exploration_party();app._refresh();await _settle()
	baseline=s.to_dict().duplicate(true)
	_check_projection([],"solo")
	check(not strip.detail_panel.visible and strip.displayed_ids.is_empty(),"Solo selection hides empty companion cards and detail")
	await _capture("06-prepared-solo-hides-empty-1280x800")
	_check_read_only("solo hidden strip")

	check(s.set_party_roster(["hero","qin","shen"]),"Actual roster API selects altered ordered subset")
	# Aspect-kept native framebuffer is 1179x736.
	root.size=Vector2i(1179,737);app._sync_exploration_party();app._refresh();await _settle()
	baseline=s.to_dict().duplicate(true)
	_check_projection(["qin","shen"],"ordered compact subset")
	await _capture("07-prepared-ordered-subset-1179x736")
	_check_read_only("ordered compact subset")

	check(s.set_party_roster(["hero","shen","tang","qin"]),"Actual roster API restores all selected companions")
	app._sync_exploration_party();app._refresh();await _settle()
	_setup_world_overlap()
	await _move_mouse(Vector2(760,450));root.gui_release_focus()
	for _i in range(12):app.hud.tick(.1);await process_frame
	baseline=s.to_dict().duplicate(true)
	_check_projection(["shen","tang","qin"],"compact actor overlap")
	await _capture("08-prepared-compact-world-hud-overlap-1179x736")
	_check_read_only("compact world HUD overlap")
	check(s.party_resource_snapshot()==initial_resources,"All capture cases preserve real actor health, Qi and final selected roster")
	_verify_source()
	var result={"scope":"Explicit completed-story eligibility followed by actual recruitment and selected-roster API; prepared low HP/low Qi/downed resources read via real GameState API. Actual Godot InputEvent mouse and keyboard delivery. Full main scene actual framebuffer outside headless. No manual-play, browser, audio, exported-build, release or FPS claim.","source_identity":source_identity,"mode":capture_mode,"engine":Engine.get_version_info(),"display_server":DisplayServer.get_name(),"checks":checks,"failures":failures,"captured":captures,"inputs":input_trace,"checkpoints":checkpoints,"runtime_sha256":runtime_hashes,"fixture_save_absolute":ProjectSettings.globalize_path(fixture+"/save.json"),"fixture_save_sha256":FileAccess.get_sha256(fixture+"/save.json"),"fixture_save_writes_before":saved_write_count,"fixture_save_writes_after":s.writes,"initial_resources":initial_resources,"final_resources":s.party_resource_snapshot()}
	var out=FileAccess.open(evidence_dir+"/condition-trace.json",FileAccess.WRITE)
	check(out!=null,"Trace destination opens")
	result.checks=checks;result.failures=failures
	if out!=null:out.store_string(JSON.stringify(result,"\t"));out.close()
	print("%s: companion condition %s; %d checks, %d capture records (native only outside headless)"%["PASS" if failures==0 else "FAIL",capture_mode,checks,captures.size()])
	app._stop_audio();app.queue_free();await process_frame
	quit(0 if failures==0 else 1)

func _verify_source() -> void:
	for path: String in runtime_hashes:
		check(FileAccess.get_sha256("res://"+path)==runtime_hashes[path],"Exact source resource: "+path)

func _settle() -> void:
	app._process(0)
	for _i in range(3):await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw

func _relocate(origin:Vector2) -> void:
	s.map_id="qingwei";s.position=origin
	app._sync_world_state();app.world.change_map("qingwei",origin)
	app.world.camera_pos=app.world._camera_target();s.position=app.world.player_pos
	app._process(0);app._refresh()
	input_trace.append({"kind":"explicit_scene_setup","map":"qingwei","requested_origin":[origin.x,origin.y],"actual_origin":[app.world.player_pos.x,app.world.player_pos.y]})

func _setup_world_overlap() -> void:
	var area:Rect2=strip.get_global_rect()
	var chosen:Vector2=Vector2.ZERO
	for y:int in range(200,321,12):
		for x:int in range(48,337,12):
			var foot:Vector2=Vector2(x,y)
			var torso:Rect2=Rect2(foot-Vector2(27,80),Vector2(54,90))
			if app.world._can_walk(foot) and area.intersects(torso):
				chosen=foot;break
		if chosen!=Vector2.ZERO:break
	check(chosen!=Vector2.ZERO,"A legal world point overlaps actual compact HUD geometry")
	if chosen!=Vector2.ZERO:_relocate(chosen)
	var intersects:bool=false
	for foot:Vector2 in app.world.exploration_actor_positions():
		var point:Vector2=(foot-app.world.camera_pos)*app.view_zoom
		if area.intersects(Rect2(point-Vector2(27,80)*app.view_zoom,Vector2(54,90)*app.view_zoom)):intersects=true
	check(intersects,"Actual live actor torso overlaps companion strip for native occlusion capture")

func _move_mouse(point:Vector2) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=root.get_final_transform()*point;event.global_position=event.position
	Input.parse_input_event(event)
	input_trace.append({"kind":"mouse_motion","logical":[point.x,point.y],"window":[event.position.x,event.position.y]})
	await _settle()

func _hover(control:Control) -> void:
	await _move_mouse(control.get_global_rect().get_center())

func _send_key(key:Key) -> void:
	input_trace.append({"kind":"key_press_release","physical_keycode":key})
	await _key(key);await _settle()

func _click_event(control:Control) -> void:
	input_trace.append({"kind":"left_click_press_release","target":String(control.get_path()),"logical_center":[control.get_global_rect().get_center().x,control.get_global_rect().get_center().y]})
	await _click(control);await _settle()

func _tab_to(control:Control) -> void:
	for _i in range(24):
		await _send_key(KEY_TAB)
		var owner:Control=root.gui_get_focus_owner()
		input_trace.append({"kind":"focus_after_tab","owner":String(owner.get_path()) if is_instance_valid(owner) else ""})
		if control.has_focus():return
	check(false,"Bounded actual Tab traversal reaches requested card")

func _check_projection(expected:Array,label:String) -> void:
	var snapshot:Dictionary=s.party_resource_snapshot()
	check(snapshot.ok,label+" real state resource snapshot is valid")
	check(strip.displayed_ids==expected,label+" strip follows exact selected order")
	check(app.world.follower_ids()==expected,label+" world follows same selected order")
	for id:String in strip.cards:
		var card:Dictionary=strip.cards[id]
		if id not in expected:
			check(not card.button.is_visible_in_tree(),label+" unselected companion hidden: "+id)
			continue
		var actor:Dictionary=_actor(snapshot,id)
		check(actor.recruited and actor.selected,label+" card actor really recruited and selected: "+id)
		check(card.button.visible,label+" selected card visible: "+id)
		check(is_equal_approx(card.hp_bar.value,float(actor.hp)) and is_equal_approx(card.hp_bar.max_value,float(actor.max_hp)),label+" exact real HP/maxHP: "+id)
		check(is_equal_approx(card.qi_bar.value,float(actor.qi)) and is_equal_approx(card.qi_bar.max_value,float(actor.max_qi)),label+" exact real Qi/maxQi: "+id)
		check(card.portrait.texture!=null,label+" original portrait resource exists: "+id)
		for key:String in ["hp_bar","qi_bar"]:
			var bar:ProgressBar=card[key]
			check(bar.size.y<=8.0,label+" actual settled "+key+" is a thin bar: "+id)
			check(Rect2(Vector2.ZERO,card.button.size).encloses(bar.get_rect()),label+" actual "+key+" stays inside compact card: "+id)
	if not expected.is_empty():check(strip.size.x<=360 and strip.size.y<=125,label+" compact permanent display bounds")

func _check_detail(id:String) -> void:
	var actor:Dictionary=_actor(s.party_resource_snapshot(),id)
	var text:String=strip.detail_label.text
	var label:Label=strip.detail_label
	check(label.size.y>=label.get_minimum_size().y,"Detail contains the actual shaped text height: "+id)
	check(Rect2(Vector2.ZERO,strip.detail_panel.size).encloses(label.get_rect()),"Actual detail text is wholly inside panel: "+id)
	check(strip.detail_panel.size.y-label.get_rect().end.y>=8.0,"Detail has at least eight logical pixels bottom padding: "+id)
	check(text.contains(String(actor.name)),"Detail identifies real actor: "+id)
	for value:int in [int(actor.hp),int(actor.max_hp),int(actor.qi),int(actor.max_qi)]:
		check(text.contains(str(value)),"Detail includes real resource number for "+id+": "+str(value))
	if int(actor.hp)==0:check(text.contains("倒下"),"Focused downed detail explicitly explains state")

func _check_read_only(label:String) -> void:
	check(s.to_dict()==baseline,label+" HUD inspection does not mutate persistent game state")
	check(s.writes==saved_write_count,label+" HUD inspection triggers no save write")
	check(FileAccess.get_file_as_bytes(fixture+"/save.json")==saved_bytes,label+" isolated save bytes unchanged")
	checkpoints.append({"label":label,"resource_snapshot":s.party_resource_snapshot(),"state":s.to_dict(),"save_writes":s.writes,"save_sha256":FileAccess.get_sha256(fixture+"/save.json")})

func _rect_data(rect:Rect2) -> Array:
	return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]

func _capture(name:String) -> void:
	await _settle()
	var cards:Dictionary={}
	for id:String in strip.cards:
		var c:Dictionary=strip.cards[id]
		cards[id]={"visible":c.button.is_visible_in_tree(),"rect":_rect_data(c.button.get_global_rect()),"status":c.status.text,"alpha":c.button.modulate.a,"hp_bar_rect":_rect_data(c.hp_bar.get_global_rect()),"qi_bar_rect":_rect_data(c.qi_bar.get_global_rect()),"hp":c.hp_bar.value,"max_hp":c.hp_bar.max_value,"qi":c.qi_bar.value,"max_qi":c.qi_bar.max_value,"focused":c.button.has_focus(),"portrait_resource":c.portrait.texture.resource_path if c.portrait.texture!=null else ""}
	var row:Dictionary={"name":name,"native_rendered":DisplayServer.get_name()!="headless","requested_window_size":[root.size.x,root.size.y],"selected_ids":strip.displayed_ids.duplicate(),"strip_visible":strip.is_visible_in_tree(),"strip_rect":_rect_data(strip.get_global_rect()),"strip_alpha":strip.modulate.a,"detail_visible":strip.detail_panel.is_visible_in_tree(),"detail_text":strip.detail_label.text,"detail_rect":_rect_data(strip.detail_panel.get_global_rect()),"detail_label_rect":_rect_data(strip.detail_label.get_global_rect()),"detail_label_minimum":[strip.detail_label.get_minimum_size().x,strip.detail_label.get_minimum_size().y],"screen":app.current_screen,"active_modal":app.active_modal,"cards":cards,"actual_resource_snapshot":s.party_resource_snapshot(),"hero_world_position":[app.world.player_pos.x,app.world.player_pos.y],"camera":[app.world.camera_pos.x,app.world.camera_pos.y]}
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var pixels:Image=root.get_texture().get_image()
		var aspect_scale:float=minf(float(root.size.x)/1280.0,float(root.size.y)/800.0)
		var expected_pixels:Vector2i=Vector2i(floori(1280.0*aspect_scale),floori(800.0*aspect_scale))
		check(pixels.get_width()==expected_pixels.x and pixels.get_height()==expected_pixels.y,"Actual framebuffer follows canvas_items aspect keep from requested window: "+name)
		row.aspect_kept_expected_size=[expected_pixels.x,expected_pixels.y]
		var path:String=evidence_dir+"/screenshots/"+name+".png"
		check(pixels.save_png(path)==OK,"Actual Godot framebuffer saved: "+name)
		row.width=pixels.get_width();row.height=pixels.get_height();row.sha256=FileAccess.get_sha256(path)
	captures.append(row)
	print("FRAME ",name," native_rendered=",row.native_rendered)
