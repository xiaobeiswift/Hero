extends SceneTree
## Synthetic model/native filesystem gates only, not earned gameplay or scene
## proximity. Frozen old readers use CURRENT dependencies; full old-runtime
## rejection is a separate optional process with the retained old Web28 PCK.
const State = preload("res://scripts/game_state.gd")
const Quest = preload("res://scripts/volume_one_capstone_rules.gd")
const Slots = preload("res://scripts/local_save_slots.gd")
const Transfer = preload("res://scripts/local_save_transfer.gd")
const FIXTURES = "res://tests/fixtures/legacy_saves/"
const OLD_READER = "res://tests/fixtures/v028_game_state.gd.txt"
const OLD_SHA = "160fe884cd9e80966cf94493020cb2a9454957e54bc7c0def72754bc95e03fd5"
var checks: int = 0
var failures: int = 0
var fixture_root: String
var old_script: GDScript

func _init() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): quit(2); return
	fixture_root = "user://capstone-schema-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(fixture_root) == OK, "Isolated synthetic filesystem")
	check(ProjectSettings.get_setting("hero/features/web_save_transfer_enabled", false) == false, "Raw save transfer remains default-off")
	var source := _bytes(OLD_READER)
	check(source.size() == 72931 and _hash(source) == OLD_SHA, "Byte-exact real Web28 reader is pinned")
	old_script = GDScript.new(); old_script.source_code = source.get_string_from_utf8().replace("class_name HeroState\n", "")
	check(old_script.reload() == OK, "Real old14 source compiles with current dependencies and only class-name removal")
	_test_legacy()
	_test_rejections()
	_test_roundtrips_and_transfer()
	_test_old_reader_gate()
	_remove_tree(fixture_root)
	if failures == 0: print("PASS: %d schema15 legacy1–14/bundle/strictness/slots/transfer/authentic-old14-source-reader checks; current dependencies; genuine producers1,9–14 and authored contracts2–8; no scene/browser claim" % checks)
	quit(0 if failures == 0 else 1)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _bytes(path: String) -> PackedByteArray: return FileAccess.get_file_as_bytes(path)
func _hash(bytes: PackedByteArray) -> String:
	var h := HashingContext.new(); h.start(HashingContext.HASH_SHA256); h.update(bytes); return h.finish().hex_encode()
func _document(data: Dictionary, version: Variant = 15) -> PackedByteArray:
	return JSON.stringify({"version": version, "player": data}, "\t").to_utf8_buffer()
func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE); check(file != null, "Open isolated fixture")
	if file != null: file.store_buffer(bytes); file.close()

func _test_legacy() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + "provenance.json"))
	var live := State.new(); live.coins = 913; live.skill_cooldown = 4
	var fixtures: Array = []
	for item: Dictionary in manifest.fixtures:
		var bytes := _bytes("res://" + item.path)
		check(_hash(bytes) == item.sha256, "Pinned old fixture schema%d" % item.version)
		if item.has("source"):
			check(_hash(_bytes("res://" + item.source)) == item.source_sha256, "Genuine producer pin")
			var script := GDScript.new(); script.source_code = FileAccess.get_file_as_string("res://" + item.source).replace("class_name HeroState\n", "")
			check(script.reload() == OK, "Genuine old producer compiles with current dependencies")
			var producer = script.new(); var doc: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
			check(producer.SAVE_VERSION == item.version and live._same_save_value(producer.to_dict(), doc.player), "Fixture exactly matches genuine historical serializer")
		fixtures.append({"version": item.version, "bytes": bytes})
	var old = old_script.new()
	check(old.SAVE_VERSION == 14 and not old.to_dict().has("capstone_stage"), "True14 producer identity")
	fixtures.append({"version": 14, "bytes": _document(old.to_dict(), old.SAVE_VERSION)})
	for item: Dictionary in fixtures:
		var before: Dictionary = live.to_dict(); var inspected := live.inspect_save_bytes(item.bytes)
		check(inspected.ok and inspected.version == item.version, "Every old1–14 format accepted:%d" % item.version)
		check(live.to_dict() == before and live.skill_cooldown == 4, "Inspection leaves live state/transient fields unchanged")
		if inspected.ok:
			for key: String in Quest.FIELDS: check(inspected.state.to_dict()[key] == State.new().to_dict()[key], "Absent capstone defaults neutral:" + key)
			check(inspected.state.hp == 100 and inspected.state.qi == 2 and inspected.state.medicine == 3 and inspected.state.coins == 24, "Legacy default migration gives no recovery or reward")
			var path := fixture_root + "/migrate%d.json" % item.version
			check(inspected.state.save_game(path) == OK and JSON.parse_string(_bytes(path).get_string_from_utf8()).version == 15, "Explicit save writes15")
		var payload: Dictionary = JSON.parse_string(item.bytes.get_string_from_utf8()).player
		for mask: int in range(1, 7):
			var partial := payload.duplicate(true)
			for index: int in range(3):
				if mask & (1 << index): partial[Quest.FIELDS[index]] = State.new().to_dict()[Quest.FIELDS[index]]
			check(not live.inspect_save_bytes(_document(partial, item.version)).ok, "Partial 3-field bundle rejects at legacy%d mask%d" % [item.version, mask])
		var present := payload.duplicate(true)
		for key: String in Quest.FIELDS: present[key] = State.new().to_dict()[key]
		check(live.inspect_save_bytes(_document(present, item.version)).ok, "Complete neutral bundle validated on legacy%d" % item.version)
		present.capstone_stage = 0.5
		check(not live.inspect_save_bytes(_document(present, item.version)).ok, "Malformed present legacy bundle never ignored")
	# Real schema14 serializer, synthetic progressed/wounded state. No historical
	# gameplay claim. All old fields survive migration exactly, including HP0 bench.
	var progressed = _ready()
	progressed.capstone_stage = 0
	for key: String in old.to_dict():
		var value = progressed.get(key)
		if value is Array: old.get(key).assign(value)
		else: old.set(key, value.duplicate(true) if value is Dictionary else value)
	var original: Dictionary = old.to_dict(); var migrated := live.inspect_save_bytes(_document(original, 14))
	check(migrated.ok, "Authentic old14 serializer with completed consignee and injuries migrates")
	if migrated.ok:
		var converted: Dictionary = migrated.state.to_dict()
		for key: String in Quest.FIELDS: converted.erase(key)
		check(live._same_save_value(converted, original), "All old stories/resources/roster preserved exactly")
		check(migrated.state.party_resources.shen.hp == 0 and migrated.state.hp == 73 and migrated.state.qi == 1, "No load-time revival or refill")
		var changed: Dictionary = Quest.progress(migrated.state)
		changed.consignee_observations.clear()
		check(migrated.state.consignee_observations.size() == 3, "Progress returns detached array copies")

