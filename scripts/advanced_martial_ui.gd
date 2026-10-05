class_name AdvancedMartialUI
extends RefCounted
var host
const Rules=preload("res://scripts/advanced_martial_rules.gd")
const Arts=preload("res://scripts/martial_catalog.gd")
const Paper=preload("res://scripts/inventory_panel.gd")
const Folio=preload("res://scripts/folio_theme.gd")
const Modal=preload("res://scripts/dialogue_sheet.gd")
# Small warning ink retains margin over painted paper, including compact views.
const WARNING_INK=Color("421a16")
const DEED_NAMES={"sluice":"废闸水令查证","archive":"霜桥原账归处"}
func _init(owner)->void:host=owner
func learning()->void:
 if host.current_screen=="battle":return
 var expected_generation:int=host.modal_generation+1
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
 _present("learning",expected_generation)
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
 var expected_generation:int=host.modal_generation+1
 var s=host.state
 var art=Arts.definition(id)
 var owned=s.available_arts().has(id)
 var body=("[color=#d3b276]已习得[/color]\n" if owned else "")+s.art_description(id)+"\n\n一次研习需%d考绩。当前%d考绩。\n学会后永久保留；当前出战招式不会自动改变。\n\n卸劲按敌方实际攻击次数消耗；蓄锋保留到下一次平击，守势与服药不消耗。" % [int(art.learn_cost),s.sect_merit]
 var options:Array=[["前往武学",host._show_martials]] if owned else [["研习 · %d考绩" % int(art.learn_cost),learn.bind(id)]]
 options.append(["返回藏页",learning])
 host._modal(id,"门中藏页 / 招式详解",body,options,true)
 _present("detail",expected_generation,id)
func learn(id:String)->void:
 if host.state.learn_art(id):
  host._autosave();host._refresh();learning()
  host._toast("已习得"+id+"。当前招式不变，按K可在战前换装。")
 else:
  host._toast("研习未完成：需本派内门、足够考绩，且尚未习得；战中不可研习。")
func deeds()->void:
 if host.current_screen=="battle":return
 var expected_generation:int=host.modal_generation+1
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
 _present("deeds",expected_generation)
func claim(id:String)->void:
 if host.state.claim_sect_deed(id):
  host._autosave();host._refresh();deeds()
  host._toast(DEED_NAMES[id]+"已记入荐帖，考绩+1。")
 else:host._toast("这份考绩尚不能领取，或已领取；余额已满时可先研习。")

