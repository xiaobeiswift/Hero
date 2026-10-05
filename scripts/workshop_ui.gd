class_name WorkshopUI
extends RefCounted
## Self-contained crafting/shop presentation; model owns all transactional rules.
## Original _modal calls retain lifecycle/guards. Only their generated view is replaced.
const Items=preload("res://scripts/item_catalog.gd")
const Paper=preload("res://scripts/inventory_panel.gd")
const Folio=preload("res://scripts/folio_theme.gd")
const Modal=preload("res://scripts/dialogue_sheet.gd")
const Economy=preload("res://scripts/economy_rules.gd")
# Small status ink keeps contrast over the painted lower trade rows.
const SMALL_WARNING_INK=Color("421a16")
var host
func _init(owner) -> void:
	host=owner

func show(read_only:bool=false) -> void:
	var expected_generation:int=host.modal_generation+1
	var body="[color=#d3b276]随身材料[/color]\n"+_bag()+"\n\n"
	for id in Items.recipe_ids():
		var recipe=Items.recipe(id)
		body+="[color=#d3b276]%s[/color] · %s\n%s\n" % [recipe.name,"可制作" if host.state.can_craft(id) else "需备料/满足条件",Items.recipe_description(id)]
	host._modal("行囊工艺","工艺 / 用得其所，物尽其材",body,[["精锻青钢剑",make.bind("refined_blade")],["轻纱内甲",make.bind("padded_armor")],["制回春散",make.bind("medicine")],["材料买卖",show_market.bind(read_only)],["剑上配件",host._open_fitting.bind("workshop",host.modal_generation+1)]],true)
	if read_only:
		host.modal_autosave_on_close=false
		host.overlay.set_meta("fitting_workshop_readonly",true)
	_present("craft",expected_generation)

func show_market(read_only:bool=false) -> void:
	var expected_generation:int=host.modal_generation+1
	host._modal("随行货担","交易 / 铜钱与材料",_bag()+"\n\n货担有铁矿、木料、布匹与药草。买入价格固定，卖出只取半价。\n\n采集所得的材料也可用于制作；任务所用青穗草单独保管，不会被售出或消耗。",[["买入材料",trade_page.bind(false,read_only)],["卖出材料",trade_page.bind(true,read_only)],["返回工艺",show.bind(read_only)]],true)
	if read_only:
		host.modal_autosave_on_close=false
		host.overlay.set_meta("fitting_workshop_readonly",true)
	_present("market",expected_generation)

func trade_page(selling:bool,read_only:bool=false) -> void:
	var expected_generation:int=host.modal_generation+1
	var body="[color=#d3b276]"+("卖出材料" if selling else "买入材料")+"[/color]\n"+_bag()+"\n\n"
	var options:Array=[]
	for id in Items.material_ids():
		var price=Items.sell_price(id) if selling else Items.buy_price(id)
		body+="%s：%d文 / 份\n" % [Items.material_name(id),price]
		options.append(["%s %d文" % [Items.material_name(id),price],transact.bind(id,selling)])
	options.append(["返回货担",show_market.bind(read_only)])
	body+="\n每次只交易一份。没有足够铜钱或材料时，不会扣除任何物品。"
	host._modal("随行货担","交易 / 逐份买卖 · 数字键1–5",body,options,true)
	if read_only:
		host.modal_autosave_on_close=false
		host.overlay.set_meta("fitting_workshop_readonly",true)
	_present("sell" if selling else "buy",expected_generation)

func transact(id:String,selling:bool) -> void:
	var success=host.state.sell_material(id) if selling else host.state.buy_material(id)
	if not success:
		host._toast("材料不足，或铜钱/行囊容量不符合交易条件。")
		return
	host._refresh()
	host._autosave()
	trade_page(selling)
	host._toast(("卖出" if selling else "买入")+Items.material_name(id)+" ×1。")

func make(id:String) -> void:
	var result=host.state.craft(id)
	if result.valid:
		host._refresh()
		host._autosave()
		show()
	host._toast(result.message)

func _bag() -> String:
	var parts:Array[String]=[]
	for id in Items.material_ids():parts.append("%s%d" % [Items.material_name(id),host.state.resources.get(id,0)])
	return "铜钱 %d文  ·  %s" % [host.state.coins,"  ".join(parts)]

