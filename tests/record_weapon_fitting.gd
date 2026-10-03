extends SceneTree
## Direct native framebuffer evidence on a genuine Main/State. Explicit prepared
## resources and location, actual scripted inputs, and natural fixed-step combat.
## Main, world, PartyUI and arena processing remain enabled throughout.
const MainScene = preload("res://scenes/main.tscn")
const State = preload("res://scripts/game_state.gd")
var app
var out_dir: String = ""
var manifest_path: String = ""
var source_identity: String = ""
var fixture_path: String = ""
var party_fixture_path: String = ""
var mode: String = "stills"
var checks: int = 0
var failures: int = 0
var failed: Array = []
var captures: Array = []
var inputs: Array = []
var transactions: Array = []
var seen_tokens: Dictionary = {}
var hashes: Dictionary = {}
var frames: int = 0
var fixture: Dictionary = {}
var battle_results: Array = []

func _initialize() -> void: _run.call_deferred()
func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1; failed.append(description); push_error(description)
func _frame(count: int = 1) -> void:
	for _i: int in count:
		_observe_transaction(); await process_frame; frames += 1; _observe_transaction()
func _observe_transaction() -> void:
	if not is_instance_valid(app): return
	var battle = (app.overlay.get_meta("party_battle") if app.overlay.has_meta("party_battle") else null)
	if battle == null or battle.pending.is_empty(): return
	var key: String = str(battle.pending.epoch)+":"+str(battle.pending.token)
	if seen_tokens.has(key): return
	seen_tokens[key] = true
	transactions.append(battle.pending.duplicate(true))
func _panel(): return (app.overlay.get_meta("weapon_fitting") if app.overlay.has_meta("weapon_fitting") else null)
func _tap(code: int) -> void:
	inputs.append({"kind":"scripted_actual_key_press_release", "key":OS.get_keycode_string(code), "frame":frames})
	for down: bool in [true, false]:
		var event = InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=down
		Input.parse_input_event(event); await _frame()
	await _frame(2)
func _click(node_name: String) -> void:
	var button = app.overlay.find_child(node_name, true, false)
	check(button is Button and button.is_visible_in_tree() and not button.disabled, "Visible enabled actual target "+node_name)
	if not button is Button or button.disabled: return
	var rect: Rect2 = button.get_global_rect()
	var point: Vector2 = root.get_final_transform()*rect.get_center()
	inputs.append({"kind":"scripted_actual_mouse_press_release", "target":node_name, "logical_rect":_area(rect), "event_point":[point.x,point.y], "frame":frames})
	var motion=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; Input.parse_input_event(motion); await _frame()
	for down: bool in [true,false]:
		var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		Input.parse_input_event(event);await _frame()
	await _frame(3)
func _focus_tab(node_name: String) -> void:
	root.gui_release_focus()
	for _i: int in 20:
		await _tap(KEY_TAB)
		var focused = root.gui_get_focus_owner()
		if focused != null and String(focused.name)==node_name:
			check(true,"Tab reaches "+node_name);return
	check(false,"Tab cannot reach "+node_name)
