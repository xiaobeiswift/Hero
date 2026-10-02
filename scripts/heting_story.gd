class_name HetingStory
extends RefCounted
const CARGO_NAMES={"meal":"开锅粮","sealed":"对秤封粮","reserve":"待分粮"}
const PLAN_NAMES={"short_ferries":"短渡分粮","open_scale":"守秤留粮"}
var host
func _init(owner)->void:host=owner
func _guard(action:Callable)->Callable:return _apply.bind(action,host.modal_generation+1)
func _apply(action:Callable,generation:int)->void:
	if host.current_screen=="explore" and host.active_modal and generation==host.modal_generation:action.call()
func _modal(title:String,subtitle:String,body:String,options:Array=[],wide:bool=false)->void:
	host._modal(title,subtitle,body,options,wide)
	host.modal_autosave_on_close=false
func _at(id:String,map_id:String="heting")->bool:
	return host.state.map_id==map_id and host.world.map_id==map_id and host.world.interactables.has(id) and host.world.player_pos.is_finite() and host.world.player_pos.distance_to(host.world.interactables[id].pos)<75.0
func _at_any(ids:Array)->bool:
	for id in ids:
		if _at(id):return true
	return false
func handle(id:String)->bool:
	match id:
		"exit_heting":entry()
		"return_mistwood":leave()
		"heting_dispatch":dispatch()
		"heting_cargo":cargo()
		"heting_lighter":lighter()
		"heting_winch":winch()
		"heting_relief":receiver("heting_relief")
		"heting_scale":receiver("heting_scale")
		_:return false
	return true
func entry()->void:
	if host.state.mist_stage<4:
		_modal("下埠山道","道路 / 鹤汀来路","山道向下通往鹤汀埠。先回秦禾处商议眼前的水势，再把底稿带到粮船交割的地方。")
		return
	var body="底稿抄件上有一处交割号，落在鹤汀埠。\n\n雨令已有人校过，粮还得有人接。你沿山道下行，想看看那笔提前结算的粮钱，究竟压在谁的船上。\n\n港内可以免费歇脚。此行不必添买物资。" if host.state.heting_stage==0 else "沿听雨关东侧下行，仍是鹤汀埠的山道。货单、浮栈与已经议定的安排都会保留。"
	_modal("顺粮路下行","第四章 / 一秤两岸",body,[["走入鹤汀埠" if host.state.heting_stage==0 else "返回鹤汀埠",_guard(enter) ],["留在坡上",host._close_modal]],true)
func enter()->void:
	if not _at("exit_heting","mistwood"):return
	if host.state.heting_stage==0 and not host.state.begin_heting():return
	if host.state.mist_stage<4:return
	host._travel("heting",Vector2(180,350))
func leave()->void:
	if not _at("return_mistwood") or host.state.battle_active:return
	if host.state.heting_cargo.is_empty():
		host._travel("mistwood",Vector2(1440,505));return
	_modal("北岸归路","押车 / 先留好货物","这辆板车留在鹤汀埠。若要离开，先把未交的一批退回原位；已交货物与草案不变，回来仍可继续。\n\n不会删除任务或扣你的行囊材料。",[["退车后离开",_guard(park_and_leave)],["留在埠内",host._close_modal]],true)
func park_and_leave()->void:
	if not _at("return_mistwood"):return
	if host.state.park_heting_cargo():host._travel("mistwood",Vector2(1440,505))
func _cargo_name()->String:return String(CARGO_NAMES.get(host.state.heting_cargo,"无"))
func _receiver_for(id:String)->String:
	if id=="meal":return "heting_relief"
	if id=="sealed":return "heting_scale"
	return "heting_relief" if host.state.heting_draft=="short_ferries" else "heting_scale"
