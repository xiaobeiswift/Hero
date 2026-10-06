extends SceneTree
## Genuine Main/HeroState integration for the companion folio visual iteration.
## Guard runs before any game load. No overrides, fake writer, or no-save adapter.
## Native capture inherits this test-only helper script; it is not a production dependency.
const SAVE_PATH = "user://hero_save.json"
const IDS = ["hero", "shen", "tang", "qin"]
const TRANSIENT_KEYS = [
	"enemy_name","enemy_hp","enemy_max_hp","enemy_intent","battle_active","battle_kind",
	"turn","guard","battle_log","skill_cooldown","enemy_base_attack","enemy_strong_attack",
	"exposed_turns","enemy_weaken_amount","enemy_weaken_strikes","focused_damage",
	"_companion_attack_count","_trial_art_used","_trial_healing","_trial_guarded_heavy",
	"party_battle_epoch","party_settlement","_party_pending_token","_party_encounter",
	"_party_sluice_entry","_party_archive_entry","_party_extra_entry","_party_practice_before",
	"_party_consignee_identity","_party_capstone_identity","_fitting_comparison_key",
	"_fitting_comparisons","_fitting_last_result_epoch","receipt_battle_epoch","receipt_settlement",
]

var app
var model
var battle_driver
var owned_root = ""
var owned_user = ""
var report_path = ""
var checks = 0
var failures: Array[String] = []
var checkpoints: Array[Dictionary] = []
var sections: Array[String] = []
var inputs: Array[Dictionary] = []
var current_section = "guard"
var finished = false
var collision_owned = false
var guard_passed = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not _guard():
		push_error("ERROR: companion folio ownership guard rejected startup before game loads")
		quit(2); return
	guard_passed = true
	create_timer(150.0).timeout.connect(func():
		if not finished:
			_check(false, "Companion folio watchdog expired")
			_finish())
	if not await _boot(): _finish(); return
	await _unrecruited()
	if not failures.is_empty(): _finish(); return
	await _roster_and_focus()
	if not failures.is_empty(): _finish(); return
	await _origins_and_stale()
	if not failures.is_empty(): _finish(); return
	await _real_failure_retry()
	if not failures.is_empty(): _finish(); return
	await _wide_and_invalid()
	if not failures.is_empty(): _finish(); return
	await _blocking()
	_finish()

func _boot() -> bool:
	model = load("res://scripts/game_state.gd")
	var scene = load("res://scenes/main.tscn")
	battle_driver = load("res://tests/unified_ui_test_driver.gd")
	if not _check(model != null and scene != null and battle_driver != null, "Production resources load after guard"): return false
	app = scene.instantiate()
	root.size = Vector2i(1280,800)
	root.add_child(app)
	await _frames(3)
	app._stop_audio(); app.audio_on = false
	return _check(app.state.get_script() == model, "Real Main owns exact production HeroState")

func _guard() -> bool:
	owned_root = OS.get_environment("HERO_FOLIO_QA_OWNED_ROOT")
	owned_user = OS.get_environment("HERO_FOLIO_QA_USER_DIR")
	report_path = OS.get_environment("HERO_FOLIO_QA_REPORT")
	var token = OS.get_environment("HERO_FOLIO_QA_TOKEN")
	if owned_root.is_empty() or owned_user.is_empty() or report_path.is_empty() or token.length() < 24:
		return false
	for path: String in [owned_root,owned_user,report_path]:
		if not path.is_absolute_path() or path != path.simplify_path() or path.ends_with("/"):
			return false
	if owned_root.get_slice_count("/") < 4 or not DirAccess.dir_exists_absolute(owned_root): return false
	if not owned_user.begins_with(owned_root+"/"): return false
	if not report_path.begins_with(owned_root+"/") or report_path.begins_with(owned_user+"/"): return false
	var project = ProjectSettings.globalize_path("res://").trim_suffix("/").simplify_path()
	if report_path.begins_with(project+"/"): return false
	if OS.get_user_data_dir().simplify_path() != owned_user: return false
	if ProjectSettings.globalize_path("user://").trim_suffix("/").simplify_path() != owned_user: return false
	if not _no_links(owned_root) or not _no_links(owned_user) or not _no_links(report_path.get_base_dir()): return false
	var marker = owned_root.path_join(".hero-folio-qa-owner")
	if not FileAccess.file_exists(marker) or not _no_links(marker): return false
	if FileAccess.get_file_as_string(marker).strip_edges() != token: return false
	if not _no_links(report_path) or FileAccess.file_exists(report_path) or DirAccess.dir_exists_absolute(report_path): return false
	if not DirAccess.dir_exists_absolute(report_path.get_base_dir()): return false
	var dir = DirAccess.open(owned_user)
	if dir == null: return false
	dir.include_hidden = true
	# Godot can create its own log directory before a SceneTree script starts.
	if not dir.get_files().is_empty(): return false
	for directory: String in dir.get_directories():
		if directory not in ["logs", "shader_cache"] or not _tree_unlinked(owned_user.path_join(directory)): return false
	return true

