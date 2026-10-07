extends SceneTree
## Independent Title Entry acceptance. No game resource loads before the
## ownership guard. Main/LocalSaveSlots are exact production; the State probe
## counts and forwards unchanged production reset, reader and writer operations.
const SAVE_PATH = "user://hero_save.json"
const LOAD_CHOICES = ["自动续写","手记一","手记二","手记三","返回"]
const TRANSIENT_KEYS = ["enemy_name","enemy_hp","enemy_max_hp","enemy_intent","battle_active","battle_kind","turn","guard","battle_log","skill_cooldown","enemy_base_attack","enemy_strong_attack","exposed_turns","enemy_weaken_amount","enemy_weaken_strikes","focused_damage","_companion_attack_count","_trial_art_used","_trial_healing","_trial_guarded_heavy","party_battle_epoch","party_settlement","_party_pending_token","_party_encounter","_party_sluice_entry","_party_archive_entry","_party_extra_entry","_party_practice_before","_party_consignee_identity","_party_capstone_identity","_fitting_comparison_key","_fitting_comparisons","_fitting_last_result_epoch","receipt_battle_epoch","receipt_settlement"]

var app
var model
var probe
var store
var owned_root = ""
var owned_user = ""
var report_path = ""
var probe_path = ""
var current_section = "guard"
var checks = 0
var failures: Array[String] = []
var sections: Array[Dictionary] = []
var checkpoints: Array[Dictionary] = []
var inputs: Array[Dictionary] = []
var collisions: Array[String] = []
var guard_passed = false
var finished = false
var section_checks = 0
var section_failures = 0

const TITLE_NOTICE = "所有保存均为格式16，旧版无法读取；自动存档不额外备份。"
const NEW_CONSEQUENCES = "继续新旅程将替换当前自动存档，三份手动手记不会删除。\n\n若要接着之前的经历，请选择返回，再点‘续写前缘’。"
const TITLE_STORY = "你带着一封没有署名的旧信，来到水路尽头的青苇渡。\n今夜，渡口的引航灯没有亮。"
const TITLE_MOTTO = "江湖未必始于名山大派，也可能始于一盏被人摘走的灯。"
const BROWSER_RETRY_NOTICE = "自动存档失败，请打开小憩，点击保存当前旅程重试。"
var geometry_samples: Array[Dictionary] = []

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	if not _guard():
		push_error("ERROR: title entry guard rejected before game loads")
		quit(2); return
	guard_passed = true
	create_timer(180.0).timeout.connect(func():
		if not finished:
			_check(false,"Title entry watchdog expired")
			_finish())
	if not await _boot(): _finish(); return
	for step: Callable in [_empty_and_manual_availability,_confirmation_and_native_input,_pointer_replay_and_quit,_load_failures,_successful_load_and_autosave_failure,_new_game_write_failure,_legacy_upgrade_and_sect_return,_non_title_scope,_geometry]:
		await step.call()
		if not failures.is_empty(): _finish(); return
	_finish()

func _guard() -> bool:
	# Reuse the existing isolated launcher's contract, rather than invent a
	# second engine or project-copy launcher. Each process needs a fresh root.
	owned_root = OS.get_environment("HERO_FOLIO_QA_OWNED_ROOT")
	owned_user = OS.get_environment("HERO_FOLIO_QA_USER_DIR")
	report_path = OS.get_environment("HERO_FOLIO_QA_REPORT")
	var token = OS.get_environment("HERO_FOLIO_QA_TOKEN")
	if owned_root.is_empty() or owned_user.is_empty() or report_path.is_empty() or token.length() < 24: return false
	for path: String in [owned_root,owned_user,report_path]:
		if not path.is_absolute_path() or path != path.simplify_path() or path.ends_with("/"): return false
	if owned_root.get_slice_count("/") < 4 or not DirAccess.dir_exists_absolute(owned_root): return false
	if not owned_user.begins_with(owned_root+"/"): return false
	if not report_path.begins_with(owned_root+"/") or report_path.begins_with(owned_user+"/"): return false
	var project = ProjectSettings.globalize_path("res://").trim_suffix("/").simplify_path()
	if report_path.begins_with(project+"/"): return false
	if OS.get_user_data_dir().simplify_path() != owned_user: return false
	if ProjectSettings.globalize_path("user://").trim_suffix("/").simplify_path() != owned_user: return false
	for path: String in [owned_root,owned_user,report_path.get_base_dir()]:
		if not _no_links(path): return false
	var marker = owned_root.path_join(".hero-folio-qa-owner")
	if not FileAccess.file_exists(marker) or not _no_links(marker): return false
	if FileAccess.get_file_as_string(marker).strip_edges() != token: return false
	if not _no_links(report_path) or FileAccess.file_exists(report_path) or DirAccess.dir_exists_absolute(report_path): return false
	if not DirAccess.dir_exists_absolute(report_path.get_base_dir()): return false
	var directory = DirAccess.open(owned_user)
	if directory == null: return false
	directory.include_hidden = true
	if not directory.get_files().is_empty(): return false
	for child: String in directory.get_directories():
		if child not in ["logs","shader_cache"] or not _tree_unlinked(owned_user.path_join(child)): return false
	probe_path = get_script().resource_path.get_base_dir().path_join("title_entry_probe_state.gd")
	if not FileAccess.file_exists(probe_path) or not _no_links(ProjectSettings.globalize_path(probe_path)): return false
	return true

func _no_links(path: String) -> bool:
	var cursor = path
	while cursor != "/" and not cursor.is_empty():
		var parent = DirAccess.open(cursor.get_base_dir())
		if parent == null or parent.is_link(cursor.get_file()): return false
		cursor = cursor.get_base_dir()
	return true

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

func _boot() -> bool:
	model = load("res://scripts/game_state.gd")
	var scene = load("res://scenes/main.tscn")
	var probe_script = load(probe_path)
	if not _check(model != null and scene != null and probe_script != null,"Production and test resources load only after guard"): return false
	app = scene.instantiate(); probe = probe_script.new(); app.state = probe
	root.size = Vector2i(1280,800); root.add_child(app); await _frames(3)
	app._stop_audio(); app.audio_on = false; app.browser_mode = false
	store = app.save_slots.store
	_check(app.get_script().resource_path == "res://scripts/main.gd","Exact production Main; no quit or modal override")
	_check(store.get_script().resource_path == "res://scripts/local_save_slots.gd","Exact production LocalSaveSlots")
	_check(model.SAVE_VERSION == 16,"Schema remains16")
	_check(not app.web_save_transfer_enabled,"File transfer is shipped default-off")
	return failures.is_empty()

func _begin(label: String) -> void:
	current_section = label; section_checks = checks; section_failures = failures.size()
	print("TITLE_ENTRY_CASE "+label)

