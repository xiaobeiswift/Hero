class_name HetingConsigneeStory
extends RefCounted
## Scene boundary for the finite new lot. State owns every mutation/settlement;
## dialogue callbacks recheck their live site and generation before calling it.
const Rules = preload("res://scripts/heting_consignee_rules.gd")
const SITES: Array[String] = ["consignee_warehouse", "heting_dispatch", "heting_lighter", "heting_scale", "heting_cargo"]
const OBSERVATION_SITES: Dictionary = {"lot_seals": "consignee_warehouse", "removal_order": "heting_dispatch", "southern_counterfoil": "heting_lighter"}
const OBSERVATION_NAMES: Dictionary = {"lot_seals": "北仓封粮", "removal_order": "调度牌撤运单", "southern_counterfoil": "南驳船收货联"}
const PLAN_NAMES: Dictionary = {"hold_for_inspection": "封粮留验", "return_to_owner": "撤运还粮"}
const METHOD_LABELS: Dictionary = {"solo": "亲自核验", "tang_teach": "请唐栖按卸力法核封", "tang_preserve": "请唐栖比对旧机刻线", "qin_timing": "请秦禾并看验放时刻", "shen_shore": "请沈青核问岸边暂存", "shen_mobile": "请沈青核问返船次序"}
var host

func _init(owner) -> void:
	host = owner

func _ready() -> bool:
	return not host.quit_pending and host.current_screen == "explore" and not host.state.battle_active \
		and host.state._party_pending_token < 0 and not host.state._party_gate() \
		and host.state.map_id == "heting" and host.world.map_id == "heting" \
		and host.state.hp > 0 and host.state.heting_stage == 4 \
		and host.state._stage_save_data(host.state.to_dict(), host.state.SAVE_VERSION).ok

func _at(site: String) -> bool:
	return _ready() and host.world.interactables.has(site) and host.world.player_pos.is_finite() \
		and host.world.player_pos.distance_to(host.world.interactables[site].pos) < 75.0

func _guard(action: Callable, site: String = "") -> Callable:
	return _apply.bind(action, host.modal_generation + 1, site)

func _apply(action: Callable, generation: int, site: String) -> void:
	if not host.active_modal or host.modal_generation != generation or not _ready(): return
	if not site.is_empty() and not _at(site): return
	action.call()

func _modal(title: String, subtitle: String, body: String, options: Array) -> void:
	host._modal(title, subtitle, body, options, true)
	host.modal_autosave_on_close = false

func _close() -> void:
	host.modal_autosave_on_close = false
	host._close_modal()

func link_label(site: String) -> String:
	if host.state.consignee_stage == 0: return "问北仓新撤运单"
	if host.state.consignee_stage == 5: return "重看未损先收记录"
	if host.state.consignee_stage == 4 and site in ["heting_scale", "heting_cargo"]: return "交接本批封粮"
	if host.state.consignee_stage == 1:
		return "核验南联" if site == "heting_lighter" else "核验新撤运单"
	return "商议本批封粮"

func open(site: String = "heting_dispatch") -> void:
	if not SITES.has(site) or not _at(site): return
	match host.state.consignee_stage:
		0: _offer(site)
		1:
			for observation: String in OBSERVATION_SITES:
				if OBSERVATION_SITES[observation] == site:
					_observation(observation, site); return
			_record(site)
		2:
			if site == Rules.SOURCE and not host.state.consignee_draft.is_empty(): _battle_ready()
			else: _draft(site)
		3:
			if site == Rules.SOURCE: _warehouse()
			else: _draft(site)
		4:
			if site in ["heting_scale", "heting_cargo"]: _receiver(site)
			else: _loaded(site)
		5: _record(site)