# Presentation is applied only after the original modal accepts the page.
# The model, original text/options and Main-owned numeric action list remain authoritative.
func _present(page:String,generation:int,id:String="")->void:
 if not is_instance_valid(host) or not host.active_modal or host.modal_generation!=generation:return
 var previous=host.overlay.find_child("DialogueSheet",true,false)
 if not is_instance_valid(previous):return # Preserve rejected and title-screen paths.
 var old_title=previous.find_child("DialogueTitle",true,false)
 var wanted_title=id if page=="detail" else "江湖复命" if page=="deeds" else "门中藏页"
 if not is_instance_valid(old_title) or old_title.text!=wanted_title:return
 var ids:Array[String]=[]
 if page=="learning":
  for art_id:String in host.state.school_art_ids():
   if int(Arts.definition(art_id).get("learn_cost",0))>0:ids.append(art_id)
  if ids.size()>2:return # Future larger catalogues retain the original scrolling page.
 var eligible:Array=host.state.eligible_sect_deeds() if page=="deeds" else []
 var expected_count:int=ids.size()+2 if page=="learning" else eligible.size()+1 if page=="deeds" else 2
 if host.modal_actions.size()!=expected_count:return
 var captions:Array[String]=[]
 for i in range(expected_count):
  var old_button=previous.find_child("DialogueChoice"+str(i+1),true,false)
  if not is_instance_valid(old_button):return
  captions.append(old_button.text)
 # Reuse the already-generated guards, without wrapping, appending, replacing,
 # disabling or reordering any production action. Locked learning still explains failure.
 var actions:Array=host.modal_actions.duplicate()
 host.overlay.remove_child(previous);previous.queue_free()
 for child in host.overlay.get_children():
  if child is ColorRect:child.color=Color(.01,.04,.04,.78)
 var frame=host._panel(host.overlay,Rect2(40,30,1200,714),Color.TRANSPARENT,Color.TRANSPARENT)
 frame.name="CultivationFolio";frame.set_meta("cultivation_page",page);frame.set_meta("cultivation_art",id)
 frame.add_theme_stylebox_override("panel",Folio.style(Color.TRANSPARENT))
 Folio.backing(frame,Rect2(0,0,1200,714))
 var wash=Paper.InventoryReadingPaper.new();wash.name="CultivationReadingPaper";wash.position=Vector2(438,130);wash.size=Vector2(744,560);wash.strength=.88;wash.mouse_filter=Control.MOUSE_FILTER_IGNORE;frame.add_child(wash)
 _heading(frame,"门中修行",Rect2(138,26,250,45),34,Folio.BONE,"CultivationSeriesTitle")
 _text(frame,"观其所长，以行证艺。",Rect2(138,82,250,32),17,Folio.BRASS)
 _account(frame,page,id)
 _text(frame,{"learning":"修行 / 各有所长","detail":"门中藏页 / 招式详解","deeds":"门中考绩 / 以行证艺"}[page],Rect2(456,38,510,28),17,Folio.SECONDARY_INK,"CultivationEyebrow")
 _heading(frame,wanted_title,Rect2(456,78,662,49),36,Folio.INK,"DialogueTitle")
 Folio.rule(frame,Rect2(456,135,662,1),Folio.BRASS)
 var close=host._button(frame,"Esc 返回",Rect2(1008,20,166,45),Modal.guarded(host,generation,host._close_modal));close.name="CultivationClose";Folio.skin_button(close,"header_close");close.add_theme_font_size_override("font_size",19)
 if page=="learning":_learning_page(frame,ids,actions,captions)
 elif page=="detail":_detail_page(frame,id,actions,captions)
 else:_deeds_page(frame,eligible,actions,captions)
 # Center the book + separate key strip as one composition. At 960x600 the
 # last strip ends at 582.75, leaving 17.25 screen pixels before the lower edge.
 var backing=ColorRect.new();backing.name="CultivationHelpBacking";backing.position=Vector2(128,715);backing.size=Vector2(1018,32);backing.color=Color("132226");backing.mouse_filter=Control.MOUSE_FILTER_IGNORE;frame.add_child(backing)
 var help="数字键选择  ·  Enter / 空格选首项  ·  Esc 返回"
 if page=="detail":help="招式正文可滚动 / 选取  ·  "+help
 _text(frame,help,Rect2(138,719,995,26),16,Folio.BONE,"DialogueHelp")

func _account(frame:Control,page:String,id:String)->void:
 var s=host.state
 _text(frame,s.sect_rank_name(),Rect2(138,145,250,30),21,Folio.BONE,"CultivationRank")
 _text(frame,s.sect,Rect2(138,183,250,28),18,Folio.BRASS,"CultivationSect")
 _text(frame,"当前考绩",Rect2(138,232,250,27),17,Folio.BRASS)
 _heading(frame,str(s.sect_merit),Rect2(138,264,250,58),45,Folio.BONE,"CultivationMerit")
 Folio.rule(frame,Rect2(138,338,250,1),Folio.BRASS.darkened(.2))
 if page=="learning":
  Folio.mark(frame,"book",Rect2(138,358,42,42),Folio.BONE)
  _heading(frame,"藏页研习",Rect2(194,360,194,36),25,Folio.BONE)
  _copyable(frame,"查看藏页后研习，学会永久保留，不自动换装。",Rect2(138,414,250,114),18,Folio.BONE,"CultivationLearningPolicy")
  _text(frame,"当前出战",Rect2(138,568,250,27),17,Folio.BRASS)
  _heading(frame,s.equipped_art,Rect2(138,606,250,38),27,Folio.BONE,"CultivationEquippedArt")
  _text(frame,"研习不会改动此招",Rect2(138,654,250,27),17,Folio.BONE)
 elif page=="detail":
  _text(frame,"本页研习所需",Rect2(138,358,250,27),17,Folio.BRASS)
  _heading(frame,"%d 考绩"%int(Arts.definition(id).learn_cost),Rect2(138,397,250,44),32,Folio.BONE,"CultivationRequiredMerit")
  _copyable(frame,"一次研习需%d考绩。当前%d考绩。"%[int(Arts.definition(id).learn_cost),s.sect_merit],Rect2(138,461,250,86),18,Folio.BONE,"CultivationCostDisclosure")
  Folio.rule(frame,Rect2(138,568,250,1),Folio.BRASS.darkened(.2))
  _text(frame,"当前出战",Rect2(138,584,250,27),17,Folio.BRASS)
  _heading(frame,s.equipped_art,Rect2(138,619,250,38),27,Folio.BONE,"CultivationEquippedArt")
 else:
  Folio.mark(frame,"compass",Rect2(138,358,42,42),Folio.BONE)
  _heading(frame,"以行证艺",Rect2(194,360,194,36),25,Folio.BONE)
  _copyable(frame,"岑远把荐帖翻到背面：‘功夫若只在院墙里有用，学得再熟也不够。’",Rect2(138,414,250,161),18,Folio.BONE,"CultivationDeedQuote")
  var claimed:int=0
  for deed_id:String in ["sluice","archive"]:
   if s.claimed_deeds.has(deed_id):claimed+=1
  _text(frame,"已复命 %d / 2"%claimed,Rect2(138,612,250,30),21,Folio.BONE,"CultivationDeedCount")
  _text(frame,"每件故事，只记一次",Rect2(138,654,250,27),17,Folio.BRASS)