func _receiver_name(id:String)->String:return "西岸粥棚" if id=="heting_relief" else "东岸公秤棚"
func dispatch()->void:
	var s=host.state
	if s.heting_stage==2:decision();return
	if s.heting_stage==3:draft();return
	if s.heting_stage==4:
		var body="“西边写去回，东边留复称签。今夜先把人照应到，天亮还得把秤重新摆开。”" if s.heting_ending=="short_ferries" else "“东边有人守着秤，西边的锅也没灭。可远泊那几家没走到岸上的，明早得再问一遍。”"
		_modal("孟绫 · 理缆人","一秤两岸 / 埠灯未尽",body+"\n\n"+companion_line(),[["查看交割单",manifest],["告辞",host._close_modal]],true);return
	var opening="“缓水渠先分走了急流，东泊桩脚露得早。我们把浮栈先系在东边。秦禾的信随后也到了，船都安稳。”" if s.mist_ending=="release_water" else "“钟信先到，船家早早退进内湾。西边借两只稳船搭好了浮栈。东泊退水迟些，眼下照样能改泊。”"
	var choices:Array=[["去中埠提货",host._close_modal],["重看交割单",manifest],["告辞",host._close_modal]]
	if not s.heting_cargo.is_empty():choices.append(["退车归位",_guard(park)])
	_modal("孟绫 · 理缆人","一秤两岸 / 一车一签",opening+"\n\n孟绫把三张货签压在牌上。\n\n“先办两批：开锅粮送西岸粥棚，对秤封粮送东岸秤棚，先后由你。南泊那批待分粮，等看清今晚怎样用人再动。”\n\n“一车只押一批。中间步栈过不了车，岛上的绞缆机能把浮栈换到另一岸；也可上岸后沿北街绕行。”",choices,true)
func manifest()->void:
	var s=host.state;var body=""
	for id in ["meal","sealed","reserve"]:
		var status="已交" if s.heting_delivered.has(id) else ("车上" if s.heting_cargo==id else "未提")
		var destination=_receiver_name(_receiver_for(id)) if id!="reserve" or not s.heting_draft.is_empty() else "两批办妥后再议"
		body+="%s · %s → %s\n" % [status,CARGO_NAMES[id],destination]
	body+="\n当前押车："+_cargo_name()+"\n浮栈："+("西岸" if s.heting_bridge=="west" else "东岸")+"；北步栈仅供步行。\n\n"+("两担封粮已当面复称，实物与提前写成的水损票不符。" if s.heting_delivered.has("sealed") else "封粮尚未复称，不提前断定实物与票据相符。")
	_modal("鹤汀交割单","记录 / 实交才作数",body,[["回交割牌",dispatch],["收起货单",host._close_modal]],true)
func cargo()->void:
	if not host.state.heting_cargo.is_empty():loaded();return
	var available=host.state.available_heting_cargo("heting_cargo")
	if available.is_empty():
		_modal("中埠粮船","交割 / 两批已办","两张货签都盖了实交记号。空笼留在船边，没有第二份可重复领取的货。");return
	var choices:Array=[]
	for id in available:choices.append(["押"+CARGO_NAMES[id],_guard(take.bind(id))])
	choices.append(["先不提货",host._close_modal])
	_modal("中埠粮船","交割 / 一车一签","船工把板车推到栈边，两张货签各压在一批货上。\n\n开锅粮：米与干柴，送西岸粥棚。\n对秤封粮：同号船货中的两担，封口尚干，送东岸公秤棚当面复称。\n\n先押哪批，就先让哪一岸办成眼前的事。货不因你多走几步便坏掉。",choices,true)
func loaded()->void:
	var options:Array=[["继续押送",host._close_modal]]
	if _can_park_here():options.append(["退车归位",_guard(park)])
	_modal("押车货签","交割 / 一次只押一批","你正押着"+_cargo_name()+"，货签写明送往"+_receiver_name(_receiver_for(host.state.heting_cargo))+"。\n\n先交到指定处，或把这批退回原位，再换另一车。板车上不会同时压两张货签。\n\n载车走不了窄步栈，可走当前浮栈或上岸后的北街。",options,true)
