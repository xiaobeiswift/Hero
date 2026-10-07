extends Control
## Category view only. The host owns queued skills, automatic basics and round timing.
## Never creates absent actors, inferred commands, rule effects or target choices.
signal actor_requested(actor_id:String)
signal command_requested(actor_id:String,action_id:String)
signal cancel_queue_requested(actor_id:String,category:String)
signal pause_requested(paused:bool)
const Folio=preload("res://scripts/folio_theme.gd")
const FONT=preload("res://assets/fonts/NotoSansSC.otf")
const COMMAND_ATLAS=preload("res://assets/ui/martial_commands_painted_atlas.png")
const CATEGORY_ATLAS=preload("res://assets/ui/internal_lightness_painted_atlas.png")
const CATEGORY_ICON_IDS=["internal:hero_tiaoxi","internal:shen_yangmai","internal:tang_dingxi","internal:qin_guiyuan","lightness:hero_tawei","lightness:shen_liuying","lightness:tang_cunbu","lightness:qin_yanliu"]
const QIN_ATLAS=preload("res://assets/ui/qin_commands_painted_atlas.png")
const COMPANION_ATLAS=preload("res://assets/ui/companion_commands_painted_atlas.png")
const PORTRAITS={
	"hero":preload("res://assets/generated/characters/painted_hero_combat.png"),
	"shen":preload("res://assets/generated/characters/painted_shen_combat.png"),
	"tang":preload("res://assets/generated/characters/painted_tang_combat.png"),
	"qin":preload("res://assets/generated/characters/painted_qin_combat.png")
}
const CROP={"hero":Rect2(168,145,172,206),"shen":Rect2(121,70,180,212),"tang":Rect2(164,53,177,216),"qin":Rect2(186,18,164,210)}
const IVORY=Color("e8dbc1")
const GOLD=Color("d8ba7f")
const MUTED=Color("a7a995")
const INK=Color("171b19")
const CLUSTER_WIDTH=350.0
const MAX_ACTORS=4
const COMPACT_CLUSTER_WIDTH=299.0
const COMPACT_SLOT_SIZE=66.0
const CLUSTER_Y=616.0
const SLOT_ORDER=["martial","internal","lightness"]
const SLOT_LABELS={"martial":"主动武学","internal":"内功","lightness":"轻功"}
var snapshot:Dictionary={}
var context:Dictionary={}
var buttons:Dictionary={}
var actor_buttons:Dictionary={}
var groups:Dictionary={}
var command_rects:Dictionary={}
var descriptors:Dictionary={}
var portraits:Dictionary={}
var icons:Dictionary={}
var hover_key:String=""
var focus_key:String=""
var journal_open:bool=false
var pause_button:Button
var journal_button:Button
var readback_button:Button
var journal_text:RichTextLabel
var _style_cache:Dictionary={}
var revision:int=0
var _signature:String=""

func _ready()->void:
	size=Vector2(1280,800);mouse_filter=Control.MOUSE_FILTER_IGNORE
	for id:String in PORTRAITS:
		var crop=AtlasTexture.new();crop.atlas=PORTRAITS[id];crop.region=CROP[id];crop.filter_clip=true;portraits[id]=crop
	for atlas_key:String in ["common","companion"]:
		var atlas:Texture2D=COMMAND_ATLAS if atlas_key=="common" else COMPANION_ATLAS
		for i in range(4):
			var tex=AtlasTexture.new();tex.atlas=atlas;tex.region=Rect2(Vector2(i%2,i/2)*atlas.get_size()*.5,atlas.get_size()*.5);tex.filter_clip=true
			icons[atlas_key+str(i)]=tex
	for i in range(2):
		var tex=AtlasTexture.new();tex.atlas=QIN_ATLAS;tex.region=Rect2(Vector2(i*QIN_ATLAS.get_width()*.5,0),Vector2(QIN_ATLAS.get_width()*.5,QIN_ATLAS.get_height()));tex.filter_clip=true;icons["qin"+str(i)]=tex
	for i in range(CATEGORY_ICON_IDS.size()):
		var tex=AtlasTexture.new();tex.atlas=CATEGORY_ATLAS;var cell=CATEGORY_ATLAS.get_size()/Vector2(4,2)
		tex.region=Rect2(Vector2(i%4,i/4)*cell,cell);tex.filter_clip=true;icons[CATEGORY_ICON_IDS[i]]=tex
	pause_button=_button(Rect2(372,27,96,50));pause_button.pressed.connect(_request_pause)
	pause_button.mouse_entered.connect(_hover.bind("pause"));pause_button.mouse_exited.connect(_hover.bind(""))
	pause_button.focus_entered.connect(_focus.bind("pause"));pause_button.focus_exited.connect(_focus.bind(""))
	readback_button=_button(Rect2(487,20,306,65))
	readback_button.pressed.connect(_toggle_journal)
	readback_button.mouse_entered.connect(_hover.bind("readback"));readback_button.mouse_exited.connect(_hover.bind(""))
	readback_button.focus_entered.connect(_focus.bind("readback"));readback_button.focus_exited.connect(_focus.bind(""))
	journal_button=_button(Rect2(1135,744,118,48))
	journal_button.pressed.connect(_toggle_journal)
	journal_button.mouse_entered.connect(_hover.bind("journal"));journal_button.mouse_exited.connect(_hover.bind(""))
	journal_button.focus_entered.connect(_focus.bind("journal"));journal_button.focus_exited.connect(_focus.bind(""))
	journal_text=RichTextLabel.new();journal_text.position=Vector2(886,486);journal_text.size=Vector2(343,140)
	journal_text.add_theme_font_override("normal_font",FONT);journal_text.add_theme_font_size_override("normal_font_size",13)
	journal_text.add_theme_color_override("default_color",IVORY);journal_text.bbcode_enabled=false;journal_text.visible=false;add_child(journal_text)
	if not snapshot.is_empty():_sync_controls()
	queue_redraw()

