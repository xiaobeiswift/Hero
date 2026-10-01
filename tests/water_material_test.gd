extends SceneTree
const Water=preload("res://scripts/qingwei_water_material.gd")
const World=preload("res://scripts/world.gd")
func _initialize()->void:
	assert(Water.texture()!=null and Water.texture()==Water.texture())
	Water.prepare();assert(Water._pond_points.size()==64 and Water._pond_uvs.size()==64)
	for i in range(64):
		var p:Vector2=Water._pond_points[i];var uv:Vector2=Water._pond_uvs[i]
		assert(uv.x>=-0.00001 and uv.x<=1.00001 and uv.y>=-0.00001 and uv.y<=1.00001)
		assert(is_equal_approx(((p-Water.POND_CENTER)/Water.POND_RADIUS).length_squared(),1))
		assert((Water.POND_RECT.get_center()+(uv-Vector2(.5,.5))*326).distance_to(p)<.001)
	assert(Water._river_points==PackedVector2Array([Vector2(1451,620),Vector2(1600,558),Vector2(1600,1050),Vector2(1451,1050)]))
	for i in range(4):assert((Water.RIVER_RECT.get_center()+(Water._river_uvs[i]-Vector2(.5,.5))*492).distance_to(Water._river_points[i])<.001)
	var world=World.new();root.add_child(world)
	assert(world._can_walk(Vector2(850,453)) and world._can_walk(Vector2(800,484)))
	assert(not world._can_walk(Water.POND_CENTER))
	assert(world._can_walk(Vector2(1500,780)) and not world._can_walk(Vector2(1530,890)))
	world.queue_free();print("PASS: painted water UV boundaries and existing shore/pier navigation remain aligned");quit()