func _offer(site: String) -> void:
	var night: String = "昨夜短渡照原议分粮，次晨才来接续核查。" if host.state.heting_ending == "short_ferries" else "昨夜公秤照原议守秤，轮值船工今晨换了班。"
	_modal("杜晦 · 平川粮栈收货管事" if site == Rules.SOURCE else ("孟绫 · 北仓新单" if site == "heting_dispatch" else "北仓新撤运单"), "鹤汀续事 / 未损先收", night + "\n\n北仓另有新编号的两篓封粮，调度牌却收到一张按水损撤运的单子。船工转述：平川粮栈的杜晦穿着整洁青衣、赭色背心，账袋紧贴腰侧，短棍横在北仓门边。他只催照单提货。\n\n“预结的钱已入账，这批就该归栈里。撤运令既到了，先搬；验粮的事，让后面的班次补。”\n\n新单旁附着孟绫的话：“预结是谁的凭据，要查；这两篓究竟如何，也得亲眼看。”\n\n可亲查北仓封粮、调度牌撤运单、南驳船收货联，先后不限。旧复签只是可选旁证，无须补做，也不改变昨夜的分粮。", [["接下本批核查", _guard(_begin.bind(site), site)], ["先不接下", _guard(_close)]])

func _begin(site: String) -> void:
	if not SITES.has(site) or not _at(site) or not host.state.begin_consignee(): return
	_persist(site, open.bind(site))

func _observation(observation: String, site: String) -> void:
	if not _at(site) or host.state.consignee_stage != 1 or OBSERVATION_SITES.get(observation) != site: return
	if host.state.consignee_observations.has(observation): _record(site); return
	var bodies: Dictionary = {
		"lot_seals": "北仓门内，两篓新封粮并在同一张货签下。篓绳压着刚盖的印，旁边留有供验粮复放的空位。\n\n核查的是眼前这一批：比货号、查封绳，再在船工见证下看篓内粮。不会拿两篓替整船作保。",
		"removal_order": "孟绫把新撤运单摊在调度牌上：货号与北仓两篓一致，理由栏已经写了水损。仓门验放刻线和签发时刻都还在。\n\n应当核对先写撤运理由，还是先准人看粮。沿用货号与时刻，不抄船工姓名。",
		"southern_counterfoil": "南泊短驳留着本批的收货联，去处是平川粮栈，收货管事署作杜晦。船工指着预结授权一栏，又指了指待返的粮船。\n\n核清这张授权对应哪一批、谁来接粮、船上如何暂存；不能只因有一笔钱便断定整条粮路。"}
	var choices: Array = []
	for method: String in Rules.available_methods(host.state, observation):
		choices.append([METHOD_LABELS[method], _guard(_observe.bind(observation, method, site), site)])
	choices.append(["先不核验", _guard(_close)])
	_modal(OBSERVATION_NAMES[observation], "未损先收 / 现场核验", bodies[observation] + "\n\n独自核验足够；可请实际在队、仍站立且有相关经历的同行人换一种方法。", choices)

func _observe(observation: String, method: String, site: String) -> void:
	if not _at(site) or OBSERVATION_SITES.get(observation) != site: return
	if not host.state.observe_consignee(observation, method):
		_observation(observation, site); return
	_persist(site, _record.bind(site))

func _record(site: String) -> void:
	if not _at(site): return
	var options: Array = []
	if host.state.consignee_stage == 1 and host.state.consignee_observations.size() == 3:
		options.append(["核对三处矛盾", _guard(_deduction.bind(site), site)])
	elif host.state.consignee_stage in [2, 3, 4]:
		options.append(["查看当前草案", _guard(open.bind(site), site)])
	options.append(["收好本批记录", _guard(_close)])
	_modal("未损先收 · 本批记录", "收货去向 / 已查%d处" % host.state.consignee_observations.size(), Rules.journal(host.state) + "\n\n" + Rules.hint(host.state), options)

func _deduction(site: String) -> void:
	if not _at(site) or host.state.consignee_stage != 1 or host.state.consignee_observations.size() != 3: return
	_modal("一批粮的先后", "未损先收 / 哪一处站不住脚", "北仓：本批两篓封记相合，篓内粮干燥。\n调度牌：水损撤运令先签，后才准开仓验粮。\n南联：平川粮栈按预结授权接这一批，杜晦负责收货。\n\n这些记录能支持哪一步判断？答错只解释，不会丢掉已查证据，也不扣资源。", [["未验先撤，理由倒置", _guard(_resolve.bind(Rules.CORRECT_ANSWER, site), site)], ["两篓干粮证明整船无损", _guard(_resolve.bind("dry_means_whole_ship", site), site)], ["必须先补取旧复签", _guard(_resolve.bind("receipt_required", site), site)], ["只凭收货姓氏便可结案", _guard(_resolve.bind("surname", site), site)], ["先留着记录", _guard(_close)]])

