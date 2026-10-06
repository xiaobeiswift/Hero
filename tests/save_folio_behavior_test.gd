extends SceneTree
## Independent Save Folio acceptance. No game resource loads before ownership
## guard. Main/LocalSaveSlots are production; the separately loaded State probe
## records requests/results while delegating unchanged to production I/O.
## Exact HeroState is restored for identity-gated fitting and battle sections.
const SAVE_PATH = "user://hero_save.json"
const SAVE_CHOICES = ["写下手记一","写下手记二","写下手记三","返回江湖"]
const LOAD_CHOICES = ["自动续写","手记一","手记二","手记三","返回"]
const TRANSIENT_KEYS = ["enemy_name","enemy_hp","enemy_max_hp","enemy_intent","battle_active","battle_kind","turn","guard","battle_log","skill_cooldown","enemy_base_attack","enemy_strong_attack","exposed_turns","enemy_weaken_amount","enemy_weaken_strikes","focused_damage","_companion_attack_count","_trial_art_used","_trial_healing","_trial_guarded_heavy","party_battle_epoch","party_settlement","_party_pending_token","_party_encounter","_party_sluice_entry","_party_archive_entry","_party_extra_entry","_party_practice_before","_party_consignee_identity","_party_capstone_identity","_fitting_comparison_key","_fitting_comparisons","_fitting_last_result_epoch","receipt_battle_epoch","receipt_settlement"]

var app
var model
var probe
var store
var battle_driver
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

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	if not _guard():
		push_error("ERROR: save folio ownership guard rejected startup before game loads")
		quit(2); return
	guard_passed = true
	create_timer(180.0).timeout.connect(func():
		if not finished:
			_check(false,"Save folio watchdog expired")
			_finish())
	if not await _boot(): _finish(); return
	await _title_and_choice_contract()
	if not failures.is_empty(): _finish(); return
	await _keyboard_and_once_only()
	if not failures.is_empty(): _finish(); return
	await _pointer_and_stale_callbacks()
	if not failures.is_empty(): _finish(); return
	await _metadata_and_backup_preservation()
	if not failures.is_empty(): _finish(); return
	await _real_failures_and_title_feedback()
	if not failures.is_empty(): _finish(); return
	await _loaded_branch_autosave_failure()
	if not failures.is_empty(): _finish(); return
	await _close_counts_and_transfer_provenance()
	if not failures.is_empty(): _finish(); return
	await _window_close_failure()
	if not failures.is_empty(): _finish(); return
	await _genuine_fitting_origin()
	if not failures.is_empty(): _finish(); return
	await _battle_and_quit_gates()
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
	probe_path = get_script().resource_path.get_base_dir().path_join("save_folio_probe_state.gd")
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
	battle_driver = load("res://tests/unified_ui_test_driver.gd")
	if not _check(model != null and scene != null and probe_script != null and battle_driver != null,"Production and test resources load only after guard"): return false
	app = scene.instantiate(); probe = probe_script.new(); app.state = probe
	root.size = Vector2i(1280,800); root.add_child(app); await _frames(3)
	app._stop_audio(); app.audio_on = false; app.browser_mode = false
	store = app.save_slots.store
	_check(app.get_script().resource_path == "res://scripts/main.gd","Exact production Main; no quit or modal override")
	_check(store.get_script().resource_path == "res://scripts/local_save_slots.gd","Exact production LocalSaveSlots")
	_check(model.SAVE_VERSION == 16,"Schema remains16")
	_check(not app.web_save_transfer_enabled,"File transfer remains disabled throughout suite")
	return failures.is_empty()

func _begin(label: String) -> void:
	current_section = label; section_checks = checks; section_failures = failures.size()
	print("SAVE_FOLIO_CASE "+label)

func _end() -> void:
	sections.append({"name":current_section,"checks":checks-section_checks,"failures":failures.size()-section_failures,"state_mode":"forwarding_observation_subclass" if app.state == probe else "exact_production_state"})