func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out_dir=argument.trim_prefix("--out=")
		if argument.begins_with("--manifest="): manifest_path=argument.trim_prefix("--manifest=")
		if argument.begins_with("--source="): source_identity=argument.trim_prefix("--source=")
		if argument.begins_with("--fixture="): fixture_path=argument.trim_prefix("--fixture=")
		if argument.begins_with("--party-fixture="): party_fixture_path=argument.trim_prefix("--party-fixture=")
		if argument.begins_with("--mode="): mode=argument.trim_prefix("--mode=")
	if party_fixture_path.is_empty() or out_dir.is_empty() or manifest_path.is_empty() or source_identity.is_empty() or OS.get_environment("HOME").is_empty() or OS.get_environment("XDG_DATA_HOME").is_empty():quit(2);return
	hashes=JSON.parse_string(FileAccess.get_file_as_string(manifest_path));_verify_source("before")
	DirAccess.make_dir_recursive_absolute(out_dir+"/screenshots")
	var state=State.new()
	if not fixture_path.is_empty():
		check(state.load_game(fixture_path)==OK,"Restore declared earned prerequisite fixture through genuine serializer")
		fixture={"origin":"earned prerequisite save, followed by explicitly prepared fitting/resource/location changes", "source_path":fixture_path,"source_sha256":FileAccess.get_sha256(fixture_path),"earned_state":state.to_dict().duplicate(true)}
	else:
		state.quest_stage=6;state.ending="守望";state.choose_sect("听潮阁")
		fixture={"origin":"Explicit prepared early eligible solo State; no earned-journey claim", "prepared_eligibility":true}
	check(state.set_weapon_fitting("edge").get("ok",false),"Prepared installed edge is valid")
	state.hp=17;state.qi=1;state.medicine=0;state.map_id="qingwei"
	app=MainScene.instantiate();app.state=state;root.add_child(app);await _frame(2)
	app._stop_audio();app.audio_on=false
	root.size=Vector2i(1180,737)
	await _probe_scroll(_first_rich(app.overlay),"title_notice",true)
	await _capture("01-title-writer16-warning-1180","Actual Main startup title at1180x737; warning is shown after actual wheel-scroll if its text overflows, with initial scroll geometry retained")
	app.current_screen="explore";app.modal_autosave_on_close=false;app._close_modal()
	app.view_preferences.full_resolution=true;app.view_preferences.zoom_index=0;app._apply_view_zoom()
	root.size=Vector2i(1280,800)
	var court: Vector2=app.world.interactables.courtyard_practice.pos
	var observation: Vector2=court+Vector2(0,24)
	app.state.position=observation;app._sync_world_state();app.world.change_map("qingwei",observation);app.world._update_nearby();app._refresh()
	await _frame(3)
	check(app.is_processing() and app.world.is_processing(),"Main and world processing remain enabled")
	check(app.state.get_script().resource_path=="res://scripts/game_state.gd","Genuine exact State script, no subclass")
	check(app.state.save_game()==OK,"Isolated prepared baseline save only")
	fixture.prepared_state=app.state.to_dict().duplicate(true)
	fixture.prepared_location=[observation.x,observation.y]
	fixture.note="Only baseline acquisition may be earned; installed edge, real17HP/1Qi/zero medicine and lawful courtyard position are declared preparation. Subsequent preview/confirmation/trials use real UI."
	await _tap(KEY_B);await _tap(KEY_5);await _click("FittingCandidate_guard")
	check(_panel()!=null and _panel().page=="preview" and _panel().candidate=="guard","Actual workshop fifth choice opens guard preview")
	var baseline: Dictionary=app.state.to_dict().duplicate(true)
	var saved: PackedByteArray=FileAccess.get_file_as_bytes(State.SAVE_PATH)
	var location: Vector2=app.world.player_pos
	await _capture("02-installed-preview-tradeoff-1280","Installed edge versus unconfirmed guard; original attack/defense costs and save16 notice")
	await _click("FittingAction_equip")
	check(_panel().page=="confirm" and app.state.weapon_fitting=="edge","Confirmation has not equipped preview")
	await _probe_scroll(_panel().body,"explicit_confirmation",false)
	await _capture("03-explicit-confirmation-1280","Real explicit confirmation before any change; cancel and save consequences visible")
	await _click("FittingAction_cancel")
	check(app.state.to_dict()==baseline and FileAccess.get_file_as_bytes(State.SAVE_PATH)==saved,"Actual cancel changes neither real State nor saved bytes")
	root.size=Vector2i(1180,737);await _frame(4)
	await _focus_tab("FittingCandidate_plain");await _tap(KEY_ENTER)
	check(_panel().candidate=="plain" and app.state.weapon_fitting=="edge","Native focused Enter changes preview only, key release does not equip")
	await _focus_tab("FittingAction_equip")
	inputs.append({"kind":"cancelled_small_window_focus_verified","focus":String(root.gui_get_focus_owner().name),"window":[root.size.x,root.size.y],"installed":app.state.weapon_fitting,"candidate":_panel().candidate,"frame":frames})
	await _tap(KEY_ESCAPE)
	# Highest-density results use a separately earned owned four-person roster.
	# This declared isolated fixture switch is not travel, recruitment or healing.
	app._stop_audio();app.queue_free();await _frame(2)
	var party_state=State.new()
	check(party_state.load_game(party_fixture_path)==OK,"Restore separately earned four-person serializer boundary")
	check(party_state.party_roster.size()==4 and party_state.companion_unlocked and party_state.tangqi_unlocked and party_state.qin_unlocked,"Four-person comparison roster genuinely owned in earned boundary")
	fixture.party={"source_path":party_fixture_path,"source_sha256":FileAccess.get_sha256(party_fixture_path),"earned_state":party_state.to_dict().duplicate(true)}
	check(party_state.set_weapon_fitting("edge").get("ok",false),"Prepared later-party edge is valid")
	party_state.hp=17;party_state.qi=1;party_state.medicine=0;party_state.map_id="qingwei"
	app=MainScene.instantiate();app.state=party_state;root.add_child(app);await _frame(2)
	app._stop_audio();app.audio_on=false;app.current_screen="explore";app.modal_autosave_on_close=false;app._close_modal()
	root.size=Vector2i(1280,800);app.view_preferences.full_resolution=true;app.view_preferences.zoom_index=1;app._apply_view_zoom()
	court=app.world.interactables.courtyard_practice.pos;observation=court+Vector2(0,24)
	app.state.position=observation;app._sync_world_state();app.world.change_map("qingwei",observation);app.world._update_nearby();app._refresh();await _frame(3)
	check(app.state.save_game()==OK,"Explicit isolated later-party prepared baseline save")
	fixture.party.prepared_state=app.state.to_dict().duplicate(true)
	fixture.party.note="Genuine earned recruitment/roster retained. Installed edge, real hero17HP/1Qi/zero medicine, Qingwei map and courtyard placement are capture-only preparation. No trial result is prepared."
	baseline=app.state.to_dict().duplicate(true);saved=FileAccess.get_file_as_bytes(State.SAVE_PATH);location=app.world.player_pos
	check(app.world.nearby_id=="courtyard_practice","Prepared lawful courtyard site selected by actual nearby logic")
	await _tap(KEY_E);await _tap(KEY_3)
	check(_panel()!=null and _panel().origin=="courtyard","Actual courtyard E third action opens fitting")
	await _click("FittingCandidate_edge");await _click("FittingAction_trial")
	check(_panel().page=="trial" and _panel().trial_entry_ready("edge","ordinary"),"Ordinary remains default and real courtyard site gate passes")
	await _click("FittingAction_pressure")
	check(_panel().profile=="pressure" and _panel().trial_entry_ready("edge","pressure"),"Pressure requires explicit visible choice before native comparisons")
	await _probe_scroll(_panel().body,"pressure_warning",true)
	await _capture("04-courtyard-pressure-setup-1280-zoom125","Explicit pressure borrowed edge, installed edge, full virtual resources and3x40 medicine; ordinary was checked as default. Real low resources are declared preparation")
	await _click("FittingAction_start")
	var battle=(app.overlay.get_meta("party_battle") if app.overlay.has_meta("party_battle") else null)
	check(battle!=null and battle.is_processing() and battle.art.is_processing(),"Actual scheduler and presentation stay enabled")
	check(battle!=null and battle.fitting_metadata.borrowed_fitting=="edge","Real borrowed fitting metadata attached")
	await _frame(12)
	await _capture("05-actual-borrowed-battle-1280","Real pressure automatic basic attacks only, no queued skill/item input; borrowed/installed badge, no injected outcomes or acknowledgements")
	await _natural_result()
	check(_panel()!=null and _panel().page=="results" and _panel().result_rows.size()==1,"First natural accepted result appears once")
	if failures>0:await _finish();return
	battle_results.append(_panel().result_rows[-1].duplicate(true))
	await _click("FittingAction_trial");await _click("FittingCandidate_guard");await _click("FittingAction_start")
	await _natural_result()
	check(_panel()!=null and _panel().page=="results" and _panel().result_rows.size()==2,"Natural second borrowed candidate produces latest-two same group")
	if failures>0:await _finish();return
	battle_results.append(_panel().result_rows[-1].duplicate(true))
	check(battle_results[0].metadata.profile_id=="pressure" and battle_results[1].metadata.profile_id=="pressure","Both naturally played rows are same explicitly chosen pressure profile")
	check(battle_results[0].metadata.comparison_key==battle_results[1].metadata.comparison_key,"Displayed results genuinely share comparison group")
	check(battle_results[0].metadata.borrowed_fitting=="edge" and battle_results[1].metadata.borrowed_fitting=="guard","Two actual different borrowed candidates recorded")
	check(app.state.to_dict()==baseline and app.world.player_pos==location and FileAccess.get_file_as_bytes(State.SAVE_PATH)==saved,"Both natural trials preserve exact persistent State, world position and isolated save bytes")
	await _probe_scroll(app.overlay.find_child("FittingResult1",true,false),"result1_profile",false)
	await _probe_scroll(app.overlay.find_child("FittingResult2",true,false),"result2_profile",false)
	await _capture("06-actual-two-result-comparison-1280","Two genuine four-person pressure results using natural automatic basic attacks only and no queued skills/items; same group, exact HP loss/attacks/rounds/remaining borrowed resources")
	root.size=Vector2i(1180,737);app.view_preferences.zoom_index=2;app._apply_view_zoom();await _frame(4)
	await _probe_scroll(app.overlay.find_child("FittingResult1",true,false),"compact_result1_profile",false)
	await _probe_scroll(app.overlay.find_child("FittingResult2",true,false),"compact_result2_profile",false)
	await _focus_tab("FittingAction_trial")
	await _capture("07-two-result-focused-1180-zoom160","Same actual four-person comparison at1180x737 and world160%; actual Tab focus, no result rewriting")
	root.size=Vector2i(1280,800);await _click("FittingAction_preview")
	check(DirAccess.make_dir_absolute(State.SAVE_PATH+".tmp")==OK,"Inject only own isolated empty tmp directory to force actual save failure")
	await _click("FittingAction_equip");await _click("FittingAction_confirm")
	check(app.state.weapon_fitting=="guard" and app.save_warning,"Real failed save retains installed guard in memory with warning")
	check(FileAccess.get_file_as_bytes(State.SAVE_PATH)==saved,"Failed save preserves prior file bytes")
	await _capture("08-real-failed-save-warning-1280","Actual explicit guard equip fails writing isolated tmp path; installed-in-memory and truthful unsaved warning")
	check(DirAccess.remove_absolute(State.SAVE_PATH+".tmp")==OK,"Remove own empty failure injection")
	await _click("FittingAction_retry_save")
	check(not app.save_warning and app.state.weapon_fitting=="guard","Explicit retry succeeds without reapplying selection")
	await _finish()