func _resolve(answer: String, site: String) -> void:
	if not _at(site): return
	var result: Dictionary = host.state.resolve_consignee_contradiction(answer)
	if result.get("correct", false): _persist(site, _plan_menu.bind(site)); return
	if host.state.consignee_stage != 1: return
	_modal("再核一步", "未损先收 / 证据边界", result.reason, [["重新核对", _guard(_deduction.bind(site), site)], ["先留着记录", _guard(_close)]])

func _plan_menu(site: String) -> void:
	if not _at(site) or host.state.consignee_stage not in [2, 3, 4]: return
	_modal("这一批怎样安置", "未损先收 / 可更改的草案", "杜晦把预结当成既得收货权，又照先到的撤运令办事；但这批粮没有先验，不能由那张水损理由直接带走。\n\n" + Rules.plan_description("hold_for_inspection") + "\n\n" + Rules.plan_description("return_to_owner") + "\n\n两案都须先到北仓阻止强提，再亲自押同一车到接粮处。交锋只保住粮，最后当面确认交接才得120修为、60文；两案相同。昨夜的安排不改。", [["拟作封粮留验", _guard(_choose.bind("hold_for_inspection", site), site)], ["拟作撤运还粮", _guard(_choose.bind("return_to_owner", site), site)], ["再想一想", _guard(_close)]])

func _choose(plan: String, site: String) -> void:
	if not _at(site): return
	if host.state.choose_consignee_plan(plan): _persist(site, open.bind(site))
	elif host.state.consignee_draft == plan and host.state.consignee_stage in [2, 3, 4]: open(site)

func _draft(site: String) -> void:
	if host.state.consignee_draft.is_empty(): _plan_menu(site); return
	_modal("未损先收 · 当前草案", "本批处置 / " + PLAN_NAMES[host.state.consignee_draft], Rules.plan_description(host.state.consignee_draft) + "\n\n" + Rules.hint(host.state) + "\n\n复签仍可到东岸公秤另办；它不替代本批核查。", [["去北仓阻止提粮" if host.state.consignee_stage == 2 else "去北仓取车", _guard(_close)], ["更改本批草案", _guard(_plan_menu.bind(site), site)], ["重看本批记录", _guard(_record.bind(site), site)], ["先离开", _guard(_close)]])

func battle_entry_ready() -> bool:
	return host.active_modal and _at(Rules.SOURCE) and Rules.can_confront(host.state)

func _battle_ready() -> void:
	if not _at(Rules.SOURCE) or not Rules.can_confront(host.state): return
	var s = host.state
	_modal("杜晦 · 平川粮栈收货管事", "未损先收 / 北仓交锋", "当前气血%d/%d，真气%d/%d，回春散%d份。\n\n" % [s.hp, s.max_hp, s.qi, s.max_qi, s.medicine] + "杜晦把账袋往身后一拨，拦在板车前：“你说留验就留验，预结亏在谁账上？我只认撤运单。”收运护手持刃并上，两人要把封粮强提走。\n\n杜晦260气血，护手160气血。两人各有自己的护势、重招与收势空隙，按头顶预告应对；Tab换目标。实际在队者自动普攻，可另排武学、内功、轻功。\n\n这是实战，出招用药照实消耗。退避不另扣钱，已用资源不返；败退最多遗落8文，回西岸粥棚恢复气血，真气至少留2点。西岸可免费调息。\n\n先存妥才开战。胜利只保住本批，不发修为铜钱，也不替你确认去向。", [["保存后阻止强提", _guard(_start, Rules.SOURCE)], ["更改本批草案", _guard(_plan_menu.bind(Rules.SOURCE), Rules.SOURCE)], ["先去免费调息", _guard(_close)], ["暂且离开", _guard(_close)]])

func _start() -> void:
	if not battle_entry_ready(): return
	# PartyUI owns the one current-resource pre-entry checkpoint and refuses a
	# failed write. Keep this page live until that guarded transition succeeds.
	if not host._start_party_consignee_battle(host.modal_generation) and host.save_warning:
		_save_failed(Rules.SOURCE, _battle_ready, true)

