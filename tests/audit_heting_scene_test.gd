extends "res://tests/audit_second_region_test.gd"
const PartyFixture=preload("res://tests/party_exploration_fixture.gd")
## Independent real-scene audit for Hero / 渡灯录. No production file writes.
## Run with an isolated XDG_DATA_HOME. The active adapter and every manual slot
## are routed below one unique fixture; navigation uses actual movement actions.
const Slots = preload("res://scripts/local_save_slots.gd")
const BaseState = preload("res://scripts/game_state.gd")
const Port = preload("res://scripts/heting_region.gd")

class PortAuditState:
	extends "res://scripts/game_state.gd"
	var fixture: String
	var writes: int = 0
	var paths: Array[String] = []
	func save_game(path: String = SAVE_PATH) -> Error:
		if path == SAVE_PATH: path = fixture.path_join("hero_save.json")
		writes += 1
		paths.append(path)
		return super.save_game(path)
	func load_game(path: String = SAVE_PATH) -> Error:
		if path == SAVE_PATH: path = fixture.path_join("hero_save.json")
		paths.append(path)
		return super.load_game(path)
	func has_save() -> bool:
		return FileAccess.file_exists(fixture.path_join("hero_save.json"))

var probe: PortAuditState
var store
var fixture: String
var walked_distance: float = 0.0
var real_interactions: int = 0

func _run() -> void:
	fixture = "user://heting-scene-audit-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_check(DirAccess.make_dir_recursive_absolute(fixture) == OK, "Create independent save fixture")
	probe = PortAuditState.new()
	probe.fixture = fixture
	store = Slots.new(fixture)
	game = load("res://scenes/main.tscn").instantiate()
	if not game.has_method("_new_game"):
		push_error("Main scene did not compile; no scene audit executed")
		game.free(); quit(2); return
	game.state = probe
	root.add_child(game)
	game.save_slots.store = store
	await process_frame
	game.world.set_process(false)
	for prior in ["release_water", "warn_ferries"]:
		for plan in ["short_ferries", "open_scale"]:
			await _route(prior, plan)
	await _parking_and_guards()
	await _save_branches_and_recovery()
	await _coexisting_quests()
	for path in probe.paths:
		_check(path.begins_with(fixture + "/"), "All audit state I/O stays isolated")
	_check(not FileAccess.file_exists(BaseState.SAVE_PATH), "No normal-player autosave created")
	for slot in range(1, 4):
		_check(not FileAccess.file_exists("user://hero_slot_%d.json" % slot), "No normal-player manual slot created")
	_check(walked_distance > 20000 and real_interactions > 50, "Audit exercised substantial real navigation and E input")
	game._stop_audio()
	game.queue_free()
	await process_frame
	_remove_port_fixture(fixture)
	_check(not DirAccess.dir_exists_absolute(fixture), "Temporary audit saves removed")
	if failures == 0: print("PASS: %d independent Heting scene checks; %.0f px navigated; %d real E interactions" % [checks, walked_distance, real_interactions])
	else: push_error("FAIL: %d of %d independent Heting scene checks" % [failures, checks])
	quit(0 if failures == 0 else 1)

func _prepare(prior: String, party: String = "") -> void:
	game._new_game()
	probe.quest_stage = 6; probe.ending = "守望"
	probe.choose_sect("问石门")
	probe.gain_xp(600)
	probe.side_stage = 3; probe.side_choice = "rescue"; probe.side_reward_claimed = true
	probe.side_clues = 2; probe.side_found.assign(["boatman", "ledger"])
	probe.chapter_two_stage = 4; probe.chapter_two_ending = "protect_witness"
	probe.archive_clues.assign(["clerk", "inscription"]); probe.seal_sequence.assign([2, 0, 1])
	probe.mist_stage = 4; probe.mist_approach = "duel"; probe.mist_ending = prior
	probe.mist_gauges.assign(["rain", "stone", "basin"])
	probe.resources = {"iron": 2, "timber": 3, "cloth": 4, "herb": 5}
	probe.coins = 137; probe.medicine = 8
	if party == "沈青":
		assert(probe.recruit_companion()); assert(probe.set_party_roster(["hero","shen"]))
		probe.shen_care_stage = 5; probe.shen_care_choice = "mobile"
	elif party == "唐栖":
		probe.bridge_repaired = true; probe.tangqi_stage = 3; probe.tangqi_choice = "teach"
		assert(probe.recruit_tangqi()); assert(probe.set_party_roster(["hero","tang"]))
	game._travel("mistwood", Vector2(1440, 505))
	game._process(0)

