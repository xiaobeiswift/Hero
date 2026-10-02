extends SceneTree
## Controller boundary tests use actual HeroState rules and a synchronous host
## double: no player save is read/written and no scene/battle UI is substituted.
const State = preload("res://scripts/game_state.gd")
const Story = preload("res://scripts/heting_receipt_story.gd")
var checks: int = 0
var failures: int = 0


class WorldStub:
	extends RefCounted
	var map_id: String = "heting"
	var player_pos: Vector2 = Vector2(420, 220)
	var interactables: Dictionary = {"heting_scale": {"pos": Vector2(420, 220)}}


class HostStub:
	extends RefCounted
	var state = State.new()
	var world = WorldStub.new()
	var current_screen: String = "explore"
	var active_modal: bool = false
	var modal_generation: int = 0
	var modal_autosave_on_close: bool = true
	var save_warning: bool = false
	var fail_save: bool = false
	var writes: int = 0
	var starts: int = 0
	var title: String = ""
	var subtitle: String = ""
	var body: String = ""
	var options: Array = []
	var persisted: Dictionary = {}
	var events: Array[String] = []

	func _modal(heading: String, subheading: String, text: String, choices: Array = [], _wide: bool = false) -> void:
		modal_generation += 1
		active_modal = true
		modal_autosave_on_close = true
		title = heading
		subtitle = subheading
		body = text
		options = choices.duplicate()

	func _close_modal() -> void:
		var autosave: bool = modal_autosave_on_close
		modal_autosave_on_close = true
		modal_generation += 1
		active_modal = false
		options.clear()
		events.append("close")
		if autosave:
			_autosave()

	func _autosave() -> void:
		writes += 1
		events.append("save")
		state.position = world.player_pos
		save_warning = fail_save
		if not fail_save:
			persisted = state.to_dict().duplicate(true)

	func _start_receipt_battle() -> void:
		events.append("start")
		if state.start_receipt_battle():
			starts += 1
			current_screen = "battle"


func _init() -> void:
	_test_read_only_and_endings()
	_test_proximity_and_context()
	_test_acceptance_and_checkpoint_failures()
	_test_stale_choices()
	_test_comparison_and_record()
	_test_settled_results()
	if failures == 0:
		print("PASS: %d Heting receipt story checks (both endings/checkpoints/stale choices/comparison/settled results)" % checks)
	else:
		push_error("FAIL: %d of %d Heting receipt story checks" % [failures, checks])
	quit(0 if failures == 0 else 1)


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


func _host(ending: String = "short_ferries"):
	var host = HostStub.new()
	var s = host.state
	s.quest_stage = 6
	s.ending = "守望"
	s.side_stage = 3
	s.side_choice = "rescue"
	s.side_reward_claimed = true
	s.side_found.assign(["boatman", "ledger"])
	s.side_clues = 2
	s.chapter_two_stage = 4
	s.chapter_two_ending = "protect_witness"
	s.archive_clues.assign(["clerk", "inscription"])
	s.seal_sequence.assign([2, 0, 1])
	s.mist_stage = 4
	s.mist_gauges.assign(["rain", "stone", "basin"])
	s.mist_approach = "duel"
	s.mist_ending = "release_water"
	s.heting_stage = 4
	s.heting_bridge = "east"
	s.heting_delivered.assign(["meal", "sealed", "reserve"])
	s.heting_draft = ending
	s.heting_ending = ending
	s.map_id = "heting"
	s.position = host.world.player_pos
	return host


func _choice(host, text: String) -> Callable:
	for entry: Array in host.options:
		if String(entry[0]) == text:
			return entry[1]
	check(false, "Expected choice exists: " + text)
	return func(): pass


func _test_read_only_and_endings() -> void:
	for ending: String in ["short_ferries", "open_scale"]:
		var host = _host(ending)
		var story = Story.new(host)
		var before: Dictionary = host.state.to_dict()
		story.open()
		check(host.active_modal and host.subtitle.contains("可选") and host.body.contains("次晨"), "Both endings open an optional next-morning review: " + ending)
		check(host.body.contains("两名受雇刀手") and host.body.contains("假水损票") and host.body.contains("预结粮钱"), "Knife hands have a bounded motive tied to established evidence")
		check(host.body.contains("没有夜班") if ending == "short_ferries" else host.body.contains("守秤"), "No new night guard contradicts the chosen ending")
		check(not host.modal_autosave_on_close and host.writes == 0 and host.state.to_dict() == before, "Opening adds no automatic reward, resource change or save")
		_choice(host, "先不接下").call()
		check(not host.active_modal and host.state.to_dict() == before and host.writes == 0, "Declining leaves old chapter and receipt stage untouched")


func _invalidate(host, kind: String) -> void:
	match kind:
		"screen": host.current_screen = "title"
		"state_map": host.state.map_id = "mistwood"
		"world_map": host.world.map_id = "mistwood"
		"battle": host.state.battle_active = true
		"cargo": host.state.heting_cargo = "meal"
		"harbor": host.state.heting_stage = 3
		"invalid_ending": host.state.heting_ending = ""
		"missing_scale": host.world.interactables.clear()
		"distance": host.world.player_pos += Vector2(75, 0)
		"nonfinite": host.world.player_pos = Vector2(INF, 220)


