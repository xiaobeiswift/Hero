extends SceneTree
const Art=preload("res://scripts/painted_tang_sprite.gd")
const Shen=preload("res://scripts/painted_shen_sprite.gd")
const Hero=preload("res://scripts/painted_traveler_sprite.gd")
const World=preload("res://scripts/world.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
	for direction in Art.ROWS:
		for frame in range(8):
			var crop=Art.texture_for(direction,frame)
			assert(crop!=null and crop.region==Rect2(frame*256,Art.ROWS[direction]*256,256,256))
			assert(crop==Art.texture_for(direction,frame+8) and crop==Art.texture_for(direction,frame-8))
			assert(crop.filter_clip and crop.atlas.get_size()==Vector2(2048,1024))
		assert(Art.texture_for(direction,0).atlas!=Hero.texture_for(direction,0).atlas and Art.texture_for(direction,0).atlas!=Shen.texture_for(direction,0).atlas)
	assert(Art.texture_for("missing",0)==null)
	for foot in [Vector2(440,570),Vector2(650,760)]:
		for scale in [67.1,72.0,80.0]:assert((Art.drawing_rect(foot,scale).position+Art.FOOT*scale/256.0).distance_to(foot)<.001)
	for pair in [[Vector2.DOWN,"front"],[Vector2.RIGHT,"right"],[Vector2.UP,"back"],[Vector2.LEFT,"left"]]:assert(Art.direction_for(pair[0])==pair[1])
	var world=World.new();root.add_child(world);world.set_process(false);world.change_map("frostbridge",Vector2(700,805))
	world.companion_name="唐栖";world.companion_active=false;assert(world.get_npc_name("bridge_worker")=="唐栖")
	world.companion_active=true;assert(world.get_npc_name("bridge_worker")=="修桥工位")
	world.companion_pos=Vector2(590,805);var old:Vector2=world.companion_pos;world._process(.1)
	assert(world.companion_pos!=old and world.companion_moving and world.companion_walk_time>0)
	for facing in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
		world.facing=facing;var target:Vector2=world._companion_follow_target();assert(world._can_walk(target) and target.distance_to(world.player_pos)>35)
		world.companion_pos=target;world._process(.05);assert(not world.companion_moving)
	world.queue_free();await process_frame;print("PASS: Tang32 directional frames, independent shared crops, grounded sizing, travelling clock and identity-safe workstation");quit()