func _no_links(path: String) -> bool:
	# Check every existing ancestor, including the owned-root ancestors.
	var cursor = path
	while cursor != "/" and not cursor.is_empty():
		var parent = DirAccess.open(cursor.get_base_dir())
		if parent == null or parent.is_link(cursor.get_file()): return false
		cursor = cursor.get_base_dir()
	return true

func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		var failure = current_section+": "+message
		failures.append(failure)
		push_error("ERROR: "+failure)
	return ok

func _tree_unlinked(path: String) -> bool:
	if not _no_links(path): return false
	var directory = DirAccess.open(path)
	if directory == null: return false
	directory.include_hidden = true; directory.include_navigational = false
	for leaf: String in directory.get_files():
		if directory.is_link(leaf): return false
	for leaf: String in directory.get_directories():
		if directory.is_link(leaf) or not _tree_unlinked(path.path_join(leaf)): return false
	return true

func _section(label: String) -> void:
	current_section = label
	sections.append(label)

func _frames(count: int = 2) -> void:
	for index: int in count: await process_frame

func _key(code: int, shift: bool = false) -> void:
	inputs.append({"section":current_section,"kind":"queued_native_key","key":OS.get_keycode_string(code),"shift":shift})
	for pressed: bool in [true,false]:
		var event = InputEventKey.new()
		event.physical_keycode = code; event.keycode = code; event.pressed = pressed; event.shift_pressed = shift
		Input.parse_input_event(event); Input.flush_buffered_events()
		await _frames(1)
	await _frames(2)

func _pointer(control, label: String) -> void:
	await _frames(3)
	if not _check(is_instance_valid(control) and control is Button and control.is_visible_in_tree() and not control.disabled, "Visible enabled pointer target: "+label): return
	var generation: int = app.modal_generation
	var point: Vector2 = root.get_final_transform()*control.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new(); motion.position = point; motion.global_position = point
	Input.parse_input_event(motion); Input.flush_buffered_events()
	await _frames(1)
	if not _check(is_instance_valid(control) and generation == app.modal_generation and control.is_visible_in_tree(), "Pointer still belongs to settled page: "+label): return
	point = root.get_final_transform()*control.get_global_rect().get_center()
	if not _check(Rect2(Vector2.ZERO,Vector2(root.size)).has_point(point), "Pointer in actual window: "+label): return
	inputs.append({"section":current_section,"kind":"queued_native_pointer","target":str(control.get_path()),"label":label,"pixel_position":[point.x,point.y]})
	for pressed: bool in [true,false]:
		var event = InputEventMouseButton.new()
		event.position = point; event.global_position = point; event.pressed = pressed; event.button_index = MOUSE_BUTTON_LEFT
		Input.parse_input_event(event); Input.flush_buffered_events()
		await _frames(1)
	await _frames(3)

func _folio():
	return app.overlay.get_meta("party_roster") if app.overlay.has_meta("party_roster") else null

func _open(direct: bool):
	if direct:
		await _pointer(app.hud.companion_condition.roster_button,"HUD 同行册")
	else:
		await _key(KEY_I); await _key(KEY_5)
	var page = _folio()
	_check(is_instance_valid(page) and app.active_modal, "Actual "+("HUD" if direct else "inventory I/5")+" entry mounts roster")
	return page

func _return_origin(direct: bool) -> void:
	await _key(KEY_ESCAPE)
	_check(not app.active_modal if direct else app.active_modal and app.overlay.get_meta("inventory",false), "Escape returns to exact entry origin")
	if not direct:
		await _key(KEY_4)
		_check(not app.active_modal, "Ordinary inventory close returns to exploration")
		_saved(app.state.to_dict(),"Ordinary inventory-close autosave remains enabled")

func _new_state():
	var value = model.new(); value.reset_game()
	return value

