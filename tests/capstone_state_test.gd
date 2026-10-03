extends SceneTree
## Synthetic state/current-controller mechanics only. High-stat fixtures prove
## atomicity, not earned balance, site/proximity, scene, artwork or rollout.
const State = preload("res://scripts/game_state.gd")
const Quest = preload("res://scripts/volume_one_capstone_rules.gd")
const Driver = preload("res://tests/automatic_state_test_driver.gd")
var checks: int = 0
var failures: int = 0
var fixture_root: String

class RewardProbe extends State:
	static var reward_calls: int = 0
	static var reentry_accepted: bool = false
	func gain_xp(amount: int) -> Array[String]:
		reward_calls += 1
		reentry_accepted = finish_capstone_homecoming()
		return super.gain_xp(amount)

func _init() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): quit(2); return
	fixture_root = "user://capstone-state-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(fixture_root) == OK, "Isolated state test filesystem")
	_test_entry_and_mutation_gates()
	_test_transitions_and_wrong_maps()
	_test_prior_routes_and_rewards()
	_test_stale_terminal_atomicity()
	_test_resource_paths()
	_test_reward_caps_growth_and_reentry()
	for file: String in DirAccess.get_files_at(fixture_root): DirAccess.remove_absolute(fixture_root.path_join(file))
	DirAccess.remove_absolute(fixture_root)
	if failures == 0: print("PASS: %d capstone whole-state/current-controller/map-scope/token/resource/reward/persistence checks; synthetic mechanics, not site/proximity or earned-balance evidence" % checks)
	quit(0 if failures == 0 else 1)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _ready(count: int = 1, consignee: String = "return_to_owner", harbor: String = "short_ferries", receipt: int = 0, archive: String = "protect_witness"):
	var s := State.new()
	s.quest_stage = 6; s.ending = "守望"; s.side_stage = 3; s.side_choice = "rescue"; s.side_clues = 2; s.side_found.assign(["boatman", "ledger"]); s.side_reward_claimed = true
	s.chapter_two_stage = 4; s.chapter_two_ending = archive; s.archive_clues.assign(["clerk", "inscription"]); s.seal_sequence.assign([2, 0, 1])
	s.mist_stage = 4; s.mist_approach = "duel"; s.mist_gauges.assign(["rain", "stone", "basin"]); s.mist_ending = "release_water"
	s.heting_stage = 4; s.heting_bridge = "east"; s.heting_delivered.assign(["meal", "sealed", "reserve"]); s.heting_draft = harbor; s.heting_ending = harbor; s.receipt_stage = receipt; s.map_id = "heting"
	s.consignee_stage = 5; s.consignee_observations.assign(State.Consignee.OBSERVATIONS); s.consignee_draft = consignee; s.consignee_ending = consignee; s.consignee_cargo_location = "grain_boat" if consignee == "return_to_owner" else "public_scale"
	if count >= 2: check(s.recruit_companion(), "Explicit synthetic Shen recruitment")
	if count >= 3: s.bridge_repaired = true; check(s.begin_tangqi_quest() and s.recover_craft_notes() and s.resolve_tangqi_quest("teach") and s.recruit_tangqi(), "Explicit synthetic Tang history and recruitment")
	if count >= 4:
		s.map_id = "mistwood"; check(s.begin_qin_quest() and s.inspect_qin_rope() and s.arrange_qin_handoff() and s.recruit_qin(), "Explicit synthetic Qin history and recruitment"); s.map_id = "heting"
	var ids: Array[String] = ["hero"]
	for id: String in ["shen", "tang", "qin"]:
		if s.party_resources.has(id): ids.append(id)
	check(s.set_party_roster(ids), "Explicit roster selection with no hidden recruiting")
	s.attack = 900; s.defense = 900; s.hp = 73; s.qi = 1
	check(s._stage_save_data(s.to_dict(), State.SAVE_VERSION).ok, "Canonical complete synthetic15 boundary")
	return s