func _end() -> void:
	sections.append({"name":current_section,"checks":checks-section_checks,"failures":failures.size()-section_failures,"state_mode":"forwarding_observation_subclass" if app.state == probe else "exact_production_state"})

func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(current_section+": "+label)
		push_error("ERROR: title entry "+failures[-1])
	return ok

func _frames(count: int = 2) -> void:
	for index: int in count: await process_frame

func _key(code: int, echo: bool = false, shift: bool = false) -> void:
	inputs.append({"case":current_section,"kind":"queued_key","key":OS.get_keycode_string(code),"echo":echo,"shift":shift})
	for pressed: bool in [true,false]:
		var event = InputEventKey.new(); event.keycode = code; event.physical_keycode = code
		event.pressed = pressed; event.echo = echo if pressed else false; event.shift_pressed = shift
		Input.parse_input_event(event); Input.flush_buffered_events(); await _frames(1)
	await _frames(2)

func _key_edge(code: int, pressed: bool) -> void:
	inputs.append({"case":current_section,"kind":"queued_key_edge","key":OS.get_keycode_string(code),"pressed":pressed,"echo":false})
	var event = InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.pressed = pressed
	Input.parse_input_event(event); Input.flush_buffered_events(); await _frames(2)

func _release_focus() -> void:
	var focus = root.gui_get_focus_owner()
	if focus != null: focus.release_focus()

func _buttons(node: Node = null) -> Array:
	if node == null: node = app.overlay
	var found: Array = []
	if node is Button and node.is_visible_in_tree(): found.append(node)
	for child: Node in node.get_children(): found.append_array(_buttons(child))
	return found

func _button(caption: String):
	for button: Button in _buttons():
		if button.text == caption: return button
	return null

func _text(node: Node = null) -> String:
	if node == null: node = app.overlay
	var value: String = ""
	if node is Label or node is RichTextLabel or node is Button:
		if node.is_visible_in_tree(): value = node.text+"\n"
	for child: Node in node.get_children(): value += _text(child)
	return value

func _choices(expected: Array) -> void:
	var buttons = _buttons()
	_check(root.gui_get_focus_owner() == null,"Opening a folio page does not automatically claim native focus")
	_check(buttons.map(func(button): return button.text) == expected,"Exact visible choice text/order: "+str(expected))
	_check(app.modal_actions.size() == expected.size(),"Exact numbered choice count "+str(expected.size()))
	for index: int in mini(expected.size(),mini(buttons.size(),app.modal_actions.size())):
		var matched = false
		for connection: Dictionary in buttons[index].pressed.get_connections():
			if connection.callable == app.modal_actions[index]: matched = true
		_check(matched,"Visible and numbered activation share explicit choice "+expected[index])
		_check(buttons[index].focus_mode == Control.FOCUS_ALL,"Native keyboard focus available for "+expected[index])

func _choose(caption: String) -> void:
	var button = _button(caption)
	if not _check(button != null and not button.disabled,"Enabled semantic action exists: "+caption): return
	var index = -1
	for connection: Dictionary in button.pressed.get_connections():
		index = app.modal_actions.find(connection.callable)
		if index >= 0: break
	if not _check(index >= 0 and index <= 4,"Action belongs to existing1–5 mapping: "+caption): return
	await _key(KEY_1+index)

func _mouse(point: Vector2, pressed: bool) -> void:
	inputs.append({"case":current_section,"kind":"queued_pointer","pressed":pressed,"position":[point.x,point.y]})
	var motion = InputEventMouseMotion.new(); motion.position = point; motion.global_position = point
	Input.parse_input_event(motion); Input.flush_buffered_events(); await _frames(1)
	var event = InputEventMouseButton.new(); event.position = point; event.global_position = point
	event.pressed = pressed; event.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(event); Input.flush_buffered_events(); await _frames(2)

func _point(caption: String) -> Vector2:
	var button = _button(caption)
	if not _check(button != null and not button.disabled,"Pointer target visible and enabled: "+caption): return Vector2(-1,-1)
	return root.get_final_transform()*button.get_global_rect().get_center()

func _bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()

func _saves(manual_only: bool = false) -> Dictionary:
	var found: Dictionary = {}
	for slot: int in range(1 if manual_only else 0,4):
		for suffix: String in ["",".bak",".tmp",".bak.tmp"]:
			var path: String = store.path_for(slot)+suffix
			if FileAccess.file_exists(path):
				var bytes = _bytes(path)
				found[path] = {"size":bytes.size(),"sha256":FileAccess.get_sha256(path),"base64":"" if bytes.is_empty() else Marshalls.raw_to_base64(bytes)}
			elif DirAccess.dir_exists_absolute(path): found[path] = {"directory":true}
	return found

func _state() -> Dictionary:
	var transient: Dictionary = {}
	for key: String in TRANSIENT_KEYS: transient[key] = app.state.get(key)
	transient.party_snapshot = app.state.party_battle_snapshot().duplicate(true)
	transient.receipt_snapshot = app.state.receipt_battle_snapshot().duplicate(true)
	transient.party_session_identity = app.state.party_session.get_instance_id() if app.state.party_session != null else 0
	transient.receipt_session_identity = app.state.receipt_session.get_instance_id() if app.state.receipt_session != null else 0
	return {"canonical":app.state.to_dict().duplicate(true),"transient":transient.duplicate(true),"map":app.world.map_id,"position":app.world.player_pos,"state_script":app.state.get_script().resource_path,"state_identity":app.state.get_instance_id()}

func _writes(path: String = "") -> int:
	if path.is_empty(): return probe.save_attempts.size()
	var count = 0
	for attempt: Dictionary in probe.save_attempts:
		if attempt.path == path: count += 1
	return count

func _snapshot(label: String) -> Dictionary:
	var counted: bool = app.state == probe
	var value = {"label":label,"case":current_section,"state":_state(),"saves":_saves(),"writer_observation_active":counted,"writer_calls":_writes() if counted else null,"auto_calls":_writes(SAVE_PATH) if counted else null,"reader_calls":probe.load_attempts.size() if counted else null,"reset_calls":probe.reset_attempts.size(),"screen":app.current_screen,"generation":app.modal_generation,"save_warning":app.save_warning,"feedback":_text()}
	checkpoints.append(value.duplicate(true)); return value

func _unchanged(before: Dictionary, label: String, count_writes: bool = true, count_reads: bool = true) -> void:
	_check(_state() == before.state,label+": full canonical/transient state and position unchanged")
	_check(_saves() == before.saves,label+": exact save bytes and owned collision state unchanged")
	if count_writes: _check(_writes() == before.writer_calls,label+": zero production writer calls")
	if count_reads and app.state == probe: _check(probe.load_attempts.size() == before.reader_calls,label+": zero active-state reader calls")
	_check(probe.reset_attempts.size() == before.reset_calls,label+": zero reset calls")
	_snapshot(label)

