extends SceneTree
## Independent synthetic schema/model/native-IO gates. Genuine producers1,9–15;
## authored historical-layout contracts2–8. Frozen source/current-dependency
## reader is separate from weapon_fitting_old15_pack_probe's complete old PCK.
## No earned journey, UI, browser persistence, graphics or deployment claim.
const State = preload("res://scripts/game_state.gd")
const Fittings = preload("res://scripts/weapon_fitting_rules.gd")
const Slots = preload("res://scripts/local_save_slots.gd")
const Transfer = preload("res://scripts/local_save_transfer.gd")
const Frozen15 = preload("res://tests/weapon_fitting_fixture_producer.gd")
const Progress = preload("res://tests/capstone_independent_fixture_producer.gd")
const SECTS = ["听潮阁", "照野堂", "问石门"]
const FITTINGS = ["plain", "edge", "guard"]
var checks := 0
var failures := 0
var folder: String
var old15: GDScript
var old14: GDScript

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func bytes(path: String) -> PackedByteArray: return FileAccess.get_file_as_bytes(path)
func doc(data: Dictionary, version: Variant = 16) -> PackedByteArray:
	return JSON.stringify({"version": version, "player": data}, "\t").to_utf8_buffer()
func write(path: String, value: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "Open own isolated fixture")
	if file != null: file.store_buffer(value); file.close()
func same(a: Variant, b: Variant) -> bool: return State.new()._same_save_value(a, b)
func properties(s) -> Dictionary:
	var result := {}
	for property: Dictionary in s.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value = s.get(property.name)
			result[property.name] = value.duplicate(true) if value is Array or value is Dictionary else value
	return result
func disk(paths: Array[String]) -> Dictionary:
	var result := {}
	for path: String in paths:
		result[path] = bytes(path) if FileAccess.file_exists(path) else null
		result[path + ".tmp"] = bytes(path + ".tmp") if FileAccess.file_exists(path + ".tmp") else null
	return result
func ready(sect: String = "听潮阁"):
	var s := State.new(); s.quest_stage = 6; s.ending = "守望"; s.sect = sect; s.sect_rank = 1
	return s
func progress(s, sect: String, plan: String, capstage: int, capplan: String):
	for outcome: bool in Progress.apply_progress(s, plan, 5): check(outcome, "Explicit synthetic companion history/recruit")
	s.sect = sect; s.sect_rank = 1
	s.capstone_stage = capstage
	s.capstone_draft = capplan if capstage >= 5 else ""
	s.capstone_ending = capplan if capstage >= 6 else ""
	return s

