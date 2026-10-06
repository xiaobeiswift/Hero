extends "res://tests/companion_folio_behavior_test.gd"
## External direct-logical diagnostic; inherits only the existing fresh-profile
## guard, real boot, fixture preparation, state snapshot and input helpers.
## Character rectangles are native advance/line envelopes, NOT pixel ink bounds.
const HELPER_PATH = "res://tests/companion_folio_behavior_test.gd"
const SIZES = [Vector2i(1280, 800), Vector2i(1179, 737)]
const BOUND_INPUTS = {
	"res://scripts/save_folio.gd":"5a1632b49f08fa033619292b596e903c240e629d09b6c0cb3795b713363c0246",
	"res://scripts/folio_theme.gd":"88b72c00d5de1df84d26c0ac61b017f374615835f4ddbcf8e9e371159abc8ea9",
	HELPER_PATH:"fd30f21f8f3fe0f1f30a29f928051aa488332986e0eee1b7a8608c92a196382b",
}
var samples: Array[Dictionary] = []

func _run() -> void:
	if not _guard():
		push_error("ERROR: SaveFolio geometry guard rejected before game load")
		quit(2); return
	guard_passed = true
	for path: String in BOUND_INPUTS:
		if not _check(FileAccess.get_sha256(path) == BOUND_INPUTS[path], "Reviewed source/helper binding: " + path): _finish(); return
	create_timer(150.0).timeout.connect(func():
		if not finished:
			_check(false, "Geometry watchdog expired")
			_finish())
	if not await _boot(): _finish(); return
	if not _check(app.state.get_script() == model and app.save_slots.store.get_script().resource_path == "res://scripts/local_save_slots.gd", "Exact production HeroState/store"): _finish(); return
	if not await _prepare(_new_state(), "Prepared geometry fixture, no progression claim"): _finish(); return
	if not _seed(): _finish(); return
	var before = _snapshot("Before geometry and UI opens")
	var files_before = _save_bytes()
	for dimensions: Vector2i in SIZES:
		root.content_scale_size = dimensions; root.size = dimensions; await _frames(5)
		_check(root.get_visible_rect().size == Vector2(dimensions) and root.get_final_transform().is_equal_approx(Transform2D.IDENTITY), "Exact unscaled logical viewport " + str(dimensions))
		# Put the suspected tight consequence viewport first for early evidence.
		app.save_slots.request_save(1); await _sample("overwrite-confirm", "confirm_save", dimensions)
		app.save_slots.save_page(); await _sample("save-list", "save", dimensions)
		app.save_slots.load_page(); await _sample("load-list", "load", dimensions)
		app.save_slots.detail(1); await _sample("current-and-backup-detail", "detail", dimensions)
		app.save_slots.detail(0); await _sample("autosave-detail", "detail", dimensions)
		app.save_slots.request_load(1, false); await _sample("current-load-confirm", "confirm_load", dimensions)
		app.save_slots.request_load(1, true); await _sample("backup-load-confirm", "confirm_load", dimensions)
		# Real read failure against an intentionally absent owned backup, no write.
		app.save_slots.request_load(3, true); app.save_slots.perform_load(3, true)
		await _sample("missing-backup-error", "confirm_load", dimensions)
		_check(_page().feedback.text.contains("当前旅程未改变") and _page().feedback_band.is_visible_in_tree(), "Actual failed reader exposes complete consequence")
		_check(_save_bytes() == files_before, "All primary/backup/temp bytes unchanged at " + str(dimensions))
	app._show_title()
	for dimensions: Vector2i in SIZES:
		root.content_scale_size = dimensions; root.size = dimensions; await _frames(5)
		_check(root.get_visible_rect().size == Vector2(dimensions) and root.get_final_transform().is_equal_approx(Transform2D.IDENTITY), "Title also uses unscaled logical viewport")
		app.save_slots.load_page(); await _sample("title-load-list", "load", dimensions)
	_expect(before, {}, "Every UI open, resize, Tab, pointer hover and failed read")
	_check(_save_bytes() == files_before, "Every original auto/manual/backup byte preserved")
	_check(samples.size() == 18, "All eighteen requested page-size samples retained")
	_finish()

func _seed() -> bool:
	for coins: int in [123, 234]:
		var value = _new_state(); value.coins = coins
		var canonical: Dictionary = value.to_dict().duplicate(true)
		var inspected: Dictionary = model.new().inspect_save_bytes(JSON.stringify({"version":model.SAVE_VERSION,"player":canonical}).to_utf8_buffer())
		if not _check(inspected.ok and inspected.state.to_dict() == canonical, "Complete prepared fixture validator round-trip"): return false
		var path: String = app.save_slots.store.path_for(1)
		if not _check(ProjectSettings.globalize_path(path).get_base_dir() == owned_user and _no_links(ProjectSettings.globalize_path(path)), "Exact owned fixture target"): return false
		if not _check(app.save_slots.store.save_slot(inspected.state, 1) == OK, "Real store seeds distinct primary and backup"): return false
	return _check(app.save_slots.store.describe_backup(1).status == "valid" and app.save_slots.store.describe_backup(3).status == "empty", "Valid backup and absent failure target")

