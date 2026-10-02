extends SceneTree
## Independent audit of frozen bae2c87. All I/O is redirected to a unique fixture.
const State = preload("res://scripts/game_state.gd")
const Slots = preload("res://scripts/local_save_slots.gd")
class AuditState:
	extends "res://scripts/game_state.gd"
	var auto_path: String
	func save_game(path: String = SAVE_PATH) -> Error:
		return super.save_game(auto_path if path == SAVE_PATH else path)
	func load_game(path: String = SAVE_PATH) -> Error:
		return super.load_game(auto_path if path == SAVE_PATH else path)
	func has_save() -> bool:
		return FileAccess.file_exists(auto_path)
var checks := 0
var failures := 0
var fixture: String
var game
var slots
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("INDEPENDENT SHEN AUDIT: " + label)
func _initialize() -> void:
	call_deferred("run")
func ready_state():
	var s = State.new()
	prepare(s)
	return s
func prepare(s) -> void:
	s.reset_game()
	s.level = 5 # Keep comparison fixtures away from XP level-up stat/HP changes.
	s.quest_stage = 6; s.ending = "秉公"; s.choose_sect("问石门")
	s.recruit_companion(); s.side_stage = 3; s.side_choice = "pursuit"
	s.side_reward_claimed = true; s.side_clues = 2; s.side_found.assign(["boatman", "ledger"])
	s.chapter_two_stage = 4; s.chapter_two_ending = "protect_witness"
	s.archive_clues.assign(["clerk", "inscription"]); s.seal_sequence.assign([2, 0, 1]); s.bridge_repaired = true
func progress(s, branch: String = "", post: bool = false) -> void:
	check(s.begin_shen_care() and s.consult_shen_patient() and s.inspect_shen_shelter(), "Reach decision via ordered public rules")
	if not branch.is_empty(): check(s.choose_shen_care(branch), "Choose branch " + branch)
	if post: check(s.post_shen_notice(), "Post branch " + branch)
func add_tang(s) -> void:
	check(s.begin_tangqi_quest() and s.recover_craft_notes() and s.resolve_tangqi_quest("teach") and s.recruit_tangqi(), "Recruit Tang via ordered public rules")
func text_of(node: Node) -> String:
	var result := ""
	if node is Label or node is Button or node is RichTextLabel: result += node.text + "\n"
	for child in node.get_children(): result += text_of(child)
	return result
func button(node: Node, label: String):
	if node is Button and node.text == label: return node
	for child in node.get_children():
		var found = button(child, label)
		if found != null: return found
	return null
func click(label: String) -> void:
	var found = button(game.overlay, label)
	check(found != null, "UI offers button " + label)
	if found != null: found.pressed.emit()
func document(data: Dictionary, version: int, path: String) -> void:
	var f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": version, "player": data})); f.close()
func byte_snapshot() -> Dictionary:
	var result := {}
	for id in [1, 2, 3]:
		for path in [slots.path_for(id), slots.path_for(id) + ".bak"]:
			if FileAccess.file_exists(path): result[path] = FileAccess.get_file_as_bytes(path)
	return result