func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(current_section+": "+label)
		push_error("ERROR: save folio "+failures[-1])
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
				found[path] = {"size":bytes.size(),"sha256":FileAccess.get_sha256(path),"base64":Marshalls.raw_to_base64(bytes)}
			elif DirAccess.dir_exists_absolute(path): found[path] = {"directory":true}
	var transition = "user://save-folio-real-state.json"
	if not manual_only and FileAccess.file_exists(transition):
		var bytes = _bytes(transition)
		found[transition] = {"size":bytes.size(),"sha256":FileAccess.get_sha256(transition),"base64":Marshalls.raw_to_base64(bytes)}
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
	var value = {"label":label,"case":current_section,"state":_state(),"saves":_saves(),"writer_observation_active":counted,"writer_calls":_writes() if counted else null,"auto_calls":_writes(SAVE_PATH) if counted else null,"reader_calls":probe.load_attempts.size() if counted else null,"screen":app.current_screen,"generation":app.modal_generation,"save_warning":app.save_warning,"feedback":_text()}
	checkpoints.append(value.duplicate(true)); return value

func _unchanged(before: Dictionary, label: String, count_writes: bool = true, count_reads: bool = true) -> void:
	_check(_state() == before.state,label+": full canonical/transient state and position unchanged")
	_check(_saves() == before.saves,label+": exact save bytes and owned collision state unchanged")
	if count_writes: _check(_writes() == before.writer_calls,label+": zero production writer calls")
	if count_reads and app.state == probe: _check(probe.load_attempts.size() == before.reader_calls,label+": zero active-state reader calls")
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

func _feedback(fragment: String) -> void:
	var feedback = app.overlay.find_child("SaveFolioFeedback",true,false)
	_check(feedback != null and (feedback is Label or feedback is RichTextLabel) and feedback.is_visible_in_tree() and feedback.text.contains(fragment),"Current visible folio contains inline feedback: "+fragment)

func _title_and_choice_contract() -> void:
	_begin("title_cancellation_and_choice_order")
	_fixture(0,777); _fixture(1,101); _fixture(1,81,true)
	app._show_title(); var before = _snapshot("Cold title holds defaults, prior-session files are distinct")
	_check(app.state.coins == 24,"Cold-title defaults are distinct from stored777-coin branch")
	await _choose("查阅手记"); _choices(LOAD_CHOICES)
	await _key(KEY_ESCAPE); _unchanged(before,"Cold-title Escape")
	# Escape at title intentionally remains on the existing load page.
	await _choose("手记一"); _choices(["读取当前版本","读取备份","返回列表"])
	await _choose("读取当前版本"); _choices(["确认读取","返回详情"])
	var stale: Callable = app.modal_actions[0]
	await _key(KEY_ESCAPE); _unchanged(before,"Title confirmation Escape performs no load/autosave")
	await _choose("返回详情"); stale.call(); _unchanged(before,"Cancelled title load callback")
	await _choose("返回列表"); await _choose("自动续写")
	_choices(["读取当前版本","返回列表"])
	_check(not _text().contains("上一份备份"),"Read-only autosave detail does not invent manual backup")
	await _choose("返回列表"); await _choose("返回")
	_check(app.current_screen == "title","List return preserves title origin")
	_unchanged(before,"All explicit cold-title cancellations")
	app._close_modal(); _unchanged(before,"Direct title close cannot autosave defaults")
	app._new_game(); await _frames(); app._show_save_slots(); _choices(SAVE_CHOICES)
	_check(_button("导入 / 导出手记") == null and not app.web_save_transfer_enabled,"No transfer entry added")
	before = _snapshot("Save list awaiting explicit action")
	await _key(KEY_5); _unchanged(before,"Out-of-range fifth save choice is inert")
	await _key(KEY_D); _unchanged(before,"Visible folio blocks exploration movement")
	_end()