func _init() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): quit(2); return
	folder = "user://weapon-fitting-schema-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(folder) == OK, "Create isolated fixture directory")
	check(State.SAVE_VERSION == 16 and State.PartyRoster.PAYLOAD_VERSION == 16, "Whole/party writer ceilings16")
	check(State.Consignee.INTRODUCED_VERSION == 14 and State.Consignee.MAX_SAVE_VERSION == 16, "Consignee since14 retained")
	check(State.Capstone.INTRODUCED_VERSION == 15 and State.Capstone.MAX_SUPPORTED_VERSION == 16 and Fittings.INTRODUCED_VERSION == 16, "Capstone since15 and fitting since16 are independent")
	check(ProjectSettings.get_setting("hero/features/web_save_transfer_enabled", true) == false, "Transfer remains default-off")
	old15 = Frozen15.old_reader(); old14 = Progress.old_reader()
	check(old15 != null and old14 != null, "Byte-exact historical source readers compile with current dependencies")
	if old15 == null or old14 == null: quit(1); return
	_legacy_defaults_and_presence()
	_legacy_progress_resources()
	_modern_and_qualification()
	_direct_handler_and_projection()
	_roundtrip_slots_transfer()
	_old15_source_gate()
	print("WEAPON_FITTING_SCHEMA_RESULT checks=%d failures=%d; synthetic model/IO, source reader has current dependencies; separate actual-PCK gate required" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _legacy_defaults_and_presence() -> void:
	var live := State.new(); live.coins = 913; live.skill_cooldown = 4; live.party_battle_epoch = 71
	var before := properties(live)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/legacy_saves/provenance.json"))
	var fitting_manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/weapon_fitting/provenance.json"))
	check(FileAccess.get_sha256("res://" + fitting_manifest.legacy_manifest) == fitting_manifest.legacy_manifest_sha256, "Existing legacy provenance remains pinned")
	var fixtures: Array = []
	for item: Dictionary in manifest.fixtures + fitting_manifest.fixtures:
		var path: String = "res://" + item.path
		check(FileAccess.get_sha256(path) == item.sha256, "Exact original fixture bytes v%d" % item.version)
		if item.has("source"):
			check(FileAccess.get_sha256("res://" + item.source) == item.source_sha256, "Original historical source pin v%d" % item.version)
		fixtures.append({"version": int(item.version), "bytes": bytes(path), "path": path})
	# Frozen14 producer serialization is independently pinned by exact source.
	check(old14.new().SAVE_VERSION == 14 and old15.new().SAVE_VERSION == 15, "True14 and true15 producer identities")
	var pinned14: Dictionary = JSON.parse_string(bytes("res://tests/fixtures/weapon_fitting/schema_14_default.json").get_string_from_utf8())
	check(same(old14.new().to_dict(), pinned14.player), "Pinned14 fixture matches genuine14 source serializer")
	check(fixtures.size() == 15, "All explicit versions1–15 represented")
	for fixture: Dictionary in fixtures:
		var version: int = fixture.version
		var data: Dictionary = JSON.parse_string(fixture.bytes.get_string_from_utf8()).player
		check(not data.has("weapon_fitting"), "Real old default has no fitting v%d" % version)
		var result: Dictionary = live.inspect_save_bytes(fixture.bytes)
		check(result.ok and result.version == version, "Historical version retained v%d" % version)
		if result.ok:
			check(result.state.weapon_fitting == "plain", "Missing old fitting defaults plain v%d" % version)
			for key: String in data: check(same(result.state.to_dict()[key], data[key]), "Every stored historical default field preserved v%d:%s" % [version, key])
			check(result.state.attack == 16 and result.state.defense == 4 and result.state.effective_attack() == 16 and result.state.effective_defense() == 4, "Plain migration never modifies base or effective defaults")
			var path := folder + "/migrate%d.json" % version
			check(result.state.save_game(path) == OK and JSON.parse_string(bytes(path).get_string_from_utf8()).version == 16, "Every normal save upgrades to16, including plain")
			check(not FileAccess.file_exists(path + ".bak"), "Normal autosave promises no automatic backup")
		for value: Variant in [null, true, false, 0, 1, 1.0, [], {}, "", "PLAIN", "unknown", "edge "]:
			var malformed := data.duplicate(true); malformed.weapon_fitting = value
			check(not live.inspect_save_bytes(doc(malformed, version)).ok, "Present malformed fitting is never erased v%d:%s" % [version, str(value)])
		for key: String in ["weapon_fitting_unlocked", "weapon_fitting_stats", "weapon_fittingCandidate", "weapon_fitting_id"]:
			var malformed := data.duplicate(true); malformed[key] = false
			check(not live.inspect_save_bytes(doc(malformed, version)).ok, "Reserved fitting prefix rejects even in old layouts v%d:%s" % [version, key])
		for fitting: String in FITTINGS:
			var present := data.duplicate(true); present.weapon_fitting = fitting
			var locked: Dictionary = live.inspect_save_bytes(doc(present, version))
			check(locked.ok == (fitting == "plain"), "Present old optional fitting validates actual eligibility v%d:%s" % [version, fitting])
			present.quest_stage = 6; present.ending = "守望"; present.sect = "听潮阁"
			if present.has("sect_rank"): present.sect_rank = 1
			var unlocked: Dictionary = live.inspect_save_bytes(doc(present, version))
			check(unlocked.ok and unlocked.state.weapon_fitting == fitting, "Complete valid fitting is retained under historical header v%d:%s" % [version, fitting])
			if fitting != "plain":
				present["defense" if fitting == "edge" else "attack"] = 1 if fitting == "edge" else 3
				check(not live.inspect_save_bytes(doc(present, version)).ok, "Present old fitting cannot hide an incomplete cost v%d:%s" % [version, fitting])
		check(same(properties(live), before), "All historical inspections leave every live property unchanged")
		if not fixture.path.is_empty(): check(bytes(fixture.path) == fixture.bytes, "Source fixture bytes not rewritten")
	var earlier: Dictionary = JSON.parse_string(bytes("res://tests/fixtures/legacy_saves/schema_01_default.json").get_string_from_utf8()).player
	earlier.quest_stage = 5; earlier.sect = "听潮阁"
	var earlier_result: Dictionary = live.inspect_save_bytes(doc(earlier, 1))
	check(earlier_result.ok and earlier_result.state.quest_stage == 6 and earlier_result.state.weapon_fitting == "plain", "Original historical quest5/chosen-sect normalization remains plain without autoequip")
	var raw15: Dictionary = JSON.parse_string(bytes("res://tests/fixtures/weapon_fitting/schema_15_default.json").get_string_from_utf8()).player
	check(same(old15.new().to_dict(), raw15), "Pinned actual-PCK15 default matches true15 source serializer/current dependencies")
	var once := State.new(); once.weapon_fitting = "guard"
	check(once.load_game("res://tests/fixtures/weapon_fitting/schema_15_default.json") == OK and once.weapon_fitting == "plain", "Loading plain overwrites stale installed choice without autoequip")

func _legacy_progress_resources() -> void:
	for sect: String in SECTS:
		for plan: String in ["hold_for_inspection", "return_to_owner"]:
			for stage: int in range(8):
				var endings: Array = [""] if stage <= 4 else (["", "pause_batch", "cancel_proven"] if stage == 5 else ["pause_batch", "cancel_proven"])
				for ending: String in endings:
					var old = progress(old15.new(), sect, plan, stage, ending)
					var original: Dictionary = old.to_dict()
					check(old._stage_save_data(original, 15).ok, "Actual15 synthetic progressed positive control")
					var result: Dictionary = State.new().inspect_save_bytes(doc(original, 15))
					check(result.ok, "Every15 capstone state/ending and sect migrates")
					if not result.ok: continue
					var converted: Dictionary = result.state.to_dict()
					check(converted.weapon_fitting == "plain", "Completed old stories never autoequip")
					converted.erase("weapon_fitting")
					check(same(converted, original), "Every old field preserved across capstone/ending/sect migration")
					check(result.state.hp == 47 and result.state.qi == 0 and result.state.medicine == 1 and result.state.party_resources.shen.hp == 0 and result.state.party_resources.tang.hp == 1 and result.state.party_resources.qin.hp == 2 and result.state.party_roster == ["hero", "shen", "qin"], "Injured hero/downed deployed/wounded benched resources and roster unchanged")
	for stage: int in [0, 5, 6]:
		var old = old15.new(); old.quest_stage = stage
		if stage == 6: old.ending = "守望"; old.sect = "听潮阁"; old.sect_rank = 1
		var result: Dictionary = State.new().inspect_save_bytes(doc(old.to_dict(), 15))
		check(result.ok and result.state.weapon_fitting == "plain", "Original persists before and after unlock without capstone prerequisite")

func reject(data: Dictionary, version: Variant, label: String) -> void:
	var live = ready(); live.coins = 913; live.skill_cooldown = 4; live.party_battle_epoch = 77
	live.enemy_hp = 17; live.enemy_name = "sentinel"; live.battle_log.assign(["unchanged"])
	var slots := Slots.new(folder)
	var paths: Array[String] = [slots.path_for(0), slots.path_for(1), slots.path_for(1) + ".bak", folder + "/rejected.json"]
	for path: String in paths: write(path, "sentinel:".to_utf8_buffer() + path.to_utf8_buffer())
	write(paths[-1], doc(data, version))
	var before := properties(live); var olddisk := disk(paths)
	var inspected: Dictionary = live.inspect_save_bytes(bytes(paths[-1]))
	check(not inspected.ok, label + " inspection rejects")
	check(live.load_game(paths[-1]) != OK, label + " direct load rejects")
	check(same(properties(live), before) and disk(paths) == olddisk, label + " all live fields and primary/manual/backup/input bytes unchanged")
	var transfer := Transfer.new(folder)
	check(not transfer.preview_import(bytes(paths[-1]), 3).ok and disk(paths) == olddisk and not FileAccess.file_exists(slots.path_for(3)), label + " default-off transfer module validation refuses without writes")

func _modern_and_qualification() -> void:
	var good: Dictionary = ready().to_dict()
	for key: String in good:
		var bad := good.duplicate(true); bad.erase(key)
		reject(bad, 16, "Missing modern16 key:" + key)
	for value: Variant in [null, true, false, 0, 1, 1.0, [], {}, "", "plain ", "edge_guard", "unknown"]:
		var bad := good.duplicate(true); bad.weapon_fitting = value
		reject(bad, 16, "Wrong type/enum:" + str(value))
	for key: String in ["weapon_fitting_unlocked", "weapon_fitting_stats", "weapon_fittingCandidate", "weapon_fitting_id"]:
		var bad := good.duplicate(true); bad[key] = false
		reject(bad, 16, "Reserved prefix:" + key)
	for version: Variant in [0, -1, 17, 99, 16.5, "16", true, null, {}, []]: reject(good, version, "Unsupported/malformed version:" + str(version))
	for version: int in [-1, 0, 17, 99]: check(not State.new()._stage_save_data(good, version).ok, "Direct staging cannot bypass version validation")
	for version: int in [13, 14, 15, 16]:
		var data: Dictionary = JSON.parse_string(bytes("res://tests/fixtures/legacy_saves/schema_13_default.json").get_string_from_utf8()).player if version == 13 else (old14.new().to_dict() if version == 14 else (old15.new().to_dict() if version == 15 else good))
		var missing := data.duplicate(true); missing.erase("internal_unlocked")
		check(not State.new().inspect_save_bytes(doc(missing, version)).ok, "Internal since13 remains mandatory")
		if version >= 14:
			for key: String in State.Consignee.FIELDS:
				missing = data.duplicate(true); missing.erase(key)
				check(not State.new().inspect_save_bytes(doc(missing, version)).ok, "Consignee since14 remains mandatory:" + key)
		if version >= 15:
			for key: String in State.Capstone.FIELDS:
				missing = data.duplicate(true); missing.erase(key)
				check(not State.new().inspect_save_bytes(doc(missing, version)).ok, "Capstone since15 remains mandatory:" + key)
	for sect: String in SECTS:
		for fitting: String in FITTINGS:
			var s = ready(sect); var before: Dictionary = s.to_dict()
			var data: Dictionary = before.duplicate(true); data.weapon_fitting = fitting
			var result: Dictionary = s.inspect_save_bytes(doc(data))
			check(result.ok and same(result.state.to_dict(), data), "Every real sect can retain optional fitting immediately after opening")
			check(s.to_dict() == before, "Detached valid inspection is read-only")
	for sect: String in ["未入门", "unknown", ""]:
		for fitting: String in ["edge", "guard"]:
			var data := good.duplicate(true); data.sect = sect; data.sect_rank = 0; data.weapon_fitting = fitting
			reject(data, 16, "Quest6 without a real sect remains locked:" + sect)
	for stage: int in range(6):
		for fitting: String in ["edge", "guard"]:
			var data: Dictionary = State.new().to_dict(); data.quest_stage = stage; data.weapon_fitting = fitting
			reject(data, 16, "Uncompleted opening remains locked:%d" % stage)
	var plain_floor := good.duplicate(true); plain_floor.attack = 1; plain_floor.defense = 0; plain_floor.weapon_fitting = "plain"
	var plain_result: Dictionary = State.new().inspect_save_bytes(doc(plain_floor))
	check(plain_result.ok and same(plain_result.state.to_dict(), plain_floor), "Original fitting remains valid at existing attack1/defense0 floors")
	for fitting: String in ["edge", "guard"]:
		for amount: int in ([0, 1] if fitting == "edge" else [1, 2, 3]):
			var data := good.duplicate(true); data.weapon_fitting = fitting
			data["defense" if fitting == "edge" else "attack"] = amount
			reject(data, 16, "Full cost cannot be floor-clamped:" + fitting + str(amount))
		var boundary := good.duplicate(true); boundary.weapon_fitting = fitting
		boundary["defense" if fitting == "edge" else "attack"] = 2 if fitting == "edge" else 4
		var result: Dictionary = State.new().inspect_save_bytes(doc(boundary))
		check(result.ok and same(result.state.to_dict(), boundary), "Exact full-cost lower boundary remains valid")

func _direct_handler_and_projection() -> void:
	for candidate: Variant in [null, true, 1, [], {}, "unknown", "edge", "guard"]:
		var s := State.new(); var before := properties(s)
		check(not s.set_weapon_fitting(candidate).ok and same(properties(s), before), "Direct handler cannot bypass lock/type:" + str(candidate))
	for sect: String in SECTS:
		var s = ready(sect); s.hp = 13; s.qi = 0; s.medicine = 1
		for fitting: String in ["edge", "guard", "plain", "edge", "plain"]:
			var before: Dictionary = s.to_dict(); var expected: Dictionary = before.duplicate(true); expected.weapon_fitting = fitting
			check(s.set_weapon_fitting(fitting).ok and s.to_dict() == expected, "Direct explicit selection changes only enum")
			var persisted: Dictionary = s.to_dict(); var projection: Dictionary = s.fitting_projection()
			for repeat: int in range(10):
				check(s.fitting_projection() == projection and s.to_dict() == persisted, "Repeated projection never stacks or mutates bases")
			check(s.set_weapon_fitting(fitting).ok and not s.set_weapon_fitting(fitting).changed and s.to_dict() == persisted, "Same-choice is an idempotent no-op")
		for fitting: String in ["edge", "guard"]:
			s.battle_active = true; var before := properties(s)
			check(not s.set_weapon_fitting(fitting).ok and same(properties(s), before), "Direct handler refuses active battle")
			s.battle_active = false
	var s = ready(); s.defense = 1
	var before := properties(s)
	check(not s.set_weapon_fitting("edge").ok and same(properties(s), before), "Direct edge floor bypass rejected")
	s = ready(); s.attack = 3; before = properties(s)
	check(not s.set_weapon_fitting("guard").ok and same(properties(s), before), "Direct guard floor bypass rejected")
	s = ready(); s.consignee_stage = 5; before = properties(s)
	check(not s.set_weapon_fitting("edge").ok and same(properties(s), before), "Direct handler cannot bypass whole-save invalid progress")
	s = ready(); s.attack = 999; s.defense = 999
	check(s.set_weapon_fitting("edge").ok and s.effective_attack() == 1002 and s.attack == 999 and s.defense == 999, "Derived attack may exceed999 without touching persistent base")
	check(s.set_weapon_fitting("guard").ok and s.effective_defense() == 1001 and s.attack == 999 and s.defense == 999, "Derived defense may exceed999 without touching persistent base")
	s.reset_game(); check(s.weapon_fitting == "plain" and s.to_dict() == State.new().to_dict(), "New journey resets exactly to plain defaults")

func _roundtrip_slots_transfer() -> void:
	for sect: String in SECTS:
		for fitting: String in FITTINGS:
			var sub := folder + "/roundtrip-%s-%s" % [sect, fitting]; DirAccess.make_dir_recursive_absolute(sub)
			var slots := Slots.new(sub); var transfer := Transfer.new(sub)
			var s = progress(State.new(), sect, "return_to_owner", 7, "cancel_proven")
			check(s.set_weapon_fitting(fitting).ok, "Prepared fitted complete state")
			var saved: Dictionary = s.to_dict()
			check(s.save_game(slots.path_for(0)) == OK and JSON.parse_string(bytes(slots.path_for(0)).get_string_from_utf8()).version == 16, "Normal autosave writes16 for every choice")
			check(not FileAccess.file_exists(slots.path_for(0) + ".bak"), "Autosave does not silently introduce backup subsystem")
			for slot: int in [1, 2, 3]:
				check(slots.save_slot(s, slot) == OK, "Every manual slot writes16")
				var first := bytes(slots.path_for(slot)); var loaded := State.new()
				check(slots.load_slot(loaded, slot) == OK and same(loaded.to_dict(), saved), "Fitting/base/resources/story exact manual roundtrip")
				s.coins += 1; check(slots.save_slot(s, slot) == OK and bytes(slots.path_for(slot) + ".bak") == first, "Manual backup rotates exact old bytes")
				check(slots.load_backup(loaded, slot) == OK and same(loaded.to_dict(), saved), "Backup restores original enum and unmodified base/resource values")
				var export: Dictionary = transfer.export_slot(slot, true)
				check(export.ok and export.version == 16 and export.bytes == first, "Default-off transfer module validates exact16 backup bytes")
				s.coins -= 1
			var target := sub + "/import"; DirAccess.make_dir_recursive_absolute(target)
			var receiver := Transfer.new(target); var subject := bytes(slots.path_for(0)); var preview: Dictionary = receiver.preview_import(subject, 1)
			check(preview.ok and preview.version == 16 and receiver.commit_import(preview.token).ok and bytes(Slots.new(target).path_for(1)) == subject, "Explicit module import preserves exact16 raw bytes")
			var before := properties(s); var paths: Array[String] = [slots.path_for(0), slots.path_for(1), slots.path_for(1) + ".bak"]
			var before_disk := disk(paths)
			check(s.save_game(sub + "/missing/failure.json") != OK and same(properties(s), before) and disk(paths) == before_disk, "Save failure preserves selected enum, every live field and existing files")
	var sub := folder + "/upgrade15"; DirAccess.make_dir_recursive_absolute(sub)
	var slots := Slots.new(sub); var original := bytes("res://tests/fixtures/weapon_fitting/schema_15_default.json")
	write(slots.path_for(1), original)
	var current := State.new(); check(slots.load_slot(current, 1) == OK and current.weapon_fitting == "plain" and bytes(slots.path_for(1)) == original, "Loading15 never rewrites historical bytes")
	check(slots.save_slot(current, 1) == OK and bytes(slots.path_for(1) + ".bak") == original and JSON.parse_string(bytes(slots.path_for(1)).get_string_from_utf8()).version == 16, "Explicit manual save upgrades15 and keeps genuine15 backup")
	current.weapon_fitting = "unknown"
	var invalid_before := properties(current); var protected: Array[String] = [slots.path_for(1), slots.path_for(1) + ".bak"]
	var saved_bytes := disk(protected)
	check(current.save_game(slots.path_for(1)) == ERR_FILE_CORRUPT and same(properties(current), invalid_before) and disk(protected) == saved_bytes, "Invalid in-memory fitting refuses a normal save without touching genuine16 primary or15 backup")

func _old15_source_gate() -> void:
	var old = old15.new(); old.coins = 913; old.skill_cooldown = 3; old.enemy_hp = 17
	old.party_battle_epoch = 53; old.receipt_settlement = {"sentinel": [1, 2]}
	var path := folder + "/current16-subject.json"
	check(State.new().save_game(path) == OK, "Current serializer creates genuine16 source-gate subject")
	var original := bytes(path); var before := properties(old)
	check(old.load_game(path) == ERR_FILE_UNRECOGNIZED and same(properties(old), before) and bytes(path) == original, "Frozen15 source with CURRENT dependencies rejects16 without any live/disk mutation")
	var control := folder + "/source15-control.json"
	check(old.save_game(control) == OK and old.load_game(control) == OK, "Frozen15 source/current-dependency positive15 control")
	check(FileAccess.get_sha256(Frozen15.OLD_PATH) == Frozen15.OLD_SHA, "Historical15 source bytes stay pinned")
