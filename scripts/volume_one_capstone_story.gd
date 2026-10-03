class_name VolumeOneCapstoneStory
extends RefCounted
## Six physical stops. These authored pages are embedded to avoid an untracked
## runtime JSON resource. State owns all progress and authentic battle settlement.
## Every callback binds a page generation, live site, state identity and revision;
## reading is transient, and save retries never replay accepted mutations.
const Rules = preload("res://scripts/volume_one_capstone_rules.gd")
const Combat = preload("res://scripts/volume_one_capstone_combat_data.gd")
const Consignee = preload("res://scripts/heting_consignee_rules.gd")
const SITES: Dictionary = {"heting_dispatch": "heting", "chapter_host": "frostbridge", "chapter_clerk": "frostbridge", "chapter_archive": "frostbridge", "capstone_order_desk": "sluice", "elder": "qingwei"}
const PAGES: Dictionary = {
	"A0": {
		"title": "孟绫 · 交割牌",
		"subtitle": "截令归灯 / 一笔授权未明",
		"body": "“两篓的去处已经记定，不能再让一张新话把粮搬回来。南联上的预结授权，留着霜桥的出令号。”\n\n孟绫将号与时刻抄到引介纸上：“回去问清谁准这张单发出。先见温行舟，再去纪小砚的文书房。”\n\n只带已有记录即可。旧复签仍可另办，不必补做。",
		"stages": [
			0
		],
		"choices": [
			[
				"接下查册引介",
				"begin",
				""
			],
			[
				"重看两篓交接",
				"existing_consignee_record",
				""
			],
			[
				"另谈鹤汀旧事",
				"existing_heting_dispatch",
				""
			],
			[
				"先留在埠内",
				"close",
				""
			]
		]
	},
	"A1": {
		"title": "孟绫 · 交割牌",
		"subtitle": "截令归灯 / 引介已接",
		"body": "“这里办过的交接照旧，后来查出的事另记一页。”\n\n{capstone_goal}\n\n孟绫把水碗推近：“路上可以歇脚。把号对准，比赶路要紧。”",
		"stages": [
			1,
			2,
			3,
			4,
			5
		],
		"choices": [
			[
				"记下去处",
				"close",
				""
			],
			[
				"重看两篓交接",
				"existing_consignee_record",
				""
			],
			[
				"另谈鹤汀旧事",
				"existing_heting_dispatch",
				""
			]
		]
	},
	"A2": {
		"title": "孟绫 · 交割牌",
		"subtitle": "截令归灯 / 处置已有回条",
		"body": "{outcome_short}\n\n“这份新回条单独归档。此前的分粮、两篓交接，都按原来记下的办。”\n\n{home_status}",
		"stages": [
			6,
			7
		],
		"choices": [
			[
				"收好记录",
				"close",
				""
			],
			[
				"重看两篓交接",
				"existing_consignee_record",
				""
			],
			[
				"另谈鹤汀旧事",
				"existing_heting_dispatch",
				""
			]
		]
	},
	"B0": {
		"title": "温行舟 · 驿丞",
		"subtitle": "截令归灯 / 纸匣里的旧信",
		"body": "温行舟认出你带回的引介，停下了添炭的手。\n\n“先坐。你上回留在这里的信，我一直收着。有件事，该在你再问账之前告诉你。”\n\n他取出纸匣，将那封原信放在灯下，又拿来一页没有寄出的留稿。",
		"stages": [
			1
		],
		"choices": [
			[
				"展开原信",
				"B1",
				""
			],
			[
				"借榻调息",
				"existing_wen_free_rest",
				""
			],
			[
				"重看霜桥旧事",
				"existing_frostbridge_record",
				""
			],
			[
				"稍后再谈",
				"close",
				""
			]
		]
	},
	"B1": {
		"title": "没有署名的旧信",
		"subtitle": "截令归灯 / 原信与留稿并看",
		"body": "见此信、愿查证的人：\n先到青苇渡，看看船能否照旧令行路。若纸上与眼前不合，请记下货号、时刻，带到霜桥驿核账。\n信边水纹拓自一份有疑处的旧水令，只供比对，不作通行凭据。是否继续，由你。\n\n原信与留稿的求证句相合，信边也有同样的水纹拓样。",
		"stages": [
			1
		],
		"choices": [
			[
				"听他说明作者",
				"B2",
				""
			],
			[
				"回到纸匣前",
				"B0",
				""
			],
			[
				"暂且离开",
				"close",
				""
			]
		]
	},
	"B2": {
		"title": "温行舟 · 驿丞",
		"subtitle": "截令归灯 / 作者亲认",
		"body": "“信是我写的。”温行舟把留稿压平，终于抬头看你。\n\n“水纹拓自可疑旧令，不是我的私印。我只想请愿意的人去看看，再把眼前的事带来核账。写信时，我不知道鹤汀后来这一批。”\n\n“你上回把信留下，我已经认出来了，却没有说明作者。这件事，我欠你一个交代。”",
		"stages": [
			1
		],
		"choices": [
			[
				"为何当时不说？",
				"B3",
				""
			],
			[
				"这封信要我做到哪里？",
				"B4",
				""
			],
			[
				"再看信中原话",
				"B1",
				""
			],
			[
				"暂且离开",
				"close",
				""
			]
		]
	},
	"B3": {
		"title": "温行舟 · 驿丞",
		"subtitle": "截令归灯 / 没有说出口的事",
		"body": "“我怕有人循着往来，把替人带信的人也拖进去。”\n\n他没有把纸匣合上：“可我可以隐去他们，仍向你承认作者。我没做，却让你担了不知情的风险。那是我的顾虑，也是我的错。”\n\n“带信的人不必写出来。你肯听清说明，并不欠我一句谅解。”",
		"stages": [
			1
		],
		"choices": [
			[
				"听清来意与归还",
				"B4",
				""
			],
			[
				"再看信中原话",
				"B1",
				""
			],
			[
				"暂且离开",
				"close",
				""
			]
		]
	},
	"B4": {
		"title": "温行舟 · 驿丞",
		"subtitle": "截令归灯 / 把原信交还你",
		"body": "“信里只请愿意的人查证，没有替谁定下一辈子的路。你查到的事，也不是我预先安排好的。”\n\n温行舟在作者说明末尾署上自己的名字，将原信推到你手边。\n\n“我署名，只交代这封信。签令的人该担哪一笔，要由留底与实查来说。原信还你；愿不愿再信我，你慢慢想。”",
		"stages": [
			1
		],
		"choices": [
			[
				"收回原信，记下说明",
				"reveal",
				""
			],
			[
				"仍要问当时为何隐瞒",
				"B3",
				""
			],
			[
				"再看信中原话",
				"B1",
				""
			],
			[
				"暂不收下",
				"close",
				""
			]
		]
	},
	"B5": {
		"title": "温行舟 · 驿丞",
		"subtitle": "截令归灯 / 信已有署名",
		"body": "“原信已经交还你，留稿在我这里。”\n\n温行舟添了半盏热水：“你肯回来听这一句，我记着。至于后面的账，我不能拿这封信替谁担保。”\n\n{wen_next}\n\n驿馆仍可免费歇脚。",
		"stages": [
			2,
			3,
			4,
			5,
			6,
			7
		],
		"choices": [
			[
				"重看作者说明",
				"B6",
				""
			],
			[
				"借榻调息",
				"existing_wen_free_rest",
				""
			],
			[
				"重看霜桥旧事",
				"existing_frostbridge_record",
				""
			],
			[
				"告辞",
				"close",
				""
			]
		]
	},
	"B6": {
		"title": "旧信 · 作者说明",
		"subtitle": "截令归灯 / 已核记录",
		"body": "温行舟已取出原信，与留稿对照，承认自己写信，也承认先前隐瞒作者不当。原信已经归还。\n\n信边水纹取自可疑旧令，只供核对；写信时只知疑点，不知后来鹤汀这一批。送信往来不列姓名。\n\n你接受的是这份可核对的说明，是否原谅仍由你判断。",
		"stages": [
			2,
			3,
			4,
			5,
			6,
			7
		],
		"choices": [
			[
				"回到驿馆",
				"B5",
				""
			],
			[
				"收好记录",
				"close",
				""
			]
		]
	},
	"C0": {
		"title": "纪小砚 · 文书学徒",
		"subtitle": "截令归灯 / 已发签令留底册",
		"body": "“原账记粮钱怎样提前，留底记谁准那道令出去。南联的霜签乙09，让我们找到了对应页。”\n\n纪小砚摆开留底和分存抄件：“每笔看编号、时刻、核准栏。共用的水纹，不能替人署名。”\n\n{record_privacy}\n{record_source}",
		"stages": [
			2
		],
		"choices": [
			[
				"展开已发留底",
				"C1",
				""
			],
			[
				"先收好记录",
				"close",
				""
			]
		]
	},
	"C1": {
		"title": "已发留底 · 甲栏",
		"subtitle": "截令归灯 / 改时与列损",
		"body": "纪小砚按南联授权号调出留底。{record_source}\n\n霜签甲17 · 旧闸改时\n留底并存原刻与改刻，相差一时辰；梁缜核准改时并交发。罗沉交出的原令与所得改令，对上各自编号和时刻。\n\n霜签甲18 · 雾竹雨录列损\n梁缜核准援引“雨尺七线”列损，并交发；实拓只到第三线。留底所指雨次、尺位，与雾竹底稿及霜桥预结条目相同。",
		"stages": [
			2
		],
		"choices": [
			[
				"继续核两次鹤汀授权",
				"C2",
				""
			],
			[
				"回到留底册",
				"C0",
				""
			],
			[
				"先收好记录",
				"close",
				""
			]
		]
	},
	"C2": {
		"title": "已发留底 · 乙栏",
		"subtitle": "截令归灯 / 两担与两篓分记",
		"body": "霜签乙06 · 旧两担所在船的按损票\n梁缜核准援引甲18雨录按损交发；票早于到港，当面复称的两担却干燥。不能据两担替全船作保。\n\n霜签乙09 · 北仓新两篓\n梁缜核准预结收货并交发。留底批注“先按水损撤运，实查后补”，与撤运单、平川粮栈南联同号；仓门验放在其后。\n\n{old_two_baskets}",
		"stages": [
			2
		],
		"choices": [
			[
				"核看经办与分存",
				"C3",
				""
			],
			[
				"回到留底册",
				"C0",
				""
			],
			[
				"先收好记录",
				"close",
				""
			]
		]
	},
	"C3": {
		"title": "纪小砚 · 文书学徒",
		"subtitle": "截令归灯 / 署名所担的动作",
		"body": "“经办登记列得清：甲17、甲18、乙06、乙09的核准人为梁缜，职任签令主事；这四笔均记已交发。”\n\n旧闸受令本、雾竹留稿和鹤汀单联，分别对上各自编号与先后。预结条目同号，旧两担与新两篓仍分列。\n\n这能核清这些核准动作；没有雇刀付款链，也未核到全部旧案。{receipt_note}\n\n{record_privacy}",
		"stages": [
			2
		],
		"choices": [
			[
				"自己核清，作出判断",
				"method:solo:C6",
				""
			],
			[
				"选择同行核对方法",
				"C4",
				""
			],
			[
				"再看甲栏",
				"C1",
				""
			],
			[
				"再看乙栏",
				"C2",
				""
			],
			[
				"先收好记录",
				"close",
				""
			]
		]
	},
	"C4": {
		"title": "已发留底 · 核对方法",
		"subtitle": "截令归灯 / 自行核对也足够",
		"body": "把已发册、分存抄件与实查记录逐项并看，再判断署名者须对什么负责。\n\n可自己完成，不需材料、额外本领或招募同伴。同行方法只在本人确有相关经历、实际在队且仍站立时可用。",
		"stages": [
			2
		],
		"choices": [
			[
				"自己逐项核对",
				"method:solo:C5",
				""
			],
			[
				"请唐栖逐项复读",
				"method:tang_teach:C5",
				"method_available(tang_teach)"
			],
			[
				"请唐栖另纸标注",
				"method:tang_preserve:C5",
				"method_available(tang_preserve)"
			],
			[
				"请秦禾并看时刻",
				"method:qin_timing:C5",
				"method_available(qin_timing)"
			],
			[
				"回到留底册",
				"C0",
				""
			]
		]
	},
	"C5": {
		"title": "已发留底 · 对照完成",
		"subtitle": "截令归灯 / 方法不替代证据",
		"body": "{evidence_method_line}\n\n甲17核准改时，甲18核准雨录列损，乙06核准按损票，乙09核准预结收货并交发。分存抄件与实查反证均按同号相校。\n\n旧两担、新两篓分记。现在判断，只限这些查实的核准与交发。",
		"stages": [
			2
		],
		"choices": [
			[
				"作出责任判断",
				"C6",
				""
			],
			[
				"重选核对方法",
				"C4",
				""
			],
			[
				"回到留底册",
				"C0",
				""
			],
			[
				"稍后再议",
				"close",
				""
			]
		]
	},
	"C6": {
		"title": "纪小砚 · 文书学徒",
		"subtitle": "截令归灯 / 能认定哪一步",
		"body": "已发留底把具体核准与交发记在梁缜名下，分存抄件能对应，实查又推翻了先写下的依据。\n\n这时能够认定什么？\n\n答错只解释，不损资源，不丢证据。未发令簿尚未取得，交锋也还没有发生。",
		"stages": [
			2
		],
		"choices": [
			[
				"梁缜须对这组核准交发负责",
				"evidence:authorized_issued_chain",
				""
			],
			[
				"同水纹的令都是梁缜写的",
				"evidence:watermark_proves_author",
				""
			],
			[
				"两篓干粮证明全船无损",
				"evidence:dry_means_whole_ship",
				""
			],
			[
				"先赢过他，才能认定责任",
				"evidence:victory_proves_guilt",
				""
			],
			[
				"先留着记录",
				"close",
				""
			]
		]
	},
	"C7": {
		"title": "再核一步",
		"subtitle": "截令归灯 / 责任有边界",
		"body": "{evidence_error}\n\n已看过的记录都在。不必另找物资，也不必靠交锋补证。",
		"stages": [
			2
		],
		"choices": [
			[
				"重新判断",
				"C6",
				""
			],
			[
				"回到留底册",
				"C0",
				""
			],
			[
				"先收好记录",
				"close",
				""
			]
		]
	},
	"C8": {
		"title": "纪小砚 · 文书学徒",
		"subtitle": "截令归灯 / 这组授权已核定",
		"body": "“梁缜·签令主事须对甲17、甲18、乙06、乙09的核准与交发负责。各笔依据与抄件一并留存，不只记一句‘上游所为’。”\n\n{clerk_next}\n\n{record_privacy}",
		"stages": [
			3,
			4,
			5,
			6,
			7
		],
		"choices": [
			[
				"重看已核责任",
				"C9",
				""
			],
			[
				"记下后续去处",
				"close",
				""
			],
			[
				"重看三印旧事",
				"existing_clerk_record",
				""
			]
		]
	},
	"C9": {
		"title": "已发留底 · 核定记录",
		"subtitle": "截令归灯 / 战前证据仍在",
		"body": "已核四笔：甲17改时、甲18雨录列损、乙06旧船按损票、乙09新两篓预结收货。核准栏与经办登记、异地分存抄件相合。\n\n责任限于这组动作。旧闸实令、三处雨痕、鹤汀当面核验仍是反证；旧两担与新两篓没有并为一批。\n\n这份已发册在交锋前就已核定，与本班四号未发簿是两件文书；未发簿尚未取得时，不能用它替此前定责作证。",
		"stages": [
			3,
			4,
			5,
			6,
			7
		],
		"choices": [
			[
				"回到文书房",
				"C8",
				""
			],
			[
				"收好记录",
				"close",
				""
			]
		]
	},
	"D0": {
		"title": "梁缜 · 签令主事",
		"subtitle": "截令归灯 / 封仓印台",
		"body": "梁缜把未发簿齐边压在案上，先看你的引介，再看剑。\n\n“甲17改时、甲18列损、乙06按损、乙09收货，核准栏都已对上。”你将核定抄件放下。\n\n“账上不能有空栏，船期不能有空班。”他按住另一册，“先依令交发，实查回来再补。若每一处都等，拖下的整班又记谁头上？”\n\n他横刃拦住本班四号未发簿。交锋只为保住这册新令，不能替已核责任作证。",
		"stages": [
			3
		],
		"choices": [
			[
				"查看应战准备",
				"D2",
				""
			],
			[
				"问清为何保住未发簿",
				"D1",
				""
			],
			[
				"重看已核责任",
				"D4",
				""
			],
			[
				"先行整备",
				"close",
				""
			]
		]
	},
	"D1": {
		"title": "梁缜 · 签令主事",
		"subtitle": "截令归灯 / 保住本班未发簿",
		"body": "“空着的核验，不能拿假读数填上。”\n\n梁缜抽刃拦住案前：“你要停这一册，就得过我这道交发口。”\n\n案上是另一件本班未发令簿，只有新待发001—004。旧韩砚原账早已取出，不在这里重封。\n\n这一战只为保住未发簿和通路。先前核定的责任，不由胜负作证。",
		"stages": [
			3
		],
		"choices": [
			[
				"查看应战准备",
				"D2",
				""
			],
			[
				"重看已核责任",
				"D4",
				""
			],
			[
				"先行整备",
				"close",
				""
			]
		]
	},
	"D2": {
		"title": "梁缜 · 签令主事",
		"subtitle": "截令归灯 / 实战准备",
		"body": "当前气血{hp}/{max_hp}，真气{qi}/{max_qi}，回春散{medicine}份。\n\n{combat_stats}\n\n出招用药照实消耗。退避不另扣钱，已用资源不返；败退最多遗落8文，回霜桥驿馆外恢复。驿馆可免费调息。\n\n先存妥才开战。胜利只取未发簿，修为、铜钱均不在这里发放。",
		"stages": [
			3
		],
		"choices": [
			[
				"保存后阻止交发",
				"start_real_capstone_battle",
				""
			],
			[
				"看招式与退避规则",
				"D3",
				""
			],
			[
				"先去免费调息",
				"close",
				""
			],
			[
				"暂且离开",
				"close",
				""
			]
		]
	},
	"D3": {
		"title": "印台交锋 · 看清招式",
		"subtitle": "截令归灯 / 统一战斗规则",
		"body": "{combat_phases}\n\n实际在队且站立者逐轮自动普攻，可另排武学、内功、轻功。只有梁缜一人，不按队伍人数加敌。\n\n退避保留已用资源。败退按实际结果扣钱并恢复气血，真气至少留2点；用药不返。回到驿馆后仍可明确选择免费调息。",
		"stages": [
			3
		],
		"choices": [
			[
				"回到应战准备",
				"D2",
				""
			],
			[
				"先行整备",
				"close",
				""
			]
		]
	},
	"D4": {
		"title": "战前核定 · 责任抄件",
		"subtitle": "截令归灯 / 已发册与未发簿分开",
		"body": "纪小砚已将甲17改时、甲18列损、乙06按损票、乙09预结收货逐笔对上梁缜的核准与交发。\n\n实查反证与独立抄件均已留存。梁缜不肯交出未发簿，不会让这些证据失效；你退开或败退，也不会丢失这项核定。\n\n印台这一册尚未取得，更不能倒过来充作此前定责的依据。",
		"stages": [
			3
		],
		"choices": [
			[
				"回到案前",
				"D1",
				""
			],
			[
				"先行整备",
				"close",
				""
			]
		]
	},
	"D5": {
		"title": "未发簿留在案上",
		"subtitle": "截令归灯 / 印台交锋胜利",
		"body": "梁缜收刃退开，手仍停在齐整的簿角。\n\n“整班的回报，总得有人交。”\n\n你把空着的核验栏留在原处：“那就照实写，别替它填满。”\n\n取得本班未发令簿，内有新待发001—004。四号尚未分类或处置；没有发终章奖励。可在此先看，也可直接去旧闸守闸桌。",
		"stages": [
			4
		],
		"choices": [
			[
				"先看四号依据",
				"E0",
				""
			],
			[
				"记下守闸桌去处",
				"close",
				""
			]
		]
	},
	"D6": {
		"title": "印台暂别",
		"subtitle": "截令归灯 / 已按退避结算",
		"body": "你从印台退开。已经出招、用药照实保留，退避不另扣钱。\n\n未发簿尚未取得，已发册的责任核定仍在。没有胜利奖励，也没有处置任何新令。\n\n霜桥驿馆可免费调息，备妥后再来。",
		"stages": [
			3
		],
		"choices": [
			[
				"先回霜桥行走",
				"close",
				""
			]
		]
	},
	"D7": {
		"title": "驿馆外缓息",
		"subtitle": "截令归灯 / 已按败退结算",
		"body": "附近行旅将你扶到霜桥驿馆外。本次遗落{actual_coin_loss}文，气血恢复，真气至少留2点；已经用掉的药不返还。\n\n未发簿尚未取得，已核责任没有改变。没有胜利奖励，也没有处置任何新令。\n\n温行舟仍在驿馆，可去免费调息。",
		"stages": [
			3
		],
		"choices": [
			[
				"站稳，再作打算",
				"close",
				""
			]
		]
	},
	"E0": {
		"title": "本班未发令簿",
		"subtitle": "截令归灯 / 四号尚待分类",
		"body": "本班新待发001—004，尚未执行。\n\n001复用甲18同雨次、同尺位的七线记录，实拓却只三线；002援引乙09那次“已经验放”，记录却是先按损签发、后才开验。\n\n003、004是另两个独立事项，查据不足。不能同册全判假，也不能替后两号判无误。\n\n看完仍须明确接受分类。离开、休整不会自动交发。",
		"stages": [
			4
		],
		"choices": [
			[
				"自行核定四号分类",
				"method:solo:E6",
				""
			],
			[
				"逐号细看依据",
				"E1",
				""
			],
			[
				"选择同行核对方法",
				"E4",
				""
			],
			[
				"先收好未发簿",
				"close",
				""
			]
		]
	},
	"E1": {
		"title": "新待发令 · 001",
		"subtitle": "截令归灯 / 引用同一雨尺记录",
		"body": "001拟据霜签甲18所引的同一雨次、同一尺位“七线”读数，批准一项新撤运。\n\n此前实拓只到第三线，上方仍有干灰。这里重用的正是那一条已被反证的读数，不是另一场尚未查过的雨。\n\n可撤的是这道失实依据所生的新令。新货日后是否遇水，仍不能由旧粮替它作答。\n\n{row001_status}",
		"stages": [
			4,
			5,
			6,
			7
		],
		"choices": [
			[
				"看002 · 验放先后",
				"E2",
				""
			],
			[
				"回到四号目录",
				"current_order_index",
				""
			],
			[
				"先收好记录",
				"close",
				""
			]
		]
	},
	"E2": {
		"title": "新待发令 · 002",
		"subtitle": "截令归灯 / 引用已被推翻的验放",
		"body": "002把霜签乙09对应的那次“已经验放、确认水损”当作成据，拟交发另一项按损收货授权。\n\n此前撤运单、仓门刻线和南联已证明：先按水损签发，后才准开仓验粮。002复用的正是这次先后，不能把“实查后补”写成“已经实查”。\n\n这是新令，不是已经划止的杜晦旧撤运单。\n\n{row002_status}",
		"stages": [
			4,
			5,
			6,
			7
		],
		"choices": [
			[
				"看003、004 · 待核事项",
				"E3",
				""
			],
			[
				"回到四号目录",
				"current_order_index",
				""
			],
			[
				"先收好记录",
				"close",
				""
			]
		]
	},
	"E3": {
		"title": "新待发令 · 003与004",
		"subtitle": "截令归灯 / 各有编号，尚未核清",
		"body": "003 · 另一编号的例行交发事项\n004 · 同班另一编号的例行交发事项\n\n本次材料尚未核清这两号的依据，也未证明它们无误。不能只因同册、同经办便按001与002一并判假。\n\n留所复核会让它们多等一轮；循例继续仍须核验、签收，不是立刻放行。\n\n{row003004_status}",
		"stages": [
			4,
			5,
			6,
			7
		],
		"choices": [
			[
				"回到四号目录",
				"current_order_index",
				""
			],
			[
				"先收好记录",
				"close",
				""
			]
		]
	},
	"E4": {
		"title": "四号未发令 · 核对方法",
		"subtitle": "截令归灯 / 分类前再看后果",
		"body": "001、002须按引用的同一事实核对；003、004查据不足。还要说清“留所等候”和“循例续核”各会改变什么。\n\n独自核对足够。沈青若确有相应照护经历、实际在队且仍站立，可帮着列出交接后果。",
		"stages": [
			4
		],
		"choices": [
			[
				"自己列明依据与后果",
				"method:solo:E5",
				""
			],
			[
				"请沈青看留岸等候",
				"method:shen_shore:E5",
				"method_available(shen_shore)"
			],
			[
				"请沈青看往返交接",
				"method:shen_mobile:E5",
				"method_available(shen_mobile)"
			],
			[
				"回到四号目录",
				"E0",
				""
			]
		]
	},
	"E5": {
		"title": "四号未发令 · 并看后果",
		"subtitle": "截令归灯 / 不替未知作结",
		"body": "{classification_method_line}\n\n001重用已证伪的同一雨尺记录；002重用已被推翻的验放先后。003、004各自仍须核查。\n\n分类只是记清依据，四号此时仍全待处置；不会自动替你选定草案。",
		"stages": [
			4
		],
		"choices": [
			[
				"作出四号分类",
				"E6",
				""
			],
			[
				"重选核对方法",
				"E4",
				""
			],
			[
				"回到四号目录",
				"E0",
				""
			],
			[
				"稍后再议",
				"close",
				""
			]
		]
	},
	"E6": {
		"title": "四号该怎样分记",
		"subtitle": "截令归灯 / 明确接受分类",
		"body": "001、002各引用了已经被实查推翻的同一条依据。003、004是独立编号，本次查据不足。\n\n怎样把四号分类记入记录？\n\n答错只解释。正确接受分类后，仍须另拟草案，再到守闸桌确认执行。",
		"stages": [
			4
		],
		"choices": [
			[
				"001、002证伪；003、004待核",
				"classify:CORRECT_PARTITION",
				""
			],
			[
				"同册四号都算假令",
				"classify:all_false",
				""
			],
			[
				"前两号假，后两号已无误",
				"classify:last_two_proven_true",
				""
			],
			[
				"先不记定",
				"close",
				""
			]
		]
	},
	"E7": {
		"title": "四号还须分清",
		"subtitle": "截令归灯 / 分类未接受",
		"body": "001、002的同一依据已有反证；003、004尚未核清。查据不足，既不能判假，也不能判成无误。\n\n四号仍待分类，没有丢失记录或扣除资源。",
		"stages": [
			4
		],
		"choices": [
			[
				"重新分类",
				"E6",
				""
			],
			[
				"回到四号目录",
				"E0",
				""
			],
			[
				"先收好记录",
				"close",
				""
			]
		]
	},
	"E8": {
		"title": "四号分类已记",
		"subtitle": "截令归灯 / 尚未处置",
		"body": "001、002：依据已证伪。\n003、004：尚未核清。\n\n分类已经记下，四号仍全部待处置。可以先拟草案，也可以离开；关闭或取消草案不会抹去分类。\n\n最终只在旧闸守闸所南侧的守闸桌确认。没有倒计时。",
		"stages": [
			5
		],
		"choices": [
			[
				"商议处置草案",
				"F0",
				""
			],
			[
				"重看逐号依据",
				"R0",
				""
			],
			[
				"先不拟稿",
				"close",
				""
			]
		]
	},
	"F0": {
		"title": "这一班怎样交接",
		"subtitle": "截令归灯 / 可更改的草案",
		"body": "两案都撤销001、002。差别只在未核清的003、004。\n\n整班暂缓：两号留所复核，暂不交发；未证错事项也多等一轮。\n逐号撤销：两号循既有核验、签收程序继续；本次不替它们保证无误。\n\n只限本班四号。此处拟稿不执行，回青苇确认归灯后，两案均得160修为、80铜钱。",
		"stages": [
			5
		],
		"choices": [
			[
				"拟作整班暂缓 · 撤2留2",
				"plan:pause_batch",
				""
			],
			[
				"拟作逐号撤销 · 撤2循例2",
				"plan:cancel_proven",
				""
			],
			[
				"重看逐号依据",
				"R0",
				""
			],
			[
				"暂不拟定",
				"close",
				""
			]
		]
	},
	"F1": {
		"title": "截令归灯 · 当前草案",
		"subtitle": "本班四号 / 尚未执行",
		"body": "{draft_description}\n\n这仍是草案，四号尚未处置。可改案、撤下草案或稍后再来；已接受的分类会保留。\n\n{planning_next}",
		"stages": [
			5
		],
		"choices": [
			[
				"查看最后确认",
				"selected_confirmation",
				"at_sluice_desk"
			],
			[
				"记下守闸桌去处",
				"close",
				"at_archive"
			],
			[
				"更改草案",
				"F0",
				""
			],
			[
				"撤下草案",
				"plan:",
				""
			],
			[
				"重看逐号依据",
				"R0",
				""
			],
			[
				"先离开",
				"close",
				""
			]
		]
	},
	"F2": {
		"title": "草案已撤下",
		"subtitle": "截令归灯 / 分类仍在",
		"body": "已撤下草案，四号仍全部待处置。\n\n001、002依据已证伪，003、004尚未核清；这项分类不会重做。\n\n不需再打印台一战，也不需重新取簿。想定之后，可在这里重新拟稿。",
		"stages": [
			5
		],
		"choices": [
			[
				"重新商议草案",
				"F0",
				""
			],
			[
				"重看逐号依据",
				"R0",
				""
			],
			[
				"先离开",
				"close",
				""
			]
		]
	},
	"G0": {
		"title": "守闸所 · 待发令案",
		"subtitle": "截令归灯 / 在此明确落定",
		"body": "轮值把空白回条摊开：“文书房核出的编号在这里。撤销的写依据，留验的写承接，循例的仍按原程序核签。”\n\n眼前只接本班001—004，不改旧闸已开的水，也不改鹤汀已交的粮。\n\n{desk_current}\n\n看页、拟稿或关上对话，都不会替你执行。",
		"stages": [
			4,
			5
		],
		"choices": [
			[
				"逐号核定分类",
				"E0",
				"stage4"
			],
			[
				"商议处置草案",
				"F0",
				"stage5_empty_draft"
			],
			[
				"查看当前草案",
				"F1",
				"stage5_has_draft"
			],
			[
				"重看逐号依据",
				"R0",
				"stage5"
			],
			[
				"先离开",
				"close",
				""
			]
		]
	},
	"G1": {
		"title": "确认 · 整班暂缓",
		"subtitle": "截令归灯 / 撤销2号，留验2号",
		"body": "001、002：依据已证伪，撤销。\n003、004：尚未核清，留所复核，暂不交发；未证错事项也多等一轮。\n\n文书房与守闸轮值逐号登记并承接后续核查，只限本班四号。旧令、旧粮、此前轮值不改。\n\n确认后本批不能改案。此处不发奖励；回青苇向陆伯确认归灯，才得一次160修为、80铜钱。",
		"stages": [
			5
		],
		"choices": [
			[
				"返回核对",
				"F1",
				""
			],
			[
				"确认执行 · 撤2留2",
				"confirm:pause_batch",
				""
			],
			[
				"更改草案",
				"F0",
				""
			],
			[
				"先不确认",
				"close",
				""
			]
		]
	},
	"G2": {
		"title": "确认 · 逐号撤销",
		"subtitle": "截令归灯 / 撤销2号，循例2号",
		"body": "001、002：依据已证伪，撤销。\n003、004：尚未核清，循既有核验、签收程序继续交发；不等于立即放行或认定无误。\n\n文书房与守闸轮值逐号登记并承接，只限本班四号。旧令、旧粮、此前轮值不改。\n\n确认后本批不能改案。此处不发奖励；回青苇向陆伯确认归灯，才得一次160修为、80铜钱。",
		"stages": [
			5
		],
		"choices": [
			[
				"返回核对",
				"F1",
				""
			],
			[
				"确认执行 · 撤2循例2",
				"confirm:cancel_proven",
				""
			],
			[
				"更改草案",
				"F0",
				""
			],
			[
				"先不确认",
				"close",
				""
			]
		]
	},
	"G3": {
		"title": "守闸所 · 登记已成",
		"subtitle": "截令归灯 / 整班暂缓",
		"body": "001、002已记撤销，依据与原页一并存留。\n003、004已交守闸所留待复核，暂不交发；未证错事项也多等一轮。\n\n文书房与守闸轮值分别留存编号回条，没有焚毁证据，也没有重新扣回旧粮。\n\n{home_status}",
		"stages": [
			6,
			7
		],
		"choices": [
			[
				"收好处置回条",
				"close",
				""
			],
			[
				"重看逐号依据",
				"R0",
				""
			]
		]
	},
	"G4": {
		"title": "守闸所 · 登记已成",
		"subtitle": "截令归灯 / 逐号撤销",
		"body": "001、002已记撤销，依据与原页一并存留。\n003、004继续循既有核验、签收程序交发，当前仍未由本次调查核清。\n\n文书房与守闸轮值分别留存编号回条。继续办理不等于已经放行，也不替后两号证明无误。\n\n{home_status}",
		"stages": [
			6,
			7
		],
		"choices": [
			[
				"收好处置回条",
				"close",
				""
			],
			[
				"重看逐号依据",
				"R0",
				""
			]
		]
	},
	"G5": {
		"title": "罗沉 · 旧闸守门人",
		"subtitle": "废闸余事 / 开闸责任仍在",
		"body": "“上游哪一笔是谁核准，如今查清了一组。我照那道改令开过闸，这件事不会被上游的名字抹去。”\n\n罗沉望向南侧的令案：“新簿要逐号记。旧事也照原样留下，不能因为又有了一张回条，就当从未发生。”",
		"stages": [
			3,
			4,
			5,
			6,
			7
		],
		"choices": [
			[
				"继续行走",
				"close",
				""
			],
			[
				"重看废闸旧事",
				"existing_sluice_aftermath",
				""
			]
		]
	},
	"H0": {
		"title": "陆伯",
		"subtitle": "截令归灯 / 回到灯下",
		"body": "灯早已重新点亮。陆伯看见你，把灯下的凳子往外挪了挪。\n\n“回来就好。这一趟查到哪一笔，哪一笔还没查清，都坐下说。”\n\n{outcome_short}\n\n交回处置回条、确认归灯后，第一卷完成。终章160修为、80铜钱只结算一次，两种安排同额；沿用既有上限与升阶规则。",
		"stages": [
			6
		],
		"choices": [
			[
				"先看回条",
				"H1",
				""
			],
			[
				"交回回条，确认归灯",
				"homecoming",
				""
			],
			[
				"先不结卷",
				"close",
				""
			]
		]
	},
	"H1": {
		"title": "陆伯 · 灯下回条",
		"subtitle": "截令归灯 / 看清再交",
		"body": "{outcome_short}\n\n旧信由温行舟写作并说明；这组已发授权由梁缜核准并交发，已逐笔留证。未查过的事，仍未查过。\n\n{home_archive}\n{record_privacy}",
		"stages": [
			6,
			7
		],
		"choices": [
			[
				"回到灯下",
				"current_home_page",
				""
			],
			[
				"先收好记录",
				"close",
				""
			]
		]
	},
	"H2": {
		"title": "灯下有回音",
		"subtitle": "第一卷终章 · 截令归灯 完",
		"body": "陆伯把回条展平：“灯是早先亮的。如今这一程，也有了能说清的首尾。”\n\n匿名旧信的来意已说明，这组签令责任已按号留证，本班四号已照你的确认交接。\n\n{actual_reward_summary}\n\n第一卷已完成，江湖仍可自由行走。未办完的复签、同行机缘、修桥与研艺都还在，不会因结卷自动完成。",
		"stages": [
			7
		],
		"choices": [
			[
				"继续行走",
				"close",
				""
			],
			[
				"回望这一程",
				"H4",
				""
			],
			[
				"重看灯下回条",
				"H1",
				""
			]
		]
	},
	"H3": {
		"title": "陆伯",
		"subtitle": "青苇余响 / 灯下可歇",
		"body": "“回条已经收好。河上还有后来事，你也不必每次都替它下个总断。”\n\n{outcome_short}\n\n这一卷的回报已结算，重看不再发奖。灯仍亮着，尚未办完的事可以慢慢接着办。",
		"stages": [
			7
		],
		"choices": [
			[
				"回望这一程",
				"H4",
				""
			],
			[
				"重看灯下回条",
				"H1",
				""
			],
			[
				"继续行走",
				"close",
				""
			]
		]
	},
	"H4": {
		"title": "这一程 · 旧选择仍在",
		"subtitle": "第一卷回望 / 不改已经走过的路",
		"body": "旧选择各有实际去处，新回条不会把它们重写。\n\n可以分段回看。这里不重开奖励，也不把同行人未完成的心事写作圆满。",
		"stages": [
			7
		],
		"choices": [
			[
				"青苇与废闸",
				"H5",
				""
			],
			[
				"霜桥与雾竹",
				"H6",
				""
			],
			[
				"鹤汀与两篓",
				"H7",
				""
			],
			[
				"回到灯下",
				"H3",
				""
			]
		]
	},
	"H5": {
		"title": "这一程 · 青苇与废闸",
		"subtitle": "第一卷回望 / 灯与先后",
		"body": "{home_archive}\n\n{side_memory}\n\n旧闸的证言与账页后来都查到了。先后留下的得失仍在，不会因此多出一份只有某条路才有的终章证据。",
		"stages": [
			7
		],
		"choices": [
			[
				"再看霜桥与雾竹",
				"H6",
				""
			],
			[
				"回到回望目录",
				"H4",
				""
			],
			[
				"继续行走",
				"close",
				""
			]
		]
	},
	"H6": {
		"title": "这一程 · 霜桥与雾竹",
		"subtitle": "第一卷回望 / 账与水势",
		"body": "{record_privacy}\n\n{mist_memory}\n\n{mist_access_memory}",
		"stages": [
			7
		],
		"choices": [
			[
				"再看鹤汀与两篓",
				"H7",
				""
			],
			[
				"回到回望目录",
				"H4",
				""
			],
			[
				"继续行走",
				"close",
				""
			]
		]
	},
	"H7": {
		"title": "这一程 · 鹤汀实交",
		"subtitle": "第一卷回望 / 各批分记",
		"body": "{harbor_memory}\n\n{old_two_baskets}\n\n{receipt_memory}\n\n三批旧交割、北仓两篓、本班四号新令分别留记，已经交下的粮不会重领。",
		"stages": [
			7
		],
		"choices": [
			[
				"回到回望目录",
				"H4",
				""
			],
			[
				"回到灯下",
				"H3",
				""
			],
			[
				"继续行走",
				"close",
				""
			]
		]
	},
	"R0": {
		"title": "四号未发令 · 逐号记录",
		"subtitle": "截令归灯 / 依据与去向",
		"body": "{orders_status}\n\n001、002同属“依据已证伪”；003、004仍属“尚未核清”。去向与依据分开显示，不能把继续办理写成已经验明。",
		"stages": [
			5,
			6,
			7
		],
		"choices": [
			[
				"看001 · 同一雨尺",
				"E1",
				""
			],
			[
				"看002 · 验放先后",
				"E2",
				""
			],
			[
				"看003、004 · 待核事项",
				"E3",
				""
			],
			[
				"回到案前",
				"current_planning_hub",
				""
			],
			[
				"收好记录",
				"close",
				""
			]
		]
	},
	"R1": {
		"title": "封仓印台 · 余页",
		"subtitle": "截令归灯 / 未发簿已得",
		"body": "梁缜已退开，旧韩砚原账也没有重封。印台不会再为这一册开战。\n\n{archive_current}\n\n查清过的签令责任，仍由战前的已发留底与实查反证支撑。",
		"stages": [
			4,
			5,
			6,
			7
		],
		"choices": [
			[
				"逐号核定分类",
				"E0",
				"stage4"
			],
			[
				"商议处置草案",
				"F0",
				"stage5_empty_draft"
			],
			[
				"查看当前草案",
				"F1",
				"stage5_has_draft"
			],
			[
				"重看逐号记录",
				"R0",
				"stage6_or7"
			],
			[
				"继续行走",
				"close",
				""
			]
		]
	},
	"S0": {
		"title": "截令归灯 · 尚未存妥",
		"subtitle": "保存未成功 / 可安全重试",
		"body": "本次已接受的进度与已结算资源，仍留在当前旅程。保存尚未成功。\n\n重试只补存当前结果，不重复核定、交接或发奖，也不会自动开战。\n\n离开对话不丢弃内存进度；退出游戏前请先存妥。",
		"stages": "any_accepted_stage",
		"choices": [
			[
				"重试保存",
				"retry",
				""
			],
			[
				"先回场中",
				"close",
				""
			]
		]
	},
	"S1": {
		"title": "印台交锋 · 尚未开始",
		"subtitle": "保存未成功 / 资源尚未消耗",
		"body": "应战前保存未成功，交锋尚未开始，也未产生战斗消耗。\n\n重试只保存当前旅程，成功后回到应战准备；仍须明确选择“保存后阻止交发”才开战。",
		"stages": [
			3
		],
		"choices": [
			[
				"重试保存",
				"retry",
				""
			],
			[
				"先行整备",
				"close",
				""
			]
		]
	}
}
const VARIANTS: Dictionary = {
	"record_privacy": {
		"protect_witness": "姓名封页仍不拆，只以货号、雨次和时刻抄件互校；证人与送信往来继续保密。",
		"open_records": "沿原先公示账页核号与时刻；此前公开不改写，这次不再添送信人的姓名。"
	},
	"record_source": {
		"秉公": "本次并看县衙已存的抄件。",
		"守望": "本次并看船家分存、托纪小砚收好的抄件。"
	},
	"old_two_baskets": {
		"hold_for_inspection": "鹤汀两篓完整封样仍在东岸共同留验，本次只用当地记录，不把实物搬来。",
		"return_to_owner": "鹤汀两篓已返还原主；本次用当时实查、划止与返还记录，不复原封样，也不重新扣粮。"
	},
	"receipt_note": {
		"receipt_stage==3": "旧复签仅为原先两担的旁证。",
		"receipt_stage<3": "旧复签尚未核定，不影响已有实查。"
	},
	"receipt_memory": {
		"receipt_stage==3": "旧两担的副签已与抄件并看，只作那两担的旁证。",
		"receipt_stage==0": "旧两担复签仍可到公秤另问，不影响本卷完成。",
		"receipt_stage==1": "旧两担的复签交锋尚可继续，本卷没有代你完成。",
		"receipt_stage==2": "旧两担副签已经取得，仍待到公秤与抄件核签。"
	},
	"home_archive": {
		"秉公": "编号回条与当初县衙收账回执一并留档，仍须有人核看后续怎样办理。",
		"守望": "船家照原先办法分存编号与时刻抄件，不抄送信往来的姓名。"
	},
	"harbor_memory": {
		"short_ferries": "那夜两名埠工随短渡送粮，公秤夜里无人值守；这次移交时刻取自短渡轮值记录。",
		"open_scale": "那夜两名埠工留在公秤，远泊的人仍须靠岸或等后续短渡；这次移交时刻取自公秤轮值记录。"
	},
	"side_memory": {
		"rescue": "废闸那一程，你先解开困住船工的断缆，再追账页。救人的先后仍记在那一页。",
		"pursuit": "废闸那一程，你先截下账页，再折回救船工；他曾多等的那一阵，也没有被账页盖过去。"
	},
	"mist_memory": {
		"release_water": "雾竹坡先通缓水渠，替近坡田地争取时辰；秦禾随后传去了更正的雨令。",
		"warn_ferries": "雾竹坡先鸣渡船钟，让下游船家撤离；最后一船靠岸，守坡人才缓开石闸。"
	},
	"mist_access_memory": {
		"duel": "当时以较量取得勘量许可。那一场已经过去，不需重打。",
		"repair": "当时修好警亭后取得勘量许可。材料已经用在实处，不需再交。",
		"records": "当时以公示原账说明来意，取得勘量许可。既有公开的历史仍保留。"
	},
	"evidence_method_line": {
		"solo": "你把原册留在桌上，逐笔复读编号、时刻和核准栏。实查反证与抄件对上，才在另纸记下结论。",
		"tang_teach": "唐栖沿工册传抄时逐项复核的做法，与你并读留底和分存抄件；手艺不被用来猜谁的笔迹。",
		"tang_preserve": "唐栖不动原页，在另纸标出相异处，再与你核对编号与核准栏。原件和判断分开放好。",
		"qin_timing": "秦禾依轮值核时的经历，与你并看原读数、核收与签发先后。旧职衔不能代替这些具体记录。"
	},
	"classification_method_line": {
		"solo": "你逐号列出依据，再把003、004留所等候与循例交发的差别写在旁页。没有追加材料或人手门槛。",
		"shen_shore": "沈青依留岸照护的经历，与你列出等候与继续交接的区别。多等一轮有实际代价；她不以医术断公文真假。",
		"shen_mobile": "沈青依随船照护的经历，与你列明往返交接的差别。继续办理仍须有人核签；她不添病人姓名或伤情。"
	},
	"outcome_short": {
		"pause_batch": "001、002已撤销；003、004留所复核，暂不交发。",
		"cancel_proven": "001、002已撤销；003、004循既有核验、签收程序继续交发，尚未核清。"
	},
	"home_status": {
		"stage6": "处置已记，终章回报尚未结算。回青苇渡，向陆伯交回回条并确认归灯。",
		"stage7": "已回青苇渡确认归灯，第一卷回报已结算一次。可自由行走，重看不再发奖。"
	},
	"wen_next": {
		"stage2": "“去东北文书房，让纪小砚按号调出已发留底。”",
		"stage3": "“已发留底已经核定。要保住本班未发簿，得去东南印台。”",
		"stage4or5": "“新簿的四号，去旧闸守闸桌逐号记清，再确认怎样交接。”",
		"stage6": "“处置有了回条。回青苇渡，把这一程向陆伯说清吧。”",
		"stage7": "“回条已经归档。再来歇脚，也不必总带着未结的事。”"
	},
	"clerk_next": {
		"stage3": "“梁缜还守着东南印台的一册未发令。那是另一册，须保住后再逐号看；韩砚的旧原账没有重封。”",
		"stage4or5": "“未发簿已经保住。四号的分类与处置另记，不把新簿倒作旧责任的证据。”",
		"stage6or7": "“四号新令已按你的确认另行登记。新回条不改旧证，也不给未查清的号添一个‘无误’。”"
	},
	"planning_next": {
		"at_archive": "此处只能拟稿。沿旧路回旧闸，到守闸所南侧守闸桌另行确认。",
		"at_sluice_desk": "这里可以打开最后确认页。只有明确选择确认执行，才会落定。"
	},
	"desk_current": {
		"stage4": "未发簿已得，四号尚待明确分类；在此即可完成，不必返回霜桥。",
		"stage5_empty_draft": "四号已分类，尚未拟稿；在此即可商议两案。",
		"stage5_has_draft": "四号已分类，当前草案尚未执行；先核看，再决定是否确认。"
	},
	"archive_current": {
		"stage4": "本班四号尚待分类。可以在此先核，也可直接去旧闸守闸桌。",
		"stage5_empty_draft": "四号分类已记，草案尚空。可在此拟稿，也可到旧闸守闸桌继续。",
		"stage5_has_draft": "四号分类与草案仍在。最终处置只在旧闸守闸桌明确确认。",
		"stage6or7": "四号已按回条登记：{outcome_short} 此处只供重看，不重开交锋或改案。"
	},
	"evidence_error": {
		"watermark_proves_author": "共用水纹不是私人印记，不能据此把所有令归到同一人名下。",
		"dry_means_whole_ship": "旧两篓实查不能证明所有粮船无损；要核对具体授权号、时刻和核准动作。",
		"victory_proves_guilt": "责任由已发留底、独立抄件与实查反证核定，胜负不作证；未发令簿此时尚未取得。"
	}
}