func _keyboard_and_once_only() -> void:
	_begin("keyboard_fallback_native_focus_and_exact_writes")
	app.save_slots.save_page(); _release_focus(); var before = _snapshot("No focused save choice")
	await _key(KEY_ENTER)
	_choices(["确认重写","返回手记"])
	_check(_writes() == before.writer_calls,"Unfocused Enter chooses first slot without writing before confirmation")
	await _choose("返回手记"); _release_focus(); await _key(KEY_SPACE)
	_choices(["确认重写","返回手记"])
	await _choose("返回手记")
	var other_slots = {"first":_bytes(store.path_for(1)),"second":_bytes(store.path_for(2))}
	var button = _button("写下手记三"); button.grab_focus(); await _frames()
	_check(root.gui_get_focus_owner() == button and button.has_focus(),"Third-slot native button owns focus before Enter")
	inputs.append({"case":current_section,"kind":"native_focus_before_enter","button":button.text,"action_mode":button.action_mode})
	var count = _writes(); await _key(KEY_ENTER)
	_check(_writes() == count+1 and store.describe(3).status == "valid","Focused Enter saves selected empty third slot exactly once")
	_check(_bytes(store.path_for(1)) == other_slots.first and _bytes(store.path_for(2)) == other_slots.second,"Focused Enter does not also activate fallback first choice")
	_feedback("已写下")
	app.state.coins = 242; app.save_slots.save_page(); _button("写下手记二").grab_focus()
	_check(root.gui_get_focus_owner() == _button("写下手记二"),"Second-slot native button owns focus before Space")
	count = _writes(); await _key(KEY_SPACE)
	_check(_writes() == count+1 and store.describe(2).status == "valid","Focused Space saves selected empty second slot exactly once")
	_check(_bytes(store.path_for(1)) == other_slots.first,"Focused Space does not also overwrite first slot")
	app.save_slots.request_save(2); before = _snapshot("Focused cancel in overwrite prompt")
	var cancel_button = _button("返回手记")
	if not _check(cancel_button != null,"Overwrite prompt exposes the expected native cancel button"): return
	cancel_button.grab_focus(); await _key(KEY_ENTER); _choices(SAVE_CHOICES)
	_unchanged(before,"Native focused cancellation never confirms overwrite")
	_release_focus(); await _key(KEY_TAB)
	var tab_focus = root.gui_get_focus_owner()
	inputs.append({"case":current_section,"kind":"first_tab_focus","path":str(tab_focus.get_path()) if tab_focus != null else "","class":tab_focus.get_class() if tab_focus != null else "none"})
	_check(root.gui_get_focus_owner() != null and root.gui_get_focus_owner() in _buttons(),"Tab reaches an actual enabled choice")
	before = _snapshot("Held-key echo guard"); _release_focus(); await _key(KEY_ENTER,true)
	_unchanged(before,"Unfocused key echo cannot save or navigate")
	# Repeated confirmed save must retain the prior meaningful branch.
	app.state.coins = 343; app.save_slots.request_save(3)
	var previous = _bytes(store.path_for(3)); var accepted: Callable = app.modal_actions[0]
	count = _writes(); await _choose("确认重写")
	_check(_writes() == count+1 and _bytes(store.path_for(3)+".bak") == previous,"One confirmed overwrite produces one real write and exact previous backup")
	var saved = _saves(true); count = _writes(); accepted.call()
	_check(_writes() == count and _saves(true) == saved,"Accepted callback replay is consumed by newer generation")
	app.save_slots.perform_save(3)
	_check(_writes() == count and _saves(true) == saved,"Repeated same-state request does not replace meaningful backup or call writer")
	app.state.coins = 444; accepted.call()
	_check(_writes() == count and _saves(true) == saved,"Old confirmed callback cannot save a later changed branch")
	_end()

func _pointer_and_stale_callbacks() -> void:
	_begin("pointer_press_cancel_release_and_stale_pages")
	app.save_slots.request_save(1); await _frames(); var point = _point("确认重写")
	var before = _snapshot("Overwrite before pointer down")
	await _mouse(point,true)
	_unchanged(before,"Pointer down alone is not confirmation")
	await _key(KEY_ESCAPE); var after_cancel = _snapshot("Pointer-held Escape closed modal")
	_check(_writes(SAVE_PATH) == before.auto_calls+1,"Ordinary exploration Escape saves once")
	await _mouse(point,false); _unchanged(after_cancel,"Release after Escape cannot activate removed button")
	app.save_slots.request_load(1,false); await _frames(); point = _point("确认读取")
	await _mouse(point,true); await _choose("返回详情"); app.save_slots.detail(2)
	before = _snapshot("Newer detail replaces held load confirmation")
	await _mouse(point,false); _unchanged(before,"Release cannot load through replaced page")
	_check(_text().contains("手记二"),"Late release preserves newer selected slot")
	app.save_slots.save_page(); var stale_list: Callable = app.modal_actions[0]
	app.save_slots.load_page(); var stale_detail: Callable = app.modal_actions[1]
	app.save_slots.detail(3); before = _snapshot("Newer detail invalidates both list callbacks")
	stale_list.call(); stale_detail.call()
	_unchanged(before,"Stale list/detail callbacks cannot replace current modal")
	_check(_text().contains("手记三"),"Newer slot remains visible after stale callbacks")
	app.save_slots.request_save(1); await _frames(); point = _point("确认重写")
	var previous = _bytes(store.path_for(1)); var count = _writes()
	await _mouse(point,true); _check(_writes() == count,"Successful pointer still waits for release")
	await _mouse(point,false)
	_check(_writes() == count+1 and _bytes(store.path_for(1)+".bak") == previous,"Actual pointer release confirms once with original primary backup")
	_end()