func _resync_position()->void:
	host._sync_world_state()
	host.world.teleport(host.world.player_pos)
	host.state.position=host.world.player_pos
func _success_notice(text:String)->void:
	host._toast(text,false,3.0)
func take(id:String)->void:
	if not _at("heting_lighter" if id=="reserve" else "heting_cargo"):return
	if host.state.take_heting_cargo(id):
		_resync_position();host._close_modal();host._autosave();_success_notice("已押"+CARGO_NAMES[id]+"。货不扣行囊资源；请按货签交割。")
func _can_park_here()->bool:
	return _at("heting_dispatch") or _at("heting_lighter" if host.state.heting_cargo=="reserve" else "heting_cargo")
func park()->void:
	if not _can_park_here():return
	if host.state.park_heting_cargo():
		_resync_position();host._close_modal();host._autosave();_success_notice("未交货物已退回原位。已交记录和夜工草案保留。")
func winch()->void:
	var s=host.state;var choices:Array=[]
	if s.heting_bridge!="west":choices.append(["改接西岸",_guard(change_bridge.bind("west"))])
	if s.heting_bridge!="east":choices.append(["改接东岸",_guard(change_bridge.bind("east"))])
	choices.append(["保持原样",host._close_modal])
	_modal("双向绞缆机","港内行路 / 改泊浮栈","浮栈眼下接着"+("西岸粥棚" if s.heting_bridge=="west" else "东岸秤棚")+"。把副缆换到另一侧，板车便可从那一岸下台。\n\n改泊不花材料，也不改变已交货物。北边窄步栈始终留给行人；载车可走浮栈，或上岸后沿北街绕行。",choices,true)
func change_bridge(side:String)->void:
	if not _at("heting_winch"):return
	if host.state.set_heting_bridge(side):
		_resync_position();host._close_modal();host._autosave();_success_notice("浮栈已接往"+("西" if side=="west" else "东")+"岸。货物与草案不变。")
func receiver(id:String)->void:
	var s=host.state;var is_relief=id=="heting_relief";var title="顾婶 · 掌勺人" if is_relief else "施衡 · 秤房记手"
	if s.heting_cargo=="reserve":
		if id==_receiver_for("reserve"):final_confirmation(id);return
		var plan="short_ferries" if is_relief else "open_scale"
		_modal(title,"交割 / 先核对去处","货签写的是"+PLAN_NAMES[s.heting_draft]+"，这处不是约定的收货点。\n\n你可以照原案继续送，也可以现在改草案；改了以后仍须再确认交割，不会在这里悄悄换了结局。",[["照原案继续送",host._close_modal],["改作"+PLAN_NAMES[plan],_guard(choose.bind(plan,id))],["先离开",host._close_modal]],true);return
	if not s.heting_cargo.is_empty():
		if _receiver_for(s.heting_cargo)!=id:
			var options:Array=[["继续押送",host._close_modal]]
			if is_relief:options.append(["免费调息",_guard(rest)])
			_modal(title,"交割 / 货签各有所属","这批是"+_cargo_name()+"，货签写明送往"+_receiver_name(_receiver_for(s.heting_cargo))+"。这里只核实来货，不会替你把别处的货记成已交。",options,true);return
		var body="“就是这一车。米下锅，柴进灶，今晚先让等在岸边的人有一口热的。”\n\n顾婶核过货签，等你把这一批正式交下。交货得10修为，只记一次。" if is_relief else "两担封口都是干的，船货号也与抄件一致。\n\n“先别替整船下结论。我们当面复称这两担，把封口、担数、到港时刻一并记下。”\n\n不记船工姓名。交货得10修为，只记一次。"
		var choices:Array=[["交下开锅粮" if is_relief else "交粮当面复称",_guard(deliver.bind(id))],["先留在车上",host._close_modal]]
		if is_relief:choices.append(["借棚调息",_guard(rest)])
		_modal(title,"交割 / 当面接手",body,choices,true);return
	var text=""
	if s.heting_stage==4:
		text=aftermath(id)
	elif s.heting_delivered.has("meal" if is_relief else "sealed"):
		text=base_result(id)
	else:
		text="“锅已经洗好，等中埠那批米和干柴。你若先去对秤也成，别把这头忘了。”\n\n棚下有热水与干席，可以免费歇脚。带着车休息，货仍留在车上。" if is_relief else "“柜上已有一张水损票，写的是鹤字三号全船浸损。我只记过票，还没见过粮。”\n\n施衡挪开空秤：“把中埠那两担带来，让票也认认实物。”"
	var options:Array=[]
	if is_relief:options.append(["借棚调息",_guard(rest)])
	options.append(["告辞",host._close_modal])
	_modal(title,"一秤两岸 / 岸边所见",text,options,true)