var host
var _site: String = ""
var _page: String = ""
var _shown_generation: int = -1
var _shown_state: int = -1
var _shown_world: int = -1
var _revision: int = 0
var _method: String = "solo"
var _read_chain: int = 0
var _evidence_error: String = ""
var _reward_summary: String = ""
var _coin_loss: int = 0
var _resume: String = ""
var _before_battle_save: bool = false

func _init(owner) -> void:
	host = owner

func _ready() -> bool:
	if not is_instance_valid(host) or host.quit_pending or host.current_screen != "explore": return false
	var s = host.state
	return s != null and not s.battle_active and s._party_pending_token < 0 and not s._party_gate() \
		and s.hp > 0 and host.world.map_id == s.map_id \
		and s._stage_save_data(s.to_dict(), s.SAVE_VERSION).ok \
		and Rules._valid_prior_story(Rules.progress(s))

func _at(site: String) -> bool:
	return SITES.has(site) and _ready() and host.state.map_id == SITES[site] \
		and host.world.interactables.has(site) and host.world.player_pos.is_finite() \
		and host.world.interactables[site].pos is Vector2 and host.world.interactables[site].pos.is_finite() \
		and host.world.player_pos.distance_to(host.world.interactables[site].pos) < 75.0

func handle(site: String) -> bool:
	if not SITES.has(site) or host.state == null: return false
	var stage: int = host.state.capstone_stage
	var relevant: bool = false
	match site:
		"heting_dispatch": relevant = stage > 0 or Rules.can_begin(host.state)
		"chapter_host", "capstone_order_desk": relevant = stage >= 1
		"chapter_clerk": relevant = stage >= 2
		"chapter_archive": relevant = stage >= 3
		"elder": relevant = stage >= 6
	if not relevant: return false
	open(site)
	return true