func _metadata_and_backup_preservation() -> void:
	_begin("corrupt_newer_and_backup_only_metadata")
	_fixture(3,613,true); var backup = _bytes(store.path_for(3)+".bak")
	for kind: String in ["corrupt","incompatible","empty"]:
		if kind == "corrupt": _write_owned(store.path_for(3),"{broken".to_utf8_buffer())
		elif kind == "incompatible": _write_owned(store.path_for(3),JSON.stringify({"version":model.SAVE_VERSION+1,"player":model.new().to_dict()}).to_utf8_buffer())
		else: _remove_owned_file(store.path_for(3))
		var before = _snapshot("Metadata-only fixture "+kind)
		var metadata: Dictionary = store.describe(3)
		_check(metadata.status == kind and metadata.level == 0 and metadata.location == "","Unavailable primary has honest "+kind+" metadata without guessed level/region")
		app.save_slots.detail(3); _choices(["读取备份","返回列表"])
		_check(_text().contains("上一份备份") and _text().contains("青苇渡"),"Validated backup remains described beside "+kind+" primary")
		_check(_text().contains({"corrupt":"文件不可读","incompatible":"更新版本","empty":"空白"}[kind]),"Visible primary status is explicit: "+kind)
		_unchanged(before,"Metadata browsing "+kind)
		if kind != "empty":
			app.state.coins += 1; app.save_slots.request_save(3); await _choose("确认重写")
			_check(_bytes(store.path_for(3)+".bak") == backup,"Explicit overwrite of "+kind+" primary preserves good backup byte-for-byte")
	# The backup-only slot must be discoverable even if all primary files vanish.
	for slot: int in [0,1,2]: _remove_owned_file(store.path_for(slot))
	app._show_title(); var before = _snapshot("Backup-only title")
	_check(_button("续写前缘") == null and _button("查阅手记") != null,"Title discovers backup-only recovery independently of autosave")
	await _choose("查阅手记"); await _choose("手记三"); await _choose("返回列表"); await _choose("返回")
	_unchanged(before,"Backup-only title cancellation creates no autosave")
	var manual = _saves(true); var count = _writes(SAVE_PATH); var reads = probe.load_attempts.size()
	await _choose("查阅手记"); await _choose("手记三"); await _choose("读取备份")
	_choices(["确认读取","返回详情"])
	_check(_text().contains("手记三") and _text().contains("备份") and _text().contains("替换当前内存"),"Backup confirmation identifies source and progress replacement")
	await _choose("确认读取")
	_check(app.state.coins == 613 and _writes(SAVE_PATH) == count+1,"Explicit backup-only load applies saved branch and autosaves exactly once")
	_check(probe.load_attempts.size() == reads+1 and probe.load_attempts[-1].path == store.path_for(3)+".bak","Explicit backup-only confirmation calls active-state production reader exactly once on selected backup")
	_check(_saves(true) == manual,"Reading backup-only branch never repairs or changes manual files")
	app._new_game(); _check(_saves(true) == manual,"New journey preserves every manual primary and backup byte")
	_fixture(1,711); _fixture(2,722)
	_end()

