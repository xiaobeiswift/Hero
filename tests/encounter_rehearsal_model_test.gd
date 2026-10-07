extends "res://tests/weapon_fitting_trial_model_test.gd"
## Genuine progression fixtures, source-pinned original12 parity and detached
## resource/metrics guards. Scene proximity and native/browser UI are separate.
const Rehearsal = preload("res://scripts/encounter_rehearsal_rules.gd")
const LEGACY_SHA256: String = "4a0869cd675db68393c5dbff08ce19be5dd1a4cca032963e339fb703decb7fe7"
const LEGACY_HEADER: String = "class_name AutomaticPartyCombat\n"
const PARITY_HEADER: String = "class_name AutomaticPartyCombatWeb37Parity\n"
const EXPECTED_PARITY_ROWS: int = 50 # 12 original encounters × 2 rosters × 2 policies + 2 ordinary fitting runs.
var earned_consignee_three
var rehearsal_rows: Array[Dictionary] = []
var seen_outcomes: Dictionary = {}
var fixture_dir: String

func _journey_win(s, encounter: String, label: String) -> bool:
	var won: bool = super._journey_win(s, encounter, label)
	if won and encounter == "heting_consignee": earned_consignee_three = s._detached_persistent_state()
	return won

func _run() -> void:
	fixture_dir = "user://earned-rehearsal-%d" % OS.get_process_id()
	check(DirAccess.make_dir_recursive_absolute(fixture_dir) == OK, "Fresh isolated rehearsal fixture storage")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--legacy-model="): legacy_model_path = argument.trim_prefix("--legacy-model=")
	var source = _earned_capstone("听潮阁", true, true)
	if source == null: _finish_rehearsal(); return
	var locked = source._detached_persistent_state(); locked.map_id = "qingwei"
	check(locked.rehearsal_options().options.size() == 1, "Pre-Liang victory reveals only already beaten Du Hui")
	check(not locked.start_encounter_rehearsal("capstone_authorizer"), "Real evidence without victory never unlocks Liang")
	if not _journey_win(source, "capstone_authorizer", "earned_rehearsal_unlock"): _finish_rehearsal(); return
	_test_earned_ranges(source)
	source.map_id = "qingwei"
	_test_rehearsal_factory(source)
	_test_rehearsal_rejections(source)
	_test_rehearsal_keys(source)
	_test_rehearsal_transactions(source)
	_test_rehearsal_identity(source)
	_test_rehearsal_old_save_and_history(source)
	_test_rehearsal_rank_boundary(source)
	if _legacy_parity_source_valid():
		_test_trial_default_parity(source)
	_assert_complete_original_parity()
	for outcome: String in ["win", "defeat", "flee"]: check(seen_outcomes.has(outcome), "Accepted trace actually covers " + outcome)
	_finish_rehearsal()

## The retained original remains untouched. This external loadable copy only
## renames its global class to avoid colliding with the current project class.
## Reversing that one exact first line must reconstruct the pinned source hash.
func _legacy_parity_source_valid() -> bool:
	var exists: bool = not legacy_model_path.is_empty() and FileAccess.file_exists(legacy_model_path)
	check(exists, "External class-name-only Web37 parity copy is required")
	if not exists: return false
	var adapted: String = FileAccess.get_file_as_string(legacy_model_path)
	var header_valid: bool = adapted.begins_with(PARITY_HEADER)
	check(header_valid, "External parity copy has the unique class-name first line")
	if not header_valid: return false
	var reconstructed: String = LEGACY_HEADER + adapted.substr(PARITY_HEADER.length())
	var bytes_valid: bool = reconstructed.sha256_text() == LEGACY_SHA256
	check(bytes_valid, "Reversing only the first class-name line reconstructs exact pinned Web37 bytes")
	return bytes_valid

func _assert_complete_original_parity() -> void:
	check(Rules.ENCOUNTER_IDS.size() == 12 and fitting_rows.size() == EXPECTED_PARITY_ROWS, "Mandatory full parity coverage: all 50 original and ordinary fitting traces")
	for count: int in [1, 4]:
		for encounter: String in Rules.ENCOUNTER_IDS:
			for policy: bool in [false, true]:
				var matches: int = 0
				for row: Dictionary in fitting_rows:
					if row.label == encounter + "/" + str(count) and row.policy == policy: matches += 1
				check(matches == 1, "Exactly one mandatory original trace " + encounter + "/" + str(count) + "/" + str(policy))
	var ordinary: int = 0
	for row: Dictionary in fitting_rows:
		if row.label == "ordinary borrowed plain" and row.policy == true: ordinary += 1
	check(ordinary == 2, "Both original ordinary-fitting parity traces are mandatory")

