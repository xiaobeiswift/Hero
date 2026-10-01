extends SceneTree
const Region=preload("res://scripts/mistwood_region.gd")
var checks=0
var failures=0
func _initialize() -> void:
	var expected={"return_frostbridge":Vector2(150,550),"mist_guide":Vector2(350,360),"mist_rain_gauge":Vector2(550,245),"mist_stone_gauge":Vector2(1000,300),"mist_basin":Vector2(1250,765),"mist_camp":Vector2(290,790),"mist_scout":Vector2(1030,560),"mist_gate":Vector2(1320,500)}
	var locations=Region.points()
	_check(locations.size()==8,"Exactly eight chapter-four interaction points")
	for id in expected:
		_check(locations.has(id) and locations[id].pos==expected[id],"Fixed position: "+id)
		_check(Region.walkable(expected[id]),"Landmark center walkable: "+id)
	_check(not Region.walkable(Vector2(NAN,500)),"NaN positions rejected")
	_check(not Region.walkable(Vector2(INF,500)),"Infinite positions rejected")
	for p in [Vector2(29,500),Vector2(1571,500),Vector2(500,154),Vector2(500,1016)]:_check(not Region.walkable(p),"Map bounds rejected")
	_check(not Region.walkable(Region.POND_CENTER),"Pond water blocks walking")
	for terrace in Region.TERRACES:
		_check(not Region.walkable(terrace.get_center()),"Terrace footprint blocks walking")
		_check(Region.walkable(terrace.end+Vector2(12,12)),"Ground beyond terrace collision is walkable")
	_check(not Region.walkable(Region.CAMP_FOOTPRINT.get_center()),"Tent footprint blocks walking")
	for p in Region.GATE_POSTS:_check(not Region.walkable(p),"Gate pillar blocks walking")
	for p in Region.BAMBOO:_check(not Region.walkable(p),"Bamboo root footprint blocks walking")
	# Check every path segment at five-unit intervals, not just an abstract BFS.
	for path in Region.PATHS:
		for j in range(path.size()-1):
			var from:Vector2=path[j];var to:Vector2=path[j+1]
			var steps=int(ceil(from.distance_to(to)/5))
			for k in range(steps+1):_check(Region.walkable(from.lerp(to,float(k)/steps)),"Painted route clear of permanent obstacles: %s" % from.lerp(to,float(k)/steps))
	var queue:Array[Vector2]=[Vector2(150,550)]
	var visited={queue[0]:true};var cursor=0
	while cursor<queue.size():
		var p=queue[cursor];cursor+=1
		for offset in [Vector2(10,0),Vector2(-10,0),Vector2(0,10),Vector2(0,-10)]:
			var next=p+offset
			if not visited.has(next) and Region.walkable(next):visited[next]=true;queue.append(next)
	for id in expected:
		var close=false
		for p in visited:
			if p.distance_to(expected[id])<=10:close=true;break
		_check(close,"Landmark reachable from entry without companion: "+id)
	# Optional argument must never add a skill, repair, or companion dependency.
	for x in range(30,1571,20):
		for y in range(155,1016,20):
			var p=Vector2(x,y)
			_check(Region.walkable(p)==Region.walkable(p,true),"Optional state does not gate exploration")
	# The returned lookup is independent so callers cannot corrupt future loads.
	locations.mist_guide.pos=Vector2.ZERO
	_check(Region.points().mist_guide.pos==expected.mist_guide,"Point lookup is mutation independent")
	print("%s: %d mistwood geometry checks; %d reachable navigation samples" % ["PASS" if failures==0 else "FAIL",checks,visited.size()])
	quit(0 if failures==0 else 1)
func _check(condition:bool,message:String) -> void:
	checks+=1
	if not condition:failures+=1;push_error(message)