func _real_failures_and_title_feedback() -> void:
	_begin("genuine_write_failure_and_title_inline_feedback")
	app.state.coins = 899
	if not _collision(store.path_for(2)+".bak.tmp"): _end(); return
	app.save_slots.request_save(2); var before = _snapshot("Existing manual branch before blocked backup write")
	await _choose("确认重写")
	_check(_saves() == before.saves,"Production backup-open failure preserves every exact manual/autosave byte")
	_check(app.state.to_dict() == before.state.canonical,"Manual save failure preserves current in-memory branch")
	_feedback("未能保存"); _check(app.active_modal and app.status_label.text.contains("未能保存"),"Write failure stays visible in current modal and normal status")
	_check(app.save_warning == before.save_warning,"Manual failure does not change independent autosave-warning latch")
	_snapshot("Actual backup-open failure"); _remove_collision(store.path_for(2)+".bak.tmp")
	if not _collision(store.path_for(3)+".tmp"): _end(); return
	app.save_slots.save_page(); before = _snapshot("Empty primary with real temporary-file collision")
	await _choose("写下手记三")
	_check(_writes() == before.writer_calls+1 and probe.save_attempts[-1].path == store.path_for(3) and probe.save_attempts[-1].error != OK,"Empty-slot save reaches production writer and fails on genuine primary temp collision")
	_check(_saves() == before.saves,"Empty-slot primary-open failure retains absent primary, existing backup and every other branch")
	_feedback("未能保存"); _remove_collision(store.path_for(3)+".tmp")
	# Revalidate at action time, including on title where the world HUD is hidden.
	app._show_title(); app.save_slots.detail(1); await _choose("读取当前版本")
	_write_owned(store.path_for(1),"{changed after selection".to_utf8_buffer())
	before = _snapshot("Title confirmation source became corrupt")
	await _choose("确认读取")
	_unchanged(before,"Failed title load preserves current memory and all bytes",true,false)
	_check(probe.load_attempts.size() == before.reader_calls+1 and probe.load_attempts[-1].error != OK,"Title failed confirmation calls genuine reader once")
	_feedback("未改变")
	_check(app.current_screen == "title" and app.active_modal,"Title load failure remains in current dismissible modal")
	_snapshot("Visible title load failure")
	_fixture(1,711); app._new_game()
	app.save_slots.detail(3); await _choose("读取备份")
	_remove_owned_file(store.path_for(3)+".bak")
	before = _snapshot("Exploration confirmation backup removed after selection")
	await _choose("确认读取")
	_unchanged(before,"Removed selected backup retains complete branch and every remaining byte",true,false)
	_check(probe.load_attempts.size() == before.reader_calls+1 and probe.load_attempts[-1].error != OK,"Removed selected backup reaches genuine reader once")
	_feedback("未改变")
	_check(app.current_screen == "explore" and app.active_modal,"Exploration read failure stays in a dismissible folio")
	_fixture(3,613,true)
	_end()

