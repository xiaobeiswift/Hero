class_name FrostbridgeStory
extends RefCounted
## Original chapter dialogue and routing, separate from the general interface.
var host
func _init(owner) -> void:host=owner
func handle(id:String) -> bool:
	match id:
		"exit_frostbridge":entry()
		"return_sluice":host._travel("sluice",Vector2(1390,290))
		"chapter_host":innkeeper()
		"chapter_clerk":clerk()
		"chapter_inscription":inscription()
		"chapter_archive":archive()
		"bridge_worker":bridge()
		"frost_ore","frost_timber","frost_herb":gather(id)
		_:return false
	return true
func entry() -> void:
	if host.state.side_stage<3:
		host._modal("霜桥古道","道路 / 上游封仓","古道通往霜桥驿。先把废闸的证言与账页查清，才知道该拿什么去问上游的人。")
		return
	host._modal("沿旧令上行","第二章 / 印下有声","水令背面的地址指向霜桥驿。第一场薄霜落下时，你看见粮仓的门被三道印扣封住。\n\n一纸公文能把河流拦住吗？这一回，答案也许藏在印记的先后。",[["前往霜桥驿",enter_region],["暂留废闸",host._close_modal]],true)
func enter_region() -> void:
	if host.state.chapter_two_stage==0:host.state.begin_chapter_two()
	host._travel("frostbridge",Vector2(190,500))
func innkeeper() -> void:
	var state=host.state
	if state.chapter_two_stage==3:
		host._modal("温行舟 · 驿丞","抉择 / 账目与姓名","原账记下了被改动的水令，也记下了那些被迫按印的船工姓名。\n\n温行舟把灯移近：‘账要见光，人也要有归路。你来决定这份证据怎样留下。’\n\n[color=#d3b276]公示原账[/color]：让过路人自行核对，也会暴露证人的姓名\n[color=#d3b276]隐去姓名[/color]：由驿站和船家互校账目，保全证人",[["公示原账",finish.bind("open_records")],["隐去姓名",finish.bind("protect_witness")]],true)
		return
	var body="‘你从青苇渡来？那盏灯总算亮了。’\n\n温行舟说，粮仓的原账被韩砚看守，门上用了水、驿、仓三种印扣。\n先问东北文书房的纪小砚，再看看北桥西头的旧碑。\n\n驿馆可免费歇脚。南桥坏了，工匠唐栖正在找木料。"
	if state.chapter_two_stage==2:body="三印已经解开。去东南封仓印台，向韩砚问清原账的去向。\n\n驿馆仍有一处热炭，整备好了再动身。"
	elif state.chapter_two_stage>=4:
		body=("驿道旁挂出了原账。粮价和水令第一次被放在同一张纸上核对。" if state.chapter_two_ending=="open_records" else "船工姓名被妥善封存。驿站和船家各持一份账，谁也不能独自改字。")+"\n\n温行舟收好你的旧信：‘霜桥的人会记得，你不只问了一场胜负。’"
	host._modal("温行舟 · 驿丞","霜桥驿 / 借灯问路",body,[["借榻调息",rest],["告辞",host._close_modal]],true)
func rest() -> void:
	host.state.heal_rest();host._close_modal();host._toast("驿馆调息完毕，气血与真气已恢复。")
func clerk() -> void:
	var route="县衙送来的抄件，与您带来的水令对得上。" if host.state.ending=="秉公" else "船家托来的抄件，我一直替他们留着。"
	host._modal("纪小砚 · 文书学徒","线索 / 三印的来历",route+"\n\n三枚印扣不是权位的高低，而是粮船走过的路：先领水令，再过驿站，最后入仓。\n\n旧桥碑上还刻着一道先后口诀。知道印是什么，还得知道怎样转。",[["记下文书线索",record_clue.bind("clerk")],["先不打扰",host._close_modal]],true)
func inscription() -> void:
	host._modal("旧桥碑文","线索 / 启封口诀","薄霜下的字仍很清晰：\n\n[color=#d3b276]水印先行，驿印居中，仓印收尾。[/color]\n\n碑旁另有一行小字：‘印为行路作证，不替持印者遮羞。’\n\n这不是武力能破开的锁。把口诀和纪小砚的话一并记下。",[["拓下碑文",record_clue.bind("inscription")],["离开",host._close_modal]],true)
func record_clue(id:String) -> void:
	var gained=host.state.add_archive_clue(id)
	host._close_modal()
	host._toast("线索记入江湖志，修为 +10。" if gained else "这条线索已经记下。")
func archive() -> void:
	var state=host.state
	if state.chapter_two_stage>=3:
		host._modal("封仓印台","霜桥驿 / 原账已得","印扣已经打开，原账也已收妥。"+("返回西岸驿馆，和温行舟商议怎样留下证据。" if state.chapter_two_stage==3 else "这一处旧账，终于有了新的读法。"))
		return
	if state.chapter_two_stage==2:
		host._modal("韩砚 · 仓门执事","交锋 / 印下有声","‘你识得三印，却未必识得持印的人。’\n\n韩砚将原账压在案下。他说自己只守仓门，不问水令为何被改。\n\n[color=#d3b276]敌方重击带有破绽。守势能化解；工艺装备与门派招式也会帮助你。[/color]",[["请他让路",func():host._start_battle("archive_boss")],["先行整备",host._close_modal]],true)
		return
	if state.archive_clues.size()<2:
		host._modal("三道封印","霜桥驿 / 线索未齐","印台上刻着驿、仓、水三个字。先问纪小砚，再读北桥西头的碑文，贸然乱试不会打开它。")
		return
	host._modal("三印机关","解谜 / 按启封次序选择", "[color=#d3b276]已对上 %d / 3 枚印扣[/color]\n\n驿印、仓印、水印，哪一枚应当先转？\n错误顺序会重新归零，不损失物品。\n\n可随时打开江湖志重看已记录的口诀。" % state.seal_sequence.size(),[["驿印",seal.bind(0)],["仓印",seal.bind(1)],["水印",seal.bind(2)],["暂且离开",host._close_modal]],true)