func _warehouse() -> void:
	if not _at(Rules.SOURCE) or host.state.consignee_stage != 3: return
	_modal("北仓提货位", "未损先收 / 同一批，两篓一车", "杜晦与护手退开，旧撤运单已被当场划止。两篓仍在原位，尚未交付，也没有第二批。\n\n" + Rules.plan_description(host.state.consignee_draft) + "\n\n取车后须亲自押送。载车不能走北步栈，可走北街与侧浮栈，岛上绞缆机仍可免费改泊。", [["押本批两篓封粮", _guard(_take, Rules.SOURCE)], ["更改本批草案", _guard(_plan_menu.bind(Rules.SOURCE), Rules.SOURCE)], ["先不提货", _guard(_close)]])

func _take() -> void:
	if not _at(Rules.SOURCE) or not host.state.take_consignee_cargo(Rules.BATCH, Rules.SOURCE): return
	_persist(Rules.SOURCE, _loaded.bind(Rules.SOURCE))

func _loaded(site: String) -> void:
	if not _at(site) or host.state.consignee_stage != 4: return
	var options: Array = [["继续押送", _guard(_close)], ["更改本批草案", _guard(_plan_menu.bind(site), site)]]
	if site == Rules.SOURCE: options.append(["把本批停回北仓", _guard(_park, Rules.SOURCE)])
	_modal("本批封粮 · 押车货签", "未损先收 / 交接前仍可改议", Rules.plan_description(host.state.consignee_draft) + "\n\n一车两篓，不与昨夜三批混记。窄步栈过不了车；北街和当前侧浮栈可通行。离港前须明确确认把车停回北仓，回来可再提。", options)

func _park() -> void:
	if not _at(Rules.SOURCE) or not host.state.park_consignee_cargo(): return
	_persist(Rules.SOURCE, _warehouse)

func _receiver(site: String) -> void:
	if not _at(site) or host.state.consignee_stage != 4: return
	var receiver: String = Rules.SCALE if site == "heting_scale" else Rules.GRAIN_BOAT
	var plan: String = host.state.consignee_draft
	if Rules.receiver_for(plan) != receiver:
		var other: String = "hold_for_inspection" if site == "heting_scale" else "return_to_owner"
		_modal("本批封粮 · 先核去处", "未损先收 / 这里不是当前接粮处", Rules.plan_description(plan) + "\n\n可以继续照原案押送，也可在这里更改草案。更改后仍会单独询问是否正式交下，不会悄悄定案。", [["照原案继续送", _guard(_close)], ["改作" + PLAN_NAMES[other], _guard(_choose.bind(other, site), site)], ["先不交货", _guard(_close)]])
		return
	_modal("施衡与轮值船工" if site == "heting_scale" else "中埠粮船 · 原主接粮", "未损先收 / 最后交接确认", Rules.plan_description(plan) + "\n\n" + ("施衡与船工共同留封样，原主保留暂存回条。待验期间，这批粮不能分用。" if plan == "hold_for_inspection" else "原主收回这一批，返还记录与抄件分别保留；开篓分用后不再保有整批封样。") + "\n\n确认后本批去向不再更改，得120修为、60文，只结算一次。昨夜分粮、旧复签与已经核过的事实均保留。", [["确认交下本批", _guard(_finish.bind(site, receiver, plan), site)], ["先留在车上", _guard(_close)], ["更改本批草案", _guard(_plan_menu.bind(site), site)]])

func _finish(site: String, receiver: String, expected_plan: String) -> void:
	if site not in ["heting_scale", "heting_cargo"] or not _at(site) or receiver != (Rules.SCALE if site == "heting_scale" else Rules.GRAIN_BOAT): return
	if not host.state.finish_consignee_delivery(receiver, expected_plan): return
	_persist(site, _completion.bind(site))

func _completion(site: String) -> void:
	if not _at(site) or host.state.consignee_stage != 5: return
	_modal("未损先收 · 交接已记", "本批完成 / " + PLAN_NAMES[host.state.consignee_ending], Rules.aftermath(host.state, "receiving_point") + "\n\n本次交接已结算120修为、60文。重看记录或重试保存不再发奖。\n\n平川粮栈是本批当地的收货受益方，杜晦按预结授权提粮；上游授权从何而来仍待追查。不能据此断言全案告破。昨夜安排照旧，旧复签仍可另核。", [["收好交接记录", _guard(_close)], ["重看本批记录", _guard(_record.bind(site), site)]])

