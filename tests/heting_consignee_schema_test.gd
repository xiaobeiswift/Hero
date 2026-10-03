extends SceneTree
## Model/native filesystem tests only. No user saves or browser-persistence claim.
const State = preload("res://scripts/game_state.gd")
const Quest = preload("res://scripts/heting_consignee_rules.gd")
const Slots = preload("res://scripts/local_save_slots.gd")
const Transfer = preload("res://scripts/local_save_transfer.gd")
const FIXTURES = "res://tests/fixtures/legacy_saves/"
var checks: int = 0
var failures: int = 0
var fixture_root: String

func _init() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): quit(2); return
	fixture_root = "user://consignee-schema-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(fixture_root) == OK, "Isolated synthetic root")
	check(ProjectSettings.get_setting("hero/features/web_save_transfer_enabled", false) == false, "Transfer feature remains default-off")
	_test_legacy()
	_test_modern_rejections()
	_test_roundtrips_and_transfer()
	_test_frozen_reader()
	_remove_tree(fixture_root)
	if failures == 0: print("PASS: %d consignee introduced14/current16 migration/atomicity/slot/transfer/real-Web25-reader checks; genuine producers1,9–13, authored contracts2–8" % checks)
	quit(0 if failures == 0 else 1)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path)

func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "Open isolated fixture")
	if file != null: file.store_buffer(bytes); file.close()

func _document(data: Dictionary, version: int = State.SAVE_VERSION) -> PackedByteArray:
	return JSON.stringify({"version": version, "player": data}, "\t").to_utf8_buffer()

func _hash(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new(); hashing.start(HashingContext.HASH_SHA256); hashing.update(bytes)
	return hashing.finish().hex_encode()

func _test_legacy() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + "provenance.json"))
	var live := State.new(); live.coins = 999; live.skill_cooldown = 4
	for item: Dictionary in manifest.fixtures:
		var path: String = "res://" + item.path
		var bytes := _bytes(path)
		check(_hash(bytes) == item.sha256, "Pinned legacy fixture bytes: schema%d" % item.version)
		if item.has("source"):
			check(_hash(_bytes("res://" + item.source)) == item.source_sha256, "Original producer source pin")
			var producer_script := GDScript.new()
			producer_script.source_code = FileAccess.get_file_as_string("res://" + item.source).replace("class_name HeroState\n", "")
			check(producer_script.reload() == OK, "Actual archived default producer compiles")
			var producer = producer_script.new()
			var fixture: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
			check(producer.SAVE_VERSION == fixture.version and live._same_save_value(producer.to_dict(), fixture.player), "Fixture is exactly original producer serialization, never relabeled current model")
		var before: Dictionary = live.to_dict()
		var inspection := live.inspect_save_bytes(bytes)
		check(inspection.ok and inspection.version == item.version, "Accept original schema%d layout" % item.version)
		check(live.to_dict() == before and live.skill_cooldown == 4 and _bytes(path) == bytes, "Inspection leaves live state and source bytes unchanged")
		if not inspection.ok: continue
		var migrated = inspection.state
		for key: String in Quest.FIELDS:
			check(migrated.to_dict()[key] == State.new().to_dict()[key], "Absent legacy chapter defaults neutral: " + key)
		check(migrated.coins == 24 and migrated.hp == 100 and migrated.qi == 2 and migrated.medicine == 3 and migrated.party_roster == ["hero"], "Original default resources unchanged")
		check(not migrated.internal_unlocked and not migrated.qin_unlocked and migrated.receipt_stage == 0, "No unearned recruits, lesson or prior reward")
		var rewritten: String = fixture_root + "/migrated%d.json" % item.version
		check(migrated.save_game(rewritten) == OK and JSON.parse_string(_bytes(rewritten).get_string_from_utf8()).version == 16, "Only explicit new save writes current schema16")
		check(_bytes(path) == bytes, "Migration never rewrites historical source")
		var partial: Dictionary = JSON.parse_string(bytes.get_string_from_utf8()).player
		partial.consignee_stage = 0
		check(not live.inspect_save_bytes(_document(partial, item.version)).ok, "Incomplete new bundle rejects even on legacy schema")
	# Real Web25 serializer's progressed document preserves all old endings,
	# recruits and wounds. Explicitly synthetic state, not an earned journey.
	var script := GDScript.new(); script.source_code = FileAccess.get_file_as_string("res://tests/fixtures/v025_game_state.gd.txt").replace("class_name HeroState\n", "")
	check(script.reload() == OK, "Frozen Web25 producer compiles")
	var old = script.new()
	old.level = 6; old.max_hp = 160; old.hp = 87; old.qi = 1; old.coins = 241; old.medicine = 2
	old.quest_stage = 6; old.sect = "听潮阁"; old.sect_rank = 1; old.ending = "守望"; old.internal_unlocked = true
	old.chapter_two_stage = 4; old.chapter_two_ending = "protect_witness"; old.archive_clues.assign(["clerk", "inscription"]); old.seal_sequence.assign([2, 0, 1])
	old.mist_stage = 4; old.mist_approach = "duel"; old.mist_gauges.assign(["rain", "stone", "basin"]); old.mist_ending = "warn_ferries"
	old.heting_stage = 4; old.heting_bridge = "west"; old.heting_delivered.assign(["meal", "sealed", "reserve"]); old.heting_draft = "open_scale"; old.heting_ending = "open_scale"
	old.receipt_stage = 3; old.map_id = "heting"; old.companion_unlocked = true; old.party_roster.assign(["hero", "shen"]); old.party_resources = {"shen": {"hp": 0, "qi": 1}}
	var original: Dictionary = old.to_dict(); var inspected := live.inspect_save_bytes(_document(original, 13))
	check(inspected.ok, "Genuine Web25 serializer progressed schema13 migrates")
	if inspected.ok:
		var converted: Dictionary = inspected.state.to_dict()
		check(inspected.state.weapon_fitting == "plain", "Historical13 fitting defaults plain")
		for key: String in Quest.FIELDS + State.Capstone.FIELDS + ["weapon_fitting"]: converted.erase(key)
		check(live._same_save_value(converted, original), "Every old ending/resource/recruit/reward field remains exact")
		check(inspected.state.party_resources.shen.hp == 0, "Migration never revives injured companion")

