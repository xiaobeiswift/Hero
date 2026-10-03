# Exact original-source lookup evidence

Baseline 606ea478, before capstone model and scene additions. These are source citations, not newly authored capstone testimony.

## scripts/main.gd
571: 	_modal("渡灯录", "H E R O  ·  原创武侠角色扮演", "[color=#d3b276]第一章 · 灯火不问归人[/color]\n\n你带着一封没有署名的旧信，来到水路尽头的青苇渡。\n今夜，渡口的引航灯没有亮。\n\n江湖未必始于名山大派，也可能始于一盏被人摘走的灯。", choices)
626: 			_modal("陆伯","抉择 / 灯火归处","你带回了灯芯和私收渡税的账页。账页上的印章，竟与旧信上的水纹一致。\n\n陆伯沉默良久：‘这账，是交给县衙，还是留给渡口的船家？’\n\n[color=#d3b276]你的选择将留在青苇渡，也会写入往后的江湖。[/color]",[["交给县衙",func(): _finish_quest("秉公")],["交给船家",func(): _finish_quest("守望")]],true)
628: 			_modal("陆伯","灯已归来","渡口的灯又亮了。"+("县衙已收下账页，往后还须有人盯着。" if state.ending=="秉公" else "船家们把账页抄成了三份，谁也不能轻易夺走。")+"\n\n你的旧信指向上游的霜桥城。等一切准备妥当，就顺流去看看吧。")
1010: 				_modal("灯芯重见天光","战斗胜利 / 渡口失灯","蒲横收起刀，把灯芯和一本薄薄的账册交给你。\n\n‘替我带句话给陆伯。那夜他救的船工，是我弟弟。’\n\n账页上的水纹印记，与你带来的旧信一模一样。事情并未止于一场争斗。\n\n[color=#d3b276]获得修为与铜钱。回到村中央，找陆伯交还物证。[/color]",[["收剑，回村",func(): _close_modal(); _autosave()]])
1118: 		_modal("废闸古道", "道路 / 东去三里", "草木遮住了通往旧闸的石阶。先把青苇渡的失灯之事查清，再去追寻旧信上的水纹印记。")
1172: 	_modal("水令留痕", "支线完成 / 废闸疑云", "罗沉交出原本的水令。两份命令只差一个时辰，却足以让整船的粮沉入河底。\n\n你把证据收入旧信。霜桥城的名字，终于有了重量。\n\n"+battle_reward+"[color=#d3b276]"+reward+"[/color]"+("\n先救人留下的是人情；往后的路，会有人记得。" if state.side_choice=="rescue" else "\n先追账册保住的是细节；往后的路，还需更多印证。"),[["收好水令",func(): _close_modal(); _autosave()]],true)

## scripts/frostbridge_story.gd
35: 		body=("驿道旁挂出了原账。粮价和水令第一次被放在同一张纸上核对。" if state.chapter_two_ending=="open_records" else "船工姓名被妥善封存。驿站和船家各持一份账，谁也不能独自改字。")+"\n\n温行舟收好你的旧信：‘霜桥的人会记得，你不只问了一场胜负。’"
67: 	host._modal("印台下的原账","战斗胜利 / 印下有声","韩砚收起兵刃：‘若只问谁的印最大，这仓里永远只有一种答案。’\n\n你翻开原账，发现每次改令前都有一笔提前结算的粮钱。证据已齐，证人却未必愿意被推到众人眼前。\n\n"+reward+"回西岸驿馆，和温行舟作最后的决定。",[["收好原账",host._close_modal]],true)

## scripts/mistwood_story.gd
27:  host._modal("山雨未至，令已先行","第三章 / 听雨辨令","原账最后一行写着‘雾竹坡雨尺已满’，落款却早于那场山雨。\n\n雾竹坡有三处旧刻度，守着它们的秦禾曾经替水司记雨。你沿东北竹坡道上行，想问她一句：一场还没落下的雨，怎样先写进了公文？\n\n建议4级以上。可先回村研习内门藏页；坡上也有免费避雨营地。",[["走入雾竹坡",enter_region],["留在霜桥",host._close_modal]],true)
84:   host._modal("雨前写成的令","听雨辨令 / 原令底稿","底稿的墨比雨痕旧。守令使终于承认，这道水令并非根据雨势写成，而是在等一场能替它作证的雨。\n\n三处读数和霜桥原账拼在一起，指向同一笔提前结算的粮钱。\n\n回秦禾处，先商议如何照应坡上与坡下的人。",[["带回底稿",host._close_modal]],true)

