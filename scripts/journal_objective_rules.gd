class_name JournalObjectiveRules
extends RefCounted
## Read-only finite earned catalog. These adapters never call story transitions,
## save/restore, normalization, party-resource reconciliation or position writes.
const Lightness = preload("res://scripts/lightness_rules.gd")
const Qin = preload("res://scripts/qin_companion_rules.gd")
const Receipt = preload("res://scripts/heting_receipt_rules.gd")
const Consignee = preload("res://scripts/heting_consignee_rules.gd")
const Heting = preload("res://scripts/heting_rules.gd")
const Capstone = preload("res://scripts/volume_one_capstone_rules.gd")
const IDS: Array[String] = ["opening", "sluice", "frostbridge", "south_bridge", "tang_notes", "shen_care", "mistwood", "qin_rope", "lightness_islet", "heting_delivery", "heting_receipt", "heting_consignee", "capstone", "mentor_reward"]
const MAP_NAMES: Dictionary = {"qingwei":"青苇渡", "sluice":"废闸", "frostbridge":"霜桥驿", "mistwood":"雾竹坡", "heting":"鹤汀埠"}
const CHAPTER_TITLES: Array[String] = ["霜桥来信", "三印问路", "封仓问剑", "原账与姓名", "霜桥余响"]
const CHAPTER_HINTS: Array[String] = ["沿废闸东北古道，前往霜桥驿。", "调查北桥碑文和东北文书房，按口诀解开东南印台。", "机关已开，去东南印台向韩砚索取原账。", "回西岸驿馆，与温行舟决定证据的公开方式。", "原账已有归处。可修南桥、返回研艺，或沿东北竹坡道追查雨令。"]
const MIST_TITLES: Array[String] = ["山雨来信", "三尺问雨", "听雨关前", "令与水势", "竹坡余声"]
const MIST_HINTS: Array[String] = ["由霜桥东北竹坡道前往雾竹坡。", "查三处雨痕；中东巡哨有较量、修亭、公示原账三种通行方案。", "三处读数齐备，去东侧听雨关索取原令底稿。", "回西北秦禾处，商议先行照应何处。", "底稿指向鹤汀埠。沿听雨关东侧下埠道，继续查粮船交割。"]
const HARBOR_TITLES: Array[String] = ["鹤汀来路", "一车两岸", "夜工待议", "最后一车", "埠灯未尽"]
const CARGO_NAMES: Dictionary = {"meal":"开锅粮", "sealed":"对秤封粮", "reserve":"待分粮"}
const PLAN_NAMES: Dictionary = {"short_ferries":"短渡分粮", "open_scale":"守秤留粮"}

static func catalog(s) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if s == null: return rows
	for id: String in IDS:
		var item: Dictionary = row(s, id)
		if not item.is_empty(): rows.append(item)
	return rows