func _investigate(s) -> void:
	check(s.begin_capstone(), "Accept referral at Heting")
	s.map_id = "frostbridge"
	check(s.reveal_capstone_letter(), "Verify authorship and return letter")
	check(s.resolve_capstone_evidence(Quest.CORRECT_ANSWER).correct, "Prove issued chain before battle")

func _terminal(s) -> Dictionary:
	var tx: Dictionary = Driver.terminal_next(s)
	check(tx.get("accepted", false) and not tx.after.active and s.battle_active, "Real automatic terminal remains pending presentation")
	return tx

func _win(s) -> Dictionary:
	check(s.start_party_battle("capstone_authorizer"), "Start genuine automatic capstone encounter")
	var tx := _terminal(s)
	if not tx.get("accepted", false): return {}
	var result: Dictionary = s.finish_party_presentation(tx.epoch, tx.token)
	check(result.get("accepted", false) and result.get("settled", false) and result.get("outcome") == "win", "Authentic terminal victory commits")
	var before: Dictionary = s.to_dict()
	check(not s.finish_party_presentation(tx.epoch, tx.token).accepted and s.to_dict() == before, "Repeated terminal acknowledgement never commits twice")
	_save_failure_retry(s, "victory")
	return result

func _snapshot(s) -> Dictionary:
	return {"save": s.to_dict(), "battle": s.party_battle_snapshot(), "active": s.battle_active, "token": s._party_pending_token, "epoch": s.party_battle_epoch, "kind": s.battle_kind}

func _old_story(s) -> Dictionary:
	var data: Dictionary = s.to_dict()
	for key: String in Quest.FIELDS + ["hp", "qi", "art_uses", "party_resources", "medicine", "level", "xp", "coins", "max_hp", "attack", "defense", "victories", "map_id", "position"]: data.erase(key)
	return data

func _save_failure_retry(s, label: String) -> void:
	var before: Dictionary = s.to_dict(); var path := fixture_root + "/checkpoint.json"
	if not FileAccess.file_exists(path): check(State.new().save_game(path) == OK, "Create prior valid checkpoint")
	var old_bytes := FileAccess.get_file_as_bytes(path)
	check(DirAccess.make_dir_absolute(path + ".tmp") == OK, label + ": force same-target temporary-file failure")
	check(s.save_game(path) != OK and s.to_dict() == before, label + ": failed save preserves accepted in-memory state")
	check(FileAccess.get_file_as_bytes(path) == old_bytes, label + ": last good target bytes unchanged")
	DirAccess.remove_absolute(path + ".tmp")
	check(s.save_game(path) == OK and s.to_dict() == before, label + ": retry writes accepted state without replay")