func _all_state(wide: bool = false):
	var fixture = load("res://tests/party_exploration_fixture.gd")
	var value = fixture.recruited_state(["hero","shen","tang","qin"])
	value.map_id = "qingwei"; value.position = Vector2(460,430)
	value.hp = 37; value.qi = 1
	value.party_resources.shen = {"hp":0,"qi":2}
	value.party_resources.tang = {"hp":41,"qi":0}
	value.party_resources.qin = {"hp":62,"qi":3}
	if wide:
		value.player_name = "江湖夜雨青苇渡灯长风归客山河故人行舟".left(18)
		value.level = 99; value.xp = 0; value.max_hp = 9999; value.hp = 9998; value.max_qi = 99; value.qi = 98
		var snapshot: Dictionary = value.party_resource_snapshot()
		for actor: Dictionary in snapshot.actors:
			if actor.id != "hero": value.party_resources[actor.id] = {"hp":actor.max_hp-1,"qi":actor.max_qi}
	return value

func _prepare(value, label: String) -> bool:
	var canonical: Dictionary = value.to_dict().duplicate(true)
	var bytes: PackedByteArray = JSON.stringify({"version":model.SAVE_VERSION,"player":canonical}).to_utf8_buffer()
	var inspected: Dictionary = model.new().inspect_save_bytes(bytes)
	if not _check(inspected.ok and inspected.state.to_dict() == canonical, "Prepared legal fixture exact validator round-trip: "+label): return false
	app._clear_overlay(); app.active_modal = false; app.state = inspected.state
	app._apply_loaded_state("同行册核验 · 预备合法状态")
	app._refresh(); await _frames(3)
	app._autosave(); _saved(canonical,"Prepared fixture: "+label)
	_snapshot("Prepared fixture; story milestones are not earned in this run: "+label)
	return failures.is_empty()

func _disk() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(SAVE_PATH) if FileAccess.file_exists(SAVE_PATH) else PackedByteArray()