func open(site: String) -> void:
	if not _at(site): return
	_site = site
	_revision += 1
	_method = "solo"
	_read_chain = 0
	var stage: int = host.state.capstone_stage
	match site:
		"heting_dispatch": _show("A0" if stage == 0 else ("A1" if stage < 6 else "A2"))
		"chapter_host":
			if stage >= 1: _show("B0" if stage == 1 else "B5")
		"chapter_clerk":
			if stage >= 2: _show("C1" if stage == 2 else "C8")
		"chapter_archive":
			if stage >= 3: _show("D0" if stage == 3 else "R1")
		"capstone_order_desk":
			if stage in [4, 5]: _show("E0" if stage == 4 else "G0")
			elif stage >= 6: _show("G3" if host.state.capstone_ending == "pause_batch" else "G4")
			elif stage > 0: _custom("early_desk", "守闸所 · 待发令案", "截令归灯 / 尚待查证", "须先核原信与已发留底，再到霜桥印台保住本班未发簿。这里不能远程取簿、定责或处置。\n\n" + String(Rules.goal(host.state).get("objective", "")), [["记下去处", "close"]])
		"elder":
			if stage >= 6: _show("H0" if stage == 6 else "H3")

func journal() -> String:
	return Rules.journal(host.state)

func _allowed_page(id: String) -> bool:
	if not PAGES.has(id) or not _at(_site): return false
	var stages: Variant = PAGES[id].stages
	if stages is Array and not stages.has(host.state.capstone_stage): return false
	if id.begins_with("A"): return _site == "heting_dispatch"
	if id.begins_with("B"): return _site == "chapter_host"
	if id.begins_with("C"): return _site == "chapter_clerk"
	if id.begins_with("D"): return _site == ("chapter_host" if id == "D7" else "chapter_archive")
	if id.begins_with("H"): return _site == "elder"
	if id.begins_with("S"): return true
	if id == "G5": return false # Existing Luo aftermath is integrated by main.
	return _site in ["chapter_archive", "capstone_order_desk"] and (id not in ["G1", "G2"] or _site == "capstone_order_desk")

