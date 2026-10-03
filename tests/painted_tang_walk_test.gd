extends SceneTree
const PartyFixture=preload("res://tests/party_exploration_fixture.gd")
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
	assert(world.get_npc_name("bridge_worker")=="唐栖")
	PartyFixture.select_world(world,["hero","tang"])
	assert(world.get_npc_name("bridge_worker")=="修桥工位")
	PartyFixture.check_cardinal_motion(world,"tang",Vector2(600,805))
	world.queue_free();await process_frame;print("PASS: Tang32 directional frames, independent shared crops, grounded sizing, travelling clock and identity-safe workstation");quit()