func _transients() -> Dictionary:
	var result: Dictionary = {}
	for key: String in TRANSIENT_KEYS:
		var value = app.state.get(key)
		result[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	result.party_session_identity = app.state.party_session.get_instance_id() if app.state.party_session != null else 0
	result.receipt_session_identity = app.state.receipt_session.get_instance_id() if app.state.receipt_session != null else 0
	result.party_snapshot = app.state.party_battle_snapshot().duplicate(true)
	result.receipt_snapshot = app.state.receipt_battle_snapshot().duplicate(true)
	return result

func _snapshot(label: String) -> Dictionary:
	var value = {"state":app.state.to_dict().duplicate(true),"transients":_transients(),"position":app.world.player_pos,"map":app.world.map_id,"disk":_disk()}
	checkpoints.append({"section":current_section,"label":label,"canonical":value.state,"transients":_json_safe(value.transients),"position":var_to_str(value.position),"map":value.map,"save_bytes":value.disk.size(),"save_sha256":FileAccess.get_sha256(SAVE_PATH) if not value.disk.is_empty() else "","save_base64":Marshalls.raw_to_base64(value.disk)})
	return value

func _json_safe(value):
	if value is Dictionary:
		var result = {}
		for key in value: result[str(key)] = _json_safe(value[key])
		return result
	if value is Array:
		var result = []
		for element in value: result.append(_json_safe(element))
		return result
	if value is Vector2 or value is Vector2i or value is Rect2: return var_to_str(value)
	return value

func _expect(before: Dictionary, edits: Dictionary, label: String, persisted: bool = false) -> void:
	var expected: Dictionary = before.state.duplicate(true)
	for key in edits: expected[key] = edits[key]
	var after = _snapshot(label)
	_check(after.state == expected,label+": complete canonical state has only expected edits")
	_check(after.transients == before.transients,label+": battle/session/effect boundaries unchanged")
	_check(after.position == before.position and after.map == before.map,label+": position and map unchanged")
	if persisted: _saved(expected,label)
	else: _check(after.disk == before.disk,label+": exact original save bytes unchanged")

func _saved(expected: Dictionary, label: String) -> void:
	var restored = model.new()
	_check(not _disk().is_empty() and restored.load_game() == OK and restored.to_dict() == expected,label+": real fresh HeroState reload matches every saved field")
	_check(not app.save_warning,label+": no save warning")

func _values(page) -> void:
	var snapshot: Dictionary = app.state.party_resource_snapshot()
	if not _check(snapshot.ok,"Valid source snapshot"): return
	_check(page.cells.size() == 4,"All four stable cells retained")
	for actor: Dictionary in snapshot.actors:
		var cell: Dictionary = page.cells[actor.id]
		var order: int = snapshot.roster.find(actor.id)+1
		_check(cell.panel.get_meta("recruited") and cell.portrait.visible and cell.portrait.texture != null,"Recruited portrait visible: "+actor.id)
		_check(cell.hp.text == "气血  %d / %d" % [actor.hp,actor.max_hp] and cell.qi.text == "真气  %d / %d" % [actor.qi,actor.max_qi],"Exact readable HP/Qi: "+actor.id)
		_check(cell.hp_bar.value == actor.hp and cell.hp_bar.max_value == actor.max_hp and cell.qi_bar.value == actor.qi and cell.qi_bar.max_value == actor.max_qi,"Exact bars: "+actor.id)
		var expected: String = ("在队 %d" % order if order > 0 else "候阵")+(" · 倒下" if actor.hp == 0 else "")
		_check(cell.status.text == expected and cell.panel.get_meta("roster_order") == order,"Exact order/bench/downed text: "+actor.id)
		var portraits = load("res://scripts/character_portraits.gd")
		_check(cell.portrait.texture.region == portraits.texture_for(actor.id).region and cell.portrait.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED,"Original portrait crop and aspect mode: "+actor.id)

func _focus_ring(page) -> void:
	var expected: Array[Button] = []
	for id: String in IDS:
		for key: String in ["toggle","story"]:
			var button: Button = page.cells[id][key]
			if button.is_visible_in_tree() and not button.disabled: expected.append(button)
	for formation: String in ["并肩","护后"]:
		if not page.formation_buttons[formation].disabled: expected.append(page.formation_buttons[formation])
	if page.retry_button.visible and not page.retry_button.disabled: expected.append(page.retry_button)
	expected.append(page.return_button)
	var before = _snapshot("Before full focus ring")
	for pair: Array in [[KEY_TAB,false,1],[KEY_TAB,true,-1],[KEY_RIGHT,false,1],[KEY_DOWN,false,1],[KEY_LEFT,false,-1],[KEY_UP,false,-1]]:
		expected[0].grab_focus()
		for step in range(1,expected.size()+1):
			await _key(pair[0],pair[1])
			_check(expected[posmod(step*int(pair[2]),expected.size())].has_focus(),"Full native focus ring step %d key %s" % [step,str(pair[0])])
	_expect(before,{},"Focus ring excludes hidden/disabled controls and never mutates")

func _geometry(page, dimensions: Vector2) -> void:
	page.size = dimensions; page._layout(); await _frames(2)
	_check(Rect2(Vector2.ZERO,dimensions).encloses(page.frame.get_rect()),"Frame inside direct logical canvas "+str(dimensions))
	var rectangles: Array[Rect2] = []
	for id: String in IDS:
		var cell: Dictionary = page.cells[id]
		var rect: Rect2 = cell.panel.get_rect()
		_check(Rect2(Vector2.ZERO,page.frame.size).encloses(rect),"Actor area inside folio: "+id)
		for previous: Rect2 in rectangles: _check(not previous.intersects(rect),"Actor areas separate: "+id)
		rectangles.append(rect)
		for node in cell.panel.get_children():
			if node is Control and node.visible:
				var actual: Rect2 = node.get_rect()
				var bounds: Rect2 = Rect2(Vector2.ZERO,cell.panel.size)
				var contained: bool = bounds.encloses(actual)
				if not contained:
					checkpoints.append({"section":current_section,"label":"exact_geometry_failure","canvas":[dimensions.x,dimensions.y],"actor":id,"node":node.name,"actual":[actual.position.x,actual.position.y,actual.size.x,actual.size.y],"parent":[bounds.size.x,bounds.size.y],"minimum":[node.get_minimum_size().x,node.get_minimum_size().y],"overflow_end":[actual.end.x-bounds.end.x,actual.end.y-bounds.end.y]})
				_check(contained,"Bounded visible actor content "+id+"/"+node.name+" at "+str(dimensions)+" actual="+var_to_str(actual)+" parent="+var_to_str(bounds)+" end-overflow=(%.12f, %.12f)" % [actual.end.x-bounds.end.x,actual.end.y-bounds.end.y])
		if id == "hero" and app.state.player_name.length() == 18:
			# Measure actual settled Control rectangles, including Label minimum
			# height after wrapping; planned font widths are not evidence of fit.
			var name_rect: Rect2 = cell.name.get_rect()
			for key: String in ["role","status","portrait","hp","qi","hp_bar","qi_bar"]:
				if cell[key].visible:
					_check(not name_rect.intersects(cell[key].get_rect()),"Settled maximum-name rectangle never overlaps "+key+" at "+str(dimensions)+" name="+var_to_str(name_rect)+" target="+var_to_str(cell[key].get_rect()))
		for key: String in ["hp","qi","actions"]:
			if cell[key].visible:
				_check(cell[key].get_theme_font_size("font_size") >= 18,"Readable body font: "+id+"/"+key)
		for key: String in ["toggle","story"]:
			if cell[key].visible: _check(cell[key].size.y >= 38,"Usable native target: "+id+"/"+key)
		_check(not cell.toggle.get_rect().intersects(cell.story.get_rect()) if cell.story.visible else true,"Cell action targets separate: "+id)
	_check(not page.notice.get_rect().intersects(page.return_button.get_rect()),"Notice never overlaps return")
	if page.retry_button.visible:
		_check(not page.notice.get_rect().intersects(page.retry_button.get_rect()) and not page.return_button.get_rect().intersects(page.retry_button.get_rect()),"Failure notice/retry/return have separate bounds")
	var count: int = page.find_children("*","",true,false).size()
	for repeat in range(4): page.refresh()
	_check(page.find_children("*","",true,false).size() == count,"Repeated refresh never accumulates controls/decorations")

func _unrecruited() -> void:
	_section("unrecruited_both_origins")
	if not await _prepare(_new_state(),"unrecruited"): return
	for direct: bool in [false,true]:
		var before = _snapshot("Unrecruited before entry")
		var page = await _open(direct)
		if page == null: return
		_check(page.return_button.has_focus() and page.cells.hero.toggle.disabled,"Unrecruited safe initial return focus, fixed hero")
		for id: String in ["shen","tang","qin"]:
			var cell: Dictionary = page.cells[id]
			_check(not cell.panel.get_meta("recruited") and cell.empty.visible and cell.hint.visible and not cell.portrait.visible and cell.portrait.texture == null,"Unrecruited placeholder has no leaked portrait: "+id)
			for field: String in ["hp","qi","hp_bar","qi_bar","actions"]: _check(not cell[field].visible,"No unrecruited data visible: "+id+"/"+field)
			_check(cell.toggle.disabled and cell.story.text == "结识线索","Unrecruited controls disclose invitation requirement")
			page._toggle_actor(id)
		page._toggle_actor("hero"); page._toggle_actor("unknown"); page._choose_formation("护后")
		_expect(before,{},"Invalid and locked direct callbacks are inert")
		await _focus_ring(page)
		await _geometry(page,Vector2(1280,800)); await _geometry(page,Vector2(1179,737))
		page.size = Vector2(1280,800); page._layout()
		await _return_origin(direct)
		_expect(before,{},"Unrecruited entry/return preserves story/resources/save content")

func _roster_and_focus() -> void:
	_section("four_selected_order_resources_focus")
	if not await _prepare(_all_state(),"all four; independent low and downed resources"): return
	var page = await _open(false)
	if page == null: return
	_values(page); await _focus_ring(page)
	var before = _snapshot("Before Shen bench")
	await _pointer(page.cells.shen.toggle,"Bench downed Shen")
	_expect(before,{"party_roster":["hero","tang","qin"]},"One deliberate bench preserves all resources",true)
	_values(page)
	before = _snapshot("Before downed rejoin")
	page.cells.shen.toggle.grab_focus(); await _key(KEY_SPACE)
	_expect(before,{"party_roster":["hero","tang","qin","shen"]},"Space rejoins downed Shen at actual end",true)
	_values(page)
	_check(app.state.party_roster.size() == 4,"Full hero plus three capacity retained")
	before = _snapshot("Invalid over-capacity and duplicate membership")
	_check(not app.state.set_party_roster(["hero","tang","qin","shen","unknown"]) and not app.state.set_party_roster(["hero","tang","qin","tang"]),"Unknown/duplicate roster rejected by real model")
	_expect(before,{},"Invalid model membership has no side effects")
	for formation: String in ["护后","并肩"]:
		before = _snapshot("Before formation "+formation)
		await _pointer(page.formation_buttons[formation],"Choose "+formation)
		_expect(before,{"formation":formation},"Explicit formation only changes formation",true)
		before = _snapshot("Before repeated formation")
		await _pointer(page.formation_buttons[formation],"Repeat "+formation)
		_expect(before,{},"Repeated same formation is inert")
		_check(page.formation_buttons[formation].button_pressed,"Current native formation remains selected")
	await _return_origin(false)
func _origins_and_stale() -> void:
	_section("story_detours_origins_and_stale")
	for recruited: bool in [false,true]:
		if not await _prepare(_all_state() if recruited else _new_state(),"Story detours recruited="+str(recruited)): return
		for direct: bool in [false,true]:
			for id: String in ["shen","tang","qin"]:
				var page = await _open(direct)
				if page == null: return
				var before = _snapshot("Before "+id+" detour; direct="+str(direct))
				var stale_story: Callable = page.story_callbacks[id]
				var stale_return: Callable = page.return_callback
				var stale_changed: Callable = page.changed_callback
				page.cells[id].story.grab_focus(); await _key(KEY_ENTER)
				_check(app.active_modal and _folio() == null and app.modal_actions.size() >= 2,"Actual story info opened: "+id)
				if app.modal_actions.size() < 2: return
				var old_back: Callable = app.modal_actions[0]
				var old_close: Callable = app.modal_actions[1]
				await _key(KEY_1)
				page = _folio()
				if not _check(page != null,"Story return restores roster"): return
				var generation: int = app.modal_generation
				old_back.call(); old_close.call(); stale_story.call(); stale_return.call(); stale_changed.call()
				_check(app.modal_generation == generation and _folio() == page,"Repeated/stale story/return/change callbacks cannot replace restored page")
				_check(page.return_button.text == ("继续赶路" if direct else "返回行囊"),"Story back retains entry origin")
				_expect(before,{},"Story detour cannot heal, recruit, advance, reward, or change save bytes")
				await _return_origin(direct)
				generation = app.modal_generation
				old_back.call(); old_close.call(); stale_story.call(); stale_return.call(); stale_changed.call()
				_check(not app.active_modal and app.modal_generation == generation,"Detached story callbacks cannot reopen exploration")
				_expect(before,{},"Detour and origin close preserve canonical state and save content")
			# Immediate queued-for-deletion guards can be invoked before objects free.
			var page = await _open(direct)
			var before = _snapshot("Before replacement stale UI methods")
			app._show_inventory()
			page._toggle_actor("tang"); page._choose_formation("护后"); page._open_story("qin"); page.retry_save(); page.close()
			_expect(before,{},"Detached immediate UI methods all reject replacement generation")
			_check(app.overlay.get_meta("inventory",false),"Replacement inventory retained")
			await _key(KEY_4)

func _create_collision() -> bool:
	var temporary = owned_user.path_join("hero_save.json.tmp")
	if not _check(_no_links(owned_user) and ProjectSettings.globalize_path(SAVE_PATH+".tmp") == temporary,"Collision is exactly owned user temporary save path"): return false
	if not _check(not FileAccess.file_exists(temporary) and not DirAccess.dir_exists_absolute(temporary),"Collision never replaces existing data"): return false
	if not _check(DirAccess.make_dir_absolute(temporary) == OK,"Create fresh empty-directory collision for actual production FileAccess.WRITE failure"): return false
	collision_owned = true
	return true

func _remove_collision() -> bool:
	if not collision_owned: return true
	var temporary = owned_user.path_join("hero_save.json.tmp")
	var directory = DirAccess.open(temporary)
	if not _check(_no_links(temporary) and directory != null,"This run's collision remains a nonsymlink directory"): return false
	directory.include_hidden = true; directory.include_navigational = false
	if not _check(directory.get_files().is_empty() and directory.get_directories().is_empty(),"This run's collision is verified empty before removal"): return false
	if not _check(DirAccess.remove_absolute(temporary) == OK,"Remove only this owned empty collision directory"): return false
	collision_owned = false
	return true

func _real_failure_retry() -> void:
	_section("real_file_failure_button_f5_reload")
	for direct: bool in [false,true]:
		if not await _prepare(_all_state(),"real failure; direct="+str(direct)): return
		var page = await _open(direct)
		if page == null or not _create_collision(): return
		var before = _snapshot("Disk checkpoint before real failed roster autosave")
		await _pointer(page.cells.tang.toggle,"Deliberate Tang bench with real write collision")
		_expect(before,{"party_roster":["hero","shen","qin"]},"Real FileAccess failure leaves exactly one accepted roster change and old disk")
		_check(app.save_warning and page.retry_button.visible and page.notice.text == "队伍仍保留在当前旅程，但尚未存妥；请点击重试保存。","Actual production modal failure notice is displayed")
		var failed = _snapshot("Failed memory accepted; old save retained")
		await _pointer(page.formation_buttons[app.state.formation],"Same formation while save failure pending")
		_expect(failed,{},"Same formation after failure does not mutate or clear warning")
		_check(app.save_warning and page.retry_button.visible,"Same formation keeps pending retry")
		await _focus_ring(page)
		await _geometry(page,Vector2(1280,800)); await _geometry(page,Vector2(1179,737))
		page.size = Vector2(1280,800); page._layout()
		await _pointer(page.retry_button,"Explicit retry still fails")
		_expect(failed,{},"Real second failed save preserves once-only accepted state and old bytes")
		_check(app.save_warning and page.retry_button.visible,"Repeat genuine failure keeps retry visible")
		await _key(KEY_ESCAPE)
		if direct: page = await _open(true)
		else:
			_check(app.overlay.get_meta("inventory",false),"Failure return goes to inventory")
			await _key(KEY_5); page = _folio()
		_check(page != null and app.save_warning and page.retry_button.visible,"Read-only roster reopening retains failure and accepted roster")
		_expect(failed,{},"Return/reopen does not replay roster change")
		if not _remove_collision(): return
		page.retry_button.grab_focus()
		await _pointer(page.retry_button,"Explicit successful retry after empty collision removal")
		_expect(failed,{},"Button retry persists accepted roster without healing or replay",true)
		_check(_folio() == page and not page.retry_button.visible and page.return_button.has_focus(),"Successful retry keeps page, hides retry and moves native focus to visible return")
		before = _snapshot("After successful button retry")
		page.retry_save(); page.retry_save()
		_expect(before,{},"Repeated successful retry callback is inert once notice cleared")
		if not _create_collision(): return
		before = _snapshot("Before real failed formation save")
		await _pointer(page.formation_buttons["护后"],"Formation change with real write collision")
		_expect(before,{"formation":"护后"},"Real formation save failure accepts exactly one formation change")
		failed = _snapshot("Accepted formation awaiting F5")
		await _key(KEY_F5)
		_expect(failed,{},"Host F5 retries genuine failure without replay")
		_check(app.save_warning and page.retry_button.visible,"Failed F5 keeps notice")
		if not _remove_collision(): return
		page.retry_button.grab_focus(); await _key(KEY_F5)
		_expect(failed,{},"Host F5 writes exact roster/formation/resources",true)
		_check(not page.retry_button.visible and page.return_button.has_focus(),"F5 success also repairs hidden retry focus")
		await _return_origin(direct)
		var saved = _snapshot("Before reload sentinel")
		app.state.coins -= 1
		_check(app.state.to_dict() != saved.state and _disk() == saved.disk,"Reload sentinel changes memory alone")
		await _key(KEY_F9)
		_check(app.state.to_dict() == saved.state,"Real Main F9 restores entire actual saved roster/formation/resources")
		_saved(saved.state,"Post-F9 exact state")

func _wide_and_invalid() -> void:
	_section("legal_max_name_wide_values_invalid_snapshot")
	if not await _prepare(_all_state(true),"maximum legal 18-character name and validated wide HP/Qi"): return
	var page = await _open(true)
	if page == null: return
	_check(app.state.player_name.length() == 18 and page.cells.hero.name.text == app.state.player_name,"Full legal 18-character name remains exact label content")
	_values(page)
	await _geometry(page,Vector2(1280,800)); await _geometry(page,Vector2(1179,737))
	page.size = Vector2(1280,800); page._layout()
	await _return_origin(true)
	var original: Dictionary = app.state.party_resources.shen.duplicate(true)
	app.state.party_resources.shen.hp = -1
	app._refresh(); await _frames(2)
	var invalid = _snapshot("Prepared invalid live snapshot; not written")
	app._show_exploration_party_roster(app.modal_generation)
	_check(not app.active_modal and _folio() == null,"HUD host blocks invalid snapshot entry")
	app._show_party_roster(false); await _frames(2)
	page = _folio()
	if not _check(page != null,"Host inventory folio can disclose invalid snapshot"): return
	_check(page.summary.text == "同行资料暂不可用","Invalid snapshot disclosure replaces stale summary")
	for id: String in IDS:
		var cell: Dictionary = page.cells[id]
		_check(not cell.portrait.visible and cell.portrait.texture == null and not cell.hp.visible and not cell.qi.visible and not cell.actions.visible and cell.toggle.disabled,"Invalid snapshot cannot leak stale actor data: "+id)
		page._toggle_actor(id)
	page._choose_formation("护后")
	_expect(invalid,{},"Invalid snapshot direct controls do not mutate or persist")
	app.state.party_resources.shen = original
	page.refresh(); _values(page)
	await _return_origin(false)

func _blocking() -> void:
	_section("quit_battle_and_stale_boundaries")
	if not await _prepare(_all_state(),"blocking boundary"): return
	for direct: bool in [false,true]:
		var page = await _open(direct)
		if page == null: return
		var before = _snapshot("Before quit-pending guards")
		app.quit_pending = true
		page._toggle_actor("shen"); page._choose_formation("护后"); page._open_story("qin"); page.retry_save(); page.close()
		app._show_party_roster(); app._show_exploration_party_roster(app.modal_generation)
		_expect(before,{},"Quit pending rejects live and host callbacks")
		_check(_folio() == page,"Quit pending cannot replace existing modal")
		app.quit_pending = false
		app.state.battle_active = true; page.refresh()
		before = _snapshot("Before active battle flag guards")
		for id: String in ["shen","tang","qin"]:
			_check(page.cells[id].toggle.disabled and page.cells[id].story.disabled,"Battle disables actions: "+id)
			page._toggle_actor(id); page._open_story(id)
		page._choose_formation("护后"); page.retry_save(); page.close(); app._show_party_roster()
		_expect(before,{},"Battle flag blocks current/stale mutation/navigation")
		app.state.battle_active = false
		# close() deliberately invalidates this UI, even when host blocks return;
		# replace it explicitly to continue the test at the same entry origin.
		app._show_party_roster(direct); await _frames(2)
		await _return_origin(direct)
	# Capture real host callbacks, then let the actual unified controller own input.
	var page = await _open(true)
	var stale_story: Callable = page.story_callbacks.qin
	var stale_change: Callable = page.changed_callback
	var stale_back: Callable = page.return_callback
	await _return_origin(true)
	var controller = battle_driver.open_training(app)
	if not _check(app.current_screen == "party_battle" and app.state.battle_active,"Actual unified training battle is active"): return
	var before = _snapshot("Real battle controller boundary")
	var generation: int = app.modal_generation
	for code: int in [KEY_I,KEY_F5]: await _key(code)
	app._show_party_roster(); app._show_exploration_party_roster(generation)
	stale_story.call(); stale_change.call(); stale_back.call()
	_expect(before,{},"Actual battle rejects folio input and stale host callbacks without reward/resource/save changes")
	_check(app.modal_generation == generation and app.overlay.get_meta("party_battle",null) == controller and controller.pending.is_empty(),"Actual battle controller, generation and pending transaction retained")
	battle_driver.leave(app)
	_check(app.current_screen == "explore" and not app.state.battle_active,"Real controller retreat returns to exploration")

func _finish() -> void:
	if finished: return
	finished = true
	if collision_owned: _remove_collision()
	if is_instance_valid(app): app._stop_audio(); app.free()
	if guard_passed:
		if not _no_links(report_path) or FileAccess.file_exists(report_path) or DirAccess.dir_exists_absolute(report_path):
			push_error("ERROR: companion folio report path became unsafe before write"); quit(2); return
		var report = {"suite":"companion_folio_behavior","status":"pass" if failures.is_empty() else "fail","checks":checks,"failures":failures,"sections":sections,"checkpoints":checkpoints,"inputs":inputs,"user_dir":owned_user,"limits":["Prepared validated fixtures are not progression earned in this run","Headless behavior/geometry is not native visual certification","Exact save bytes do not prove absence of same-content writes","Ordinary inventory-close autosave is preserved","This suite uses no save override; original adapter tests complement once-only call counts"]}
		var file = FileAccess.open(report_path,FileAccess.WRITE)
		if file == null: push_error("ERROR: companion folio report cannot be opened"); quit(2); return
		file.store_string(JSON.stringify(report,"\t")); file.flush()
		var error = file.get_error(); file.close()
		if error != OK: push_error("ERROR: companion folio report write failed"); quit(2); return
	if failures.is_empty(): print("PASS: NEW companion folio behavior, %d checks" % checks)
	else: push_error("ERROR: companion folio behavior failed, %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