func _show(id: String) -> void:
	if not _allowed_page(id): return
	# First evidence judgement cannot skip any of the concrete issued fields.
	if id == "C1": _read_chain = maxi(_read_chain, 1)
	elif id == "C2":
		if _read_chain < 1: return
		_read_chain = maxi(_read_chain, 2)
	elif id == "C3":
		if _read_chain < 2: return
		_read_chain = 3
	elif id in ["C4", "C5", "C6", "C7"] and _read_chain < 3: return
	if id in ["F1", "G1", "G2"] and host.state.capstone_draft.is_empty(): _show("F0"); return
	if id in ["G1", "G2"] and host.state.capstone_draft != ("pause_batch" if id == "G1" else "cancel_proven"): return
	var page: Dictionary = PAGES[id]
	var choices: Array = []
	for entry: Array in page.choices:
		if _condition(String(entry[2])): choices.append([entry[0], entry[1]])
	_custom(id, page.title, page.subtitle, _render(page.body), choices)

func _condition(condition: String) -> bool:
	if condition.is_empty(): return true
	if condition.begins_with("method_available("):
		var method: String = condition.trim_prefix("method_available(").trim_suffix(")")
		return Rules.available_methods(host.state, "classification" if method.begins_with("shen_") else "evidence").has(method)
	match condition:
		"at_archive": return _site == "chapter_archive"
		"at_sluice_desk": return _site == "capstone_order_desk"
		"stage4": return host.state.capstone_stage == 4
		"stage5": return host.state.capstone_stage == 5
		"stage5_empty_draft": return host.state.capstone_stage == 5 and host.state.capstone_draft.is_empty()
		"stage5_has_draft": return host.state.capstone_stage == 5 and not host.state.capstone_draft.is_empty()
		"stage6_or7": return host.state.capstone_stage >= 6
	return false

