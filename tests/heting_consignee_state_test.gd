extends SceneTree
## Synthetic state/controller mechanics only. Earned balance belongs to the
## separate new-combat matrix; these high-stat fixtures are not gameplay proof.
const State = preload("res://scripts/game_state.gd")
const Quest = preload("res://scripts/heting_consignee_rules.gd")
const Driver = preload("res://tests/automatic_state_test_driver.gd")
var checks: int = 0
var failures: int = 0
var fixture_root: String
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _init() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): quit(2); return
	fixture_root = "user://consignee-state-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(fixture_root)
	_test_entry_and_mutation_gates()
	_test_all_prior_routes_and_rewards()
	_test_stale_terminal_atomicity()
	_test_resource_paths()
	_test_reward_caps_and_growth()
	for file: String in DirAccess.get_files_at(fixture_root): DirAccess.remove_absolute(fixture_root.path_join(file))
	DirAccess.remove_absolute(fixture_root)
	if failures == 0: print("PASS: %d consignee State/current-controller entry, stale settlement, resource, reward-cap and save-failure checks" % checks)
	quit(0 if failures == 0 else 1)

func _ready(count: int = 1, harbor: String = "short_ferries", receipt: int = 0, archive: String = "protect_witness"):
	var s := State.new()
	s.quest_stage = 6; s.ending = "守望"; s.side_stage = 3; s.side_choice = "rescue"; s.side_reward_claimed = true
	s.side_found.assign(["boatman", "ledger"]); s.side_clues = 2
	s.chapter_two_stage = 4; s.chapter_two_ending = archive; s.bridge_repaired = true
	s.archive_clues.assign(["clerk", "inscription"]); s.seal_sequence.assign([2, 0, 1])
	s.mist_stage = 4; s.mist_ending = "release_water"; s.mist_approach = "duel"; s.mist_gauges.assign(["rain", "stone", "basin"])
	s.heting_stage = 4; s.heting_bridge = "east"; s.heting_delivered.assign(["meal", "sealed", "reserve"])
	s.heting_draft = harbor; s.heting_ending = harbor; s.receipt_stage = receipt; s.map_id = "heting"
	if count >= 2: check(s.recruit_companion(), "Explicit synthetic Shen recruitment")
	if count >= 3:
		check(s.begin_tangqi_quest() and s.recover_craft_notes() and s.resolve_tangqi_quest("teach") and s.recruit_tangqi(), "Synthetic completed-story Tang quest/recruitment")
	if count >= 4:
		s.map_id = "mistwood"
		check(s.begin_qin_quest() and s.inspect_qin_rope() and s.arrange_qin_handoff() and s.recruit_qin(), "Synthetic completed-story Qin invitation")
		s.map_id = "heting"
	s.attack = 900; s.defense = 900; s.hp = 73; s.qi = 1
	check(s._stage_save_data(s.to_dict(), 14).ok, "Synthetic boundary fixture is complete canonical14")
	return s

func _investigate(s, plan: String = "hold_for_inspection") -> void:
	check(s.begin_consignee(), "Begin new distinct chapter")
	for id: String in Quest.OBSERVATIONS: check(s.observe_consignee(id), "Observe finite evidence:" + id)
	check(s.resolve_consignee_contradiction(Quest.CORRECT_ANSWER).correct and s.choose_consignee_plan(plan), "Earn contradiction and draft")

func _terminal(s) -> Dictionary:
	var tx: Dictionary = Driver.terminal_next(s)
	check(tx.get("accepted", false) and not tx.after.active and s.battle_active, "Real controller terminal remains pending presentation")
	return tx

func _win(s) -> Dictionary:
	check(s.start_party_battle("heting_consignee"), "Enter current controller")
	var tx := _terminal(s)
	if not tx.get("accepted", false): return {}
	var result: Dictionary = s.finish_party_presentation(tx.epoch, tx.token)
	check(result.get("accepted", false) and result.get("settled", false) and result.get("outcome") == "win", "Actual terminal win commits once")
	check(not s.finish_party_presentation(tx.epoch, tx.token).get("accepted", false), "Duplicate terminal acknowledgement rejects")
	var settled_data: Dictionary = s.to_dict()
	check(s.save_game(fixture_root + "/missing/battle.json") != OK and s.to_dict() == settled_data, "Battle save failure preserves secured stage and resources")
	check(s.save_game(fixture_root + "/battle-retry.json") == OK and s.to_dict() == settled_data, "Battle persistence retry never repeats settlement")
	return result

