class_name WorkshopUI
extends RefCounted
## Self-contained crafting/shop presentation; model owns all transactional rules.
const Items=preload("res://scripts/item_catalog.gd")
var host
func _init(owner) -> void:
	host=owner

func show() -> void:
	var body="[color=#d3b276]随身材料[/color]\n"+_bag()+"\n\n"
	for id in Items.recipe_ids():
		var recipe=Items.recipe(id)
		body+="[color=#d3b276]%s[/color] · %s\n%s\n" % [recipe.name,"可制作" if host.state.can_craft(id) else "需备料/满足条件",Items.recipe_description(id)]
	host._modal("行囊工艺","工艺 / 用得其所，物尽其材",body,[["精锻青钢剑",make.bind("refined_blade")],["轻纱内甲",make.bind("padded_armor")],["制回春散",make.bind("medicine")],["材料买卖",show_market]],true)

func show_market() -> void:
	host._modal("随行货担","交易 / 铜钱与材料",_bag()+"\n\n货担有铁矿、木料、布匹与药草。买入价格固定，卖出只取半价。\n\n采集所得的材料也可用于制作；任务所用青穗草单独保管，不会被售出或消耗。",[["买入材料",trade_page.bind(false)],["卖出材料",trade_page.bind(true)],["返回工艺",show]],true)

func trade_page(selling:bool) -> void:
	var body="[color=#d3b276]"+("卖出材料" if selling else "买入材料")+"[/color]\n"+_bag()+"\n\n"
	var options:Array=[]
	for id in Items.material_ids():
		var price=Items.sell_price(id) if selling else Items.buy_price(id)
		body+="%s：%d文 / 份\n" % [Items.material_name(id),price]
		options.append(["%s %d文" % [Items.material_name(id),price],transact.bind(id,selling)])
	options.append(["返回货担",show_market])
	body+="\n每次只交易一份。没有足够铜钱或材料时，不会扣除任何物品。"
	host._modal("随行货担","交易 / 逐份买卖 · 数字键1–5",body,options,true)

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
