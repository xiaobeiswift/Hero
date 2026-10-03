extends RefCounted
## A compact, read-only comparison of learned moves before choosing one for combat.
const Paper=preload("res://scripts/inventory_panel.gd")
const HeroArt=preload("res://scripts/painted_battle_hero.gd")
const Arts=preload("res://scripts/martial_catalog.gd")
const Rules=preload("res://scripts/advanced_martial_rules.gd")
const INK=Color("304a42")
const MUTED=Color("687668")
const GOLD=Color("947441")

static func show(host)->void:
	if host.current_screen in ["battle","receipt_battle"] or host.state.battle_active:return
	host.modal_generation+=1;host._clear_overlay();host.active_modal=true
	var generation:int=host.modal_generation
	var veil=ColorRect.new();veil.color=Color(.01,.04,.04,.76);veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);host.overlay.add_child(veil)
	var frame=host._panel(host.overlay,Rect2(72,55,1136,690),Color("133333"),Color("c5aa70"));frame.name="MartialFolio"
	var sheet=Paper.PaperSurface.new();sheet.position=Vector2(18,91);sheet.size=Vector2(1100,482);frame.add_child(sheet)
	text(host,frame,"武学与心得",Rect2(34,18,550,44),30,Color("efe4c8"))
	text(host,frame,"观其所长，再择一招出战。",Rect2(36,60,600,22),14,Color("b8c4aa"))
	text(host,frame,"%s · 考绩 %d"%[host.state.sect_rank_name(),host.state.sect_merit],Rect2(763,32,335,28),18,Color("d8bf87")).name="MartialRank"
	var current:Dictionary=Arts.definition(host.state.equipped_art)
	text(host,frame,"当 前 出 战",Rect2(41,111,248,23),13,MUTED)
	text(host,frame,host.state.equipped_art,Rect2(39,143,255,35),26,INK).name="EquippedArtTitle"
	text(host,frame,host.state.sect+" · "+Arts.rank_name(host.state.art_rank(host.state.equipped_art)),Rect2(41,182,250,24),15,GOLD)
	var figure=TextureRect.new();figure.name="MartialTraveller";figure.texture=HeroArt.texture_for("idle");figure.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;figure.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;figure.position=Vector2(40,211);figure.size=Vector2(252,247);figure.mouse_filter=Control.MOUSE_FILTER_IGNORE;frame.add_child(figure)
	text(host,frame,String(current.description),Rect2(42,467,248,58),16,INK).name="EquippedArtDescription"
	text(host,frame,"战斗中按 2 施展 · 战前可换招",Rect2(42,539,257,23),12,MUTED)
	var learned:Array=host.state.available_arts()
	var catalog:Array=host.state.school_art_ids()
	for i in range(catalog.size()):
		var id:String=catalog[i]
		var number:int=learned.find(id)+1
		card(host,frame,Rect2(333+(i%2)*384,109+(i/2)*231,370,224),id,number,generation)
	if catalog.size()==1:
		var note=host._panel(frame,Rect2(717,109,370,224),Color("d9d6bc"),Color("b9b799"));note.name="MartialInvitation"
		text(host,note,"门派荐帖",Rect2(24,25,318,33),23,INK)
		text(host,note,"完成青苇渡的失灯之事，\n再选一门适合自己的功夫。",Rect2(25,76,318,66),17,MUTED)
		text(host,note,"不同门派各有攻守，已学招式可在此比较。",Rect2(25,158,318,43),14,MUTED)
		text(host,frame,"以行证艺",Rect2(355,379,684,35),24,INK)
		text(host,frame,"真正施展招式才会积累心得。\n5次熟习，15次通明；更换出战招式不重置真气与调息。",Rect2(356,428,668,74),17,MUTED)
	var close=Paper.guarded(host,generation,host._close_modal);host.modal_actions.append(close)
	var button=host._button(frame,"返回江湖",Rect2(819,606,268,46),close);button.name="MartialClose"
	text(host,button,str(learned.size()+1),Rect2(12,13,28,21),14,Color("d8bd80"))
	text(host,frame,"数字键修习  ·  Enter / 空格选首项  ·  Esc 返回",Rect2(40,613,742,24),14,Color("c0c8ae"))
	text(host,frame,"基础伤害受敌势影响；卸劲按来击消耗，蓄锋留给下次平击。藏页需向岑远研习。",Rect2(40,657,1055,21),13,Color("9caf99"))

