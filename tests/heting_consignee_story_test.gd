extends SceneTree
## State-backed controller boundary tests. Synthetic old-chapter fixtures;
## real world movement/input and rendered battle are covered separately.
const State = preload("res://scripts/game_state.gd")
const Story = preload("res://scripts/heting_consignee_story.gd")
const Rules = preload("res://scripts/heting_consignee_rules.gd")
const Driver = preload("res://tests/automatic_state_test_driver.gd")
var checks: int = 0
var failures: int = 0
var hosts: Array = []
class WorldStub:
	extends RefCounted
	var map_id: String = "heting"
	var player_pos: Vector2 = Vector2(535, 350)
	var interactables: Dictionary = {"consignee_warehouse": {"pos": Vector2(700,315)}, "heting_dispatch": {"pos": Vector2(535,350)}, "heting_lighter": {"pos": Vector2(970,780)}, "heting_scale": {"pos": Vector2(1390,600)}, "heting_cargo": {"pos": Vector2(665,620)}, "return_mistwood": {"pos": Vector2(150,335)}, "heting_relief": {"pos": Vector2(230,780)}}
	func teleport(point: Vector2) -> void: player_pos = point
class HostStub:
	extends RefCounted
	var state = State.new()
	var world = WorldStub.new()
	var current_screen: String = "explore"
	var active_modal: bool = false
	var modal_generation: int = 0
	var modal_autosave_on_close: bool = true
	var save_warning: bool = false
	var quit_pending: bool = false
	var fail_save: bool = false
	var writes: int = 0
	var starts: int = 0
	var title: String = ""
	var subtitle: String = ""
	var body: String = ""
	var options: Array = []
	var persisted: Dictionary = {}
	var consignee_story
	func _modal(heading: String, sub: String, text: String, choices: Array, _wide: bool) -> void:
		modal_generation += 1; active_modal = true; modal_autosave_on_close = true
		title = heading; subtitle = sub; body = text; options = choices.duplicate()
	func _close_modal() -> void:
		var save: bool = modal_autosave_on_close
		modal_generation += 1; active_modal = false; options.clear(); modal_autosave_on_close = true
		if save: _autosave()
	func _autosave() -> void:
		writes += 1; state.position = world.player_pos; save_warning = fail_save
		if not fail_save: persisted = state.to_dict().duplicate(true)
	func _sync_world_state() -> void: pass
	func _refresh() -> void: pass
	func _travel(map: String, position: Vector2) -> void:
		_close_modal(); state.map_id = map; world.map_id = map; world.player_pos = position; _autosave()
	func _start_party_consignee_battle(generation: int) -> bool:
		if generation != modal_generation or not consignee_story.battle_entry_ready(): return false
		_autosave()
		if save_warning or not state.start_party_battle("heting_consignee"): return false
		starts += 1; modal_generation += 1; current_screen = "party_battle"
		return true