func set_snapshot(value:Dictionary,view_context:Dictionary={})->void:
	if snapshot==value and context==view_context:return
	snapshot=value.duplicate(true);context=view_context.duplicate(true);revision+=1
	if is_inside_tree():_sync_controls()
	queue_redraw()

func _allies()->Array:return snapshot.get("actors",[])
func _actor(id:String)->Dictionary:
	for actor:Dictionary in _allies():
		if String(actor.get("id",""))==id:return actor
	return {}
func _category(action:Dictionary)->String:
	var value=String(action.get("slot",action.get("category","")))
	return value
func _slots(actor:Dictionary)->Array:
	var supplied:Array=actor.get("skill_slots",actor.get("actions",[]))
	var by_category:Dictionary={}
	for action:Dictionary in supplied:
		var category=_category(action)
		if category not in SLOT_ORDER or String(action.get("id","")) in ["attack","guard","item","flee"]:continue
		if not by_category.has(category):
			var copy=action.duplicate(true);copy.slot=category;by_category[category]=copy
	var result:Array=[]
	for category:String in SLOT_ORDER:
		result.append(by_category.get(category,{"id":"","slot":category,"name":"尚无招式","available":false,"empty":true,"reason":"此位置尚无可用技能","description":"此位置尚无可用技能","target_team":"none"}))
	return result
func slot_key(actor_id:String,category:String)->String:return _key(actor_id,"slot:"+category)
func slot_descriptor(actor_id:String,category:String)->Dictionary:
	for action:Dictionary in _slots(_actor(actor_id)):
		if action.slot==category:return action
	return {}
func _slot_reason(actor_id:String,action:Dictionary)->String:
	var actor=_actor(actor_id)
	if actor.is_empty():return "角色不在场"
	if not bool(snapshot.get("active",true)):return "交锋已结束"
	if bool(actor.get("incapacitated",false)) or int(actor.get("hp",0))<=0:return "已倒下"
	if bool(action.get("empty",false)) or not bool(action.get("learned",true)) or String(action.get("id","")).is_empty():return String(action.get("reason","此位置尚无可用技能"))
	if not String(context.get("input_block_reason","")).is_empty():return String(context.input_block_reason)
	if not bool(action.get("available",false)):return String(action.get("reason","此招不可用")) if not String(action.get("reason","")).is_empty() else "此招不可用"
	return ""
func _commands_locked()->bool:return bool(snapshot.get("locked",false)) or int(snapshot.get("pending_token",-1))>0
func _category_state(actor:Dictionary,category:String)->Dictionary:
	var value=actor.get("categories",{}).get(category,{})
	return value if value is Dictionary else {}
func _queued(actor:Dictionary,category:String)->bool:return bool(_category_state(actor,category).get("queued",false))
func queued_caption(actor:Dictionary,category:String)->String:
	var state=_category_state(actor,category)
	if not bool(state.get("queued",false)):return ""
	return "下轮待发" if int(state.get("queue_round",snapshot.get("round",0)))>int(snapshot.get("round",0)) else "本轮待发"
func basic_caption(actor:Dictionary)->String:
	if int(actor.get("hp",0))<=0:return "普攻 · 已倒下"
	if not bool(snapshot.get("active",true)):return "普攻 · 已结束"
	return "普攻 · 已出手" if bool(actor.get("basic_done",false)) else "普攻 · 待出手"
func _status_badges(actor:Dictionary)->Array:
	# Read only the presented snapshot; do not recompute stored effects from skills or attack.
	var status:Dictionary=actor.get("status",{})
	var badges:Array=[]
	for entry:Array in [
		["barrier","护",Color("102c2d"),Color("9eac7c"),Color("dceabb")],
		["vulnerability_hits","破绽",Color("3b2320"),Color("bc8568"),Color("f0b798")],
		["next_hit_reduction","卸",Color("143333"),Color("779d9e"),Color("b6e6e5")],
		["focused_damage","蓄锋",Color("342c16"),Color("bba05d"),Color("f1d58a")]
	]:
		var amount=int(status.get(entry[0],0))
		if amount>0:badges.append({"text":String(entry[1])+str(amount),"fill":entry[2],"border":entry[3],"color":entry[4]})
	return badges
func status_caption(actor_id:String)->String:
	var captions:PackedStringArray=[]
	for badge:Dictionary in _status_badges(_actor(actor_id)):captions.append(String(badge.text))
	return " · ".join(captions)
func _status_badge_rect(group:Rect2,index:int)->Rect2:
	return Rect2(group.position+Vector2(11,106-index*17),Vector2(54,17))
func _unit(id:String)->Dictionary:
	var ally=_actor(id)
	if not ally.is_empty():return ally
	for enemy:Dictionary in snapshot.get("enemies",[]):
		if String(enemy.get("id",""))==id:return enemy
	return {}