func _fixture(slot: int, coins: int, backup: bool = false) -> void:
	var state = model.new(); state.coins = coins
	_check(state.save_game(store.path_for(slot)+(".bak" if backup else "")) == OK,"Production writer prepares slot%d%s with %d coins" % [slot," backup" if backup else "",coins])

func _write_owned(path: String, bytes: PackedByteArray) -> void:
	var absolute = ProjectSettings.globalize_path(path)
	if not _check(absolute.begins_with(owned_user+"/") and _no_links(absolute),"Raw fixture remains inside owned user directory"): return
	var file = FileAccess.open(path,FileAccess.WRITE)
	if not _check(file != null,"Open owned metadata fixture"): return
	file.store_buffer(bytes); file.flush(); var error = file.get_error(); file.close()
	_check(error == OK,"Owned metadata fixture written in full")

func _remove_owned_file(path: String) -> void:
	var absolute = ProjectSettings.globalize_path(path)
	if not _check(absolute.begins_with(owned_user+"/") and _no_links(absolute) and FileAccess.file_exists(path),"Only a retained test-owned fixture file may be removed"): return
	_snapshot("Retain bytes before fixture removal: "+path)
	_check(DirAccess.remove_absolute(absolute) == OK,"Remove owned fixture primary to establish backup-only case")

func _collision(path: String) -> bool:
	var absolute = ProjectSettings.globalize_path(path)
	if not _check(absolute.begins_with(owned_user+"/") and _no_links(absolute) and not FileAccess.file_exists(path) and not DirAccess.dir_exists_absolute(path),"Fresh nonsymlink collision path belongs to this test"): return false
	if not _check(DirAccess.make_dir_absolute(path) == OK,"Create genuine production I/O blocker: "+path): return false
	collisions.append(path)
	return true

func _remove_collision(path: String) -> void:
	if not _check(collisions.has(path) and _no_links(ProjectSettings.globalize_path(path)),"Collision removal owns exact path"): return
	var directory = DirAccess.open(path)
	if not _check(directory != null,"Owned collision still exists"): return
	directory.include_hidden = true; directory.include_navigational = false
	if not _check(directory.get_files().is_empty() and directory.get_directories().is_empty(),"Owned collision empty including hidden entries"): return
	if _check(DirAccess.remove_absolute(path) == OK,"Remove only owned empty collision"): collisions.erase(path)

func _page(): return app.overlay.get_node_or_null("TitleEntryPage")

func _entry(kind: String, expected: Array) -> void:
	var page = _page()
	if not _check(page != null and page.kind == kind and app.current_screen == "title" and app.active_modal,"Expected real title entry page: "+kind): return
	_choices(expected)
	for index: int in expected.size():
		var target = page.find_child("TitleEntryChoice"+str(index+1),true,false)
		_check(target is Button and target.text == expected[index],"Stable native action identity "+str(index+1))
	var version = page.find_child("BuildVersion",true,false)
	_check(version is Label and version.text == app._version_caption(),"Exact production version caption remains visible")
	if kind == "home": _check(_text().contains(TITLE_NOTICE),"Exact one-way schema16 notice is present")
	else: _check(_text().contains(NEW_CONSEQUENCES),"Exact new-journey consequences are present")

func _clear_auto() -> void:
	if FileAccess.file_exists(SAVE_PATH): _remove_owned_file(SAVE_PATH)

func _counts(before: Dictionary, resets: int, reads: int, writes: int, label: String) -> void:
	_check(probe.reset_attempts.size() == before.reset_calls+resets,label+": exact reset count")
	_check(probe.load_attempts.size() == before.reader_calls+reads,label+": exact real reader count")
	_check(_writes(SAVE_PATH) == before.auto_calls+writes,label+": exact real autosave attempt count")

func _empty_and_manual_availability() -> void:
	_begin("empty_and_manual_only_title_availability")
	_entry("home",["踏入江湖"])
	var before = _snapshot("Empty title performs no automatic action")
	for code: int in [KEY_ESCAPE,KEY_2,KEY_5,KEY_D]: await _key(code)
	await _key(KEY_ENTER,true)
	_unchanged(before,"Empty title inert keys and echo")
	var first: Callable = app.modal_actions[0]
	await _key(KEY_ENTER)
	_counts(before,1,0,1,"Explicit unfocused Enter without autosave")
	_check(app.current_screen == "explore" and not app.active_modal and _page() == null,"No-save first action starts immediately")
	_check(app.state.coins == 24 and not app.save_warning and app.state.has_save(),"New branch saved through real writer")
	var accepted = _snapshot("Accepted empty-profile start")
	first.call(); _unchanged(accepted,"Accepted home callback cannot start twice")
	_clear_auto()
	if not _collision(SAVE_PATH): _end(); return
	app._show_title(); _entry("home",["踏入江湖"])
	_check(not app.state.has_save(),"Autosave directory is not a discoverable autosave file")
	_remove_collision(SAVE_PATH)
	if not _collision(store.path_for(1)): _end(); return
	app._show_title(); _entry("home",["踏入江湖","查阅手记"])
	_check(store.has_manual_saves(),"Manual-path directory retains existing discoverability semantics")
	_remove_collision(store.path_for(1))
	_fixture(1,101); app._show_title(); _entry("home",["踏入江湖","查阅手记"])
	_check(not app.state.has_save(),"Current-only manual profile does not imply an autosave")
	_fixture(3,303,true)
	app._show_title(); _entry("home",["踏入江湖","查阅手记"])
	before = _snapshot("Manual current and backup without autosave")
	await _choose("查阅手记"); _choices(LOAD_CHOICES)
	_check(_page() == null and app.overlay.get_node_or_null("SaveFolioPage") != null,"Title manual entry opens unchanged SaveFolio")
	await _key(KEY_ESCAPE); _unchanged(before,"Manual title Escape remains inert")
	await _choose("返回"); _entry("home",["踏入江湖","查阅手记"])
	_unchanged(before,"Manual list cancellation")
	_remove_owned_file(store.path_for(1))
	app._show_title(); _entry("home",["踏入江湖","查阅手记"])
	_check(store.has_manual_saves() and not app.state.has_save(),"Backup-only manual discovery is independent from auto")
	var manual = _saves(true); before = _snapshot("Backup-only explicit start")
	await _key(KEY_SPACE)
	_counts(before,1,0,1,"Unfocused Space with manual-only backup")
	_check(app.current_screen == "explore" and not app.active_modal and _saves(true) == manual,"Manual-only start needs no confirmation and preserves all manual bytes")
	_fixture(1,101); _fixture(1,81,true); _fixture(2,202)
	_end()