func _test_modern_rejections() -> void:
	var live := State.new(); live.coins = 777; live.skill_cooldown = 3
	var before: Dictionary = live.to_dict()
	var good := State.new().to_dict()
	check(State.SAVE_VERSION == 16 and live.PartyRoster.PAYLOAD_VERSION == 16, "Both whole-save and party schema caps explicitly16; introduced14 completeness is separately preserved")
	for key: String in good:
		var missing := good.duplicate(true); missing.erase(key)
		check(not live.inspect_save_bytes(_document(missing)).ok, "Modern required key rejects: " + key)
	var extras := good.duplicate(true); extras["consignee_hidden_reward"] = true
	check(not live.inspect_save_bytes(_document(extras)).ok, "Modern extra field rejects")
	for key: String in Quest.FIELDS:
		for bad: Variant in [null, true, 0.5, {}, [], "unknown"]:
			var candidate := good.duplicate(true); candidate[key] = bad
			if live._same_save_value(candidate, good): continue
			check(not live.inspect_save_bytes(_document(candidate)).ok, "Wrong chapter field type/value rejects: " + key + ":" + str(bad))
	for stage: Variant in [-1, 0.5, 1, 2, 3, 4, 5, 6]:
		var data := good.duplicate(true); data.consignee_stage = stage
		check(not live.inspect_save_bytes(_document(data)).ok, "Unproven/inconsistent stage rejects:" + str(stage))
	for version: Variant in [0, 13.5, 14.5, 17, 99, "16", true]:
		var inspected := live.inspect_save_bytes(JSON.stringify({"version": version, "player": good}).to_utf8_buffer())
		check(not inspected.ok, "Unknown/malformed schema rejects")
	var path := fixture_root + "/bad.json"; _write(path, _document(extras)); var bytes := _bytes(path)
	check(live.load_game(path) == ERR_FILE_CORRUPT and live.to_dict() == before and live.skill_cooldown == 3 and _bytes(path) == bytes, "Failed load preserves whole live model and source bytes")
	# Format13 remains strict: only an absent new bundle gets its explicit
	# exception; no widening for missing old fields or unrelated extras.
	var legacy: Dictionary = JSON.parse_string(_bytes(FIXTURES + "schema_13_default.json").get_string_from_utf8()).player
	for key: String in legacy:
		var missing := legacy.duplicate(true); missing.erase(key)
		check(not live.inspect_save_bytes(_document(missing, 13)).ok, "Schema13 required old key still rejects:" + key)
	legacy.extra = 1
	check(not live.inspect_save_bytes(_document(legacy, 13)).ok, "Schema13 extra field still rejects")

