extends SceneTree
const Props=preload("res://scripts/qingwei_ferry_props.gd")
const World=preload("res://scripts/world.gd")
func _initialize()->void:
	assert(Props.wood_texture()!=null and Props.wood_texture()==Props.wood_texture())
	assert(Props.skiff_texture()!=null and Props.skiff_texture()==Props.skiff_texture())
	assert(Rect2(Vector2.ZERO,Props.skiff_texture().atlas.get_size()).encloses(Props.SKIFF_REGION))
	assert(Props.skiff_texture().filter_clip and is_equal_approx(Props.skiff_rect().size.x/Props.skiff_rect().size.y,Props.SKIFF_REGION.size.x/Props.SKIFF_REGION.size.y))
	assert(Rect2(1440,602,160,448).encloses(Props.skiff_rect()))
	for area in [Props.FISHING_DECK,Props.FERRY_DECK]:
		var geo=Props.deck_geometry(area);assert(geo.points.size()==4 and geo.uvs.size()==4 and Props._deck_cache.has(area))
		for i in range(4):assert((area.get_center()+(geo.uvs[i]-Vector2(.5,.5))*maxf(area.size.x,area.size.y)).distance_to(geo.points[i])<.001)
	var world=World.new();root.add_child(world)
	assert(world._can_walk(Vector2(854,453)) and world._can_walk(Vector2(1500,780)))
	assert(not world._can_walk(Props.SKIFF_CENTER))
	world.queue_free();print("PASS: cached deck/skiff art fits original pier access and non-walkable river");quit()
