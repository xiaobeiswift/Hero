class_name LightnessStory
extends RefCounted
const L=preload("res://scripts/lightness_rules.gd")
var host
func _init(owner)->void:host=owner
func _guard(action:Callable)->Callable:return _apply.bind(action,host.modal_generation+1)
func _apply(action:Callable,generation:int)->void:
	if host.current_screen=="explore" and host.active_modal and host.modal_generation==generation:action.call()
func lesson()->void:
	var body="岑远将两枚石子放在地上，隔出一小段距离。\n\n“轻身不是忘了脚下。看准这一处借力，也要先替自己留好归路。”\n\n踏苇行可越过青苇渡东南浮石间的断水，抵达苇心小洲。\n只在标明的渡点使用，不改变普通行走碰撞。来回不耗真气或物品。"
	var choices:Array=[]
	if host.state.lightness_unlocked:
		body+="\n\n你已经学会踏苇行。小洲的回岸浮石始终可以使用。"
	elif host.state.Lightness.can_learn(host.state):
		body+="\n\n修习要求：3级、已获门派荐帖；不收费。"
		choices.append(["修习踏苇行",_guard(learn)])
	else:body+="\n\n先到3级并获得门派荐帖，再来练习落脚。"
	choices.append(["返回门中功课",host.sect_progress.show]);choices.append(["告辞",host._close_modal])
	host._modal("岑远 · 轻身课","探索 / 踏苇行",body,choices,true)
func learn()->void:
	if host.state.learn_lightness():
		host._close_modal();host._toast("习得踏苇行。青苇渡东南岸的苇心浮石可通往小洲。")
func shore()->void:
	var choices:Array=[]
	var text="河岸外露着几块湿石，中间仍隔着一段流水。苇心小洲上似乎立着一截残碑。\n\n这里不能直接涉水。"
	if host.state.lightness_unlocked:
		text+="\n\n你记起岑远教过的落脚：借浮石过水，先看清归处。\n踏苇行不消耗真气；到洲上后仍可免费返回。"
		choices.append(["踏苇过水",_guard(cross.bind(true))])
	else:text+="\n\n练武堂南庭的岑远可教轻身基础。需3级并已获门派荐帖，不收费用。"
	choices.append(["留在岸上",host._close_modal])
	host._modal("苇心浮石","探索 / 一水之外",text,choices,true)
func return_bank()->void:
	host._modal("回岸浮石","踏苇行 / 归路常留","河岸上的旧路还在。无论是否读过残碑，都可以从这里安全回去。\n\n返回不耗真气、物品，也不重置气血。",[["借石回岸",_guard(cross.bind(false))],["再看看小洲",host._close_modal]],true)
func cross(outward:bool)->void:
	host.state.position=host.world.player_pos
	if not host.state.cross_reed_water(outward):
		host._toast("请站在对应的浮石渡点；去小洲前须学会踏苇行。")
		return
	var destination=host.state.position
	host.world.teleport(destination)
	host._close_modal()
	host._toast("借浮石落在苇心小洲。残碑与回岸浮石都在脚边。" if outward else "已回青苇渡东南岸。来去的路，都要看清。")
func relic()->void:
	if not L.on_islet(host.world.player_pos) or host.state.map_id!="qingwei":return
	if not host.state.lightness_unlocked:
		host._modal("苇心残碑","探索 / 先认归路","你尚未修习踏苇行。先从回岸浮石安全返回，再向岑远请教。",[[ "借石回岸",_guard(cross.bind(false))],["暂留片刻",host._close_modal]],true)
		return
	if host.state.lightness_relics.has(L.RELIC_ID):
		host._modal("苇心残碑","山河拾遗 / 已拓录","碑背的小字已经收入江湖志：\n\n“留刻度，不留渡价。水涨时，先问哪一岸还有人。”\n\n石匣已空。旧字仍在，不会再给同一份谢礼。")
		return
	host._modal("苇心残碑","山河拾遗 / 无名人的刻度","残碑正面被芦叶磨得模糊，背面却刻着不同年月的水痕。\n\n一位撑篙人留下的，不是谁能收多少渡钱，而是水涨时，哪一岸还有落脚的地方。\n\n“留刻度，不留渡价。水涨时，先问哪一岸还有人。”\n\n碑边石匣中，过路人留了一包草药与18文谢礼。拓录后得30修为、草药×1；这份拾遗只结算一次。",[["拓录残碑",_guard(discover)],["暂且离开",host._close_modal]],true)
func discover()->void:
	host.state.position=host.world.player_pos
	if host.state.discover_reed_islet():
		host._close_modal();host._toast("山河拾遗：苇心残碑。修为+30、铜钱+18、草药+1。")
func journal()->String:
	if not host.state.lightness_unlocked:return "\n\n[color=#d3b276]轻身与拾遗[/color]\n3级并获门派荐帖后，可向岑远请教踏苇行。"
	var found=host.state.lightness_relics.has(L.RELIC_ID)
	return "\n\n[color=#d3b276]轻身与拾遗 · 踏苇行[/color]\n已学会。青苇渡东南浮石可去小洲，回程不耗物品。\n"+("✓ 苇心残碑已拓录：留刻度，不留渡价。" if found else "◇ 到苇心小洲，读读残碑背面的旧字。")