func seal(index:int) -> void:
	var result=host.state.try_seal(index)
	host._autosave();host._refresh();archive();host._toast(result.message)
func battle_victory() -> void:
	host.state.mark_archive_victory()
	host._modal("印台下的原账","战斗胜利 / 印下有声","韩砚收起兵刃：‘若只问谁的印最大，这仓里永远只有一种答案。’\n\n你翻开原账，发现每次改令前都有一笔提前结算的粮钱。证据已齐，证人却未必愿意被推到众人眼前。\n\n回西岸驿馆，和温行舟作最后的决定。",[["收好原账",host._close_modal]],true)
func finish(choice:String) -> void:
	var success=host.state.resolve_chapter_two(choice)
	host._close_modal()
	if success:host._toast("第二章完成 · 修为 +100、铜钱 +65。东北竹坡道通往雾竹坡。")
func bridge() -> void:
	if host.state.bridge_repaired and host.state.chapter_two_stage>=4:
		host.companion_story.bridge();return
	if host.state.bridge_repaired:
		host._modal("唐栖 · 修桥匠","支线 / 一桥两岸","南桥已修好。唐栖把刨子收进布包：‘走近路的人，也别忘了是谁把木头一块块搭上去的。’\n\n两岸之间已多出一条可通行的近路。")
		return
	host._modal("唐栖 · 修桥匠","支线 / 一桥两岸","‘桥骨没坏，缺的是两块好木料。’\n\n西南路旁散着可用的木料，也可以从货担购买。交出 2 份木料，就能修通南桥，省去绕行北桥的路。\n\n报酬：20 铜钱、25 修为，只结算一次。",[["交出木料 ×2",repair],["下次再来",host._close_modal]],true)
func repair() -> void:
	if not host.state.repair_bridge():host._toast("木料不足2份，或南桥已经修复。")
	else:
		host.world.bridge_repaired=true;host._close_modal();host._toast("南桥修复 · 铜钱 +20、修为 +25，近路已通。")
func gather(id:String) -> void:
	var names={"frost_ore":"露头铁矿","frost_timber":"散落木料","frost_herb":"耐寒药草"}
	if host.state.gathered_nodes.has(id):
		host._modal(names[id],"霜桥风物 / 已采集","这处可用的材料已经收进你的行囊。余下的部分不宜再取，换一处寻找吧。")
		return
	host._modal(names[id],"采集 / 霜桥风物","可取得三份工艺材料。本处只采集一次，不会通过往返地图刷新。\n\n青苇渡任务所需的青穗草仍单独保存。",[["小心采集",collect.bind(id)],["留下它们",host._close_modal]])
func collect(id:String) -> void:
	var result=host.state.gather_resource(id)
	host._close_modal();host._toast(result.message)
func quest_title() -> String:
	return ["霜桥来信","三印问路","封仓问剑","原账与姓名","霜桥余响"][host.state.chapter_two_stage]
func quest_hint() -> String:
	return ["沿废闸东北古道，前往霜桥驿。","调查北桥碑文和东北文书房，按口诀解开东南印台。","机关已开，去东南印台向韩砚索取原账。","回西岸驿馆，与温行舟决定证据的公开方式。","原账已有归处。可修南桥、返回研艺，或沿东北竹坡道追查雨令。"][host.state.chapter_two_stage]
func target_id() -> String:
	match host.state.chapter_two_stage:
		1:
			if not host.state.archive_clues.has("clerk"):return "chapter_clerk"
			if not host.state.archive_clues.has("inscription"):return "chapter_inscription"
			return "chapter_archive"
		2:return "chapter_archive"
		3:return "chapter_host"
		4:return "bridge_worker" if not host.state.bridge_repaired else ("exit_mistwood" if host.state.mist_stage==0 else "return_sluice")
	return "chapter_host"
func journal() -> String:
	var s=host.state
	var body="[color=#d3b276]第一章与废闸行纪：已完成[/color]\n\n[color=#d3b276]第二章 · 印下有声[/color]\n%s 纪小砚的文书线索\n%s 旧桥碑文\n%s 三印机关\n%s 封仓原账\n%s 原账归处\n\n" % ["✓" if s.archive_clues.has("clerk") else "◇","✓" if s.archive_clues.has("inscription") else "◇","✓" if s.chapter_two_stage>=2 else "◇","✓" if s.chapter_two_stage>=3 else "◇","✓" if s.chapter_two_stage>=4 else "◇"]
	if s.archive_clues.has("inscription"):body+="口诀：水印先行，驿印居中，仓印收尾。\n"
	body+="南桥："+("已修通" if s.bridge_repaired else "可交木料2份修通")
	return body
