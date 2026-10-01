class_name ShenCareStory
extends RefCounted
var host
func _init(owner)->void:host=owner
func pending()->bool:return host.state.shen_care_stage in [1,2,3,4]
func visible()->bool:return host.state.shen_care_stage>0 or host.state.ShenCare.can_begin(host.state)
func _guard(action:Callable)->Callable:return _apply.bind(action,host.modal_generation+1)
func _apply(action:Callable,generation:int)->void:
	if host.current_screen=="explore" and host.active_modal and generation==host.modal_generation:action.call()
func pharmacy()->void:
	var s=host.state
	match s.shen_care_stage:
		0:
			if not s.ShenCare.can_begin(s):route_info();return
			host._modal("沈青 · 药师","同行机缘 / 药箱之外","沈青翻着一张旧便条，迟迟没有落笔。\n\n“许照川回来换过伤布。我写了‘可以行走’，船头便当他已经能出工。可走回家，和站在湿滑的跳板上拉缆，是两回事。”\n\n“我只问了伤口，没有问他回去以后靠什么过日子。能不能把这件事补问清楚？”\n\n许照川如今在废闸南岸。此行不用另买药材。",[["去问问他的近况",_guard(begin)],["稍后再谈",host._close_modal],["先去调息",host._healer_dialogue]],true)
		1,2:
			host._modal("沈青","药箱之外 / 等你回来",hint()+"\n\n“不要替他把话说完。问问他，怎样才算能过自己的日子。”",[["记住了",host._close_modal],["药铺调息",host._healer_dialogue]],true)
		3:decision()
		4:draft()
		5:
			var text="药棚有人照看了。我还得记着，能走到门前的，只是需要照应的一部分人。" if s.shen_care_choice=="shore" else "短渡把问候带远了。我还得记着，问到了人，也不能忘了给需要长歇的人找个落脚处。"
			host._modal("沈青","药箱之外 / 仍有未尽之事","“"+text+"”\n\n"+benefit()+"\n这份约定已写进渡口的日子。",[["查看同行册",host.companion_story.roster],["药铺调息",host._healer_dialogue],["告辞",host._close_modal]],true)
func begin()->void:
	if host.state.begin_shen_care():
		host._close_modal();host._toast("同行机缘：药箱之外。去废闸南岸，听许照川说说近况。")
func patient()->void:
	var s=host.state
	if s.shen_care_stage==5:
		var text="“这回他们先问我今天能做什么，没有先问什么时候上船。”\n\n许照川正替药棚记轮值。有人接了他那一班重活，他便先做些不勉强自己的小事。远埠的人还得靠岸来，这点难处也写在约里。\n\n“不是从此没了难处。是说一句‘我还不行’，终于有人肯听。”" if s.shen_care_choice=="shore" else "“以前船到得晚，药铺的门也该关了。现在短渡的人会来问一句。”\n\n许照川在岸边指认停泊处，不再硬撑着拉缆。遇上需要长歇的人，仍要费心联系送岸，旧药棚还缺固定照看。\n\n“帮忙的人没有变多，只是这回，远处的人也算在里头了。”"
		host._modal("许照川 · 船工","药箱之外 / 渡口的后来",text,[["听水令旧事",testimony],["告辞",host._close_modal]],true)
		return
	var text="“那天你先割断了缆绳，我才敢说自己撑不住。”\n\n许照川扶着岸桩，没有像先前那样急着站直。\n\n“伤口收了，踏跳板时却还使不上力。船头说有药师的字，我再歇就是躲活。我想歇两天，可饭钱不能也歇两天。”\n\n“北边旧仓药棚能歇脚，可外埠的船未必靠这岸。要帮人，得想清楚谁走得过来。”"
	if s.side_choice=="pursuit":
		text="“账页已经找到了吧？我记得的水令，都告诉你了。”\n\n你说，这回来不是补证言，只想知道他过得怎样。许照川这才松开扶着岸桩的手。\n\n“我知道那张纸也要紧。可现在踏跳板还使不上力，船头却拿药师的字催我出工。歇得起的人，才敢承认没养好。”\n\n“北边旧仓药棚能歇脚，可外埠的船未必靠这岸。若有人肯去问一问，别只问他还能不能拉缆。”"
	var choices:Array=[]
	choices.append(["记下他的难处",_guard(consult)] if s.shen_care_stage==1 else ["记住了",host._close_modal])
	choices.append(["再听水令旧事",testimony]);choices.append(["先不打扰",host._close_modal])
	host._modal("许照川 · 船工","药箱之外 / 伤口以外",text,choices,true)
