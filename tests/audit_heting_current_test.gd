extends "res://tests/audit_second_region_test.gd"
## Independent current-UI/save-close audit for Hero / 渡灯录.
## Run only this focused test with isolated XDG_DATA_HOME and XDG_CACHE_HOME.
## All active state/manual files additionally live under one unique fixture.
## Historical-reader bytes are bundled and SHA-256 verified; no Git is required.
const Main = preload("res://scripts/main.gd")
const Model = preload("res://scripts/game_state.gd")
const Slots = preload("res://scripts/local_save_slots.gd")
const Port = preload("res://scripts/heting_region.gd")
const FROZEN_V017_PATH = "res://tests/fixtures/v017_game_state.gd.txt"
const FROZEN_V017_SHA256 = "fd5d6da903a8d24a16ecd5774642c2e5e2bc792a084807734ba6caa95f972f4f"

class RoutedState extends Model:
	var directory: String
	var writes: int = 0
	var accessed: Array[String] = []
	func save_game(path: String = SAVE_PATH) -> Error:
		if path == SAVE_PATH: path = directory.path_join("hero_save.json")
		writes += 1; accessed.append(path)
		return super.save_game(path)
	func load_game(path: String = SAVE_PATH) -> Error:
		if path == SAVE_PATH: path = directory.path_join("hero_save.json")
		accessed.append(path)
		return super.load_game(path)
	func has_save() -> bool:
		return FileAccess.file_exists(directory.path_join("hero_save.json"))

class CloseProbe extends Main:
	var exits: int = 0
	var exit_save: bool = true
	func _quit_cleanly(save_progress: bool = true) -> void:
		exits += 1; exit_save = save_progress; quit_pending = true

var fixture: String
var store
var state_probe: RoutedState
var pier_notices: int = 0

func _run() -> void:
	fixture = "user://heting-current-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_check(DirAccess.make_dir_recursive_absolute(fixture) == OK, "Create independent fixture")
	store = Slots.new(fixture)
	state_probe = RoutedState.new(); state_probe.directory = fixture
	game = CloseProbe.new(); game.state = state_probe
	root.add_child(game); game.save_slots.store = store
	await process_frame
	game.world.set_process(false)
	game._stop_audio(); game.audio_on = false
	await _migration_and_historical_reader()
	await _paper_ui_and_interruptions()
	await _loaded_storage_failures()
	await _loaded_exit_guards()
	_test_pier_notice()
	for path in state_probe.accessed:
		_check(path.begins_with(fixture + "/"), "Adapter accesses only test-owned files")
	_check(not FileAccess.file_exists(Model.SAVE_PATH), "Test did not create ordinary-player autosave")
	for slot in range(1,4):
		_check(not FileAccess.file_exists("user://hero_slot_%d.json" % slot), "Test did not create ordinary-player manual slot")
	game._stop_audio(); game.queue_free(); await process_frame
	_remove_fixture(fixture)
	_check(not DirAccess.dir_exists_absolute(fixture), "Remove test-owned save data and failure blockers")
	if failures == 0: print("PASS: %d current Heting migration/paper-input/storage/close checks" % checks)
	else: push_error("FAIL: %d of %d current Heting migration/paper-input/storage/close checks" % [failures, checks])
	quit(0 if failures == 0 else 1)

func _base() -> void:
	game.quit_pending = false
	game._new_game()
	state_probe.player_name = "九版旅人"
	state_probe.quest_stage = 6; state_probe.ending = "守望"; state_probe.choose_sect("听潮阁")
	state_probe.gain_xp(600); state_probe.coins = 137; state_probe.medicine = 7
	state_probe.side_stage = 3; state_probe.side_choice = "rescue"; state_probe.side_reward_claimed = true
	state_probe.side_found.assign(["boatman", "ledger"]); state_probe.side_clues = 2
	state_probe.chapter_two_stage = 4; state_probe.chapter_two_ending = "protect_witness"
	state_probe.archive_clues.assign(["clerk", "inscription"]); state_probe.seal_sequence.assign([2,0,1])
	state_probe.mist_stage = 4; state_probe.mist_gauges.assign(state_probe.Mist.GAUGES)
	state_probe.mist_approach = "duel"; state_probe.mist_ending = "release_water"
	state_probe.companion_unlocked = true; state_probe.active_companion = "沈青"
	state_probe.shen_care_stage = 5; state_probe.shen_care_choice = "mobile"
	state_probe._apply_party_plan(state_probe.PartyRoster.load_plan(state_probe, {"active_companion": "沈青"}, 11))
	game._travel("mistwood", Vector2(1440,505))