func base_result(id:String)->String:
	var s=host.state
	var text="锅沿升起了白汽，空碗排到棚外。顾婶把实交记号写在货签上。\n\n“有饭不等于人人到得了这里。南泊那批粮，你们还得想想远处的人。”" if id=="heting_relief" else "施衡把两张纸并在秤旁：水损票早于到港，抽称的两担却仍是干粮。\n\n“至少这两担，不能跟着一张票就算坏了。有人先写好了损耗，再等水替他作证。”\n\n他另写复称签，只记货号、担数与时刻，留给船家和秤棚各一份。"
	if id=="heting_scale":text+="\n\n"+("路过的船家拿公示账的货号来核，两边对得上。" if s.chapter_two_ending=="open_records" else "核的是货号与时刻，原账中受保护的姓名仍未展开。")
	if s.heting_stage==2:text+="\n\n两批都已交妥。回北岸交割牌，与孟绫商议今晚的人手。"
	return text
func deliver(id:String)->void:
	if id not in ["heting_relief","heting_scale"] or not _at(id):return
	if host.state.deliver_heting_base(id):
		_resync_position();host._autosave();host._refresh()
		_modal("实交记号","交割完成 / 修为+10",base_result(id),[["收好货签",host._close_modal]],true)
func rest()->void:
	if not _at("heting_relief") or host.state.battle_active:return
	host.state.heal_rest();host._close_modal();host._autosave();_success_notice("棚下调息，气血与真气恢复。所押货物不变。")
func decision()->void:
	_modal("孟绫","今夜 / 粮够分，人只一班","“锅开了，假损耗也留下了对照。可南泊还有两担粮，今夜能轮出的埠工只有一班两人。”\n\n[color=#d3b276]短渡分粮[/color]：两人随船，把粮送给不便上岸的几处泊船；公秤棚夜里无人值守，新交割等天亮复核。\n\n[color=#d3b276]守秤留粮[/color]：两人留秤棚，粮作共同存粮，今晚交割有人复称；远泊的人仍须靠岸，或等明日短渡。\n\n“两边都有人肯接。你押最后一车，把同意的安排送到实处。”",[["拟作短渡分粮",_guard(choose.bind("short_ferries",""))],["拟作守秤留粮",_guard(choose.bind("open_scale",""))],["再想一想",host._close_modal]],true)
func choose(id:String,receiver_after:String="")->void:
	if receiver_after.is_empty():
		if not _at("heting_dispatch"):return
	elif receiver_after not in ["heting_relief","heting_scale"] or not _at(receiver_after) or host.state.heting_cargo!="reserve" or ("short_ferries" if receiver_after=="heting_relief" else "open_scale")!=id:return
	var changed=host.state.choose_heting_plan(id)
	var same=host.state.heting_stage==3 and host.state.heting_draft==id and host.state.Heting.PLANS.has(id)
	if not changed and not same:return
	if changed:host._autosave();host._refresh()
	if not receiver_after.is_empty() and host.state.heting_cargo=="reserve":final_confirmation(receiver_after)
	else:draft()