func _confirmation_and_native_input() -> void:
	_begin("confirmation_cancellation_native_keyboard_and_explicit_default")
	_fixture(0,777); app.state.coins = 66
	app._show_title(); _entry("home",["踏入江湖","续写前缘","查阅手记"])
	var before = _snapshot("Existing journey before intentional home activation")
	await _key(KEY_ENTER)
	_entry("confirm_new",["确认新旅程","返回"])
	_unchanged(before,"Opening confirmation alone")
	for code: int in [KEY_ESCAPE,KEY_3,KEY_5]: await _key(code)
	await _key(KEY_SPACE,true)
	_unchanged(before,"Confirmation Escape echo and invalid digits")
	var stale: Callable = app.modal_actions[0]
	await _key(KEY_TAB); _check(root.gui_get_focus_owner() == _button("确认新旅程"),"First intentional Tab enters first native action")
	var focused_before = _snapshot("Focused destructive confirmation before echoed activation keys")
	for code: int in [KEY_ENTER,KEY_SPACE]:
		await _key(code,true)
		_unchanged(focused_before,"Focused echoed "+OS.get_keycode_string(code)+" cannot reset load or save")
		_check(app.modal_generation == focused_before.generation and _page() != null and _page().kind == "confirm_new","Focused echo retains the same unaccepted confirmation")
	await _key(KEY_TAB); _check(root.gui_get_focus_owner() == _button("返回"),"Second Tab reaches Return")
	await _key(KEY_ENTER)
	_entry("home",["踏入江湖","续写前缘","查阅手记"])
	_unchanged(before,"Focused Return Enter activates Return only")
	stale.call(); _unchanged(before,"Cancelled confirmation callback cannot reset")
	await _choose("踏入江湖"); await _key(KEY_TAB,false,true)
	_check(root.gui_get_focus_owner() == _button("返回"),"First Shift-Tab enters last action")
	await _key(KEY_SPACE); _unchanged(before,"Focused Return Space fires only Return")
	await _key(KEY_TAB); _check(root.gui_get_focus_owner() == _button("踏入江湖"),"Home Tab ring enters first action")
	await _key(KEY_TAB); _check(root.gui_get_focus_owner() == _button("续写前缘"),"Home next Tab focuses Continue")
	var continue_callback: Callable = app.modal_actions[1]
	await _key(KEY_ENTER)
	_counts(before,0,1,1,"Focused native Continue")
	_check(app.current_screen == "explore" and app.state.coins == 777 and not app.active_modal,"Continue restores stored branch without first-choice fallback")
	var loaded = _snapshot("Loaded by focused Continue")
	continue_callback.call(); _unchanged(loaded,"Accepted Continue callback cannot read/write twice")
	app._show_title(); before = _snapshot("Two separate intentional first-choice keystrokes")
	await _key(KEY_SPACE); _entry("confirm_new",["确认新旅程","返回"])
	var confirm: Callable = app.modal_actions[0]
	await _key(KEY_ENTER)
	_counts(before,1,0,1,"Explicit unfocused home Space then confirmation Enter")
	_check(app.state.coins == 24 and app.current_screen == "explore" and _saves(true) == _manual_from_snapshot(before),"Confirmed new journey resets progress and preserves all manual branches")
	# Exact manual comparison is kept independent from autosave replacement.
	var completed = _snapshot("Accepted explicit new-journey confirmation")
	confirm.call(); confirm.call(); _unchanged(completed,"Repeated accepted confirmation is inert")
	_check(not FileAccess.file_exists(SAVE_PATH+".bak"),"New journey does not invent autosave backup")
	_fixture(0,779); app._show_title(); await _choose("踏入江湖")
	await _key(KEY_TAB); _check(root.gui_get_focus_owner() == _button("确认新旅程"),"Explicit focus reaches native confirmation")
	before = _snapshot("Focused confirmation before Space release")
	await _key(KEY_SPACE); _counts(before,1,0,1,"Focused native confirmation Space fires once")
	_check(app.current_screen == "explore" and app.state.coins == 24,"Focused confirmation commits reset branch")
	_end()

func _pointer_replay_and_quit() -> void:
	_begin("real_pointer_held_replacement_stale_callbacks_and_quit")
	_fixture(0,888); app._show_title()
	var stale_home: Callable = app.modal_actions[0]
	var stale_continue: Callable = app.modal_actions[1]
	var point = _point("踏入江湖")
	await _mouse(point,true)
	_check(_page().kind == "home","Native pointer press alone does not activate home action")
	app._show_title(); var before = _snapshot("New home replaces held old pointer target")
	await _mouse(point,false); stale_home.call(); stale_continue.call()
	_unchanged(before,"Release and old callbacks cannot replace newer home")
	_check(app.modal_generation == before.generation and _page().kind == "home","New title generation remains selected")
	stale_home = app.modal_actions[0]; stale_continue = app.modal_actions[1]
	app._clear_overlay(); before = _snapshot("Page detached without a generation change")
	stale_home.call(); stale_continue.call(); _unchanged(before,"Detached callback cannot act even when generation still matches")
	_check(app.modal_generation == before.generation and _page() == null,"Detached page cannot remount itself")
	app._show_title()
	point = _point("踏入江湖"); await _mouse(point,true); await _mouse(point,false)
	_check(_page().kind == "confirm_new","Real pointer release opens confirmation exactly once")
	var stale_confirm: Callable = app.modal_actions[0]
	point = _point("确认新旅程"); await _mouse(point,true)
	app._show_title(); before = _snapshot("New home replaces held confirmation")
	await _mouse(point,false); stale_confirm.call(); _unchanged(before,"Late confirmation pointer release and callback are inert")
	await _choose("踏入江湖")
	var confirm: Callable = app.modal_actions[0]
	var cancel: Callable = app.modal_actions[1]
	point = _point("确认新旅程"); app.quit_pending = true; before = _snapshot("Quit pending owns current confirmation")
	for code: int in [KEY_1,KEY_2,KEY_ENTER,KEY_SPACE,KEY_ESCAPE]: await _key(code)
	confirm.call(); cancel.call(); await _mouse(point,true); await _mouse(point,false)
	_unchanged(before,"Quit pending blocks callbacks keys and pointer")
	_check(app.modal_generation == before.generation,"Quit pending cannot replace modal generation")
	app.quit_pending = false; _release_focus(); before = _snapshot("Real pointer confirmation ready")
	point = _point("确认新旅程"); await _mouse(point,true)
	_unchanged(before,"Pointer press waits for explicit release")
	await _mouse(point,false); _counts(before,1,0,1,"Real pointer accepted confirmation")
	var completed = _snapshot("Pointer confirmation completed"); confirm.call(); _unchanged(completed,"Pointer confirmation callback replay")
	for code: int in [KEY_ENTER,KEY_SPACE]:
		app._show_title(); await _choose("踏入江湖"); await _key(KEY_TAB)
		_check(root.gui_get_focus_owner() == _button("确认新旅程"),"Interrupted native key owns focused confirmation")
		before = _snapshot("Focused confirmation before held "+OS.get_keycode_string(code))
		await _key_edge(code,true)
		_unchanged(before,"Native activation press waits for release: "+OS.get_keycode_string(code))
		app._show_title(); var replaced = _snapshot("New home replaced key-held confirmation: "+OS.get_keycode_string(code))
		await _key_edge(code,false)
		_unchanged(replaced,"Key release cannot activate removed confirmation: "+OS.get_keycode_string(code))
		_check(app.modal_generation == replaced.generation and _page() != null and _page().kind == "home","Late native key release preserves newer home")
	_end()