static func row(s, id: String) -> Dictionary:
	if s == null or not IDS.has(id): return {}
	var stage: int = 0
	var title: String = ""
	var action: String = ""
	var map: String = ""
	var site: String = ""
	var status: String = "active"
	var history: Array[String] = []
	match id:
		"opening":
			stage = s.quest_stage
			if not _stage(stage, 6): return {}
			title = s.quest_title(); action = s.quest_hint(); map = "qingwei"
			site = ["elder", "herb", "healer", "bandit", "elder", "elder", ""][stage]
			status = "completed" if stage == 6 else "active"
			var steps: Array[String] = ["与村中央的陆伯交谈", "到东北苇岸采集青穗草", "回村西药铺，将草药交给沈青", "前往东南旧渡口，夺回引航灯", "向陆伯交还灯芯与账页", "决定证据归处，选择修行方向"]
			for i: int in range(stage): history.append("✓ " + steps[i])
			if not s.ending.is_empty(): history.append("证据归处：" + s.ending)
			if stage == 6: history.append("修行方向：" + s.sect)
		"sluice":
			stage = s.side_stage
			if s.quest_stage < 6 or not _stage(stage, 3): return {}
			title = "废闸疑云" if stage < 3 else "水令留痕"
			action = _side_hint(s); map = "sluice"
			site = ("ledger_runner" if s.side_found.has("boatman") else "stranded_boatman") if stage < 2 else "sluice_boss"
			status = _status(stage, 3)
			if s.side_found.has("boatman"): history.append("✓ 船工的证言（南岸）")
			if s.side_found.has("ledger"): history.append("✓ 传令人的账页（东北）")
			if stage >= 3: history.append("✓ 闸首罗沉与伪造水令（东南）")
			if s.side_choice in ["rescue", "pursuit"]: history.append("先行之路：" + ("先救船工" if s.side_choice == "rescue" else "先追账页"))
		"frostbridge":
			stage = s.chapter_two_stage
			if not (s.side_stage >= 3 or stage > 0) or not _stage(stage, 4): return {}
			title = CHAPTER_TITLES[stage]; action = CHAPTER_HINTS[stage]; map = "frostbridge"; site = _chapter_site(s); status = _status(stage, 4)
			if stage == 0: action = "沿废闸东北古道，前往霜桥驿问路。"
			if s.archive_clues.has("clerk"): history.append("✓ 纪小砚的文书线索")
			if s.archive_clues.has("inscription"): history.append("✓ 旧桥碑文\n口诀：水印先行，驿印居中，仓印收尾。")
			if stage >= 2: history.append("✓ 三印机关")
			if stage >= 3: history.append("✓ 封仓原账")
			if stage >= 4: history.append("✓ 原账归处：" + ("公示原账" if s.chapter_two_ending == "open_records" else "隐去姓名"))
		"south_bridge":
			if s.chapter_two_stage <= 0: return {}
			stage = int(s.bridge_repaired); title = "一桥两岸"; map = "frostbridge"; site = "bridge_worker"
			status = "completed" if s.bridge_repaired else "available"
			action = "南桥已修通。" if s.bridge_repaired else "到南桥交木料×2修桥（现有%d）。北桥仍可通行。" % int(s.resources.get("timber", 0))
			if s.bridge_repaired: history.append("✓ 南桥已修通")
		"tang_notes":
			stage = s.tangqi_stage
			if not (stage > 0 or (s.chapter_two_stage >= 4 and s.bridge_repaired)) or not _stage(stage, 3): return {}
			title = "唐栖的旧事" if stage == 0 else "尺上旧痕"
			action = "到霜桥南桥，找唐栖聊聊旧事。" if stage == 0 else _tang_hint(s)
			map = "sluice" if stage == 1 else "frostbridge"; site = "sluice_cache" if stage == 1 else "bridge_worker"
			status = "completed" if s.tangqi_unlocked else ("available" if stage == 0 else "active")
			if stage >= 2: history.append("✓ 寻回旧工册")
			if stage >= 3: history.append("✓ 决定手艺的去向\n" + ("工册已传给学徒。" if s.tangqi_choice == "teach" else "原稿与水令一同留存。"))
			if s.tangqi_unlocked: history.append("✓ 邀请唐栖同行")
		"shen_care":
			stage = s.shen_care_stage
			if not (stage > 0 or _shen_earned(s)) or not _stage(stage, 5): return {}
			title = "药箱之外"; action = _shen_hint(s); status = _status(stage, 5)
			map = "sluice" if stage in [1, 2] else "qingwei"; site = ["healer", "stranded_boatman", "sluice_cache", "healer", "board", ""][stage]
			if stage == 0: action = "回青苇药铺，向沈青询问船工近况。"
			var steps: Array[String] = ["向沈青询问船工近况", "听许照川说清自己的难处", "查看旧仓药棚", "与沈青议定照护办法", "把照护约贴在村中告示牌"]
			for i: int in range(stage): history.append("✓ " + steps[i])
			if stage >= 4: history.append(("已定：" if stage == 5 else "草案：") + ("留岸照护" if s.shen_care_choice == "shore" else "随船问诊"))
			if stage == 5: history.append("沈青自身防御提高1。" if s.shen_care_choice == "shore" else "沈青青灯渡脉的治疗提高2点（不超过目标气血上限）。")
		"mistwood":
			stage = s.mist_stage
			if not (s.chapter_two_stage >= 4 or stage > 0) or not _stage(stage, 4): return {}
			title = MIST_TITLES[stage]; action = MIST_HINTS[stage]; map = "mistwood"; site = _mist_site(s); status = _status(stage, 4)
			if stage == 0: action = "由霜桥东北竹坡道前往雾竹坡问路。"
			if stage == 1:
				action = {"mist_rain_gauge":"查北侧雨痕竹尺。", "mist_basin":"查分水石盂。", "mist_stone_gauge":"已有通行办法，去查叠石刻度。", "mist_scout":"到中东巡哨商议通行；可较量查哨。"}[site]
				if site == "mist_scout":
					if int(s.resources.get("timber", 0)) >= 1 and int(s.resources.get("cloth", 0)) >= 1: action += "也可交木料×1、布料×1修亭。"
					else: action += "修亭需木料×1、布料×1，现有材料不足。"
					if s.chapter_two_ending == "open_records": action += "也可援引已公示原账。"
			for gauge: String in ["rain", "stone", "basin"]:
				if s.mist_gauges.has(gauge): history.append("✓ " + {"rain":"雨痕竹尺", "stone":"叠石刻度", "basin":"分水石盂"}[gauge])
			if not s.mist_approach.is_empty(): history.append("通行：" + {"duel":"较量查哨", "repair":"修复警亭", "records":"援引公示原账"}.get(s.mist_approach, "已取得许可"))
			if stage >= 3: history.append("✓ 原令底稿")
			if stage >= 4: history.append("✓ 水势抉择：" + ("先通缓水渠" if s.mist_ending == "release_water" else "先鸣渡船钟"))
		"qin_rope":
			stage = s.qin_stage
			if not (stage > 0 or _mist_finished(s)) or not _stage(stage, 4): return {}
			title = "秦禾的近况" if stage == 0 else Qin.TITLE
			action = "去秦禾处问问。" if stage == 0 else Qin.hint(s)
			map = "mistwood"; site = ["mist_guide", "mist_rain_gauge", "mist_camp", "mist_guide", ""][stage]
			status = "completed" if s.qin_unlocked or stage == 4 else _status(stage, 4)
			var steps: Array[String] = ["答应复核尺绳", "查验竹尺与警水刻线", "交接营地轮值", "邀请秦禾同行"]
			for i: int in range(stage): history.append("✓ " + steps[i])
			if stage == 4: history.append(Qin.hint(s))
		"lightness_islet":
			if not (s.lightness_unlocked or (s.level >= 3 and s.sect in ["听潮阁", "照野堂", "问石门"])): return {}
			stage = 2 if s.lightness_relics.has(Lightness.RELIC_ID) else int(s.lightness_unlocked)
			title = "轻身功课" if stage == 0 else "轻身与拾遗 · 踏苇行"; status = _status(stage, 2)
			map = "qingwei"; site = "mentor" if stage == 0 else "reed_relic"
			action = "到练武堂南庭，请教踏苇行。" if stage == 0 else "由青苇渡东南浮石去苇心小洲，读读残碑背面的旧字。"
			if stage >= 1: history.append("✓ 已学会踏苇行。青苇渡东南浮石可去小洲，回程不耗物品。")
			if stage == 2: history.append("✓ 苇心残碑已拓录：留刻度，不留渡价。")
		"heting_delivery":
			stage = s.heting_stage
			if not (_mist_finished(s) or stage > 0) or not _stage(stage, 4): return {}
			title = HARBOR_TITLES[stage]; action = _harbor_hint(s); map = "heting"; site = _harbor_site(s); status = _status(stage, 4)
			if stage == 0: action = "沿听雨关东侧下埠道前往鹤汀埠，问明粮船实交。"
			for cargo: String in ["meal", "sealed", "reserve"]:
				if s.heting_delivered.has(cargo): history.append("✓ " + CARGO_NAMES[cargo])
			if stage > 0: history.append("当前押车：" + String(CARGO_NAMES.get(s.heting_cargo, "无")) + "；浮栈接" + ("西岸" if s.heting_bridge == "west" else "东岸") + "。")
			if s.heting_delivered.has("sealed"): history.append("复称发现：提前写成的全船浸损票，与抽称两担的干封不符。")
			if not s.heting_draft.is_empty():
				history.append(("已定：" if stage == 4 else "草案：") + String(PLAN_NAMES.get(s.heting_draft, s.heting_draft)))
				history.append("公秤棚夜间不留人，新交割等天亮复核。" if s.heting_draft == "short_ferries" else "远泊的人仍须靠岸，或等明日短渡。")
		"heting_receipt":
			stage = s.receipt_stage
			if s.heting_stage != 4 or not _stage(stage, 3): return {}
			title = "东岸次晨复核" if stage == 0 else "复签不撤"
			action = "到东岸公秤棚，听听次晨复核的事。" if stage == 0 else Receipt.hint(s)
			map = "heting"; site = "heting_scale"; status = _status(stage, 3)
			if stage > 0: history.append(Receipt.journal(s))
		"heting_consignee":
			stage = s.consignee_stage
			if not _consignee_earned(s) or not _stage(stage, 5): return {}
			title = "北仓新撤运单" if stage == 0 else "未损先收"
			action = "去调度牌问问北仓的新撤运单。" if stage == 0 else Consignee.hint(s)
			map = "heting"; site = _consignee_site(s); status = _status(stage, 5)
			if stage > 0: history.append(Consignee.journal(s))
		"capstone":
			stage = s.capstone_stage
			var goal: Dictionary = Capstone.goal(s)
			if goal.is_empty() and not (stage == 7 and Capstone.valid(Capstone.progress(s), Capstone.MAX_SUPPORTED_VERSION)): return {}
			title = Capstone.TITLE; action = String(goal.get("objective", "")); map = String(goal.get("map_id", "")); site = String(goal.get("site_id", "")); status = _status(stage, 7)
			var record: String = Capstone.journal(s)
			if stage == 6: record = record.replace("尚未向陆伯确认归灯，终章160阅历、80铜钱尚未结算；两案同额。", "尚未向陆伯确认归灯。")
			history.append(record)
		"mentor_reward":
			if not (s.sect_trial_won and s.sect_rank == 1) and not (s.sect_rank >= 2 and s.sect in ["听潮阁", "照野堂", "问石门"]): return {}
			stage = int(s.sect_rank >= 2); title = "待领门中荐记" if stage == 0 else "门中荐记"
			action = "岑远已验明考绩。到练武堂南庭领取内门荐记。"; map = "qingwei"; site = "mentor"
			status = "completed" if stage == 1 else "active"
			history.append("✓ 已通过门中考绩")
			if stage == 1: history.append("✓ 已领取内门荐记")
	if status == "completed":
		map = ""; site = ""; action = "此事已记定，可阅读已得见闻。"
	elif not action.is_empty() and not history.has(action): history.append("◇ " + action)
	return {"id":id, "kind":"objective", "display_title":title, "status":status, "trackable":status != "completed", "next_action":action, "destination_map":map, "destination_site":site, "earned_history":"\n".join(history), "step_key":id + ":" + str(stage) + ":" + site}

