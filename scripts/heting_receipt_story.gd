class_name HetingReceiptStory
extends RefCounted
## Optional next-morning encounter. HeroState owns all combat and reward writes;
## this controller only accepts the errand, checkpoints, and compares evidence.
const Receipt = preload("res://scripts/heting_receipt_rules.gd")
const Harbor = preload("res://scripts/heting_rules.gd")
var host


func _init(owner) -> void:
	host = owner


func _port_ready() -> bool:
	if host.current_screen != "explore" or host.state.battle_active \
		or host.state.map_id != "heting" or host.world.map_id != "heting" \
		or host.state.heting_stage != 4 or not host.state.heting_cargo.is_empty():
		return false
	var progress: Dictionary = host.state.to_dict()
	return Harbor.valid(progress, 9) and Receipt.valid(progress, 11)


func _at_scale() -> bool:
	return _port_ready() and host.world.interactables.has("heting_scale") \
		and host.world.player_pos.is_finite() \
		and host.world.player_pos.distance_to(host.world.interactables.heting_scale.pos) < 75.0


func _guard(action: Callable, require_scale: bool = true) -> Callable:
	return _apply.bind(action, host.modal_generation + 1, require_scale)


func _apply(action: Callable, generation: int, require_scale: bool) -> void:
	if not host.active_modal or generation != host.modal_generation or not _port_ready():
		return
	if require_scale and not _at_scale():
		return
	action.call()


func _modal(subtitle: String, body: String, options: Array, title: String = "施衡 · 复签不撤") -> void:
	host._modal(title, subtitle, body, options, true)
	host.modal_autosave_on_close = false


func _close() -> void:
	host.modal_autosave_on_close = false
	host._close_modal()


func open() -> void:
	if not _at_scale():
		return
	match host.state.receipt_stage:
		0: _offer()
		1: _ready()
		2: _compare_ready()
		3: _record()


func _offer() -> void:
	var last_night: String = "昨夜两名埠工随短渡分粮，秤棚没有夜班。施衡照约在次晨开秤，才来核对白日留下的副签。" if host.state.heting_ending == "short_ferries" else "昨夜两名埠工守秤，共同存粮也照章记下。次晨换班，施衡把白日的副签拿出来续核；远泊的短渡仍待接着安排。"
	_modal("鹤汀余事 / 可选 · 次晨复核", last_night + "\n\n“昨夜怎样分粮，照原议的办。这张复称签，也不能因换了一班人就撤。”\n\n两名受雇刀手截住了送签的人，把副签扣在秤棚外。他们要施衡撤下实交记录，免得假水损票与那笔预结粮钱留下可核的来路。\n\n这是一件可选余事，随时可先离开。接下只记委托，不立刻开战；两岸原定安排与第四章奖励不变。", [["接下取签之事", _guard(_accept)], ["先不接下", _guard(_close, false)]])


func _accept() -> void:
	if not _at_scale() or host.state.receipt_stage != 0 or not host.state.begin_receipt():
		return
	# Acceptance must be an ordinary durable checkpoint before combat is offered.
	host._autosave()
	if host.save_warning:
		_save_failed()
	else:
		_ready()


func _resources() -> String:
	var s = host.state
	return "当前气血%d/%d，真气%d/%d，回春散%d份。" % [s.hp, s.max_hp, s.qi, s.max_qi, s.medicine]


func _ready() -> void:
	if not _at_scale() or host.state.receipt_stage != 1:
		return
	_modal("鹤汀余事 / 应战前核对", _resources() + "\n\n[color=#d3b276]这是实战：[/color]出招与用药会真实消耗；撤退不另扣钱，已用资源不返还。败北最多遗落8文，送回西岸粥棚并恢复气血，真气至少留2点。西岸粥棚可免费调息，备妥再来。\n\n取签之事拖到月上。两名刀手守在公秤外栈桥：截签刀客进攻，架刀护手替他挡招。点击对手或按Tab切换目标，先破护手可解除减伤。\n\n“副签只记货号、两担干封与到港时刻，不写船工姓名。取回后，与水损票、预结粮钱的旧抄件并看。”\n\n首次胜利得80修为、40文；核签不再另发奖励。", [["保存后应战", _guard(_start)], ["先去免费调息", _guard(_close, false)], ["暂且离开", _guard(_close, false)]])


func _start() -> void:
	if not _at_scale() or host.state.receipt_stage != 1:
		return
	# Resources may have changed since acceptance; checkpoint the current state.
	host._autosave()
	if host.save_warning:
		_save_failed()
		return
	_close()
	host._start_receipt_battle()