func _loaded_branch_autosave_failure() -> void:
	_begin("successful_load_genuine_autosave_failure_and_f5_recovery")
	_fixture(1,811); app.state.coins = 988; app._save()
	var target = model.new(); _check(target.load_game(store.path_for(1)) == OK,"Expected loaded model comes from production reader")
	if not _collision(SAVE_PATH+".tmp"): _end(); return
	app.save_slots.detail(1); await _choose("读取当前版本")
	var before = _snapshot("Valid manual load before genuine autosave failure"); var manual = _saves(true)
	var accepted: Callable = app.modal_actions[0]
	await _choose("确认读取")
	_check(app.current_screen == "explore" and not app.active_modal and app.state.to_dict() == target.to_dict(),"Successful load retains complete loaded branch despite subsequent autosave failure")
	_check(_writes(SAVE_PATH) == before.auto_calls+1 and probe.save_attempts[-1].error != OK,"Load performs exactly one genuine failed autosave")
	_check(probe.load_attempts.size() == before.reader_calls+1 and probe.load_attempts[-1].path == store.path_for(1),"Accepted current-version confirmation reads selected manual primary exactly once")
	_check(_saves() == before.saves and _saves(true) == manual,"Load-time failure preserves prior auto and all manual/backup bytes")
	_check(app.save_warning and app.status_label.text.contains("已续写") and app.status_label.text.contains("自动存档失败"),"Loaded-success status includes unresolved autosave failure")
	var loaded = _snapshot("Loaded branch before replayed confirmation"); accepted.call()
	_unchanged(loaded,"Repeated accepted load callback cannot load/save again")
	app._process(8.0)
	_check(app.save_warning and app.status_label.text.contains("自动存档失败"),"Autosave failure survives expiration of routine success toast")
	_snapshot("Loaded branch and persistent genuine failure")
	app.save_slots.save_page(); var manual_writes = _writes(); var auto_writes = _writes(SAVE_PATH)
	await _choose("写下手记三")
	_check(_writes() == manual_writes+1 and _writes(SAVE_PATH) == auto_writes,"Explicit empty manual save remains a separate one-write action")
	_check(app.save_warning,"Successful manual save does not clear unresolved autosave-warning latch")
	_feedback("已写下"); manual = _saves(true)
	app._close_modal()
	_check(app.save_warning and _writes(SAVE_PATH) == auto_writes+1,"Normal close still makes its own genuine failed autosave attempt")
	_remove_collision(SAVE_PATH+".tmp"); var count = _writes(SAVE_PATH)
	await _key(KEY_F5)
	_check(_writes(SAVE_PATH) == count+1 and not app.save_warning,"Actual F5 retries writer once and clears warning only on success")
	var actual = model.new(); _check(actual.load_game(SAVE_PATH) == OK and actual.to_dict() == app.state.to_dict(),"Recovered autosave contains complete loaded branch")
	_check(_saves(true) == manual,"F5 recovery never rewrites manual primary or backup")
	_snapshot("Actual F5 recovered branch")
	var saved: Dictionary = app.state.to_dict().duplicate(true)
	app.state.coins -= 1; var reads = probe.load_attempts.size(); count = _writes(SAVE_PATH)
	await _key(KEY_F9)
	_check(probe.load_attempts.size() == reads+1 and _writes(SAVE_PATH) == count+1 and not app.active_modal and app.state.to_dict() == saved,"Actual F9 remains quick autosave load with one common-transition autosave")
	_check(_saves(true) == manual,"F9 leaves every manual branch unchanged")
	_end()

func _close_counts_and_transfer_provenance() -> void:
	_begin("exploration_close_counts_and_transfer_provenance")
	for entry: String in ["save","load"]:
		if entry == "save": app._show_save_slots()
		else: app._show_load_slots()
		var count = _writes(SAVE_PATH); await _key(KEY_ESCAPE)
		_check(_writes(SAVE_PATH) == count+1 and not app.active_modal,"Normal exploration "+entry+" close autosaves exactly once")
	# Preserve the already-existing passive provenance contract without enabling
	# transfer, injecting a transport, or claiming a real transfer-origin journey.
	app.save_slots.transfer_browse = true; app.save_slots.load_page()
	var before = _snapshot("Existing passive transfer-browse provenance")
	await _choose("手记一"); await _choose("返回列表"); await _choose("返回")
	_unchanged(before,"Passive transfer-browse close suppresses autosave")
	_check(not app.web_save_transfer_enabled,"Transfer remains disabled after provenance test")
	app._show_save_slots(); var count = _writes(SAVE_PATH); await _key(KEY_ESCAPE)
	_check(_writes(SAVE_PATH) == count+1,"Ordinary fresh entry resets passive provenance and preserves normal close save")
	_end()

