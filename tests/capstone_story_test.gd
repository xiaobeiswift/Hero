extends SceneTree
## State-backed controller unit tests, with a synthetic world/folio host.
## Uses real canonical State, real atomic saves and authentic combat tokens.
## This is NOT actual main-scene input, walking, earned balance or visual QA.
const State = preload("res://scripts/game_state.gd")
const Story = preload("res://scripts/volume_one_capstone_story.gd")
const Rules = preload("res://scripts/volume_one_capstone_rules.gd")
const HetingStory = preload("res://scripts/heting_story.gd")
const Driver = preload("res://tests/automatic_state_test_driver.gd")
var checks: int = 0
var failures: int = 0
var hosts: Array = []
var fixture_root: String = ""

class WorldFixture extends RefCounted:
	var map_id: String = "heting"
	var player_pos: Vector2 = Vector2(535, 350)
	var interactables: Dictionary = {"heting_dispatch": {"pos": Vector2(535,350)}, "chapter_host": {"pos": Vector2(405,365)}, "chapter_clerk": {"pos": Vector2(1150,385)}, "chapter_archive": {"pos": Vector2(1320,745)}, "capstone_order_desk": {"pos": Vector2(1340,650)}, "elder": {"pos": Vector2(520,440)}}
	func teleport(point: Vector2) -> void: player_pos = point

class FolioFixture extends RefCounted:
	var state = State.new()
	var world = WorldFixture.new()
	var current_screen: String = "explore"
	var quit_pending: bool = false
	var active_modal: bool = false
	var modal_generation: int = 0
	var modal_autosave_on_close: bool = true
	var save_warning: bool = false
	var title: String = ""
	var subtitle: String = ""
	var body: String = ""
	var options: Array = []
	var writes: int = 0
	var starts: int = 0
	var path: String = ""
	var capstone_story
	var heting_story
	var toast: String = ""
	func _modal(heading: String, sub: String, text: String, choices: Array, _wide: bool) -> void:
		modal_generation += 1; active_modal = true; modal_autosave_on_close = true
		title = heading; subtitle = sub; body = text; options = choices.duplicate()
	func _close_modal() -> void:
		var save: bool = modal_autosave_on_close
		modal_generation += 1; active_modal = false; options.clear(); modal_autosave_on_close = true
		if save: _autosave()
	func _sync_world_state() -> void: pass
	func _refresh() -> void: pass
	func _toast(text: String) -> void: toast = text
	func _autosave() -> void:
		writes += 1; state.position = world.player_pos
		save_warning = state.save_game(path) != OK
	func _start_party_capstone_battle(generation: int) -> bool:
		if generation != modal_generation or not capstone_story.battle_entry_ready(): return false
		_autosave()
		if save_warning or not state.start_party_battle("capstone_authorizer"): return false
		starts += 1; modal_generation += 1; current_screen = "party_battle"
		return true

