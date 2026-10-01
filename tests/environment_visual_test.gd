extends SceneTree
const World=preload("res://scripts/world.gd")
const Art=preload("res://scripts/qingwei_environment_art.gd")
const Actor=preload("res://scripts/traveler_visual.gd")
var count=0
func check(ok:bool,description:String)->void:
	count+=1
	if not ok:push_error(description);quit(1)
func _initialize()->void:run.call_deferred()
func run()->void:
	var world=World.new();root.add_child(world);world.set_process(false)
	for b in world.buildings:
		var r=Art.building_rect(b)
		var ratio=r.size.x/Art.REGIONS[b.type].size.x
		var anchor=r.position+Art.ANCHORS[b.type]*ratio
		check(anchor.distance_to(b.pos+Vector2(b.size.x*.5,b.size.y))<.001,"Painting preserves door threshold")
		check(Art.texture_for(b.type)!=null,"Imported original texture exists")
		check(r.encloses(Art.plaque_rect(b)),"Runtime plaque remains within sprite")
		check(not world._can_walk(b.pos+b.size*.5),"Painted architecture does not remove building collision")
	for pair in [[Vector2.DOWN,0],[Vector2.RIGHT,1],[Vector2.UP,2],[Vector2.LEFT,3]]:
		check(Actor.direction_index(pair[0])==pair[1],"Four direction silhouettes")
		var step=Actor.pose(pair[0],PI*.5,true)
		check(float(step.gait)>.99,"Walking has articulated alternating gait")
		check(Actor.pose(pair[0],2,false).gait==0,"Idle feet remain planted")
	world.companion_active=true;world.teleport(Vector2(460,430));world.facing=Vector2.RIGHT
	var p=world.player_pos;var old_phase=world.companion_walk_time
	world._process(.05)
	check(world.player_pos==p,"Presentation does not move idle player")
	check(world.companion_moving and world.companion_walk_time>old_phase,"Follower animates from real displacement")
	world.companion_pos=world._companion_follow_target()
	world._process(.05)
	check(not world.companion_moving,"Follower rests at destination without sliding gait")
	world.player_pos=Vector2(500,670)
	check(world._tree_opacity({"pos":Vector2(510,740),"scale":1.0})<.5,"Foreground canopy fades over traveller")
	check(world._tree_opacity({"pos":Vector2(510,620),"scale":1.0})==1.0,"Background trees remain opaque")
	world.queue_free();await process_frame
	print("PASS: %d painted environment/actor invariants"%count);quit()