func _port(stage: int = 3, cargo: String = "reserve", plan: String = "short_ferries", bridge: String = "east") -> void:
	_base()
	state_probe.heting_stage = stage; state_probe.heting_bridge = bridge
	state_probe.heting_delivered.clear()
	if stage >= 2: state_probe.heting_delivered.assign(["meal", "sealed"])
	if stage == 4: state_probe.heting_delivered.append("reserve")
	state_probe.heting_cargo = cargo; state_probe.heting_draft = plan
	state_probe.heting_ending = plan if stage == 4 else ""
	game._travel("heting", Port.LOADED_SAFE)
	game._process(0)

func _migration_and_historical_reader() -> void:
	_base()
	var old_state: Dictionary = state_probe.to_dict()
	_write_document(store.path_for(1), 9, old_state)
	var original: PackedByteArray = _bytes(store.path_for(1))
	state_probe.coins = 999
	game.save_slots.detail(1); _press("读取当前版本")
	var writes: int = state_probe.writes
	_press("确认读取")
	_check(state_probe.to_dict() == old_state and _version(store.path_for(0)) == Model.SAVE_VERSION, "Current paper-slot flow upgrades legitimate v9 to current schema without altering old progress")
	_check(state_probe.writes == writes + 1 and _bytes(store.path_for(1)) == original and not FileAccess.file_exists(store.path_for(1) + ".bak"), "Migration performs one autosave and preserves manual source bytes")
	# Old WIP-format v9 port data must still restore in the new reader.
	_port(3, "reserve", "open_scale", "east")
	game.world.teleport(Vector2(1130,730)); game._process(0)
	var loaded_branch: Dictionary = state_probe.to_dict()
	_write_document(store.path_for(2), 9, loaded_branch)
	original = _bytes(store.path_for(2))
	_port(1, "meal", "", "west")
	game.save_slots.detail(2); _press("读取当前版本"); _press("确认读取")
	_check(state_probe.to_dict() == loaded_branch and game.world.player_pos == Vector2(1130,730) and game.world.heting_bridge == "east" and game.world.heting_cargo == "reserve", "V9 loaded bridge coordinate is kept because saved terrain is applied before repair")
	_check(_bytes(store.path_for(2)) == original and _version(store.path_for(0)) == Model.SAVE_VERSION, "Latent v9 port source remains intact after migration")
	# Exact frozen v0.0.17 bytes travel with source ZIPs. See the adjacent
	# provenance note. Verify the bytes being compiled before removing only the
	# global class declaration, avoiding conflict with the current HeroState.
	var frozen: PackedByteArray = FileAccess.get_file_as_bytes(FROZEN_V017_PATH)
	_check(not frozen.is_empty(), "Read bundled frozen v0.0.17 reader without Git")
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256); hashing.update(frozen)
	var digest: String = hashing.finish().hex_encode()
	_check(digest == FROZEN_V017_SHA256, "Historical reader bytes match pinned SHA-256 before compilation")
	if digest == FROZEN_V017_SHA256:
		var old_script := GDScript.new()
		old_script.source_code = frozen.get_string_from_utf8().replace("class_name HeroState\n", "")
		var parsed: Error = old_script.reload()
		_check(parsed == OK, "Historical v0.0.17 reader parses independently")
		if parsed == OK:
			var old_reader = old_script.new()
			old_reader.coins = 4242
			var before: Dictionary = old_reader.to_dict()
			original = _bytes(store.path_for(0))
			_check(old_reader.load_game(store.path_for(0)) == ERR_FILE_UNRECOGNIZED and old_reader.to_dict() == before, "Exact v0.0.17 reader rejects newer schema before replacing any state")
			_check(_bytes(store.path_for(0)) == original, "Rollback rejection leaves newer save bytes untouched")
	# Corruption after the current confirmation appeared must leave everything live.
	game.save_slots.detail(2); _press("读取当前版本")
	var invalid: Dictionary = loaded_branch.duplicate(true); invalid.erase("heting_bridge")
	_write_document(store.path_for(2), 9, invalid)
	var entire: Dictionary = _all_state()
	var world_before: Array = _world()
	var autosave: PackedByteArray = _bytes(store.path_for(0))
	writes = state_probe.writes
	_press("确认读取")
	_check(_all_state() == entire and _world() == world_before and state_probe.writes == writes and _bytes(store.path_for(0)) == autosave, "Corrupt-after-selection v9 preserves full state, world and autosave")
	game._close_modal()