func testimony()->void:
	host._modal("许照川 · 船工","废闸 / 已得证言","“那天有人换了水令，命我们在逆流时入港。不是天灾，是有人在等粮船翻。”\n\n这份证言已经记下，不会改变照护约的调查进度。",[["谈谈近况",patient],["告辞",host._close_modal]],true)
func consult()->void:
	if host.state.consult_shen_patient():
		host._close_modal();host._toast("已听清许照川的难处。去废闸西北旧仓药棚，看看这里能照应谁。")
func shelter()->void:
	host._modal("旧仓药棚","药箱之外 / 一处灯照多远","草席仍干净，门槛却高过寻常船板。近岸的人能来歇脚，泊在远埠的人未必赶得上。\n\n船家愿意轮出一人帮忙，却只能顾一头：留在棚里照看歇工的人，或随短渡去问那些不来药铺的人。\n\n药和布暂时够用，缺的是肯留下来的工夫。多买一包药，也不能替人多守一夜。\n\n把这里的情形带回青苇药铺，再与沈青商量。",[["记下药棚情形",_guard(inspect)],["在此免费调息",rest],["稍后再看",host._close_modal]],true)
func shared_shelter()->void:
	host._modal("旧仓药棚","旧地 / 两件未了的事","棚边的木匣还在，屋里的草席也未撤去。可以分别办妥手头的事，不必舍弃其中一件。",[["查看照护场地",shelter],["寻找旧工册",host.companion_story.notebook],["免费调息",rest],["离开",host._close_modal]],true)
func rest()->void:
	host.state.heal_rest();host._close_modal();host._toast("气血与真气恢复；照护调查仍可继续。")
func inspect()->void:
	if host.state.inspect_shen_shelter():
		host._close_modal();host._toast("药棚情形已记下。回青苇药铺，与沈青商议照护的办法。")
func decision()->void:
	host._modal("沈青 · 药师","药箱之外 / 方子没有写完","沈青在便条上添了一句：“能行走，不等于能出工。”\n\n“我不能只替船头写一张放心的纸。该不该歇，由他自己的身子与处境一起说话。”\n\n[color=#d3b276]留岸照护[/color]：轮值留在药棚，照看上岸歇工者；远埠仍须等靠岸。沈青护后减伤由2变为3。\n\n[color=#d3b276]随船问诊[/color]：随短渡探问不来药铺的人；药棚暂缺固定照看。沈青并肩相助时另恢复2气血。\n\n都不消耗物品。张贴照护约后生效，并得40修为。",[["留岸照护",_guard(choose.bind("shore"))],["随船问诊",_guard(choose.bind("mobile"))],["再想一想",host._close_modal]],true)
func choose(id:String)->void:
	if host.state.choose_shen_care(id):
		host._autosave();host._refresh();draft()
	elif not host.state.battle_active and host.state.shen_care_stage==4 and host.state.shen_care_choice==id and host.state.ShenCare.CHOICES.has(id):
		# Keeping an existing draft is navigation, not another state mutation.
		draft()
func draft()->void:
	var text="“先让愿意上岸的人，真有个能停下来的地方。”\n\n轮值会在药棚照看行装、联系替班；能否再出工，留给本人和复诊时商议。外埠船只仍须等靠岸再来。" if host.state.shen_care_choice=="shore" else "“有些人不到药铺，并不是他们不需要人问。”\n\n轮值船工会随短渡探问伤者，留下求助的去处；遇上需要歇工的人，再联系送回岸上。旧药棚仍可歇脚，暂时没有固定照看。"
	host._modal("沈青","药箱之外 / 未贴出的照护约",text+"\n\n这张约只写轮值办法，不写病人的姓名与伤情。\n\n到村中告示牌张贴后得40修为，并启用：\n"+benefit()+"\n张贴前还可回来改议。",[["带去告示牌",host._close_modal],["重新商议",decision],["先去调息",host._healer_dialogue]],true)
func sponsor()->String:
	return "当初抄过账页的船家读过照护约，各自认下轮值的日子。陆伯记下，谁临时缺席，便先找人补上。" if host.state.ending=="守望" else "陆伯把照护约与县衙收账的回执并排挂好：“收了纸，还得有人盯着做。”他另记轮值，交给来往船家核对。"