func _acting_id()->String:
	return String(context.get("acting_unit_id",snapshot.get("acting_unit_id","")))

func _action(actor:Dictionary,id:String)->Dictionary:
	if id in ["attack","guard"]:return {}
	for action:Dictionary in actor.get("actions",[])+_slots(actor):
		if String(action.get("id",""))==id:return action
	return {}
func _key(actor_id:String,action_id:String)->String:return actor_id+"::"+action_id

func action_reason(actor_id:String,action_id:String)->String:
	var actor=_actor(actor_id);var action=_action(actor,action_id)
	if action.is_empty():return "此招不可用"
	return _slot_reason(actor_id,action)

func _reason_for_key(key:String)->String:
	if not descriptors.has(key):return "此招不可用"
	var actor=_actor(String(key.split("::")[0]));var category=_category(descriptors[key])
	if _queued(actor,category) and bool(snapshot.get("active",true)) and String(context.get("input_block_reason","")).is_empty():return ""
	return _slot_reason(String(key.split("::")[0]),descriptors[key])

func is_compact()->bool:return _allies().size()>3
func utility_geometry(action_id:String)->Rect2:
	if action_id=="flee":return Rect2(1120,25,130,50)
	if is_compact():return Rect2(819,25,166,50) if action_id=="item" else Rect2(999,25,105,50)
	return Rect2(1135,651,118,82) if action_id=="item" else Rect2(1135,744,118,48)

func _sync_controls()->void:
	groups.clear();command_rects.clear();descriptors.clear()
	var actors:Array=_allies()
	var compact:bool=is_compact()
	var cluster_width:float=COMPACT_CLUSTER_WIDTH if compact else CLUSTER_WIDTH
	var total:float=actors.size()*cluster_width+maxi(0,actors.size()-1)*12
	var x:float=22 if compact else maxf(22,(1120-total)*.5)
	journal_button.position=utility_geometry("journal").position
	journal_button.size=utility_geometry("journal").size
	var signature_parts:Array[String]=[]
	for actor:Dictionary in actors:
		var id=String(actor.get("id",""));if id.is_empty():continue
		groups[id]=Rect2(x,CLUSTER_Y,cluster_width,176)
		var actions:Array=_slots(actor)
		# Three fixed category positions. Empty categories never shift hotkeys.
		for i in range(actions.size()):
			var action:Dictionary=actions[i];var action_id=String(action.get("id",""))
			var key=slot_key(id,String(action.slot))
			command_rects[key]=Rect2(x+74+i*73,663,COMPACT_SLOT_SIZE,100) if compact else Rect2(x+84+i*85,658,76,107)
			descriptors[key]=action
			signature_parts.append(key)
		x+=cluster_width+12
	var active=String(snapshot.get("selected_actor_id",""))
	var active_actor=_actor(active)
	for utility in ["item","flee"]:
		var action=_action(active_actor,utility)
		if not action.is_empty():
			var key=_key(active,utility)
			command_rects[key]=utility_geometry(utility)
			descriptors[key]=action;signature_parts.append(key)
	var signature="|".join(signature_parts)+str(groups)
	if signature!=_signature:
		var keep_focus:String=focus_key
		for button:Button in buttons.values():remove_child(button);button.queue_free()
		for button:Button in actor_buttons.values():remove_child(button);button.queue_free()
		buttons.clear();actor_buttons.clear()
		for id:String in groups:
			var r:Rect2=groups[id]
			var pick=_button(Rect2(r.position+Vector2(8,6),Vector2(58 if compact else 67,161)))
			pick.pressed.connect(_request_actor.bind(id))
			pick.mouse_entered.connect(_hover.bind("actor::"+id));pick.mouse_exited.connect(_hover.bind(""))
			pick.focus_entered.connect(_focus.bind("actor::"+id));pick.focus_exited.connect(_focus.bind(""))
			actor_buttons[id]=pick
		for key:String in command_rects:
			var button=_button(command_rects[key]);button.name=key.replace(":","_")
			button.pressed.connect(_request_command.bind(key))
			button.mouse_entered.connect(_hover.bind(key));button.mouse_exited.connect(_hover.bind(""))
			button.focus_entered.connect(_focus.bind(key));button.focus_exited.connect(_focus.bind(""))
			buttons[key]=button
		_signature=signature
		if buttons.has(keep_focus):buttons[keep_focus].grab_focus()
		elif keep_focus.begins_with("actor::") and actor_buttons.has(keep_focus.trim_prefix("actor::")):actor_buttons[keep_focus.trim_prefix("actor::")].grab_focus()
	for id:String in actor_buttons:
		var actor:Dictionary=_actor(id)
		actor_buttons[id].tooltip_text="%s · 气血%d/%d · 真气%d/%d\n点击安排此人的技能；出招中标记属于正在演出的角色"%[actor.get("name",""),int(actor.get("hp",0)),int(actor.get("max_hp",0)),int(actor.get("qi",0)),int(actor.get("max_qi",0))]
	for key:String in buttons:
		buttons[key].mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND if _reason_for_key(key).is_empty() else Control.CURSOR_ARROW
	readback_button.tooltip_text=readback_text()+("\n点击查看完整战报；Enter仍确认队友目标" if not String(context.get("selected_action_id","")).is_empty() else "\n点击或Enter打开完整战报")
	var logs=snapshot.get("log",[])
	journal_text.text="\n".join(logs) if logs is Array else String(logs)
	pause_button.tooltip_text="当前出招收束后暂停" if bool(snapshot.get("pause_requested",false)) and not bool(snapshot.get("paused",false)) else ("继续自动交锋" if bool(snapshot.get("paused",false)) else "在当前出招收束后暂停；暂停时仍可安排技能")
	_sync_journal()