func _paper_ui_and_interruptions() -> void:
	for zoom in range(3):
		for detail in [false, true]:
			_port(3, "reserve", "short_ferries", "west")
			game.view_preferences.zoom_index = zoom; game.view_preferences.full_resolution = detail
			game._apply_view_zoom()
			await _talk("heting_scale")
			await process_frame; await process_frame
			var sheet = game.overlay.find_child("DialogueSheet", true, false)
			_check(sheet != null and Rect2(0,0,1280,800).encloses(sheet.get_rect()), "Current paper confirmation stays inside viewport at every view setting")
			var body = game.overlay.find_child("DialogueBody", true, false)
			_check(body != null and body.scroll_active and body.text.contains("仍须再确认交割"), "Actual paper body retains separate-confirmation explanation")
			for index in range(game.modal_actions.size()):
				var button = game.overlay.find_child("DialogueChoice" + str(index + 1), true, false)
				_check(button != null and Rect2(Vector2.ZERO, sheet.size).encloses(button.get_rect()), "Paper choices remain inside sheet")
			game._save()
			var before: Dictionary = state_probe.to_dict()
			var writes: int = state_probe.writes
			await _key(KEY_ESCAPE)
			_check(state_probe.to_dict() == before and state_probe.writes == writes and not game.active_modal, "One real Escape dismisses port sheet without writing or opening pause")
			await _key(KEY_ESCAPE)
			await process_frame # Let main synchronize world.active after the input event.
			_check(game.overlay.get_meta("pause_menu", false) and not game.world.active, "Next Escape opens current pause menu with loaded cart safely paused")
			await _key(KEY_ESCAPE)
			_check(not game.active_modal and state_probe.heting_cargo == "reserve", "Pause dismissal keeps cargo and resumes normally")
	_port(3, "reserve", "short_ferries", "west")
	await _talk("heting_scale")
	var old_plan_action: Callable = game.modal_actions[1]
	await _key(KEY_2)
	_check(state_probe.heting_draft == "open_scale" and state_probe.heting_stage == 3 and state_probe.heting_cargo == "reserve" and _find_button(game.overlay, "照此交割") != null, "Real numeric key changes local draft and requires a new paper confirmation")
	var before: Dictionary = state_probe.to_dict()
	old_plan_action.call()
	_check(state_probe.to_dict() == before and game.overlay.find_child("DialogueTitle", true, false).text == "施衡与埠工", "Double-wrapped paper/story generation guards reject replaced-page callback")
	# Real press -> Escape -> release across a removed confirmation button.
	await process_frame; await process_frame
	var button = _find_button(game.overlay, "照此交割")
	var point: Vector2 = button.get_global_rect().get_center()
	var stale_final: Callable = game.modal_actions[0]
	await _mouse(point, true)
	await _key(KEY_ESCAPE)
	var writes: int = state_probe.writes
	before = state_probe.to_dict()
	await _mouse(point, false)
	stale_final.call()
	_check(state_probe.to_dict() == before and state_probe.writes == writes and not game.active_modal, "Escape during actual held confirmation prevents delayed release and explicit replay from delivering")
	await _talk("heting_cargo")
	_check(_find_button(game.overlay, "退车归位") == null, "Reserve cargo cannot be parked at the base-grain source")
	await _key(KEY_ESCAPE)
	await _talk("heting_lighter")
	_check(_find_button(game.overlay, "退车归位") != null, "Reserve cargo can still be parked at its actual source")
	await _key(KEY_ESCAPE)
	game._show_map()
	var chart = game.overlay.find_child("RegionChart", true, false)
	_check(chart != null and chart.heting_bridge == "west" and chart.markers.size() == 7 and chart.current_target == "heting_scale", "Current embedded paper chart has actual bridge, seven sites and revised cargo target")
	await _key(KEY_ESCAPE)