func _load_failures() -> void:
	_begin("real_corrupt_future_empty_and_disappeared_autosave_readers")
	app.save_warning = false; app.state.coins = 69
	for kind: String in ["corrupt","unsupported","zero_bytes","disappeared"]:
		var bytes = "{broken".to_utf8_buffer()
		if kind == "unsupported": bytes = JSON.stringify({"version":model.SAVE_VERSION+1,"player":model.new().to_dict()}).to_utf8_buffer()
		elif kind == "zero_bytes": bytes = PackedByteArray()
		elif kind == "disappeared": _fixture(0,901); bytes = _bytes(SAVE_PATH)
		_write_owned(SAVE_PATH,bytes)
		app._show_title(); _entry("home",["踏入江湖","续写前缘","查阅手记"])
		_check(app.state.has_save(),"File existence retains Continue for "+kind)
		await _choose("踏入江湖"); _entry("confirm_new",["确认新旅程","返回"])
		await _choose("返回")
		if kind == "disappeared": _remove_owned_file(SAVE_PATH)
		var before = _snapshot("Real bad or removed autosave: "+kind)
		await _choose("续写前缘")
		_unchanged(before,"Failed Continue "+kind,true,false)
		_counts(before,0,1,0,"Failed Continue "+kind)
		var expected: String = "存档版本不受支持，请使用兼容的新版本。" if kind == "unsupported" else "未能读取存档：文件不存在或格式损坏。"
		var error: int = ERR_FILE_UNRECOGNIZED if kind == "unsupported" else (ERR_FILE_NOT_FOUND if kind == "disappeared" else ERR_FILE_CORRUPT)
		_check(probe.load_attempts[-1].error == error,"Actual production reader returns expected error for "+kind)
		var feedback = app.overlay.find_child("TitleEntryFeedback",true,false)
		_check(feedback is Label and feedback.is_visible_in_tree() and feedback.text == app.status_label.text and feedback.text == expected,"Same existing failure is visible inline: "+kind)
		_check(app.current_screen == "title" and app.active_modal and app.modal_generation == before.generation,"Failed Continue keeps same live home available")
		before = _snapshot("Same page permits explicit retry "+kind)
		await _choose("续写前缘"); _counts(before,0,1,0,"Fresh explicit retry "+kind)
		_unchanged(before,"Retry preserves branch and bytes "+kind,true,false)
	_fixture(0,777)
	_end()

func _successful_load_and_autosave_failure() -> void:
	_begin("loaded_branch_survives_real_followup_autosave_failure")
	_fixture(0,913); app.state.coins = 68; app.save_warning = false
	var target = model.new(); _check(target.load_game(SAVE_PATH) == OK,"Independent production reader obtains expected stored branch")
	if not _collision(SAVE_PATH+".tmp"): _end(); return
	app._show_title(); var before = _snapshot("Valid Continue before genuine atomic write obstruction")
	var manual = _saves(true); var accepted: Callable = app.modal_actions[1]
	await _choose("续写前缘")
	_counts(before,0,1,1,"Successful Continue with failed automatic rewrite")
	_check(app.current_screen == "explore" and not app.active_modal and app.state.to_dict() == target.to_dict(),"Entire loaded branch remains applied despite write failure")
	_check(app.world.map_id == target.map_id and app.world.player_pos == target.position,"Loaded production map and position applied")
	_check(probe.save_attempts[-1].error != OK and probe.load_attempts[-1].error == OK,"Actual read succeeds and actual atomic temp open fails")
	_check(_saves() == before.saves and _saves(true) == manual,"Failed post-load autosave preserves exact auto/manual/backup bytes")
	_check(app.save_warning and app.status_label.text.contains("读档成功") and app.status_label.text.contains("自动存档失败"),"Success feedback retains unresolved autosave warning")
	var loaded = _snapshot("Loaded memory despite failed persistence"); accepted.call(); _unchanged(loaded,"Accepted Continue cannot replay after failed autosave")
	app._process(8.0); _check(app.save_warning and app.status_label.text.contains("自动存档失败"),"Failure latch survives normal toast expiry")
	_remove_collision(SAVE_PATH+".tmp")
	before = _snapshot("Normal F5 retry after removing only owned obstruction")
	await _key(KEY_F5); _counts(before,0,0,1,"Production F5 recovery")
	_check(not app.save_warning,"Normal F5 clears warning only after success")
	var reloaded = model.new(); _check(reloaded.load_game(SAVE_PATH) == OK and reloaded.to_dict() == app.state.to_dict(),"Fresh production reader proves entire loaded branch persisted")
	_check(_saves(true) == manual,"F5 retry leaves all manual branches intact")
	_end()

func _new_game_write_failure() -> void:
	_begin("new_journey_reset_survives_real_autosave_failure")
	_fixture(0,934); app.state.coins = 937; app._show_title()
	await _choose("踏入江湖")
	if not _collision(SAVE_PATH+".tmp"): _end(); return
	var before = _snapshot("New-journey explicit confirmation before real failed write")
	var manual = _saves(true); var accepted: Callable = app.modal_actions[0]
	await _choose("确认新旅程"); _counts(before,1,0,1,"New journey with genuine failed auto write")
	var reset = model.new(); reset.reset_game()
	_check(app.state.to_dict() == reset.to_dict() and app.current_screen == "explore" and not app.active_modal,"Complete reset branch stays in memory after failure")
	_check(app.save_warning and probe.save_attempts[-1].error != OK,"Real new-journey failure remains signaled")
	_check(_saves() == before.saves and _saves(true) == manual,"Original automatic and manual save bytes survive failed new journey")
	var failed = _snapshot("Reset branch waiting for save recovery"); accepted.call(); _unchanged(failed,"Accepted reset callback cannot repeat after failure")
	_remove_collision(SAVE_PATH+".tmp"); await _key(KEY_F5)
	var reloaded = model.new(); _check(reloaded.load_game(SAVE_PATH) == OK and reloaded.to_dict() == reset.to_dict() and not app.save_warning,"Normal F5 persists reset branch and clears failure")
	_end()