func _custom(id: String, title: String, subtitle: String, body: String, entries: Array) -> void:
	if not _at(_site) or entries.is_empty() or entries.size() > 5: return
	_page = id
	_revision += 1
	var stamp: Dictionary = {"generation": host.modal_generation + 1, "revision": _revision, "site": _site, "page": _page,
		"state": host.state.get_instance_id(), "world": host.world.get_instance_id(), "stage": host.state.capstone_stage,
		"draft": host.state.capstone_draft, "ending": host.state.capstone_ending}
	var options: Array = []
	for entry: Array in entries: options.append([entry[0], _apply.bind(String(entry[1]), stamp)])
	host._modal(title, subtitle, body, options, true)
	_shown_generation = host.modal_generation
	_shown_state = host.state.get_instance_id()
	_shown_world = host.world.get_instance_id()
	host.modal_autosave_on_close = false

func _apply(action: String, stamp: Dictionary) -> void:
	if not _at(String(stamp.site)) or not host.active_modal or host.modal_generation != stamp.generation \
		or _revision != stamp.revision or _site != stamp.site or _page != stamp.page \
		or host.state.get_instance_id() != stamp.state or host.world.get_instance_id() != stamp.world \
		or host.state.capstone_stage != stamp.stage or host.state.capstone_draft != stamp.draft \
		or host.state.capstone_ending != stamp.ending: return
	_dispatch(action)