static func card(host,parent:Node,rect:Rect2,id:String,number:int,generation:int)->void:
	var art:Dictionary=Arts.definition(id)
	var owned:bool=number>0
	var selected:bool=host.state.equipped_art==id
	var color=Color("eef0d9") if selected else Color("dcdac2") if owned else Color("d4d3ba")
	var panel=host._panel(parent,rect,color,Color("8b9b73") if selected else Color("b7bd9f"));panel.name="ArtCard_"+id
	panel.tooltip_text=host.state.art_description(id)
	text(host,panel,String(art.style)+(" · 当前出战" if selected else " · 已习得" if owned else " · 藏页未习"),Rect2(16,8,338,19),12,GOLD if selected else MUTED)
	text(host,panel,id,Rect2(15,31,338,31),23,INK)
	text(host,panel,"真气 %d  ·  调息 %d 回合"%[int(art.cost),int(art.cooldown)],Rect2(17,70,337,24),15,MUTED).name="ArtCost"
	var effects:Array[String]=["基础伤害 %d"%Rules.direct_damage(art,host.state.effective_attack(),host.state.art_rank(id))]
	if int(art.healing)>0:effects.append("回血 %d"%int(art.healing))
	if art.guard:effects.append("守势 / 清破绽")
	if int(art.weaken_amount)>0:effects.append("卸劲 %d × %d击"%[int(art.weaken_amount),int(art.weaken_strikes)])
	var focus:int=Rules.focus_damage(art,host.state.effective_attack())
	if focus>0:effects.append("下次平击 +%d"%focus)
	text(host,panel," · ".join(effects),Rect2(17,103,337,36),15,INK).name="ArtEffects"
	if owned:
		var uses:int=int(host.state.art_uses.get(id,0));var rank:int=host.state.art_rank(id)
		var next:int=5 if rank==1 else 15
		var caption=Arts.rank_name(rank)+" · 已施展%d次"%uses
		if rank<3:caption+=" / %d次%s"%[next,Arts.rank_name(rank+1)]
		text(host,panel,caption,Rect2(17,144,337,22),13,MUTED).name="ArtProficiency"
		var bar=host._bar(panel,Rect2(17,171,336,4),Color("89935f"));bar.max_value=next;bar.value=mini(uses,next);bar.name="ArtPracticeBar"
		var action=Paper.guarded(host,generation,host._equip_art.bind(id));host.modal_actions.append(action)
		var button=host._button(panel,"修习 "+id,Rect2(17,184,337,32),action);button.name="ArtEquip"
		text(host,button,str(number),Rect2(9,7,23,20),12,Color("d8bd80"))
	else:
		text(host,panel,"需内门 · %d 考绩"%int(art.learn_cost),Rect2(17,144,337,23),13,MUTED)
		var button=host._button(panel,"到岑远处研习",Rect2(17,182,337,34),func():pass);button.disabled=true;button.name="ArtLocked"
		button.tooltip_text="与练武堂南庭的岑远交谈，查看门中藏页；这里不会花费考绩。"

static func text(host,parent:Node,value:String,rect:Rect2,pixels:int,color:Color)->Label:
	var result=Paper.text(host,parent,value,rect,pixels,color)
	# Reassert the requested width after theme/font sizing so long Chinese
	# descriptions wrap inside the left folio column instead of growing across it.
	result.size=rect.size
	result.set_deferred("size",rect.size)
	return result