func _at_courtyard(source):
	var s = source._detached_persistent_state()
	s.map_id = "qingwei"
	return s

func _assert_unlocked(source, encounter: String, stage: int) -> void:
	var s = _at_courtyard(source)
	var before: Dictionary = s.to_dict()
	check(s.rehearsal_preview(encounter).ok, "Genuinely earned stage preview " + encounter + "/" + str(stage))
	check(s.start_encounter_rehearsal(encounter), "Genuinely earned stage start " + encounter + "/" + str(stage))
	check(s.to_dict() == before and s._party_consignee_identity.is_empty() and s._party_capstone_identity.is_empty(), "Rehearsal never installs real-story entry capability")
	s._clear_battle()
	check(s.to_dict() == before, "Discarding untouched rehearsal leaves real journey exact")

func _test_earned_ranges(source) -> void:
	check(earned_consignee_three != null and earned_consignee_three.consignee_stage == 3, "Capture actual Du Hui victory, not injected stage")
	if earned_consignee_three != null:
		_assert_unlocked(earned_consignee_three, "heting_consignee", 3)
		var delivery = earned_consignee_three._detached_persistent_state()
		check(delivery.take_consignee_cargo(delivery.Consignee.BATCH, delivery.Consignee.SOURCE), "Genuine retained cargo advances stage4")
		check(delivery.consignee_stage == 4 and delivery.rehearsal_options().options.size() == 1, "Valid stage4 cargo state retains earned Du Hui choice")
		var delivery_before: Dictionary = delivery.to_dict()
		check(not delivery.start_encounter_rehearsal("heting_consignee") and delivery.to_dict() == delivery_before, "Carrying cargo in Heting cannot start a distant courtyard rehearsal")
		var invalid_travel = _at_courtyard(delivery)
		check(not invalid_travel.rehearsal_preview("heting_consignee").ok, "Unparked stage4 cargo cannot bypass the unchanged map/save constraint")
		check(delivery.park_consignee_cargo() and delivery.consignee_stage == 3, "Actual cargo parking restores valid travel boundary")
		_assert_unlocked(delivery, "heting_consignee", 3)
	_assert_unlocked(source, "heting_consignee", 5)
	var cap = source._detached_persistent_state()
	_assert_unlocked(cap, "capstone_authorizer", 4)
	check(cap.classify_capstone_orders(cap.Capstone.CORRECT_PARTITION).ok, "Genuine four-order classification")
	_assert_unlocked(cap, "capstone_authorizer", 5)
	check(cap.choose_capstone_plan("pause_batch"), "Genuine capstone draft")
	cap.map_id = "sluice"
	check(cap.confirm_capstone_disposition("pause_batch"), "Genuine capstone disposition")
	_assert_unlocked(cap, "capstone_authorizer", 6)
	cap.map_id = "qingwei"
	check(cap.finish_capstone_homecoming(), "Genuine homecoming")
	_assert_unlocked(cap, "capstone_authorizer", 7)