func _learning_page(frame:Control,ids:Array[String],actions:Array,captions:Array[String])->void:
 if ids.is_empty():
  Folio.mark(frame,"book",Rect2(472,180,62,62),Folio.SECONDARY_INK)
  _heading(frame,"门派荐帖",Rect2(552,187,538,42),30,Folio.INK)
  _copyable(frame,"先取得门派荐帖，并通过岑远的内门验艺。",Rect2(472,272,626,94),21,Folio.INK,"CultivationInvitation")
 else:
  for i in range(ids.size()):
   var id:String=ids[i];var art:Dictionary=Arts.definition(id);var owned:bool=host.state.available_arts().has(id)
   var condition:String="已习得" if owned else "可研习" if host.state.can_learn_art(id) else "需内门与足够考绩"
   var row=_row(frame,Rect2(456,155+i*202,662,185),"CultivationArt_"+id)
   Folio.mark(row,"book",Rect2(18,19,30,30),Folio.SECONDARY_INK)
   _heading(row,id,Rect2(60,12,356,43),29,Folio.INK,"CultivationArtTitle")
   _text(row,"研习需 %d 考绩"%int(art.learn_cost),Rect2(18,70,206,30),18,Folio.SECONDARY_INK,"CultivationArtCost")
   _text(row,condition,Rect2(238,70,406,30),18,Folio.SECONDARY_INK if owned or host.state.can_learn_art(id) else WARNING_INK,"CultivationArtStatus")
   _copyable(row,summary(id),Rect2(18,115,626,58),19,Folio.INK,"CultivationArtSummary")
   _action(row,captions[i],Rect2(444,16,200,46),actions[i],i+1,false)
 _copyable(frame,"完成废闸与霜桥故事后可各复命一次，取得额外考绩。",Rect2(472,564,626,59),19,Folio.SECONDARY_INK,"CultivationDeedInvitation")
 _action(frame,captions[ids.size()],Rect2(456,642,314,45),actions[ids.size()],ids.size()+1,not host.state.eligible_sect_deeds().is_empty())
 _action(frame,captions[ids.size()+1],Rect2(804,642,314,45),actions[ids.size()+1],ids.size()+2,false)

func _detail_page(frame:Control,id:String,actions:Array,captions:Array[String])->void:
 var owned:bool=host.state.available_arts().has(id)
 var ready:bool=host.state.can_learn_art(id)
 var condition:String="已习得" if owned else "可研习" if ready else "需内门与足够考绩"
 Folio.rule(frame,Rect2(456,153,662,37),Folio.CLOTH).name="CultivationArtStateBacking"
 _text(frame,condition,Rect2(472,157,626,28),18,Folio.BONE,"CultivationArtState")
 _text(frame,"招式与效果",Rect2(472,206,626,28),18,Folio.SECONDARY_INK)
 var description=_copyable(frame,host.state.art_description(id),Rect2(472,247,626,139),20,Folio.INK,"DialogueBody")
 description.scroll_active=true;description.add_theme_constant_override("line_separation",5)
 Folio.scrollbar(description.get_v_scroll_bar());Folio.scroll_edges(frame,description.get_v_scroll_bar(),description.get_rect())
 Folio.rule(frame,Rect2(456,409,662,1),Folio.BRASS)
 _heading(frame,"用法要诀",Rect2(472,421,626,36),25,Folio.INK)
 _copyable(frame,"卸劲按敌方实际攻击次数消耗；蓄锋保留到下一次平击，守势与服药不消耗。",Rect2(472,473,626,65),19,Folio.INK,"CultivationEffectPolicy")
 _copyable(frame,"学会后永久保留；当前出战招式不会自动改变。",Rect2(472,556,626,53),19,Folio.INK,"CultivationEquipPolicy")
 _action(frame,captions[0],Rect2(456,642,314,45),actions[0],1,owned or ready)
 _action(frame,captions[1],Rect2(804,642,314,45),actions[1],2,false)

