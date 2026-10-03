extends SceneTree
## Focused synthetic state invariants. Schema migration and actual old readers
## have separate tests; scene confirmation/proximity and balance are not claimed.
const State = preload("res://scripts/game_state.gd")
const Fittings = preload("res://scripts/weapon_fitting_rules.gd")
const Courtyard = preload("res://scripts/courtyard_exercise_rules.gd")
const Receipt = preload("res://scripts/heting_receipt_combat.gd")
const Advanced = preload("res://scripts/advanced_martial_rules.gd")
var checks: int = 0
var failures: int = 0
var fixture_root: String

class SaveProbe extends State:
	var writes: int = 0
	func save_game(path: String = SAVE_PATH) -> Error:
		writes += 1
		return super.save_game(path)

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)

func _ready_state(sect: String = "听潮阁"):
	var s := SaveProbe.new()
	s.quest_stage = 6; s.ending = "守望"; s.choose_sect(sect)
	s.hp = 17; s.qi = 1; s.medicine = 2; s.coins = 173
	return s

func _all_variables(s) -> Dictionary:
	var result: Dictionary = {}
	for property: Dictionary in s.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = s.get(property.name)
			result[property.name] = value.duplicate(true) if value is Dictionary or value is Array else value
	return result

func _init() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): quit(2); return
	fixture_root = "user://weapon-fitting-state-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(fixture_root) == OK, "Isolated test storage")
	_test_selection_and_resources()
	_test_rejections()
	_test_base_growth()
	_test_read_consumers()
	_test_roundtrip_and_failed_save()
	if failures == 0: print("PASS: %d fitting explicit-state/enum-only/no-save/no-drift/resources/growth/read-consumer/persistence checks" % checks)
	quit(0 if failures == 0 else 1)

func _test_selection_and_resources() -> void:
	for sect: String in State.SECTS:
		var s = _ready_state(sect)
		check(s.recruit_companion(), "Actual Shen invitation")
		s.party_resources.shen = {"hp": 0, "qi": 0}
		check(s.set_party_roster(["hero"]), "Benched downed companion")
		var original: Dictionary = s.to_dict()
		var actor_before: Dictionary = s.party_resource_snapshot().actors[1]
		for loop: int in range(8):
			for fitting: String in ["edge", "guard", "plain"]:
				var before: Dictionary = _all_variables(s)
				var preview: Dictionary = s.preview_weapon_fitting(fitting)
				check(preview.ok and _all_variables(s) == before, "Preview is wholly read-only")
				var result: Dictionary = s.set_weapon_fitting(fitting)
				check(result.ok and result.changed and s.weapon_fitting == fitting, "Explicit valid selection")
				var after: Dictionary = _all_variables(s); after.weapon_fitting = before.weapon_fitting
				check(after == before, "Setter changes exactly one enum, including all transient variables")
				check(s.party_resource_snapshot().actors[1] == actor_before, "Fitting cannot heal, alter or enroll a downed benched companion")
				check(s.effective_attack() == s.attack + Fittings.DELTAS[fitting].x and s.effective_defense() == s.defense + Fittings.DELTAS[fitting].y, "Effective stats apply once to bases")
				before = _all_variables(s)
				result = s.set_weapon_fitting(fitting)
				check(result.ok and not result.changed and _all_variables(s) == before and s.writes == 0, "Duplicate selection is no-op and never saves")
		check(s.to_dict() == original, "Repeated original-edge-guard-original has no drift")
		check(s.set_weapon_fitting("edge").ok, "Installed choice for detached clone")
		var detached = s._detached_persistent_state()
		check(detached.set_weapon_fitting("guard").ok and s.weapon_fitting == "edge", "Detached choice cannot leak to live state")
		s.reset_game()
		check(s.weapon_fitting == "plain" and s.effective_attack() == 16 and s.effective_defense() == 4, "New journey resets to original")