func _route(prior: String, plan: String) -> void:
	var tag: String = prior + "/" + plan
	_prepare(prior, "沈青" if plan == "short_ferries" else "唐栖")
	var initial_xp: int = _total_xp()
	var old_progress: Dictionary = _old_progress()
	await _talk_port("exit_heting", false)
	await _cancel_reload("stage0 entry " + tag)
	await _talk_port("exit_heting", false)
	_press("走入鹤汀埠")
	_check(probe.map_id == "heting" and game.world.map_id == "heting" and probe.heting_stage == 1, "Real entry starts fifth region " + tag)
	_check(probe.heting_bridge == ("east" if prior == "release_water" else "west"), "Prior Mist choice selects distinct initial floating pier")
	_check(game.region_header.text.contains("鹤汀") and game.chapter_header.text.contains("第四章"), "HUD names real region and chapter")
	_check(not probe.lightness_unlocked, "Heting entrance does not require lightness")
	_assert_saved("entry")
	await _key(KEY_M)
	var chart = _find_chart(game.overlay)
	_check(chart != null and chart.map_id == "heting" and chart.markers.size() == 7 and chart.heting_bridge == probe.heting_bridge, "Chart shows seven real sites and current floating pier")
	await _key(KEY_ESCAPE)
	var order: Array = ["sealed", "meal"] if prior == "release_water" else ["meal", "sealed"]
	for cargo_id in order:
		await _talk_port("heting_cargo")
		await _cancel_reload("source before " + cargo_id)
		await _talk_port("heting_cargo")
		_press("押" + ("开锅粮" if cargo_id == "meal" else "对秤封粮"))
		_check(probe.heting_cargo == cargo_id and probe.heting_ending.is_empty(), "Taking cargo creates only the chosen loaded cart")
		_assert_saved("cargo " + cargo_id)
		_check(not game.world._can_step(Vector2(805, 420), Vector2(805, 595)), "Loaded cart cannot leap across narrow foot pier")
		var receiver: String = "heting_relief" if cargo_id == "meal" else "heting_scale"
		await _talk_port(receiver)
		await _cancel_reload("loaded base receiver " + cargo_id)
		await _talk_port(receiver)
		var callback: Callable = game.modal_actions[0]
		_press("交下开锅粮" if cargo_id == "meal" else "交粮当面复称")
		_check(probe.heting_delivered.has(cargo_id) and probe.heting_cargo.is_empty(), "Local confirmed delivery consumes exactly that batch")
		_assert_saved("delivery result still open")
		var settled: Dictionary = probe.to_dict()
		callback.call()
		_check(probe.to_dict() == settled, "Repeated delivery callback cannot duplicate reward")
		if cargo_id == "sealed":
			_check(_modal_text().contains("两担") and not _modal_text().contains("许照川"), "Evidence stays narrow and protected witness remains unnamed")
		await _cancel_reload("post-delivery stage%d" % probe.heting_stage)
	_check(probe.heting_delivered == order and probe.heting_stage == 2 and _total_xp() == initial_xp + 20, "Either actual UI order produces only two +10 rewards")
	await _talk_port("heting_dispatch")
	await _cancel_reload("stage2 unchosen plan")
	await _talk_port("heting_dispatch")
	_press("拟作" + ("短渡分粮" if plan == "short_ferries" else "守秤留粮"))
	_check(probe.heting_stage == 3 and probe.heting_draft == plan and probe.heting_ending.is_empty(), "Night plan is a reversible draft")
	_assert_saved("chosen plan still open")
	var same_before: Dictionary = probe.to_dict()
	var same_writes: int = probe.writes
	_press("重新商议")
	_press("拟作" + ("短渡分粮" if plan == "short_ferries" else "守秤留粮"))
	_check(probe.to_dict() == same_before and probe.writes == same_writes and _modal_text().contains("夜工草案"), "Reaffirming same plan is a no-write no-reward draft redisplay")
	await _cancel_reload("stage3 draft")
	await _talk_port("heting_lighter")
	await _cancel_reload("reserve source")
	await _talk_port("heting_lighter")
	_press("押待分粮")
	_assert_saved("loaded reserve")
	_check(probe.heting_ending.is_empty(), "Loading final cart does not lock ending")
	await _talk_port("heting_relief" if plan == "short_ferries" else "heting_scale")
	await _cancel_reload("stage3 final confirmation")
	await _talk_port("heting_relief" if plan == "short_ferries" else "heting_scale")
	var final_callback: Callable = game.modal_actions[0]
	_press("照此交割")
	_check(probe.heting_stage == 4 and probe.heting_ending == plan and probe.heting_delivered == order + ["reserve"], "Final local confirmation alone locks actual destination " + tag)
	_check(probe.coins == 197 and _total_xp() == initial_xp + 120, "Both endings have identical +120 XP and +60 coins")
	_diff(old_progress,_old_progress(),"old progress")
	_check(_old_progress() == old_progress, "Heting leaves materials, medicine, old rewards, old choices and personal stories unchanged")
	_assert_saved("final result still open")
	var final_state: Dictionary = probe.to_dict()
	final_callback.call()
	_check(probe.to_dict() == final_state, "Completed final callback cannot replay reward")
	await _cancel_reload("stage4 ending")
	for receiver in ["heting_relief", "heting_scale", "heting_lighter"]:
		await _talk_port(receiver)
		_check(_find_button(game.overlay, "照此交割") == null and _find_button(game.overlay, "押待分粮") == null, "Completed sites expose aftermath only")
		await _key(KEY_ESCAPE)
	await _talk_port("heting_winch")
	var old_bridge: String = probe.heting_bridge
	_press("改接东岸" if old_bridge == "west" else "改接西岸")
	_check(probe.heting_bridge != old_bridge and probe.heting_ending == plan and probe.mist_ending == prior, "Completed chapter still permits free navigation without changing either ending")
	await _key(KEY_J)
	_check(_modal_text().contains("一秤两岸") and _modal_text().contains("已定：") and _modal_text().contains("复称"), "Journal preserves local evidence and final night arrangement")
	await _key(KEY_ESCAPE)