func _test_rejections() -> void:
	var live := State.new(); live.coins = 777; live.skill_cooldown = 3
	var before: Dictionary = live.to_dict(); var good := State.new().to_dict()
	check(State.SAVE_VERSION == 15 and State.PartyRoster.PAYLOAD_VERSION == 15, "Whole-state and roster accept up to15")
	check(State.Consignee.INTRODUCED_VERSION == 14 and State.Consignee.MAX_SAVE_VERSION == 15, "Consignee introduction remains14, support ceiling15")
	for version: int in [14, 15]:
		var canonical: Dictionary = old_script.new().to_dict() if version == 14 else good
		for key: String in canonical:
			var missing := canonical.duplicate(true); missing.erase(key)
			check(not live.inspect_save_bytes(_document(missing, version)).ok, "All canonical%d fields mandatory:%s" % [version, key])
		var no_consignee := canonical.duplicate(true)
		for key: String in State.Consignee.FIELDS: no_consignee.erase(key)
		check(not live.inspect_save_bytes(_document(no_consignee, version)).ok, "Entire consignee bundle required since14 even under15 ceiling")
	var legacy13: Dictionary = JSON.parse_string(_bytes(FIXTURES + "schema_13_default.json").get_string_from_utf8()).player
	for key: String in legacy13:
		var missing := legacy13.duplicate(true); missing.erase(key)
		check(not live.inspect_save_bytes(_document(missing, 13)).ok, "Legacy13 old fields still mandatory:" + key)
	for version: int in [12, 13, 14, 15]:
		var extra := good.duplicate(true); extra.capstone_reward_claimed = true
		check(not live.inspect_save_bytes(_document(extra, version)).ok, "Strict current formats reject hidden reward/extra fields")
	for key: String in Quest.FIELDS:
		for bad: Variant in [null, true, false, 0.5, {}, [], "unknown", INF, NAN]:
			var malformed := good.duplicate(true); malformed[key] = bad
			check(not live._stage_save_data(malformed, 15).ok, "Malformed raw type/value rejected:" + key + ":" + str(bad))
	for stage: Variant in [-1, 0.5, 8, 99, "3", true]:
		var malformed: Dictionary = _ready().to_dict(); malformed.capstone_stage = stage
		check(not live.inspect_save_bytes(_document(malformed)).ok, "Invalid stage rejected:" + str(stage))
	for version: Variant in [null, -1, 0, 14.5, 15.5, 16, 99, "15", true, {}, []]:
		check(not live.inspect_save_bytes(_document(good, version)).ok, "Malformed/unknown header rejected:" + str(version))
	for malformed: PackedByteArray in [PackedByteArray(), "{}".to_utf8_buffer(), "[]".to_utf8_buffer(), "{broken".to_utf8_buffer(), '{"version":15,"player":[]}'.to_utf8_buffer()]:
		check(not live.inspect_save_bytes(malformed).ok, "Malformed envelope rejected")
	# Cross-field rules are tested via the whole reader at every stage.
	for stage: int in range(8):
		for draft: String in ["", "pause_batch", "cancel_proven"]:
			for ending: String in ["", "pause_batch", "cancel_proven"]:
				var data: Dictionary = _ready().to_dict(); data.capstone_stage = stage; data.capstone_draft = draft; data.capstone_ending = ending
				var valid: bool = draft.is_empty() and ending.is_empty() if stage <= 4 else (ending.is_empty() if stage == 5 else (not ending.is_empty() and draft == ending))
				check(live.inspect_save_bytes(_document(data)).ok == valid, "Exact stage/draft/ending relationship %d:%s:%s" % [stage, draft, ending])
	var invalid := good.duplicate(true); invalid.capstone_stage = 6
	var path := fixture_root + "/invalid.json"; _write(path, _document(invalid)); var original := _bytes(path)
	check(live.load_game(path) == ERR_FILE_CORRUPT and live.to_dict() == before and live.skill_cooldown == 3 and _bytes(path) == original, "Invalid load changes neither persistent/transient state nor bytes")
	_write(path, _document(good, 16)); original = _bytes(path)
	check(live.load_game(path) == ERR_FILE_UNRECOGNIZED and live.to_dict() == before and live.skill_cooldown == 3 and _bytes(path) == original, "Future16 rejection atomic")
	var malformed_live := State.new(); malformed_live.capstone_stage = 6
	check(malformed_live.save_game(path) == ERR_FILE_CORRUPT and _bytes(path) == original, "Invalid save does not overwrite existing file")