func _test_rehearsal_factory(source) -> void:
	for roster: Array in [["hero"], ["hero", "shen"], ["hero", "qin", "tang"], ["hero", "qin", "tang", "shen"]]:
		for formation: String in ["并肩", "护后"]:
			var s = _at_courtyard(source)
			check(s.set_formation(formation) and s.set_party_roster(roster), "Actual selected roster/order/formation")
			s.hp = 1; s.qi = 0; s.medicine = 0
			for id: String in s.party_resources: s.party_resources[id] = {"hp": 0, "qi": 0}
			for fitting: String in ["plain", "edge", "guard"]:
				check(s.set_weapon_fitting(fitting).ok, "Current installed fitting")
				for encounter: String in Rehearsal.IDS:
					var before: Dictionary = s.to_dict()
					var built: Dictionary = Rehearsal.build(s, encounter)
					check(built.ok and _frozen_tree(built), "Authentic immutable factory")
					if not built.ok: continue
					var model = Rules.new()
					check(model.configure_encounter_rehearsal(s, encounter), "Detached model entry")
					var view: Dictionary = model.snapshot()
					check(view.resource_policy == Rehearsal.POLICY and view.encounter_id == encounter, "Resource policy distinct from exact original encounter identity")
					check(view.medicine == 3 and view.medicine_heal == 40 and view.formation == formation, "Borrowed medicine and actual formation")
					var ids: Array = []
					for actor: Dictionary in view.actors:
						ids.append(actor.id)
						check(actor.hp == actor.max_hp and actor.qi == actor.max_qi, "Only virtual selected actors refill")
						check(actor.categories.keys().size() == 3, "Exactly three fixed skill categories retained")
					check(ids == roster, "Selected party/order exact; no extra recruited actors")
					check(view.actors[0].attack == s.effective_attack() and view.actors[0].defense == s.effective_defense(), "Installed fitting applies exactly once")
					var real_team: Dictionary = built.team.duplicate(true); real_team.medicine_heal = 45
					var original = Rules.new(); check(original.configure(real_team, encounter), "Original-source encounter comparison configures")
					check(original.snapshot().enemies == view.enemies and original.snapshot().enemy_intents == view.enemy_intents, "Exact original enemies and first announced timing/targets")
					check(not model.configure_encounter_rehearsal(s, encounter), "Repeated configure rejected")
					check(s.to_dict() == before, "Factory and model snapshots preserve real zero/downed/benched resources")
	var ephemeral = _at_courtyard(source)
	var reference: WeakRef = weakref(ephemeral)
	var detached = Rules.new(); check(detached.configure_encounter_rehearsal(ephemeral, "heting_consignee"), "Ephemeral genuine state configures")
	ephemeral = null
	check(reference.get_ref() == null and detached.snapshot().active, "Model retains no live or staged State reference")

func _test_rehearsal_rejections(source) -> void:
	var fresh = State.new()
	check(fresh.rehearsal_options().options.is_empty(), "New journey has no hidden enemy cards")
	for id: Variant in [null, true, 1, {}, [], "", "story", "training", "courtyard_practice", "heting_consignee "]:
		var s = _at_courtyard(source); var before: Dictionary = s.to_dict()
		check(not s.start_encounter_rehearsal(id) and s.to_dict() == before and s.party_session == null, "Malformed or non-whitelisted target atomically rejected")
	for supplied: Variant in [null, {}, source.to_dict(), Rehearsal.build(source, "heting_consignee")]:
		var model = Rules.new()
		check(not model.configure_encounter_rehearsal(supplied, "heting_consignee") and model.snapshot().phase == "unconfigured", "Caller payload is not an authentic State")
	for mode: String in ["map", "pending", "active", "hero_down", "malformed", "duplicate", "unearned", "overflow"]:
		var s = _at_courtyard(source)
		match mode:
			"map": s.map_id = "heting"
			"pending": s._party_pending_token = 8
			"active": s.battle_active = true
			"hero_down": s.hp = 0
			"malformed": s.medicine = -1
			"duplicate": s.party_roster.append("hero")
			"unearned": s.capstone_stage = 3
			"overflow": s.capstone_stage = 8
		var before: Dictionary = s.to_dict()
		check(not s.start_encounter_rehearsal("capstone_authorizer") and s.to_dict() == before and s.party_session == null, "State/model guard cannot bypass " + mode)

func _test_rehearsal_keys(source) -> void:
	var s = _at_courtyard(source)
	var key: String = s.rehearsal_preview("heting_consignee").metadata.comparison_key
	for mode: String in ["formation", "roster", "order", "fitting", "art", "rank", "internal", "lightness", "attack", "defense", "max_hp", "max_qi", "level", "equipment", "armor"]:
		var changed = _at_courtyard(s)
		match mode:
			"formation": changed.set_formation("护后" if changed.formation == "并肩" else "并肩")
			"roster": changed.set_party_roster(["hero"])
			"order": changed.set_party_roster(["hero", "qin", "tang", "shen"])
			"fitting": changed.set_weapon_fitting("edge")
			"art": changed.equip_art("照夜一线" if changed.equipped_art != "照夜一线" else changed.sect_art())
			"rank": changed.art_uses[changed.equipped_art] += 15
			"internal": changed.internal_unlocked = not changed.internal_unlocked
			"lightness": changed.lightness_unlocked = not changed.lightness_unlocked
			"equipment": changed.equipment = "青钢剑"
			"armor": changed.armor = "轻纱内甲"
			_: changed.set(mode, changed.get(mode) + 1)
		var preview: Dictionary = changed.rehearsal_preview("heting_consignee")
		check(preview.ok and preview.metadata.comparison_key != key, "Comparison changes with actual input " + mode)
	var spent = _at_courtyard(s); spent.hp = 1; spent.qi = 0; spent.medicine = 0
	for id: String in spent.party_resources: spent.party_resources[id] = {"hp": 0, "qi": 0}
	check(spent.rehearsal_preview("heting_consignee").metadata.comparison_key == key, "Only real spent/downed resources normalize to same virtual inputs")
	check(s.rehearsal_preview("capstone_authorizer").metadata.comparison_key != key, "Encounter changes comparison identity")
	for care: String in ["shore", "mobile"]:
		var changed = _at_courtyard(s)
		check(changed.begin_shen_care() and changed.consult_shen_patient() and changed.inspect_shen_shelter() and changed.choose_shen_care(care) and changed.post_shen_notice(), "Actual Shen care history")
		check(changed.rehearsal_preview("heting_consignee").metadata.comparison_key != key, "Actual companion bonuses split comparisons")