func draft()->void:
	var s=host.state
	var body="待分粮送西岸粥棚分装，两名埠工随短渡照应几处不便上岸的泊船。公秤棚夜里不留人，新交割等天亮复核。" if s.heting_draft=="short_ferries" else "待分粮送东岸公秤棚，列入共同存粮，两名埠工守秤复称。远泊的人仍须靠岸来领，或等明日短渡。"
	var options:Array=[["去南泊提货" if s.heting_cargo.is_empty() else "继续押送",host._close_modal],["重新商议",decision]]
	if not s.heting_cargo.is_empty():options.append(["退车归位",_guard(park)])
	options.append(["告辞",host._close_modal])
	_modal("孟绫","夜工草案 / "+PLAN_NAMES[s.heting_draft],"今夜先办"+PLAN_NAMES[s.heting_draft]+"。\n\n"+body+"\n\n这还是草案。最后一车正式交下前，仍可改议。装车、改泊、休息都不会锁定结局。",options,true)
func lighter()->void:
	var s=host.state
	if s.heting_stage==4:
		_modal("南泊短驳","一秤两岸 / 后来的船",aftermath("heting_lighter"));return
	if not s.heting_cargo.is_empty():loaded();return
	if s.heting_stage<3:
		_modal("南泊短驳","交割 / 待分粮","这两担待分粮已留好，船工没有催你付钱。\n\n"+("先交妥开锅粮与对秤封粮。" if s.heting_stage==1 else "先到交割牌，与孟绫议定今晚的人手。")+"\n\n粮不会因你离开一会儿便被收走。");return
	_modal("南泊短驳","交割 / 最后一车","船工将两担待分粮放上板车：“去处写明白了，接手的人才知道今晚守哪里。”\n\n草案："+PLAN_NAMES[s.heting_draft]+"\n收货："+_receiver_name(_receiver_for("reserve"))+"\n\n交货前仍可改议。这一批不花你的钱，也不扣行囊材料。",[["押待分粮",_guard(take.bind("reserve"))],["先不装车",host._close_modal]],true)
func final_confirmation(id:String)->void:
	var plan=host.state.heting_draft
	var body="“粮在这里分装，两名埠工随短渡走。先让那些不便上岸的人收到。”\n\n公秤棚今晚不留人，新交割等天亮复核。白日的复称签仍由两边保存。" if plan=="short_ferries" else "“粮入共同存粮，两名埠工留下守秤。今晚再来交割的船，都能当面复称。”\n\n远泊的人仍须靠岸来领，或等明日短渡。粥棚已下锅的粮照常分发。"
	_modal("顾婶与船工" if id=="heting_relief" else "施衡与埠工","交割确认 / "+PLAN_NAMES[plan],body+"\n\n照此交割后，今夜安排不再改换。得100修为、60文；此前两批不再重复计奖。",[["照此交割",_guard(finish.bind(id,plan))],["先不交货",host._close_modal],["回去改议",host._close_modal]],true)
func finish(id:String,expected_plan:String)->void:
	if id not in ["heting_relief","heting_scale"] or not _at(id):return
	if host.state.finish_heting_delivery(id,expected_plan):
		_resync_position();host._autosave();host._refresh()
		_modal("埠灯未尽","第四章完成 / "+PLAN_NAMES[host.state.heting_ending],aftermath(id)+"\n\n白日的复称签仍在两岸，各人认下今夜的差事。那笔提前结算的粮钱，还得沿真正的收货人往下查。\n\n获得100修为、60文。"+companion_line(),[["回访两岸",host._close_modal]],true)
	else:host._toast("货单或草案已有变化，请重新核对本次交割。")
