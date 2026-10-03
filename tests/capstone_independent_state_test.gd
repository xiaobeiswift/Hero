extends SceneTree
## Synthetic mechanics only. Every tested win/flee/defeat uses real automatic transactions.
const State = preload("res://scripts/game_state.gd")
const Quest = preload("res://scripts/volume_one_capstone_rules.gd")
const Driver = preload("res://tests/automatic_state_test_driver.gd")
const Fixture = preload("res://tests/capstone_independent_fixture_producer.gd")
class ReentrantState extends State:
	var callback_count: int = 0
	var observed_stage: int = -1
	var reentry_accepted: bool = false
	func gain_xp(amount: int) -> Array[String]:
		callback_count += 1
		observed_stage = capstone_stage
		reentry_accepted = Capstone.finish_homecoming(self)
		return super.gain_xp(amount)
var checks := 0
var failures := 0
var folder: String
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _init() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): quit(2); return
	folder = "user://capstone-state-independent-%d" % Time.get_ticks_usec()
	check(DirAccess.make_dir_recursive_absolute(folder) == OK, "Isolated state fixture root")
	_stages()
	_adversaries()
	_helpers_aliases()
	_rewards()
	_resources()
	print("INDEPENDENT_STATE_RESULT checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
func ready(prior: String = "hold_for_inspection"):
	var script := Fixture.old_reader()
	check(script != null, "Authentic pinned14 producer available")
	if script == null: return State.new()
	var old = script.new()
	for outcome: bool in Fixture.apply_progress(old, prior): check(outcome, "Synthetic explicit companion history/recruit")
	# Read actual14 serialization, not current15 data relabeled as14.
	old.receipt_stage = 1
	var bytes := JSON.stringify({"version": old.SAVE_VERSION, "player": old.to_dict()}, "\t").to_utf8_buffer()
	var imported: Dictionary = State.new().inspect_save_bytes(bytes)
	check(imported.ok, "Independent real14 progressed fixture migrates")
	if not imported.ok: return State.new()
	var s = imported.state
	s.attack = 900; s.defense = 900
	return s
func clone(s):
	return s._detached_persistent_state()
func snapshot(s) -> Dictionary:
	return {"data": s.to_dict(), "battle": s.party_battle_snapshot(), "active": s.battle_active, "token": s._party_pending_token, "epoch": s.party_battle_epoch, "kind": s.battle_kind, "identity": s._party_capstone_identity.duplicate(true)}
func unchanged_except(before: Dictionary, after: Dictionary, keys: Array) -> bool:
	var a := before.duplicate(true); var b := after.duplicate(true)
	for key: String in keys: a.erase(key); b.erase(key)
	return a == b
func retry_boundary(s, label: String) -> void:
	var path := folder + "/atomic-boundary.json"
	if not FileAccess.file_exists(path): check(State.new().save_game(path) == OK, "Initialize old good checkpoint")
	var bytes := FileAccess.get_file_as_bytes(path); var data: Dictionary = s.to_dict()
	check(DirAccess.make_dir_absolute(path + ".tmp") == OK, "Own conflicting temporary directory:" + label)
	check(s.save_game(path) != OK and s.to_dict() == data and FileAccess.get_file_as_bytes(path) == bytes, "Failed same-target save leaves accepted result and old disk exact:" + label)
	check(DirAccess.remove_absolute(path + ".tmp") == OK, "Remove only own empty fixture conflict")
	check(s.save_game(path) == OK and s.to_dict() == data, "Retry serializes result without rerunning action:" + label)
func to_three(s) -> void:
	check(s.begin_capstone(), "Begin at completed old handover"); retry_boundary(s, "referral")
	s.map_id = "frostbridge"
	check(s.reveal_capstone_letter(), "Return original letter"); retry_boundary(s, "letter")
	check(Quest.goal(s).site_id == "chapter_clerk", "Proof objective corrected to clerk")
	check(s.resolve_capstone_evidence(Quest.CORRECT_ANSWER).correct, "Issued-chain proof before battle"); retry_boundary(s, "evidence")
func terminal(s) -> Dictionary:
	var tx: Dictionary = Driver.terminal_next(s)
	check(tx.get("accepted", false) and not tx.after.active and s.battle_active, "Real terminal awaiting presentation")
	return tx
func win(s) -> bool:
	var before: Dictionary = s.to_dict()
	check(s.start_party_battle("capstone_authorizer") and s.to_dict() == before, "Entry adds no heal, XP or book")
	var tx := terminal(s)
	if not tx.get("accepted", false): return false
	var accepted: Dictionary = s.to_dict()
	var result: Dictionary = s.finish_party_presentation(tx.epoch, tx.token)
	check(result.accepted and result.settled and result.outcome == "win" and s.capstone_stage == 4, "Accepted real victory grants only stage4 book")
	if not result.accepted: return false
	check(not result.settlement.awarded and result.settlement.reward_xp == 0 and s.coins == before.coins and s.xp == before.xp and s.level == before.level, "No victory reward")
	check(unchanged_except(accepted, s.to_dict(), ["capstone_stage", "victories"]), "Victory preserves every other accepted field")
	check(not s.finish_party_presentation(tx.epoch, tx.token).accepted and not s.start_party_battle("capstone_authorizer"), "Duplicate victory and refarm rejected")
	retry_boundary(s, "victory")
	return true
func _stages() -> void:
	for prior: String in ["hold_for_inspection", "return_to_owner"]:
		for receipt: int in range(4):
			for ending: String in Quest.PLANS:
				var s = ready(prior); s.receipt_stage = receipt
				var before: Dictionary = s.to_dict()
				to_three(s)
				check(unchanged_except(before, s.to_dict(), ["capstone_stage", "map_id"]), "Prebattle keeps old cargo/witness/receipt/resources exactly")
				if not win(s): continue
				before = s.to_dict()
				check(not s.choose_capstone_plan(ending) and not s.confirm_capstone_disposition(ending) and s.to_dict() == before, "Stage4 cannot draft or skip classification")
				check(s.classify_capstone_orders(Quest.CORRECT_PARTITION.duplicate(true)).correct and s.capstone_stage == 5 and s.capstone_draft == "", "Explicit exact classification persists separately")
				check(unchanged_except(before, s.to_dict(), ["capstone_stage"]), "Classification only changes stage"); retry_boundary(s, "classification")
				var path := folder + "/classified.json"
				check(s.save_game(path) == OK, "Empty draft stage5 persists")
				var restored := State.new(); check(restored.load_game(path) == OK and restored.to_dict() == s.to_dict(), "Reload retains completed classification")
				check(s.choose_capstone_plan(ending), "Reversible draft accepted"); retry_boundary(s, "draft")
				before = s.to_dict()
				check(not s.choose_capstone_plan(ending) and not s.confirm_capstone_disposition(ending) and s.to_dict() == before, "Same draft no-op; archive cannot finalize")
				check(s.choose_capstone_plan("") and s.choose_capstone_plan(ending), "Clear and rechoose draft")
				for row: Dictionary in Quest.order_rows(s): check(row.disposition == "pending", "Draft changes no operation")
				s.map_id = "sluice"; before = s.to_dict()
				check(s.confirm_capstone_disposition(ending) and s.capstone_stage == 6 and unchanged_except(before, s.to_dict(), ["capstone_stage", "capstone_ending"]), "Only explicit desk confirmation disposes batch without reward"); retry_boundary(s, "disposition")
				var rows: Array = Quest.order_rows(s)
				for i: int in range(4):
					check(rows[i].id == Quest.ORDER_IDS[i] and rows[i].evidence == ("proven_false" if i < 2 else "unverified") and rows[i].disposition == ("cancelled" if i < 2 else ("held" if ending == "pause_batch" else "continuing")), "Exact two-and-two finite dispositions")
				before = s.to_dict()
				check(not s.finish_capstone_homecoming() and not s.confirm_capstone_disposition(ending) and s.to_dict() == before, "No out-of-map or repeated ending payout")
				s.map_id = "qingwei"; before = s.to_dict(); var earned_before: int = earned(s)
				check(s.finish_capstone_homecoming() and s.capstone_stage == 7 and earned(s) - earned_before == 160 and s.coins == before.coins + 80, "Exactly equal fixed homecoming payout"); retry_boundary(s, "homecoming")
				check(s.party_resources == before.party_resources and s.receipt_stage == receipt and s.consignee_ending == prior and s.consignee_cargo_location == before.consignee_cargo_location, "Homecoming preserves companions and old local outcome")
				before = s.to_dict()
				check(not s.finish_capstone_homecoming() and Quest.goal(s).is_empty() and s.to_dict() == before, "Completed goal empty and duplicate payout absent")
				check(s.save_game(folder + "/missing/homecoming.json") != OK and s.to_dict() == before, "Failed final write preserves accepted paid model")
				check(s.save_game(path) == OK and s.to_dict() == before and restored.load_game(path) == OK and not restored.finish_capstone_homecoming(), "Save retry/load cannot replay payout")
func _adversaries() -> void:
	var s = ready(); to_three(s)
	check(s.start_party_battle("capstone_authorizer"), "Enter terminal adversary battle")
	var tx := terminal(s); if not tx.get("accepted", false): return
	var accepted = clone(s)
	var original_snapshot: Dictionary = s.party_session.snapshot()
	var before := snapshot(s)
	check(not s.finish_party_presentation(tx.epoch + 1, tx.token).accepted and not s.finish_party_presentation(tx.epoch, tx.token + 1).accepted and snapshot(s) == before, "Wrong token/epoch leave exact pending terminal")
	for key: String in ["hp", "qi", "medicine", "coins", "xp", "receipt_stage", "heting_bridge", "capstone_stage", "consignee_cargo_location", "party_resources", "art_uses", "position"]:
		match key:
			"hp": s.hp -= 1
			"qi": s.qi += 1
			"medicine": s.medicine += 1
			"coins": s.coins += 1
			"xp": s.xp += 1
			"receipt_stage": s.receipt_stage = 3
			"heting_bridge": s.heting_bridge = "west"
			"capstone_stage": s.capstone_stage = 4
			"consignee_cargo_location": s.consignee_cargo_location = "grain_boat"
			"party_resources": s.party_resources.tang.hp += 1
			"art_uses": s.art_uses[s.equipped_art] += 1
			"position": s.position += Vector2(1, 0)
		before = snapshot(s)
		check(not s.finish_party_presentation(tx.epoch, tx.token).accepted and snapshot(s) == before, "Stale entry field rejected before any commit:" + key)
		s._copy_persistent_from(accepted)
	for key: String in ["encounter_id", "epoch", "pending_token", "capstone_provenance", "actors", "enemies", "medicine", "outcome", "locked", "active"]:
		var forged := original_snapshot.duplicate(true)
		match key:
			"encounter_id": forged.encounter_id = "training"
			"epoch": forged.epoch += 1
			"pending_token": forged.pending_token += 1
			"capstone_provenance": forged.capstone_provenance = {}
			"actors": forged.actors[0].hp += 1
			"enemies": forged.enemies[0].hp = 1
			"medicine": forged.medicine += 1
			"outcome": forged.outcome = "defeat"
			"locked": forged.locked = false
			"active": forged.active = true
		before = snapshot(s)
		check(not s._party_terminal_plan(forged).ok and snapshot(s) == before, "Forged terminal snapshot rejected:" + key)
	check(s.finish_party_presentation(tx.epoch, tx.token).accepted, "Authentic restored terminal settles once")
	var old_epoch: int = tx.epoch; var old_token: int = tx.token
	s = ready(); to_three(s); check(s.start_party_battle("capstone_authorizer"), "Start another session")
	var flee: Dictionary = s.party_battle_action("flee"); check(flee.accepted and s.finish_party_presentation(flee.epoch, flee.token).accepted, "Flee old session")
	check(s.start_party_battle("capstone_authorizer"), "Re-enter unchanged stage3")
	before = snapshot(s)
	check(not s.finish_party_presentation(old_epoch, old_token).accepted and snapshot(s) == before, "Old session token cannot touch new entry")
	flee = s.party_battle_action("flee"); check(flee.accepted and s.finish_party_presentation(flee.epoch, flee.token).accepted, "Finish isolated fixture")
	for gate: String in ["battle", "pending", "invalid"]:
		s = ready(); s.capstone_stage = 5; s.map_id = "sluice"
		match gate:
			"battle": s.battle_active = true
			"pending": s._party_pending_token = 27
			"invalid": s.medicine = -1
		before = snapshot(s)
		check(not s.begin_capstone() and not s.reveal_capstone_letter() and not s.resolve_capstone_evidence(Quest.CORRECT_ANSWER).ok and not s.classify_capstone_orders(Quest.CORRECT_PARTITION).ok and not s.choose_capstone_plan("pause_batch") and not s.confirm_capstone_disposition("pause_batch") and not s.finish_capstone_homecoming() and snapshot(s) == before, "All detached wrappers fail atomically:" + gate)
func _helpers_aliases() -> void:
	var direct = ready(); direct.capstone_stage = 3; direct.map_id = "frostbridge"
	var original: Dictionary = direct.to_dict(); var forged = clone(direct); forged.capstone_stage = 4
	check(not direct._commit_capstone_candidate(forged) and direct.to_dict() == original, "Noncombat candidate cannot supply unearned victory")
	direct.capstone_stage = 5; original = direct.to_dict(); forged = clone(direct); forged.capstone_draft = "pause_batch"; forged.coins += 1
	check(not direct._commit_capstone_candidate(forged) and direct.to_dict() == original, "Detached draft candidate cannot smuggle unrelated coin delta")
	var s = ready(); s.capstone_stage = 4; s.map_id = "frostbridge"
	var before: Dictionary = s.to_dict()
	var variants: Array = [null, [], {}, true, {1: "proven_false"}]
	for key: String in Quest.ORDER_IDS:
		var missing := Quest.CORRECT_PARTITION.duplicate(true); missing.erase(key); variants.append(missing)
		for bad: Variant in [true, 0, [], null, "verified_valid", "pending"]:
			var changed := Quest.CORRECT_PARTITION.duplicate(true); changed[key] = bad; variants.append(changed)
	var extra := Quest.CORRECT_PARTITION.duplicate(true); extra["capstone_pending_005"] = "unverified"; variants.append(extra)
	for variant: Variant in variants:
		check(not s.classify_capstone_orders(variant).ok and s.to_dict() == before, "Exact4-key classification rejects malformed input without costs")
	var input := Quest.CORRECT_PARTITION.duplicate(true)
	check(s.classify_capstone_orders(input).correct, "Correct partition accepted once")
	input.clear()
	var rows: Array = Quest.order_rows(s); rows[0].id = "mutated"; rows[1].disposition = "cancelled"; rows.clear()
	var projection: Dictionary = Quest.progress(s); projection.party_resources.shen.hp = 99; projection.consignee_observations.clear(); projection.party_roster.clear()
	check(s.capstone_stage == 5 and s.capstone_draft == "" and s.party_resources.shen.hp == 0 and s.consignee_observations.size() == 3 and Quest.order_rows(s)[0].id == Quest.ORDER_IDS[0], "Inputs and returned projections never alias persistent/catalog data")
	s = ready(); s.capstone_stage = 2; s.map_id = "frostbridge"
	check(Quest.available_methods(s, "evidence").has("solo") and Quest.available_methods(s, "evidence").has("qin_timing") and not Quest.available_methods(s, "evidence").has("tang_preserve"), "Deployed standing Qin eligible; benched Tang unavailable")
	before = s.to_dict()
	check(not s.resolve_capstone_evidence(Quest.CORRECT_ANSWER, "tang_preserve").ok and s.to_dict() == before, "Forged benched helper cannot advance")
	check(s.resolve_capstone_evidence(Quest.CORRECT_ANSWER, "qin_timing").correct, "Eligible current helper advances proof")
	s.party_resources.qin.hp = 0; s.party_roster.assign(["hero"])
	check(s._stage_save_data(s.to_dict(), 15).ok and s.capstone_stage == 3, "Later bench/downing does not revoke proof")
func earned(s) -> int:
	return s.xp + 30 * s.level * (s.level - 1)
func _rewards() -> void:
	for plan: String in Quest.PLANS:
		for mode: String in ["no_level", "cross", "multi", "cap"]:
			var s = ready(); s.capstone_stage = 6; s.capstone_draft = plan; s.capstone_ending = plan; s.map_id = "qingwei"
			match mode:
				"no_level": s.level = 10; s.xp = 0
				"cross": s.level = 2; s.xp = 119
				"multi": s.level = 1; s.xp = 59
				"cap": s.level = 99; s.xp = 5939; s.coins = 999999
			var before: Dictionary = s.to_dict(); var total := earned(s)
			check(s.finish_capstone_homecoming(), "Canonical reward case:" + mode + plan)
			check(s.party_resources == before.party_resources and s.party_roster == before.party_roster, "Reward preserves benched/downed absolute resources")
			if mode == "cap": check(s.level == 99 and s.xp == 5939 and s.coins == 999999 and s.hp == before.hp and s.qi == before.qi, "Reward saturates without invented recovery at99")
			else:
				check(earned(s) == total + 160 and s.coins == before.coins + 80, "Exact160/80 reward")
				if mode == "no_level": check(s.hp == before.hp and s.qi == before.qi, "No-level homecoming does not heal")
				elif mode == "cross": check(s.level == 3 and s.xp == 159 and s.hp == s.max_hp and s.qi == s.max_qi, "160XP crosses one threshold and restores hero")
				else: check(s.level == 3 and s.xp == 39 and s.hp == s.max_hp and s.qi == s.max_qi, "160XP at level1/59 correctly crosses two levels and restores hero")
	var r = ReentrantState.new(); var base = ready(); r._copy_persistent_from(base)
	r.capstone_stage = 6; r.capstone_draft = "pause_batch"; r.capstone_ending = "pause_batch"; r.map_id = "qingwei"
	var before: Dictionary = r.to_dict(); var total := earned(r)
	check(Quest.finish_homecoming(r) and r.callback_count == 1 and r.observed_stage == 7 and not r.reentry_accepted and r.capstone_stage == 7 and earned(r) - total == 160 and r.coins == before.coins + 80, "Pure reward boundary consumed before reentrant growth callback")
func _resources() -> void:
	var s = ready(); to_three(s)
	var before: Dictionary = s.to_dict()
	check(s.start_party_battle("capstone_authorizer"), "Resource/flee entry")
	var medicine: Dictionary = s.party_battle_action("item", "hero")
	check(medicine.accepted and s.finish_party_presentation(medicine.epoch, medicine.token).accepted, "Actually expend medicine")
	var flee: Dictionary = s.party_battle_action("flee"); var accepted: Dictionary = s.to_dict()
	check(flee.accepted and s.finish_party_presentation(flee.epoch, flee.token).accepted and s.to_dict() == accepted and s.medicine == before.medicine - 1 and s.party_resources.shen.hp == 0 and s.party_resources.tang.hp == 1 and s.capstone_stage == 3, "Flee preserves real use and does not heal/reward")
	s = ready(); s.party_roster.assign(["hero"]); s.hp = 1; s.qi = 0; s.attack = 1; s.defense = 0; s.coins = 5; s.medicine = 0; to_three(s)
	check(s.start_party_battle("capstone_authorizer"), "Genuine weak defeat entry")
	var tx := terminal(s)
	check(tx.after.outcome == "defeat" and s.finish_party_presentation(tx.epoch, tx.token).accepted, "Real defeat accepted")
	check(s.capstone_stage == 3 and s.map_id == "frostbridge" and s.position == Vector2(405, 430) and s.coins == 0 and s.medicine == 0, "New-only defeat target and existing bounded loss")
	check(s.hp == s.max_hp and s.qi == 2 and s.party_resources.shen.hp > 0 and s.party_resources.tang.hp > 1 and s.party_resources.qin.hp > 2, "Existing explicit defeat recovery includes all recruited bench/downed companions")