func _snapshot(s) -> Dictionary:
	return {"save": s.to_dict(), "battle": s.party_battle_snapshot(), "active": s.battle_active, "token": s._party_pending_token, "epoch": s.party_battle_epoch, "kind": s.battle_kind}

func _test_entry_and_mutation_gates() -> void:
	var fresh := State.new(); var before := _snapshot(fresh)
	check(not fresh.begin_consignee() and not fresh.start_party_battle("heting_consignee") and _snapshot(fresh) == before, "New game neutral and entry blocked before Heting ending")
	for field: String in ["heting_stage", "heting_ending", "receipt_stage", "consignee_stage", "consignee_cargo_location", "medicine", "hp", "party_resources"]:
		var s = _ready(); _investigate(s)
		match field:
			"heting_stage": s.heting_stage = 3
			"heting_ending": s.heting_ending = ""
			"receipt_stage": s.receipt_stage = 4
			"consignee_stage": s.consignee_stage = 3
			"consignee_cargo_location": s.consignee_cargo_location = "cart"
			"medicine": s.medicine = -1
			"hp": s.hp = 0
			"party_resources": s.party_resources = {"shen": {"hp": 1, "qi": 1}}
		before = _snapshot(s)
		check(not s.start_party_battle("heting_consignee") and _snapshot(s) == before, "Whole-progress/resource invalid entry rejects:" + field)
	var s = _ready(); _investigate(s)
	s._party_pending_token = 123
	before = _snapshot(s)
	check(not s.choose_consignee_plan("return_to_owner") and not s.start_party_battle("heting_consignee") and _snapshot(s) == before, "Pending token without session blocks new mutations and entry")
	s._party_pending_token = -1
	var resources_before: Dictionary = s.to_dict()
	check(s.start_party_battle("heting_consignee") and s.to_dict() == resources_before, "Entry gives no free heal, resource, reward or four-person requirement")
	check(s.party_session.get_script().resource_path.ends_with("automatic_party_combat.gd"), "Uses current automatic controller")
	var snap: Dictionary = s.party_battle_snapshot()
	check(snap.enemies.size() == 2 and snap.enemies[0].id == "du_hui" and snap.enemies[1].id == "consignee_guard", "Two real independent named targets")
	var tx: Dictionary = s.advance_party_battle(); check(tx.accepted, "Actual presentation pending")
	before = _snapshot(s)
	check(not s.begin_consignee() and not s.observe_consignee("lot_seals") and not s.resolve_consignee_contradiction(Quest.CORRECT_ANSWER).ok, "Investigation blocked while pending")
	check(not s.choose_consignee_plan("return_to_owner") and not s.take_consignee_cargo(Quest.BATCH, Quest.SOURCE) and not s.park_consignee_cargo() and not s.finish_consignee_delivery(Quest.SCALE, Quest.PLANS[0]), "All new chapter mutations blocked while pending")
	check(_snapshot(s) == before and s.save_game(fixture_root + "/pending.json") == ERR_BUSY, "Blocked mutations/save preserve exact pending state")
	s.battle_active = false
	check(not s.choose_consignee_plan("return_to_owner"), "Stale cleared battle flag cannot bypass token gate")
	s.battle_active = true
	check(s.finish_party_presentation(tx.epoch, tx.token).accepted, "Exact in-progress token advances")
	var flee: Dictionary = s.party_battle_action("flee")
	check(flee.accepted and s.finish_party_presentation(flee.epoch, flee.token).accepted, "Cleanly leave fixture battle")