## Exact frozen Main._refresh last-applicable-branch policy. This intentionally
## keeps its broad Mist scout-method summary. Manual rows above describe only
## currently earned/affordable methods, and never mark locked actions usable.
static func automatic(s) -> Dictionary:
	if s == null: return {}
	var id: String = "opening"
	var title: String = s.quest_title()
	var hint: String = s.quest_hint()
	if s.quest_stage >= 6:
		id = "sluice"; title = "废闸疑云" if s.side_stage < 3 else "水令留痕"; hint = _side_hint(s)
	if s.chapter_two_stage > 0 or (s.quest_stage >= 6 and s.side_stage >= 3):
		id = "frostbridge"; title = _text(CHAPTER_TITLES, s.chapter_two_stage); hint = _text(CHAPTER_HINTS, s.chapter_two_stage)
	if tang_pending(s): id = "tang_notes"; title = "尺上旧痕"; hint = _tang_hint(s)
	if s.mist_stage > 0 and ((s.map_id == "mistwood" and (s.mist_stage < 4 or not tang_pending(s))) or (s.mist_stage < 4 and not tang_pending(s))):
		id = "qin_rope" if s.qin_stage in [1, 2, 3] else "mistwood"
		title = Qin.TITLE if id == "qin_rope" else _text(MIST_TITLES, s.mist_stage)
		hint = Qin.hint(s) if id == "qin_rope" else _text(MIST_HINTS, s.mist_stage)
	if track_shen(s): id = "shen_care"; title = "药箱之外"; hint = _shen_hint(s)
	if track_heting(s):
		id = "heting_consignee" if s.consignee_stage in [1, 2, 3, 4] else ("heting_receipt" if s.receipt_stage in [1, 2] else "heting_delivery")
		title = "未损先收" if id == "heting_consignee" else ("复签不撤" if id == "heting_receipt" else _text(HARBOR_TITLES, s.heting_stage))
		hint = _combined_harbor_hint(s)
	if s.map_id == "mistwood" and s.qin_stage in [1, 2, 3]: id = "qin_rope"; title = Qin.TITLE; hint = Qin.hint(s)
	if s.sect_trial_won and s.sect_rank == 1 and s.map_id == "qingwei": id = "mentor_reward"; title = "待领门中荐记"; hint = "岑远已验明考绩。到练武堂南庭领取内门荐记。"
	var capstone: Dictionary = Capstone.goal(s)
	if not capstone.is_empty(): id = "capstone"; title = Capstone.TITLE; hint = String(capstone.objective)
	var result: Dictionary = row(s, id)
	if result.is_empty(): return {}
	result.display_title = title; result.next_action = hint; result.source_arc_id = id
	if not result.trackable:
		result.kind = "exploration"; result.id = ""; result.destination_map = s.map_id
		result.destination_site = _legacy_local_landmark(s)
		result.step_key = "exploration:" + id + ":" + str(s.map_id) + ":" + result.destination_site
	return result