func _port():
	var s := State.new()
	s.map_id = "heting"; s.chapter_two_stage = 4; s.chapter_two_ending = "protect_witness"
	s.archive_clues.assign(["clerk", "inscription"]); s.seal_sequence.assign([2, 0, 1])
	s.mist_stage = 4; s.mist_approach = "duel"; s.mist_gauges.assign(["rain", "stone", "basin"]); s.mist_ending = "release_water"
	s.heting_stage = 4; s.heting_bridge = "east"; s.heting_delivered.assign(["meal", "sealed", "reserve"]); s.heting_draft = "short_ferries"; s.heting_ending = "short_ferries"
	return s

func _test_roundtrips_and_transfer() -> void:
	var states: Array = [State.new()]
	var s = _port(); check(s.begin_consignee(), "Begin stage1"); states.append(s._detached_persistent_state())
	for observation: String in Quest.OBSERVATIONS: check(s.observe_consignee(observation), "Solo evidence:" + observation)
	check(s.resolve_consignee_contradiction(Quest.CORRECT_ANSWER).correct, "Evidence earns stage2"); states.append(s._detached_persistent_state())
	check(s.choose_consignee_plan(Quest.PLANS[0]), "Prepare reversible draft")
	# Pure rule helper models victory; combat provenance is covered separately.
	check(Quest.settle_victory(s, Quest.PLANS[0]), "Rule stage3 transition"); states.append(s._detached_persistent_state())
	check(s.take_consignee_cargo(Quest.BATCH, Quest.SOURCE), "Finite stage4 cart"); states.append(s._detached_persistent_state())
	for plan: String in Quest.PLANS:
		var ending_state = s._detached_persistent_state()
		if ending_state.consignee_draft != plan: check(ending_state.choose_consignee_plan(plan), "Other reversible draft")
		check(ending_state.finish_consignee_delivery(Quest.receiver_for(plan), plan), "Explicit stage5 handover:" + plan)
		states.append(ending_state)
	for index: int in range(states.size()):
		var state = states[index]; var folder := fixture_root + "/roundtrip-%d" % index; DirAccess.make_dir_absolute(folder)
		var slots := Slots.new(folder); var transfer := Transfer.new(folder)
		check(slots.save_slot(state, 1) == OK, "Save stage%d" % state.consignee_stage)
		var original := _bytes(slots.path_for(1)); var loaded := State.new()
		check(slots.load_slot(loaded, 1) == OK and loaded.to_dict() == state.to_dict(), "Stage/ending exact roundtrip")
		state.coins += 1; check(slots.save_slot(state, 1) == OK and _bytes(slots.path_for(1) + ".bak") == original, "Backup preserves exact former stage")
		check(slots.load_backup(loaded, 1) == OK and loaded.to_dict() != state.to_dict(), "Stage backup restores detached model")
		check(slots.describe(1).status == "valid" and slots.describe_backup(1).status == "valid", "Metadata sees current16 and backup16")
		var export := transfer.export_slot(1, true); check(export.ok and export.version == 16 and export.bytes == original, "Export exact current16 backup bytes")
		var preview := transfer.preview_import(original, 2); check(preview.ok and preview.version == 16, "Empty-slot current16 preview")
		if preview.ok: check(transfer.commit_import(preview.token).ok and _bytes(slots.path_for(2)) == original, "Import retains exact current16 bytes")
		check(not transfer.preview_import(original, 2).ok, "Never replace occupied import target")
		var historical := _bytes(FIXTURES + "schema_13_default.json"); preview = transfer.preview_import(historical, 3)
		check(preview.ok and preview.version == 13, "Genuine schema13 empty-slot preview")
		if preview.ok: check(transfer.commit_import(preview.token).ok and _bytes(slots.path_for(3)) == historical and slots.load_slot(loaded, 3) == OK and loaded.consignee_stage == 0, "Exact13 import plus neutral migration")
		check(transfer.export_slot(3).bytes == historical, "Re-export13 preserves old bytes")
	# Ordinary save failure does not roll back a paid ending or pay it again.
	var paid = states[-1]; var before: Dictionary = paid.to_dict()
	check(paid.save_game(fixture_root + "/missing/save.json") != OK and paid.to_dict() == before, "Failed write retains already settled ending")
	check(not paid.finish_consignee_delivery(Quest.receiver_for(paid.consignee_draft), paid.consignee_draft) and paid.to_dict() == before, "Failed-save retry cannot double reward")
	check(paid.save_game(fixture_root + "/retry.json") == OK and paid.to_dict() == before, "Retry persists same paid state")