func _close() -> void:
	_revision += 1
	host.modal_autosave_on_close = false
	host._close_modal()

func _live_page() -> bool:
	return _at(_site) and host.active_modal and host.modal_generation == _shown_generation \
		and host.state.get_instance_id() == _shown_state and host.world.get_instance_id() == _shown_world

func _dispatch(action: String) -> void:
	if not _live_page(): return
	if PAGES.has(action): _show(action); return
	if action.begins_with("method:"):
		var parts: PackedStringArray = action.split(":")
		var domain: String = "evidence" if parts[2].begins_with("C") else "classification"
		if not Rules.available_methods(host.state, domain).has(parts[1]): _unavailable(domain); return
		_method = parts[1]; _show(parts[2]); return
	if action.begins_with("evidence:"):
		if _site != "chapter_clerk" or _page != "C6" or _read_chain != 3: return
		if not Rules.available_methods(host.state, "evidence").has(_method): _unavailable("evidence"); return
		var result: Dictionary = host.state.resolve_capstone_evidence(action.trim_prefix("evidence:"), _method)
		if result.get("ok", false): _persist("goal"); return
		_evidence_error = String(result.get("reason", "请再核对具体编号。")); _show("C7"); return
	if action.begins_with("classify:"):
		if _page != "E6" or _site not in ["chapter_archive", "capstone_order_desk"]: return
		if not Rules.available_methods(host.state, "classification").has(_method): _unavailable("classification"); return
		var partition: Dictionary = Rules.CORRECT_PARTITION.duplicate()
		if action == "classify:all_false": partition[Rules.ORDER_IDS[2]] = "proven_false"; partition[Rules.ORDER_IDS[3]] = "proven_false"
		elif action == "classify:last_two_proven_true": partition[Rules.ORDER_IDS[2]] = "proven_true"; partition[Rules.ORDER_IDS[3]] = "proven_true"
		elif action != "classify:CORRECT_PARTITION": return
		var result: Dictionary = host.state.classify_capstone_orders(partition, _method)
		if result.get("ok", false): _persist("classified")
		else: _show("E7")
		return
	if action.begins_with("plan:"):
		if _site not in ["chapter_archive", "capstone_order_desk"] or _page not in ["F0", "F1"]: return
		var plan: String = action.trim_prefix("plan:")
		if host.state.choose_capstone_plan(plan): _persist("F2" if plan.is_empty() else "F1")
		elif host.state.capstone_stage == 5 and host.state.capstone_draft == plan: _show("F0" if plan.is_empty() else "F1")
		return
	if action.begins_with("confirm:"):
		if _site != "capstone_order_desk" or _page not in ["G1", "G2"]: return
		var plan: String = action.trim_prefix("confirm:")
		if host.state.confirm_capstone_disposition(plan): _persist("G3" if plan == "pause_batch" else "G4")
		return
	match action:
		"close": _close()
		"begin":
			if _site == "heting_dispatch" and _page == "A0" and host.state.begin_capstone(): _persist("goal")
		"reveal":
			if _site == "chapter_host" and _page == "B4" and host.state.reveal_capstone_letter(): _persist("goal")
		"homecoming": _homecoming()
		"retry": _retry_save()
		"start_real_capstone_battle": _start()
		"existing_wen_free_rest": _rest()
		"existing_consignee_record", "existing_heting_dispatch", "existing_heting_manifest", "existing_frostbridge_record", "existing_clerk_record": _legacy(action)
		"current_order_index": _show("E0" if host.state.capstone_stage == 4 else "R0")
		"current_planning_hub":
			if _site == "chapter_archive": _show("R1")
			elif host.state.capstone_stage <= 5: _show("G0")
			else: _show("G3" if host.state.capstone_ending == "pause_batch" else "G4")
		"selected_confirmation":
			if _site == "capstone_order_desk": _show("G1" if host.state.capstone_draft == "pause_batch" else ("G2" if host.state.capstone_draft == "cancel_proven" else "F0"))
		"current_home_page": _show("H0" if host.state.capstone_stage == 6 else "H3")
		"return_site": open(_site)