func _save_bytes() -> Dictionary:
	var result: Dictionary = {}
	for slot: int in range(4):
		for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
			var path: String = app.save_slots.store.path_for(slot) + suffix
			_check(_no_links(ProjectSettings.globalize_path(path)), "Save boundary remains nonsymlink")
			result[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return result

func _page(): return app.overlay.get_node_or_null("SaveFolioPage")

func _sample(case_id: String, kind: String, dimensions: Vector2i) -> void:
	_section(case_id + "-" + str(dimensions.x) + "x" + str(dimensions.y))
	await _frames(5)
	var page = _page()
	if not _check(page != null and page.data.kind == kind and app.active_modal, "Expected real folio mounted"): return
	_check(page.size == Vector2(dimensions), "Page receives direct logical dimensions")
	var canvas = Rect2(Vector2.ZERO, Vector2(dimensions))
	_check(canvas.encloses(page.frame.get_global_rect()), "Actual folio frame contained in canvas")
	var record: Dictionary = {"case":current_section, "logical_size":[dimensions.x, dimensions.y], "frame":_rect(page.frame.get_global_rect()), "labels":[], "rich_text":[], "buttons":[]}
	var footer: Label = page.frame.get_node("SaveKeyboardHelp")
	var footer_envelope: Rect2 = _label_envelope(footer)
	var footer_backing: Rect2 = page.frame.get_node("SaveKeyboardBacking").get_global_rect()
	for label: Label in page.find_children("*", "Label", true, false):
		if not label.is_visible_in_tree() or label.text.is_empty(): continue
		_check(label.get_visible_line_count() == label.get_line_count() and label.lines_skipped == 0 and label.visible_characters == -1 and label.visible_ratio == 1.0, "Every native Label line/character enabled: " + label.name)
		var bounds: Rect2 = _label_envelope(label)
		record.labels.append({"path":str(label.get_path()), "text":label.text, "raw_control_rect":_rect(label.get_global_rect()), "native_advance_line_envelope":_rect(bounds), "line_count":label.get_line_count(), "visible_line_count":label.get_visible_line_count(), "line_height":label.get_line_height(), "inside_canvas":canvas.encloses(bounds), "clearance_before_footer":footer_envelope.position.y - bounds.end.y})
	# These envelope diagnostics are not silently promoted to actual ink proof.
	record.footer = {"backing":_rect(footer_backing), "native_advance_line_envelope":_rect(footer_envelope), "metric_envelope_inside_backing":footer_backing.encloses(footer_envelope), "metric_bottom_clearance":footer_backing.end.y - footer_envelope.end.y, "metric_top_clearance":footer_envelope.position.y - footer_backing.position.y}
	for rich: RichTextLabel in page.find_children("*", "RichTextLabel", true, false):
		if not rich.is_visible_in_tree(): continue
		var normal: StyleBox = rich.get_theme_stylebox("normal")
		var inner_height: float = rich.size.y - normal.get_minimum_size().y
		var bar: VScrollBar = rich.get_v_scroll_bar()
		var inner_width: float = rich.size.x - normal.get_minimum_size().x - (bar.size.x if bar.is_visible_in_tree() else 0.0)
		var content_height: int = rich.get_content_height()
		var content_width: int = rich.get_content_width()
		var metric: Dictionary = {"path":str(rich.get_path()), "text":rich.get_parsed_text(), "viewport":_rect(rich.get_global_rect()), "inner_height":inner_height, "inner_width":inner_width, "content_height":content_height, "content_width":content_width, "height_clearance":inner_height - content_height, "scroll_value":bar.value, "scroll_max":bar.max_value, "scroll_page":bar.page, "scroll_visible":bar.is_visible_in_tree()}
		record.rich_text.append(metric)
		print("SAVE_FOLIO_GEOMETRY " + current_section + " " + rich.name + " " + JSON.stringify(metric))
		_check(rich.is_finished() and rich.visible_ratio == 1.0 and rich.visible_characters == -1, "Complete RichText layout finished: " + rich.name)
		_check(content_height <= inner_height + 0.15 and content_width <= inner_width + 0.15, "Entire RichText content fits immediately: " + rich.name)
		_check(is_zero_approx(bar.value) and bar.max_value - bar.page <= 0.15, "Mandatory RichText needs no hidden scroll continuation: " + rich.name)
		_check(canvas.encloses(rich.get_global_rect()) and rich.get_global_rect().end.y < footer_envelope.position.y, "RichText viewport clears canvas/footer")
		if rich == page.detail_note: _check(not rich.text.is_empty() and rich.get_parsed_text() == String(page.data.get("consequences", page.body)), "Full mandatory consequences preserved exactly")
	_check(page.numbers.size() == page.buttons.size() and page.find_children("SaveChoiceNumber*", "Label", true, false).size() == page.buttons.size(), "Exactly one native shortcut number per action")
	var old_focus = root.gui_get_focus_owner()
	if old_focus != null: old_focus.release_focus()
	for index: int in page.buttons.size():
		var button: Button = page.buttons[index]
		var hit: Rect2 = button.get_global_rect()
		var number: Label = page.numbers[index]
		var number_envelope: Rect2 = _label_envelope(number)
		_check(button.is_visible_in_tree() and not button.disabled and button.focus_mode == Control.FOCUS_ALL and hit.size.x >= 44 and hit.size.y >= 44 and canvas.encloses(hit), "Visible usable native hit target inside canvas")
		_check(number.text == str(index + 1) and hit.encloses(number_envelope), "Native shortcut advance/line envelope inside own hit target")
		for other: Button in page.buttons:
			if other != button: _check(not hit.intersects(other.get_global_rect()), "Actual button targets do not overlap")
		for rich: RichTextLabel in page.find_children("*", "RichTextLabel", true, false):
			if rich.is_visible_in_tree(): _check(not hit.intersects(rich.get_global_rect()), "Actual button does not obstruct mandatory RichText viewport")
		await _key(KEY_TAB)
		_check(root.gui_get_focus_owner() == button, "Native Tab reaches expected action")
		var focus_style: StyleBox = button.get_theme_stylebox("focus")
		if not _check(focus_style is StyleBoxFlat, "Focus bounds require documented StyleBoxFlat margins"): return
		var flat: StyleBoxFlat = focus_style as StyleBoxFlat
		if not _check(flat.shadow_size == 0 and flat.skew == Vector2.ZERO and flat.corner_radius_top_left == 0 and flat.corner_radius_top_right == 0 and flat.corner_radius_bottom_left == 0 and flat.corner_radius_bottom_right == 0, "Declared focus bounds assume no shadow, skew or rounded corners"): return
		# Declared rectangular extent from bound style margins, not sampled pixels.
		var focus_local: Rect2 = Rect2(Vector2.ZERO, button.size).grow_individual(flat.expand_margin_left, flat.expand_margin_top, flat.expand_margin_right, flat.expand_margin_bottom)
		var focus: Rect2 = button.get_global_transform() * focus_local
		_check(canvas.encloses(focus), "Declared StyleBoxFlat focus bounds inside canvas")
		for point: Vector2 in [hit.get_center(), number_envelope.get_center(), hit.position + Vector2(2, 2), hit.end - Vector2(2, 2)]:
			var motion = InputEventMouseMotion.new(); motion.position = point; motion.global_position = point
			Input.parse_input_event(motion); Input.flush_buffered_events(); await _frames(1)
			_check(root.gui_get_hovered_control() == button, "Native hover hit routing works over caption, number, and corners")
		record.buttons.append({"text":button.text, "hit":_rect(hit), "declared_focus_bounds":_rect(focus), "number_advance_line_envelope":_rect(number_envelope), "caption_font_size":button.get_theme_font_size("font_size"), "caption_font_measure":str(button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")))})
	await _key(KEY_TAB)
	_check(root.gui_get_focus_owner() == page.buttons[0], "Native Tab ring wraps")
	samples.append(record)

func _label_envelope(label: Label) -> Rect2:
	var envelope = Rect2()
	for index: int in label.text.length():
		var cell: Rect2 = label.get_character_bounds(index)
		if cell.has_area(): envelope = cell if not envelope.has_area() else envelope.merge(cell)
	return label.get_global_transform() * envelope

func _rect(value: Rect2) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]

func _finish() -> void:
	if finished: return
	finished = true
	if is_instance_valid(app): app._stop_audio(); app.free()
	if guard_passed:
		if not _no_links(report_path) or FileAccess.file_exists(report_path) or DirAccess.dir_exists_absolute(report_path): push_error("ERROR: unsafe geometry report target"); quit(2); return
		var report: Dictionary = {"suite":"save_folio_direct_logical_geometry", "status":"pass" if failures.is_empty() else "fail", "checks":checks, "failures":failures, "samples":samples, "inputs":inputs, "checkpoints":checkpoints, "driver_sha256":FileAccess.get_sha256(get_script().resource_path), "bound_inputs":BOUND_INPUTS, "limits":["Label character rectangles are native advance/line layout envelopes, not actual pixel ink or guaranteed glyph-overhang bounds", "Raw Label control rectangles are recorded only; oversized minimum-size rectangles never prove containment", "Caption/number/ornament pixel separation remains under independent final native PNG review; this diagnostic does not certify it", "RichText full content height/width, viewport and scroll metrics are actual native measurements", "Direct logical 1280x800 and 1179x737 only; no direct960 or minimum-supported-size claim", "Prepared legal saves are not earned progression; failure uses an absent owned backup and real reader", "This focused gate supplements and does not replace unchanged 449-check SaveFolio behavior suite"]}
		var file = FileAccess.open(report_path, FileAccess.WRITE)
		if file == null: push_error("ERROR: cannot write geometry report"); quit(2); return
		file.store_string(JSON.stringify(report, "\t")); file.flush(); var error = file.get_error(); file.close()
		if error != OK: push_error("ERROR: geometry report write failed"); quit(2); return
	if failures.is_empty(): print("PASS: SaveFolio direct logical geometry, %d checks" % checks)
	else: push_error("ERROR: SaveFolio geometry failed, %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