func _present(page:String,generation:int)->void:
	if not is_instance_valid(host) or not host.active_modal or host.modal_generation!=generation:return
	var previous=host.overlay.find_child("DialogueSheet",true,false)
	if not is_instance_valid(previous):return # Original title-screen/rejected path.
	var old_title=previous.find_child("DialogueTitle",true,false)
	var wanted_title="行囊工艺" if page=="craft" else "随行货担"
	if not is_instance_valid(old_title) or old_title.text!=wanted_title:return
	var expected_count=3 if page=="market" else 5
	if host.modal_actions.size()!=expected_count:return
	var captions:Array[String]=[]
	for i in range(expected_count):
		var old_button=previous.find_child("DialogueChoice"+str(i+1),true,false)
		if not is_instance_valid(old_button):return
		captions.append(old_button.text)
	# Preserve the exact generated guards; removing their old view does not
	# remove or recreate the Main-owned numeric action list.
	var actions:Array=host.modal_actions.duplicate()
	host.overlay.remove_child(previous);previous.queue_free()
	for child in host.overlay.get_children():
		if child is ColorRect:child.color=Color(.01,.04,.04,.78)
	var frame=host._panel(host.overlay,Rect2(40,46,1200,714),Color.TRANSPARENT,Color.TRANSPARENT);frame.name="WorkshopFolio";frame.set_meta("workshop_page",page)
	frame.add_theme_stylebox_override("panel",Folio.style(Color.TRANSPARENT))
	Folio.backing(frame,Rect2(0,0,1200,714))
	var wash=Paper.InventoryReadingPaper.new();wash.name="WorkshopReadingPaper";wash.position=Vector2(438,130);wash.size=Vector2(744,560);wash.strength=.84;wash.mouse_filter=Control.MOUSE_FILTER_IGNORE;frame.add_child(wash)
	_heading(frame,wanted_title,Rect2(138,26,250,45),34,Folio.BONE,"DialogueTitle")
	_text(frame,"用得其所，物尽其材。" if page=="craft" else "铜钱与材料，逐份记清。",Rect2(138,82,250,48),17,Folio.BRASS)
	_stock(frame)
	var eyebrow="工艺 / 下方数字为「持有 / 所需」" if page=="craft" else "交易 / 买入定价 · 卖出半价取整" if page=="market" else "交易 / 每次一份 · 数字键 1–5"
	_text(frame,eyebrow,Rect2(456,38,500,28),17,Folio.SECONDARY_INK,"WorkshopEyebrow")
	_heading(frame,{"craft":"制作与备料","market":"材料买卖","buy":"买入材料","sell":"卖出材料"}[page],Rect2(456,78,620,49),36,Folio.INK,"WorkshopPageTitle")
	Folio.rule(frame,Rect2(456,135,662,1),Folio.BRASS)
	var close=host._button(frame,"Esc 返回",Rect2(1008,20,166,45),Modal.guarded(host,generation,host._close_modal));close.name="WorkshopClose";Folio.skin_button(close,"header_close");close.add_theme_font_size_override("font_size",19)
	if page=="craft":
		for i in range(Items.recipe_ids().size()):_recipe_row(frame,Items.recipe_ids()[i],i,actions[i],captions[i])
		_action(frame,captions[3],Rect2(456,642,314,45),actions[3],4,false)
		_action(frame,captions[4],Rect2(804,642,314,45),actions[4],5,false)
	elif page=="market":_market_rows(frame,actions,captions)
	else:_trade_rows(frame,page=="sell",actions,captions)
	var help={"craft":"1–3 制作 · 4 材料买卖 · 5 剑上配件 · Enter / 空格首项 · Esc 返回","market":"1 买入材料 · 2 卖出材料 · 3 返回工艺 · Enter / 空格首项 · Esc 返回","buy":"1–4 逐份买入 · 5 返回货担 · Enter / 空格首项 · Esc 返回","sell":"1–4 逐份卖出 · 5 返回货担 · Enter / 空格首项 · Esc 返回"}[page]
	var backing=ColorRect.new();backing.name="WorkshopHelpBacking";backing.position=Vector2(128,715);backing.size=Vector2(1018,32);backing.color=Color("132226");backing.mouse_filter=Control.MOUSE_FILTER_IGNORE;frame.add_child(backing)
	_text(frame,help,Rect2(138,719,995,26),16,Folio.BONE,"DialogueHelp")

