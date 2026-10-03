extends SceneTree
## Retained independent synthetic model/IO checks. No user saves, earned progression, UI or browser claim.
## The pinned genuine15 fixture producer and old14-pack probe form a separate optional two-process gate.
const State = preload("res://scripts/game_state.gd")
const Frozen15 = preload("res://tests/weapon_fitting_fixture_producer.gd")
const Quest = preload("res://scripts/volume_one_capstone_rules.gd")
const Consignee = preload("res://scripts/heting_consignee_rules.gd")
const Slots = preload("res://scripts/local_save_slots.gd")
const Transfer = preload("res://scripts/local_save_transfer.gd")
const Fixture = preload("res://tests/capstone_independent_fixture_producer.gd")
const OLD_SHA = "160fe884cd9e80966cf94493020cb2a9454957e54bc7c0def72754bc95e03fd5"
var checks := 0
var failures := 0
var folder: String
var old_script: GDScript
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _init() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): quit(2); return
	folder = "user://capstone-independent-%s" % Time.get_ticks_usec()
	check(DirAccess.make_dir_recursive_absolute(folder) == OK, "Create isolated fixture directory")
	old_script = GDScript.new()
	var raw := FileAccess.get_file_as_bytes(Fixture.OLD_PATH)
	check(raw.size() == 72931 and FileAccess.get_sha256(Fixture.OLD_PATH) == OLD_SHA, "Pinned independently extracted real14 source")
	old_script.source_code = raw.get_string_from_utf8().replace("class_name HeroState\n", "")
	check(old_script.reload() == OK, "Only class registration removed in memory from real14 reader")
	if failures > 0: quit(1); return
	_legacy()
	_modern()
	_roundtrip_transfer()
	_old_policy_equivalence()
	_old_reader()
	print("INDEPENDENT_SCHEMA_RESULT checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
func doc(data: Dictionary, version: Variant = State.SAVE_VERSION) -> PackedByteArray:
	return JSON.stringify({"version": version, "player": data}, "\t").to_utf8_buffer()
func write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "Open own fixture:" + path)
	if file != null: file.store_buffer(bytes); file.close()
func eq(a: Variant, b: Variant) -> bool:
	return State.new()._same_save_value(a, b)
func progress(s, plan: String = "hold_for_inspection", stage: int = 5):
	for outcome: bool in Fixture.apply_progress(s, plan, stage): check(outcome, "Synthetic explicit companion history/recruit")
	return s