func _parking_and_guards() -> void:
	_prepare("warn_ferries")
	await _talk_port("exit_heting", false); _press("走入鹤汀埠")
	await _talk_port("heting_cargo")
	var canceled_take: Callable = game.modal_actions[0]
	await _key(KEY_ESCAPE)
	var before: Dictionary = probe.to_dict()
	canceled_take.call()
	_check(probe.to_dict() == before and not game.active_modal, "Cancelled cargo modal callback cannot later take cargo")
	await _talk_port("heting_cargo"); _press("押开锅粮")
	await _talk_port("heting_winch")
	var loaded_before: Dictionary = probe.to_dict()
	_press("改接东岸")
	_check(probe.heting_bridge == "east" and probe.heting_cargo == "meal" and probe.coins == loaded_before.coins and probe.resources == loaded_before.resources, "Loaded cart can operate real island winch for free")
	_assert_saved("loaded bridge change")
	await _talk_port("heting_winch"); _press("改接西岸")
	await _talk_port("heting_cargo"); _press("退车归位")
	_check(probe.heting_cargo.is_empty() and probe.heting_delivered.is_empty(), "Original source parking returns batch without delivery")
	await _talk_port("heting_cargo"); _press("押开锅粮")
	await _talk_port("heting_dispatch"); _press("退车归位")
	_check(probe.heting_cargo.is_empty() and probe.available_heting_cargo("heting_cargo").size() == 2, "Dispatch parking restores exactly finite source stock")
	await _talk_port("heting_cargo"); _press("押对秤封粮")
	await _talk_port("heting_relief")
	_check(_find_button(game.overlay, "交下开锅粮") == null, "Wrong base receiver cannot consume sealed grain")
	probe.hp = 40; probe.qi = 0
	_press("免费调息")
	_check(probe.heting_cargo == "sealed" and probe.hp == probe.max_hp and probe.qi == probe.max_qi, "Free wrong-receiver rest preserves carried grain")
	await _talk_port("return_mistwood")
	await _cancel_reload("loaded exit cancellation")
	await _talk_port("return_mistwood"); _press("退车后离开")
	_check(probe.map_id == "mistwood" and probe.heting_cargo.is_empty() and probe.heting_stage == 1, "Loaded exit explicitly parks then travels")
	await _talk_port("exit_heting", false); _press("返回鹤汀埠")
	_check(probe.available_heting_cargo("heting_cargo").size() == 2 and probe.heting_bridge == "west", "Reentry restores finite stock and bridge")
	await _talk_port("heting_cargo")
	var remote_take: Callable = game.modal_actions[0]
	game.world.teleport(Vector2(180, 350)); game._process(0)
	before = probe.to_dict()
	remote_take.call()
	_check(probe.to_dict() == before, "Same-generation cargo callback rejects an actor moved away from source")
	game._close_modal()
	# Independent fixture for a loaded final cart; real transitions above cover setup.
	_set_port(3, "reserve", "short_ferries", "east")
	await _talk_port("heting_scale")
	var coins_before: int = probe.coins
	_press("改作守秤留粮")
	_check(probe.heting_draft == "open_scale" and probe.heting_stage == 3 and probe.heting_cargo == "reserve" and probe.coins == coins_before, "Wrong receiver local plan change remains uncompleted")
	_check(_find_button(game.overlay, "照此交割") != null, "Local plan change opens a distinct final confirmation")
	_assert_saved("local revised draft")
	var obsolete_final: Callable = game.modal_actions[0]
	await _key(KEY_ESCAPE)
	await _talk_port("heting_dispatch")
	_press("重新商议"); _press("拟作短渡分粮")
	before = probe.to_dict()
	obsolete_final.call()
	_check(probe.to_dict() == before and _modal_text().contains("短渡分粮"), "Old final modal cannot override a newer draft/modal")
	game._close_modal()
	await _talk_port("heting_scale")
	before = probe.to_dict()
	game.heting_story.finish("heting_scale", "open_scale")
	_check(probe.to_dict() == before, "Explicit stale expected-plan callback cannot finish a changed draft")
	await _key(KEY_ESCAPE)
	await _talk_port("heting_relief")
	var remote_final: Callable = game.modal_actions[0]
	game.world.teleport(Vector2(180, 350)); game._process(0)
	before = probe.to_dict(); remote_final.call()
	_check(probe.to_dict() == before, "Final receiver callback rechecks actual local distance")
	game._close_modal()
	_set_port(3, "reserve", "short_ferries", "west")
	await _talk_port("heting_dispatch"); _press("退车归位")
	_check(probe.heting_draft == "short_ferries" and probe.heting_cargo.is_empty(), "Reserve parking preserves draft")
	await _talk_port("heting_lighter"); _press("押待分粮")
	await _talk_port("return_mistwood"); _press("退车后离开")
	await _talk_port("exit_heting", false); _press("返回鹤汀埠")
	_check(probe.heting_stage == 3 and probe.heting_draft == "short_ferries" and probe.available_heting_cargo("heting_lighter") == ["reserve"], "Loaded reserve exit and reentry preserve draft and return last batch to source")