func _drive_rehearsal(s, encounter: String, policy: String) -> Dictionary:
	var path: String = fixture_dir + "/checkpoint.json"
	check(s.save_game(path) == OK, "Write good real journey checkpoint before run")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	s.coins += 1 # Unsaved legitimate difference catches accidental autosaves.
	var before: Dictionary = s.to_dict()
	check(s.start_encounter_rehearsal(encounter), "State starts earned rehearsal")
	if not s.battle_active: return {}
	var start: Dictionary = s.party_battle_snapshot()
	var losses: Dictionary = {}; var loss: int = 0; var medicine: int = 0; var attacks: int = 0; var rounds: int = 0; var steps: int = 0
	var basics: Dictionary = {}; var used_skills: Dictionary = {}
	for actor: Dictionary in start.actors: losses[actor.id] = 0
	while s.battle_active and steps < 1000:
		var item_actor: String = _plan(s.party_session) if policy == "queued" else ""
		var tx: Dictionary
		if policy == "flee": tx = s.party_battle_action("flee")
		elif item_actor.is_empty(): tx = s.advance_party_battle()
		else: s.select_party_actor(item_actor); tx = s.party_battle_action("item")
		check(tx.accepted, "Accepted rehearsal action progresses")
		if not tx.accepted: break
		steps += 1
		_check_transaction(tx, used_skills)
		for actor: Dictionary in tx.before.actors:
			var actual: int = maxi(0, int(actor.hp) - int(_actor(tx.after, actor.id).hp))
			losses[actor.id] += actual; loss += actual
		medicine += int(tx.before.medicine) - int(tx.after.medicine)
		for event: Dictionary in tx.events:
			check(event.type != "proficiency", "Virtual martial skills never award proficiency")
			if event.type == "action" and event.get("action_id") == "enemy:attack": attacks += 1
			if event.type == "round_end": rounds += 1
			if event.type == "action" and event.get("action_id") == "attack":
				var basic_key: String = str(tx.before.round) + "/" + event.source_id
				check(not basics.has(basic_key), "At most one automatic basic per living actor/round")
				basics[basic_key] = true
		var metrics: Dictionary = s.party_session.rehearsal_snapshot().metrics
		check(metrics.actual_hp_lost_by_actor == losses and metrics.total_actual_hp_lost == loss and metrics.medicine_used == medicine, "Metrics equal capped accepted resource deltas")
		check(metrics.enemy_attacks_executed == attacks and metrics.completed_rounds == rounds and metrics.accepted_transactions == steps, "Metrics count accepted attacks/rounds/tokens only")
		check(metrics.outcome == tx.after.outcome and metrics.terminal_round == (0 if tx.after.active else int(tx.after.round)), "Terminal/display round distinctions exact")
		check(s.to_dict() == before and FileAccess.get_file_as_bytes(path) == bytes, "Every accepted action preserves all real fields and disk bytes")
		check(s.save_game(path) == ERR_BUSY and s.load_game(path) == ERR_BUSY, "Active and pending token block save/load")
		check(not s.start_encounter_rehearsal(encounter), "Repeated entry during pending presentation rejected")
		check(not s.finish_party_presentation(tx.epoch + 1, tx.token).accepted and not s.finish_party_presentation(tx.epoch, tx.token + 9999).accepted, "Wrong epoch/token cannot settle")
		s.party_session._record_rehearsal_transaction(tx, true)
		check(s.party_session.rehearsal_snapshot().metrics == metrics, "Duplicate metric collection cannot double count")
		var history_size: int = s.rehearsal_comparison_snapshot().results.size()
		var done: Dictionary = s.finish_party_presentation(tx.epoch, tx.token)
		check(done.accepted and s.to_dict() == before, "Presentation and settlement preserve all real state")
		check(not s.finish_party_presentation(tx.epoch, tx.token).accepted, "Duplicate presentation rejected")
		if not tx.after.active:
			check(done.settled and done.settlement.practice and done.settlement.rehearsal and not done.settlement.awarded and done.settlement.reward_xp == 0 and done.settlement.coin_change == 0, "Virtual terminal never grants reward or real defeat recovery")
			check(s.rehearsal_comparison_snapshot().results.size() == mini(2, history_size + 1), "Only acknowledged terminal adds one result")
	check(not s.battle_active and s.to_dict() == before and FileAccess.get_file_as_bytes(path) == bytes, "Terminal path remains detached from live state and saved bytes")
	var result: Dictionary = s.party_session.rehearsal_snapshot()
	if not result.is_empty(): seen_outcomes[result.metrics.outcome] = true
	if start.actors.size() == 4 and rounds > 0:
		for actor: Dictionary in start.actors: check(basics.has("1/" + actor.id), "Every initially living party member earns first-round automatic basic")
	rehearsal_rows.append({"encounter": encounter, "policy": policy, "actors": start.actors.size(), "metrics": result.metrics})
	return result

