extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Items = preload("res://scripts/item_catalog.gd")
var checks=0
var failures=0
func _initialize() -> void:
	var s=State.new()
	s.coins=2000
	for id in Items.material_ids():
		var before=s.coins
		check(s.buy_material(id,3),"Buy material "+id)
		check(s.resources[id]==3 and s.coins==before-Items.buy_price(id)*3,"Exact purchase charge")
		check(s.sell_material(id,2),"Sell owned material")
		check(s.resources[id]==1 and s.coins<before,"No buy/sell arbitrage")
		var snapshot=s.to_dict()
		check(not s.sell_material(id,2),"Cannot sell unowned material")
		check(s.to_dict()==snapshot,"Rejected trade is atomic")
	for q in [-1,0,100,100000]:
		check(not s.buy_material("iron",q),"Invalid buy quantity")
		check(not s.sell_material("iron",q),"Invalid sell quantity")
	check(not s.buy_material("mystery"),"Unknown material rejected")
	s.coins=0
	check(not s.buy_material("iron"),"Unaffordable material rejected")
	s.coins=2000
	s.resources={"iron":20,"timber":20,"cloth":20,"herb":20}
	var original=s.to_dict()
	check(not s.craft("refined_blade").valid,"Forge requires base sword and level")
	check(s.to_dict()==original,"Failed craft changes nothing")
	check(s.buy_equipment(),"Buy sword")
	s.level=3
	var attack_before=s.attack
	check(s.craft("refined_blade").valid,"Forge advanced sword")
	check(s.equipment=="精锻青钢剑" and s.attack==attack_before+5,"Sword bonus applied once")
	original=s.to_dict()
	check(not s.craft("refined_blade").valid,"Cannot forge duplicate sword")
	check(not s.buy_equipment(),"Cannot downgrade elite sword to stack bonuses")
	check(s.to_dict()==original,"Duplicate weapon action changes nothing")
	var hp_before=s.max_hp
	var defense_before=s.defense
	check(s.craft("padded_armor").valid,"Craft armor")
	check(s.armor=="轻纱内甲" and s.max_hp==hp_before+10 and s.defense==defense_before+3,"Armor applies exact bonuses")
	check(not s.craft("padded_armor").valid,"Cannot stack armor")
	var medicine_before=s.medicine
	check(s.craft("medicine").valid and s.medicine==medicine_before+1,"Renewable medicine craft")
	for id in Items.GATHER_NODES:
		check(s.gather_resource(id).valid,"Gather original node")
		original=s.to_dict()
		check(not s.gather_resource(id).valid and s.to_dict()==original,"Gather de-duplication")
	s.battle_active=true
	original=s.to_dict()
	check(not s.buy_material("iron") and not s.sell_material("iron") and not s.craft("medicine").valid,"No mid-battle economy bypass")
	check(s.to_dict()==original,"Blocked battle actions atomic")
	s.battle_active=false
	var path="user://hero-economy-test.json"
	check(s.save_game(path)==OK,"Economy save")
	var restored=State.new()
	check(restored.load_game(path)==OK,"Economy load")
	check(s.to_dict()==restored.to_dict(),"All resources, armor and crafted equipment round-trip without reapplying")
	var doc={"version":1,"player":s.to_dict()}
	for key in ["resources","armor","gathered_nodes"]:doc.player.erase(key)
	write_doc(path,doc)
	check(restored.load_game(path)==OK,"Legacy save compatibility")
	check(restored.resources=={"iron":0,"timber":0,"cloth":0,"herb":0} and restored.armor=="粗布行衣","Legacy defaults")
	doc.player.resources={"iron":-5,"timber":100000,"bad":20}
	doc.player.gathered_nodes=["frost_ore","frost_ore","unknown"]
	write_doc(path,doc)
	check(restored.load_game(path)==OK,"Recover out-of-range economy")
	check(restored.resources.iron==0 and restored.resources.timber==9999 and not restored.resources.has("bad"),"Clamp and discard unknown resources")
	check(restored.gathered_nodes==["frost_ore"],"Normalize collected IDs")
	original=restored.to_dict()
	doc.player.resources={"iron":"not a number"}
	write_doc(path,doc)
	check(restored.load_game(path)!=OK and restored.to_dict()==original,"Bad economy save cannot mutate game")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures==0: print("PASS: %d economy checks" % checks)
	else:push_error("FAIL: %d / %d economy checks" % [failures,checks])
	quit(0 if failures==0 else 1)
func check(condition:bool,message:String) -> void:
	checks+=1
	if not condition:failures+=1;push_error(message)
func write_doc(path:String,doc:Dictionary) -> void:
	var file=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(doc));file.close()
