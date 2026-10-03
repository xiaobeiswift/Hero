class_name AdvancedMartialUI
extends RefCounted
var host
const Rules=preload("res://scripts/advanced_martial_rules.gd")
const Arts=preload("res://scripts/martial_catalog.gd")
const DEED_NAMES={"sluice":"废闸水令查证","archive":"霜桥原账归处"}
func _init(owner)->void:host=owner
func learning()->void:
 if host.current_screen=="battle":return
 var s=host.state
 var body="[color=#d3b276]%s · 考绩%d[/color]\n查看藏页后研习，学会永久保留，不自动换装。\n\n" % [s.sect_rank_name(),s.sect_merit]
 var options:Array=[]
 for id in s.school_art_ids():
  var art=Arts.definition(id)
  if int(art.get("learn_cost",0))<=0:continue
  var owned=s.available_arts().has(id)
  var condition="已习得" if owned else ("可研习" if s.can_learn_art(id) else "需内门与足够考绩")
  body+="[color=#d3b276]%s · %d考绩 · %s[/color]\n%s\n\n" % [id,int(art.learn_cost),condition,summary(id)]
  options.append(["查看"+id,detail.bind(id)])
 if options.is_empty():body+="先取得门派荐帖，并通过岑远的内门验艺。"
 body+="完成废闸与霜桥故事后可各复命一次，取得额外考绩。"
 options.append(["江湖复命",deeds])
 options.append(["返回导师",host.sect_progress.show])
 host._modal("门中藏页","修行 / 各有所长",body,options,true)
func summary(id:String)->String:
 var s=host.state
 var a=Arts.definition(id)
 var parts:Array[String]=["伤%d" % Rules.direct_damage(a,s.effective_attack(),s.art_rank(id)),"气%d" % int(a.cost),"息%d" % int(a.cooldown)]
 if int(a.healing)>0:parts.append("回血%d" % int(a.healing))
 if a.guard:parts.append("守势")
 if int(a.get("weaken_amount",0))>0:parts.append("卸劲%d×%d击" % [int(a.weaken_amount),int(a.weaken_strikes)])
 var focus=Rules.focus_damage(a,s.effective_attack())
 if focus>0:parts.append("蓄锋+%d" % focus)
 return " · ".join(parts)
func detail(id:String)->void:
 if host.current_screen=="battle":return
 var s=host.state
 var art=Arts.definition(id)
 var owned=s.available_arts().has(id)
 var body=("[color=#d3b276]已习得[/color]\n" if owned else "")+s.art_description(id)+"\n\n一次研习需%d考绩。当前%d考绩。\n学会后永久保留；当前出战招式不会自动改变。\n\n卸劲按敌方实际攻击次数消耗；蓄锋保留到下一次平击，守势与服药不消耗。" % [int(art.learn_cost),s.sect_merit]
 var options:Array=[["前往武学",host._show_martials]] if owned else [["研习 · %d考绩" % int(art.learn_cost),learn.bind(id)]]
 options.append(["返回藏页",learning])
 host._modal(id,"门中藏页 / 招式详解",body,options,true)
func learn(id:String)->void:
 if host.state.learn_art(id):
  host._autosave();host._refresh();learning()
  host._toast("已习得"+id+"。当前招式不变，按K可在战前换装。")
 else:
  host._toast("研习未完成：需本派内门、足够考绩，且尚未习得；战中不可研习。")
func deeds()->void:
 if host.current_screen=="battle":return
 var s=host.state
 var eligible=s.eligible_sect_deeds()
 var body="岑远把荐帖翻到背面：‘功夫若只在院墙里有用，学得再熟也不够。’\n\n内门弟子完成下列江湖事件后，各可复命一次，得1考绩。不同故事选择的考绩相同，旧日经历也可补记。\n\n"
 var options:Array=[]
 for id in ["sluice","archive"]:
  var status="已复命" if s.claimed_deeds.has(id) else ("可领取1考绩" if eligible.has(id) else "尚未完成，或尚未晋入内门")
  body+="%s · %s\n" % [DEED_NAMES[id],status]
  if eligible.has(id):options.append(["复命·"+DEED_NAMES[id],claim.bind(id)])
 body+="\n当前考绩：%d。复命奖励只记一次，不要求重新战斗。" % s.sect_merit
 options.append(["返回藏页",learning])
 host._modal("江湖复命","门中考绩 / 以行证艺",body,options,true)
func claim(id:String)->void:
 if host.state.claim_sect_deed(id):
  host._autosave();host._refresh();deeds()
  host._toast(DEED_NAMES[id]+"已记入荐帖，考绩+1。")
 else:host._toast("这份考绩尚不能领取，或已领取；余额已满时可先研习。")