func _button(rect:Rect2)->Button:
	var button=Button.new();button.position=rect.position;button.size=rect.size;button.flat=true;button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","disabled","focus"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	add_child(button);return button
func focus_actor_commands(actor_id:String)->bool:
	for action:Dictionary in _slots(_actor(actor_id)):
		var key=slot_key(actor_id,String(action.slot))
		if buttons.has(key):buttons[key].grab_focus();return true
	return false
func focus_actor_selector(actor_id:String)->bool:
	if not actor_buttons.has(actor_id):return false
	actor_buttons[actor_id].grab_focus();return true

func _request_actor(id:String)->void:
	var actor=_actor(id)
	if actor.is_empty() or not bool(snapshot.get("active",true)) or not String(context.get("input_block_reason","")).is_empty() or bool(actor.get("incapacitated",false)) or int(actor.get("hp",0))<=0:return
	actor_requested.emit(id)
func _request_command(key:String)->void:
	if not descriptors.has(key) or not _reason_for_key(key).is_empty():return
	var action:Dictionary=descriptors[key];var actor_id=String(key.split("::")[0]);var category=_category(action)
	if _queued(_actor(actor_id),category):
		cancel_queue_requested.emit(actor_id,category);return
	var action_id=String(action.get("id",""))
	if action_id.is_empty() or action_id in ["attack","guard"]:return
	command_requested.emit(actor_id,action_id)
func request_slot(actor_id:String,index:int)->void:
	if index<0 or index>=SLOT_ORDER.size():return
	_request_command(slot_key(actor_id,SLOT_ORDER[index]))
func request_utility(actor_id:String,action_id:String)->void:
	if action_id not in ["item","flee"]:return
	_request_command(_key(actor_id,action_id))
func _request_pause()->void:
	if not bool(snapshot.get("active",false)) or not String(context.get("input_block_reason","")).is_empty():return
	pause_requested.emit(not bool(snapshot.get("pause_requested",snapshot.get("paused",false))))
func _hover(key:String)->void:hover_key=key;_sync_journal();queue_redraw()
func _focus(key:String)->void:focus_key=key;_sync_journal();queue_redraw()
func _toggle_journal()->void:journal_open=not journal_open;_sync_journal();queue_redraw()
func _sync_journal()->void:
	if journal_text!=null:journal_text.visible=journal_open or hover_key=="journal" or focus_key=="journal"

func _draw()->void:
	if snapshot.is_empty():return
	_gradient(Rect2(0,0,1280,140),Color(.015,.02,.025,.82),Color(.015,.02,.025,0))
	_gradient(Rect2(0,596,1280,204),Color(.015,.02,.025,0),Color(.01,.018,.02,.98))
	_material(Rect2(18,612,1242,184),"textile_sample")
	draw_rect(Rect2(18,612,1242,184),Color(.025,.055,.065,.58))
	draw_line(Vector2(18,613),Vector2(1260,613),Folio.BRASS,1.2,true)
	draw_line(Vector2(18,796),Vector2(1260,796),Folio.BRASS.darkened(.35),1,true)
	_text(String(context.get("location","")),Vector2(35,34),12,MUTED)
	draw_string(Folio.HEADING_FONT,Vector2(35,65),String(context.get("title","交锋")),HORIZONTAL_ALIGNMENT_LEFT,-1,26,Folio.BONE)
	_header()
	var pause_rect=Rect2(372,27,96,50)
	_frame(pause_rect,Color("211f1a"),hover_key=="pause" or focus_key=="pause" or bool(snapshot.get("paused",false)))
	var pause_caption="继续" if bool(snapshot.get("paused",false)) else ("暂停中" if bool(snapshot.get("pause_requested",false)) else "暂停")
	_ink_text(pause_caption,pause_rect.get_center()+Vector2(0,6),16,IVORY,true)
	for actor:Dictionary in _allies():
		var id=String(actor.get("id",""))
		if groups.has(id):_cluster(actor,groups[id])
	_utilities()
	var focused:String=hover_key if not hover_key.is_empty() else focus_key
	if descriptors.has(focused):_tooltip(focused)
	if journal_open or focused=="journal":
		_frame(Rect2(868,441,380,204),INK,true);_ink_text("战报",Vector2(886,472),18,IVORY)
		_text("点击固定 · 可滚动",Vector2(1230,471),11,MUTED,false,true)
	var notice=String(context.get("target_prompt",context.get("notice","")))
	if not notice.is_empty():
		var area=notice_geometry(notice)
		_frame(area,Color(.09,.085,.07,.96),false)
		draw_multiline_string(FONT,area.position+Vector2(18,25),notice,HORIZONTAL_ALIGNMENT_LEFT,area.size.x-36,14,-1,GOLD)