func _test_rehearsal_transactions(source) -> void:
	for encounter: String in Rehearsal.IDS:
		for count: int in [1, 4]:
			for policy: String in ["idle", "queued", "flee"]:
				var s = _at_courtyard(source)
				check(s.set_party_roster(["hero"] if count == 1 else ["hero", "qin", "tang", "shen"]), "Actual selected transaction roster")
				s.hp = 1; s.qi = 0; s.medicine = 0
				for id: String in s.party_resources: s.party_resources[id] = {"hp": 0, "qi": 0}
				_drive_rehearsal(s, encounter, policy)
	var weak = _at_courtyard(source)
	weak.set_party_roster(["hero"]); weak.attack = 1; weak.defense = 0
	_drive_rehearsal(weak, "capstone_authorizer", "idle")

func _test_rehearsal_identity(source) -> void:
	for mode: String in ["epoch", "encounter", "policy", "session", "persistent", "enemy", "provenance", "actor", "outcome", "resources", "formation", "skill_flag"]:
		var s = _at_courtyard(source)
		check(s.start_encounter_rehearsal("heting_consignee"), "Identity guard starts")
		var tx: Dictionary = s.party_battle_action("flee")
		check(tx.accepted, "Authentic terminal awaits presentation")
		match mode:
			"epoch": s.party_battle_epoch += 1
			"encounter": s._party_encounter = "capstone_authorizer"
			"policy": s._party_resource_policy = "real"
			"session":
				var other = Rules.new(); other.configure_encounter_rehearsal(_at_courtyard(source), "heting_consignee"); s.party_session = other
			"persistent": s.coins += 1
			"enemy": s.party_session._enemies[0].attack += 1
			"provenance": s.party_session._consignee_entry.du_hui_max_hp += 1
			"actor": s.party_session._actors[0].attack += 1
			"outcome": s.party_session._outcome = "win"
			"resources": s.party_session._medicine = 4
			"formation": s.party_session._formation = "护后" if s.formation == "并肩" else "并肩"
			"skill_flag": s.party_session._actors[0].internal_unlocked = not s.internal_unlocked
		var before: Dictionary = s.to_dict()
		check(not s.finish_party_presentation(tx.epoch, tx.token).accepted and s.to_dict() == before, "Tampered rehearsal cannot settle: " + mode)
		check(s.rehearsal_comparison_snapshot().results.is_empty(), "Rejected identity cannot create comparison")
		s._clear_battle()
		check(s.to_dict() == before, "Interrupted invalid session cannot rollback real state")
	var s = _at_courtyard(source)
	var before: Dictionary = s.to_dict()
	check(s.start_encounter_rehearsal("heting_consignee"), "Interruption starts")
	var old: Dictionary = s.advance_party_battle()
	s._clear_battle()
	check(s.to_dict() == before and s.rehearsal_comparison_snapshot().results.is_empty(), "Mid-presentation release keeps journey and omits incomplete result")
	check(s.start_encounter_rehearsal("heting_consignee"), "Retry after interruption revalidates input")
	check(not s.finish_party_presentation(old.epoch, old.token).accepted, "Stale prior-attempt token cannot advance replacement")
	s._clear_battle()