func _stock(frame:Control)->void:
	_text(frame,"现有铜钱",Rect2(138,146,250,26),17,Folio.BRASS)
	_heading(frame,"%d 文"%host.state.coins,Rect2(138,177,250,43),31,Folio.BONE,"WorkshopCoins")
	Folio.rule(frame,Rect2(138,229,250,1),Folio.BRASS.darkened(.2))
	_text(frame,"随身备料",Rect2(138,246,250,30),21,Folio.BONE)
	for i in range(Items.material_ids().size()):
		var id:String=Items.material_ids()[i];var y=290+i*42
		_text(frame,Items.material_name(id),Rect2(138,y,104,31),20,Folio.BONE)
		var count=_heading(frame,str(host.state.resources.get(id,0)),Rect2(248,y-2,140,35),25,Folio.BONE,"WorkshopStock_"+id);count.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	Folio.rule(frame,Rect2(138,460,250,1),Folio.BRASS.darkened(.2))
	_text(frame,"当前 %d 级 · 回春散 %d 包"%[host.state.level,host.state.medicine],Rect2(138,476,250,31),18,Folio.BONE,"WorkshopLevelMedicine")
	_text(frame,"佩剑 · "+host.state.equipment,Rect2(138,511,250,28),17,Folio.BONE,"WorkshopEquipment")
	_text(frame,"衣甲 · "+host.state.armor,Rect2(138,544,250,28),17,Folio.BONE,"WorkshopArmor")
	_text(frame,"青穗草 ×%d · 任务物品"%host.state.herbs,Rect2(138,595,250,29),18,Folio.BONE,"WorkshopQuestHerb")
	_copyable(frame,"单独保管，不会被售出\n或用于制作。",Rect2(138,634,250,54),17,Folio.BONE,"WorkshopQuestHerbPolicy")

func _recipe_row(frame:Control,id:String,index:int,action:Callable,caption:String)->void:
	var recipe:Dictionary=Items.recipe(id);var ready:bool=host.state.can_craft(id)
	var row=host._panel(frame,Rect2(456,151+160*index,662,156),Color.TRANSPARENT,Color.TRANSPARENT);row.name="WorkshopRecipe_"+id
	row.add_theme_stylebox_override("panel",Folio.style(Color(.25,.19,.1,.015),Folio.BRASS,1))
	var glyph=Paper.ItemGlyph.new();glyph.kind=["sword","armor","medicine"][index];glyph.position=Vector2(16,5);glyph.size=Vector2(48,55);row.add_child(glyph)
	_heading(row,recipe.name,Rect2(72,2,180,42),26,Folio.INK,"RecipeTitle")
	_text(row,_craft_status(id,ready),Rect2(260,10,204,28),17,Folio.SECONDARY_INK if ready else Folio.CINNABAR,"RecipeStatus")
	_copyable(row,recipe.description,Rect2(72,61,574,26),17,Folio.SECONDARY_INK,"RecipeDescription")
	_action(row,caption,Rect2(482,8,166,44),action,index+1,ready)
	var materials:Array=recipe.needs.keys()
	for i in range(materials.size()):
		var material:String=materials[i];_requirement(row,Items.material_name(material),int(host.state.resources.get(material,0)),int(recipe.needs[material]),Rect2(16+i*134,89,126,63),"RecipeNeed_"+material)
	_requirement(row,"铜钱",host.state.coins,int(recipe.coins),Rect2(284,89,230,63),"RecipeNeedCoins")
	_requirement(row,"等级",host.state.level,int(recipe.level),Rect2(522,89,126,63),"RecipeNeedLevel")

func _craft_status(id:String,ready:bool)->String:
	if ready:return "可制作"
	if host.state.battle_active:return "战斗中不可制作"
	if id=="refined_blade" and host.state.equipment!="青钢剑":return "已精锻" if host.state.equipment=="精锻青钢剑" else "需先装备青钢剑"
	if id=="padded_armor" and host.state.armor!="粗布行衣":return "已制成"
	var recipe:Dictionary=Items.recipe(id);var supplied:bool=host.state.level>=int(recipe.level) and host.state.coins>=int(recipe.coins)
	for material:String in recipe.needs:supplied=supplied and int(host.state.resources.get(material,0))>=int(recipe.needs[material])
	if id=="medicine" and supplied:return "药量已达上限"
	return "需备料/满足条件"

func _requirement(parent:Control,title:String,owned:int,needed:int,rect:Rect2,node_name:String)->void:
	_text(parent,title,Rect2(rect.position,Vector2(rect.size.x,26)),17,Folio.SECONDARY_INK)
	var ink=Folio.INK if owned>=needed else Folio.CINNABAR
	_copyable(parent,"[color=#%s][font_size=22]%d[/font_size][/color] / %d"%[ink.to_html(false),owned,needed],Rect2(rect.position+Vector2(0,28),Vector2(rect.size.x,33)),17,Folio.SECONDARY_INK,node_name)