func _loaded_storage_failures() -> void:
	_port(3, "reserve", "open_scale", "east")
	await _talk("heting_scale")
	game._save()
	var old_auto: PackedByteArray = _bytes(store.path_for(0))
	_block_autosave()
	_press("照此交割")
	_check(state_probe.heting_stage == 4 and state_probe.heting_ending == "open_scale" and game.save_warning, "Successful local delivery remains in memory when actual disk autosave fails")
	_check(_bytes(store.path_for(0)) == old_auto and _modal_text().contains("第四章完成"), "Failed delivery autosave preserves earlier valid loaded-cart bytes")
	var completed: Dictionary = state_probe.to_dict()
	var writes: int = state_probe.writes
	await _key(KEY_ESCAPE)
	_check(state_probe.to_dict() == completed and state_probe.writes == writes and game.save_warning, "Dismissing unsaved result does not silently retry or erase failure warning")
	_unblock_autosave()
	await _key(KEY_F5)
	_check(not game.save_warning and _saved_state() == completed, "F5 retries completed branch without a second reward")
	_port(3, "reserve", "short_ferries", "west")
	await _talk("heting_dispatch")
	game.save_slots.perform_save(3)
	game._close_modal()
	var manual: PackedByteArray = _bytes(store.path_for(3))
	_port(3, "reserve", "open_scale", "east")
	old_auto = _bytes(store.path_for(0))
	_block_autosave()
	game.save_slots.detail(3); _press("读取当前版本"); _press("确认读取")
	_check(state_probe.heting_draft == "short_ferries" and state_probe.heting_cargo == "reserve" and game.save_warning and not game.active_modal, "Valid manual branch resumes despite load-time autosave failure")
	_check(_bytes(store.path_for(0)) == old_auto and _bytes(store.path_for(3)) == manual, "Load-time failure leaves both old autosave and loaded manual source untouched")
	_unblock_autosave(); await _key(KEY_F5)
	_check(not game.save_warning and _saved_state() == state_probe.to_dict(), "Loaded branch can be explicitly saved after storage recovery")

func _loaded_exit_guards() -> void:
	_port(3, "reserve", "open_scale", "east")
	await _talk("heting_scale")
	game._save()
	var old_auto: PackedByteArray = _bytes(store.path_for(0))
	var branch: Dictionary = state_probe.to_dict()
	_block_autosave()
	var exits: int = game.exits
	game._notification(game.NOTIFICATION_WM_CLOSE_REQUEST)
	_check(game.exits == exits and not game.quit_pending and game.active_modal and state_probe.to_dict() == branch, "OS-close while final delivery is pending cannot leave on failed save or deliver cargo")
	_check(_bytes(store.path_for(0)) == old_auto and _modal_text().contains("手记未能落笔"), "Current close guard preserves real earlier save bytes and opens retry page")
	var old_retry: Callable = game.modal_actions[0]
	game._notification(game.NOTIFICATION_WM_CLOSE_REQUEST)
	var writes: int = state_probe.writes
	old_retry.call()
	_check(state_probe.writes == writes and game.exits == exits, "Repeated window-close replaces and invalidates older retry callback")
	_press("返回小憩")
	await _key(KEY_ESCAPE)
	_check(state_probe.to_dict() == branch and not game.active_modal and game.save_warning, "Cancel failed close back to exploration keeps loaded branch")
	_unblock_autosave()
	await _key(KEY_ESCAPE); _press("返回首页"); _press("保存并离开")
	_check(game.current_screen == "title" and not game.quit_pending and _saved_state() == branch, "Current pause title exit saves cargo/plan/location rather than invoking port travel/parking")
	_press("续写前缘")
	_check(game.current_screen == "explore" and state_probe.to_dict() == branch and game.world.map_id == "heting", "Continue from title restores exact loaded port branch")
	# Retry a real file-open failure, then emulate the intercepted app exit.
	await _talk("heting_scale"); game._save()
	_block_autosave(); game._notification(game.NOTIFICATION_WM_CLOSE_REQUEST)
	_unblock_autosave(); _press("重试保存")
	_check(game.exits == exits + 1 and game.quit_pending and not game.exit_save and _saved_state() == state_probe.to_dict(), "Recovered window-close saves loaded cart once then exits without a second write")
	writes = state_probe.writes
	game._notification(game.NOTIFICATION_WM_CLOSE_REQUEST)
	_check(state_probe.writes == writes and game.exits == exits + 1, "Duplicate completed close neither writes nor exits again")
	game.quit_pending = false
	_port(3, "reserve", "short_ferries", "west")
	old_auto = _bytes(store.path_for(0)); state_probe.coins += 9
	_block_autosave(); game._notification(game.NOTIFICATION_WM_CLOSE_REQUEST)
	_press("不保存离开")
	_check(game.exits == exits + 1 and _modal_text().contains("舍下未存"), "Discarding unsaved loaded progress requires its own explicit confirmation")
	writes = state_probe.writes
	_press("确认不保存离开")
	_check(game.exits == exits + 2 and state_probe.writes == writes and _bytes(store.path_for(0)) == old_auto, "Explicit discard preserves exact earlier autosave and does not park, deliver or retry")
	_unblock_autosave(); game.quit_pending = false