static func tang_pending(s) -> bool: return s.tangqi_stage > 0 and not s.tangqi_unlocked
static func shen_pending(s) -> bool: return s.shen_care_stage in [1, 2, 3, 4]
static func track_shen(s) -> bool:
	if s.map_id == "mistwood" and s.qin_stage in [1, 2, 3]: return false
	return s.map_id != "heting" and shen_pending(s) and not tang_pending(s) and not (s.map_id == "mistwood" and s.mist_stage < 4) and not (s.map_id == "qingwei" and s.sect_trial_won and s.sect_rank == 1)
static func track_heting(s) -> bool:
	if s.map_id == "mistwood" and s.qin_stage in [1, 2, 3]: return false
	if s.map_id == "heting": return s.heting_stage > 0
	if tang_pending(s) or shen_pending(s): return false
	if s.map_id == "qingwei" and s.sect_trial_won and s.sect_rank == 1: return false
	return s.consignee_stage in [1, 2, 3, 4] or s.heting_stage in [1, 2, 3] or (s.heting_stage == 0 and s.mist_stage == 4 and s.map_id == "mistwood")
static func _stage(value: int, maximum: int) -> bool: return value >= 0 and value <= maximum
static func _status(stage: int, terminal: int) -> String: return "completed" if stage >= terminal else ("available" if stage == 0 else "active")
static func _text(values: Array[String], index: int) -> String: return values[index] if index >= 0 and index < values.size() else ""
static func _mist_finished(s) -> bool: return s.mist_stage == 4 and s.mist_ending in ["release_water", "warn_ferries"]
static func _shen_earned(s) -> bool: return s.companion_unlocked and s.quest_stage >= 6 and s.side_stage >= 3 and s.side_choice in ["rescue", "pursuit"] and s.ending in ["秉公", "守望"]
static func _consignee_earned(s) -> bool:
	return s.heting_stage == 4 and s.receipt_stage in [0, 1, 2, 3] and s.chapter_two_stage == 4 and s.chapter_two_ending in ["open_records", "protect_witness"] and Heting.valid(Consignee.progress(s), 9)
