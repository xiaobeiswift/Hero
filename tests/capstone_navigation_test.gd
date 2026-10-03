extends SceneTree
## Pure projection plus real world/chart consumers. Prepared fixtures only.
const Nav=preload("res://scripts/volume_one_capstone_navigation.gd")
const Rules=preload("res://scripts/volume_one_capstone_rules.gd")
const World=preload("res://scripts/world.gd")
const Chart=preload("res://scripts/map_chart.gd")
const Fixture=preload("res://tests/capstone_world_fixture.gd")
var checks:int=0
var failures:int=0
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures+=1;push_error(label)
func run()->void:
	var w=World.new();w.terrain_cache_enabled=false;root.add_child(w);w.set_process(false)
	var chart=Chart.new();root.add_child(chart)
	var expected_sites:Array=["heting_dispatch","chapter_host","chapter_clerk","chapter_archive","capstone_order_desk","capstone_order_desk","elder",""]
	var expected_maps:Array=["heting","frostbridge","frostbridge","frostbridge","sluice","sluice","qingwei",""]
	for stage:int in range(8):
		var s=Fixture.state(stage)
		var before:Dictionary=s.to_dict()
		Fixture.sync(w,s)
		for map:String in Nav.MAPS:
			w.change_map(map,Vector2(500,450))
			var old_goal:Dictionary=Rules.goal(s)
			var resolved:Dictionary=Nav.resolve(old_goal,map)
			var target:String=Nav.target_id(old_goal,map)
			check(w.capstone_navigation()==resolved,"world shared resolver stage%d/%s"%[stage,map])
			if stage==7:
				check(target.is_empty() and resolved.is_empty(),"completed goal releases priority "+map)
				continue
			check(old_goal.site_id==expected_sites[stage] and old_goal.map_id==expected_maps[stage],"Rules sole goal facts")
			check(w._quest_target_id()==target and w.interactables.has(target),"world live projected target stage%d/%s"%[stage,map])
			check(resolved.objective==old_goal.objective and resolved.site_id==old_goal.site_id,"resolver preserves Rules meaning")
			check(resolved.is_exit==(map!=expected_maps[stage]),"exit only outside target map")
			if map==expected_maps[stage]:check(target==expected_sites[stage],"same-map direct site")
			else:
				check(w.interactables[target].kind=="exit","existing map exit")
				var cursor:String=map;var hops:int=0
				while cursor!=expected_maps[stage] and hops<5:
					var step:int=1 if Nav.MAPS.find(cursor)<Nav.MAPS.find(expected_maps[stage]) else -1
					var next_target:String=Nav.target_id(old_goal,cursor)
					check(next_target==String(Nav.FORWARD.get(cursor,"")) if step==1 else next_target==String(Nav.BACKWARD.get(cursor,"")),"route uses existing adjacent exit")
					cursor=Nav.MAPS[Nav.MAPS.find(cursor)+step];hops+=1
				check(cursor==expected_maps[stage] and hops<5,"bounded connected five-map route")
			chart.map_id=map;chart.markers=w.interactables.duplicate(true);chart.current_target=target
			check(chart.markers.has(chart.current_target),"chart consumes same target and point")
			if target==World.CAPSTONE_DESK_ID:check(chart.markers[target].name==w.get_npc_name(target),"desk chart/world label agreement")
			var competing:String=""
			for id:String in w.interactables:
				if id!=target:competing=id;break
			w.personal_target_id=competing;w.shen_target_id=competing;w.heting_target_id=competing
			check(w._quest_target_id()==target,"capstone remains first priority")
			w.personal_target_id="";w.shen_target_id="";w.heting_target_id=""
		check(s.to_dict()==before,"all map projections are read-only stage"+str(stage))
	for bad:Dictionary in [{},{"map_id":"unknown","site_id":"elder"},{"map_id":"qingwei"}]:check(Nav.resolve(bad,"qingwei").is_empty(),"invalid/empty goal safe")
	check(Nav.resolve(Rules.goal(Fixture.state(1)),"unknown").is_empty(),"invalid current map safe")
	var goal:Dictionary=Rules.goal(Fixture.state(1));var view:Dictionary=Nav.resolve(goal,"heting");view.objective="changed"
	check(goal.objective!="changed","projection detached from Rules goal")
	Fixture.sync(w,Fixture.state(7));w.change_map("qingwei",Vector2(500,450));w.mentor_pending=true
	check(w._quest_target_id()=="mentor","stage7 restores mentor priority")
	w.shen_target_id="healer";check(w._quest_target_id()=="healer","stage7 restores Shen priority")
	w.shen_target_id="";w.mentor_pending=false;w.personal_target_id="shrine";check(w._quest_target_id()=="shrine","stage7 restores optional priority")
	w.change_map("heting",Vector2(500,450));w.heting_target_id="heting_scale";check(w._quest_target_id()=="heting_scale","stage7 restores receipt/harbor priority")
	chart.queue_free();w.queue_free();await process_frame
	print("%s capstone_navigation: %d checks, all8stages x5maps; prepared projection/consumer evidence"%["PASS" if failures==0 else "FAIL",checks]);quit(0 if failures==0 else 1)