func _test_frozen_reader() -> void:
	var source := _bytes("res://tests/fixtures/v025_game_state.gd.txt")
	check(_hash(source) == "4e052447cb4dbfed20ee3fd22f23261aef043ad7791a457e1e737fe8faa1176d", "REAL Web25 schema13 reader byte pin")
	var script := GDScript.new(); script.source_code = source.get_string_from_utf8().replace("class_name HeroState\n", "")
	check(script.reload() == OK, "Actual Web25 reader compiles with class name adaptation only")
	var old = script.new(); old.coins = 913; old.skill_cooldown = 3
	var before: Dictionary = old.to_dict(); var path := fixture_root + "/format14.json"
	var producer_bytes := _bytes("res://tests/fixtures/v028_game_state.gd.txt")
	check(_hash(producer_bytes) == "160fe884cd9e80966cf94493020cb2a9454957e54bc7c0def72754bc95e03fd5", "True14 producer byte pin")
	var producer_script := GDScript.new(); producer_script.source_code = producer_bytes.get_string_from_utf8().replace("class_name HeroState\n", "")
	check(producer_script.reload() == OK, "Frozen14 producer compiles with class-name adaptation only")
	var producer = producer_script.new()
	check(producer.SAVE_VERSION == 14 and producer.save_game(path) == OK, "Actual frozen14 producer creates true14 document")
	var bytes := _bytes(path)
	check(old.SAVE_VERSION == 13 and old.load_game(path) == ERR_FILE_UNRECOGNIZED, "Deployed schema13 reader rejects14 at version gate")
	check(old.to_dict() == before and old.skill_cooldown == 3 and _bytes(path) == bytes, "Frozen reader rejected before state or file mutation")
	var prior12 := GDScript.new(); prior12.source_code = FileAccess.get_file_as_string("res://tests/fixtures/v022_game_state.gd.txt").replace("class_name HeroState\n", "")
	check(prior12.reload() == OK, "Original schema12 reader compiles")
	var older = prior12.new(); var older_before: Dictionary = older.to_dict()
	check(older.load_game(path) == ERR_FILE_UNRECOGNIZED and older.to_dict() == older_before and _bytes(path) == bytes, "Schema12 also rejects14 without mutation")

func _remove_tree(path: String) -> void:
	for file: String in DirAccess.get_files_at(path): DirAccess.remove_absolute(path.path_join(file))
	for child: String in DirAccess.get_directories_at(path): _remove_tree(path.path_join(child))
	DirAccess.remove_absolute(path)