func _test_rehearsal_old_save_and_history(source) -> void:
	var s = _at_courtyard(source)
	for index: int in 3: _drive_rehearsal(s, "heting_consignee", "flee")
	check(s.rehearsal_comparison_snapshot().results.size() == 2, "Recent-two bound after repeated valid attempts")
	var history: Dictionary = s.rehearsal_comparison_snapshot()
	check(s.load_game(fixture_dir + "/missing.json") != OK and s.rehearsal_comparison_snapshot() == history, "Failed load preserves recent completed history")
	check(s.set_weapon_fitting("edge").ok and s.rehearsal_comparison_snapshot().results.is_empty(), "Changed loadout immediately hides incompatible results")
	_drive_rehearsal(s, "heting_consignee", "flee")
	check(s.rehearsal_comparison_snapshot().results.size() == 1, "Changed inputs begin fresh comparison group")
	var path: String = fixture_dir + "/history.json"
	check(s.save_game(path) == OK and s.load_game(path) == OK and s.rehearsal_comparison_snapshot().results.is_empty(), "Successful load clears session-only history")
	var old: Dictionary = source.to_dict(); old.erase("weapon_fitting")
	var bytes: PackedByteArray = JSON.stringify({"version": 15, "player": old}).to_utf8_buffer()
	var restored: Dictionary = s.inspect_save_bytes(bytes)
	check(restored.ok and restored.state.weapon_fitting == "plain", "Existing v15 migration defaults fitting; no new save field required")
	if restored.ok:
		var legacy = _at_courtyard(restored.state)
		check(legacy.rehearsal_options().options.size() == 2 and legacy.start_encounter_rehearsal("capstone_authorizer"), "Old genuine earned journey unlocks only its proven encounters")
		legacy._clear_battle()
	check(not s.to_dict().has("resource_policy") and not s.to_dict().has("encounter_rehearsal") and State.SAVE_VERSION == 16, "Schema and persistent save payload unchanged")
	s.reset_game(); check(s.rehearsal_comparison_snapshot().results.is_empty() and s.rehearsal_options().options.is_empty(), "New journey clears history and earned choices")

func _test_rehearsal_rank_boundary(source) -> void:
	var s = _at_courtyard(source)
	s.art_uses[s.equipped_art] = 4
	var virtual = Rules.new(); check(virtual.configure_encounter_rehearsal(s, "capstone_authorizer"), "Threshold-boundary virtual model")
	var built: Dictionary = Rehearsal.build(s, "capstone_authorizer")
	var team: Dictionary = built.team.duplicate(true); team.medicine_heal = 45
	var real = Rules.new(); check(real.configure(team, "capstone_authorizer"), "Threshold-boundary original model")
	for model in [real, virtual]:
		check(model.queue_skill("hero", "art:" + s.equipped_art, "liang_zhen").ok, "Queue exact same threshold martial skill")
		var tx: Dictionary = model.advance(); check(tx.accepted and model.complete_presentation(tx.token), "Execute threshold martial skill")
	check(_actor(real.snapshot(), "hero").art_uses[s.equipped_art] == 5 and _actor(virtual.snapshot(), "hero").art_uses[s.equipped_art] == 4, "Real proficiency growth retained; rehearsal proficiency intentionally frozen")
	check(real.snapshot().enemies == virtual.snapshot().enemies and real.snapshot().enemy_intents == virtual.snapshot().enemy_intents, "Initial same skill damage/enemy cadence exact before later real rank benefits")

func _finish_rehearsal() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			var file: FileAccess = FileAccess.open(argument.trim_prefix("--output="), FileAccess.WRITE)
			check(file != null, "Rehearsal source report opens")
			if file != null:
				file.store_string(JSON.stringify({"checks": checks, "failures": failures, "rows": rehearsal_rows, "original_parity": fitting_rows, "scope": "Source model/earned State isolation/metrics/original12 parity only; scene, rendered UI, exported pack and browser are separate."}, "\t")); file.close()
	print("%s: %d earned encounter rehearsal checks; %d virtual traces; %d original parity traces" % ["PASS" if failures == 0 else "FAIL", checks, rehearsal_rows.size(), fitting_rows.size()])
	quit(0 if failures == 0 else 1)
