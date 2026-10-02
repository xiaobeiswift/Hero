class_name QinCompanionStory
extends RefCounted
const Rules = preload("res://scripts/qin_companion_rules.gd")
const Region = preload("res://scripts/mistwood_region.gd")
var host
func _init(owner) -> void: host = owner

func handle(id: String) -> bool:
	if host.state.map_id != "mistwood" or host.state.mist_stage != 4: return false
	if id == "mist_guide": guide(); return true
	if id == "mist_rain_gauge" and host.state.qin_stage == 1: rope(); return true
	if id == "mist_camp" and host.state.qin_stage == 2: handoff(); return true
	return false

func _guard(action: Callable, stage: int, landmark: String) -> Callable:
	return _apply.bind(action, stage, landmark, host.modal_generation + 1)

func _apply(action: Callable, stage: int, landmark: String, generation: int) -> void:
	if host.current_screen != "explore" or not host.active_modal or generation != host.modal_generation: return
	if not Rules.eligible(host.state) or host.state.qin_stage != stage: return
	if host.world.player_pos.distance_to(Region.points()[landmark].pos) > 85: return
	action.call()

func guide() -> void:
	var s = host.state
	var choices: Array = []
	var body: String
	match s.qin_stage:
		0:
			body = "秦禾把旧公文收进布袋，手里只留下一根刻过水线的长杖。\n\n“底稿带出去了，可这里不能只剩一句‘有人照看’。竹尺的警水绳松了，营地也该有人接着记雨。”\n\n“帮我复核一遍，再把轮值交到人手上。我才好离开这道坡，亲自看看那些令最后落在谁身上。”\n\n这件事不用交钱或物品。办妥后仍由你决定是否邀请她同行。"
			choices.append(["帮她复核尺绳", _guard(begin, 0, "mist_guide")])
		1, 2:
			body = "“尺绳交给肯看它的人，才算真的交出去了。”\n\n" + Rules.hint(s)
		3:
			body = "营地守坡人已经认下轮值，也记住了警水刻线。秦禾把长杖横在膝前，听完你的转述。\n\n“那就轮到我走远些了。再见有人拿一纸公文催人涉水，我也好替他挡一挡。”\n\n邀请后秦禾加入当前队伍，最多主角与三名同伴。她有独立的气血、真气与行动；守渡横杖为一名活着的队友承受下一次来击，不治疗或复起倒地者。"
			choices.append(["邀请秦禾同行", _guard(invite, 3, "mist_guide")])
		_:
			body = "“尺绳有人接着看，我们也该接着走。”\n\n秦禾已接受你的邀请。她的长杖既能出招，也能横在同伴与来敌之间。\n\n" + Rules.hint(s)
	choices.append(["谈谈水势与底稿", host.mist_story.guide])
	choices.append(["稍后再谈", host._close_modal])
	host._modal("秦禾 · 旧监水吏", "同行机缘 / 尺绳有托", body, choices, true)

func rope() -> void:
	host._modal("雨痕竹尺", "尺绳有托 / 复核刻线", "竹尺上旧雨痕还在。你依着原先拓下的读数，将松开的尺绳重新对齐警水刻线。\n\n绳结要留在不被第一道涨水淹住的位置，营地的人才来得及示警。这里只复核轮值用的刻线，不改写调查记录。", [["核好尺绳，记下轮值要点", _guard(inspect, 1, "mist_rain_gauge")], ["稍后再查", host._close_modal]], true)

func handoff() -> void:
	host._modal("避雨营地 · 轮值守坡人", "尺绳有托 / 交到人手上", "守坡人接过记着警水刻线的竹片，重新说了一遍巡看的时辰。\n\n“水到这道线就敲钟，不必等一张新令。缺班的人，由我先顶上。”\n\n你把尺绳所在与示警办法交代清楚。秦禾可以放心离坡，但是否与你同行，还要亲口相邀。", [["确认轮值交接", _guard(arrange, 2, "mist_camp")], ["先免费调息", host.mist_story.rest], ["稍后再谈", host._close_modal]], true)

func route_info() -> void:
	host._modal("秦禾的近况", "同行机缘 / 尺绳有托", Rules.hint(host.state) + Rules.journal(host.state), [["返回同行册", host._show_party_roster], ["继续赶路", host._close_modal]], true)

func begin() -> void:
	if host.state.begin_qin_quest(): host._close_modal(); host._toast(Rules.hint(host.state))
func inspect() -> void:
	if host.state.inspect_qin_rope(): host._close_modal(); host._toast(Rules.hint(host.state))
func arrange() -> void:
	if host.state.arrange_qin_handoff(): host._close_modal(); host._toast(Rules.hint(host.state))
func invite() -> void:
	if host.state.recruit_qin(): host._close_modal(); host._toast("秦禾应邀同行。当前队伍最多四人，气血与真气各自记录。")
