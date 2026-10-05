extends RefCounted
## Original folio comparison; catalogue, learning, equipment and save rules stay in HeroState.
const Paper=preload("res://scripts/inventory_panel.gd")
const HeroArt=preload("res://scripts/painted_battle_hero.gd")
const Arts=preload("res://scripts/martial_catalog.gd")
const Rules=preload("res://scripts/advanced_martial_rules.gd")
const Folio=preload("res://scripts/folio_theme.gd")
const INK=Folio.INK
const MUTED=Folio.SECONDARY_INK
const GOLD=Folio.BRASS

static func show(host)->void:
	if host.current_screen in ["battle","receipt_battle"] or host.state.battle_active:return
	host.modal_generation+=1;host._clear_overlay();host.active_modal=true
	var generation:int=host.modal_generation
	var veil=ColorRect.new();veil.color=Color(.01,.04,.04,.78);veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);host.overlay.add_child(veil)
	var frame=host._panel(host.overlay,Rect2(40,46,1200,714),Color.TRANSPARENT,Color.TRANSPARENT);frame.name="MartialFolio"
	frame.add_theme_stylebox_override("panel",Folio.style(Color.TRANSPARENT))
	Folio.backing(frame,Rect2(0,0,1200,714))
	var wash=Paper.InventoryReadingPaper.new();wash.name="MartialReadingPaper";wash.position=Vector2(438,130);wash.size=Vector2(744,560);wash.strength=.84;wash.mouse_filter=Control.MOUSE_FILTER_IGNORE;frame.add_child(wash)
	heading(host,frame,"武 学",Rect2(138,26,250,45),34,Folio.BONE).name="MartialTitle"
	text(host,frame,"观其所长，再择一招出战。",Rect2(138,82,250,48),17,Folio.BRASS)
	var current:Dictionary=Arts.definition(host.state.equipped_art)
	text(host,frame,"当 前 出 战",Rect2(138,145,250,26),15,Folio.BRASS)
	heading(host,frame,host.state.equipped_art,Rect2(138,181,250,43),30,Folio.BONE).name="EquippedArtTitle"
	text(host,frame,host.state.sect+" · "+Arts.rank_name(host.state.art_rank(host.state.equipped_art)),Rect2(138,232,250,28),18,Folio.BRASS)
	var figure=TextureRect.new();figure.name="MartialTraveller";figure.texture=HeroArt.texture_for("idle");figure.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;figure.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;figure.position=Vector2(140,270);figure.size=Vector2(248,223);figure.mouse_filter=Control.MOUSE_FILTER_IGNORE;frame.add_child(figure)
	text(host,frame,String(current.description),Rect2(138,501,248,83),17,Folio.BONE).name="EquippedArtDescription"
	Folio.rule(frame,Rect2(138,598,250,1),Folio.BRASS.darkened(.2))
	text(host,frame,"战斗中按 1 排定武学 · 战前可换招",Rect2(138,612,250,46),16,Folio.BONE).name="MartialCombatHint"
	text(host,frame,"更换不重置真气与调息",Rect2(138,665,250,27),16,Folio.BRASS).name="MartialResourceHint"
	text(host,frame,"招式比较 / 已习与藏页",Rect2(456,38,510,28),18,MUTED)
	heading(host,frame,"武学与心得",Rect2(456,78,420,49),36,INK).name="MartialPageTitle"
	text(host,frame,"%s · 考绩 %d"%[host.state.sect_rank_name(),host.state.sect_merit],Rect2(842,92,276,28),18,MUTED).name="MartialRank"
	Folio.rule(frame,Rect2(456,135,662,1),Folio.BRASS)
	var learned:Array=host.state.available_arts()
	var catalog:Array=host.state.school_art_ids()
	for i in range(catalog.size()):
		var id:String=catalog[i]
		var number:int=learned.find(id)+1
		card(host,frame,Rect2(456+(i%2)*342,151+(i/2)*262,320,248),id,number,generation)
	if catalog.size()==1:
		var note=host._panel(frame,Rect2(798,151,320,248),Color.TRANSPARENT,Color.TRANSPARENT);note.name="MartialInvitation"
		note.add_theme_stylebox_override("panel",Folio.style(Color(.25,.19,.1,.025),Folio.BRASS,1))
		heading(host,note,"门派荐帖",Rect2(18,24,284,38),27,INK)
		text(host,note,"完成青苇渡的失灯之事，\n再选一门适合自己的功夫。",Rect2(18,81,284,74),18,MUTED)
		text(host,note,"不同门派各有攻守，已学招式可在此比较。",Rect2(18,181,284,55),16,MUTED)
		heading(host,frame,"以行证艺",Rect2(476,451,600,41),28,INK)
		text(host,frame,"真正施展招式才会积累心得。\n5次熟习，15次通明；更换出战招式不重置真气与调息。",Rect2(477,512,616,104),19,MUTED)
	var close=Paper.guarded(host,generation,host._close_modal);host.modal_actions.append(close)
	var button=host._button(frame,"返回江湖",Rect2(1008,20,166,45),close);button.name="MartialClose";Folio.skin_button(button,"header_close");button.add_theme_font_size_override("font_size",19)
	text(host,button,str(learned.size()+1),Rect2(10,8,23,27),17,Folio.BONE).name="MartialCloseShortcut"
	text(host,frame,"基础伤害受敌势影响；卸劲按来击消耗，蓄锋留给下次平击。藏页需向岑远研习。",Rect2(456,667,662,39),16,MUTED).name="MartialRulesNote"
	var help_back=ColorRect.new();help_back.name="MartialHelpBacking";help_back.position=Vector2(128,715);help_back.size=Vector2(1018,32);help_back.color=Color("132226");help_back.mouse_filter=Control.MOUSE_FILTER_IGNORE;frame.add_child(help_back)
	text(host,frame,"数字键修习  ·  Enter / 空格选首项  ·  Esc 返回",Rect2(138,719,995,26),16,Folio.BONE).name="MartialHelp"