func _ready():
	var s := State.new()
	s.map_id = "heting"; s.hp = 73; s.qi = 1
	s.quest_stage = 6; s.ending = "守望"; s.side_stage = 3; s.side_choice = "rescue"; s.side_clues = 2; s.side_found.assign(["boatman", "ledger"]); s.side_reward_claimed = true
	s.chapter_two_stage = 4; s.chapter_two_ending = "protect_witness"; s.archive_clues.assign(["clerk", "inscription"]); s.seal_sequence.assign([2, 0, 1])
	s.mist_stage = 4; s.mist_approach = "duel"; s.mist_gauges.assign(["rain", "stone", "basin"]); s.mist_ending = "warn_ferries"
	s.heting_stage = 4; s.heting_bridge = "west"; s.heting_delivered.assign(["meal", "sealed", "reserve"]); s.heting_draft = "open_scale"; s.heting_ending = "open_scale"
	s.receipt_stage = 3; s.consignee_stage = 5; s.consignee_observations.assign(State.Consignee.OBSERVATIONS); s.consignee_draft = "return_to_owner"; s.consignee_ending = "return_to_owner"; s.consignee_cargo_location = "grain_boat"
	s.companion_unlocked = true; s.party_roster.assign(["hero"]); s.party_resources = {"shen": {"hp": 0, "qi": 1}}
	return s