func _test_proximity_and_context() -> void:
	for kind: String in ["screen", "state_map", "world_map", "battle", "cargo", "harbor", "invalid_ending", "missing_scale", "distance", "nonfinite"]:
		var host = _host()
		var story = Story.new(host)
		_invalidate(host, kind)
		var before: Dictionary = host.state.to_dict()
		story.open()
		check(not host.active_modal and host.writes == 0 and host.state.to_dict() == before, "Open refuses invalid context: " + kind)
		# Change the context after capturing a real button from a valid page.
		host = _host()
		story = Story.new(host)
		story.open()
		var accept: Callable = _choice(host, "接下取签之事")
		_invalidate(host, kind)
		before = host.state.to_dict()
		accept.call()
		check(host.writes == 0 and host.starts == 0 and host.state.to_dict() == before, "Accepted callback revalidates live context: " + kind)
	var host = _host()
	host.world.player_pos += Vector2(74.9, 0)
	Story.new(host).open()
	check(host.active_modal, "Distance under 75 is permitted")


func _test_acceptance_and_checkpoint_failures() -> void:
	var host = _host()
	var story = Story.new(host)
	host.fail_save = true
	story.open()
	_choice(host, "接下取签之事").call()
	check(host.state.receipt_stage == 1 and host.save_warning and host.writes == 1 and host.starts == 0, "Failed acceptance checkpoint keeps accepted memory without starting battle")
	check(host.subtitle.contains("尚未存妥") and host.options.size() == 2 and not host.modal_autosave_on_close, "Failed checkpoint offers retry and leave, with no accidental close save")
	var retry: Callable = _choice(host, "重试保存")
	retry.call()
	check(host.state.receipt_stage == 1 and host.writes == 2 and host.starts == 0, "Failed retry never discards acceptance or starts")
	host.fail_save = false
	_choice(host, "重试保存").call()
	check(host.persisted.receipt_stage == 1 and host.writes == 3 and not host.save_warning and host.starts == 0, "Successful retry persists acceptance before offering a fight")
	check(host.body.contains("Tab") and host.body.contains("最多遗落8文") and host.body.contains("免费调息") and host.body.contains("真实消耗"), "Ready page gives controls, actual stakes and free rest")
	check(host.body.begins_with("当前气血") and host.body.contains("拖到月上"), "Resources lead the ready page and narrative accounts for moonlit dock")
	retry.call()
	check(host.writes == 3, "Old save-retry callback cannot act on the new ready page")
	host.state.hp = 23
	host.state.qi = 1
	host.state.medicine = 0
	host.fail_save = true
	_choice(host, "保存后应战").call()
	check(host.writes == 4 and host.starts == 0 and not host.state.battle_active and host.state.hp == 23, "Failed current-resource checkpoint blocks battle without healing")
	_choice(host, "先回埠内").call()
	check(not host.active_modal and host.writes == 4 and host.state.receipt_stage == 1, "Leaving save failure preserves accepted progress and avoids implicit save")
	host.fail_save = false
	story.open()
	check(host.body.contains("气血23/") and host.body.contains("真气1/") and host.body.contains("回春散0份"), "Retry preview reads live resources")
	var start: Callable = _choice(host, "保存后应战")
	start.call()
	check(host.starts == 1 and host.state.battle_active and host.writes == 5, "Successful start uses one explicit checkpoint and one fight")
	check(host.events.slice(-3) == ["save", "close", "start"] and host.persisted.hp == 23 and host.persisted.qi == 1 and host.persisted.medicine == 0, "Current checkpoint precedes dialogue close and start without a close autosave")
	start.call()
	check(host.starts == 1 and host.writes == 5, "Repeated start is stale after transition")


func _test_stale_choices() -> void:
	var host = _host()
	var story = Story.new(host)
	story.open()
	var accept: Callable = _choice(host, "接下取签之事")
	var old_close: Callable = _choice(host, "先不接下")
	host._close_modal()
	story.open()
	accept.call()
	old_close.call()
	check(host.active_modal and host.state.receipt_stage == 0 and host.writes == 0, "Cancelled page cannot accept or close a newly opened page")
	_choice(host, "接下取签之事").call()
	var start: Callable = _choice(host, "保存后应战")
	var close: Callable = _choice(host, "暂且离开")
	host.modal_generation += 1
	start.call()
	close.call()
	check(host.active_modal and host.writes == 1 and host.starts == 0, "Changed generation rejects progression and close callbacks")
	for kind: String in ["screen", "state_map", "world_map", "battle", "cargo", "harbor", "invalid_ending", "missing_scale", "distance", "nonfinite"]:
		host = _host()
		host.state.receipt_stage = 1
		story = Story.new(host)
		story.open()
		start = _choice(host, "保存后应战")
		_invalidate(host, kind)
		start.call()
		check(host.starts == 0 and host.writes == 0, "Start rechecks full live context: " + kind)