static func card(host,parent:Node,rect:Rect2,id:String,number:int,generation:int)->void:
	var art:Dictionary=Arts.definition(id)
	var owned:bool=number>0
	var selected:bool=host.state.equipped_art==id
	var panel=host._panel(parent,rect,Color.TRANSPARENT,Color.TRANSPARENT);panel.name="ArtCard_"+id
	panel.add_theme_stylebox_override("panel",Folio.style(Color(.25,.19,.1,.015),Folio.BRASS if selected else Color("aa9a7c"),1))
	panel.tooltip_text=host.state.art_description(id)
	if selected:
		Folio.rule(panel,Rect2(0,0,320,30),Folio.CINNABAR).name="ArtEquippedRibbon"
		Folio.mark(panel,"compass",Rect2(282,6,18,18),Folio.BONE)
	text(host,panel,String(art.style)+(" · 当前出战" if selected else " · 已习得" if owned else " · 藏页未习"),Rect2(16,4,268,24),14,Folio.BONE if selected else MUTED).name="ArtOwnership"
	heading(host,panel,id,Rect2(16,38,288,40),28,INK).name="ArtTitle"
	text(host,panel,"真气 %d  ·  调息 %d 回合"%[int(art.cost),int(art.cooldown)],Rect2(17,82,287,26),16,MUTED).name="ArtCost"
	var effects:Array[String]=["基础伤害 %d"%Rules.direct_damage(art,host.state.effective_attack(),host.state.art_rank(id))]
	if int(art.healing)>0:effects.append("回血 %d"%int(art.healing))
	if art.guard:effects.append("守势 / 清破绽")
	if int(art.weaken_amount)>0:effects.append("卸劲 %d × %d击"%[int(art.weaken_amount),int(art.weaken_strikes)])
	var focus:int=Rules.focus_damage(art,host.state.effective_attack())
	if focus>0:effects.append("下次平击 +%d"%focus)
	text(host,panel," · ".join(effects),Rect2(17,118,287,48),16,INK).name="ArtEffects"
	if owned:
		var uses:int=int(host.state.art_uses.get(id,0));var rank:int=host.state.art_rank(id)
		var next:int=5 if rank==1 else 15
		var caption=Arts.rank_name(rank)+" · 已施展%d次"%uses
		if rank<3:caption+=" / %d次%s"%[next,Arts.rank_name(rank+1)]
		text(host,panel,caption,Rect2(17,170,287,26),15,MUTED).name="ArtProficiency"
		var bar=host._bar(panel,Rect2(17,199,286,3),Folio.CINNABAR if selected else Color("625038"));bar.max_value=next;bar.value=mini(uses,next);bar.name="ArtPracticeBar"
		var action=Paper.guarded(host,generation,host._equip_art.bind(id));host.modal_actions.append(action)
		var button=host._button(panel,"修习 "+id,Rect2(17,207,286,34),action);button.name="ArtEquip";button.tooltip_text=host.state.art_description(id);Folio.skin_button(button,"primary" if selected else "paper_quiet");button.add_theme_font_size_override("font_size",18)
		if not selected:button.add_theme_stylebox_override("normal",Folio.style(Color(.12,.15,.12,.025),Folio.BRASS,1))
		text(host,button,str(number),Rect2(23 if selected else 12,5,23,24),15,Folio.BONE if selected else MUTED).name="ArtShortcut"
	else:
		text(host,panel,"需内门 · %d 考绩"%int(art.learn_cost),Rect2(17,171,287,25),15,MUTED).name="ArtLearnRequirement"
		var button=host._button(panel,"到岑远处研习",Rect2(17,207,286,34),func():pass);button.disabled=true;button.name="ArtLocked";Folio.skin_button(button,"paper_quiet");button.add_theme_font_size_override("font_size",18)
		button.tooltip_text="与练武堂南庭的岑远交谈，查看门中藏页；这里不会花费考绩。"

static func heading(host,parent:Node,value:String,rect:Rect2,pixels:int,color:Color)->Label:
	var result=text(host,parent,value,rect,pixels,color)
	result.add_theme_font_override("font",Folio.heading_font())
	return result

static func text(host,parent:Node,value:String,rect:Rect2,pixels:int,color:Color)->Label:
	var result=Paper.text(host,parent,value,rect,pixels,color)
	# Reassert the requested width after theme/font sizing so long Chinese
	# descriptions wrap inside the left folio column instead of growing across it.
	result.size=rect.size
	result.set_deferred("size",rect.size)
	return result
