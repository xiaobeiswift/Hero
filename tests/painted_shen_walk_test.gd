extends SceneTree
const Art=preload("res://scripts/painted_shen_sprite.gd")
const Hero=preload("res://scripts/painted_traveler_sprite.gd")
const World=preload("res://scripts/world.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
	for direction in Art.ROWS:
		for frame in range(8):
			var crop=Art.texture_for(direction,frame)
			assert(crop!=null and crop.region==Rect2(frame*256,Art.ROWS[direction]*256,256,256))
			assert(crop==Art.texture_for(direction,frame+8))
		assert(Art.texture_for(direction,0).atlas!=Hero.texture_for(direction,0).atlas)
	var foot=Vector2(435,650)
	assert((Art.drawing_rect(foot).position+Art.FOOT*(72.0/256.0)).distance_to(foot)<.001)
	assert(Art.texture_for("missing",0)==null)
	var world=World.new();root.add_child(world);world.set_process(false)
	world.companion_active=true;world.companion_name="沈青"
	assert(world._painted_npc_role("healer").is_empty() and world.get_npc_name("healer")=="药铺伙计")
	world.teleport(foot);var old:Vector2=world.companion_pos
	world._process(.1)
	assert(world.companion_moving and world.companion_pos!=old and world.companion_walk_time>0)
	for facing in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
		world.facing=facing
		var destination:Vector2=world._companion_follow_target()
		assert(world._can_walk(destination) and destination.distance_to(world.player_pos)>35)
		world.companion_pos=destination;world._process(.05)
		assert(not world.companion_moving)
	world.player_pos=Vector2(600,650);world.companion_pos=Vector2(500,670)
	assert(world._tree_opacity({"pos":Vector2(510,740),"scale":1.0})==.4)
	world.companion_active=false
	assert(world._tree_opacity({"pos":Vector2(510,740),"scale":1.0})==1.0)
	world.companion_active=true
	world.companion_name="唐栖"
	assert(world._painted_npc_role("healer")=="healer")
	world.queue_free();await process_frame
	print("PASS: 32 painted Shen frames, independent caches, fixed foot and travelling identity");quit()