func _market_rows(frame:Control,actions:Array,captions:Array[String])->void:
	_copyable(frame,"铁矿、木料、布匹与药草，可买入补足，也可卖出换钱。",Rect2(472,159,626,54),18,Folio.INK,"MarketIntroduction")
	for i in range(2):
		var y=226+i*178
		var row=host._panel(frame,Rect2(456,y,662,159),Color.TRANSPARENT,Color.TRANSPARENT);row.name="MarketBuy" if i==0 else "MarketSell";row.add_theme_stylebox_override("panel",Folio.style(Color(.25,.19,.1,.015),Folio.BRASS,1))
		_heading(row,"添置备料" if i==0 else "余料换钱",Rect2(20,14,400,38),27,Folio.INK)
		_copyable(row,"按固定单价补足所需材料。" if i==0 else "按目录半价收购，金额取整数。",Rect2(21,59,600,30),18,Folio.SECONDARY_INK,"MarketPolicy")
		var prices:Array[String]=[]
		for id:String in Items.material_ids():prices.append("%s %d"%[Items.material_name(id),Items.buy_price(id) if i==0 else Items.sell_price(id)])
		_copyable(row," · ".join(prices)+" 文/份",Rect2(21,96,410,50),17,Folio.SECONDARY_INK,"MarketPrices")
		_action(row,captions[i],Rect2(482,98,166,45),actions[i],i+1,i==0)
	_copyable(frame,"采集所得也可制作；任务青穗草单独保管，不会被售出或消耗。",Rect2(472,588,626,51),18,Folio.SECONDARY_INK,"MarketSafety")
	_action(frame,captions[2],Rect2(456,648,230,43),actions[2],3,false)

func _trade_rows(frame:Control,selling:bool,actions:Array,captions:Array[String])->void:
	_text(frame,"材料",Rect2(472,157,120,28),17,Folio.SECONDARY_INK)
	_text(frame,"现有",Rect2(626,157,132,28),17,Folio.SECONDARY_INK)
	_text(frame,"单价 / 份",Rect2(785,157,140,28),17,Folio.SECONDARY_INK)
	for i in range(Items.material_ids().size()):
		var id:String=Items.material_ids()[i];var y=194+i*91;var price:int=Items.sell_price(id) if selling else Items.buy_price(id)
		var row=host._panel(frame,Rect2(456,y,662,86),Color.TRANSPARENT,Color.TRANSPARENT);row.name="TradeRow_"+id;row.add_theme_stylebox_override("panel",Folio.style(Color(.25,.19,.1,.015),Folio.BRASS,1))
		_heading(row,Items.material_name(id),Rect2(16,18,136,37),25,Folio.INK,"TradeMaterial")
		_heading(row,"×%d"%int(host.state.resources.get(id,0)),Rect2(170,16,130,39),26,Folio.INK,"TradeOwned")
		_heading(row,"%d 文"%price,Rect2(329,16,140,38),25,Folio.INK,"TradePrice")
		# Query the same economic rule on a detached value-only dictionary.
		# No real State, save, reward, callback or resource is mutated here.
		var preview={"battle_active":host.state.battle_active,"coins":host.state.coins,"resources":host.state.resources.duplicate(true)}
		var available:bool=Economy.sell(preview,id) if selling else Economy.buy(preview,id)
		_action(row,captions[i],Rect2(482,11,166,43),actions[i],i+1,available and not selling)
		var status="可卖出" if selling else "可买入"
		if not available:
			if host.state.battle_active:status="战斗中不可交易"
			elif selling:status="暂无可售材料" if int(host.state.resources.get(id,0))<1 else "铜钱将超上限"
			else:status="还需 %d 文"%maxi(0,price-host.state.coins) if host.state.coins<price else "行囊已满"
		_text(row,status,Rect2(482,57,166,27),17,Folio.SECONDARY_INK if available else SMALL_WARNING_INK,"TradeStatus")
	_copyable(frame,"每次只交易一份。没有足够铜钱或材料时，不会扣除任何物品。",Rect2(472,575,626,54),18,Folio.INK,"TradeSafety")
	_action(frame,captions[4],Rect2(456,648,230,43),actions[4],5,false)

func _action(parent:Control,caption:String,rect:Rect2,action:Callable,number:int,primary:bool)->Button:
	var button=host._button(parent,caption,rect,action);button.name="DialogueChoice"+str(number);Folio.skin_button(button,"primary" if primary else "paper_quiet");button.add_theme_font_size_override("font_size",20)
	if not primary:button.add_theme_stylebox_override("normal",Folio.style(Color(.12,.15,.12,.025),Folio.BRASS,1))
	for key:String in ["normal","hover","pressed","disabled"]:
		var box=button.get_theme_stylebox(key).duplicate();box.content_margin_left=44 if primary else 32;box.content_margin_right=8;button.add_theme_stylebox_override(key,box)
	_text(button,str(number),Rect2(23 if primary else 10,8,23,27),17,Folio.BONE if primary else Folio.SECONDARY_INK,"ChoiceNumber")
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