func _save_failed() -> void:
	_modal("复签不撤 / 尚未存妥", "本次保存没有成功，交锋尚未开始。已接下的委托仍留在当前旅程中，不会退回未听闻，也不重复给奖。\n\n可检查存储条件后重试；也可先回埠内。离开对话不会丢弃当前进度，退出游戏前请先存妥。", [["重试保存", _guard(_retry_checkpoint)], ["先回埠内", _guard(_close, false)]])


func _retry_checkpoint() -> void:
	if not _at_scale():
		return
	host._autosave()
	if host.save_warning:
		if host.state.receipt_stage == 1:
			_save_failed()
		else:
			_record()
		return
	open()


func _compare_ready() -> void:
	if not _at_scale() or host.state.receipt_stage != 2:
		return
	_modal("鹤汀余事 / 副签待核", "副签已经取回，货号、两担与干封记号都还在。施衡把它压在秤砣旁，另取出水损票和预结粮钱的旧抄件。\n\n“打赢只能把纸留下。它能证到哪一步，还得照着担数与时刻来。”\n\n现在可当面核对三处记录，补入行纪；不会再发一份胜利奖励。", [["并看三处记号", _guard(_compare)], ["稍后再核", _guard(_close, false)]])


func _compare() -> void:
	if not _at_scale() or host.state.receipt_stage != 2 or not host.state.compare_receipt():
		return
	host._autosave()
	_record()


func _record() -> void:
	if not _at_scale() or host.state.receipt_stage != 3:
		return
	var body: String = Receipt.journal(host.state) + "\n\n“能认下这两担，就把这两担记住。不拿它替整船、替所有人作保。”\n\n复核已写进行纪。短渡与守秤各自照顾的难处仍在，昨夜的安排照旧；回访只重看记录。"
	var options: Array = [["收好记录", _guard(_close, false)]]
	if host.save_warning:
		body += "\n\n本次记录尚未存妥，当前进度仍保留。重试只补存这份结果，不重复核签或发奖。"
		options.push_front(["重试保存", _guard(_retry_checkpoint)])
	_modal("鹤汀余事 / 副签已核", body, options)


func after_battle(summary: Dictionary) -> void:
	# Called only after settlement and world restoration. Reading this immutable
	# receipt never changes resources, stage, rewards, or persistence.
	if not _port_ready() or int(summary.get("stage", -1)) != host.state.receipt_stage:
		return
	var outcome: String = String(summary.get("outcome", ""))
	var body: String = ""
	var options: Array = []
	match outcome:
		"win":
			if host.state.receipt_stage != 2:
				return
			body = "刀手退开，副签留在你手里。两担干粮的记号还在，但假水损与预结粮钱怎样相接，仍须同施衡核对。"
			if bool(summary.get("awarded", false)):
				body += "\n\n本次已结算：80修为、%d文。" % int(summary.get("coin_change", 0))
			else:
				body += "\n\n本次没有重复发放奖励。"
			if int(summary.get("level_after", 0)) > int(summary.get("level_before", 0)):
				body += "境界由%d级升至%d级。" % [int(summary.level_before), int(summary.level_after)]
			options.append(["与施衡核签", _guard(_compare_ready)] if _at_scale() else ["回东岸核签", _guard(_close, false)])
			options.append(["稍后再核", _guard(_close, false)])
		"flee":
			if host.state.receipt_stage != 1:
				return
			body = "你退回秤棚一侧，副签仍待取回。已经出招、用药的消耗照实保留，撤退不另扣钱，也没有发放奖励。\n\n" + _resources() + "\n可以先去西岸粥棚免费调息，之后再到施衡处应战；昨夜的分粮安排照旧。"
			options.append(["先回埠内", _guard(_close, false)])
		"defeat":
			if host.state.receipt_stage != 1:
				return
			body = "埠工将你送回西岸粥棚。败退时遗落了%d文；照应后气血已恢复，真气至少留2点，用掉的回春散没有返还。\n\n" % maxi(0, -int(summary.get("coin_change", 0)))
			body += _resources() + "\n副签仍待取回，没有发放胜利奖励。棚下可继续免费调息；准备好后回东岸找施衡即可，接下的委托与昨夜安排都还在。"
			options.append(["在西岸歇脚", _guard(_close, false)])
		_:
			return
	if host.save_warning:
		body += "\n\n本次结果尚未存妥，已结算的消耗和奖励仍保留在当前旅程。请先重试保存，再退出游戏。"
	_modal("鹤汀余事 / " + {"win": "副签取回", "flee": "暂退留步", "defeat": "西岸缓息"}[outcome], body, options, "复签不撤")
