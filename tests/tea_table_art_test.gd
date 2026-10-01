extends SceneTree
const Art=preload("res://scripts/painted_tea_table.gd")
const World=preload("res://scripts/world.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
	var texture=Art.texture();assert(texture!=null and texture==Art.texture() and texture.filter_clip)
	assert(texture.atlas.get_size()==Vector2(1774,887) and Rect2(Vector2.ZERO,texture.atlas.get_size()).encloses(texture.region))
	var world=World.new();root.add_child(world);world.set_process(false)
	var original_points=world.interactables.duplicate(true)
	for p in Art.POSITIONS:
		var rect:Rect2=Art.drawing_rect(p)
		assert((rect.position+Art.FOOT*Art.WIDTH/Art.REGION.size.x).distance_to(p+Vector2(0,8))<.001)
		assert(rect.size.x==76 and is_equal_approx(rect.size.x/rect.size.y,Art.REGION.size.x/Art.REGION.size.y))
		assert(Rect2(p-Vector2(40,32),Vector2(80,48)).encloses(rect))
		var before=world._can_walk(p+Vector2(0,30));world.painted_tea_tables_enabled=false
		assert(world._can_walk(p+Vector2(0,30))==before);world.painted_tea_tables_enabled=true
	assert(world.interactables==original_points)
	world.queue_free();await process_frame
	print("PASS: painted tea-table crop/cache/feet, bounded courtyard extent and unchanged routes/interactions");quit()