func _test_all_prior_routes_and_rewards() -> void:
	for harbor: String in ["short_ferries", "open_scale"]:
		for receipt: int in range(4):
			for archive: String in ["open_records", "protect_witness"]:
				for plan: String in Quest.PLANS:
					var s = _ready(1, harbor, receipt, archive); _investigate(s, plan)
					var before: Dictionary = s.to_dict(); var result := _win(s)
					if result.is_empty(): continue
					check(s.consignee_stage == 3 and s.consignee_ending.is_empty() and not result.settlement.awarded and result.settlement.reward_xp == 0, "Battle only secures one lot; no ending/XP reward")
					check(s.coins == before.coins and s.level == before.level and s.xp == before.xp and s.victories == before.victories + 1, "Combat grants only one victory count")
					check(s.receipt_stage == receipt and s.heting_ending == harbor and s.chapter_two_ending == archive and s.heting_delivered == before.heting_delivered, "Every optional receipt/prior ending remains exact")
					check(not s.start_party_battle("heting_consignee"), "Completed finite fight cannot farm")
					check(s.take_consignee_cargo(Quest.BATCH, Quest.SOURCE), "Take only secured finite lot")
					check(s.park_consignee_cargo() and s.take_consignee_cargo(Quest.BATCH, Quest.SOURCE), "Parking preserves same lot and draft")
					var earned_before: int = _earned(s); var coins_before: int = s.coins
					check(s.finish_consignee_delivery(Quest.receiver_for(plan), plan), "Explicit branch-correct handover")
					check(_earned(s) - earned_before == 120 and s.coins - coins_before == 60, "Equal finite final reward only")
					var final_data: Dictionary = s.to_dict()
					check(not s.finish_consignee_delivery(Quest.receiver_for(plan), plan) and not s.take_consignee_cargo(Quest.BATCH, Quest.SOURCE) and s.to_dict() == final_data, "Repeated handover/source activation never duplicates cargo/reward")
					check(s.save_game(fixture_root + "/missing/save.json") != OK and s.to_dict() == final_data, "Failed final save leaves in-memory ending settled")
					check(s.save_game(fixture_root + "/final.json") == OK and s.to_dict() == final_data, "Persistence retry leaves exact one-time reward")

func _test_stale_terminal_atomicity() -> void:
	var s = _ready(4); _investigate(s); check(s.start_party_battle("heting_consignee"), "Prepare real terminal for stale mutation checks")
	var tx := _terminal(s); if not tx.get("accepted", false): return
	var terminal_state = s._detached_persistent_state()
	var snapshot: Dictionary = s.party_session.snapshot()
	check(not s.finish_party_presentation(tx.epoch + 1, tx.token).accepted and not s.finish_party_presentation(tx.epoch, tx.token + 1).accepted, "Wrong epoch/token cannot settle")
	for field: String in ["hp", "qi", "medicine", "coins", "xp", "receipt_stage", "heting_bridge", "consignee_draft", "party_resources", "art_uses"]:
		match field:
			"hp": s.hp -= 1
			"qi": s.qi += 1
			"medicine": s.medicine += 1
			"coins": s.coins += 1
			"xp": s.xp += 1
			"receipt_stage": s.receipt_stage = 1
			"heting_bridge": s.heting_bridge = "west"
			"consignee_draft": s.consignee_draft = "return_to_owner"
			"party_resources": s.party_resources.shen.hp = maxi(0, s.party_resources.shen.hp - 1)
			"art_uses": s.art_uses[s.equipped_art] += 1
		var before := _snapshot(s)
		check(not s.finish_party_presentation(tx.epoch, tx.token).accepted and _snapshot(s) == before, "Stale real resource/progress fails before reward/recovery:" + field)
		s._copy_persistent_from(terminal_state)
	for key: String in ["encounter_id", "epoch", "pending_token", "consignee_provenance", "actors"]:
		var forged := snapshot.duplicate(true)
		match key:
			"encounter_id": forged.encounter_id = "training"
			"epoch": forged.epoch += 1
			"pending_token": forged.pending_token += 1
			"consignee_provenance": forged.consignee_provenance = {}
			"actors": forged.actors[0].hp += 1
		check(not s._party_terminal_plan(forged).ok, "Forged snapshot does not establish accepted victory:" + key)
	check(s.finish_party_presentation(tx.epoch, tx.token).accepted and s.consignee_stage == 3, "Same authentic terminal can settle once after external stale data restored")