func _init() -> void:
	_read_only_and_context()
	_failures_and_stale_actions()
	_observations_and_live_companions()
	_completion_and_parking()
	for h in hosts:
		h.options.clear(); h.consignee_story.host = null; h.consignee_story = null
	hosts.clear()
	print("%s: %d consignee story boundary checks (live guards, observations, save failures, finite handover)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _host(harbor: String = "short_ferries", receipt: int = 0):
	var h = HostStub.new(); hosts.append(h); var s = h.state
	s.quest_stage = 6; s.ending = "守望"; s.side_stage = 3; s.side_choice = "rescue"; s.side_reward_claimed = true
	s.side_found.assign(["boatman", "ledger"]); s.side_clues = 2; s.chapter_two_stage = 4; s.chapter_two_ending = "protect_witness"
	s.archive_clues.assign(["clerk", "inscription"]); s.seal_sequence.assign([2,0,1]); s.mist_stage = 4; s.mist_gauges.assign(["rain","stone","basin"])
	s.mist_approach = "duel"; s.mist_ending = "release_water"; s.heting_stage = 4; s.heting_bridge = "east"; s.heting_delivered.assign(["meal","sealed","reserve"])
	s.heting_draft = harbor; s.heting_ending = harbor; s.receipt_stage = receipt; s.map_id = "heting"; s.position = h.world.player_pos
	h.consignee_story = Story.new(h)
	check(s._stage_save_data(s.to_dict(),14).ok, "Whole-state synthetic old ending is canonical")
	return h
func _go(h, site: String) -> void:
	h.world.player_pos = h.world.interactables[site].pos; h.state.position = h.world.player_pos
func _choose(h, label: String) -> Callable:
	for entry: Array in h.options:
		if entry[0] == label: return entry[1]
	check(false, "Expected option exists: " + label + " in " + str(h.options.map(func(entry): return entry[0])))
	return func(): pass
func _start(h) -> void:
	h.consignee_story.open(); _choose(h,"接下本批核查").call()
func _investigate(h, order: Array = ["lot_seals","removal_order","southern_counterfoil"]) -> void:
	_start(h)
	for id: String in order:
		var site: String = Story.OBSERVATION_SITES[id]; _go(h, site); h.consignee_story.open(site)
		_choose(h,"亲自核验").call()
	_choose(h,"核对三处矛盾").call(); _choose(h,"未验先撤，理由倒置").call()
func _invalidate(h, reason: String) -> void:
	match reason:
		"screen": h.current_screen = "title"
		"state_map": h.state.map_id = "mistwood"
		"world_map": h.world.map_id = "mistwood"
		"quit": h.quit_pending = true
		"battle": h.state.battle_active = true
		"token": h.state._party_pending_token = 77
		"stage": h.state.heting_stage = 3
		"ending": h.state.heting_ending = ""
		"hp": h.state.hp = 0
		"invalid_resource": h.state.medicine = -1
		"distance": h.world.player_pos += Vector2(75,0)
		"nonfinite": h.world.player_pos = Vector2(INF,350)
		"missing_site": h.world.interactables.clear()
func _read_only_and_context() -> void:
	for harbor: String in ["short_ferries","open_scale"]:
		for receipt: int in range(4):
			var h = _host(harbor,receipt); var before: Dictionary = h.state.to_dict()
			h.consignee_story.open()
			check(h.active_modal and not h.modal_autosave_on_close and h.body.contains("杜晦") and h.body.contains("平川粮栈"), "Either old ending/optional receipt opens distinct receiver story")
			_choose(h,"先不接下").call()
			check(h.state.to_dict() == before and h.writes == 0 and not h.active_modal, "Inspect and decline make no progress or save")
	for reason: String in ["screen","state_map","world_map","quit","battle","token","stage","ending","hp","invalid_resource","distance","nonfinite","missing_site"]:
		var h = _host(); h.consignee_story.open(); var callback: Callable = _choose(h,"接下本批核查")
		_invalidate(h,reason); var before: Dictionary = h.state.to_dict(); callback.call()
		check(h.state.to_dict() == before and h.writes == 0 and h.starts == 0, "Acceptance rejects live invalid context: " + reason)
		h.active_modal = false; h.consignee_story.open()
		check(not h.active_modal, "Invalid context cannot open new page: " + reason)
func _failures_and_stale_actions() -> void:
	var h = _host(); h.fail_save = true; h.consignee_story.open(); var stale: Callable = _choose(h,"接下本批核查")
	stale.call(); check(h.state.consignee_stage == 1 and h.writes == 1 and h.save_warning and h.body.contains("未成功"), "Failed acceptance retains in-memory progress with retry")
	stale.call(); check(h.writes == 1, "Repeated accepted generation is stale")
	var retry: Callable = _choose(h,"重试保存"); retry.call(); check(h.writes == 2 and h.state.consignee_stage == 1, "Failed retry only writes same state")
	h.fail_save = false; _choose(h,"重试保存").call(); retry.call()
	check(h.writes == 3 and h.persisted.consignee_stage == 1 and not h.save_warning, "Successful retry writes once; stale retry blocked")
	var examine: Callable = _choose(h,"亲自核验"); _choose(h,"先不核验").call(); h.consignee_story.open(); examine.call()
	check(h.state.consignee_observations.is_empty() and h.writes == 3, "Cancelled examination cannot affect newer page")
	h = _host(); _investigate(h); _choose(h,"拟作封粮留验").call(); _go(h,Rules.SOURCE); h.consignee_story.open(Rules.SOURCE)
	h.fail_save = true; var battle: Callable = _choose(h,"保存后阻止强提"); var before: Dictionary = h.state.to_dict(); battle.call()
	check(h.state.to_dict() == before and h.starts == 0 and h.body.contains("交锋尚未开始"), "Failed pre-entry checkpoint refuses combat and resource use")
	h.fail_save = false; _choose(h,"重试保存").call(); check(h.starts == 0, "Saving retry never automatically starts fight")
	_choose(h,"保存后阻止强提").call(); battle.call(); check(h.starts == 1 and h.state.battle_active, "One accepted modal starts one real state combat")
	var flee: Dictionary = h.state.party_battle_action("flee"); var result: Dictionary = h.state.finish_party_presentation(flee.epoch,flee.token)
	h.current_screen = "explore"; h.consignee_story.after_battle(result.settlement)
	check(h.state.consignee_stage == 2 and h.body.contains("未推进"), "Retreat result explains retained investigation and draft")
func _observations_and_live_companions() -> void:
	for order: Array in [["lot_seals","removal_order","southern_counterfoil"],["southern_counterfoil","removal_order","lot_seals"],["removal_order","lot_seals","southern_counterfoil"]]:
		var h = _host(); _start(h)
		for id: String in order:
			var site: String = Story.OBSERVATION_SITES[id]; _go(h,site); h.consignee_story.open(site)
			var action: Callable = _choose(h,"亲自核验"); action.call(); var writes: int = h.writes; action.call()
			check(h.state.consignee_observations.has(id) and h.writes == writes, "Physical clue accepted once: " + id)
		_choose(h,"核对三处矛盾").call()
		for wrong: String in ["两篓干粮证明整船无损","必须先补取旧复签","只凭收货姓氏便可结案"]:
			var before: Dictionary = h.state.to_dict(); var writes: int = h.writes
			_choose(h,wrong).call(); check(h.state.to_dict() == before and h.writes == writes and not h.body.is_empty(), "Wrong deduction is explanatory/read-only")
			_choose(h,"重新核对").call()
		_choose(h,"未验先撤，理由倒置").call(); check(h.state.consignee_stage == 2, "Three observations support bounded deduction in any order")
	for method: String in Rules.CONTRIBUTIONS:
		var h = _host(); var actor: String = "tang" if method.begins_with("tang") else ("shen" if method.begins_with("shen") else "qin")
		if actor == "tang":
			h.state.bridge_repaired = true; h.state.tangqi_stage = 3; h.state.tangqi_choice = "teach" if method == "tang_teach" else "preserve"; check(h.state.recruit_tangqi(), "Synthetic earned Tang recruitment")
		elif actor == "shen":
			check(h.state.recruit_companion(), "Synthetic Shen recruitment"); h.state.shen_care_stage = 5; h.state.shen_care_choice = "shore" if method == "shen_shore" else "mobile"
		else:
			h.state.map_id = "mistwood"; check(h.state.begin_qin_quest() and h.state.inspect_qin_rope() and h.state.arrange_qin_handoff() and h.state.recruit_qin(), "Synthetic Qin actual recruitment"); h.state.map_id = "heting"
		_start(h); var observation: String = "lot_seals" if actor == "tang" else ("southern_counterfoil" if actor == "shen" else "removal_order")
		var site: String = Story.OBSERVATION_SITES[observation]; _go(h,site); h.consignee_story.open(site)
		var help: Callable = _choose(h,Story.METHOD_LABELS[method]); h.state.party_resources[actor].hp = 0; var writes: int = h.writes; help.call()
		check(h.state.consignee_observations.is_empty() and h.writes == writes, "Companion must still stand at action: " + method)
		h.state.party_resources[actor].hp = 1; h.consignee_story.open(site); help = _choose(h,Story.METHOD_LABELS[method]); check(h.state.set_party_roster(["hero"]), "Bench helper"); help.call()
		check(h.state.consignee_observations.is_empty() and h.writes == writes, "Companion must still be selected: " + method)
		check(h.state.set_party_roster(["hero",actor]), "Reselect living helper"); h.consignee_story.open(site); _choose(h,Story.METHOD_LABELS[method]).call()
		check(h.state.consignee_observations == [observation] and h.state.consignee_contributions == [method] and h.body.contains(Rules.method_description(method)), "Alternative records actual contribution: " + method)
func _win(h) -> void:
	_go(h,Rules.SOURCE); h.consignee_story.open(Rules.SOURCE); h.state.attack = 900; h.state.defense = 900
	_choose(h,"保存后阻止强提").call(); var terminal: Dictionary = Driver.terminal_next(h.state); var result: Dictionary = h.state.finish_party_presentation(terminal.epoch,terminal.token)
	h.current_screen = "explore"; h.consignee_story.after_battle(result.settlement)
	check(h.state.consignee_stage == 3 and result.settlement.reward_xp == 0 and result.settlement.coin_change == 0, "Real win secures without rewards")
func _completion_and_parking() -> void:
	for plan: String in Rules.PLANS:
		var h = _host(); _investigate(h); _choose(h,"拟作"+Story.PLAN_NAMES[plan]).call(); _win(h)
		_choose(h,"查看北仓这一车").call(); var take: Callable = _choose(h,"押本批两篓封粮"); take.call(); take.call()
		check(h.state.consignee_stage == 4 and h.state.consignee_cargo_location == "cart" and h.state.heting_cargo.is_empty(), "One distinct cart leaves old cargo untouched")
		_go(h,"return_mistwood"); check(h.consignee_story.leave(), "Loaded leave requires explicit page"); var park: Callable = _choose(h,"停回北仓后离开"); _choose(h,"留在埠内").call(); park.call()
		check(h.state.consignee_stage == 4 and h.state.map_id == "heting", "Cancelled leave never parks/travels")
		h.consignee_story.leave(); h.fail_save = true; _choose(h,"停回北仓后离开").call()
		check(h.state.consignee_stage == 3 and h.state.map_id == "heting" and h.save_warning, "Failed parking save keeps same stock at warehouse and stays in port")
		h.fail_save = false; _choose(h,"重试保存").call(); check(h.state.map_id == "mistwood" and h.state.consignee_stage == 3, "Successful parking retry continues authorized departure")
		h.state.map_id = "heting"; h.world.map_id = "heting"; _go(h,Rules.SOURCE); h.consignee_story.open(Rules.SOURCE); _choose(h,"押本批两篓封粮").call()
		var site: String = "heting_scale" if plan == "hold_for_inspection" else "heting_cargo"; _go(h,site); h.consignee_story.open(site)
		var finish: Callable = _choose(h,"确认交下本批"); var before: Dictionary = h.state.to_dict(); var coins: int = h.state.coins; var xp: int = h.state.xp + 30*h.state.level*(h.state.level-1)
		_go(h,Rules.SOURCE); finish.call(); h.consignee_story._finish(Rules.SOURCE,Rules.GRAIN_BOAT,plan)
		check(h.state.consignee_stage == 4 and h.state.coins == coins, "Remote callback and forged receiver source reject")
		_go(h,site); h.fail_save = true; finish.call()
		check(h.state.consignee_stage == 5 and h.state.consignee_ending == plan and h.save_warning, "Failed final write preserves one accepted ending")
		check(h.state.coins == coins+60 and h.state.xp+30*h.state.level*(h.state.level-1) == xp+120, "Equal final reward exactly once")
		var settled: Dictionary = h.state.to_dict(); finish.call(); h.fail_save = false; _choose(h,"重试保存").call()
		check(h.state.to_dict() == settled and h.persisted == settled and h.body.contains("不再发奖"), "Final retry persists rather than replaying reward")
		check(h.state.heting_ending == before.heting_ending and h.state.receipt_stage == before.receipt_stage, "Old endings and optional receipt unchanged")