func board()->void:
	var route="轮值留在旧仓药棚，先照看上岸歇工的人；远埠伤者仍须等靠岸求助。" if host.state.shen_care_choice=="shore" else "轮值随短渡探问远埠伤者，联系送回岸上的办法；旧药棚暂时没有固定照看。"
	host._modal("青苇渡告示","药箱之外 / 把约定留在人前",sponsor()+"\n\n[color=#d3b276]约定[/color]："+route+"\n\n不张贴病人的姓名与伤情。张贴后，本次安排不再改换。\n\n完成奖励：40修为；"+benefit(),[["照此张贴",_guard(post)],["回去再商议",host._close_modal],["看看原告示",host._show_board_base]],true)
func post()->void:
	if host.state.post_shen_notice():
		host._autosave();host._refresh()
		var text="“从前我总觉得，把人送出门，就是治完了。如今该多问一句：门外有人肯等他吗？”\n\n许照川暂且留岸，替轮值的人记清来往。他的恢复还没有结束，但不必再拿逞强证明自己。" if host.state.shen_care_choice=="shore" else "“从前我只在门里等人。那些不进门的人，也该有地方开口。”\n\n许照川先替短渡指认停泊处，不再勉强拉缆。他的恢复还没有结束，往来的人却知道该向谁求助了。"
		host._modal("沈青","同行机缘完成 / 药箱之外","沈青从药铺过来，把旧便条收进药箱。\n\n"+text+"\n\n获得40修为。"+benefit()+"\n照护约已留在村中告示上。",[["查看同行册",host.companion_story.roster],["继续赶路",host._close_modal]],true)
		host._toast("药箱之外已完成。照护约改变了渡口的日常，也留下沈青的照护心得。")
func benefit()->String:
	return "沈青护后时，每次来袭减伤3（仍至少受伤1）。" if host.state.shen_care_choice=="shore" else "沈青并肩相助时，另恢复2气血（不超过上限）。"
func board_append()->String:
	if host.state.shen_care_stage!=5:return ""
	var text="旧仓药棚有人轮值，照看上岸歇工者并联系替班。远埠仍须靠岸求助。" if host.state.shen_care_choice=="shore" else "轮值随短渡探问远埠伤者，联系上岸求助。旧药棚暂时没有固定照看。"
	return "\n\n[color=#d3b276]照护约 · "+("留岸照护" if host.state.shen_care_choice=="shore" else "随船问诊")+"[/color]\n"+text+"\n不以一纸便条催人出工。"
func shelter_append()->String:
	if host.state.shen_care_stage!=5:return ""
	return "\n\n门边多了一张轮值纸。有人把新来的行装挪到干处，给歇脚的人让出位置。" if host.state.shen_care_choice=="shore" else "\n\n门边留着短渡停泊的时辰。油布包随船去了，棚里的草席仍给来人留着。"
func hint()->String:
	return ["完成废闸疑云，并与沈青结伴后，回青苇药铺问问船工近况。","去废闸南岸找许照川，这次听听他自己的近况。","去废闸西北旧仓药棚，查看能照应哪些来往的人。","回青苇药铺，把船工与药棚的情况告诉沈青。","到青苇渡中央告示牌张贴照护约；张贴前可回药铺改议。","留岸照护已议定。" if host.state.shen_care_choice=="shore" else "随船问诊已议定。"][host.state.shen_care_stage]
func route_info()->void:
	host._modal("沈青的近况","同行机缘 / 药箱之外",hint()+"\n\n"+(benefit() if host.state.shen_care_stage==5 else "此页只记行程，不代替亲自去听人说话。"),[["回到同行册",host.companion_story.roster],["继续赶路",host._close_modal]],true)
func target_id()->String:
	if not pending():return ""
	var s=host.state
	match s.map_id:
		"qingwei":return "exit_sluice" if s.shen_care_stage in [1,2] else ("healer" if s.shen_care_stage==3 else "board")
		"sluice":return "stranded_boatman" if s.shen_care_stage==1 else ("sluice_cache" if s.shen_care_stage==2 else "return_village")
		"frostbridge":return "return_sluice"
		"mistwood":return "return_frostbridge"
	return ""
func journal()->String:
	if not host.state.companion_unlocked:return ""
	var s=host.state
	var lines=["向沈青询问船工近况","听许照川说清自己的难处","查看旧仓药棚","与沈青议定照护办法","把照护约贴在村中告示牌"]
	var text="\n\n[color=#d3b276]同行机缘 · 药箱之外[/color]"
	for i in range(5):text+="\n"+("✓ " if s.shen_care_stage>i else "◇ ")+lines[i]
	return text+"\n"+hint()+(("\n"+benefit()) if s.shen_care_stage==5 else "")