static func _side_hint(s) -> String:
	if s.map_id == "sluice" and s.side_stage == 0: return "南岸有人呼救，东北有人携卷而去。先救人，还是先追线索？"
	return _text(["沿村东古道前往废闸，追查账册上的水纹印记。", "救下船工，并夺回传令人的账页。行动先后将改变收获。", "证言与账页已齐，去旧闸东南找闸首对质。", "旧闸的水令已寻回。回村休整，继续切磋与修行。"], s.side_stage)
static func _tang_hint(s) -> String:
	return "返回废闸西北旧仓木匣，寻找唐栖父亲的工册。" if s.tangqi_stage == 1 else ("回霜桥南桥，将旧工册交给唐栖。" if s.tangqi_stage == 2 else "回霜桥南桥，与唐栖商议同行。")
static func _shen_hint(s) -> String:
	return _text(["完成废闸疑云，并与沈青结伴后，回青苇药铺问问船工近况。", "去废闸南岸找许照川，这次听听他自己的近况。", "去废闸西北旧仓药棚，查看能照应哪些来往的人。", "回青苇药铺，把船工与药棚的情况告诉沈青。", "到青苇渡中央告示牌张贴照护约；张贴前可回药铺改议。", "留岸照护已议定。" if s.shen_care_choice == "shore" else "随船问诊已议定。"], s.shen_care_stage)