func _save_branches_and_recovery() -> void:
	for slot in range(1, 4):
		DirAccess.remove_absolute(store.path_for(slot))
		DirAccess.remove_absolute(store.path_for(slot) + ".bak")
	_set_port(1, "meal", "", "east")
	game.world.teleport(Vector2(1130, 730)); game._process(0)
	await _key(KEY_F6); _press("写下手记一"); await _key(KEY_ESCAPE)
	var branch1: Dictionary = probe.to_dict()
	_set_port(3, "reserve", "open_scale", "west")
	game.world.teleport(Vector2(470, 730)); game._process(0)
	await _key(KEY_F6); _press("写下手记二"); await _key(KEY_ESCAPE)
	var branch2: Dictionary = probe.to_dict()
	_set_port(4, "", "short_ferries", "east")
	await _key(KEY_F6); _press("写下手记三"); await _key(KEY_ESCAPE)
	var branch3: Dictionary = probe.to_dict()
	var originals: Dictionary = _slot_bytes()
	for pair in [[1, branch1], [2, branch2], [3, branch3], [2, branch2], [1, branch1]]:
		await _key(KEY_F10)
		_press(["", "手记一", "手记二", "手记三"][pair[0]])
		_press("读取当前版本"); _press("确认读取")
		_check(probe.to_dict() == pair[1] and game.world.player_pos == probe.position, "Real manual load restores exact branch including active-bridge coordinate")
		_check(game.world.heting_bridge == probe.heting_bridge and game.world.heting_cargo == probe.heting_cargo, "Saved terrain and loaded status applied before coordinate repair")
		_check(_slot_bytes() == originals, "Branch load does not rewrite any manual branch")
	# Capture old first branch as backup through real overwrite UI.
	_set_port(3, "reserve", "short_ferries", "west")
	await _key(KEY_F6); _press("写下手记一"); _press("确认重写"); await _key(KEY_ESCAPE)
	_check(FileAccess.get_file_as_bytes(store.path_for(1) + ".bak") == originals[store.path_for(1)], "Overwriting keeps exact earlier loaded-cart branch as backup")
	await _key(KEY_F10); _press("手记一"); _press("读取备份"); _press("确认读取")
	_check(probe.to_dict() == branch1, "UI backup read restores terrain, cargo, coordinates and old state")
	for unsafe in [Vector2(805, 500), Vector2(450, 730), Vector2(500, 900)]:
		_set_port(3, "reserve", "short_ferries", "east")
		probe.position = unsafe
		_check(probe.save_game() == OK, "Write valid-state unsafe-coordinate fixture")
		game.world.heting_bridge = "west"; game.world.heting_cargo = ""
		game._load()
		_check(game.world.player_pos == Port.LOADED_SAFE and probe.heting_cargo == "reserve" and probe.heting_delivered == ["meal", "sealed"], "Unsafe loaded coordinate repaired after terrain state without losing or delivering cargo")
		var followers_safe:bool=Port.walkable(game.world.player_pos,"east",false)
		for id in game.world.follower_ids():followers_safe=followers_safe and Port.walkable(game.world.follower_view(id).position,"east",false)
		_check(followers_safe, "Restored player and every selected follower are placed on legal terrain")
	_set_port(3, "reserve", "open_scale", "west")
	game._save()
	var valid: Dictionary = probe.to_dict()
	var bads: Array = []
	for patch in [{"heting_stage": 3.5}, {"heting_bridge": "north"}, {"heting_delivered": ["meal", "meal"]}, {"heting_cargo": "sealed"}, {"heting_ending": "open_scale"}, {"map_id": "mistwood"}, {"mist_stage": 3}, {"heting_stage": 4}]:
		var corrupt: Dictionary = valid.duplicate(true); corrupt.merge(patch, true); bads.append(corrupt)
	var missing: Dictionary = valid.duplicate(true); missing.erase("heting_draft"); bads.append(missing)
	for corrupt in bads:
		_write_document(store.path_for(3), {"version": 9, "player": corrupt})
		probe.enemy_hp = 73; probe.turn = 12; probe.skill_cooldown = 2; probe.battle_log.assign(["retained transient marker"])
		var full_before: Dictionary = _full_state()
		var world_before: Dictionary = _world_snapshot()
		var auto_before: PackedByteArray = FileAccess.get_file_as_bytes(store.path_for(0))
		var write_before: int = probe.writes
		game.save_slots.perform_load(3, false)
		_check(_full_state() == full_before and _world_snapshot() == world_before and probe.writes == write_before and FileAccess.get_file_as_bytes(store.path_for(0)) == auto_before, "Invalid manual load preserves every persistent/transient state field, terrain and autosave")
	# A legitimate version-eight save remains accepted after the version-nine expansion.
	var legacy = BaseState.new()
	var old: Dictionary = legacy.to_dict()
	for field in probe.Heting.FIELDS: old.erase(field)
	_write_document(store.path_for(3), {"version": 8, "player": old})
	game.save_slots.perform_load(3, false)
	_check(probe.map_id == "qingwei" and probe.heting_stage == 0 and probe.heting_bridge.is_empty(), "Actual loader still accepts a field-less v8 save")