func leave() -> bool:
	if host.state.consignee_cargo_location != "cart": return false
	if not _at("return_mistwood"): return true
	_modal("北岸归路", "未损先收 / 先留好这一车", "本批两篓还在车上，不能带离鹤汀。要离港，先明确把同一车停回北仓；已查事实、阻止强提的结果与草案都保留。回来只取原来这一批。", [["停回北仓后离开", _guard(_park_and_leave, "return_mistwood")], ["留在埠内", _guard(_close)]])
	return true

func _park_and_leave() -> void:
	if not _at("return_mistwood") or not host.state.park_consignee_cargo(): return
	_persist("return_mistwood", _leave_saved)

func _leave_saved() -> void:
	if not _at("return_mistwood") or host.state.consignee_stage != 3: return
	host.modal_autosave_on_close = false
	host._travel("mistwood", Vector2(1440, 505))

func _persist(site: String, resume: Callable) -> void:
	host._sync_world_state()
	host.world.teleport(host.world.player_pos)
	host.state.position = host.world.player_pos
	host._autosave()
	host._refresh()
	if host.save_warning: _save_failed(site, resume)
	else: resume.call()

func _save_failed(site: String, resume: Callable, before_battle: bool = false) -> void:
	_modal("未损先收 · 尚未存妥", "保存未成功 / 可安全重试", ("交锋尚未开始，尚未产生战斗消耗。" if before_battle else "本次已接受的进度、已结算的资源或交接奖励仍留在当前旅程。") + "\n\n本次保存未成功。重试只补存当前结果，不重复核验、交接或发奖，也不会自动开战。离开对话不丢弃内存中的进度；退出游戏前请先存妥。", [["重试保存", _guard(_retry_save.bind(site, resume), site)], ["先回埠内", _guard(_close)]])

func _retry_save(site: String, resume: Callable) -> void:
	if not _at(site): return
	host._autosave()
	if host.save_warning: _save_failed(site, resume)
	else: resume.call()

func after_battle(summary: Dictionary) -> void:
	if not _ready() or summary.get("encounter_id") != "heting_consignee" \
		or int(summary.get("consignee_stage", -1)) != host.state.consignee_stage: return
	var outcome: String = String(summary.get("outcome", ""))
	var body: String = ""
	var site: String = Rules.SOURCE
	var options: Array = []
	if outcome == "win" and host.state.consignee_stage == 3:
		body = "杜晦收起短棍，仍攥着那份预结账，却不能再按旧撤运单强提。两篓封粮留在北仓。\n\n这场交锋只保住本批，没有发修为或铜钱，去向仍是可更改的草案。还须到提货位押车，亲自送到接粮处确认。"
		if _at(site): options.append(["查看北仓这一车", _guard(_warehouse, site)])
	elif outcome in ["flee", "defeat"] and host.state.consignee_stage == 2:
		if outcome == "defeat":
			site = "heting_relief"
			body = "全队退回西岸粥棚，本次遗落%d文。气血恢复，真气至少留2点，用药不返还。" % maxi(0, -int(summary.get("coin_change", 0)))
		else: body = "你从北仓退开，已出招、用药照实保留，退避不另扣钱。"
		body += "\n\n没有发放胜利奖励，也未推进本批阶段或锁定去向。调查与草案仍在；西岸粥棚可免费调息，备妥再来。"
	else: return
	options.append(["先回埠内", _guard(_close)])
	if host.save_warning:
		body += "\n\n本次结果尚未存妥。资源与进度保留在当前旅程，请重试保存后再退出。"
		if _at(site): options.push_front(["重试保存", _guard(_retry_save.bind(site, _close), site)])
	_modal("未损先收 · " + {"win": "封粮仍在", "flee": "暂退留步", "defeat": "西岸缓息"}[outcome], "北仓交锋 / 已按实际结果结算", body, options)

func target_id() -> String:
	match host.state.consignee_stage:
		1:
			for observation: String in Rules.OBSERVATIONS:
				if not host.state.consignee_observations.has(observation): return OBSERVATION_SITES[observation]
			return "heting_dispatch"
		2: return "heting_dispatch" if host.state.consignee_draft.is_empty() else Rules.SOURCE
		3: return Rules.SOURCE
		4: return "heting_scale" if host.state.consignee_draft == "hold_for_inspection" else "heting_cargo"
	return "heting_dispatch"
