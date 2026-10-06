extends SceneTree
## NEW validation of recovered current source; not a recreation of lost evidence.
## Run only through the isolated launcher. Intentionally no game preloads,
## subclasses, redirected-save adapters, or suppressed production save calls.
## This file stays external; the launcher runs the recovered checkout in place
## with a fresh external QA profile and source-before/source-after hashes.

const SAVE_PATH = "user://hero_save.json"
const SCHOOLS = [
	{"sect":"听潮阁", "arts":["照夜一线","回潮断浪","束潮削势","伏汐藏锋"], "costs":[3,4,3,4], "cooldowns":[2,3,2,3], "multipliers":[2,2,1,1], "bonuses":[8,16,8,6]},
	{"sect":"照野堂", "arts":["照夜一线","青灯续脉","青灯息争","续灯引锋"], "costs":[3,3,3,4], "cooldowns":[2,3,3,3], "multipliers":[2,1,1,1], "bonuses":[8,0,0,0]},
	{"sect":"问石门", "arts":["照夜一线","磐石回锋","石隙封腕","藏锋立岳"], "costs":[3,3,3,4], "cooldowns":[2,2,2,3], "multipliers":[2,1,1,1], "bonuses":[8,10,4,0]},
]
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
var current_section = "guard"
var finished = false
var collision_owned = false
var guard_passed = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not _guard():
		push_error("ERROR: isolated folio QA guard rejected startup; no game resources loaded")
		quit(2)
		return
	guard_passed = true
	create_timer(120.0).timeout.connect(func():
		if not finished:
			_check(false, "Integration test exceeded its 120-second watchdog")
			_finish())
	# Loading Main initializes a genuine HeroState only AFTER guard success.
	model = load("res://scripts/game_state.gd")
	var scene = load("res://scenes/main.tscn")
	battle_driver = load("res://tests/unified_ui_test_driver.gd")
	if not _check(model != null and scene != null and battle_driver != null, "Dynamic game resources load"):
		_finish(); return
	app = scene.instantiate()
	if not _check(app != null and app.has_method("_new_game"), "Real Main script instantiates"):
		_finish(); return
	root.size = Vector2i(1280,800)
	root.add_child(app)
	await process_frame
	app._stop_audio()
	app.audio_on = false
	app.battle_presentation_enabled = false
	_check(app.state.get_script() == model, "Main owns exactly the production HeroState script")
	await _inventory()
	if not failures.is_empty(): _finish(); return
	await _martial()
	if not failures.is_empty(): _finish(); return
	await _workshop()
	if not failures.is_empty(): _finish(); return
	await _cultivation()
	if not failures.is_empty(): _finish(); return
	await _failed_save_retry()
	if not failures.is_empty(): _finish(); return
	await _battle_gate()
	_finish()

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
	if FileAccess.file_exists(report_path) or DirAccess.dir_exists_absolute(report_path): return false
	if not DirAccess.dir_exists_absolute(report_path.get_base_dir()): return false
	var dir = DirAccess.open(owned_user)
	if dir == null: return false
	dir.include_hidden = true
	# Godot can create its own log directory before a SceneTree script starts.
	if not dir.get_files().is_empty(): return false
	for directory: String in dir.get_directories():
		if directory != "logs" or not _no_links(owned_user.path_join(directory)): return false
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

func _section(name: String) -> void:
	current_section = name
	sections.append(name)

func _key(code: int) -> void:
	# Events pass through the real viewport and Main's input dispatcher.
	for pressed: bool in [true,false]:
		var event = InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func _button(caption: String):
	for node in app.overlay.find_children("*","Button",true,false):
		if node.text == caption: return node
	return null

func _click(caption: String) -> void:
	# Newly built NPC pages defer native text measurement and recentering.
	# Settle that layout BEFORE sampling a pointer location, as a user sees it.
	await process_frame
	var target = _button(caption)
	if not _check(target != null and target.is_visible_in_tree(), "Pointer target exists: "+caption): return
	var location: Vector2 = target.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = location
	root.push_input(motion,true)
	await process_frame
	if not _check(is_instance_valid(target) and target.is_visible_in_tree() and target.get_global_rect().has_point(location), "Pointer target remains under sampled coordinate after layout: "+caption): return
	for pressed: bool in [true,false]:
		var event = InputEventMouseButton.new()
		event.position = location
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

func _action(index: int) -> Callable:
	if not _check(index >= 0 and index < app.modal_actions.size(), "Saved callback exists at index "+str(index)):
		return func(): pass
	return app.modal_actions[index]

func _texts(node: Node) -> String:
	var result = ""
	if node is Label or node is RichTextLabel: result = node.text
	for child in node.get_children(): result += _texts(child)
	return result

func _disk() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(SAVE_PATH) if FileAccess.file_exists(SAVE_PATH) else PackedByteArray()