func _test_rejections() -> void:
	for candidate: Variant in [null, 0, true, {}, [], "", "unknown"]:
		var s = _ready_state(); var before: Dictionary = _all_variables(s)
		check(not s.set_weapon_fitting(candidate).ok and _all_variables(s) == before, "Malformed handler input cannot mutate")
	for stage: int in range(6):
		var s = _ready_state(); s.quest_stage = stage
		var before: Dictionary = _all_variables(s)
		check(not s.set_weapon_fitting("edge").ok and _all_variables(s) == before, "No bypass before actual opening completion")
	for sect: String in ["未入门", "unknown"]:
		var s = State.new(); s.quest_stage = 6; s.sect = sect
		var before: Dictionary = s.to_dict()
		check(not s.set_weapon_fitting("guard").ok and s.to_dict() == before, "Stage6 alone never fabricates valid sect")
	for setting: Dictionary in [{"attack": 3, "defense": 4, "fitting": "guard"}, {"attack": 16, "defense": 1, "fitting": "edge"}]:
		var s = _ready_state(); s.attack = setting.attack; s.defense = setting.defense
		var before: Dictionary = s.to_dict()
		check(not s.preview_weapon_fitting(setting.fitting).ok and not s.set_weapon_fitting(setting.fitting).ok and s.to_dict() == before, "Floor cost rejects preview and explicit setter without clamp")
		check(s.set_weapon_fitting("plain").ok, "Original remains valid at low bases")
	var s = _ready_state(); s.attack = 999; s.defense = 999
	check(s.set_weapon_fitting("edge").ok and s.effective_attack() == 1002 and s.attack == 999, "Max-base attack selection remains canonical")
	check(s.set_weapon_fitting("guard").ok and s.effective_defense() == 1001 and s.defense == 999, "Max-base defense selection remains canonical")
	check(s._stage_save_data(s.to_dict(), State.SAVE_VERSION).ok, "Derived over999 never pollutes canonical bases")
	s = _ready_state(); s.battle_active = true
	var before: Dictionary = _all_variables(s)
	check(not s.set_weapon_fitting("edge").ok and _all_variables(s) == before, "Active battle blocks explicit setter")
	s.battle_active = false; s.party_session = RefCounted.new(); s._party_pending_token = 19
	before = _all_variables(s)
	check(not s.set_weapon_fitting("edge").ok and _all_variables(s) == before, "Pending presentation blocks setter even without active combat")
	s.party_session = null
	before = _all_variables(s)
	check(not s.set_weapon_fitting("edge").ok and _all_variables(s) == before, "Stale pending token without session still blocks setter")

	s = _ready_state(); s.attack = 1; s.weapon_fitting = "guard"
	before = _all_variables(s)
	check(not s.fitting_projection().ok and not State.PartyCatalog.build_team(s, ["hero"]).ok, "Invalid installed fitting rejects instead of becoming silently inactive")
	check(not Courtyard.new().configure(s) and not Receipt.new().configure(s), "Retained adapters reject invalid installed fitting")
	check(not s._stage_save_data(s.to_dict(), State.SAVE_VERSION).ok and _all_variables(s) == before, "Malformed installed fitting cannot save or silently downgrade")
	s = _ready_state(); s.party_roster.append("unknown")
	before = _all_variables(s)
	check(not s.set_weapon_fitting("edge").ok and _all_variables(s) == before, "Whole-state invalidity cannot be normalized away by fitting transaction")

func _test_base_growth() -> void:
	var s = _ready_state(); check(s.set_weapon_fitting("edge").ok, "Growth setup")
	var attack: int = s.attack; var defense: int = s.defense
	check(s.buy_equipment() and s.attack == attack + 4 and s.effective_attack() == attack + 7, "Original sword purchase still writes base+4 only")
	s.gain_xp(180)
	check(s.level == 3 and s.attack == attack + 10 and s.defense == defense + 2 and s.effective_attack() == attack + 13, "Existing level growth remains base-only with one projection")
	s.resources.iron = 3; s.resources.timber = 1
	check(s.craft("refined_blade").valid and s.attack == attack + 15 and s.effective_attack() == attack + 18, "Original forge adds exactly base+5")
	var before: Dictionary = s.to_dict()
	check(s.set_weapon_fitting("plain").ok and s.attack == attack + 15 and s.defense == defense + 2, "Revert never reverses real purchase/forge/growth")
	before.weapon_fitting = "plain"
	check(s.to_dict() == before, "Revert only enum after upgrades")