func _legacy_upgrade_and_sect_return() -> void:
	_begin("explicit_legacy_autosave_upgrade_and_pending_sect_return")
	var legacy_path = "res://tests/fixtures/weapon_fitting/schema_15_default.json"
	if not _check(FileAccess.get_sha256(legacy_path) == "decba7dffc7af4906c3e3166e1b32ac9765329434869a3dcd0bf86f3653e17d6","Pinned actual-old15-producer fixture bytes retained"): _end(); return
	_write_owned(SAVE_PATH,_bytes(legacy_path)); app._show_title()
	var before = _snapshot("Historical schema15 autosave before passive title")
	_entry("home",["踏入江湖","续写前缘","查阅手记"])
	await _choose("踏入江湖"); await _choose("返回")
	_unchanged(before,"Title and cancellation cannot upgrade historical save bytes")
	await _choose("续写前缘"); _counts(before,0,1,1,"Explicit legacy Continue uses normal read and writer")
	var upgraded = JSON.parse_string(_bytes(SAVE_PATH).get_string_from_utf8())
	_check(upgraded is Dictionary and upgraded.version == 16 and not FileAccess.file_exists(SAVE_PATH+".bak"),"Normal explicit-load autosave writes16 without adding automatic backup")
	_check(_saves(true) == _manual_from_snapshot(before),"Legacy Continue leaves all manual bytes intact")
	var pending = model.new(); pending.quest_stage = 5; pending.coins = 965
	if not _check(pending.save_game(SAVE_PATH) == OK,"Production validator/writer accepts prepared pending-sect branch"): _end(); return
	app._show_title(); before = _snapshot("Pending sect selection stored branch")
	await _choose("续写前缘"); _counts(before,0,1,1,"Pending-sect Continue reads/saves once")
	_check(app.current_screen == "explore" and app.active_modal and app.state.quest_stage == 5 and app.state.sect == "未入门" and app.state.coins == 965,"Successful load retains pending story choice")
	_check(_page() == null and _buttons().map(func(button): return button.text) == ["听潮阁","照野堂","问石门"],"Existing three-sect dialogue remains exact and outside title entry")
	app.modal_autosave_on_close = false; app._close_modal()
	_end()

func _non_title_scope() -> void:
	_begin("opt_in_scope_version_and_dormant_transfer")
	app._show_title(); var before = _snapshot("Read-only scope boundaries")
	app._modal("旧标题弹窗","原有调用","保留原有页面",[["返回",app._show_title]])
	_check(_page() == null,"An unrelated title _modal call does not implicitly opt in")
	app._show_title(); app.browser_mode = true
	_check(not app.web_save_transfer_enabled,"Shipped transfer flag remains false")
	app._show_title(); _entry("home",["踏入江湖","续写前缘","查阅手记"])
	_check(_button("导入 / 导出手记") == null,"Browser mode alone never exposes dormant transfer")
	app.browser_mode = false; app._show_title(); _unchanged(before,"All title presentation and browser-default-off checks")
	app._new_game(); await _frames()
	app._npc_dialogue("陆伯 · 守灯人","旧对话","原有对话显示",[["返回",app._close_modal]])
	_check(_page() == null and app.overlay.get_node_or_null("SaveFolioPage") == null,"Ordinary NPC dialogue stays outside title presentation")
	app.modal_autosave_on_close = false; app._close_modal()
	app._show_load_slots(); _check(_page() == null and app.overlay.get_node_or_null("SaveFolioPage") != null,"Exploration manual loading keeps existing SaveFolio")
	app.modal_autosave_on_close = false; app._close_modal()
	var fitting_ui = load("res://scripts/weapon_fitting_ui.gd")
	_check(model.SAVE_VERSION == 16 and fitting_ui.TITLE_SAVE_NOTICE == TITLE_NOTICE,"Schema and exact one-way save notice remain16")
	_end()