func _unavailable(domain: String) -> void:
	_method = "solo"
	_custom("method_unavailable", "同行方法现不可用", "截令归灯 / 可独自完成", "该同行人须有相应经历、实际出战且仍站立。当前方法已不可用；仍可自己逐项核对，不扣资源，也不撤销已经核清的事实。", [["重新选择核对方法", "C4" if domain == "evidence" else "E4"], ["先收好记录", "close"]])

func _rest() -> void:
	if not _live_page() or _site != "chapter_host": return
	host.state.heal_rest()
	_persist("rested")

func _legacy(action: String) -> void:
	# Already-completed old scenes remain readable without reviving clue,
	# cargo or reward callbacks. Other optional NPCs are never intercepted.
	var body: String = ""
	var title: String = ""
	match action:
		"existing_consignee_record":
			if _site != "heting_dispatch": return
			title = "未损先收 · 本批记录"; body = Consignee.journal(host.state)
		"existing_heting_dispatch":
			if _site != "heting_dispatch": return
			title = "孟绫 · 理缆人"; body = _variant("harbor_memory", host.state.heting_ending) + "\n\n开锅粮、对秤封粮、待分粮三批均已实际交下，不再领取。北仓两篓另记，旧两担复签仍可到东岸公秤另问。"
		"existing_heting_manifest":
			if _site != "heting_dispatch": return
			title = "鹤汀交割单"; body = host.heting_story.manifest_body()
		"existing_frostbridge_record":
			if _site != "chapter_host": return
			title = "温行舟 · 霜桥旧事"; body = _variant("record_privacy", host.state.chapter_two_ending) + "\n\n原账早已取得，水、驿、仓三印已解，南桥是否修好仍依当时实做。" + ("\n\n旧信仍由温行舟保管，须听清作者说明后明确收回。" if host.state.capstone_stage == 1 else "\n\n旧信已交还你，不会因重看旧事再次被收走。")
		"existing_clerk_record":
			if _site != "chapter_clerk": return
			title = "纪小砚 · 三印旧事"; body = _variant("record_source", host.state.ending) + "\n\n先领水令，再过驿站，最后入仓。水印先行，驿印居中，仓印收尾。\n\n旧线索与启封已经记下；这里不再记线索或发修为。"
	if body.is_empty(): return
	var options: Array = [["回到眼前", "return_site"], ["继续行走", "close"]]
	if action == "existing_heting_dispatch": options.push_front(["查看原交割单", "existing_heting_manifest"])
	elif action == "existing_heting_manifest": options[0] = ["回到交割旧事", "existing_heting_dispatch"]
	_custom("legacy_manifest" if action == "existing_heting_manifest" else "legacy_record", title, "旧事重看 / 原选择保留", body, options)