func _legacy() -> void:
	var live := State.new(); live.coins = 789; live.skill_cooldown = 3
	var before: Dictionary = live.to_dict()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/legacy_saves/provenance.json"))
	var seen: Array[int] = []
	for item: Dictionary in manifest.fixtures:
		var path: String = "res://" + item.path
		var bytes := FileAccess.get_file_as_bytes(path)
		check(FileAccess.get_sha256(path) == item.sha256, "Legacy original fixture hash v%d" % item.version)
		var result: Dictionary = live.inspect_save_bytes(bytes)
		check(result.ok and result.version == item.version, "Historical source/layout accepted v%d" % item.version)
		check(live.to_dict() == before and live.skill_cooldown == 3 and FileAccess.get_file_as_bytes(path) == bytes, "Legacy inspection is read-only v%d" % item.version)
		if not result.ok: continue
		seen.append(int(item.version))
		check(result.state.capstone_stage == 0 and result.state.capstone_draft == "" and result.state.capstone_ending == "", "Absent capstone neutral v%d" % item.version)
		var data: Dictionary = JSON.parse_string(bytes.get_string_from_utf8()).player
		for mask: int in range(1, 7):
			var partial := data.duplicate(true)
			for i: int in range(3):
				if mask & (1 << i): partial[Quest.FIELDS[i]] = 0 if i == 0 else ""
			check(not live.inspect_save_bytes(doc(partial, item.version)).ok, "Every nonempty partial capstone mask rejects v%d mask%d" % [item.version, mask])
		var present := data.duplicate(true)
		present.capstone_stage = 0; present.capstone_draft = ""; present.capstone_ending = ""
		check(live.inspect_save_bytes(doc(present, item.version)).ok, "Full neutral legacy bundle retained v%d" % item.version)
		present.capstone_draft = "pause_batch"
		check(not live.inspect_save_bytes(doc(present, item.version)).ok, "Present malformed bundle cannot be erased v%d" % item.version)
	check(seen.has(1) and seen.has(13) and seen.size() >= 13, "All explicit historical versions1–13 covered")
	var old = old_script.new()
	check(old.SAVE_VERSION == 14 and not old.to_dict().has("capstone_stage"), "True14 serializer identity")
	var default: Dictionary = old.to_dict()
	for key: String in default:
		var bad := default.duplicate(true); bad.erase(key)
		check(not live.inspect_save_bytes(doc(bad, 14)).ok, "Every required14 key remains required:" + key)
	for plan: String in ["hold_for_inspection", "return_to_owner"]:
		for stage: int in range(6):
			old = progress(old_script.new(), plan, stage)
			old.receipt_stage = stage % 4
			var raw_data: Dictionary = old.to_dict()
			check(old._stage_save_data(raw_data, 14).ok, "Real14 producer control valid stage%d %s" % [stage, plan])
			var bytes := doc(raw_data, 14)
			var result: Dictionary = live.inspect_save_bytes(bytes)
			check(result.ok, "Real14 progressed accepted stage%d %s" % [stage, plan])
			if not result.ok: continue
			var converted: Dictionary = result.state.to_dict()
			check(result.state.weapon_fitting == "plain", "Old14 fitting defaults plain")
			for key: String in Quest.FIELDS + ["weapon_fitting"]: converted.erase(key)
			check(eq(converted, raw_data), "Every real14 story/resource/cargo/array field preserved stage%d %s" % [stage, plan])
			check(result.state.party_resources.shen.hp == 0 and result.state.party_resources.tang.hp == 1 and result.state.party_roster == ["hero", "shen", "qin"], "Downed deployed and wounded bench survive migration")
			if stage == 5:
				for capstage: int in range(8):
					var cap := raw_data.duplicate(true)
					cap.capstone_stage = capstage; cap.capstone_draft = "pause_batch" if capstage >= 6 else ""; cap.capstone_ending = "pause_batch" if capstage >= 6 else ""
					var migrated: Dictionary = live.inspect_save_bytes(doc(cap, 14))
					check(migrated.ok and migrated.state.weapon_fitting == "plain" and eq(without_fitting(migrated.state.to_dict()), cap), "Present complete valid14 capstone is never dropped stage%d" % capstage)
	for version: int in [14, 15]:
		var original: Dictionary = progress(old_script.new()).to_dict()
		if version == 15: original.capstone_stage = 0; original.capstone_draft = ""; original.capstone_ending = ""
		for badvalue: Variant in [true, false, -1, 0.5, INF, NAN, "0", null]:
			var bad := original.duplicate(true); bad.party_resources.shen.hp = badvalue
			check(not live._stage_save_data(bad, version).ok, "Present downed-resource malformed values rejected before normalization v%d:" % version + str(badvalue))
	for mask: int in range(1, 7):
		var partial := default.duplicate(true)
		for i: int in range(3):
			if mask & (1 << i): partial[Quest.FIELDS[i]] = 0 if i == 0 else ""
		check(not live.inspect_save_bytes(doc(partial, 14)).ok, "Partial14 capstone mask rejects%d" % mask)
	check(live.to_dict() == before and live.skill_cooldown == 3, "All legacy adversaries leave live data unchanged")