func _geometry() -> void:
	_begin("true_logical_geometry_and_all_native_focus_targets")
	app._show_title(); var before = _snapshot("Before title geometry and input-only focus sweep")
	var original_browser_revision: String = app.browser_build_revision
	var original_save_warning: bool = app.save_warning
	for dimensions: Vector2i in [Vector2i(1280,800),Vector2i(1179,737)]:
		root.content_scale_size = dimensions; root.size = dimensions; await _frames(5)
		_check(root.get_visible_rect().size == Vector2(dimensions) and root.get_final_transform().is_equal_approx(Transform2D.IDENTITY),"Actual unscaled logical viewport "+str(dimensions))
		app._show_title(); await _geometry_sample("home-maximum-default",dimensions)
		app._request_new_game(); await _geometry_sample("confirm-new",dimensions)
		app._show_title(); _write_owned(SAVE_PATH,"{real corrupt auto".to_utf8_buffer())
		await _choose("续写前缘"); await _geometry_sample("home-real-error",dimensions)
		_fixture(0,24)
		# Labeled existing opt-in path only; never invokes transfer or a browser API.
		app.browser_mode = true; app.web_save_transfer_enabled = true; app._show_title()
		app.browser_build_revision = "35"; app._show_title()
		await _geometry_sample("home-existing-transfer-opt-in",dimensions)
		var browser_version = _page().find_child("BuildVersion",true,false)
		_check(browser_version is Label and browser_version.text == "0.0.38 · Web 35" and browser_version.text == app._version_caption(),"Full current game version and prepared Web revision appear in measured geometry at "+str(dimensions))
		_check(_buttons().size() == 4 and _button("导入 / 导出手记") != null,"Existing optional fourth action stays reachable")
		app.web_save_transfer_enabled = false; app.browser_mode = false
		app.browser_build_revision = original_browser_revision
		# The original _toast suffix is longest in browser mode with an already
		# latched save failure. Exercise the real reader, without injecting an error.
		app.browser_mode = true; app.browser_build_revision = "1"; app.save_warning = true
		_write_owned(SAVE_PATH,JSON.stringify({"version":model.SAVE_VERSION+1,"player":model.new().to_dict()}).to_utf8_buffer())
		app._show_title(); var warning_before = _snapshot("Browser title with existing save warning before actual unsupported read")
		await _choose("续写前缘")
		_unchanged(warning_before,"Browser warning plus actual failed Continue",true,false)
		_counts(warning_before,0,1,0,"Browser warning plus actual unsupported reader")
		var warning_page = _page()
		_check(probe.load_attempts[-1].error == ERR_FILE_UNRECOGNIZED and app.save_warning,"Real unsupported read preserves existing warning latch")
		_check(warning_page.feedback.text == "存档版本不受支持，请使用兼容的新版本。  ⚠ "+BROWSER_RETRY_NOTICE and warning_page.feedback.text == app.status_label.text,"Full original longest browser error and retry suffix appear verbatim")
		_check(warning_page.find_child("BuildVersion",true,false).text == "0.0.38 · Web 1","Prepared longest-error browser revision is explicit")
		await _geometry_sample("home-browser-error-with-existing-warning",dimensions)
		# Keep the ordinary three-action error case above. This separate sample
		# combines the existing optional fourth row with the same real longest error.
		app.web_save_transfer_enabled = true; app._show_title()
		var four_row_before = _snapshot("Opt-in four-row browser title before actual unsupported read")
		var four_row_rects: Array = _buttons().map(func(button): return button.get_global_rect())
		_check(_buttons().size() == 4 and _button("导入 / 导出手记") != null,"Longest-error optional fourth row is visible without invoking transport")
		await _choose("续写前缘")
		_unchanged(four_row_before,"Four-row browser warning plus actual failed Continue",true,false)
		_counts(four_row_before,0,1,0,"Four-row browser actual unsupported reader")
		_check(_page().feedback.text == "存档版本不受支持，请使用兼容的新版本。  ⚠ "+BROWSER_RETRY_NOTICE and _page().feedback.text == app.status_label.text and app.save_warning,"Four-row case retains complete original browser error and warning latch")
		_check(_buttons().map(func(button): return button.get_global_rect()) == four_row_rects,"Real longest feedback keeps all four native action locations stable")
		_check(ProjectSettings.get_setting("hero/features/web_save_transfer_enabled",true) == false,"Optional in-memory fourth-row fixture never changes shipped project default")
		await _geometry_sample("home-four-row-browser-error-with-existing-warning",dimensions)
		app.web_save_transfer_enabled = false
		app.browser_mode = false; app.browser_build_revision = original_browser_revision; app.save_warning = original_save_warning
		_fixture(0,24)
	root.content_scale_size = Vector2i(1280,800); root.size = Vector2i(1280,800); app._show_title()
	_check(_state() == before.state and probe.reset_attempts.size() == before.reset_calls and _writes() == before.writer_calls,"Geometry/focus sweep changes no live branch and invokes no save/reset")
	_check(_saves(true) == _manual_from_snapshot(before),"Geometry and raw autosave error fixtures preserve every manual byte")
	_check(not app.web_save_transfer_enabled,"Opt-in fixture is restored to shipped-off state")
	_check(geometry_samples.size() == 12,"All eight original plus four longest-error true-logical geometry samples recorded")
	_check(app.save_warning == original_save_warning and app.browser_build_revision == original_browser_revision and not app.browser_mode,"Longest-error fixture restores original warning and browser flags")
	_end()