func _test_entry_and_mutation_gates() -> void:
	var fresh := State.new(); var before := _snapshot(fresh)
	check(not fresh.begin_capstone() and not fresh.start_party_battle("capstone_authorizer") and _snapshot(fresh) == before, "Fresh game has neutral unavailable finale")
	for field: String in ["quest_stage", "side_found", "chapter_two_ending", "mist_ending", "heting_stage", "consignee_stage", "consignee_ending", "receipt_stage", "medicine", "hp", "party_resources"]:
		var s = _ready(); _investigate(s)
		match field:
			"quest_stage": s.quest_stage = 5
			"side_found": s.side_found.clear()
			"chapter_two_ending": s.chapter_two_ending = ""
			"mist_ending": s.mist_ending = ""
			"heting_stage": s.heting_stage = 3
			"consignee_stage": s.consignee_stage = 4
			"consignee_ending": s.consignee_ending = ""
			"receipt_stage": s.receipt_stage = 4
			"medicine": s.medicine = -1
			"hp": s.hp = 0
			"party_resources": s.party_resources = {"shen": {"hp": 1, "qi": 1}}
		before = _snapshot(s)
		check(not s.start_party_battle("capstone_authorizer") and not s.choose_capstone_plan(Quest.PLANS[0]) and _snapshot(s) == before, "Malformed full-state entry/action rejects:" + field)
	var s = _ready(); _investigate(s); s._party_pending_token = 123; before = _snapshot(s)
	check(not s.begin_capstone() and not s.start_party_battle("capstone_authorizer") and _snapshot(s) == before, "Dangling presentation token blocks actions and entry")
	s._party_pending_token = -1; var resources: Dictionary = s.to_dict()
	check(s.start_party_battle("capstone_authorizer") and s.to_dict() == resources, "Entry adds no recovery, cost, XP or rewards")
	var view: Dictionary = s.party_battle_snapshot()
	check(view.enemies.size() == 1 and view.enemies[0].id == "liang_zhen" and s.party_session.get_script().resource_path.ends_with("automatic_party_combat.gd"), "Sole original enemy in actual automatic controller")
	var tx: Dictionary = s.advance_party_battle(); check(tx.accepted, "Presentation pending")
	before = _snapshot(s)
	check(not s.begin_capstone() and not s.reveal_capstone_letter() and not s.resolve_capstone_evidence(Quest.CORRECT_ANSWER).ok and not s.classify_capstone_orders(Quest.CORRECT_PARTITION).ok and not s.choose_capstone_plan(Quest.PLANS[0]) and not s.confirm_capstone_disposition(Quest.PLANS[0]) and not s.finish_capstone_homecoming(), "Every wrapper refuses pending battle")
	check(s.save_game(fixture_root + "/pending.json") == ERR_BUSY and s.load_game(fixture_root + "/checkpoint.json") == ERR_BUSY and _snapshot(s) == before, "Pending save/load/action gates are nondestructive")
	s.battle_active = false; check(not s.finish_capstone_homecoming(), "Stale cleared battle flag cannot evade token gate"); s.battle_active = true
	check(s.finish_party_presentation(tx.epoch, tx.token).accepted, "Exact pending transaction finishes")

func _test_transitions_and_wrong_maps() -> void:
	var s = _ready(); var old: Dictionary = _old_story(s)
	for stage: int in range(7):
		if stage == 3:
			s.map_id = "frostbridge"; _win(s); continue
		var allowed: Array = ["heting"] if stage == 0 else (["frostbridge"] if stage in [1, 2] else (["frostbridge", "sluice"] if stage in [4, 5] else ["qingwei"]))
		if stage == 5: allowed = ["sluice"]
		for place: String in ["qingwei", "sluice", "frostbridge", "mistwood", "heting"]:
			if allowed.has(place): continue
			s.map_id = place; var before: Dictionary = s.to_dict()
			check(not _next(s, stage) and s.to_dict() == before, "Wrong-map stage%d action atomic:%s (site/proximity separately scoped)" % [stage, place])
		s.map_id = allowed[0]
		if stage == 2:
			var before: Dictionary = s.to_dict(); check(not s.resolve_capstone_evidence("victory_proves_guilt").ok and s.to_dict() == before, "Wrong issued-chain answer has no cost")
		if stage == 4:
			var before: Dictionary = s.to_dict()
			for partition: Variant in [{}, [], true, "all_false", {"capstone_pending_001":"proven_false"}]: check(not s.classify_capstone_orders(partition).ok and s.to_dict() == before, "Missing/wrong-shaped partition rejects")
			for id: String in Quest.ORDER_IDS:
				var wrong: Dictionary = Quest.CORRECT_PARTITION.duplicate(true); wrong[id] = "proven_false" if wrong[id] == "unverified" else "unverified"
				check(not s.classify_capstone_orders(wrong).ok and s.to_dict() == before, "Each wrong row rejects:" + id)
			var extra: Dictionary = Quest.CORRECT_PARTITION.duplicate(true); extra.other_order = "unverified"
			check(not s.classify_capstone_orders(extra).ok and not s.choose_capstone_plan(Quest.PLANS[0]) and s.to_dict() == before, "Extra order rejected; classification cannot be skipped")
		check(_next(s, stage) and s.capstone_stage == stage + 1, "Exact ordered atomic transition%d to%d" % [stage, stage + 1])
		if stage == 4:
			check(s.capstone_draft.is_empty() and s.capstone_ending.is_empty(), "Classification persists without draft")
			check(s.choose_capstone_plan(Quest.PLANS[0]) and s.choose_capstone_plan(Quest.PLANS[1]) and s.choose_capstone_plan(""), "Draft change and clear reversible")
			check(s.choose_capstone_plan(Quest.PLANS[0]), "Prepare desk confirmation")
			var before: Dictionary = s.to_dict()
			check(not s.choose_capstone_plan(Quest.PLANS[0]) and not s.classify_capstone_orders(Quest.CORRECT_PARTITION).ok and s.to_dict() == before, "Same draft/classification no-op cannot replay stage")
			s.map_id = "sluice"
			check(not s.confirm_capstone_disposition(Quest.PLANS[1]), "Stale different expected plan rejects")
			s.map_id = allowed[0]
			check(s.to_dict() == before, "Rejected stale expected plan changes no field")
		if stage == 5:
			var before: Dictionary = s.to_dict(); check(not s.confirm_capstone_disposition(Quest.PLANS[0]) and not s.choose_capstone_plan(Quest.PLANS[1]) and s.to_dict() == before, "Confirmed disposition immutable")
		check(_old_story(s) == old, "Transition preserves every old story/recruitment/equipment field")
		_save_failure_retry(s, "stage%d" % s.capstone_stage)
	var paid: Dictionary = s.to_dict()
	check(not s.finish_capstone_homecoming() and s.to_dict() == paid and Quest.goal(s).is_empty(), "Homecoming once; goal clears")