func _first_rich(node: Node):
	if node is RichTextLabel:return node
	for child: Node in node.get_children():
		var found=_first_rich(child)
		if found!=null:return found
	return null
func _probe_scroll(text, label: String, leave_at_bottom: bool) -> void:
	check(text is RichTextLabel,"Visible text exists for scroll probe "+label)
	if not text is RichTextLabel:return
	await _frame(3)
	var bar=text.get_v_scroll_bar()
	var before: float=bar.value
	var limit: float=maxf(0.0,bar.max_value-bar.page)
	var row: Dictionary={"kind":"actual_text_scroll_probe","label":label,"text":text.text,"content_height":text.get_content_height(),"rect":_area(text.get_global_rect()),"initial_scroll":before,"max_scroll":limit,"focus_mode":text.focus_mode,"frame":frames}
	if limit>0:
		root.gui_release_focus()
		var reached: bool=false
		var focus_path: Array=[]
		for _i: int in 24:
			await _tap(KEY_TAB)
			var focused=root.gui_get_focus_owner()
			focus_path.append("none" if focused==null else String(focused.name))
			if focused==text or focused==bar:reached=true;break
		row.keyboard_tab_reaches_text_or_bar=reached;row.focus_path=focus_path
		if reached:
			await _tap(KEY_PAGEDOWN);row.keyboard_page_down_scroll=bar.value
			await _tap(KEY_END);row.keyboard_end_scroll=bar.value
			check(bar.value>before,"Keyboard PageDown or End scrolls focused overflowing text "+label)
		var point: Vector2=root.get_final_transform()*text.get_global_rect().get_center()
		for direction: int in [MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_UP]:
			if direction==MOUSE_BUTTON_WHEEL_UP and leave_at_bottom:break
			for _i: int in 12:
				for down: bool in [true,false]:
					var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=direction;event.pressed=down;event.factor=1.0
					Input.parse_input_event(event);await _frame()
			if direction==MOUSE_BUTTON_WHEEL_DOWN:
				row.reached_scroll=bar.value
				check(bar.value>=limit-.1,"Actual wheel reaches full text bottom "+label)
			else:check(is_zero_approx(bar.value),"Actual wheel restores text top "+label)
	row.final_scroll=bar.value;inputs.append(row)