func _test_resource_paths() -> void:
	for count: int in range(1, 5):
		var s = _ready(count); _investigate(s)
		if count >= 2: s.party_resources.shen.hp = 0
		var before: Dictionary = s.to_dict()
		check(s.start_party_battle("heting_consignee") and s.to_dict() == before, "Entry preserves wounds/downed resource at roster%d" % count)
		var used: Dictionary = s.party_battle_action("item", "hero")
		check(used.accepted and s.finish_party_presentation(used.epoch, used.token).accepted, "Real medicine consumption presented")
		var flee: Dictionary = s.party_battle_action("flee")
		check(flee.accepted, "Retreat is real accepted utility")
		var accepted: Dictionary = s.to_dict(); var settled: Dictionary = s.finish_party_presentation(flee.epoch, flee.token)
		check(settled.accepted and s.to_dict() == accepted and s.medicine == before.medicine - 1 and s.consignee_stage == 2 and s.consignee_ending.is_empty(), "Retreat preserves actual used resources; no reward/progress")
		if count >= 2: check(s.party_resources.shen.hp == 0, "Retreat never revives downed companion")
		check(s.start_party_battle("heting_consignee"), "Retreat leaves retry available without free refill")
		flee = s.party_battle_action("flee"); check(flee.accepted and s.finish_party_presentation(flee.epoch, flee.token).accepted, "Clean retry retreat")
	var skilled = _ready(); _investigate(skilled); skilled.attack = 60; skilled.qi = 6
	check(skilled.start_party_battle("heting_consignee"), "Prepare real queued qi/proficiency expenditure")
	var skill_tx: Dictionary = Driver.queued_next(skilled, "hero", "art:照夜一线", "du_hui")
	check(skill_tx.get("accepted", false) and skill_tx.action_id == "art:照夜一线" and skill_tx.after.active, "Current controller executes queued martial against explicit target")
	if skill_tx.get("accepted", false):
		check(skilled.finish_party_presentation(skill_tx.epoch, skill_tx.token).accepted, "Acknowledge actual martial presentation")
		check(skilled.qi < 6 and skilled.art_uses["照夜一线"] == 1, "Actual qi expenditure and proficiency committed")
		var qi_flee: Dictionary = skilled.party_battle_action("flee")
		var real_resources: Dictionary = skilled.to_dict()
		check(qi_flee.accepted and skilled.finish_party_presentation(qi_flee.epoch, qi_flee.token).accepted and skilled.to_dict() == real_resources, "Retreat preserves actual spent qi/proficiency without refill")
	var defeated = _ready(); _investigate(defeated); defeated.hp = 1; defeated.qi = 0; defeated.attack = 1; defeated.defense = 0; defeated.medicine = 0; defeated.coins = 5
	check(defeated.start_party_battle("heting_consignee"), "Real weak fixture starts without hidden healing")
	var terminal := _terminal(defeated)
	check(terminal.after.outcome == "defeat", "Actual current controller exhausts hero")
	var settlement: Dictionary = defeated.finish_party_presentation(terminal.epoch, terminal.token)
	check(settlement.accepted and defeated.map_id == "heting" and defeated.position == Vector2(230, 735), "New defeat explicitly recovers at west Heting")
	check(defeated.hp == defeated.max_hp and defeated.qi == 2 and defeated.coins == 0 and defeated.medicine == 0, "Existing limited penalty/recovery; no negative coin or medicine refund")
	check(defeated.consignee_stage == 2 and defeated.consignee_ending.is_empty() and defeated.victories == 0, "Defeat never completes, pays or changes draft")
	check(defeated.save_game(fixture_root + "/defeat.json") == OK, "Recovered defeat is canonical14")

func _earned(s) -> int:
	return s.xp + 30 * s.level * (s.level - 1)

func _test_reward_caps_and_growth() -> void:
	var s = _ready(4); _investigate(s); _win(s)
	check(s.take_consignee_cargo(Quest.BATCH, Quest.SOURCE), "Prepare capped final handover")
	s.level = 99; s.xp = 5939; s.coins = 999999; s.victories = 999999
	var companion_resources: Dictionary = s.party_resources.duplicate(true)
	check(s.finish_consignee_delivery(Quest.SCALE, Quest.PLANS[0]), "Legal final handover succeeds at resource caps")
	check(s.level == 99 and s.xp == 5939 and s.coins == 999999 and s.victories == 999999 and s.party_resources == companion_resources, "Final reward caps do not fabricate growth or companion healing")
	var growth = _ready(2); _investigate(growth); _win(growth)
	check(growth.take_consignee_cargo(Quest.BATCH, Quest.SOURCE), "Prepare level-up final handover")
	growth.party_resources.shen.hp = 0; growth.party_resources.shen.qi = 0; growth.hp = 1; growth.qi = 0; growth.xp = 59
	check(growth.finish_consignee_delivery(Quest.SCALE, Quest.PLANS[0]), "Final XP reconciles real level growth")
	check(growth.level == 2 and growth.xp == 119 and growth.hp == growth.max_hp and growth.qi == growth.max_qi, "Existing explicit hero level-up recovery preserved")
	check(growth.party_resources.shen.hp == 0 and growth.party_resources.shen.qi == 0, "XP never revives/refills fallen companion")