func _coexisting_quests() -> void:
	_prepare("release_water", "沈青")
	probe.shen_care_stage = 3; probe.shen_care_choice = ""
	probe.bridge_repaired = true; probe.tangqi_stage = 1
	await _talk_port("exit_heting", false); _press("走入鹤汀埠")
	_check(game.quest_label.text == game.heting_story.title() and game.world._quest_target_id() == "heting_cargo", "Port objective remains usable with both personal quests pending")
	await _talk_port("heting_dispatch")
	_check(not _modal_text().contains("唐栖："), "Absent companion does not speak remotely")
	await _key(KEY_ESCAPE)
	await _talk_port("return_mistwood")
	_check(probe.map_id == "mistwood" and probe.shen_care_stage == 3 and probe.tangqi_stage == 1, "Leaving port preserves both unfinished personal stories")
	_check(game.quest_label.text == "尺上旧痕" and game.world._quest_target_id() == "return_frostbridge", "Old companion quest resumes actual return target outside port")
	probe.tangqi_stage = 0
	game._process(0); game._refresh()
	_check(game.quest_label.text == "药箱之外", "Shen personal story resumes when it is the remaining pending story")
	game._travel("qingwei", Vector2(460, 430))
	probe.sect_trial_won = true; probe.sect_rank = 1
	game._process(0); game._refresh()
	_check(game.quest_label.text == "待领门中荐记" and game.world._quest_target_id() == "mentor", "Existing earned sect reward remains targeted over optional chapter travel")