func run() -> void:
	fixture = "user://shen-independent-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(fixture) == OK, "Create unique fixture")
	slots = Slots.new(fixture)
	natural_combat()
	migrations_and_invalid_documents()
	var routed = AuditState.new(); routed.auto_path = slots.path_for(0)
	game = load("res://scenes/main.tscn").instantiate(); game.state = routed
	root.add_child(game); game.save_slots.store = slots
	await process_frame
	game._new_game()
	manual_archived_branches()
	shared_task_routes()
	cancel_and_reselect()
	check(not FileAccess.file_exists(State.SAVE_PATH), "Never created normal-player autosave")
	for id in [1, 2, 3]: check(not FileAccess.file_exists("user://hero_slot_%d.json" % id), "Never created normal-player manual slot")
	game._stop_audio(); game.queue_free(); await process_frame
	for file in DirAccess.get_files_at(fixture): DirAccess.remove_absolute(fixture.path_join(file))
	DirAccess.remove_absolute(fixture)
	print("INDEPENDENT SHEN AUDIT: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
func natural_combat() -> void:
	# No counter or enemy-HP manipulation: valid attacks advance natural cadence.
	for branch in ["shore", "mobile"]:
		for who in ["沈青", "唐栖"]:
			for form in ["并肩", "护后"]:
				var plain = ready_state(); var upgraded = ready_state()
				progress(plain, branch); progress(upgraded, branch, true)
				for s in [plain, upgraded]:
					if who == "唐栖": add_tang(s)
					s.level = 5; s.xp = 0; s.hp = 70; s.set_formation(form); s.start_battle("sluice_boss")
				var expected_difference := 0
				var accepted_offense := 0
				for action in ["attack", "invalid", "guard", "skill", "skill", "attack"]:
					var before_count = upgraded._companion_attack_count
					var before_hp = upgraded.hp
					var a = plain.battle_action(action); var b = upgraded.battle_action(action)
					check(a.valid == b.valid, "Branch cannot alter accepted inputs")
					if not b.valid:
						check(upgraded.hp == before_hp and upgraded._companion_attack_count == before_count, "Rejected input causes no healing or cadence change")
					else:
						if form == "并肩" and action in ["attack", "skill"]: accepted_offense += 1
						if who == "沈青" and branch == "mobile" and form == "并肩" and action in ["attack", "skill"] and accepted_offense % 2 == 0: expected_difference += 2
						if who == "沈青" and branch == "shore" and form == "护后": expected_difference += 1
					check(upgraded.hp - plain.hp == expected_difference, "Natural support differential: %s / %s / %s / %s" % [branch, who, form, action])
					check(upgraded.enemy_hp == plain.enemy_hp and upgraded.qi == plain.qi, "Care branch preserves damage and qi cadence")
				check(upgraded.battle_active, "Sequence remains in actual active battle")
				var hp = upgraded.hp; upgraded.battle_action("flee")
				check(upgraded.hp == hp and not upgraded.battle_active, "Flee never heals")
				upgraded.start_battle("sluice_boss")
				check(upgraded._companion_attack_count == 0, "New battle resets cadence")
	# End-of-battle ordering: main blow kills before assist, versus actual assist kill.
	for attack in [18, 19]:
		var s = ready_state(); progress(s, "mobile", true); s.level = 5; s.xp = 0; s.attack = attack; s.hp = 70
		s.start_battle("training"); s.battle_action("attack")
		var hp = s.hp
		var result = s.battle_action("skill")
		check(result.won, "Natural training battle ends on second offensive action")
		check(s.hp == hp + (2 if attack == 18 else 0), "Only actual support finishing blow may heal; main blow cannot")
		check(not s.battle_action("attack").valid and s.hp == hp + (2 if attack == 18 else 0), "Inactive battle input never heals")
	var rejected = ready_state(); progress(rejected, "mobile", true)
	rejected.start_battle("sluice_boss"); rejected.battle_action("attack")
	rejected.medicine = 0; var before_reject = rejected.to_dict(); var count = rejected._companion_attack_count
	check(not rejected.battle_action("item").valid and rejected.to_dict() == before_reject and rejected._companion_attack_count == count, "Empty medicine input cannot heal or advance pending support")
	rejected.qi = 0; before_reject = rejected.to_dict()
	check(not rejected.battle_action("skill").valid and rejected.to_dict() == before_reject and rejected._companion_attack_count == count, "Insufficient qi cannot heal or advance pending support")
	check(not rejected.select_companion("唐栖") and rejected.current_companion() == "沈青", "Active battle forbids companion replacement")
	# Full HP cap with real support; no direct assist or counter calls.
	var capped = ready_state(); progress(capped, "mobile", true); capped.defense = 999
	capped.start_battle("sluice_boss"); capped.battle_action("attack"); capped.battle_action("attack")
	check(capped.hp == capped.max_hp - 1, "Support healing caps at maximum before minimum-one incoming damage")
func migrations_and_invalid_documents() -> void:
	var path = fixture.path_join("migrate.json")
	for version in range(1, 7):
		var s = ready_state(); add_tang(s)
		var old = s.to_dict(); old.erase("shen_care_stage"); old.erase("shen_care_choice")
		document(old, version, path)
		var loaded = State.new(); check(loaded.load_game(path) == OK, "Read legacy schema " + str(version))
		check(loaded.shen_care_stage == 0 and loaded.shen_care_choice == "" and loaded.current_companion() == "唐栖", "Migration neither invents Shen progress nor changes active companion")
		check(loaded.ShenCare.can_begin(loaded), "Migrated completed journey can start Shen story")
		check(loaded.save_game(path) == OK, "Explicit save upgrades legacy document")
		check(JSON.parse_string(FileAccess.get_file_as_string(path)).version == State.SAVE_VERSION, "Upgrade writes current schema")
	var minimal := {}
	var originals = State.new().to_dict()
	for field in ["player_name", "level", "xp", "coins", "hp", "max_hp", "qi", "max_qi", "attack", "defense", "medicine", "herbs", "quest_stage", "sect", "ending", "position", "victories"]: minimal[field] = originals[field]
	document(minimal, 1, path)
	var original_save = State.new()
	check(original_save.load_game(path) == OK and original_save.shen_care_stage == 0 and original_save.current_companion() == "", "Actual original-fields-only v1 save remains playable without invented companions or story")
	var stable = ready_state(); progress(stable, "shore", true)
	for field in ["shen_care_stage", "shen_care_choice"]:
		for bad in [null, {}, [], true, 1.25, "unknown"]:
			var corrupt = stable.to_dict(); corrupt[field] = bad; document(corrupt, State.SAVE_VERSION, path)
			var before = stable.to_dict()
			check(stable.load_game(path) == ERR_FILE_CORRUPT and stable.to_dict() == before, "Reject malformed " + field + " atomically: " + str(bad))
	for stage in range(6):
		var canonical = ready_state().to_dict(); canonical.shen_care_stage = stage; canonical.shen_care_choice = "mobile" if stage >= 4 else ""
		canonical.quest_stage = 5; canonical.side_stage = 1; canonical.side_reward_claimed = true
		document(canonical, 11, path)
		var restored = State.new(); check(restored.load_game(path) == OK, "Legacy11 effective completion accepts stage " + str(stage))
		check(restored.quest_stage == 6 and restored.side_stage == 3 and restored.shen_care_stage == stage, "Legacy migration restores coherent progression and exact stage")
		var before_current: Dictionary = restored.to_dict()
		document(canonical, State.SAVE_VERSION, path)
		check(restored.load_game(path) == ERR_FILE_CORRUPT and restored.to_dict() == before_current, "Current12 rejects noncanonical effective completion without mutating the migrated state")
func manual_archived_branches() -> void:
	prepare(game.state); progress(game.state); game._travel("qingwei", Vector2(330, 365))
	check(slots.save_slot(game.state, 1) == OK, "Archive pre-choice branch")
	game.shen_story.pharmacy(); click("留岸照护"); game._close_modal()
	check(slots.save_slot(game.state, 2) == OK, "Archive shore draft")
	game._show_board(); click("照此张贴"); game._close_modal()
	var shore_xp = game.state.xp
	check(slots.save_slot(game.state, 2) == OK, "Posted shore rotates draft to manual backup")
	check(slots.load_slot(game.state, 1) == OK, "Reopen pre-choice archive")
	game._apply_loaded_state(); game.shen_story.pharmacy(); click("随船问诊"); game._close_modal()
	game._show_board(); var old_post: Callable = game.modal_actions[0]; click("照此张贴"); game._close_modal()
	check(slots.save_slot(game.state, 3) == OK and game.state.xp == shore_xp, "Independent mobile branch receives one matching reward")
	var bytes = byte_snapshot()
	game.save_slots.detail(2); click("读取备份"); click("确认读取")
	check(game.state.shen_care_stage == 4 and game.state.shen_care_choice == "shore" and game.state.xp == shore_xp - 40, "UI backup restores exact unposted shore draft")
	var before = game.state.to_dict(); old_post.call()
	check(game.state.to_dict() == before, "Expired other-branch confirmation cannot post loaded archive")
	game.save_slots.detail(3); click("读取当前版本"); click("返回详情")
	check(game.state.to_dict() == before and byte_snapshot() == bytes, "Cancel branch switch preserves active state and every manual byte")
	click("读取当前版本"); click("确认读取")
	check(game.state.shen_care_stage == 5 and game.state.shen_care_choice == "mobile" and game.state.xp == shore_xp, "UI loading posted mobile restores correct reward and benefit")
	check(not game.state.post_shen_notice() and game.state.xp == shore_xp, "Archived completion cannot reaward")
	check(byte_snapshot() == bytes, "Reading branches and backup never rewrites manual files")
	game._new_game(); check(byte_snapshot() == bytes, "New journey retains all archived Shen branches")
	game.save_slots.detail(2); click("读取当前版本"); click("确认读取")
	check(game.state.shen_care_stage == 5 and game.state.shen_care_choice == "shore", "Posted shore remains loadable after new journey")
func shared_task_routes() -> void:
	for tang_first in [true, false]:
		prepare(game.state); game.state.begin_shen_care(); game.state.consult_shen_patient(); game.state.begin_tangqi_quest()
		game.state.mist_stage = 1
		game._travel("sluice", Vector2(570, 350)); game._sluice_cache_dialogue()
		check(button(game.overlay, "查看照护场地") != null and button(game.overlay, "寻找旧工册") != null, "Both simultaneous requests remain accessible")
		if tang_first:
			click("寻找旧工册"); click("收好工册"); game._sluice_cache_dialogue(); click("记下药棚情形")
		else:
			click("查看照护场地"); click("记下药棚情形"); game._sluice_cache_dialogue(); click("收好工册")
		check(game.state.shen_care_stage == 3 and game.state.tangqi_stage == 2 and game.state.mist_stage == 1, "Both completion orders preserve all three task states")
		game._travel("mistwood", Vector2(200, 460)); game._process(0); game._refresh()
		check(game.quest_label.text == game.mist_story.title() and game.world._quest_target_id() == game.mist_story.target_id(), "Active Mistwood objective agrees between HUD and world with both personal tasks pending")
func cancel_and_reselect() -> void:
	for branch in ["shore", "mobile"]:
		prepare(game.state); progress(game.state); game._travel("qingwei", Vector2(330, 365))
		game.shen_story.pharmacy(); var stale: Callable = game.modal_actions[0]
		game._close_modal(); stale.call()
		check(game.state.shen_care_stage == 3, "Canceled decision callback cannot create draft")
		game.shen_story.pharmacy(); click("留岸照护" if branch == "shore" else "随船问诊")
		var before = game.state.to_dict(); click("重新商议")
		click("留岸照护" if branch == "shore" else "随船问诊")
		check(game.state.to_dict() == before, "Reaffirming draft does not duplicate reward or change state")
		check(button(game.overlay, "带去告示牌") != null, "Reaffirming existing " + branch + " draft returns to draft confirmation")
		game._close_modal()