func _init() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): quit(2); return
	fixture_root = "user://capstone-story-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(fixture_root) == OK, "Isolated real atomic-save directory")
	_guards_and_reads()
	_letter_and_evidence()
	_helper_live_eligibility()
	_battle_boundary()
	_classify_and_plan()
	_completion_and_rewards()
	_authored_pages()
	for h in hosts:
		DirAccess.remove_absolute(h.path + ".tmp")
		h.options.clear(); h.capstone_story.host = null; h.capstone_story = null; h.heting_story.host = null; h.heting_story = null
	hosts.clear()
	for file: String in DirAccess.get_files_at(fixture_root): DirAccess.remove_absolute(fixture_root.path_join(file))
	DirAccess.remove_absolute(fixture_root)
	print("%s: %d capstone story controller checks; synthetic UI/world host + real State/disk/token mechanics, not main-scene input or earned balance" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _host(stage: int = 0, site: String = "heting_dispatch"):
	var h = FolioFixture.new(); hosts.append(h); var s = h.state
	s.quest_stage = 6; s.ending = "守望"; s.side_stage = 3; s.side_choice = "rescue"; s.side_clues = 2; s.side_found.assign(["boatman", "ledger"]); s.side_reward_claimed = true
	s.chapter_two_stage = 4; s.chapter_two_ending = "protect_witness"; s.archive_clues.assign(["clerk", "inscription"]); s.seal_sequence.assign([2, 0, 1])
	s.mist_stage = 4; s.mist_approach = "duel"; s.mist_gauges.assign(["rain", "stone", "basin"]); s.mist_ending = "release_water"
	s.heting_stage = 4; s.heting_bridge = "east"; s.heting_delivered.assign(["meal", "sealed", "reserve"]); s.heting_draft = "short_ferries"; s.heting_ending = "short_ferries"
	s.consignee_stage = 5; s.consignee_observations.assign(State.Consignee.OBSERVATIONS); s.consignee_draft = "return_to_owner"; s.consignee_ending = "return_to_owner"; s.consignee_cargo_location = "grain_boat"
	s.capstone_stage = stage
	if stage >= 6: s.capstone_draft = "pause_batch"; s.capstone_ending = "pause_batch"
	h.path = fixture_root.path_join("host-%d.json" % hosts.size())
	h.capstone_story = Story.new(h); h.heting_story = HetingStory.new(h); _go(h, site)
	check(s._stage_save_data(s.to_dict(), s.SAVE_VERSION).ok, "Synthetic complete historical fixture is canonical")
	check(s.save_game(h.path) == OK, "Initial real disk checkpoint")
	return h

func _go(h, site: String) -> void:
	h.world.map_id = Story.SITES[site]; h.state.map_id = h.world.map_id
	h.world.player_pos = h.world.interactables[site].pos; h.state.position = h.world.player_pos

func _choose(h, label: String) -> Callable:
	for entry: Array in h.options:
		if entry[0] == label: return entry[1]
	check(false, "Expected choice: %s; actual %s" % [label, str(h.options.map(func(entry): return entry[0]))])
	return func(): pass

func _press(h, label: String) -> void: _choose(h, label).call()

func _fail(h) -> PackedByteArray:
	var old: PackedByteArray = FileAccess.get_file_as_bytes(h.path)
	check(DirAccess.make_dir_absolute(h.path + ".tmp") == OK, "Force save failure with same-target temp directory")
	return old

func _retry(h, old: PackedByteArray) -> void:
	var accepted: Dictionary = h.state.to_dict()
	check(h.save_warning and FileAccess.get_file_as_bytes(h.path) == old, "Failure retains original disk bytes")
	var stale: Callable = _choose(h, "重试保存")
	stale.call()
	check(h.state.to_dict() == accepted and FileAccess.get_file_as_bytes(h.path) == old, "Failed retry serializes only; accepted memory unchanged")
	DirAccess.remove_absolute(h.path + ".tmp")
	_press(h, "重试保存")
	var writes: int = h.writes; stale.call()
	check(h.writes == writes and h.state.to_dict() == accepted and not h.save_warning, "Successful retry and stale retry never replay mutation")
	var reloaded = State.new()
	check(reloaded.load_game(h.path) == OK and reloaded.to_dict() == accepted, "Exact accepted state can reload from successful retry")

func _invalidate(h, reason: String) -> void:
	match reason:
		"screen": h.current_screen = "title"
		"quit": h.quit_pending = true
		"battle": h.state.battle_active = true
		"token": h.state._party_pending_token = 88
		"state_map": h.state.map_id = "mistwood"
		"world_map": h.world.map_id = "mistwood"
		"distance": h.world.player_pos += Vector2(75, 0)
		"nonfinite": h.world.player_pos = Vector2(INF, 350)
		"missing_site": h.world.interactables.clear()
		"site_nonfinite": h.world.interactables.heting_dispatch.pos = Vector2(INF, 350)
		"invalid_resource": h.state.medicine = -1
		"invalid_history": h.state.consignee_stage = 4
		"hp": h.state.hp = 0
		"modal_closed": h.active_modal = false
		"generation": h.modal_generation += 1
		"world_replaced": h.world = WorldFixture.new()
		"state_reloaded":
			var replacement = State.new(); check(replacement.load_game(h.path) == OK, "Load replacement state identity")
			h.state = replacement

func _guards_and_reads() -> void:
	for reason: String in ["screen", "quit", "battle", "token", "state_map", "world_map", "distance", "nonfinite", "missing_site", "site_nonfinite", "invalid_resource", "invalid_history", "hp", "modal_closed", "generation", "state_reloaded", "world_replaced"]:
		var h = _host(); h.capstone_story.open("heting_dispatch")
		var callback: Callable = _choose(h, "接下查册引介"); _invalidate(h, reason)
		var before: Dictionary = h.state.to_dict(); callback.call()
		check(h.state.to_dict() == before and h.writes == 0 and h.starts == 0, "Full live callback rejects " + reason)
		if reason not in ["modal_closed", "generation", "state_reloaded", "world_replaced"]:
			h.active_modal = false; h.capstone_story.open("heting_dispatch")
			check(not h.active_modal, "Direct open rejects " + reason)
	var h = _host(); var before: Dictionary = h.state.to_dict()
	h.capstone_story.open("heting_dispatch"); var stale: Callable = _choose(h, "接下查册引介")
	_press(h, "重看两篓交接"); _press(h, "回到眼前"); stale.call()
	check(h.state.to_dict() == before and h.writes == 0, "Read-only A-to-B-to-A pages invalidate old acceptance")
	_press(h, "先留在埠内")
	check(h.state.to_dict() == before and h.writes == 0 and not h.active_modal, "Reading and closing never progress or save")
	for manifest_stage: int in [0, 1, 7]:
		h = _host(manifest_stage); h.capstone_story.open("heting_dispatch"); _press(h, "另谈鹤汀旧事")
		before = h.state.to_dict(); var manifest: Callable = _choose(h, "查看原交割单"); manifest.call()
		check(h.body == h.heting_story.manifest_body() and h.body.contains("开锅粮") and h.body.contains("对秤封粮") and h.body.contains("待分粮"), "Guarded original manifest preserves full exact read-only old contents")
		_press(h, "回到交割旧事"); manifest.call()
		check(h.capstone_story._page == "legacy_record" and h.state.to_dict() == before and h.writes == 0, "Stale manifest callback cannot reopen after returning; no progress/save")
		_press(h, "查看原交割单"); _press(h, "继续行走")
		check(h.state.to_dict() == before and h.writes == 0, "Original manifest close stays read-only")
	for stage: int in [1, 2, 3]:
		h = _host(stage, "capstone_order_desk"); before = h.state.to_dict(); h.capstone_story.open("capstone_order_desk")
		check(h.body.contains("不能远程") and Rules.order_rows(h.state).is_empty(), "Early desk has no book or remote progress")
		_press(h, "记下去处"); check(h.state.to_dict() == before and h.writes == 0, "Early desk close read-only")
	h = _host(0, "chapter_host"); check(not h.capstone_story.handle("chapter_host"), "Old Wen branch remains owner before capstone")
	h = _host(2, "chapter_archive"); check(not h.capstone_story.handle("chapter_archive"), "Premature archive falls back to old completed chapter")

func _letter(h) -> void:
	h.capstone_story.open("chapter_host")
	_press(h, "展开原信"); check(h.body.contains("见此信、愿查证的人") and h.body.contains("留稿"), "Original and unmailed draft are visibly compared")
	_press(h, "听他说明作者"); check(h.body.contains("信是我写的") and h.body.contains("不知道鹤汀"), "Wen admits bounded authorship without foreknowledge")
	_press(h, "这封信要我做到哪里？")

func _evidence(h) -> void:
	h.capstone_story.open("chapter_clerk")
	check(h.body.contains("霜签甲17") and h.body.contains("霜签甲18"), "First issued page shows concrete changed-time/rain authority")
	_press(h, "继续核两次鹤汀授权"); check(h.body.contains("霜签乙06") and h.body.contains("霜签乙09"), "Second issued page separates old two担 and new two篓")
	_press(h, "核看经办与分存"); check(h.body.contains("梁缜") and h.body.contains("已交发"), "Register identifies actual named authorization, not just watermark")
	_press(h, "自己核清，作出判断")

func _letter_and_evidence() -> void:
	var h = _host(); h.capstone_story.open("heting_dispatch"); var old: PackedByteArray = _fail(h)
	_press(h, "接下查册引介"); check(h.state.capstone_stage == 1, "Accepted introduction survives failed save"); _retry(h, old)
	_go(h, "chapter_host"); var before: Dictionary = h.state.to_dict(); _letter(h)
	check(h.state.to_dict() == before, "Reading Wen pages neither returns letter nor heals")
	old = _fail(h); _press(h, "收回原信，记下说明"); check(h.state.capstone_stage == 2, "Explicit acceptance alone returns original"); _retry(h, old)
	h.capstone_story.open("chapter_host"); check(h.body.contains("原信已经交还"), "Repeat does not retake original")
	_press(h, "重看霜桥旧事"); check(h.body.contains("不会") and h.body.contains("旧信已交还"), "Legacy letter continuity remains corrected")
	_go(h, "chapter_clerk"); before = h.state.to_dict(); _evidence(h)
	for wrong: String in ["同水纹的令都是梁缜写的", "两篓干粮证明全船无损", "先赢过他，才能认定责任"]:
		var writes: int = h.writes; _press(h, wrong)
		check(h.state.to_dict() == before and h.writes == writes, "Wrong evidence is explanatory and resource-free: " + wrong)
		_press(h, "重新判断")
	old = _fail(h); _press(h, "梁缜须对这组核准交发负责"); check(h.state.capstone_stage == 3, "Correct issued responsibility persists separately from future combat"); _retry(h, old)
	h = _host(2, "chapter_clerk"); h.capstone_story.open("chapter_clerk"); var page: String = h.capstone_story._page
	h.capstone_story._show("C6")
	check(h.capstone_story._page == page and h.state.capstone_stage == 2, "Judgement cannot skip concrete issued fields even via direct page request")
	h = _host(1, "chapter_host"); h.state.hp = 17; h.state.qi = 0; h.capstone_story.open("chapter_host")
	var rest: Callable = _choose(h, "借榻调息"); h.world.player_pos += Vector2(75,0); rest.call()
	check(h.state.hp == 17 and h.writes == 0, "Walk-away stale rest cannot heal remotely")
	_go(h, "chapter_host"); old = _fail(h); rest.call()
	check(h.state.hp == h.state.max_hp and h.state.qi == h.state.max_qi and h.state.capstone_stage == 1, "Explicit Wen rest heals without letter reveal")
	_retry(h, old)

func _helper_live_eligibility() -> void:
	for method: String in ["tang_teach", "tang_preserve", "qin_timing", "shen_shore", "shen_mobile"]:
		var domain: String = "classification" if method.begins_with("shen") else "evidence"
		var h = _host(4 if domain == "classification" else 2, "capstone_order_desk" if domain == "classification" else "chapter_clerk")
		var actor: String = "shen" if method.begins_with("shen") else ("tang" if method.begins_with("tang") else "qin")
		if actor == "shen":
			check(h.state.recruit_companion(), "Recruit synthetic Shen"); h.state.shen_care_stage = 5; h.state.shen_care_choice = "shore" if method == "shen_shore" else "mobile"
		elif actor == "tang":
			h.state.bridge_repaired = true; h.state.tangqi_stage = 3; h.state.tangqi_choice = "teach" if method == "tang_teach" else "preserve"; check(h.state.recruit_tangqi(), "Recruit synthetic Tang")
		else:
			h.state.map_id = "mistwood"; check(h.state.begin_qin_quest() and h.state.inspect_qin_rope() and h.state.arrange_qin_handoff() and h.state.recruit_qin(), "Recruit synthetic Qin"); h.state.map_id = h.world.map_id
		if domain == "evidence": _evidence(h); h.capstone_story._show("C4")
		else: h.capstone_story.open("capstone_order_desk"); _press(h, "选择同行核对方法")
		var labels: Dictionary = {"tang_teach": "请唐栖逐项复读", "tang_preserve": "请唐栖另纸标注", "qin_timing": "请秦禾并看时刻", "shen_shore": "请沈青看留岸等候", "shen_mobile": "请沈青看往返交接"}
		_press(h, labels[method]); _press(h, "作出责任判断" if domain == "evidence" else "作出四号分类")
		var accept: Callable = _choose(h, "梁缜须对这组核准交发负责" if domain == "evidence" else "001、002证伪；003、004待核")
		h.state.party_resources[actor].hp = 0; var before: Dictionary = h.state.to_dict(); accept.call()
		check(h.state.to_dict() == before and h.writes == 0 and h.body.contains("当前方法已不可用"), "Selected helper must still stand when accepting " + method)
		_press(h, "重新选择核对方法")
		check(h.options.size() <= 5, "Filtered helper page stays within five choices")
		_press(h, "自己逐项核对" if domain == "evidence" else "自己列明依据与后果")
		_press(h, "作出责任判断" if domain == "evidence" else "作出四号分类")
		_press(h, "梁缜须对这组核准交发负责" if domain == "evidence" else "001、002证伪；003、004待核")
		check(h.state.capstone_stage == (3 if domain == "evidence" else 5), "Solo remains sufficient after helper loses eligibility")

func _battle_boundary() -> void:
	var h = _host(3, "chapter_archive"); h.capstone_story.open("chapter_archive")
	check(not h.capstone_story.battle_entry_ready(), "Confrontation prose is not battle confirmation")
	_press(h, "查看应战准备"); check(h.capstone_story.battle_entry_ready(), "Explicit ready page permits live entry")
	var stale: Callable = _choose(h, "保存后阻止交发"); h.modal_generation += 1
	check(not h.capstone_story.battle_entry_ready() and not h._start_party_capstone_battle(h.modal_generation), "Unrelated newer modal cannot reuse stale D2 entry")
	stale.call(); check(h.starts == 0 and h.writes == 0, "Stale start has no presave side effect")
	h.capstone_story.open("chapter_archive"); _press(h, "查看应战准备"); var old: PackedByteArray = _fail(h)
	_press(h, "保存后阻止交发"); check(h.starts == 0 and not h.state.battle_active and h.body.contains("尚未开始"), "Party-owned failed pre-save refuses combat")
	_retry(h, old); check(h.starts == 0 and h.capstone_story.battle_entry_ready(), "Serialization retry returns ready page and never starts combat")
	_press(h, "保存后阻止交发"); var tx: Dictionary = h.state.party_battle_action("flee"); var result: Dictionary = h.state.finish_party_presentation(tx.epoch, tx.token)
	check(result.get("accepted", false) and result.get("settled", false), "Actual controller flee token accepted")
	h.current_screen = "explore"; h.capstone_story.after_battle(result.settlement)
	check(h.state.capstone_stage == 3 and h.body.contains("未发簿尚未取得"), "Real flee preserves responsibility but acquires no book")
	h = _host(3, "chapter_archive"); h.state.attack = 900; h.state.defense = 900
	h.capstone_story.open("chapter_archive"); _press(h, "查看应战准备"); _press(h, "保存后阻止交发")
	tx = Driver.terminal_next(h.state); result = h.state.finish_party_presentation(tx.epoch, tx.token)
	check(result.get("accepted", false) and result.get("settled", false) and result.outcome == "win", "Synthetic-high-stat real-controller terminal win")
	h.current_screen = "explore"; old = _fail(h); h._autosave(); h.capstone_story.after_battle(result.settlement)
	check(h.state.capstone_stage == 4 and result.settlement.reward_xp == 0 and result.settlement.coin_change == 0 and h.body.contains("保存尚未成功"), "Accepted win only obtains separate unclassified book even if its checkpoint fails")
	_retry(h, old); check(h.body.contains("没有发终章奖励"), "Win retry resumes book explanation without another settlement")
	var before: Dictionary = h.state.to_dict(); h.capstone_story.after_battle(result.settlement)
	check(h.state.to_dict() == before, "Repeated presentation never settles again")
	h = _host(3, "chapter_archive"); h.state.attack = 1; h.state.defense = 0; h.state.hp = 1; h.state.medicine = 0; h.state.coins = 3
	h.capstone_story.open("chapter_archive"); _press(h, "查看应战准备"); _press(h, "保存后阻止交发")
	tx = Driver.terminal_next(h.state); result = h.state.finish_party_presentation(tx.epoch, tx.token)
	check(result.get("accepted", false) and result.get("settled", false) and result.outcome == "defeat", "Actual low-resource controller defeat")
	h.current_screen = "explore"; h.world.map_id = h.state.map_id; h.world.player_pos = h.state.position
	old = _fail(h); h._autosave(); h.capstone_story.after_battle(result.settlement)
	check(h.capstone_story._site == "chapter_host" and h.state.capstone_stage == 3 and h.state.coins == 0, "Defeat explanation anchored at actual recovery, only real available coins lost")
	_retry(h, old); check(h.body.contains("本次遗落3文") and h.body.contains("用掉的药不返还"), "Defeat retry reports actual loss and does not replay recovery")

func _classify_and_plan() -> void:
	for site: String in ["chapter_archive", "capstone_order_desk"]:
		var h = _host(4, site); h.capstone_story.open(site)
		if site == "chapter_archive": _press(h, "逐号核定分类")
		_press(h, "自行核定四号分类"); var before: Dictionary = h.state.to_dict()
		for wrong: String in ["同册四号都算假令", "前两号假，后两号已无误"]:
			_press(h, wrong); check(h.state.to_dict() == before and h.writes == 0, "Wrong complete partition is read-only")
			_press(h, "重新分类")
		var old: PackedByteArray = _fail(h); _press(h, "001、002证伪；003、004待核")
		check(h.state.capstone_stage == 5 and h.state.capstone_draft.is_empty(), "Classification independently accepts stage5 empty draft")
		_retry(h, old); check(h.capstone_story._page == "F0", "Concise classification route goes directly to reversible plans")
		_press(h, "暂不拟定"); h.capstone_story.open(site)
		check(not h.capstone_story.battle_entry_ready() and h.state.capstone_stage == 5, "Reopening classified-empty stage never reopens fight")
		_press(h, "商议处置草案"); old = _fail(h); _press(h, "拟作整班暂缓 · 撤2留2")
		check(h.state.capstone_draft == "pause_batch" and h.state.capstone_ending.is_empty(), "Draft acceptance changes no disposition")
		_retry(h, old)
		check(Rules.order_rows(h.state).all(func(row): return row.disposition == "pending"), "All four pending under saved draft")
		_press(h, "撤下草案"); check(h.state.capstone_stage == 5 and h.state.capstone_draft.is_empty(), "Clear draft retains classification")
		_press(h, "重新商议草案"); _press(h, "拟作整班暂缓 · 撤2留2")
		if site == "chapter_archive":
			check(not h.options.any(func(entry): return entry[0] == "查看最后确认"), "Archive cannot expose final disposition")
			var before_archive: Dictionary = h.state.to_dict(); h.capstone_story._show("G1")
			check(h.state.to_dict() == before_archive and h.capstone_story._page == "F1", "Direct archive confirmation page is blocked")
			_go(h, "capstone_order_desk"); h.capstone_story.open("capstone_order_desk"); _press(h, "查看当前草案")
		_press(h, "查看最后确认"); var stale: Callable = _choose(h, "确认执行 · 撤2留2")
		check(h.options[0][0] == "返回核对", "First confirmation choice is safe return")
		_press(h, "更改草案"); _press(h, "拟作逐号撤销 · 撤2循例2"); _press(h, "更改草案"); _press(h, "拟作整班暂缓 · 撤2留2")
		var writes: int = h.writes; stale.call()
		check(h.state.capstone_stage == 5 and h.writes == writes, "A-to-B-to-A plan does not revive prior confirmation")

func _completion_and_rewards() -> void:
	for plan: String in Rules.PLANS:
		var h = _host(5, "capstone_order_desk"); h.capstone_story.open("capstone_order_desk"); _press(h, "商议处置草案")
		_press(h, "拟作整班暂缓 · 撤2留2" if plan == "pause_batch" else "拟作逐号撤销 · 撤2循例2")
		_press(h, "查看最后确认"); var old: PackedByteArray = _fail(h)
		var coins: int = h.state.coins; var total_xp: int = h.state.xp + 30 * h.state.level * (h.state.level - 1)
		_press(h, "确认执行 · 撤2留2" if plan == "pause_batch" else "确认执行 · 撤2循例2")
		check(h.state.capstone_stage == 6 and h.state.capstone_ending == plan and h.state.coins == coins, "Disposition accepted once without reward")
		_retry(h, old)
		var rows: Array[Dictionary] = Rules.order_rows(h.state)
		check(rows.size() == 4 and rows[0].disposition == "cancelled" and rows[1].disposition == "cancelled" and rows[2].disposition == ("held" if plan == "pause_batch" else "continuing"), "Finite exact two-plus-two final dispositions")
		_go(h, "elder"); h.capstone_story.open("elder"); check(h.options[0][0] == "先看回条", "Homecoming first choice is read-only")
		_press(h, "先看回条"); _press(h, "回到灯下"); old = _fail(h)
		var finish: Callable = _choose(h, "交回回条，确认归灯"); finish.call()
		check(h.state.capstone_stage == 7 and h.state.coins == coins + 80 and h.state.xp + 30 * h.state.level * (h.state.level - 1) == total_xp + 160, "Both plans reward exactly160XP/80coins only at elder")
		var accepted: Dictionary = h.state.to_dict(); finish.call(); check(h.state.to_dict() == accepted, "Duplicate homecoming input cannot duplicate reward")
		_retry(h, old); check(h.body.contains("修为160、铜钱80") and h.body.contains("升至"), "Actual completion describes once reward and ordinary level-up recovery")
		_press(h, "继续行走"); h.capstone_story.open("elder"); check(h.body.contains("重看不再发奖") and h.state.to_dict() == accepted, "Repeat completion read-only")
		_go(h, "chapter_host"); h.capstone_story.open("chapter_host"); check(h.options.any(func(entry): return entry[0] == "借榻调息"), "Wen explicit free rest still available after completion")
		check(not h.capstone_story.handle("bridge_worker") and not h.capstone_story.handle("heting_scale"), "Optional bridge/receipt content remains outside capstone routing")
	var stale_direct = _host(6, "elder"); stale_direct.capstone_story.open("elder"); stale_direct._close_modal()
	var direct_before: Dictionary = stale_direct.state.to_dict(); stale_direct.capstone_story._homecoming()
	check(stale_direct.state.to_dict() == direct_before and stale_direct.writes == 0, "Direct stale homecoming method cannot bypass dismissed modal")
	var capped = _host(6, "elder"); capped.state.coins = 999980; capped.capstone_story.open("elder"); _press(capped, "交回回条，确认归灯")
	check(capped.state.coins == 999999 and capped.body.contains("铜钱实得19"), "Capped real coin delta is shown accurately")
	var xp_capped = _host(6, "elder"); xp_capped.state.level = 99; xp_capped.state.xp = xp_capped.state.xp_to_next() - 1
	xp_capped.capstone_story.open("elder"); _press(xp_capped, "交回回条，确认归灯")
	check(xp_capped.state.capstone_stage == 7 and xp_capped.state.xp == xp_capped.state.xp_to_next() - 1 and xp_capped.body.contains("修为按既有规则计入") and not xp_capped.body.contains("修为160、铜钱80"), "Level99 receipt never overstates actual XP gain")

func _authored_pages() -> void:
	for stage: int in range(8):
		for site: String in Story.SITES:
			var h = _host(stage, site)
			if stage == 5: h.state.capstone_draft = "pause_batch"
			h.capstone_story.open(site); h.capstone_story._site = site; h.capstone_story._read_chain = 3
			for id: String in Story.PAGES:
				if not h.capstone_story._allowed_page(id): continue
				h.capstone_story._show(id)
				if h.capstone_story._page != id: continue
				check(h.options.size() > 0 and h.options.size() <= 5, "Bounded rendered choice count " + id)
				check(not h.body.contains("{") and not h.body.contains("}"), "All runtime variants rendered " + id)
				check(not h.modal_autosave_on_close, "Read-only page never autosaves on close " + id)