func _next(s, stage: int) -> bool:
	match stage:
		0: return s.begin_capstone()
		1: return s.reveal_capstone_letter()
		2: return s.resolve_capstone_evidence(Quest.CORRECT_ANSWER).ok
		4: return s.classify_capstone_orders(Quest.CORRECT_PARTITION).ok
		5: return s.confirm_capstone_disposition(Quest.PLANS[0])
		6: return s.finish_capstone_homecoming()
	return false

func _test_prior_routes_and_rewards() -> void:
	for consignee: String in State.Consignee.PLANS:
		for harbor: String in ["short_ferries", "open_scale"]:
			for receipt: int in range(4):
				for archive: String in ["open_records", "protect_witness"]:
					var s = _ready(1, consignee, harbor, receipt, archive); var old: Dictionary = _old_story(s); _investigate(s)
					var before: Dictionary = s.to_dict(); var result := _win(s)
					if result.is_empty(): continue
					check(s.capstone_stage == 4 and s.capstone_draft.is_empty() and s.capstone_ending.is_empty() and not result.settlement.awarded and result.settlement.reward_xp == 0, "Victory only obtains new book")
					check(s.coins == before.coins and s.xp == before.xp and s.level == before.level and s.victories == before.victories + 1, "Victory no XP/coins; ordinary statistic only")
					check(not s.start_party_battle("capstone_authorizer"), "Capstone cannot be farmed")
					check(s.classify_capstone_orders(Quest.CORRECT_PARTITION).ok, "Classify recovered four orders")
					for plan: String in Quest.PLANS:
						var branch = s._detached_persistent_state(); check(branch.choose_capstone_plan(plan), "Either disposition available")
						var earned: int = _earned(branch); var coins: int = branch.coins
						branch.map_id = "sluice"; check(branch.confirm_capstone_disposition(plan), "Explicit confirmed disposition")
						check(_earned(branch) == earned and branch.coins == coins and branch.capstone_stage == 6, "Disposition does not complete/pay")
						branch.map_id = "qingwei"; check(branch.finish_capstone_homecoming(), "Homecoming action completes")
						check(_earned(branch) - earned == 160 and branch.coins - coins == 80 and _old_story(branch) == old, "Equal reward; old endings/cargo/optional receipt exact")