func _test_comparison_and_record() -> void:
	for ending: String in ["short_ferries", "open_scale"]:
		var host = _host(ending)
		host.state.receipt_stage = 2
		var story = Story.new(host)
		story.open()
		var compare: Callable = _choice(host, "并看三处记号")
		var coins: int = host.state.coins
		var xp: int = host.state.xp
		host.fail_save = true
		compare.call()
		check(host.state.receipt_stage == 3 and host.save_warning and host.writes == 1, "Compare changes real stage once even when persistence fails: " + ending)
		check(host.body.contains("不添船工姓名") and host.body.contains("不拿它替整船") and host.body.contains("安排照旧"), "Evidence is bounded to two loads and preserves the ending")
		compare.call()
		check(host.writes == 1 and host.state.coins == coins and host.state.xp == xp, "Repeated comparison grants nothing and cannot repeat a failed save")
		host.fail_save = false
		_choice(host, "重试保存").call()
		check(host.persisted.receipt_stage == 3 and not host.save_warning and host.state.coins == coins and host.state.xp == xp, "Record-save retry persists the same reward-free result")
		_choice(host, "收好记录").call()
		story.open()
		check(host.writes == 2 and host.options.size() == 1 and host.state.receipt_stage == 3, "Completed revisit is record-only with no new writes")
	for kind: String in ["screen", "state_map", "world_map", "battle", "cargo", "harbor", "invalid_ending", "missing_scale", "distance", "nonfinite"]:
		var host = _host()
		host.state.receipt_stage = 2
		var story = Story.new(host)
		story.open()
		var compare: Callable = _choice(host, "并看三处记号")
		_invalidate(host, kind)
		compare.call()
		check(host.state.receipt_stage == 2 and host.writes == 0, "Comparison revalidates live context: " + kind)


func _settle(host, outcome: String) -> Dictionary:
	var s = host.state
	s.receipt_stage = 1
	s.attack = 999
	s.defense = 99
	s.hp = 1 if outcome == "defeat" else s.max_hp
	if outcome == "defeat":
		s.defense = 0
		s.attack = 1
	check(s.start_receipt_battle(), "Actual wrapper begins result fixture")
	var action: String = "flee" if outcome == "flee" else "attack"
	for _i in range(3):
		if not s.battle_active:
			break
		var tx: Dictionary = s.receipt_battle_action(action)
		check(tx.accepted and s.finish_receipt_presentation(tx.epoch, tx.token), "Actual wrapper settles accepted result action")
	check(not s.battle_active and s.receipt_settlement.outcome == outcome and s.receipt_settlement.is_read_only(), "Result uses actual immutable settlement: " + outcome)
	host.current_screen = "explore"
	host.world.player_pos = s.position
	return s.receipt_settlement


func _test_settled_results() -> void:
	for outcome: String in ["win", "flee", "defeat"]:
		var host = _host()
		host.state.coins = 3
		var story = Story.new(host)
		var summary: Dictionary = _settle(host, outcome)
		var before: Dictionary = host.state.to_dict()
		var facts: Dictionary = summary.duplicate(true)
		host.save_warning = true
		story.after_battle(summary)
		check(host.active_modal and host.state.to_dict() == before and summary == facts and host.writes == 0, "Result rendering neither settles nor saves again: " + outcome)
		check(host.body.contains("尚未存妥"), "Unresolved result save is disclosed: " + outcome)
		if outcome == "win":
			check(host.body.contains("80修为、40文") and host.body.contains("境界由"), "Victory reads actual reward and level movement")
			_choice(host, "与施衡核签").call()
			check(host.subtitle.contains("副签待核") and host.state.receipt_stage == 2, "Victory leads to explicit comparison without advancing yet")
			_choice(host, "稍后再核").call()
		elif outcome == "flee":
			check(host.body.contains("不另扣钱") and host.body.contains("免费调息"), "Flee reports retained costs and free recovery")
			host.world.player_pos = Vector2(230, 735)
			_choice(host, "先回埠内").call()
		else:
			check(host.body.contains("遗落了3文") and host.body.contains("没有返还") and host.world.player_pos == Vector2(230, 735), "Defeat reports actual bounded coin loss and medicine rule")
			_choice(host, "在西岸歇脚").call()
		check(not host.active_modal and host.writes == 0 and host.state.to_dict() == before, "Result can close without scale proximity or extra resource/reward changes: " + outcome)
		story.after_battle(summary)
		var stale_close: Callable = host.options[-1][1]
		host._close_modal()
		host._modal("new page", "new", "new", [])
		stale_close.call()
		check(host.active_modal and host.title == "new page", "Result close cannot dismiss a newer page: " + outcome)
	var host = _host()
	var story = Story.new(host)
	var summary: Dictionary = _settle(host, "win")
	host.state.compare_receipt()
	story.after_battle(summary)
	check(not host.active_modal, "Old victory summary cannot replace a completed comparison")