func _test_roundtrips_and_transfer() -> void:
	var states: Array = [State.new()]; var s = _ready()
	check(s.begin_capstone(), "Earn model referral stage1"); states.append(s._detached_persistent_state())
	s.map_id = "frostbridge"; check(s.reveal_capstone_letter(), "Earn letter stage2"); states.append(s._detached_persistent_state())
	check(s.resolve_capstone_evidence(Quest.CORRECT_ANSWER).correct, "Earn issued responsibility stage3"); states.append(s._detached_persistent_state())
	# Pure transition is used ONLY to produce synthetic roundtrip fixtures here;
	# actual controller/entry/epoch/resource proof is in capstone_state_test.gd.
	check(Quest.settle_victory(s), "Synthetic model victory stage4"); states.append(s._detached_persistent_state())
	check(s.classify_capstone_orders(Quest.CORRECT_PARTITION).correct, "Earn persistent classification stage5"); states.append(s._detached_persistent_state())
	for plan: String in Quest.PLANS:
		var ending_state = s._detached_persistent_state(); check(ending_state.choose_capstone_plan(plan), "Choose reversible draft")
		states.append(ending_state._detached_persistent_state())
		ending_state.map_id = "sluice"; check(ending_state.confirm_capstone_disposition(plan), "Explicit desk disposition stage6"); states.append(ending_state._detached_persistent_state())
		ending_state.map_id = "qingwei"; states.append(ending_state._detached_persistent_state()) # Unpaid stage6 at destination remains unpaid on load.
		check(ending_state.finish_capstone_homecoming(), "Explicit homecoming stage7"); states.append(ending_state)
	for index: int in range(states.size()):
		var state = states[index]; var folder := fixture_root + "/roundtrip%d" % index; DirAccess.make_dir_absolute(folder)
		var slots := Slots.new(folder); var transfer := Transfer.new(folder); var loaded := State.new()
		check(slots.save_slot(state, 1) == OK, "Save exact stage%d" % state.capstone_stage)
		var original := _bytes(slots.path_for(1))
		check(slots.load_slot(loaded, 1) == OK and loaded.to_dict() == state.to_dict(), "Stage, draft, ending, old resources exact roundtrip")
		state.coins += 1; check(slots.save_slot(state, 1) == OK and _bytes(slots.path_for(1) + ".bak") == original, "Backup retains exact prior bytes")
		check(slots.load_backup(loaded, 1) == OK and slots.describe(1).status == "valid" and slots.describe_backup(1).status == "valid", "Current15 and backup15 metadata accepted")
		var export := transfer.export_slot(1, true); check(export.ok and export.version == 15 and export.bytes == original, "Export exact15 backup bytes")
		var preview := transfer.preview_import(original, 2); check(preview.ok and preview.version == 15, "Same reader accepts15 for empty slot")
		if preview.ok:
			check(transfer.commit_import(preview.token).ok and _bytes(slots.path_for(2)) == original, "Import retains exact bytes")
			check(transfer.commit_import(preview.token).ok, "Repeated import confirmation is read-only")
		check(not transfer.preview_import(original, 2).ok, "Occupied target protected")
		for suffix: String in [".bak", ".tmp", ".bak.tmp"]:
			var conflict := slots.path_for(3) + suffix; _write(conflict, "existing".to_utf8_buffer())
			check(not transfer.preview_import(original, 3).ok and _bytes(conflict) == "existing".to_utf8_buffer(), "Backup/temp target protected:" + suffix)
			DirAccess.remove_absolute(conflict)
		var true14 := _document(old_script.new().to_dict(), 14); preview = transfer.preview_import(true14, 3)
		check(preview.ok and preview.version == 14, "Old14 still accepted through transfer")
		if preview.ok: check(transfer.commit_import(preview.token).ok and transfer.export_slot(3).bytes == true14, "Transfer never rewrites14 bytes")
	var paid = states[-1]; var before: Dictionary = paid.to_dict()
	check(paid.save_game(fixture_root + "/missing/final.json") != OK and paid.to_dict() == before, "Failed persistence retains accepted paid state")
	check(not paid.finish_capstone_homecoming() and paid.to_dict() == before, "Retry cannot pay again")
	check(paid.save_game(fixture_root + "/retry.json") == OK and paid.to_dict() == before, "Retry only saves accepted state")

func _test_old_reader_gate() -> void:
	var old = old_script.new(); old.coins = 913; old.skill_cooldown = 3; old.enemy_hp = 17
	old.enemy_name = "preserve rejected-load transients"; old.enemy_intent = "unchanged"; old.battle_log.assign(["read-only rejection sentinel"])
	old.party_battle_epoch = 8; old.receipt_battle_epoch = 9; old.party_settlement = {"sentinel": [1, 2]}; old.receipt_settlement = {"sentinel": 3}
	var all_before := _all_script_properties(old)
	var before: Dictionary = old.to_dict(); var path := fixture_root + "/true15.json"
	check(State.new().save_game(path) == OK and JSON.parse_string(_bytes(path).get_string_from_utf8()).version == 15, "Current serializer creates actual15 subject")
	var bytes := _bytes(path)
	check(old.load_game(path) == ERR_FILE_UNRECOGNIZED and old.to_dict() == before and old.skill_cooldown == 3 and old.enemy_hp == 17 and _bytes(path) == bytes, "Authentic old14 source/current dependencies rejects15 before state/disk changes")
	check(old._same_save_value(_all_script_properties(old), all_before), "Every old script variable, including all persistent/transient fields, unchanged by rejection")
	var control := fixture_root + "/true14.json"; check(old.save_game(control) == OK and old.load_game(control) == OK, "Old reader's own true14 control accepted")
	check(_hash(_bytes(OLD_READER)) == OLD_SHA, "Frozen historical reader remains byte exact")

func _all_script_properties(s) -> Dictionary:
	var result: Dictionary = {}
	for property: Dictionary in s.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value = s.get(property.name)
			result[property.name] = value.duplicate(true) if value is Array or value is Dictionary else value
	return result

func _remove_tree(path: String) -> void:
	for file: String in DirAccess.get_files_at(path): DirAccess.remove_absolute(path.path_join(file))
	for child: String in DirAccess.get_directories_at(path): _remove_tree(path.path_join(child))
	DirAccess.remove_absolute(path)