func _test_stale_terminal_atomicity() -> void:
	var s = _ready(4); _investigate(s); check(s.start_party_battle("capstone_authorizer"), "Prepare real terminal identity")
	var tx := _terminal(s); if not tx.get("accepted", false): return
	var terminal = s._detached_persistent_state(); var snapshot: Dictionary = s.party_session.snapshot()
	check(not s.finish_party_presentation(tx.epoch + 1, tx.token).accepted and not s.finish_party_presentation(tx.epoch, tx.token + 1).accepted, "Wrong host epoch/token rejected")
	for field: String in ["hp", "qi", "medicine", "coins", "xp", "receipt_stage", "consignee_ending", "heting_bridge", "capstone_stage", "capstone_draft", "party_resources", "art_uses", "map_id", "position"]:
		match field:
			"hp": s.hp -= 1
			"qi": s.qi += 1
			"medicine": s.medicine += 1
			"coins": s.coins += 1
			"xp": s.xp += 1
			"receipt_stage": s.receipt_stage = 1
			"consignee_ending": s.consignee_ending = "hold_for_inspection"
			"heting_bridge": s.heting_bridge = "west"
			"capstone_stage": s.capstone_stage = 4
			"capstone_draft": s.capstone_draft = Quest.PLANS[0]
			"party_resources": s.party_resources.shen.hp = maxi(0, s.party_resources.shen.hp - 1)
			"art_uses": s.art_uses[s.equipped_art] += 1
			"map_id": s.map_id = "qingwei"
			"position": s.position += Vector2(1, 0)
		var before := _snapshot(s)
		check(not s.finish_party_presentation(tx.epoch, tx.token).accepted and _snapshot(s) == before, "Stale whole identity rejects before recovery/progression:" + field)
		s._copy_persistent_from(terminal)
	for key: String in ["encounter_id", "epoch", "pending_token", "capstone_provenance", "actors", "enemies", "locked", "outcome"]:
		var forged := snapshot.duplicate(true)
		match key:
			"encounter_id": forged.encounter_id = "archive_boss"
			"epoch": forged.epoch += 1
			"pending_token": forged.pending_token += 1
			"capstone_provenance": forged.capstone_provenance = {}
			"actors": forged.actors[0].hp += 1
			"enemies": forged.enemies = []
			"locked": forged.locked = false
			"outcome": forged.outcome = "flee"
		check(not s._party_terminal_plan(forged).ok, "Forged snapshot rejects:" + key)
	var real_session = s.party_session
	var replacement = _ready(); _investigate(replacement)
	check(replacement.start_party_battle("capstone_authorizer"), "Create separate genuine controller")
	s.party_session = replacement.party_session
	check(not s._party_terminal_plan(snapshot).ok, "Different real session cannot inherit entry identity")
	s.party_session = real_session
	s._party_encounter = "training"
	check(not s._party_terminal_plan(snapshot).ok, "Changed transient encounter cannot route capstone into generic reward")
	s._party_encounter = "capstone_authorizer"
	s.battle_kind = "training"
	check(not s._party_terminal_plan(snapshot).ok, "Changed battle identity rejects")
	s.battle_kind = "capstone_authorizer"
	# Even a snapshot genuinely emitted by the same controller cannot change
	# the fixed opponent spec recorded at entry.
	var original_attack: int = s.party_session._enemies[0].attack
	s.party_session._enemies[0].attack += 1
	check(not s._party_terminal_plan(s.party_session.snapshot()).ok, "Authentic snapshot with changed fixed enemy spec rejected")
	s.party_session._enemies[0].attack = original_attack
	var host_epoch: int = s.party_battle_epoch; s.party_battle_epoch += 1
	check(not s._party_terminal_plan(snapshot).ok, "Entry identity pins host epoch"); s.party_battle_epoch = host_epoch
	check(s.finish_party_presentation(tx.epoch, tx.token).accepted and s.capstone_stage == 4, "Authentic terminal retries after stale data restored")
	var saved: Dictionary = s.to_dict(); check(not s.finish_party_presentation(tx.epoch, tx.token).accepted and s.to_dict() == saved, "Double callback no pay/advance")