static func _chapter_site(s) -> String:
	if s.chapter_two_stage == 1:
		if not s.archive_clues.has("clerk"): return "chapter_clerk"
		if not s.archive_clues.has("inscription"): return "chapter_inscription"
		return "chapter_archive"
	return "chapter_archive" if s.chapter_two_stage == 2 else "chapter_host"
static func _mist_site(s) -> String:
	if s.mist_stage == 1:
		if not s.mist_gauges.has("rain"): return "mist_rain_gauge"
		if not s.mist_gauges.has("basin"): return "mist_basin"
		return "mist_scout" if s.mist_approach.is_empty() else "mist_stone_gauge"
	return "mist_gate" if s.mist_stage == 2 else "mist_guide"
static func _harbor_receiver(s) -> String:
	if s.heting_cargo == "meal": return "heting_relief"
	if s.heting_cargo == "sealed": return "heting_scale"
	return "heting_relief" if s.heting_draft == "short_ferries" else "heting_scale"
static func _harbor_site(s) -> String:
	if not s.heting_cargo.is_empty(): return _harbor_receiver(s)
	return {1:"heting_cargo", 2:"heting_dispatch", 3:"heting_lighter"}.get(s.heting_stage, "heting_dispatch")
static func _harbor_hint(s) -> String:
	if s.heting_stage == 0: return "沿听雨关东侧下埠道前往鹤汀埠，追看粮船的实交。"
	if not s.heting_cargo.is_empty(): return "押" + String(CARGO_NAMES.get(s.heting_cargo, "无")) + "至" + ("西岸粥棚" if _harbor_receiver(s) == "heting_relief" else "东岸公秤棚") + "；窄步栈过不了车，可免费改泊或沿北岸绕行。"
	return {1:"中埠粮船有两批固定货：开锅粮送西岸，对秤封粮送东岸，可任选先后。", 2:"两批已办妥。回北岸交割牌，与孟绫议定今夜的人手。", 3:"到南泊短驳提待分粮；按草案交货前仍可改议。", 4:"今夜安排保留。可问孟绫的新撤运单；东岸复签仍可另办。"}.get(s.heting_stage, "")