func _set_port(stage: int, cargo_id: String, plan: String, bridge: String) -> void:
	if game.active_modal: game._close_modal()
	probe.heting_stage = stage; probe.heting_bridge = bridge
	probe.heting_delivered.clear()
	if stage >= 2: probe.heting_delivered.assign(["meal", "sealed"])
	if stage == 4: probe.heting_delivered.append("reserve")
	probe.heting_cargo = cargo_id; probe.heting_draft = plan
	probe.heting_ending = plan if stage == 4 else ""
	game._travel("heting", Port.LOADED_SAFE if not cargo_id.is_empty() else Port.ENTRY)
	game._process(0)

func _talk_port(id: String, navigate: bool = true) -> void:
	if game.active_modal: game._close_modal()
	_check(game.world.interactables.has(id), "Interaction exists: " + id)
	if not game.world.interactables.has(id): return
	var destination: Vector2 = game.world.interactables[id].pos
	if navigate and game.world.map_id == "heting": _navigate(destination)
	else: game.world.teleport(destination)
	game.world._update_nearby(); game._process(0)
	_check(game.world.nearby_id == id, "Navigation reaches actual nearest interaction: " + id)
	await _key(KEY_E)
	real_interactions += 1
	_check(game.active_modal or (id == "return_mistwood" and probe.map_id == "mistwood"), "Actual E input handles " + id)

func _cancel_reload(label: String) -> void:
	# A cancellation cannot rewrite a save, even to identical bytes. Save the
	# current position explicitly first so the subsequent reload has a baseline.
	game._save()
	var before: Dictionary = probe.to_dict()
	var count: int = probe.writes
	var data: PackedByteArray = FileAccess.get_file_as_bytes(store.path_for(0))
	await _key(KEY_ESCAPE)
	_check(probe.to_dict() == before and probe.writes == count and FileAccess.get_file_as_bytes(store.path_for(0)) == data, "Escape cancel makes no state or file write: " + label)
	game._load()
	_diff(before,probe.to_dict(),label)
	_check(probe.to_dict() == before and not game.active_modal, "Cancel then reload preserves exact stage: " + label)

func _assert_saved(label: String) -> void:
	var loaded = BaseState.new()
	var load_error=loaded.load_game(store.path_for(0))
	if load_error==OK:_diff(probe.to_dict(),loaded.to_dict(),label)
	_check(load_error == OK and loaded.to_dict() == probe.to_dict(), "Transition autosaved before further dismissal: " + label)

func _total_xp() -> int:
	return probe.xp + 30 * probe.level * (probe.level - 1)

func _old_progress() -> Dictionary:
	var data: Dictionary = probe.to_dict()
	for key in ["level", "xp", "coins", "hp", "max_hp", "qi", "attack", "defense", "position", "map_id"] + Array(probe.Heting.FIELDS): data.erase(key)
	return data

func _full_state() -> Dictionary:
	var result: Dictionary = {}
	var template = BaseState.new()
	for property in template.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value = probe.get(property.name)
			result[property.name] = value.duplicate(true) if value is Dictionary or value is Array else value
	return result

func _world_snapshot() -> Dictionary:
	return {"map": game.world.map_id, "player": game.world.player_pos, "companion": game.world.companion_pos, "followers": PartyFixture.positions(game.world), "bridge": game.world.heting_bridge, "cargo": game.world.heting_cargo, "draft": game.world.heting_draft, "delivered": game.world.heting_delivered.duplicate(), "ending": game.world.heting_ending}

func _slot_bytes() -> Dictionary:
	var result: Dictionary = {}
	for slot in range(1, 4):
		for suffix in ["", ".bak"]:
			var path: String = store.path_for(slot) + suffix
			if FileAccess.file_exists(path): result[path] = FileAccess.get_file_as_bytes(path)
	return result