func _test_pier_notice() -> void:
	_port(1, "meal", "", "east")
	game.world.traversal_blocked.connect(func(_message): pier_notices += 1)
	game.world.teleport(Vector2(805,425)); game._process(0)
	Input.action_press("move_down")
	for i in range(10): game.world._process(0.05)
	Input.action_release("move_down")
	_check(pier_notices == 1 and game.world.player_pos.y < 450 and state_probe.heting_cargo == "meal", "Actual held movement meets loaded pier restriction with one hint")
	game.world.teleport(Vector2(535,350)); game.world._process(0)
	game.world.teleport(Vector2(805,425)); Input.action_press("move_down"); game.world._process(0.15); Input.action_release("move_down")
	_check(pier_notices == 2, "Leaving the blockage region rearms the one-shot cart hint")

func _talk(id: String) -> void:
	if game.active_modal: game._close_modal()
	game.world.teleport(game.world.interactables[id].pos)
	game._process(0)
	await _key(KEY_E)
	_check(game.active_modal, "Real E opens current port sheet: " + id)

func _mouse(point: Vector2, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new(); motion.position = point; root.push_input(motion, true)
	var event := InputEventMouseButton.new(); event.position = point; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
	root.push_input(event, true); await process_frame

func _all_state() -> Dictionary:
	var result: Dictionary = {}
	var model = Model.new()
	for property in model.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value = state_probe.get(property.name)
			result[property.name] = value.duplicate(true) if value is Dictionary or value is Array else value
	return result

func _world() -> Array:
	return [game.world.map_id, game.world.player_pos, game.world.companion_pos, game.world.heting_bridge, game.world.heting_cargo, game.world.heting_draft, game.world.heting_delivered.duplicate()]
func _write_document(path: String, version: int, player: Dictionary) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE); file.store_string(JSON.stringify({"version": version, "player": player})); file.close()
func _bytes(path: String) -> PackedByteArray: return FileAccess.get_file_as_bytes(path)
func _version(path: String) -> int: return int(JSON.parse_string(FileAccess.get_file_as_string(path)).version)
func _saved_state() -> Dictionary:
	var saved = Model.new()
	_check(saved.load_game(store.path_for(0)) == OK, "Autosave remains a valid restorable branch")
	return saved.to_dict()
func _block_autosave() -> void:
	_check(DirAccess.make_dir_absolute(store.path_for(0) + ".tmp") == OK, "Inject reversible real temporary-file write failure")
func _unblock_autosave() -> void:
	_check(DirAccess.remove_absolute(store.path_for(0) + ".tmp") == OK, "Remove only test-owned failure blocker")
func _remove_fixture(path: String) -> void:
	var directory = DirAccess.open(path)
	if directory == null: return
	directory.list_dir_begin(); var name: String = directory.get_next()
	while not name.is_empty():
		var child: String = path.path_join(name)
		if directory.current_is_dir(): _remove_fixture(child)
		else: DirAccess.remove_absolute(child)
		name = directory.get_next()
	directory.list_dir_end(); DirAccess.remove_absolute(path)