func battle_entry_ready() -> bool:
	return _live_page() and _site == "chapter_archive" and _page == "D2" and Rules.can_confront(host.state)

func _start() -> void:
	if not battle_entry_ready(): return
	if not host._start_party_capstone_battle(host.modal_generation) and host.save_warning: _save_failed("D2", true)

func _homecoming() -> void:
	if not _live_page() or _site != "elder" or _page != "H0" or host.state.capstone_stage != 6: return
	var coins_before: int = host.state.coins
	var level_before: int = host.state.level
	if not host.state.finish_capstone_homecoming(): return
	var coins: int = host.state.coins - coins_before
	_reward_summary = "终章回报已结算：修为160、铜钱80，只此一次。" if coins == 80 and host.state.level < 99 else "终章回报已按上限结算：修为按既有规则计入，铜钱实得%d。本卷回报不会重复发放。" % coins
	if host.state.level > level_before: _reward_summary += "\n升至%d级，沿用既有升阶恢复。" % host.state.level
	_persist("H2")

func _persist(resume: String) -> void:
	_revision += 1
	host._sync_world_state()
	host.world.teleport(host.world.player_pos)
	host.state.position = host.world.player_pos
	host._autosave()
	host._refresh()
	if host.save_warning: _save_failed(resume)
	else: _continue(resume)

func _save_failed(resume: String, before_battle: bool = false) -> void:
	_resume = resume
	_before_battle_save = before_battle
	_show("S1" if before_battle else "S0")

func _retry_save() -> void:
	if not _live_page() or _page not in ["S0", "S1"]: return
	host._autosave()
	if host.save_warning: _save_failed(_resume, _before_battle_save)
	else: _continue(_resume)

func _continue(resume: String) -> void:
	if resume == "goal":
		var objective: String = Rules.goal(host.state).get("objective", "")
		_close()
		host._toast(objective)
	elif resume == "classified":
		_show("F0"); host._toast("四号分类已记；四号仍全部待处置，尚未拟稿。")
	elif resume == "rested":
		_close(); host._toast("驿馆免费调息完毕，气血与真气已恢复。")
	else: _show(resume)

func after_battle(result: Dictionary) -> void:
	if not _ready() or result.get("encounter_id") != Combat.ENCOUNTER_ID \
		or result.get("capstone_stage", -1) != host.state.capstone_stage: return
	var outcome: String = String(result.get("outcome", ""))
	var page: String = ""
	if outcome == "win" and host.state.capstone_stage == 4: _site = "chapter_archive"; page = "D5"
	elif outcome == "flee" and host.state.capstone_stage == 3: _site = "chapter_archive"; page = "D6"
	elif outcome == "defeat" and host.state.capstone_stage == 3:
		_site = "chapter_host"; page = "D7"; _coin_loss = maxi(0, -int(result.get("coin_change", 0)))
	else: return
	if not _at(_site): return
	_method = "solo"; _read_chain = 0; _revision += 1
	# Settlement is already committed by State/PartyUI. This only explains it.
	if host.save_warning: _save_failed(page)
	else: _show(page)

func _variant(key: String, branch: String) -> String:
	return String(VARIANTS.get(key, {}).get(branch, ""))

func _render(template: String) -> String:
	var s = host.state
	var stage: int = s.capstone_stage
	var status12: String = "状态：尚待明确分类；尚未处置。" if stage == 4 else ("分类：依据已证伪。去向：待处置。" if stage == 5 else "分类：依据已证伪。去向：已撤销。")
	var remaining: String = "留所复核，暂不交发" if s.capstone_ending == "pause_batch" else "循既有核验、签收程序继续交发，尚未核清"
	var status34: String = "状态：尚待明确分类；尚未处置。" if stage == 4 else ("分类：尚未核清。去向：待处置。" if stage == 5 else "分类：尚未核清。去向：" + remaining + "。")
	var phases: Array[String] = []
	for phase: Dictionary in Combat.PHASES:
		var line: String = "%s：招式基础伤害%d" % [phase.name, phase.damage]
		if phase.guarded: line += "，护势减半"
		if phase.heavy: line += "，重招"
		if int(phase.opening) > 0: line += "，承受伤害额外%d" % phase.opening
		phases.append(line + "。")
	var values: Dictionary = {
		"capstone_goal": Rules.goal(s).get("objective", ""), "draft_description": Rules.plan_description(s.capstone_draft),
		"record_privacy": _variant("record_privacy", s.chapter_two_ending), "record_source": _variant("record_source", s.ending),
		"old_two_baskets": _variant("old_two_baskets", s.consignee_ending), "home_archive": _variant("home_archive", s.ending),
		"harbor_memory": _variant("harbor_memory", s.heting_ending), "side_memory": _variant("side_memory", s.side_choice),
		"mist_memory": _variant("mist_memory", s.mist_ending), "mist_access_memory": _variant("mist_access_memory", s.mist_approach),
		"receipt_note": _variant("receipt_note", "receipt_stage==3" if s.receipt_stage == 3 else "receipt_stage<3"),
		"receipt_memory": _variant("receipt_memory", "receipt_stage==%d" % s.receipt_stage),
		"evidence_method_line": _variant("evidence_method_line", _method), "classification_method_line": _variant("classification_method_line", _method),
		"outcome_short": _variant("outcome_short", s.capstone_ending), "home_status": _variant("home_status", "stage7" if stage == 7 else "stage6"),
		"wen_next": _variant("wen_next", "stage4or5" if stage in [4, 5] else "stage%d" % stage),
		"clerk_next": _variant("clerk_next", "stage3" if stage == 3 else ("stage4or5" if stage <= 5 else "stage6or7")),
		"planning_next": _variant("planning_next", "at_archive" if _site == "chapter_archive" else "at_sluice_desk"),
		"desk_current": _variant("desk_current", "stage4" if stage == 4 else ("stage5_empty_draft" if s.capstone_draft.is_empty() else "stage5_has_draft")),
		"archive_current": _variant("archive_current", "stage4" if stage == 4 else ("stage6or7" if stage >= 6 else ("stage5_empty_draft" if s.capstone_draft.is_empty() else "stage5_has_draft"))),
		"row001_status": status12, "row002_status": status12, "row003004_status": status34,
		"orders_status": "001、002：依据已证伪，%s。\n003、004：尚未核清，%s。" % ["待处置" if stage == 5 else "已撤销", "待处置" if stage == 5 else remaining],
		"hp": str(s.hp), "max_hp": str(s.max_hp), "qi": str(s.qi), "max_qi": str(s.max_qi), "medicine": str(s.medicine),
		"combat_stats": "梁缜气血%d，全场只有这一名对手，人数不改变其气血。按头顶预告应对。" % int(Combat.endurance().liang_zhen_max_hp),
		"combat_phases": "\n".join(phases), "actual_coin_loss": str(_coin_loss), "actual_reward_summary": _reward_summary,
		"evidence_error": _evidence_error}
	# Exactly one known nested outcome substitution, never expression evaluation.
	values.archive_current = String(values.archive_current).replace("{outcome_short}", String(values.outcome_short))
	var text: String = template
	for key: String in values: text = text.replace("{" + key + "}", String(values[key]))
	return text