func _write_document(path: String, doc: Dictionary) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(doc)); file.close()

func _navigate(destination: Vector2) -> void:
	# Use the world collision API to plan, then feed the actual movement actions.
	# This cannot teleport across water or through the loaded-cart restriction.
	var start: Vector2 = game.world.player_pos
	if game.world._can_step(start, destination):
		_drive_segment(destination)
		return
	var start_cell := Vector2i(roundi(start.x / 20.0), roundi(start.y / 20.0))
	var goal_cell := Vector2i(roundi(destination.x / 20.0), roundi(destination.y / 20.0))
	var start_grid := Vector2(start_cell) * 20.0
	var goal_grid := Vector2(goal_cell) * 20.0
	_check(game.world._can_step(start, start_grid) and game.world._can_step(goal_grid, destination), "Route grid anchors connect to actual actor/site")
	var frontier: Array[Vector2i] = [start_cell]
	var previous: Dictionary = {start_cell: start_cell}
	var cursor: int = 0
	while cursor < frontier.size() and not previous.has(goal_cell):
		var cell: Vector2i = frontier[cursor]; cursor += 1
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + step
			if previous.has(next) or next.x < 2 or next.x > 78 or next.y < 8 or next.y > 50: continue
			if not game.world._can_step(Vector2(cell) * 20.0, Vector2(next) * 20.0): continue
			previous[next] = cell; frontier.append(next)
	_check(previous.has(goal_cell), "Actual world has a reachable route to " + str(destination))
	if not previous.has(goal_cell): return
	var route: Array[Vector2] = [destination]
	var cell := goal_cell
	while cell != start_cell:
		route.push_front(Vector2(cell) * 20.0); cell = previous[cell]
	route.push_front(start_grid)
	for point in route: _drive_segment(point)
	_check(game.world.player_pos.distance_to(destination) < 0.2, "Real move actions reach requested site without teleport")

func _drive_segment(destination: Vector2) -> void:
	var difference: Vector2 = destination - game.world.player_pos
	if difference.length() < 0.01: return
	# A diagonal's action vector matches the world normalization. Subdivide the
	# residual when the slope is not exactly diagonal.
	if absf(difference.x) > 0.01 and absf(difference.y) > 0.01 and absf(absf(difference.x) - absf(difference.y)) > 0.01:
		var corner := Vector2(destination.x, game.world.player_pos.y)
		if game.world._can_step(game.world.player_pos, corner) and game.world._can_step(corner, destination):
			_drive_segment(corner); _drive_segment(destination); return
		corner = Vector2(game.world.player_pos.x, destination.y)
		if game.world._can_step(game.world.player_pos, corner) and game.world._can_step(corner, destination):
			_drive_segment(corner); _drive_segment(destination); return
		_check(false, "Navigation cannot translate unsafe diagonal corner"); return
	var direction: Vector2 = difference.normalized()
	for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)
	if direction.x < -0.001: Input.action_press("move_left")
	if direction.x > 0.001: Input.action_press("move_right")
	if direction.y < -0.001: Input.action_press("move_up")
	if direction.y > 0.001: Input.action_press("move_down")
	var length: float = difference.length()
	var steps: int = maxi(1, int(ceil(length / 8.0)))
	var safe: bool = true
	game.world.active = true
	for i in range(steps):
		game.world._process(length / float(steps) / game.world.SPEED)
		safe = safe and game.world._can_walk(game.world.player_pos)
		for id in game.world.follower_ids():safe=safe and Port.walkable(game.world.follower_view(id).position,probe.heting_bridge,false)
	for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)
	walked_distance += length
	_check(safe, "Actual movement and companion remain on legal port terrain")
	game._process(0)

func _remove_port_fixture(path: String) -> void:
	var directory = DirAccess.open(path)
	if directory == null: return
	directory.list_dir_begin()
	var name: String = directory.get_next()
	while not name.is_empty():
		var child: String = path.path_join(name)
		if directory.current_is_dir(): _remove_port_fixture(child)
		else: DirAccess.remove_absolute(child)
		name = directory.get_next()
	directory.list_dir_end(); DirAccess.remove_absolute(path)

func _diff(before:Dictionary,after:Dictionary,label:String)->void:
	for key in before:
		if before[key]!=after.get(key):print("STATE_DIFFERENCE ",label," ",key,": ",before[key]," -> ",after.get(key))