func _window_close_failure() -> void:
	_begin("desktop_window_close_genuine_failure_cancel_and_retry")
	app.state.coins += 19; app._save(); app.state.coins += 23
	if not _collision(SAVE_PATH+".tmp"): _end(); return
	var before = _snapshot("Desktop window close with unsaved branch")
	app._notification(app.NOTIFICATION_WM_CLOSE_REQUEST); await _frames()
	_check(_writes(SAVE_PATH) == before.auto_calls+1 and probe.save_attempts[-1].error != OK,"Desktop close actually attempts one production save")
	_check(not app.quit_pending and app.current_screen == "explore" and app.active_modal,"Genuine failed close keeps process and branch open")
	_check(_saves() == before.saves and app.state.to_dict() == before.state.canonical,"Failed close preserves all save bytes and unsaved canonical branch")
	_check(_text().contains("手记未能落笔") and _text().contains("游戏尚未退出"),"Window-close failure remains visibly actionable")
	var stale: Callable = app.modal_actions[0]
	app._notification(app.NOTIFICATION_WM_CLOSE_REQUEST); var count = _writes(); stale.call()
	_check(_writes() == count and not app.quit_pending,"Repeated window request invalidates previous retry token")
	await _choose("返回小憩"); await _choose("继续行走")
	_check(not app.quit_pending,"Cancel failed exit returns to exploration")
	_remove_collision(SAVE_PATH+".tmp"); count = _writes(SAVE_PATH); await _key(KEY_F5)
	_check(_writes(SAVE_PATH) == count+1 and not app.save_warning,"F5 recovers actual failed-close branch")
	_end()

func _genuine_fitting_origin() -> void:
	_begin("exact_state_fitting_exit_readonly_browse")
	# Identity-gated fitting intentionally rejects subclasses. Transfer the full
	# validated branch via real disk, then use exact production State from here.
	_check(app.state.save_game("user://save-folio-real-state.json") == OK,"Persist complete fixture for exact-State transition")
	var real = model.new()
	_check(real.load_game("user://save-folio-real-state.json") == OK,"Production State loads complete transition fixture")
	app.state = real; app._apply_loaded_state(); await _frames()
	_check(app.state.get_script() == model,"Identity-gated tests own exact production HeroState")
	var stored = model.new(); _check(stored.load_game(SAVE_PATH) == OK,"Read baseline autosave with production validator")
	app.state.coins += 37
	_check(app.state.to_dict() != stored.to_dict(),"Fitting fixture has unsaved canonical changes detectable by an unintended autosave")
	app._open_fitting("workshop"); await _frames()
	_check(app.overlay.has_meta("weapon_fitting"),"Real fitting page opened through production entry")
	if not _collision(SAVE_PATH+".tmp"): _end(); return
	app._notification(app.NOTIFICATION_WM_CLOSE_REQUEST); await _frames()
	_check(not app.quit_pending and app.overlay.get_meta("fitting_exit_readonly",false) and _text().contains("手记未能落笔"),"Genuine fitting window-close failure carries existing read-only exit provenance")
	_remove_collision(SAVE_PATH+".tmp")
	var before = _snapshot("After genuine fitting exit save failure")
	await _choose("返回小憩"); await _choose("存一卷手记")
	_check(not app.modal_autosave_on_close,"Fitting-origin save browse explicitly suppresses modal-close save")
	await _key(KEY_ESCAPE)
	_unchanged(before,"Actual fitting failure to pause to save browse to Escape",false)
	# Re-enter a genuine fitting page and repeat through load detail/back.
	app.state.coins += 1
	app._open_fitting("workshop")
	if not _collision(SAVE_PATH+".tmp"): _end(); return
	app._notification(app.NOTIFICATION_WM_CLOSE_REQUEST); await _frames()
	_remove_collision(SAVE_PATH+".tmp")
	before = _snapshot("Second fitting failure before read-only load browse")
	await _choose("返回小憩"); await _choose("查阅手记"); await _choose("手记一")
	_check(not app.modal_autosave_on_close,"Fitting-origin detail preserves close suppression")
	await _choose("返回列表"); await _choose("返回")
	_unchanged(before,"Actual fitting failure to pause to load detail and back",false)
	await _key(KEY_F5)
	_check(not app.save_warning,"Exact production State recovers after fitting-origin failure")
	_end()