func _natural_result() -> void:
	var start: int=frames
	while app.current_screen=="party_battle" and frames-start<18000:
		await _frame()
	check(app.current_screen=="explore" and not app.state.battle_active,"Natural scheduler/presentation reaches terminal within300 simulation seconds")
	await _frame(4)
func _area(rect: Rect2) -> Array: return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
func _nodes(node: Node, rows: Array) -> void:
	if node is Control and node.is_visible_in_tree() and (String(node.name).begins_with("Fitting") or node is Label or node is RichTextLabel):
		var row: Dictionary={"name":String(node.name),"rect":_area(node.get_global_rect())}
		if node is Label or node is RichTextLabel: row.text=node.text
		if node is RichTextLabel:
			row.content_height=node.get_content_height();row.scroll_active=node.scroll_active
			row.vertical_scroll=node.get_v_scroll_bar().value;row.focus_mode=node.focus_mode
			row.scroll_max=node.get_v_scroll_bar().max_value;row.scroll_page=node.get_v_scroll_bar().page
		if node is Button:row.disabled=node.disabled;row.focus=node.has_focus()
		rows.append(row)
	for child: Node in node.get_children():_nodes(child,rows)
func _capture(name: String,note: String) -> void:
	await _frame(4)
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
	var rows: Array=[];_nodes(app.overlay,rows)
	var panel=_panel()
	var frame: Dictionary={"name":name,"note":note,"frame":frames,"window":[root.size.x,root.size.y],"world_zoom":app.view_zoom,"screen":app.current_screen,"state":app.state.to_dict(),"controls":rows,"main_processing":app.is_processing(),"world_processing":app.world.is_processing(),"save_sha256":(FileAccess.get_sha256(State.SAVE_PATH) if FileAccess.file_exists(State.SAVE_PATH) else ""),"logical_viewport":_area(root.get_visible_rect()),"input_scale":[root.get_final_transform().get_scale().x,root.get_final_transform().get_scale().y]}
	if panel!=null:frame.page=panel.page;frame.candidate=panel.candidate;frame.profile=panel.profile;frame.results=panel.result_rows
	var battle=(app.overlay.get_meta("party_battle") if app.overlay.has_meta("party_battle") else null)
	if battle!=null:frame.snapshot=battle.art.display_snapshot;frame.pending=battle.pending.duplicate(true);frame.presentation_phase=battle.art.presentation_phase;frame.fitting_metadata=battle.fitting_metadata
	var focus=root.gui_get_focus_owner();frame.focus="" if focus==null else String(focus.name)
	if DisplayServer.get_name()!="headless":
		var pixels: Image=root.get_texture().get_image()
		check(pixels.save_png(out_dir+"/screenshots/"+name+".png")==OK,"Unedited actual framebuffer "+name)
		frame.width=pixels.get_width();frame.height=pixels.get_height()
	captures.append(frame);_write("capture-progress.json")
func _verify_source(when: String) -> void:
	for path: String in hashes:check(FileAccess.get_sha256("res://"+path)==hashes[path],"Source/driver hash "+when+": "+path)
func _write(name: String) -> void:
	var file=FileAccess.open(out_dir+"/"+name,FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"Actual native Godot Main framebuffer; explicit fixture/resource/location preparation; scripted InputEvent keys/mouse and naturally accepted fixed-step30fps automatic battle. No manual-play, browser, FPS, persistence or earned-walking claim. No forged metrics or direct accepted-token acknowledgement.","source_identity":source_identity,"engine":Engine.get_version_info(),"display_server":DisplayServer.get_name(),"checks":checks,"failures":failures,"failed":failed,"frames":frames,"fixture":fixture,"captures":captures,"inputs":inputs,"transactions":transactions,"battle_results":battle_results,"runtime_and_driver_sha256":hashes},"\t"));file.close()
func _finish() -> void:
	_verify_source("after");_write("capture-trace.json")
	print("%s fitting native: %d checks; %d stills; %d failures"%["PASS" if failures==0 else "FAIL",checks,captures.size(),failures])
	app._stop_audio();app.queue_free();await process_frame;quit(0 if failures==0 else 1)