func _transients() -> Dictionary:
	var result = {}
	for key: String in TRANSIENT_KEYS:
		var value = app.state.get(key)
		result[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	result["party_session_identity"] = app.state.party_session.get_instance_id() if app.state.party_session != null else 0
	result["receipt_session_identity"] = app.state.receipt_session.get_instance_id() if app.state.receipt_session != null else 0
	result["party_snapshot"] = app.state.party_battle_snapshot().duplicate(true)
	result["receipt_snapshot"] = app.state.receipt_battle_snapshot().duplicate(true)
	return result

func _snapshot(label: String) -> Dictionary:
	var result = {"state":app.state.to_dict().duplicate(true), "transients":_transients(),
		"world_position":app.world.player_pos, "world_map":app.world.map_id, "disk":_disk()}
	# Actual byte arrays are compared in memory; the report records exact hashes,
	# lengths and full canonical/transient values without repeating save JSON.
	checkpoints.append({"section":current_section,"label":label,"state":result.state,
		"transients":_json_safe(result.transients), "world_position":var_to_str(result.world_position),
		"world_map":result.world_map,"save_bytes":result.disk.size(),
		"save_sha256":FileAccess.get_sha256(SAVE_PATH) if not result.disk.is_empty() else ""})
	return result

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

func _expect(before: Dictionary, edits: Dictionary, label: String, save_policy: String = "unchanged") -> void:
	var expected: Dictionary = before.state.duplicate(true)
	for key in edits: expected[key] = edits[key]
	var after = _snapshot(label)
	_check(after.state == expected, label+": only expected canonical fields change")
	_check(after.transients == before.transients, label+": battle/effect/session transients unchanged")
	_check(after.world_position == before.world_position and after.world_map == before.world_map, label+": world position/map unchanged")
	if save_policy == "unchanged":
		_check(after.disk == before.disk, label+": save bytes unchanged")
	elif save_policy == "persisted":
		_saved(expected,label)

func _saved(expected: Dictionary, label: String) -> void:
	_check(FileAccess.file_exists(SAVE_PATH) and not _disk().is_empty(), label+": production save exists")
	var loaded = model.new()
	var error = loaded.load_game()
	_check(error == OK, label+": real HeroState reload validates save")
	if error == OK: _check(loaded.to_dict() == expected, label+": reload retains exact canonical state")
	_check(not app.save_warning, label+": no save warning")

func _checkpoint() -> void:
	app._refresh()
	app._autosave()
	_saved(app.state.to_dict(),"Prepared legal fixture checkpoint")

func _new_game() -> void:
	app._new_game()
	app._stop_audio()
	app.audio_on = false
	app.world.teleport(Vector2(460,430))
	app.state.position = app.world.player_pos
	app._refresh()

func _school_fixture(school: String, completed_deeds: bool = false) -> void:
	_new_game()
	app.state.gain_xp(180)
	app.state.choose_sect(school)
	app.state.quest_stage = 6
	app.state.ending = "守望"
	app.state.sect_trial_won = true
	_check(app.state.complete_sect_trial(),"Legal prepared inner-disciple promotion")
	if completed_deeds:
		app.state.side_stage = 3
		app.state.side_choice = "rescue"
		app.state.side_reward_claimed = true
		app.state.side_clues = 2
		app.state.side_found.assign(["boatman","ledger"])
		app.state.chapter_two_stage = 4
		app.state.chapter_two_ending = "protect_witness"
		app.state.archive_clues.assign(["clerk","inscription"])
		app.state.seal_sequence.assign([2,0,1])
	_checkpoint()

func _inventory() -> void:
	_section("inventory")
	_new_game()
	var before = _snapshot("New journey")
	await _key(KEY_I)
	_expect(before,{},"I opens inventory without state/save mutation")
	_check(app.active_modal and app.overlay.get_meta("inventory",false) and app.modal_actions.size()==5,"Inventory retains five numeric actions")
	var frame = app.overlay.find_child("InventoryFrame",true,false)
	if not _check(frame != null,"Current inventory folio exists"): return
	_check(Rect2(Vector2.ZERO,Vector2(1280,800)).encloses(frame.get_rect()),"Inventory frame stays inside logical viewport")
	_check(frame.find_child("InventoryTraveller",true,false) != null,"Traveller is present")
	var text = _texts(frame)
	for content: String in ["旧铁剑","粗布行衣","照夜一线","攻击 16","防御 4","修为 0 / 60","还需 21 文"]:
		_check(text.contains(content),"New inventory displays "+content)
	for label in frame.find_children("*","RichTextLabel",true,false):
		_check(not label.scroll_active,"Inventory summary retains non-scrolling labels")
	for caption: String in ["回春散","切换阵型","青钢剑 · 45文","返回江湖","同行册"]:
		var button = _button(caption)
		if not _check(button != null and button.is_visible_in_tree(),"Visible original action "+caption): return
	_check(_button("回春散").disabled and _button("回春散").tooltip_text=="气血已满","Full-health medicine is disabled with reason")
	_check(_button("切换阵型").disabled and _button("青钢剑 · 45文").disabled,"Unavailable formation and sword are disabled")
	var old_purchase = _action(2)
	await _key(KEY_3)
	_expect(before,{},"Insufficient-money numeric purchase is inert")
	_check(app.overlay.find_child("InventoryHelp",true,false).text=="还需 21 文","Numeric blocked purchase explains shortage")
	await _key(KEY_2)
	_expect(before,{},"No-companion numeric formation is inert")
	_check(app.overlay.find_child("InventoryHelp",true,false).text=="尚无同行人","Numeric blocked formation explains absence")
	await _key(KEY_1)
	_expect(before,{},"Full-health numeric medicine is inert")
	await _key(KEY_ESCAPE)
	_check(not app.active_modal,"Escape closes inventory")
	_saved(app.state.to_dict(),"Ordinary inventory close saves by production policy")
	before = _snapshot("After close")
	old_purchase.call()
	_expect(before,{},"Saved purchase callback after close is inert")
	await _key(KEY_I)
	before = _snapshot("Reopened inventory")
	old_purchase.call()
	_expect(before,{},"Prior-generation purchase cannot act on reopened inventory")
	_check(app.active_modal,"Stale callback does not close the new inventory")
	await _key(KEY_K)
	_expect(before,{},"Inventory K changes only the page")
	_check(app.overlay.find_child("MartialFolio",true,false)!=null and not app.overlay.get_meta("inventory",false),"K opens martial folio")
	await _key(KEY_ESCAPE)
	await _key(KEY_I)
	before = _snapshot("Inventory before B")
	await _key(KEY_B)
	_expect(before,{},"Inventory B changes only the page")
	_check(app.overlay.find_child("WorkshopFolio",true,false)!=null and not app.overlay.get_meta("inventory",false),"B opens workshop folio")
	await _key(KEY_ESCAPE)
	app.state.quest_stage = 6
	app.state.ending = "守望"
	_check(app.state.recruit_companion(),"Prepared legal companion recruited")
	app.state.coins = 70
	_checkpoint()
	await _key(KEY_I)
	before = _snapshot("Affordable sword")
	old_purchase.call()
	_expect(before,{},"Old unavailable-page callback stays invalid when purchase is now affordable")
	old_purchase = _action(2)
	await _click("青钢剑 · 45文")
	_expect(before,{"coins":25,"equipment":"青钢剑","attack":before.state.attack+4},"Pointer sword purchase costs exactly45 and adds4 attack")
	_check(_button("青钢剑 · 45文").disabled and _texts(app.overlay).contains("青钢剑"),"Purchase redraws owned equipment and disables repeat")
	before = _snapshot("Purchased sword before close")
	old_purchase.call()
	await _key(KEY_3)
	_expect(before,{},"Stale callback and current numeric duplicate cannot buy twice")
	await _click("切换阵型")
	_expect(before,{"formation":"护后"},"Pointer formation changes only formation")
	before = _snapshot("Formation before numeric toggle")
	await _key(KEY_2)
	_expect(before,{"formation":"并肩"},"Numeric2 permits next valid formation toggle")
	await _key(KEY_4)
	_check(not app.active_modal,"Numeric4 closes inventory")
	_saved(app.state.to_dict(),"Close persists sword and formation changes")
	app.state.hp = 50
	_checkpoint()
	await _key(KEY_I)
	before = _snapshot("Medicine at50 health")
	await _key(KEY_1)
	_expect(before,{"hp":95,"medicine":before.state.medicine-1},"Numeric1 consumes one medicine and heals45","persisted")
	_check(not app.active_modal,"Successful medicine closes inventory")
	# Separate prepared school fixture preserves the existing 55-point exception.
	_school_fixture("照野堂")
	app.state.hp = 40
	_checkpoint()
	await _key(KEY_I)
	before = _snapshot("Zhaoye medicine at40 health")
	await _key(KEY_SPACE)
	_expect(before,{"hp":95,"medicine":before.state.medicine-1},"Space medicine heals55 for Zhaoye","persisted")
	_new_game()
	app.state.coins = 70
	_checkpoint()
	await _key(KEY_I)
	before = _snapshot("Affordable numeric sword purchase")
	await _key(KEY_3)
	_expect(before,{"coins":25,"equipment":"青钢剑","attack":20},"Numeric3 retains the original45-coin4-attack purchase")
	await _key(KEY_4)
	_saved(app.state.to_dict(),"Numeric sword purchase persists on ordinary close")

func _martial() -> void:
	_section("martial")
	_new_game()
	await _key(KEY_K)
	_check(app.overlay.find_child("MartialInvitation",true,false)!=null and app.modal_actions.size()==2,"Unjoined school has base move plus invitation and return")
	await _key(KEY_2)
	_check(not app.active_modal,"Unjoined numeric2 returns")
	for school: Dictionary in SCHOOLS:
		_school_fixture(school.sect)
		app.state.sect_merit = 5
		_checkpoint()
		for learned: bool in [false,true]:
			if learned:
				_check(app.state.learn_art(school.arts[2]) and app.state.learn_art(school.arts[3]),"Prepared both advanced pages through real learning rules")
				_checkpoint()
			# Window sizes are physical. Control rectangles remain in the project's
			# 1280x800 logical canvas; these bounds are not visual acceptance.
			for dimensions: Vector2i in [Vector2i(1280,800),Vector2i(1180,737),Vector2i(960,600)]:
				root.size = dimensions
				await process_frame
				for uses: int in [0,4,5,14,15]:
					app.state.art_uses[school.arts[1]] = uses
					_checkpoint()
					var browse_before = _snapshot("Martial before browse %s/%s/%s/%s" % [school.sect,learned,dimensions,uses])
					await _key(KEY_K)
					await process_frame
					_expect(browse_before,{},"Martial browse preserves state/transients/save")
					var page = app.overlay.find_child("MartialFolio",true,false)
					if not _check(page != null,"Martial folio exists"): return
					_check(app.modal_actions.size()==(5 if learned else 3),"Owned moves alone receive numeric slots plus return")
					_check(page.find_child("EquippedArtTitle",true,false).text==app.state.equipped_art,"Equipped title equals model")
					var description = page.find_child("EquippedArtDescription",true,false)
					_check(description != null and description.position.x>=138 and description.position.x+description.size.x<=388 and description.get_minimum_size().y<=description.size.y,"Current left-column description fits its actual column and allocated height")
					for i: int in range(4):
						var id: String = school.arts[i]
						var card = page.find_child("ArtCard_"+id,true,false)
						if not _check(card != null,"Card exists: "+id): return
						_check(Rect2(Vector2.ZERO,page.size).encloses(card.get_rect()),"Card remains inside folio: "+id)
						for control in card.get_children():
							if control is Control: _check(Rect2(Vector2.ZERO,card.size).encloses(control.get_rect()),"Card control stays inside: "+id+"/"+str(control.name))
						for label in card.find_children("*","Label",true,false):
							_check(Rect2(Vector2.ZERO,label.get_parent().size).encloses(label.get_rect()),"Card label stays inside actual parent: "+id+"/"+str(label.name))
							_check(label.get_minimum_size().y<=label.size.y,"Card label has its required height: "+id+"/"+str(label.name))
						var rank = (3 if uses>=15 else 2 if uses>=5 else 1) if i==1 else 1
						var damage: int = app.state.attack*school.multipliers[i]+school.bonuses[i]+3*(rank-1)
						_check(card.find_child("ArtCost",true,false).text=="真气 %d  ·  调息 %d 回合" % [school.costs[i],school.cooldowns[i]],"Exact authored qi/cooldown: "+id)
						_check(card.find_child("ArtEffects",true,false).text.split(" · ")[0]=="基础伤害 %d" % damage,"Exact displayed damage including rank: "+id)
						if i<2 or learned:
							_check(card.find_child("ArtEquip",true,false).text=="修习 "+id,"Owned equip action remains reachable: "+id)
							var proficiency = card.find_child("ArtProficiency",true,false).text
							_check(proficiency.begins_with(["未习","初窥","熟习","通明"][rank]),"Proficiency boundary rank: "+id)
							if i==1: _check(proficiency.contains("已施展%d次" % uses),"Exact use count is presented")
						else:
							var locked = card.find_child("ArtLocked",true,false)
							if not _check(locked != null and locked.disabled,"Unowned page remains locked: "+id): return
							locked.pressed.emit()
					_expect(browse_before,{},"Even emitted locked button cannot grant/equip/spend")
					await _key(KEY_ESCAPE)
					_check(not app.active_modal,"Escape closes martial folio")
			# Check every original numeric equip entry for owned and learned cases.
			for i: int in range(4 if learned else 2):
				app.state.skill_cooldown = 2
				app.state.qi = 2
				_checkpoint()
				await _key(KEY_K)
				var equip_before = _snapshot("Before numeric equip")
				await _key(KEY_1+i)
				_expect(equip_before,{"equipped_art":school.arts[i]},"Numeric equip preserves qi/cooldown/stats","persisted")
				_check(not app.active_modal,"Numeric equip closes folio")
		await _key(KEY_K)
		var stale = _action(0)
		await _key(KEY_ESCAPE)
		await _key(KEY_K)
		var stale_before = _snapshot("Reopened martial folio")
		stale.call()
		_expect(stale_before,{},"Saved martial callback cannot affect a reopened folio")
		_check(app.active_modal,"Stale martial callback leaves current page open")
		await _key(KEY_5)
		_check(not app.active_modal,"Four owned moves retain numeric5 return")
	root.size = Vector2i(1280,800)
	await process_frame
	await _key(KEY_K)
	var pointer_before = _snapshot("Pointer base equip")
	await _click("修习 照夜一线")
	_expect(pointer_before,{"equipped_art":"照夜一线"},"Pointer equips base art through real control","persisted")
	_check(not app.active_modal,"Pointer equip closes folio")

func _workshop() -> void:
	_section("workshop")
	_new_game()
	app.state.gain_xp(180)
	app.state.coins = 300
	app.state.herbs = 2 # Quest herbs remain separate from recipe/trading herb.
	_check(app.state.buy_equipment(),"Prepared workshop owns legal45-coin sword")
	_checkpoint()
	var before = _snapshot("Before workshop")
	await _key(KEY_B)
	_expect(before,{},"B opens workshop without mutation")
	_check(app.overlay.find_child("WorkshopFolio",true,false)!=null and app.modal_actions.size()==5,"Workshop retains recipe1-3, market4, fitting5")
	var stale_craft = _action(2)
	await _key(KEY_4)
	_expect(before,{},"Numeric4 browses market without mutation")
	await _click("买入材料")
	_expect(before,{},"Pointer browses stock without mutation")
	var stale_buy = _action(0)
	for count: int in [1,2,3]:
		before = _snapshot("Before iron purchase "+str(count))
		await _key(KEY_1)
		var iron_resources: Dictionary = before.state.resources.duplicate(true)
		iron_resources.iron += 1
		_expect(before,{"coins":before.state.coins-8,"resources":iron_resources},"Current numeric iron purchase consumes8 for one unit","persisted")
	before = _snapshot("Repeated legal iron purchases")
	stale_buy.call()
	_expect(before,{},"Saved trade callback cannot repeat after page refresh even when affordable")
	await _click("木料 5文")
	var resources: Dictionary = before.state.resources.duplicate(true)
	resources.timber += 1
	_expect(before,{"coins":before.state.coins-5,"resources":resources},"Pointer timber purchase consumes5 for one unit","persisted")
	before = _snapshot("Materials collected")
	await _key(KEY_5)
	_expect(before,{},"Stock numeric5 returns to market without mutation")
	_check(_button("返回工艺")!=null,"Stock numeric5 opens correct market return")
	await _key(KEY_3)
	_expect(before,{},"Market numeric3 returns to craft without mutation")
	before = _snapshot("Before sword crafting")
	var stale_blade = _action(0)
	await _click("精锻青钢剑")
	resources = before.state.resources.duplicate(true)
	resources.iron -= 3
	resources.timber -= 1
	_expect(before,{"coins":before.state.coins-25,"resources":resources,"equipment":"精锻青钢剑","attack":before.state.attack+5},"Sword recipe consumes3 iron1 timber25 coins for5 attack","persisted")
	before = _snapshot("Crafted blade")
	stale_blade.call()
	await _key(KEY_1)
	_expect(before,{},"Old and current duplicate blade requests cannot duplicate bonus or charges")
	await _key(KEY_ESCAPE)
	_saved(app.state.to_dict(),"Workshop ordinary close remains saved")
	var canonical: Dictionary = app.state.to_dict().duplicate(true)
	var saved_bytes = _disk()
	app.state.coins -= 1
	_check(app.state.to_dict()!=canonical and _disk()==saved_bytes,"Workshop reload sentinel changes only memory, preserving saved checkpoint")
	app._load()
	_check(app.state.to_dict()==canonical,"Main reload preserves actual crafting result")
	app.state.resources.cloth = 3
	app.state.resources.herb = 5
	_checkpoint()
	await _key(KEY_B)
	before = _snapshot("Reopened workshop with valid medicine materials")
	stale_craft.call()
	_expect(before,{},"Old pre-close medicine callback stays invalid even with valid materials")
	var stale_medicine = _action(2)
	await _click("轻纱内甲")
	resources = before.state.resources.duplicate(true)
	resources.cloth -= 3
	resources.herb -= 1
	_expect(before,{"coins":before.state.coins-18,"resources":resources,"armor":"轻纱内甲","defense":before.state.defense+3,"max_hp":before.state.max_hp+10,"hp":before.state.hp+10},"Armor consumes3 cloth1 herb18 coins for3 defense10 health","persisted")
	before = _snapshot("Crafted armor, medicine still valid")
	stale_medicine.call()
	_expect(before,{},"Pre-refresh medicine callback cannot craft despite valid resources")
	await _key(KEY_2)
	_expect(before,{},"Already-owned armor is not crafted twice")
	for count: int in [1,2]:
		before = _snapshot("Before repeatable medicine "+str(count))
		await _key(KEY_3)
		resources = before.state.resources.duplicate(true)
		resources.herb -= 2
		_expect(before,{"coins":before.state.coins-4,"resources":resources,"medicine":before.state.medicine+1},"Each current medicine action consumes2 herbs4 coins","persisted")
	before = _snapshot("Exhausted recipe materials")
	await _key(KEY_3)
	_expect(before,{},"Insufficient herb recipe cannot charge or award")
	await _key(KEY_4)
	await _key(KEY_2)
	_expect(before,{},"Browse selling remains read-only")
	await _click("铁矿 4文")
	_expect(before,{},"Selling absent iron cannot award coins")
	_check(app.state.herbs==2,"Quest herbs survive all actual purchases/crafts/failed sales")
	await _key(KEY_ESCAPE)
	await _key(KEY_I)
	_check(_texts(app.overlay).contains("精锻青钢剑") and _texts(app.overlay).contains("轻纱内甲"),"Inventory reflects both real crafted items")
	await _key(KEY_ESCAPE)
	# Trade caps are presentation branches that must still use model rejection.
	app.state.resources.iron = 9999
	app.state.coins = 8
	_checkpoint()
	await _key(KEY_B)
	await _key(KEY_4)
	await _key(KEY_1)
	before = _snapshot("Material cap")
	await _key(KEY_1)
	_expect(before,{},"9999-unit buy cap leaves all state/save bytes unchanged")
	_check(_texts(app.overlay).contains("行囊已满"),"Trade displays actual capacity reason")
	await _key(KEY_ESCAPE)
	app.state.resources.iron = 1
	app.state.coins = 999999
	_checkpoint()
	await _key(KEY_B)
	await _key(KEY_4)
	await _key(KEY_2)
	before = _snapshot("Coin cap")
	await _key(KEY_1)
	_expect(before,{},"Coin-cap sale cannot consume material")
	_check(_texts(app.overlay).contains("铜钱将超上限"),"Trade displays actual coin-cap reason")
	await _key(KEY_ESCAPE)

func _cultivation() -> void:
	_section("cultivation")
	for school: Dictionary in SCHOOLS:
		_school_fixture(school.sect,true)
		var cheap: String = school.arts[2]
		var costly: String = school.arts[3]
		var original: String = app.state.equipped_art
		_check(app.state.sect_merit==3 and app.state.available_arts().size()==2,"Prepared inner disciple owns only base and school moves")
		app.world.teleport(Vector2(650,720))
		app.state.position = app.world.player_pos
		app._process(0.0)
		_checkpoint()
		var before = _snapshot("Before nearby mentor")
		await _key(KEY_E)
		if not _check(_button("研习藏页")!=null,"Queued nearby mentor interaction exposes learning service"): return
		_expect(before,{},"Mentor opens without mutation")
		await _key(KEY_1)
		_expect(before,{},"Learning overview is read-only")
		_check(app.overlay.find_child("CultivationFolio",true,false)!=null and _texts(app.overlay).contains(cheap) and _texts(app.overlay).contains(costly),"Current cultivation presents both authored pages")
		var old_detail = _action(0)
		await _key(KEY_1)
		_expect(before,{},"Opening cheap detail is not purchasing")
		_check(_texts(app.overlay).contains("2 考绩") and _button("研习 · 2考绩")!=null,"Detail discloses2-merit learning cost")
		var canceled_learn = _action(0)
		await _key(KEY_ESCAPE)
		_check(not app.active_modal,"Escape cancels detail without purchase")
		_expect(before,{},"Ordinary cultivation cancel preserves canonical state and saves by existing close policy","persisted")
		app.advanced_martial.learning()
		await process_frame
		before = _snapshot("Reopened cultivation overview")
		canceled_learn.call()
		old_detail.call()
		_expect(before,{},"Canceled learning and stale detail callbacks cannot affect reopened overview")
		_check(app.overlay.find_child("CultivationFolio",true,false).get_meta("cultivation_page")=="learning","Stale detail callback cannot navigate newer generation")
		await _key(KEY_1)
		before = _snapshot("Before2-merit purchase")
		var stale_learn = _action(0)
		await _key(KEY_ENTER)
		_expect(before,{"learned_arts":[cheap],"sect_merit":1},"Enter learns cheap page for exactly2 without autoequip","persisted")
		_check(app.state.equipped_art==original,"First learned page preserves equipped art")
		before = _snapshot("Cheap page learned")
		stale_learn.call()
		app.advanced_martial.learn(cheap)
		_expect(before,{},"Saved UI callback and current model-backed duplicate cannot charge twice")
		await _key(KEY_2)
		_expect(before,{},"Costly detail browse does not purchase")
		_check(_texts(app.overlay).contains("3 考绩") and _button("研习 · 3考绩")!=null,"Costly detail discloses3-merit requirement")
		var unaffordable_learn = _action(0)
		await _key(KEY_ENTER)
		_expect(before,{},"Insufficient1-merit attempt for3-merit page is atomic")
		await _key(KEY_ESCAPE)
		var reload_expected: Dictionary = app.state.to_dict().duplicate(true)
		var reload_bytes = _disk()
		app.state.coins -= 1
		_check(app.state.to_dict()!=reload_expected and _disk()==reload_bytes,"Cultivation reload sentinel changes only memory")
		app._load()
		_check(app.state.to_dict()==reload_expected and app.state.learned_arts==[cheap] and app.state.sect_merit==1,"Escape/Main reload restores exact saved state, learned page, and balance")
		if not _check(app.state.eligible_sect_deeds()==["sluice","archive"],"Reloaded prepared stories are eligible for both original deed rewards"): return
		app._interact("mentor")
		await _click("江湖复命")
		var deeds_page = app.overlay.find_child("CultivationFolio",true,false)
		if not _check(deeds_page!=null and deeds_page.get_meta("cultivation_page","")=="deeds","Mentor pointer opens actual deeds page before any reward action"): return
		_check(_texts(app.overlay).contains("可领取1考绩"),"Completed stories expose one-point deed claims")
		before = _snapshot("Before first deed")
		var stale_deed = _action(0)
		await _click("复命·废闸水令查证")
		_expect(before,{"claimed_deeds":["sluice"],"sect_merit":2},"Sluice deed grants exactly1 once","persisted")
		before = _snapshot("Before second deed")
		stale_deed.call()
		app.advanced_martial.claim("sluice")
		_expect(before,{},"Old and direct duplicate first-deed requests are inert")
		await _click("复命·霜桥原账归处")
		_expect(before,{"claimed_deeds":["sluice","archive"],"sect_merit":3},"Archive deed grants exactly1 once","persisted")
		before = _snapshot("Both deeds claimed")
		app.advanced_martial.claim("archive")
		_expect(before,{},"Second-deed duplicate cannot grant again")
		_check(app.modal_actions.size()==1,"Claimed deeds disappear from actionable choices")
		await _click("返回藏页")
		unaffordable_learn.call()
		_expect(before,{},"Earlier insufficient callback stays invalid after balance becomes affordable")
		await _key(KEY_2)
		before = _snapshot("Before3-merit purchase")
		await _click("研习 · 3考绩")
		_expect(before,{"learned_arts":[cheap,costly],"sect_merit":0},"Pointer learns costly page for exactly3 without autoequip","persisted")
		_check(app.state.equipped_art==original,"Second learned page also preserves equipped art")
		before = _snapshot("Both pages learned")
		await _key(KEY_1)
		_check(_button("前往武学")!=null and _button("研习 · 2考绩")==null,"Owned detail offers navigation, not another charge")
		_expect(before,{},"Owned-page detail browsing remains read-only")
		await _click("前往武学")
		_expect(before,{},"Owned-detail pointer callback opens martial without mutation")
		_check(app.overlay.find_child("MartialFolio",true,false)!=null and app.overlay.find_child("CultivationFolio",true,false)==null,"Owned-detail navigation replaces cultivation with actual martial folio")
		_check(app.modal_actions.size()==5,"Both advanced pages fill four equip slots plus return")
		before = _snapshot("Advanced numeric equip")
		await _key(KEY_4)
		_expect(before,{"equipped_art":costly},"Numeric4 explicitly equips costly page","persisted")

func _failed_save_retry() -> void:
	_section("real_save_failure_retry")
	_school_fixture("听潮阁")
	var cheap = "束潮削势"
	app.advanced_martial.learning()
	await _key(KEY_1)
	var before = _snapshot("Checkpoint before real filesystem failure")
	var temporary = owned_user.path_join("hero_save.json.tmp")
	if not _check(_no_links(owned_user) and ProjectSettings.globalize_path(SAVE_PATH+".tmp")==temporary,"Failure target is exactly the owned userdata temporary save path"): return
	if not _check(not FileAccess.file_exists(temporary) and not DirAccess.dir_exists_absolute(temporary),"Failure fixture never replaces any existing path"): return
	# A new empty directory at the temporary filename makes FileAccess.WRITE fail
	# even under elevated Unix users. No subclass, permissions change, or host path.
	if not _check(DirAccess.make_dir_absolute(temporary)==OK,"Create owned empty-directory collision for genuine save failure"): return
	collision_owned = true
	var stale_learn = _action(0)
	await _key(KEY_ENTER)
	_expect(before,{"learned_arts":[cheap],"sect_merit":1},"Failed write retains exactly one in-memory purchase and old save bytes")
	_check(app.save_warning and app.status_label.text.contains("存档失败"),"Success toast retains actual save-failure warning")
	var after_failure = _snapshot("After failed automatic save")
	stale_learn.call()
	app.advanced_martial.learn(cheap)
	_expect(after_failure,{},"Duplicate learning after write failure does not retry purchase")
	await _key(KEY_ESCAPE)
	_expect(after_failure,{},"Ordinary close attempts save and leaves old bytes when failure persists")
	_check(app.save_warning,"Failed close retains warning")
	if not _remove_collision(): return
	await _key(KEY_F5)
	_expect(after_failure,{},"F5 retries persistence without recharging or relearning","persisted")
	_check(not app.save_warning,"Successful retry clears warning")
	var expected: Dictionary = app.state.to_dict().duplicate(true)
	var retry_bytes = _disk()
	app.state.coins -= 1
	_check(app.state.to_dict()!=expected and _disk()==retry_bytes,"F9 retry sentinel changes only memory after successful F5 save")
	await _key(KEY_F9)
	_check(app.state.to_dict()==expected and app.state.learned_arts==[cheap] and app.state.sect_merit==1,"Main F9 reload recovers exactly the once-purchased page")
	_saved(expected,"Post-retry Main reload")

func _battle_gate() -> void:
	_section("battle_gate")
	_school_fixture("听潮阁",true)
	app.state.coins = 200
	app.state.hp = 50
	app.state.resources.herb = 4
	_checkpoint()
	await _key(KEY_I)
	var inventory_action = _action(0)
	await _key(KEY_ESCAPE)
	await _key(KEY_K)
	var equip_action = _action(1)
	await _key(KEY_ESCAPE)
	await _key(KEY_B)
	var craft_action = _action(2)
	await _key(KEY_ESCAPE)
	app.advanced_martial.learning()
	await _key(KEY_1)
	var learn_action = _action(0)
	await _key(KEY_ESCAPE)
	var controller = battle_driver.open_training(app)
	if not _check(app.current_screen=="party_battle" and app.state.battle_active and battle_driver.active(app),"Genuine unified training controller entered"): return
	# Freeze its documented test-driver scheduler, not HeroState or save behavior.
	var before = _snapshot("Active unified battle")
	var generation: int = app.modal_generation
	for code: int in [KEY_I,KEY_K,KEY_B]: await _key(code)
	app._show_inventory()
	app._show_martials()
	app._show_workshop()
	app.advanced_martial.learning()
	app.advanced_martial.detail("束潮削势")
	app.advanced_martial.deeds()
	inventory_action.call()
	equip_action.call()
	craft_action.call()
	learn_action.call()
	app.advanced_martial.learn("束潮削势")
	app.advanced_martial.claim("sluice")
	_expect(before,{},"Battle rejects folio shortcuts/direct opens/stale callbacks/learning/deeds")
	_check(app.current_screen=="party_battle" and app.overlay.get_meta("party_battle")==controller and app.modal_generation==generation,"Battle controller and modal generation remain intact")
	_check(controller.pending.is_empty(),"Blocked folio input queues no combat transaction")
	battle_driver.leave(app)
	_check(not app.state.battle_active and app.current_screen=="explore","Real controller retreat settles back into exploration")
	if app.active_modal: await _key(KEY_ESCAPE)
	await _key(KEY_I)
	_check(app.overlay.get_meta("inventory",false),"Inventory remains usable after real battle exit")
	await _key(KEY_ESCAPE)
	_saved(app.state.to_dict(),"Post-battle close saves valid checkpoint")

func _remove_collision() -> bool:
	if not collision_owned: return true
	var temporary = owned_user.path_join("hero_save.json.tmp")
	var directory = DirAccess.open(temporary)
	if not _check(_no_links(temporary) and directory!=null,"Owned collision remains a nonsymlink directory"): return false
	directory.include_hidden = true
	if not _check(directory.get_files().is_empty() and directory.get_directories().is_empty(),"Owned collision remains empty before removal"): return false
	if not _check(DirAccess.remove_absolute(temporary)==OK,"Remove only this run's empty temporary-path collision"): return false
	collision_owned = false
	return true

func _finish() -> void:
	if finished: return
	finished = true
	if collision_owned:
		_remove_collision()
	if is_instance_valid(app):
		app._stop_audio()
		app.free()
	if guard_passed:
		var report = {"suite":"current_folio_behavior_new_validation", "historical_evidence_recreated":false,
			"checks":checks,"failures":failures,"sections":sections,"checkpoints":checkpoints,
			"status":"pass" if failures.is_empty() else "fail", "user_dir":owned_user,
			"limits":["Prepared legal fixtures; does not establish full story journey earning", "No native screenshot or pixel/contrast certification", "Does not replace unavailable historical tests or evidence", "Save byte equality establishes unchanged content, not a syscall write count"]}
		var file = FileAccess.open(report_path,FileAccess.WRITE)
		if file == null:
			push_error("ERROR: caller-specified report could not be written")
			quit(2); return
		file.store_string(JSON.stringify(report,"\t"))
		file.flush()
		var write_error = file.get_error()
		file.close()
		if write_error != OK:
			push_error("ERROR: report write failed")
			quit(2); return
	if failures.is_empty(): print("PASS: NEW current folio behavior validation, %d checks" % checks)
	else: push_error("ERROR: NEW current folio behavior validation failed, %d failures / %d checks" % [failures.size(),checks])
	quit(0 if failures.is_empty() else 1)