func _test_resource_paths() -> void:
	for count: int in range(1, 5):
		var s = _ready(count); _investigate(s)
		if count >= 2: s.party_resources.shen.hp = 0
		var before: Dictionary = s.to_dict(); check(s.start_party_battle("capstone_authorizer") and s.to_dict() == before, "Entry preserves wounds/downed at roster%d" % count)
		var item: Dictionary = s.party_battle_action("item", "hero"); check(item.accepted and s.finish_party_presentation(item.epoch, item.token).accepted, "Real medicine presented")
		var flee: Dictionary = s.party_battle_action("flee"); var accepted: Dictionary = s.to_dict()
		check(flee.accepted and s.finish_party_presentation(flee.epoch, flee.token).accepted and s.to_dict() == accepted and s.medicine == before.medicine - 1 and s.capstone_stage == 3, "Retreat retains consumed medicine/proof without refill/reward")
		if count >= 2: check(s.party_resources.shen.hp == 0, "Retreat never revives downed companion")
		check(s.start_party_battle("capstone_authorizer"), "Retry available after actual retreat")
		flee = s.party_battle_action("flee"); check(flee.accepted and s.finish_party_presentation(flee.epoch, flee.token).accepted, "Clean retry retreat")
	var recovering_qin = _ready(4); _investigate(recovering_qin)
	check(recovering_qin.set_party_roster(["hero", "shen", "qin"]), "Select real Qin with wounded Tang bench")
	recovering_qin.attack = 50; recovering_qin.party_resources.shen.hp = 0; recovering_qin.party_resources.qin.qi = 0
	recovering_qin.party_resources.tang = {"hp": 2, "qi": 0}
	var before_qin: Dictionary = recovering_qin.party_resources.duplicate(true)
	var qin_win: Dictionary = _win(recovering_qin)
	check(qin_win.get("accepted", false) and recovering_qin.capstone_stage == 4 and recovering_qin.party_resources.qin.qi > 0, "Actual deployed Qin basic qi regeneration accepted at genuine win")
	check(recovering_qin.party_resources.shen.hp == 0 and recovering_qin.party_resources.tang == before_qin.tang, "Win retains downed Shen and wounded benched Tang")
	var skilled = _ready(); _investigate(skilled); skilled.attack = 16; skilled.qi = 6
	check(skilled.start_party_battle("capstone_authorizer"), "Prepare real qi/proficiency spend")
	var skill: Dictionary = Driver.queued_next(skilled, "hero", "art:照夜一线", "liang_zhen")
	check(skill.get("accepted", false) and skill.action_id == "art:照夜一线" and skill.after.active, "Actual queued martial exact enemy")
	if skill.get("accepted", false):
		check(skilled.finish_party_presentation(skill.epoch, skill.token).accepted and skilled.qi < 6 and skilled.art_uses["照夜一线"] == 1, "Qi/proficiency real costs retained")
		var flee: Dictionary = skilled.party_battle_action("flee"); var resources: Dictionary = skilled.to_dict()
		check(flee.accepted and skilled.finish_party_presentation(flee.epoch, flee.token).accepted and skilled.to_dict() == resources, "Retreat keeps spent qi/proficiency")
	var defeated = _ready(4); _investigate(defeated)
	check(defeated.set_party_roster(["hero"]), "Explicitly bench all companions")
	for id: String in defeated.party_resources: defeated.party_resources[id] = {"hp": 0, "qi": 0}
	defeated.hp = 1; defeated.qi = 0; defeated.attack = 1; defeated.defense = 0; defeated.medicine = 0; defeated.coins = 5
	var old: Dictionary = _old_story(defeated)
	check(defeated.start_party_battle("capstone_authorizer"), "Weak fixture enters without healing")
	var terminal := _terminal(defeated); check(terminal.after.outcome == "defeat", "Genuine model defeats weak hero")
	var settlement: Dictionary = defeated.finish_party_presentation(terminal.epoch, terminal.token)
	check(settlement.accepted and defeated.map_id == "frostbridge" and defeated.position == Vector2(405, 430), "New-only defeat Frostbridge geometry; scene movement separate")
	check(defeated.hp == defeated.max_hp and defeated.qi == 2 and defeated.coins == 0 and defeated.medicine == 0 and defeated.capstone_stage == 3 and _old_story(defeated) == old, "Existing defeat recovery/loss retains proof/old story")
	var catalog: Dictionary = State.PartyRoster._catalog(defeated)
	for id: String in defeated.party_resources: check(defeated.party_resources[id].hp == catalog.actors[id].max_hp and defeated.party_resources[id].qi == 2, "Existing defeat restores ALL recruited including bench/downed:" + id)
	check(defeated.save_game(fixture_root + "/defeat.json") == OK, "Recovered defeat canonical15")

