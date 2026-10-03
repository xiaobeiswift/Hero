extends SceneTree
## External first image only. No Main/State preload before the isolation gate.
const FIXTURE = "bounded_qin_tang_fix_1_1"
var app
var out: String
var io_failed: bool = false
var evidence: Dictionary = {"status":"started", "fixture":FIXTURE, "prepared_fixture":true,
	"scripted_native_input":true, "manual_input":false, "contrast_complete":false,
	"full_regression":false, "pck_test":false, "browser_test":false, "inputs":[]}
func _initialize() -> void: run.call_deferred()
func frames(n: int = 3) -> void:
	for i: int in n: await process_frame
func norm(path: String) -> String: return path.replace("\\", "/").simplify_path().trim_suffix("/").to_lower()
func need(ok: bool, label: String) -> bool:
	if not ok:
		evidence.status = "failed"; evidence.failure = label; push_error(label)
		if not out.is_empty(): write_report()
		quit(2)
	return ok
func write_report() -> void:
	var file = FileAccess.open(out + "/capture.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(evidence, "\t")); file.close()
func listing(path: String) -> Variant:
	var directory = DirAccess.open(path)
	if directory == null:
		io_failed = true; need(false, "Cannot open required inventory directory: " + path); return null
	directory.include_hidden = true
	if directory.list_dir_begin() != OK:
		io_failed = true; need(false, "Cannot enumerate required inventory directory: " + path); return null
	var result: Array = []; var name: String = directory.get_next()
	while not name.is_empty():
		if name not in [".", ".."]:
			if directory.is_link(name):
				directory.list_dir_end(); io_failed = true; need(false, "Linked inventory entry: " + path.path_join(name)); return null
			result.append([name, directory.current_is_dir()])
		name = directory.get_next()
	directory.list_dir_end(); return result
func disk(path: String = "user://") -> Dictionary:
	var result: Dictionary = {}
	if path == "user://shader_cache":
		var parent_entries: Variant = listing("user://")
		if parent_entries == null: return {"__probe_io_failure__":path}
		var present: bool = false
		for entry: Array in parent_entries:
			if entry[0] == "shader_cache": present = true
		if not present: return {} # Explicitly observed absence, not an open failure.
	var entries: Variant = listing(path)
	if entries == null: return {"__probe_io_failure__":path}
	for entry: Array in entries:
		var child: String = path.path_join(entry[0])
		if entry[1]:
			if path == "user://" and entry[0] == "shader_cache": continue
			result.merge(disk(child))
		else:
			var digest: String = FileAccess.get_sha256(child)
			if digest.length() != 64 or not digest.is_valid_hex_number(false):
				io_failed = true; need(false, "Cannot hash required inventory file: " + child); return {"__probe_io_failure__":child}
			result[child] = digest
	return result

func folio(): return app.overlay.get_meta("journal_ui", null)
func guidance_agrees() -> bool:
	var snap: Dictionary = app.journal_guidance_snapshot
	return app.journal_session.tracked_arc_id.is_empty() and snap.get("mode") == "auto" and snap.get("arc_id") == "qin_rope" and snap.get("next_target_id") == "mist_rain_gauge" and app.world._quest_target_id() == "mist_rain_gauge" and app.world.journal_guidance_snapshot == snap and app.hud.journal_guidance_snapshot == snap and folio().guidance_snapshot == snap
func tap(code: int) -> void:
	evidence.inputs.append({"kind":"queued_key", "key":OS.get_keycode_string(code)})
	for down: bool in [true, false]:
		var event = InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.pressed = down
		Input.parse_input_event(event); Input.flush_buffered_events(); await frames(2)
func click(control: Control) -> void:
	var point: Vector2 = root.get_final_transform() * control.get_global_rect().get_center()
	evidence.inputs.append({"kind":"queued_pointer", "node":str(control.get_path()), "pixel_point":[point.x,point.y]})
	var motion = InputEventMouseMotion.new(); motion.position = point; motion.global_position = point
	Input.parse_input_event(motion); Input.flush_buffered_events(); await frames(1)
	for down: bool in [true, false]:
		var event = InputEventMouseButton.new(); event.position = point; event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT; event.pressed = down
		Input.parse_input_event(event); Input.flush_buffered_events(); await frames(2)
func fonts(node: Node) -> Array:
	var found: Array = []
	if node is Label or node is Button or node is RichTextLabel:
		var key: String = "normal_font" if node is RichTextLabel else "font"
		var actual: Font = node.get_theme_font(key)
		var item: Dictionary = {"node":str(node.get_path()), "resource_path":actual.resource_path, "font_name":actual.get_font_name()}
		if node is RichTextLabel:
			item.bbcode_enabled = node.bbcode_enabled; item.raw_bbcode = node.text
			item.default_color = node.get_theme_color("default_color").to_html()
			item.note = "Raw BBCode contains color/size spans; default_color is NOT a contrast inventory"
		found.append(item)
	for child: Node in node.get_children(): found.append_array(fonts(child))
	return found
func run() -> void:
	var owned: String = OS.get_environment("HERO_FOLIO_OWNED")
	if not need(not owned.is_empty() and owned.is_absolute_path(), "Missing owned absolute path"): return
	var marker: Variant = JSON.parse_string(FileAccess.get_file_as_string(owned + "/owner.json"))
	if not need(marker is Dictionary and marker.get("nonce", "") == OS.get_environment("HERO_FOLIO_NONCE") and not OS.get_environment("HERO_FOLIO_NONCE").is_empty(), "Missing owned-profile token"): return
	if not need(OS.get_name() == "Windows" and DisplayServer.get_name() != "headless", "Native Windows display required; headless is not visual evidence"): return
	var profile_root: String = marker.get("capture_profile_root", "")
	if not need(not profile_root.is_empty() and profile_root.is_absolute_path() and FileAccess.get_file_as_string(profile_root + "/.hero-first-capture-started") == marker.nonce, "Missing owned profile claim"): return
	for key: String in marker.capture_environment:
		if not need(norm(OS.get_environment(key)) == norm(marker.capture_environment[key]) and (norm(marker.capture_environment[key]) == norm(profile_root) or norm(marker.capture_environment[key]).begins_with(norm(profile_root) + "/")), "Unowned environment: " + key): return
	var user_dir: String = OS.get_user_data_dir()
	if not need(not ProjectSettings.get_setting("application/config/use_custom_user_dir", false) and norm(user_dir) == norm(marker.capture_userdata) and norm(user_dir).begins_with(norm(profile_root) + "/") and norm(user_dir) == norm(OS.get_environment("APPDATA") + "/Godot/app_userdata/" + String(ProjectSettings.get_setting("application/config/name"))), "Unexpected user:// location"): return
	if not need(marker.capture_fresh_verified_before_launch == true and marker.prelaunch_application_files == {} and not FileAccess.file_exists(owned + "/capture-started") and disk().is_empty(), "Existing user data or reused capture profile"): return
	var directory = DirAccess.open("user://")
	if directory != null:
		for name: String in directory.get_directories():
			if not need(name == "shader_cache" and not directory.is_link(name), "Unexpected preexisting user subdirectory"): return
	if not need(norm(marker.output) == norm(owned + "/out") and DirAccess.dir_exists_absolute(marker.output), "Output outside owned root"): return
	out = marker.output
	var used = FileAccess.open(owned + "/capture-started", FileAccess.WRITE); used.store_string(marker.nonce); used.close()
	evidence.merge({"engine":Engine.get_version_info(), "os":OS.get_name(), "os_version":OS.get_version(), "display_server":DisplayServer.get_name(), "user_data_dir":user_dir, "environment":marker.capture_environment})
	var binding: Variant = JSON.parse_string(FileAccess.get_file_as_string(out + "/source-binding.json"))
	if not need(binding is Dictionary, "Missing post-import source binding"): return
	for relative: String in binding.effective_files:
		if not need(FileAccess.get_sha256("res://" + relative) == binding.effective_files[relative], "Source differs after import: " + relative): return
	evidence.project_cache_at_pre_main = disk("res://.godot")
	evidence.startup_engine_shader_cache = disk("user://shader_cache")
	evidence.file_invariance_scope = "All application files in user://; engine-created shader_cache separately inventoried, not required byte-invariant"
	evidence.source_binding_sha256 = FileAccess.get_sha256(out + "/source-binding.json")
	evidence.source_binding = binding
	if not need(not io_failed, "Inventory read failed before Main"): return
	var State = load("res://scripts/game_state.gd")
	if not need(State != null, "Production State failed to load"): return
	var corpus: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/journal_guidance_frozen_oracle.json"))
	var fixture: Dictionary = {}
	for row: Dictionary in corpus.rows:
		if row.label == FIXTURE: fixture = row
	if not need(not fixture.is_empty(), "Prepared oracle label missing"): return
	var prepared_bytes: PackedByteArray = JSON.stringify({"version":State.SAVE_VERSION,"player":fixture.state}).to_utf8_buffer()
	var parsed: Dictionary = State.new().inspect_save_bytes(prepared_bytes)
	if not need(parsed.ok, "Unmodified production reader rejected fixture"): return
	var scene = load("res://scenes/main.tscn")
	if not need(scene != null, "Actual Main scene failed to load"): return
	app = scene.instantiate(); root.add_child(app); await frames(); app._stop_audio(); app.audio_on = false
	if not need(app.get_script() == load("res://scripts/main.gd"), "Wrong Main script"): return
	app.current_screen = "explore"; app.active_modal = false; app._clear_overlay(); app.state = parsed.state
	app._apply_loaded_state("Prepared first-render fixture"); app._refresh(); await frames()
	if not need(app.state.get_script() == State and app.state.save_game() == OK, "Genuine prepared save failed"): return
	var before: Dictionary = app.state.to_dict().duplicate(true); var files: Dictionary = disk(); var position: Vector2 = app.world.player_pos
	evidence.before_engine_shader_cache = disk("user://shader_cache")
	if not need(not io_failed, "Prepared baseline inventory failed"): return
	evidence.before_state = before; evidence.before_files = files; evidence.prepared_input_sha256 = prepared_bytes.get_string_from_utf8().sha256_text()
	evidence.prepared_input_hash_note = "SHA256 of exact UTF8 prepared JSON; source oracle hash is in source_binding"
	await tap(KEY_J)
	if not need(is_instance_valid(folio()) and folio().row_buttons.has("tang_notes"), "J did not expose actual Tang row"): return
	if not need(guidance_agrees(), "Expected automatic Qin before browse"): return
	await click(folio().row_buttons.tang_notes)
	if not need(folio().browse_arc_id == "tang_notes" and root.gui_get_focus_owner() == folio().row_buttons.tang_notes and guidance_agrees(), "Pointer did not browse/focus Tang while preserving auto Qin"): return
	evidence.pointer_focus_path = str(root.gui_get_focus_owner().get_path())
	await tap(KEY_ENTER)
	if not need(folio().browse_arc_id == "tang_notes" and guidance_agrees(), "Tang browse changed automatic Qin"): return
	await frames(3); await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if not need(image.get_size() == Vector2i(1280,800) and root.size == Vector2i(1280,800), "Actual render/window must both be 1280x800"): return
	evidence.after_state = app.state.to_dict(); evidence.after_files = disk(); evidence.after_engine_shader_cache = disk("user://shader_cache")
	if not need(not io_failed and evidence.after_state == before and evidence.after_files == files and app.world.player_pos == position, "Browse changed canonical State, application/save bytes or position"): return
	if not need(image.save_png(out + "/first-native.png") == OK, "PNG write failed"): return
	evidence.merge({"status":"captured_pending_visual_review", "image_sha256":FileAccess.get_sha256(out + "/first-native.png"), "framebuffer":[image.get_width(),image.get_height()], "window":[root.size.x,root.size.y], "fonts_and_richtext":fonts(folio()), "guidance":app.journal_guidance_snapshot, "browse":folio().browse_arc_id, "tracked":app.journal_session.tracked_arc_id, "main_processing":app.is_processing(), "world_processing":app.world.is_processing(), "world_position":[position.x,position.y]})
	write_report(); print("FIRST_RENDER_CAPTURED_PENDING_VISUAL_REVIEW")
	app._stop_audio(); app.queue_free(); await frames(2); quit(0)