func _battle_and_quit_gates() -> void:
	_begin("quit_pending_and_actual_battle_gates")
	app.state.coins += 1
	app.save_slots.save_page()
	var back_button = _button("返回江湖")
	if not _check(back_button != null,"Current save folio offers Back for quit-pending native-key boundary"): _end(); return
	back_button.grab_focus(); await _frames()
	_check(root.gui_get_focus_owner() == back_button,"Real save-list Back owns native focus before quit-pending")
	app.quit_pending = true
	var focused_before = _snapshot("Quit-pending focused Back with unsaved canonical changes")
	await _key(KEY_ENTER); await _key(KEY_SPACE)
	_unchanged(focused_before,"Quit-pending native Back cannot close or autosave",false)
	_check(app.active_modal and app.modal_generation == focused_before.generation,"Quit-pending focused Back preserves current folio")
	app.quit_pending = false; _release_focus()
	app.save_slots.save_page(); var save_callback: Callable = app.modal_actions[0]
	app.save_slots.request_load(1,false); var load_callback: Callable = app.modal_actions[0]
	app.quit_pending = true; var before = _snapshot("Quit-pending boundary")
	for code: int in [KEY_F5,KEY_F6,KEY_F9,KEY_F10]: await _key(code)
	app.save_slots.save_page(); app.save_slots.load_page(); save_callback.call(); load_callback.call()
	app.save_slots.perform_save(1); app.save_slots.perform_load(1,false)
	_unchanged(before,"Quit-pending rejects UI and direct save/load actions",false)
	_check(app.modal_generation == before.generation,"Quit-pending retains current modal identity")
	app.quit_pending = false; app.modal_autosave_on_close = false; app._close_modal()
	var controller = battle_driver.open_training(app)
	_check(app.current_screen == "party_battle" and app.state.battle_active,"Actual production battle controller owns input")
	before = _snapshot("Actual battle before blocked save/load routes")
	for code: int in [KEY_F5,KEY_F6,KEY_F9,KEY_F10]: await _key(code)
	app.save_slots.save_page(); app.save_slots.load_page()
	for slot: int in range(1,4):
		app.save_slots.request_save(slot); app.save_slots.perform_save(slot)
		app.save_slots.request_load(slot,false); app.save_slots.perform_load(slot,true)
	save_callback.call(); load_callback.call()
	_unchanged(before,"Actual battle rejects keys and direct/stale callbacks",false)
	_check(app.modal_generation == before.generation and app.overlay.get_meta("party_battle",null) == controller and controller.pending.is_empty(),"Battle controller and pending presentation remain intact")
	battle_driver.leave(app)
	_check(app.current_screen == "explore" and not app.state.battle_active,"Actual battle retreat completes through production controller")
	_check(not app.web_save_transfer_enabled,"Transfer stayed disabled for entire suite")
	_end()

func _finish() -> void:
	if finished: return
	finished = true
	for path: String in collisions.duplicate(): _remove_collision(path)
	if is_instance_valid(app): app._stop_audio(); app.free()
	if guard_passed:
		if not _no_links(report_path) or FileAccess.file_exists(report_path) or DirAccess.dir_exists_absolute(report_path):
			push_error("ERROR: save folio report path unsafe before write"); quit(2); return
		var report = {"suite":"save_folio_behavior","status":"pass" if failures.is_empty() else "fail","checks":checks,"failures":failures,"sections":sections,"checkpoints":checkpoints,"inputs":inputs,"writer_attempts":probe.save_attempts if probe != null else [],"reader_attempts":probe.load_attempts if probe != null else [],"user_dir":owned_user,"helper_sha256":FileAccess.get_sha256(probe_path),"driver_sha256":FileAccess.get_sha256(get_script().resource_path),"limits":["Prepared legal fixtures are not progression earned in this run","Queued input and headless geometry do not certify native pixels","The State observation subclass unconditionally delegates real writer/reader; exact production State is used for fitting/battle","Reader attempt counts cover the active State only; metadata preview models perform separate production reads","Fitting and battle evidence includes complete state/bytes but the retained probe does not count exact-State writer calls","Transfer provenance fixture tests existing close suppression without enabling transport or claiming transfer end-to-end","Desktop failure/cancellation use real Main; successful desktop termination remains covered by retained window-close tests","Source and actual PCK require separately bound executions; twelve native PNGs require independent pixel review"]}
		var file = FileAccess.open(report_path,FileAccess.WRITE)
		if file == null: push_error("ERROR: save folio report cannot open"); quit(2); return
		file.store_string(JSON.stringify(report,"\t")); file.flush(); var error = file.get_error(); file.close()
		if error != OK: push_error("ERROR: save folio report write failed"); quit(2); return
	if failures.is_empty(): print("PASS: NEW save folio behavior, %d checks" % checks)
	else: push_error("ERROR: save folio failed, %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