func _test_read_consumers() -> void:
	for fitting: String in Fittings.IDS:
		var s = _ready_state(); check(s.set_weapon_fitting(fitting).ok, "Read consumer setup")
		var power: int = s.attack + Fittings.DELTAS[fitting].x; var protection: int = s.defense + Fittings.DELTAS[fitting].y
		var actor: Dictionary = State.PartyCatalog.build_team(s, ["hero"]).team.actors[0]
		check(actor.attack == power and actor.defense == protection and actor.equipment == s.equipment, "Actor catalog effective combat stats preserve sword identity")
		var before: Dictionary = _all_variables(s)
		var courtyard := Courtyard.new(); var receipt := Receipt.new()
		check(courtyard.configure(s) and courtyard.attack == power and courtyard.defense == protection, "Retained courtyard direct adapter uses projection")
		check(receipt.configure(s) and receipt.attack == power and receipt.defense == protection, "Retained receipt direct adapter uses projection")
		check(_all_variables(s) == before, "Both detached adapters leave source wholly unchanged")
		check(s.art_description(State.Arts.BASE_ART).contains("造成 %d 点伤害" % (2 * power + 8)), "Description damage agrees with effective attack")
		var messages: Array[String] = []
		Advanced.apply_effects(s, State.Arts.definition("伏汐藏锋"), messages)
		check(s.focused_damage == power + 18, "Legacy focus uses projected power")
		s.start_battle("spar"); s.hp = s.max_hp; s.enemy_hp = 1000; s.enemy_max_hp = 1000
		var old_hp: int = s.hp
		s.battle_action("attack")
		check(s.enemy_hp == 1000 - power, "Legacy basic attack uses projection")
		check(old_hp - s.hp == maxi(1, 9 - protection), "Legacy incoming damage uses projected defense and unchanged floor")
		s.battle_action("flee")

func _test_roundtrip_and_failed_save() -> void:
	var s = _ready_state()
	var primary: String = fixture_root.path_join("primary.json")
	var manual: String = fixture_root.path_join("manual.json")
	var backup: String = fixture_root.path_join("manual.json.bak")
	check(s.save_game(primary) == OK and s.save_game(manual) == OK and s.save_game(backup) == OK, "Create isolated original-primary/manual/backup controls")
	var bytes: Dictionary = {}
	for path: String in [primary, manual, backup]: bytes[path] = FileAccess.get_file_as_bytes(path)
	var writes: int = s.writes
	for fitting: String in ["edge", "guard", "plain", "edge"]:
		check(s.preview_weapon_fitting(fitting).ok and s.set_weapon_fitting(fitting).ok and s.writes == writes, "Preview/equip/revert never implicitly save")
		for path: String in bytes: check(FileAccess.get_file_as_bytes(path) == bytes[path], "All preexisting primary/manual/backup bytes unchanged")
	var before: Dictionary = s.to_dict()
	var blocked: String = fixture_root.path_join("blocked-save-target")
	check(DirAccess.make_dir_recursive_absolute(blocked) == OK, "Deterministic rename-failure directory")
	check(s.save_game(blocked) != OK and s.to_dict() == before and s.weapon_fitting == "edge", "Failed explicit save retains selected in-memory fitting without replay")
	for path: String in bytes: check(FileAccess.get_file_as_bytes(path) == bytes[path], "Save failure preserves old controls")
	check(s.save_game(primary) == OK, "Explicit save retry writes current selected state")
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(primary))
	check(document.version == 16 and document.player.weapon_fitting == "edge" and document.player.attack == s.attack and document.player.defense == s.defense, "Writer16 stores enum and unchanged bases only")
	check(not FileAccess.file_exists(primary + ".bak"), "No automatic-backup subsystem added")
	var loaded := State.new()
	check(loaded.load_game(primary) == OK and loaded.to_dict() == s.to_dict(), "Selected fitting roundtrips without stat reapplication")
	check(loaded.effective_attack() == s.attack + 3 and loaded.effective_defense() == s.defense - 2, "Post-load projection is once-only")