func _modern() -> void:
	var live := State.new(); live.coins = 777; live.skill_cooldown = 4
	var before: Dictionary = live.to_dict(); var good := State.new().to_dict()
	check(State.SAVE_VERSION == 16 and State.PartyRoster.PAYLOAD_VERSION == 16 and Consignee.INTRODUCED_VERSION == 14 and Consignee.MAX_SAVE_VERSION == 16, "Schema cap and introduction split")
	for key: String in good:
		var bad := good.duplicate(true); bad.erase(key)
		check(not live.inspect_save_bytes(doc(bad)).ok, "All16 keys required:" + key)
	for extra: String in ["capstone_reward_claimed", "capstone_orders", "capstone_right", "unknown"]:
		var bad := good.duplicate(true); bad[extra] = false
		check(not live.inspect_save_bytes(doc(bad)).ok, "Redundant/unknown16 field rejected:" + extra)
	for key: String in Quest.FIELDS:
		for badvalue: Variant in [null, false, true, 0.5, -1, 8, [], {}, "unknown", INF, -INF, NAN]:
			var bad := good.duplicate(true); bad[key] = badvalue
			check(not live._stage_save_data(bad, 15).ok, "Raw wrong/nonfinite new field rejects:" + key + ":" + str(badvalue))
	var ready = progress(State.new())
	for stage: int in range(8):
		for draft: String in ["", "pause_batch", "cancel_proven"]:
			for ending: String in ["", "pause_batch", "cancel_proven"]:
				var data: Dictionary = ready.to_dict(); data.capstone_stage = stage; data.capstone_draft = draft; data.capstone_ending = ending
				var expected: bool = (stage <= 4 and draft == "" and ending == "") or (stage == 5 and ending == "") or (stage >= 6 and draft != "" and ending == draft)
				var result: Dictionary = live.inspect_save_bytes(doc(data))
				check(result.ok == expected, "Exact stage/draft/ending truth table:%d %s %s" % [stage, draft, ending])
				if result.ok: check(eq(result.state.to_dict(), data), "Accepted16 exact roundtrip")
	for version: Variant in [0, 17, 99, 14.5, "16", true, null, INF, NAN]:
		var bytes := doc(good, version); var result: Dictionary = live.inspect_save_bytes(bytes)
		check(not result.ok, "Malformed/future version rejected:" + str(version))
		if version is int and version in [17, 99]: check(result.error == ERR_FILE_UNRECOGNIZED, "Future version gives explicit unrecognized")
	var bad := good.duplicate(true); bad.capstone_stage = 1
	var path := folder + "/bad.json"; var bytes := doc(bad); write(path, bytes)
	check(live.load_game(path) == ERR_FILE_CORRUPT and live.to_dict() == before and live.skill_cooldown == 4 and FileAccess.get_file_as_bytes(path) == bytes, "Rejected disk load preserves bytes, live persistent and transient state")
	for key: String in ["quest_stage", "ending", "side_stage", "side_choice", "chapter_two_stage", "chapter_two_ending", "mist_stage", "mist_ending", "heting_stage", "heting_ending", "consignee_stage", "consignee_ending"]:
		var data: Dictionary = ready.to_dict(); data.capstone_stage = 1
		data[key] = "" if data[key] is String else 0
		check(not live._stage_save_data(data, 15).ok, "Active capstone rejects missing prerequisite:" + key)
