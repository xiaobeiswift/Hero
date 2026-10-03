extends SceneTree
const PartyFixture=preload("res://tests/party_exploration_fixture.gd")
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
	PartyFixture.select_world(world,["hero","shen"])
	assert(world._painted_npc_role("healer").is_empty() and world.get_npc_name("healer")=="药铺伙计")
	PartyFixture.check_cardinal_motion(world,"shen",Vector2(600,450))
	world.teleport(Vector2(600,450))
	# Prepared render fixture: canopy opacity only, not a movement claim.
	for id in ["shen","tang","qin"]:
		PartyFixture.prepare_render(world,[PartyFixture.render_frame(id,Vector2(500,670))])
		assert(world._tree_opacity({"pos":Vector2(510,740),"scale":1.0})==.4)
	PartyFixture.prepare_render(world,[])
	assert(world._tree_opacity({"pos":Vector2(510,740),"scale":1.0})==1.0)
	PartyFixture.select_world(world,["hero","tang"])
	assert(world._painted_npc_role("healer")=="healer")
	world.queue_free();await process_frame
	print("PASS: 32 painted Shen frames, independent caches, fixed foot and travelling identity");quit()
