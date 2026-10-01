extends SceneTree
const State=preload("res://scripts/game_state.gd")
const L=preload("res://scripts/lightness_rules.gd")
const PATH="user://lightness-rules.json"
var checks=0
var failures=0
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures+=1;push_error(label)
func ready_state(school:String="听潮阁"):
	var s=State.new();s.quest_stage=6;s.ending="守望";s.gain_xp(180);s.choose_sect(school);s.position=L.SHORE
	return s
func write_doc(data:Dictionary,version:int=State.SAVE_VERSION)->void:
	var f=FileAccess.open(PATH,FileAccess.WRITE);f.store_string(JSON.stringify({"version":version,"player":data}));f.close()
func _init()->void:
	var fresh=State.new()
	check(not fresh.learn_lightness(),"Unjoined novice cannot learn")
	fresh.gain_xp(180);check(not fresh.learn_lightness(),"Level alone cannot replace a school introduction")
	fresh=State.new();fresh.choose_sect("照野堂");check(not fresh.learn_lightness(),"School alone cannot replace level3")
	for school in ["听潮阁","照野堂","问石门"]:
		var s=ready_state(school);var original=s.to_dict()
		check(not s.cross_reed_water(true) and not s.discover_reed_islet(),"No outward crossing or reward before lesson")
		check(s.to_dict()==original,"Locked attempt changes no position or resources")
		check(s.learn_lightness() and s.lightness_unlocked,"Every school may learn the shared lightness foundation")
		check(not s.learn_lightness() and s.xp==original.xp and s.coins==original.coins,"Learning is free and nonrepeatable")
		check(s.cross_reed_water(true) and s.position==L.LANDING,"Lightness crosses only the declared link")
		check(not s.cross_reed_water(true),"Cannot outward-cross again while already on island")
		check(s.discover_reed_islet() and s.lightness_relics==[L.RELIC_ID],"First discovery records unique lore")
		check(s.coins==original.coins+18 and s.resources.herb==original.resources.herb+1 and s.xp==original.xp+30,"Discovery gives exact one-time modest rewards")
		var completed=s.to_dict()
		check(not s.discover_reed_islet() and s.to_dict()==completed,"Repeat discovery cannot farm rewards")
		check(s.save_game(PATH)==OK,"Island progress saves")
		var loaded=State.new()
		check(loaded.load_game(PATH)==OK and loaded.to_dict()==s.to_dict(),"Island position and lore round-trip")
		check(loaded.cross_reed_water(false) and loaded.position==L.SHORE,"Loaded island hero always has a return path")
		for i in range(3):
			check(loaded.cross_reed_water(true) and loaded.cross_reed_water(false),"Repeated travel remains free and reversible")
		check(loaded.coins==s.coins and loaded.qi==s.qi and loaded.medicine==s.medicine,"Travel does not spend or refill combat resources")
		for map_id in ["sluice","frostbridge","mistwood"]:
			loaded.map_id=map_id;loaded.position=L.LANDING
			check(not loaded.cross_reed_water(false) and not loaded.cross_reed_water(true) and not loaded.discover_reed_islet(),"No remote cross-map use: "+map_id)
		loaded.map_id="qingwei";loaded.position=L.SHORE;loaded.start_battle("spar")
		var before=loaded.to_dict()
		check(not loaded.learn_lightness() and not loaded.cross_reed_water(true) and not loaded.discover_reed_islet(),"Battle prohibits traversal and pickups")
		check(loaded.to_dict()==before,"Battle-gated interaction is atomic")
		loaded.battle_action("flee");loaded.reset_game()
		check(not loaded.lightness_unlocked and loaded.lightness_relics.is_empty(),"New journey clears exploration progression")
	var stranded=State.new();stranded.position=L.ISLET_CENTER
	check(stranded.cross_reed_water(false) and stranded.position==L.SHORE,"Recovery return works even if a loaded traveller lacks the lesson")
	var s=ready_state();s.learn_lightness()
	for point in [Vector2(460,430),Vector2(1500,850),Vector2(1441,930),Vector2(NAN,930)]:
		s.position=point;check(not s.cross_reed_water(true),"Bad departure cannot bypass declared shoreline")
	for point in [L.ISLET_CENTER,L.LANDING,L.RELIC_POSITION]:
		check(L.on_islet(point),"Authored island points lie on land")
	for point in [L.SHORE,Vector2(1470,930),Vector2(INF,0),Vector2(1514,967)]:
		check(not L.on_islet(point),"Water/out-of-bounds/nonfinite position excluded")
	s.position=L.SHORE
	for version in range(1,8):
		var legacy=s.to_dict();legacy.erase("lightness_unlocked");legacy.erase("lightness_relics");write_doc(legacy,version)
		var loaded=State.new()
		check(loaded.load_game(PATH)==OK and not loaded.lightness_unlocked and loaded.lightness_relics.is_empty(),"Legacy version defaults to unlearned without rewards: "+str(version))
	for patch in [{"lightness_unlocked":1},{"lightness_unlocked":"true"},{"lightness_unlocked":null},{"lightness_relics":{}},{"lightness_relics":["unknown"]},{"lightness_relics":[L.RELIC_ID,L.RELIC_ID]},{"lightness_relics":[1]},{"lightness_unlocked":false,"lightness_relics":[L.RELIC_ID]},{"level":2},{"sect":"未入门"}]:
		var data=s.to_dict()
		for key in patch:data[key]=patch[key]
		write_doc(data);var before=s.to_dict()
		check(s.load_game(PATH)==ERR_FILE_CORRUPT and s.to_dict()==before,"Invalid save rejected atomically: "+str(patch))
	for key in ["lightness_unlocked","lightness_relics"]:
		for version in [7,8]:
			var data=s.to_dict();data.erase(key);write_doc(data,version)
			check(State.new().load_game(PATH)==ERR_FILE_CORRUPT,"Partial field pairs are never silently discarded")
	if failures==0:print("PASS: %d lightness traversal rule checks" % checks)
	else:push_error("FAIL: lightness rule checks")
	quit(0 if failures==0 else 1)