## scripts/heting_story.gd
36: 	var body="底稿抄件上有一处交割号，落在鹤汀埠。\n\n雨令已有人校过，粮还得有人接。你沿山道下行，想看看那笔提前结算的粮钱，究竟压在谁的船上。\n\n港内可以免费歇脚。此行不必添买物资。" if host.state.heting_stage==0 else "沿听雨关东侧下行，仍是鹤汀埠的山道。货单、浮栈与已经议定的安排都会保留。"
75: 	body+="\n当前押车："+_cargo_name()+"\n浮栈："+("西岸" if s.heting_bridge=="west" else "东岸")+"；北步栈仅供步行。\n\n"+("两担封粮已当面复称，实物与提前写成的水损票不符。" if s.heting_delivered.has("sealed") else "封粮尚未复称，不提前断定实物与票据相符。")
87: 	_modal("中埠粮船","交割 / 一车一签","船工把板车推到栈边，两张货签各压在一批货上。\n\n开锅粮：米与干柴，送西岸粥棚。\n对秤封粮：同号船货中的两担，封口尚干，送东岸公秤棚当面复称。\n\n先押哪批，就先让哪一岸办成眼前的事。货不因你多走几步便坏掉。",choices,true)
129: 		var body="“就是这一车。米下锅，柴进灶，今晚先让等在岸边的人有一口热的。”\n\n顾婶核过货签，等你把这一批正式交下。交货得10修为，只记一次。" if is_relief else "两担封口都是干的，船货号也与抄件一致。\n\n“先别替整船下结论。我们当面复称这两担，把封口、担数、到港时刻一并记下。”\n\n不记船工姓名。交货得10修为，只记一次。"
139: 		text="“锅已经洗好，等中埠那批米和干柴。你若先去对秤也成，别把这头忘了。”\n\n棚下有热水与干席，可以免费歇脚。带着车休息，货仍留在车上。" if is_relief else "“柜上已有一张水损票，写的是鹤字三号全船浸损。我只记过票，还没见过粮。”\n\n施衡挪开空秤：“把中埠那两担带来，让票也认认实物。”"
150: 	var text="锅沿升起了白汽，空碗排到棚外。顾婶把实交记号写在货签上。\n\n“有饭不等于人人到得了这里。南泊那批粮，你们还得想想远处的人。”" if id=="heting_relief" else "施衡把两张纸并在秤旁：水损票早于到港，抽称的两担却仍是干粮。\n\n“至少这两担，不能跟着一张票就算坏了。有人先写好了损耗，再等水替他作证。”\n\n他另写复称签，只记货号、担数与时刻，留给船家和秤棚各一份。"
163: 	_modal("孟绫","今夜 / 粮够分，人只一班","“锅开了，假损耗也留下了对照。可南泊还有两担粮，今夜能轮出的埠工只有一班两人。”\n\n[color=#d3b276]短渡分粮[/color]：两人随船，把粮送给不便上岸的几处泊船；公秤棚夜里无人值守，新交割等天亮复核。\n\n[color=#d3b276]守秤留粮[/color]：两人留秤棚，粮作共同存粮，今晚交割有人复称；远泊的人仍须靠岸，或等明日短渡。\n\n“两边都有人肯接。你押最后一车，把同意的安排送到实处。”",[["拟作短渡分粮",_guard(choose.bind("short_ferries",""))],["拟作守秤留粮",_guard(choose.bind("open_scale",""))],["再想一想",host._close_modal]],true)
187: 		_modal("南泊短驳","交割 / 待分粮","这两担待分粮已留好，船工没有催你付钱。\n\n"+("先交妥开锅粮与对秤封粮。" if s.heting_stage==1 else "先到交割牌，与孟绫议定今晚的人手。")+"\n\n粮不会因你离开一会儿便被收走。");return
188: 	_modal("南泊短驳","交割 / 最后一车","船工将两担待分粮放上板车：“去处写明白了，接手的人才知道今晚守哪里。”\n\n草案："+PLAN_NAMES[s.heting_draft]+"\n收货："+_receiver_name(_receiver_for("reserve"))+"\n\n交货前仍可改议。这一批不花你的钱，也不扣行囊材料。",[["押待分粮",_guard(take.bind("reserve"))],["先不装车",host._close_modal]],true)
197: 		_modal("埠灯未尽","第四章完成 / "+PLAN_NAMES[host.state.heting_ending],aftermath(id)+"\n\n白日的复称签仍在两岸，各人认下今夜的差事。那笔提前结算的粮钱，还得沿真正的收货人往下查。\n\n获得100修为、60文。"+companion_line(),[["回访两岸",host._close_modal]],true)
203: 		"heting_scale":return "“复称签没撤。只是夜里这把秤无人看，新来船的交割先搁到天亮。”" if short else "“这两担抽称粮怎样来的，写得清楚。共同存粮怎样出去，也得一样清楚。”"
204: 		_:return "去回牌上记着几处泊船，不记领粮人的私事。近西岸的低灯还亮着，这一班短渡正在照约走。" if short else "短渡安稳系在南泊。两担待分粮已入公秤棚，船上的原位空了；这班船待明日再走。"
242: 	if s.heting_delivered.has("sealed"):text+="\n复称发现：提前写成的全船浸损票，与抽称两担的干封不符。"