func notice_geometry(message:String)->Rect2:
	var width=minf(380,FONT.get_string_size(message,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+36)
	var height=FONT.get_multiline_string_size(message,HORIZONTAL_ALIGNMENT_LEFT,width-36,14,-1).y+26
	return Rect2(1254-width,103,width,height)

func _visible_readback()->Dictionary:
	var data:Dictionary=context.get("combat_readback",{})
	var action:Dictionary=data.get("action",{})
	var result=String(data.get("result_text",""))
	var latest:Dictionary=data.get("latest_completed",{})
	var use_latest=not latest.is_empty() and (String(data.get("status",""))!="presenting" or (action.is_empty() and result.is_empty()))
	var view:Dictionary=latest if use_latest else data
	var visible_action:Dictionary=view.get("action",{})
	var events:Array=view.get("events",[])
	var displayed_round=int(visible_action.get("round",snapshot.get("round",1)))
	if visible_action.is_empty() and not events.is_empty():displayed_round=int(events[0].get("round",displayed_round))
	return {"action":visible_action,"result":String(view.get("result_text","")),"summary":String(view.get("summary",view.get("result_text",""))),"latest":use_latest,"round":displayed_round}

func readback_text()->String:
	var data:Dictionary=context.get("combat_readback",{})
	var view=_visible_readback();var action:Dictionary=view.action;var result:String=view.result
	var prefix="上次结算" if view.latest else "本次已呈现"
	if action.is_empty():
		if not result.is_empty():return prefix+"："+result
		return "正在安排："+String(data.get("command_actor_name",_actor(String(snapshot.get("selected_actor_id",""))).get("name","")))+"\n所选目标："+String(data.get("command_target_name","尚未选择"))
	return "%s：%s · %s\n实际目标：%s%s"%[prefix,action.get("source_name",""),action.get("name",""),action.get("target_name","无需目标"),("\n"+result) if not result.is_empty() else ("\n已收招；完整经过见战报" if view.latest else "\n效果尚未呈现")]

func _fit_text(value:String,at:Vector2,width:float,font_size:int,color:Color)->void:
	var rendered=value
	while rendered.length()>1 and FONT.get_string_size(rendered,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>width:
		rendered=rendered.left(rendered.length()-2)+"…" if rendered.ends_with("…") else rendered.left(rendered.length()-1)+"…"
	draw_string(FONT,at,rendered,HORIZONTAL_ALIGNMENT_LEFT,width,font_size,color)

func _header()->void:
	var rect=Rect2(487,20,306,65)
	_material(rect,"paper_sample");draw_rect(rect,Color(.93,.89,.8,.58))
	draw_rect(rect,Folio.BRASS,false,1.0)
	if hover_key=="readback" or focus_key=="readback":draw_rect(rect.grow(-3),Folio.INK,false,2)
	var data:Dictionary=context.get("combat_readback",{})
	var view=_visible_readback();var action:Dictionary=view.action;var result:String=view.summary
	var phase=String(context.get("phase_label","已暂停" if snapshot.get("paused",false) else "自动交锋"))
	if view.latest:phase="上次结算"
	_text("第%02d回合 · %s"%[int(view.round),phase],Vector2(499,37),11,Folio.SECONDARY_INK)
	_text("战报 ›",Vector2(781,37),10,Folio.SECONDARY_INK,false,true)
	if action.is_empty() and not result.is_empty():
		_fit_text("排招变化",Vector2(499,57),282,14,Folio.INK)
		_fit_text(result,Vector2(499,75),282,12,Folio.SECONDARY_INK)
	elif action.is_empty():
		_fit_text("正在安排："+String(data.get("command_actor_name",_actor(String(snapshot.get("selected_actor_id",""))).get("name",""))),Vector2(499,57),282,14,Folio.INK)
		_fit_text("所选目标："+String(data.get("command_target_name",_unit(String(snapshot.get("selected_target_id",""))).get("name","尚未选择"))),Vector2(499,75),282,12,Folio.SECONDARY_INK)
	else:
		_fit_text(String(action.get("source_name",""))+" · "+String(action.get("name","")),Vector2(499,57),282,14,Folio.INK)
		var second="→ "+String(action.get("target_name","无需目标"))
		if not result.is_empty():second+=" · "+result.trim_prefix(String(action.get("target_name","")))
		else:second+=" · 已收招" if view.latest else " · 效果未至"
		_fit_text(second,Vector2(499,75),282,12,Folio.SECONDARY_INK)

func _cluster(actor:Dictionary,rect:Rect2)->void:
	var id=String(actor.id)
	var active:bool=id==String(snapshot.get("selected_actor_id",""))
	var acting:bool=_commands_locked() and id==_acting_id()
	var dead:bool=bool(actor.get("incapacitated",false)) or int(actor.get("hp",0))<=0
	# Selection controls future commands; acting is the renderer's current actor.
	# Different labels and shapes keep those facts distinct even without color.
	if active:
		draw_rect(Rect2(rect.position,Vector2(rect.size.x,30)),Color("6c2c27"))
		draw_line(rect.position+Vector2(0,30),rect.position+Vector2(rect.size.x,30),Folio.BRASS,1,true)
	if acting:
		draw_rect(Rect2(rect.position+Vector2(1,33),Vector2(3,137)),Color("9bcaca"))
		draw_colored_polygon(PackedVector2Array([rect.position+Vector2(5,13),rect.position+Vector2(10,17),rect.position+Vector2(5,21)]),Color("a2d8d5"))
	if hover_key=="actor::"+id or focus_key=="actor::"+id:draw_rect(Rect2(rect.position+Vector2(7,5),Vector2(61,161)),Folio.BONE,false,2)
	draw_line(Vector2(rect.end.x+6,rect.position.y+10),Vector2(rect.end.x+6,rect.end.y-8),Color(.71,.63,.47,.38),1,true)
	_fit_text(String(actor.get("name","")),rect.position+Vector2(13,23),60,15,Folio.BONE if active else (IVORY if not dead else MUTED))
	if active:_text("指令",rect.position+Vector2(77,22),11,Folio.BONE)
	if acting:_text("出招中",rect.position+Vector2(117,22),11,Color("a2d8d5"))
	_text(basic_caption(actor),rect.position+Vector2(rect.size.x-13,23),11,Folio.BONE if active else (GOLD if acting else MUTED),false,true)
	if portraits.has(id):draw_texture_rect(portraits[id],Rect2(rect.position+Vector2(11,35),Vector2(54,77)),false,Color(.5,.5,.5) if dead else Color.WHITE)
	var badges=_status_badges(actor)
	for i in range(badges.size()):
		var badge:Dictionary=badges[i];var area=_status_badge_rect(rect,i)
		_box(area,badge.fill,badge.border,1)
		_ink_text(String(badge.text),area.position+Vector2(27,13),11,badge.color,true)
	var maximum=maxi(1,int(actor.get("max_hp",1)));var hp=maxi(0,int(actor.get("hp",0)))
	var bar=Rect2(rect.position+Vector2(11,128),Vector2(54,5))
	draw_rect(bar.grow(1),Color("595345"));draw_rect(bar,Color("311b19"))
	draw_rect(Rect2(bar.position,Vector2(bar.size.x*float(hp)/maximum,bar.size.y)),Color("bd4b38"))
	_text("%d/%d"%[hp,maximum],rect.position+Vector2(38,151),11,Color("cfbfa5"),true)
	for action:Dictionary in _slots(actor):_slot(actor,action)
	_qi(actor,rect.position+Vector2(74 if is_compact() else 84,158),rect.size.x-(74 if is_compact() else 84)-19)

func _slot(actor:Dictionary,action:Dictionary)->void:
	var category=String(action.slot);var key=slot_key(String(actor.id),category)
	var area:Rect2=command_rects[key];var rect=Rect2(area.position,Vector2.ONE*area.size.x)
	var reason=_reason_for_key(key);var available=reason.is_empty()
	var empty=bool(action.get("empty",false)) or not bool(action.get("learned",true)) or String(action.get("id","")).is_empty()
	var focus=key==hover_key or key==focus_key
	var selected=String(context.get("selected_actor_id",""))==String(actor.id) and String(context.get("selected_action_id",""))==String(action.get("id","")) and not empty
	var queued=not empty and _queued(actor,category)
	_text(SLOT_LABELS[category],Vector2(rect.get_center().x,655),10,Color("d6c09a") if not empty else MUTED,true)
	_frame(rect,Color("181b1d"),focus or selected or queued)
	var texture=_icon_for(String(actor.id),action)
	if texture!=null and not empty:draw_texture_rect(texture,rect.grow(-5),false,Color.WHITE if available or queued else Color(.52,.52,.52))
	else:
		_gradient(rect.grow(-5),Color("252923"),Color("101615"))
		for i in range(3):draw_line(rect.position+Vector2(13,20+i*12),rect.position+Vector2(rect.size.x-13,20+i*12),Color(.6,.53,.39,.12),1)
	draw_rect(rect.grow(-4),Color(0,0,0,.8),false,1.5)
	if String(actor.id)==String(snapshot.get("selected_actor_id","")):
		_box(Rect2(rect.position+Vector2(4,4),Vector2(17,17)),Color(.03,.03,.025,.94),Color("a58f63"),1)
		_ink_text(str(SLOT_ORDER.find(category)+1),rect.position+Vector2(12.5,17),11,IVORY if not empty else MUTED,true)
	if not empty and int(action.get("cost",0))>0:
		_box(Rect2(rect.end.x-31,rect.position.y+4,27,18),Color("44251a"),Color("a68d52"),1)
		_ink_text("%d气"%int(action.cost),Vector2(rect.end.x-17.5,rect.position.y+17),10,Color("edcb8c"),true)
	if empty:
		_ink_text(String(action.get("empty_label","未习得" if action.get("learned",true)==false else "尚无招式")),rect.get_center()+Vector2(0,8),12,MUTED,true)
	elif queued:
		_box(Rect2(rect.position+Vector2(5,rect.size.y-22),Vector2(rect.size.x-10,17)),Color("29321e"),Color("a89455"),1)
		_ink_text(queued_caption(actor,category),Vector2(rect.get_center().x,rect.end.y-9),11,Color("e1dbaa"),true)
	elif not available:
		if int(actor.get("hp",0))<=0 or bool(actor.get("incapacitated",false)) or not String(context.get("input_block_reason","")).is_empty():
			draw_rect(rect.grow(-5),Color(0,0,0,.42))
			_ink_text("倒下" if int(actor.get("hp",0))<=0 else "交锋中",rect.get_center()+Vector2(0,6),13,IVORY,true)
		elif int(action.get("cooldown_remaining",0))>0:
			draw_rect(rect.grow(-5),Color(.015,.02,.03,.55))
			_ink_text(str(action.cooldown_remaining),rect.get_center()+Vector2(0,8),27,IVORY,true)
			_ink_text("回合",Vector2(rect.get_center().x,rect.end.y-9),9,IVORY,true)
		else:
			draw_rect(Rect2(rect.position+Vector2(5,rect.size.y-23),Vector2(rect.size.x-10,18)),Color(.12,.06,.02,.93))
			var status="真气不足" if reason.contains("真气") else ("无治疗目标" if reason.contains("治疗") and reason.contains("目标") else ("无目标" if reason.contains("目标") else "不可用"))
			_ink_text(status,Vector2(rect.get_center().x,rect.end.y-10),10,Color("d5aa7b"),true)
	var name=String(action.get("name","")) if not empty else ""
	var name_size=13
	while name_size>10 and FONT.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,name_size).x>rect.size.x+4:name_size-=1
	_ink_text(name,Vector2(rect.get_center().x,747 if queued else 752),name_size,IVORY if available or queued else MUTED,true)
	if queued:
		var target_id=String(_category_state(actor,category).get("target_id",action.get("queued_target_id","")))
		var target_name=String(_unit(target_id).get("name",""))
		if not target_name.is_empty():_fit_text("→ "+target_name,Vector2(rect.position.x+1,763),rect.size.x-2,10,Color("e1dbaa"))

func _qi(actor:Dictionary,at:Vector2,available_width:float)->void:
	var maximum=maxi(1,int(actor.get("max_qi",1)));var qi=int(actor.get("qi",0))
	var width=available_width-45;var segment=(width-4*(maximum-1))/maximum
	for i in range(maximum):
		var rect=Rect2(at+Vector2(i*(segment+4),0),Vector2(segment,8))
		_box(rect.grow(1),Color("0a1013"),Color("625b48"),1)
		if i<qi:_gradient(rect,Color("82edf2"),Color("15698e"))
		else:draw_rect(rect,Color("12212b"))
	_text("%d/%d"%[qi,maximum],at+Vector2(available_width,9),11,Color("acd0d4"),false,true)

func _utilities()->void:
	var actor_id=String(snapshot.get("selected_actor_id",""));var actor=_actor(actor_id)
	var item=_action(actor,"item");var flee=_action(actor,"flee")
	if not item.is_empty():
		var key=_key(actor_id,"item");var r=utility_geometry("item")
		var available=action_reason(actor_id,"item").is_empty()
		var item_color=IVORY if available else Color("7f8277")
		var item_caption=utility_caption(actor_id,"item")
		_frame(r,Color(.09,.09,.075,.92),key==hover_key or key==focus_key)
		if is_compact():
			draw_texture_rect(icons.common3,Rect2(r.position+Vector2(5,5),Vector2(40,40)),false,Color.WHITE if available else Color(.28,.28,.28))
			_ink_text("4" if available else "×",r.position+Vector2(10,18),10,item_color)
			_ink_text("×%d"%int(snapshot.get("medicine",0)),r.position+Vector2(150,21),16,item_color,true)
			_text(String(item.get("name","回春散")),r.position+Vector2(52,21),13,item_color)
			_text(item_caption,r.position+Vector2(52,40),11,MUTED)
		else:
			draw_texture_rect(icons.common3,Rect2(r.position+Vector2(7,6),Vector2(50,50)),false,Color.WHITE if available else Color(.28,.28,.28))
			_ink_text("4" if available else "×",r.position+Vector2(15,19),10,item_color)
			_ink_text("×%d"%int(snapshot.get("medicine",0)),r.position+Vector2(83,31),17,item_color,true)
			_text(item_caption,r.position+Vector2(83,53),10,MUTED,true)
			_text(String(item.get("name","回春散")),r.position+Vector2(59,70),12,item_color,true)
	if not flee.is_empty():
		var key=_key(actor_id,"flee");var r=utility_geometry("flee")
		_frame(r,Color(.09,.09,.08,.87),key==hover_key or key==focus_key)
		var enabled=action_reason(actor_id,"flee").is_empty()
		_ink_text("5  退开" if enabled else "收招中",r.get_center()+Vector2(0,7),16,IVORY if enabled else Color("7f8277"),true)
	var journal=utility_geometry("journal")
	_frame(journal,Color(.09,.09,.08,.9),journal_open or hover_key=="journal" or focus_key=="journal")
	_ink_text("战报",journal.get_center()+Vector2(0,7),15,IVORY,true)

func utility_caption(actor_id:String,action_id:String)->String:
	var reason=action_reason(actor_id,action_id)
	if reason.is_empty():return String(_actor(actor_id).get("name",""))+"自用"
	if _commands_locked():return "交锋中 · 暂不可用"
	if reason.contains("本轮") and reason.contains("药"):return "本轮已用药"
	if reason.contains("气血"):return "气血充盈"
	if reason.contains("回春散"):return "药品不足"
	return reason

func _icon_for(actor_id:String,action:Dictionary)->Texture2D:
	var explicit=String(action.get("icon_key",""))
	if not explicit.is_empty():return icons.get(explicit,null)
	if icons.has(String(action.get("id",""))):return icons[String(action.id)]
	if String(action.get("id",""))=="item":return icons.common3
	if _category(action)!="martial":return null
	if actor_id=="shen":return icons.companion1
	if actor_id=="tang":return icons.companion3
	if actor_id=="qin":return icons.qin1
	return icons.common1
func _tooltip_content(key:String)->Dictionary:
	var action:Dictionary=descriptors[key];var actor_id=String(key.split("::")[0]);var category=_category(action)
	var description=String(action.get("description",""));var reason=_reason_for_key(key)
	var learned=bool(action.get("learned",true)) and not String(action.get("id","")).is_empty()
	var team=String(action.get("target_team",""))
	var target_label={"enemy":"敌方目标","ally":"我方目标","self":"自身","none":"无需目标"}.get(team,team)
	var lines:Array=[]
	lines.append({"text":description,"size":13,"color":Color("d6d4bf")})
	if learned:
		var target_line=target_label
		if category in SLOT_ORDER:target_line+=" · 施展时耗%d气"%int(action.get("cost",0))
		lines.append({"text":target_line,"size":12,"color":MUTED})
		var cooldown=int(action.get("cooldown_remaining",0));var eligible=int(action.get("eligible_round",0))
		var cooldown_line="冷却 %d 回合"%cooldown
		if eligible>int(snapshot.get("round",0)):cooldown_line+=" · 第%d回合可用"%eligible
		lines.append({"text":cooldown_line,"size":12,"color":MUTED})
	if not reason.is_empty() and reason!=description:lines.append({"text":reason,"size":12,"color":Color("dfa275")})
	var queued=_category_state(_actor(actor_id),category)
	if bool(queued.get("queued",false)):
		var round_number=int(queued.get("queue_round",snapshot.get("round",0)))
		var target_id=String(queued.get("target_id",action.get("queued_target_id","")))
		var target_name=String(_unit(target_id).get("name",""))
		var line=queued_caption(_actor(actor_id),category)+" · 第%d回合普攻前施展"%round_number
		if not target_name.is_empty():line+="\n目标："+target_name
		line+="\n施展前复核真气与目标；再次点击此槽取消"
		lines.append({"text":line,"size":12,"color":GOLD})
	var height=48.0
	for line:Dictionary in lines:
		line.height=FONT.get_multiline_string_size(String(line.text),HORIZONTAL_ALIGNMENT_LEFT,320,int(line.size),-1).y
		height+=float(line.height)+8
	return {"title":String(action.get("name",SLOT_LABELS.get(category,"技能"))),"lines":lines,"height":height}
func _tooltip(key:String)->void:
	var content=_tooltip_content(key);var height=float(content.height);var anchor:Rect2=command_rects[key]
	var origin=Vector2(clampf(anchor.get_center().x-178,24,900),96 if anchor.position.y<100 else maxf(96,606-height))
	_frame(Rect2(origin,Vector2(356,height)),INK,true)
	_ink_text(content.title,origin+Vector2(17,29),18,IVORY)
	var y=50.0
	for line:Dictionary in content.lines:
		draw_multiline_string(FONT,origin+Vector2(17,y),line.text,HORIZONTAL_ALIGNMENT_LEFT,320,int(line.size),-1,line.color)
		y+=float(line.height)+8

func _material(rect:Rect2,region_name:String)->void:
	# Sample at native pixel density; never enlarge a small texture patch.
	var region:Rect2=Folio.ATLAS_REGIONS[region_name]
	var y=0.0
	while y<rect.size.y:
		var x=0.0
		while x<rect.size.x:
			var extent=Vector2(minf(region.size.x,rect.size.x-x),minf(region.size.y,rect.size.y-y))
			draw_texture_rect_region(Folio.BACKING,Rect2(rect.position+Vector2(x,y),extent),Rect2(region.position,extent))
			x+=region.size.x
		y+=region.size.y

func _frame(rect:Rect2,fill:Color,highlight:bool)->void:
	var edge=Folio.BONE if highlight else Folio.BRASS.darkened(.25)
	draw_rect(rect.grow(1),Color(.01,.025,.03,.75))
	draw_rect(rect,fill);draw_rect(rect,edge,false,1.0)
	if highlight:
		draw_rect(rect.grow(-3),Color(edge,.75),false,1.0)
	for corner:Vector2 in [rect.position,rect.end]:
		var direction=1.0 if corner==rect.position else -1.0
		draw_line(corner,corner+Vector2(7*direction,0),edge,1.4,true)
		draw_line(corner,corner+Vector2(0,7*direction),edge,1.4,true)

func _box(rect:Rect2,color:Color,border:Color,radius:int)->void:
	var key=color.to_html()+border.to_html()+str(radius)
	if not _style_cache.has(key):
		var style=StyleBoxFlat.new();style.bg_color=color;style.border_color=border;style.set_border_width_all(1);style.set_corner_radius_all(radius);_style_cache[key]=style
	draw_style_box(_style_cache[key],rect)
func _gradient(rect:Rect2,top:Color,bottom:Color)->void:
	draw_polygon(PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]),PackedColorArray([top,top,bottom,bottom]))
func _text(value:String,at:Vector2,font_size:int,color:Color,center:bool=false,right:bool=false)->void:
	var width=FONT.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	if center:at.x-=width*.5
	elif right:at.x-=width
	draw_string(FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
func _ink_text(value:String,at:Vector2,font_size:int,color:Color,center:bool=false)->void:
	if center:at.x-=FONT.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*.5
	draw_string_outline(FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,3,Color(.015,.015,.01,.96))
	draw_string(FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