func _earned(s) -> int: return s.xp + 30 * s.level * (s.level - 1)
func _stage6(count: int = 2):
	var s = _ready(count); s.map_id = "qingwei"; s.capstone_stage = 6; s.capstone_draft = Quest.PLANS[0]; s.capstone_ending = Quest.PLANS[0]
	check(s._stage_save_data(s.to_dict(), State.SAVE_VERSION).ok, "Synthetic unpaid stage6 fixture")
	return s

func _test_reward_caps_growth_and_reentry() -> void:
	var capped = _stage6(4); capped.level = 99; capped.xp = 5939; capped.coins = 999999; capped.victories = 999999
	var resources: Dictionary = capped.party_resources.duplicate(true)
	check(capped.finish_capstone_homecoming() and capped.level == 99 and capped.xp == 5939 and capped.coins == 999999 and capped.victories == 999999 and capped.party_resources == resources, "Reward caps retain resources without growth")
	for level: int in [1, 2, 10]:
		var s = _stage6(); s.level = level; s.xp = 0; s.hp = 1; s.qi = 0; s.party_resources.shen = {"hp": 0, "qi": 0}
		var before: int = _earned(s); var old_hp: int = s.hp
		check(s.finish_capstone_homecoming() and _earned(s) - before == 160 and s.coins == 104, "Exact160XP/80coin reward at level%d" % level)
		check(s.party_resources.shen.hp == 0 and s.party_resources.shen.qi == 0, "Homecoming never revives/refills companion")
		if level < s.level: check(s.hp == s.max_hp and s.qi == s.max_qi, "Ordinary level-up explicitly restores hero")
		else: check(s.hp == old_hp and s.qi == 0, "No level-up means no recovery")
	var multi = _stage6(); multi.xp = 59; multi.hp = 1; multi.qi = 0
	check(multi.finish_capstone_homecoming() and multi.level == 3 and multi.xp == 39 and multi.hp == multi.max_hp, "Ordinary multi-level crossing")
	var probe := RewardProbe.new(); probe._copy_persistent_from(_stage6())
	RewardProbe.reward_calls = 0; RewardProbe.reentry_accepted = false
	check(probe.finish_capstone_homecoming() and RewardProbe.reward_calls == 1 and not RewardProbe.reentry_accepted and probe.capstone_stage == 7, "Consume stage before reward callback; reentry rejected; callback once")
	var before: Dictionary = probe.to_dict()
	check(not probe.finish_capstone_homecoming() and RewardProbe.reward_calls == 1 and probe.to_dict() == before, "Repeated callback stays consumed")
	_save_failure_retry(probe, "reward")
	var original = _ready(); var candidate = original._detached_persistent_state(); candidate.capstone_stage = 1; candidate.coins += 1
	check(not original._commit_capstone_candidate(candidate) and original.capstone_stage == 0, "Unrelated mutation in canonical candidate rejects")
	_investigate(original); candidate = original._detached_persistent_state(); candidate.capstone_stage = 4
	check(not original._commit_capstone_candidate(candidate) and original.capstone_stage == 3, "Noncombat commit helper cannot shortcut actual victory")
