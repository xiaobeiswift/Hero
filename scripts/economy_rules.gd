class_name EconomyRules
extends RefCounted
const Items = preload("res://scripts/item_catalog.gd")

static func buy(state, id: String, quantity: int = 1) -> bool:
	var price = Items.buy_price(id)
	if state.battle_active or price<=0 or quantity<1 or quantity>99: return false
	if state.coins < price*quantity or int(state.resources.get(id,0))+quantity>9999: return false
	state.coins -= price*quantity
	state.resources[id] = int(state.resources.get(id,0))+quantity
	return true

static func sell(state, id: String, quantity: int = 1) -> bool:
	var price = Items.sell_price(id)
	if state.battle_active or price<=0 or quantity<1 or quantity>99: return false
	if int(state.resources.get(id,0))<quantity or state.coins+price*quantity>999999: return false
	state.resources[id] -= quantity
	state.coins += price*quantity
	return true

static func can_craft(state,id: String) -> bool:
	var data = Items.recipe(id)
	if state.battle_active or data.is_empty(): return false
	if state.level < int(data["level"]) or state.coins<int(data["coins"]): return false
	if id=="refined_blade" and state.equipment!="青钢剑": return false
	if id=="padded_armor" and state.armor!="粗布行衣": return false
	if id=="medicine" and state.medicine>=999: return false
	for material in data["needs"]:
		if int(state.resources.get(material,0))<int(data["needs"][material]): return false
	return true

static func craft(state,id:String) -> Dictionary:
	if not can_craft(state,id): return {"valid":false,"message":"材料、铜钱或等级不足，或这件装备已制作。"}
	var data = Items.recipe(id)
	state.coins -= int(data["coins"])
	for material in data["needs"]: state.resources[material]-=int(data["needs"][material])
	match id:
		"refined_blade":
			state.equipment="精锻青钢剑"
			state.attack+=5
		"padded_armor":
			state.armor="轻纱内甲"
			state.defense+=3
			state.max_hp+=10
			state.hp=mini(state.max_hp,state.hp+10)
		"medicine": state.medicine+=1
	return {"valid":true,"message":"制成"+String(data["name"])+"。"}

static func gather(state,node_id:String) -> Dictionary:
	if state.battle_active or not Items.GATHER_NODES.has(node_id) or state.gathered_nodes.has(node_id):
		return {"valid":false,"message":"此处已采集，或暂时无法采集。"}
	var node:Dictionary=Items.GATHER_NODES[node_id]
	var material:String=node["material"]
	var amount:int=node["count"]
	if int(state.resources.get(material,0))+amount>9999: return {"valid":false,"message":"行囊里的材料已满。"}
	state.resources[material]=int(state.resources.get(material,0))+amount
	state.gathered_nodes.append(node_id)
	return {"valid":true,"message":"获得%s ×%d。" % [Items.material_name(material),amount]}