func _deeds_page(frame:Control,eligible:Array,actions:Array,captions:Array[String])->void:
 _copyable(frame,"内门弟子完成下列江湖事件后，各可复命一次，得1考绩。不同故事选择的考绩相同，旧日经历也可补记。",Rect2(472,157,626,96),19,Folio.INK,"CultivationDeedPolicy")
 var action_index:int=0
 for i in range(2):
  var id:String=["sluice","archive"][i]
  var claimed:bool=host.state.claimed_deeds.has(id)
  var status:String="已复命" if claimed else "可领取1考绩" if eligible.has(id) else "尚未完成，或尚未晋入内门"
  var row=_row(frame,Rect2(456,268+i*166,662,152),"CultivationDeed_"+id)
  Folio.mark(row,"compass" if id=="sluice" else "book",Rect2(18,19,28,28),Folio.SECONDARY_INK)
  _heading(row,DEED_NAMES[id],Rect2(58,12,442,41),27,Folio.INK,"CultivationDeedTitle")
  _text(row,status,Rect2(18,64,626,29),18,Folio.SECONDARY_INK if claimed or eligible.has(id) else WARNING_INK,"CultivationDeedStatus")
  _text(row,"一次奖励 · 1考绩",Rect2(18,109,330,28),17,Folio.SECONDARY_INK,"CultivationDeedReward")
  if eligible.has(id):
   _action(row,captions[action_index],Rect2(372,100,272,43),actions[action_index],action_index+1,true)
   action_index+=1
 _copyable(frame,"当前考绩：%d。复命奖励只记一次，不要求重新战斗。"%host.state.sect_merit,Rect2(472,603,626,47),18,Folio.INK,"CultivationDeedSafety")
 _action(frame,captions[action_index],Rect2(456,653,260,40),actions[action_index],action_index+1,false)

func _row(parent:Control,rect:Rect2,node_name:String)->Panel:
 var row=host._panel(parent,rect,Color.TRANSPARENT,Color.TRANSPARENT);row.name=node_name
 row.add_theme_stylebox_override("panel",Folio.style(Color(.25,.19,.1,.015),Folio.BRASS,1))
 return row

func _action(parent:Control,caption:String,rect:Rect2,action:Callable,number:int,primary:bool)->Button:
 var button=host._button(parent,caption,rect,action);button.name="DialogueChoice"+str(number);Folio.skin_button(button,"primary" if primary else "paper_quiet");button.add_theme_font_size_override("font_size",19)
 if not primary:button.add_theme_stylebox_override("normal",Folio.style(Color(.12,.15,.12,.025),Folio.BRASS,1))
 for key:String in ["normal","hover","pressed","disabled"]:
  var box=button.get_theme_stylebox(key).duplicate();box.content_margin_left=44 if primary else 32;box.content_margin_right=8;button.add_theme_stylebox_override(key,box)
 _text(button,str(number),Rect2(23 if primary else 10,(rect.size.y-27)*.5,23,27),17,Folio.BONE if primary else Folio.INK,"ChoiceNumber")
 button.tooltip_text=caption
 return button

func _text(parent:Node,value:String,rect:Rect2,pixels:int,color:Color,node_name:String="")->Label:
 return Paper.folio_text(host,parent,value,rect,pixels,color,node_name)

func _heading(parent:Node,value:String,rect:Rect2,pixels:int,color:Color,node_name:String="")->Label:
 return Paper.folio_heading(host,parent,value,rect,pixels,color,node_name)

func _copyable(parent:Node,value:String,rect:Rect2,pixels:int,color:Color,node_name:String)->RichTextLabel:
 var label=RichTextLabel.new();label.name=node_name;label.position=rect.position;label.size=rect.size;label.bbcode_enabled=true;label.text=value;label.scroll_active=false;label.selection_enabled=true;label.focus_mode=Control.FOCUS_NONE
 label.add_theme_font_override("normal_font",Folio.BODY_FONT);label.add_theme_font_size_override("normal_font_size",pixels);label.add_theme_color_override("default_color",color);label.add_theme_color_override("font_selected_color",Folio.BONE);label.add_theme_color_override("selection_color",Folio.INK);parent.add_child(label)
 return label