## scripts/heting_consignee_story.gd
7: const OBSERVATION_SITES: Dictionary = {"lot_seals": "consignee_warehouse", "removal_order": "heting_dispatch", "southern_counterfoil": "heting_lighter"}
8: const OBSERVATION_NAMES: Dictionary = {"lot_seals": "北仓封粮", "removal_order": "调度牌撤运单", "southern_counterfoil": "南驳船收货联"}
48: 		return "核验南联" if site == "heting_lighter" else "核验新撤运单"
85: 		"southern_counterfoil": "南泊短驳留着本批的收货联，去处是平川粮栈，收货管事署作杜晦。船工指着预结授权一栏，又指了指待返的粮船。\n\n核清这张授权对应哪一批、谁来接粮、船上如何暂存；不能只因有一笔钱便断定整条粮路。"}
110: 	_modal("一批粮的先后", "未损先收 / 哪一处站不住脚", "北仓：本批两篓封记相合，篓内粮干燥。\n调度牌：水损撤运令先签，后才准开仓验粮。\n南联：平川粮栈按预结授权接这一批，杜晦负责收货。\n\n这些记录能支持哪一步判断？答错只解释，不会丢掉已查证据，也不扣资源。", [["未验先撤，理由倒置", _guard(_resolve.bind(Rules.CORRECT_ANSWER, site), site)], ["两篓干粮证明整船无损", _guard(_resolve.bind("dry_means_whole_ship", site), site)], ["必须先补取旧复签", _guard(_resolve.bind("receipt_required", site), site)], ["只凭收货姓氏便可结案", _guard(_resolve.bind("surname", site), site)], ["先留着记录", _guard(_close)]])

## scripts/heting_consignee_rules.gd
16: const OBSERVATIONS: Array[String] = ["lot_seals", "removal_order", "southern_counterfoil"]
79: 	return _answer(true, "同批粮尚未开验，撤运单已按水损收走；南联又写明平川粮栈预结收货。这一批的撤运理由站不住脚。")
157: 		"shen_shore": return "沈青依照岸边照看安排，陪你问接粮船工的暂存需求，并核验南联的本批收货授权。"
158: 		"shen_mobile": return "沈青依照随行照看安排，陪你到待返船边问接粮次序，并核验南联的本批收货授权。"
184: 	if s.consignee_observations.has("southern_counterfoil"):
185: 		lines.append("南联载明平川粮栈为本批收货方，杜晦以该栈收货管事身份按预结授权提粮。")
187: 		lines.append("旧复称副签另作旁证；旧副签只关乎原先两担，不代替本批两篓实查。")
329: 		"shen": return "southern_counterfoil"

## scripts/companion_story.gd
12:   host._modal("唐栖","尺上旧痕 / 一笔未完","工册的末页画着一座会让水的桥。旁边写着：‘桥不是和河争路，是替人借一条路。’\n\n唐栖看了许久，终于放下紧握的短尺。\n\n[color=#d3b276]传给学徒[/color]：把工册抄开，让更多人学会修桥，得布料×2\n[color=#d3b276]留存原稿[/color]：留在驿馆与水令同存，先校正每一处细节，得铁料×2\n两条路都得50修为，也都能邀请唐栖同行。",[["传给学徒",resolve.bind("teach")],["留存原稿",resolve.bind("preserve")],["再想想",host._close_modal]],true)
16:   var memory="学徒们已经在抄那座让水的桥。" if s.tangqi_choice=="teach" else "原稿留在驿馆，每处改笔都另纸注明。"

## scripts/heting_receipt_rules.gd
63: 			return "次晨复核，两担封粮复称时仍干，副签却被人扣住，催着撤下柜边的实交记录。施衡请你取回副签，让已经记下的担数与时刻留得住。"
65: 			return "复称副签已经取回，货号与两担干粮的记号仍清楚。尚须同施衡核对水损票、到港时刻和预结粮钱的记录，不能只凭交锋就替账下结论。"
67: 			return "施衡将副签与旧抄件并放：同一货号的两担粮封口未湿，水损票却早于到港写成；预结粮钱的交割号又与它相合。三处记号接上了先后，假水损再不能抹去这两担实交。副签只记货号、担数与时刻，不添船工姓名；昨夜既定的分粮安排仍照旧。"

Literal issued-ID lookup at 606ea478: exit 1; NO MATCHES
Literal issued-ID lookup at 31ba4221: exit 1; NO MATCHES