func aftermath(id:String)->String:
	var short=host.state.heting_ending=="short_ferries"
	match id:
		"heting_relief":return "“分装时才看出来，等在锅前的只是看得见的人。短渡回程也写在牌上，不能只管送出去。”" if short else "“热饭照常分。有人问外埠怎么领，我把靠岸处指给他；走不过来的，还得等明日短渡。”"
		"heting_scale":return "“复称签没撤。只是夜里这把秤无人看，新来船的交割先搁到天亮。”" if short else "“这两担抽称粮怎样来的，写得清楚。共同存粮怎样出去，也得一样清楚。”"
		_:return "去回牌上记着几处泊船，不记领粮人的私事。近西岸的低灯还亮着，这一班短渡正在照约走。" if short else "短渡安稳系在南泊。两担待分粮已入公秤棚，船上的原位空了；这班船待明日再走。"
func companion_line()->String:
	var s=host.state
	if s.current_companion()=="沈青":
		if s.shen_care_stage<5:return "沈青：“先问谁到不了岸上，再问粮放在哪里。”"
		return "沈青：“岸上有了去处，还得记着那些走不到门前的人。”" if s.shen_care_choice=="shore" else "沈青：“送出去要有人，接回来也要有人。去回都写清楚。”"
	if s.current_companion()=="唐栖":return "唐栖：“改栈的法子留在牌背，让下一个轮值的人也会用。”" if s.tangqi_choice=="teach" else "唐栖：“两边缆位各有受力，别只照着一张旧图硬搬。”"
	return ""
func title()->String:return ["鹤汀来路","一车两岸","夜工待议","最后一车","埠灯未尽"][host.state.heting_stage]
func hint()->String:
	var s=host.state
	if s.heting_stage==0:return "沿听雨关东侧下埠道前往鹤汀埠，追看粮船的实交。"
	if not s.heting_cargo.is_empty():return "押"+_cargo_name()+"至"+_receiver_name(_receiver_for(s.heting_cargo))+"；窄步栈过不了车，可免费改泊或沿北岸绕行。"
	return {1:"中埠粮船有两批固定货：开锅粮送西岸，对秤封粮送东岸，可任选先后。",2:"两批已办妥。回北岸交割牌，与孟绫议定今夜的人手。",3:"到南泊短驳提待分粮；按草案交货前仍可改议。",4:"今夜已有实际安排。可回访两岸，或沿北岸山道返回。"}[s.heting_stage]
func target_id()->String:
	var s=host.state
	if s.map_id=="heting":
		if not s.heting_cargo.is_empty():return _receiver_for(s.heting_cargo)
		return {1:"heting_cargo",2:"heting_dispatch",3:"heting_lighter",4:"heting_dispatch"}.get(s.heting_stage,"heting_dispatch")
	if s.heting_stage in [1,2,3] or (s.heting_stage==0 and s.mist_stage==4 and s.map_id=="mistwood"):
		return {"qingwei":"exit_sluice","sluice":"exit_frostbridge","frostbridge":"exit_mistwood","mistwood":"exit_heting"}.get(s.map_id,"")
	return ""
func journal()->String:
	var s=host.state
	if s.heting_stage==0:return "\n\n[color=#d3b276]第四章 · 鹤汀来路[/color]\n"+hint() if s.mist_stage==4 else ""
	var text="\n\n[color=#d3b276]第四章 · 一秤两岸[/color]"
	for id in ["meal","sealed","reserve"]:text+="\n"+("✓ " if s.heting_delivered.has(id) else "◇ ")+CARGO_NAMES[id]
	text+="\n当前押车："+_cargo_name()+"；浮栈接"+("西岸" if s.heting_bridge=="west" else "东岸")+"。"
	if s.heting_delivered.has("sealed"):text+="\n复称发现：提前写成的全船浸损票，与抽称两担的干封不符。"
	if not s.heting_draft.is_empty():
		text+="\n"+("已定：" if s.heting_stage==4 else "草案：")+PLAN_NAMES[s.heting_draft]
		text+="\n公秤棚夜间不留人，新交割等天亮复核。" if s.heting_draft=="short_ferries" else "\n远泊的人仍须靠岸，或等明日短渡。"
	return text+"\n"+hint()