func _roundtrip_transfer() -> void:
	check(ProjectSettings.get_setting("hero/features/web_save_transfer_enabled", true) == false, "Save transfer remains default-off")
	var state = progress(State.new()); state.capstone_stage = 5
	for map: String in ["qingwei", "sluice", "frostbridge", "mistwood", "heting"]:
		state.map_id = map
		check(state._stage_save_data(state.to_dict(), 15).ok, "Unpaid empty-draft classified state is portable:" + map)
	var slots := Slots.new(folder); var transfer := Transfer.new(folder)
	check(slots.save_slot(state, 1) == OK, "Save classified empty draft")
	var original := FileAccess.get_file_as_bytes(slots.path_for(1))
	state.capstone_draft = "pause_batch"
	check(slots.save_slot(state, 1) == OK and FileAccess.get_file_as_bytes(slots.path_for(1) + ".bak") == original, "Backup preserves exact previous empty draft")
	var exported: Dictionary = transfer.export_slot(1, true)
	check(exported.ok and exported.version == 16 and exported.bytes == original, "Backup raw-byte export exact16")
	var preview: Dictionary = transfer.preview_import(original, 2)
	check(preview.ok and transfer.commit_import(preview.token).ok and FileAccess.get_file_as_bytes(slots.path_for(2)) == original, "Empty-slot import preserves raw bytes")
	var loaded := State.new()
	check(slots.load_slot(loaded, 2) == OK and loaded.capstone_stage == 5 and loaded.capstone_draft == "", "Import never loses completed classification or chooses draft")
	check(not transfer.preview_import(original, 2).ok, "Occupied slot rejects import")
	var historical := doc(progress(old_script.new()).to_dict(), 14)
	preview = transfer.preview_import(historical, 3)
	check(preview.ok, "Real14 import preview")
	write(slots.path_for(3) + ".bak", original)
	check(not transfer.commit_import(preview.token).ok and not FileAccess.file_exists(slots.path_for(3)) and FileAccess.get_file_as_bytes(slots.path_for(3) + ".bak") == original, "Late backup conflict prevents write and preserves conflict")
	DirAccess.remove_absolute(slots.path_for(3) + ".bak")
	check(not transfer.commit_import(preview.token).ok, "Failed confirmation consumed; conflict removal does not reuse token")
	preview = transfer.preview_import(historical, 3)
	check(preview.ok and transfer.commit_import(preview.token).ok and transfer.export_slot(3).bytes == historical, "Fresh real14 import/reexport stays exact14")
	var before: Dictionary = state.to_dict()
	check(state.save_game(folder + "/missing/failed.json") != OK and state.to_dict() == before and FileAccess.get_file_as_bytes(slots.path_for(1) + ".bak") == original, "Write failure preserves model and existing backup bytes")
func _old_policy_equivalence() -> void:
	for policy: String in ["rest", "growth", "no_growth", "cap"]:
		var old = progress(old_script.new())
		if policy == "no_growth": old.level = 10; old.xp = 0
		elif policy == "cap": old.level = 99; old.xp = 5939
		else: old.level = 1; old.xp = 59
		var inspected: Dictionary = State.new().inspect_save_bytes(doc(old.to_dict(), 14))
		check(inspected.ok, "Existing policy control imports:" + policy)
		if not inspected.ok: continue
		var current = inspected.state
		if policy == "rest": old.heal_rest(); current.heal_rest()
		else: old.gain_xp(160); current.gain_xp(160)
		var data: Dictionary = current.to_dict()
		check(current.weapon_fitting == "plain", "Historical policy retains plain fitting")
		for key: String in Quest.FIELDS + ["weapon_fitting"]: data.erase(key)
		check(eq(old.to_dict(), data), "Actual old14 vs16 existing explicit recovery/growth policy byte-value parity:" + policy)
func _old_reader() -> void:
	var producer15 := Frozen15.old_reader()
	check(producer15 != null, "Pinned15 producer loaded")
	if producer15 == null: return
	var current = producer15.new(); var path := folder + "/true15-subject.json"
	check(current.save_game(path) == OK, "Pinned historical producer writes true15 subject for authentic source-reader gate")
	var bytes := FileAccess.get_file_as_bytes(path); var old = old_script.new()
	old.coins = 913; old.skill_cooldown = 3
	var before: Dictionary = old.to_dict()
	check(old.load_game(path) == ERR_FILE_UNRECOGNIZED, "Authentic old14 source gate rejects true15 with current dependencies")
	check(old.to_dict() == before and old.skill_cooldown == 3 and FileAccess.get_file_as_bytes(path) == bytes, "Raw old-reader rejection byte/persistent/transient preserving")
	var control := folder + "/true14-control.json"
	check(old.save_game(control) == OK and old.load_game(control) == OK, "Real old14 source control accepted")

func without_fitting(data: Dictionary) -> Dictionary:
	var result := data.duplicate(true); result.erase("weapon_fitting"); return result