func _manual_from_snapshot(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for path: String in value.saves:
		if path != SAVE_PATH and not path.begins_with(SAVE_PATH+"."): result[path] = value.saves[path]
	return result

func _geometry_sample(label: String, dimensions: Vector2i) -> void:
	await _frames(5)
	var page = _page()
	if not _check(page != null,"Geometry real title page exists: "+label): return
	var canvas = Rect2(Vector2.ZERO,Vector2(dimensions))
	var record: Dictionary = {"case":label,"logical_size":[dimensions.x,dimensions.y],"kind":page.kind,"buttons":[],"rich_text":[],"labels":[]}
	_check(page.size == Vector2(dimensions),"Title page receives direct logical dimensions")
	record.typography = _typography_contract(page,canvas)
	for rich: RichTextLabel in page.find_children("*","RichTextLabel",true,false):
		if not rich.is_visible_in_tree(): continue
		var style: StyleBox = rich.get_theme_stylebox("normal")
		var scrollbar = rich.get_v_scroll_bar()
		var inner_height: float = rich.size.y-style.get_minimum_size().y
		var inner_width: float = rich.size.x-style.get_minimum_size().x-(scrollbar.size.x if scrollbar.is_visible_in_tree() else 0.0)
		_check(rich.is_finished() and rich.visible_characters == -1 and rich.visible_ratio == 1.0,"Complete mandatory rich text enabled: "+rich.name)
		_check(rich.get_content_height() <= inner_height+0.15 and rich.get_content_width() <= inner_width+0.15,"Complete mandatory text fits without cropping: "+rich.name)
		_check(is_zero_approx(scrollbar.value) and scrollbar.max_value-scrollbar.page <= 0.15,"Mandatory text needs no hidden scroll: "+rich.name)
		_check(canvas.encloses(rich.get_global_rect()),"Rich-text viewport inside logical canvas: "+rich.name)
		record.rich_text.append({"name":rich.name,"text":rich.get_parsed_text(),"rect":_rect(rich.get_global_rect()),"content_height":rich.get_content_height(),"inner_height":inner_height,"content_width":rich.get_content_width(),"inner_width":inner_width})
	for label_node: Label in page.find_children("*","Label",true,false):
		if not label_node.is_visible_in_tree() or label_node.text.is_empty(): continue
		var envelope = Rect2()
		for index: int in label_node.text.length():
			var cell = label_node.get_character_bounds(index)
			if cell.has_area(): envelope = cell if not envelope.has_area() else envelope.merge(cell)
		envelope = label_node.get_global_transform()*envelope
		_check(label_node.get_visible_line_count() == label_node.get_line_count() and label_node.visible_characters == -1 and label_node.visible_ratio == 1.0,"Native label lines fully enabled: "+label_node.name)
		_check(canvas.encloses(envelope),"Native label advance envelope inside canvas: "+label_node.name)
		record.labels.append({"name":label_node.name,"text":label_node.text,"control_rect":_rect(label_node.get_global_rect()),"native_advance_line_envelope":_rect(envelope)})
	var buttons = _buttons(); _release_focus()
	for button: Button in buttons:
		var hit = button.get_global_rect()
		_check(button.focus_mode == Control.FOCUS_ALL and not button.disabled and canvas.encloses(hit) and hit.size.x >= 44 and hit.size.y >= 44,"Usable native title target contained: "+button.text)
		for other: Button in buttons:
			if other != button: _check(not hit.intersects(other.get_global_rect()),"Real title hit targets do not overlap")
		for rich: RichTextLabel in page.find_children("*","RichTextLabel",true,false):
			if rich.is_visible_in_tree(): _check(not hit.intersects(rich.get_global_rect()),"Title actions do not overlap mandatory prose")
		await _key(KEY_TAB); _check(root.gui_get_focus_owner() == button,"Native Tab reaches expected action "+button.text)
		var focus_style = button.get_theme_stylebox("focus")
		_check(focus_style is StyleBoxFlat,"Native focus uses inspectable StyleBoxFlat")
		if focus_style is StyleBoxFlat:
			var focus = button.get_global_transform()*Rect2(Vector2.ZERO,button.size).grow_individual(focus_style.expand_margin_left,focus_style.expand_margin_top,focus_style.expand_margin_right,focus_style.expand_margin_bottom)
			_check(canvas.encloses(focus),"Declared focus border inside logical canvas")
		for point: Vector2 in [hit.get_center(),hit.position+Vector2(2,2),hit.end-Vector2(2,2)]:
			var motion = InputEventMouseMotion.new(); motion.position = point; motion.global_position = point
			Input.parse_input_event(motion); Input.flush_buffered_events(); await _frames(1)
			_check(root.gui_get_hovered_control() == button,"Real native hover routes to intended button")
		record.buttons.append({"text":button.text,"rect":_rect(hit),"font_size":button.get_theme_font_size("font_size")})
	await _key(KEY_TAB); _check(root.gui_get_focus_owner() == buttons[0],"Native title Tab ring wraps")
	await _key(KEY_TAB,false,true); _check(root.gui_get_focus_owner() == buttons[-1],"Native title Shift-Tab reverses ring")
	_release_focus(); geometry_samples.append(record)

func _label_envelope(label: Label) -> Rect2:
	var envelope = Rect2()
	for index: int in label.text.length():
		var cell = label.get_character_bounds(index)
		if cell.has_area(): envelope = cell if not envelope.has_area() else envelope.merge(cell)
	return label.get_global_transform()*envelope

func _typography_contract(page, canvas: Rect2) -> Dictionary:
	var cover: Rect2 = page.cover.get_global_rect()
	var notice: Rect2 = _label_envelope(page.notice)
	var footer_node: Label = page.find_child("TitleEntryKeyboardHelp",true,false)
	var footer: Rect2 = _label_envelope(footer_node)
	_check(page.notice.text == TITLE_NOTICE,"Original one-way save notice remains byte-for-byte unchanged")
	if page.kind == "home":
		_check(page.story.get_parsed_text().replace("\n","") == TITLE_STORY.replace("\n",""),"Narrative preserves every original letter and punctuation, allowing inserted linebreaks only")
		_check(page.motto.text.replace("\n","") == TITLE_MOTTO,"Motto preserves every original letter and punctuation, allowing inserted linebreaks only")
		_check(page.chapter.get_parsed_text() == "第一章 · 灯火不问归人","Original chapter wording remains exact")
	else:
		_check(page.story.get_parsed_text().replace("\n","") == NEW_CONSEQUENCES.replace("\n",""),"Confirmation prose preserves every original letter and punctuation")
	_check(canvas.encloses(cover),"Actual title cover stays inside logical canvas")
	_check(cover.encloses(notice) and cover.encloses(footer),"Actual notice and footer advance envelopes stay inside cover")
	_check(notice.end.y+4.0 <= footer.position.y,"Save notice clears keyboard footer by at least four logical pixels")
	_check(cover.end.y-footer.end.y >= 14.0,"Keyboard footer advance envelope clears lower cover edge by at least fourteen pixels")
	var result: Dictionary = {"cover":_rect(cover),"notice_envelope":_rect(notice),"footer_envelope":_rect(footer),"notice_footer_clearance":footer.position.y-notice.end.y,"footer_cover_clearance":cover.end.y-footer.end.y,"feedback_visible":page.feedback_band.is_visible_in_tree()}
	if page.feedback_band.is_visible_in_tree():
		var band: Rect2 = page.feedback_band.get_global_rect()
		var feedback: Rect2 = _label_envelope(page.feedback)
		_check(band.encloses(feedback) and cover.encloses(band),"Complete native feedback advance envelope fits its band and cover")
		_check(band.end.y+4.0 <= notice.position.y and not band.intersects(footer),"Actual feedback band clears save notice and keyboard footer")
		for button: Button in page.buttons:
			_check(not band.intersects(button.get_global_rect()),"Error feedback does not overlap native actions")
		_check(page.feedback.get_visible_line_count() == page.feedback.get_line_count() and page.feedback.visible_characters == -1 and page.feedback.visible_ratio == 1.0,"Every line of full current feedback remains enabled")
		result.merge({"feedback_text":page.feedback.text,"feedback_band":_rect(band),"feedback_envelope":_rect(feedback),"feedback_notice_clearance":notice.position.y-band.end.y})
	return result

func _rect(value: Rect2) -> Array: return [value.position.x,value.position.y,value.size.x,value.size.y]

func _finish() -> void:
	if finished: return
	finished = true
	for path: String in collisions.duplicate(): _remove_collision(path)
	if is_instance_valid(app): app._stop_audio(); app.free()
	if guard_passed:
		if not _no_links(report_path) or FileAccess.file_exists(report_path) or DirAccess.dir_exists_absolute(report_path):
			push_error("ERROR: title entry report path unsafe before write"); quit(2); return
		var report = {"suite":"title_entry_behavior","status":"pass" if failures.is_empty() else "fail","checks":checks,"failures":failures,"sections":sections,"checkpoints":checkpoints,"inputs":inputs,"geometry":geometry_samples,"writer_attempts":probe.save_attempts if probe != null else [],"reader_attempts":probe.load_attempts if probe != null else [],"reset_attempts":probe.reset_attempts if probe != null else [],"user_dir":owned_user,"fixture_sha256":FileAccess.get_sha256(probe_path),"driver_sha256":FileAccess.get_sha256(get_script().resource_path),"limits":["Prepared legal fixtures are not earned progression","Observation subclass delegates unchanged production I/O/reset; production Main and store are exact","Reader counts cover active State only, excluding metadata preview readers","Genuine failures use raw corrupt/future/removed fixtures and an owned empty temporary-path directory; no errors are mocked","Explicit unfocused Enter/Space first-action semantics and title Escape no-op are intentionally retained","Raw/advance layout metrics are not pixel-ink proof; independent native screenshots and readability review are required","Direct logical1280x800 and1179x737; physical960x600 requires separate native capture","Transient flag-on geometry does not invoke dormant transfer; default-off restored","Full regression, exact PCK/browser and historical-reader gates remain separate"]}
		var file = FileAccess.open(report_path,FileAccess.WRITE)
		if file == null: push_error("ERROR: title entry report cannot open"); quit(2); return
		file.store_string(JSON.stringify(report,"\t")); file.flush(); var error = file.get_error(); file.close()
		if error != OK: push_error("ERROR: title entry report write failed"); quit(2); return
	if failures.is_empty(): print("PASS: NEW title entry behavior, %d checks" % checks)
	else: push_error("ERROR: title entry failed, %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