static func _combined_harbor_hint(s) -> String:
	if s.consignee_stage in [1, 2, 3, 4]:
		return "沿既有粮路返回鹤汀埠，继续未损先收；北仓封粮、已查记录与草案保留。" if s.map_id != "heting" else Consignee.hint(s) + " 复签仍可到东岸公秤另办。"
	if s.receipt_stage in [1, 2]: return Receipt.hint(s)
	if s.consignee_stage == 5: return Consignee.hint(s) + " 旧复签仍可到东岸公秤另核，或沿北岸山道返回。"
	return _harbor_hint(s)
static func _consignee_site(s) -> String:
	if s.consignee_stage == 1:
		for observation: String in Consignee.OBSERVATIONS:
			if not s.consignee_observations.has(observation): return {"lot_seals":"consignee_warehouse", "removal_order":"heting_dispatch", "southern_counterfoil":"heting_lighter"}[observation]
	if s.consignee_stage == 2: return "heting_dispatch" if s.consignee_draft.is_empty() else Consignee.SOURCE
	if s.consignee_stage == 3: return Consignee.SOURCE
	if s.consignee_stage == 4: return Consignee.receiver_for(s.consignee_draft)
	return "heting_dispatch"

## Only used for a completed automatic branch. One owner retains the frozen
## world onward/rest landmark; active/manual goals never use this cascade.
static func _legacy_local_landmark(s) -> String:
	if track_heting(s):
		if s.map_id == "heting":
			if s.consignee_stage in [1, 2, 3, 4]: return _consignee_site(s)
			if s.receipt_stage in [1, 2]: return "heting_scale"
			return _harbor_site(s)
	if track_shen(s): return {"qingwei":"exit_sluice" if s.shen_care_stage in [1, 2] else ("healer" if s.shen_care_stage == 3 else "board"), "sluice":"stranded_boatman" if s.shen_care_stage == 1 else ("sluice_cache" if s.shen_care_stage == 2 else "return_village"), "frostbridge":"return_sluice", "mistwood":"return_frostbridge"}.get(s.map_id, "")
	if s.map_id == "mistwood":
		if s.qin_stage in [1, 2, 3]: return Qin.target_id(s)
		return _mist_site(s) if s.mist_stage in [1, 2, 3] else "mist_camp"
	if s.map_id == "qingwei" and s.sect_trial_won and s.sect_rank == 1: return "mentor"
	if s.qin_stage in [1, 2, 3]: return Qin.target_id(s)
	if s.map_id == "heting": return "heting_dispatch"
	if s.map_id == "frostbridge":
		if s.chapter_two_stage == 4: return "bridge_worker" if not s.bridge_repaired else ("exit_mistwood" if s.mist_stage == 0 else "return_sluice")
		return _chapter_site(s)
	if s.map_id == "sluice":
		if s.side_stage < 2: return "ledger_runner" if s.side_found.has("boatman") else "stranded_boatman"
		if s.side_stage == 2: return "sluice_boss"
		return "exit_frostbridge" if s.chapter_two_stage < 4 else "return_village"
	return "exit_sluice" if s.quest_stage >= 6 and s.side_stage < 3 else ""
