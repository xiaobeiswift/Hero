extends SceneTree
const Art=preload("res://scripts/painted_lantern_post.gd")
const World=preload("res://scripts/world.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
	assert(Art.texture()!=null and Art.texture()==Art.texture() and Art.texture().get_size()==Art.SOURCE_SIZE)
	assert(Art.post_texture()==Art.post_texture() and Art.post_texture().filter_clip)
	assert(Rect2(Vector2.ZERO,Art.SOURCE_SIZE).encloses(Art.POST_REGION) and Rect2(Vector2.ZERO,Art.SOURCE_SIZE).encloses(Art.LAMP_REGION))
	assert(not Art.POST_REGION.intersects(Art.LAMP_REGION))
	var world=World.new();root.add_child(world);world.set_process(false)
	for foot in Art.POSITIONS:
		var post=Art.post_rect(foot);assert((post.position+Art.POST_FOOT*Art.POST_HEIGHT/Art.POST_REGION.size.y).distance_to(foot)<.001)
		var u=Art.LOOP.x/Art.LAMP_REGION.size.x;var v=Art.LOOP.y/Art.LAMP_REGION.size.y
		var initial=Art.lamp_geometry(foot,0).points
		for time in [0,1,2,3]:
			var data=Art.lamp_geometry(foot,time);var p=data.points
			var pivot=p[0]*(1-u)*(1-v)+p[1]*u*(1-v)+p[2]*u*v+p[3]*(1-u)*v
			assert(pivot.distance_to(Art.lamp_pivot(foot))<.001 and Geometry2D.triangulate_polygon(p).size()==6)
			for uv in data.uvs:assert(uv.x>=0 and uv.x<=1 and uv.y>=0 and uv.y<=1)
		assert(initial!=Art.lamp_geometry(foot,1).points)
		var before=world._can_walk(foot+Vector2(10,8));world.painted_lanterns_enabled=false
		assert(world._can_walk(foot+Vector2(10,8))==before);world.painted_lanterns_enabled=true
	world.queue_free();await process_frame
	print("PASS: independent post/lamp crops, cached art, fixed feet/hanging pivots, visible sway and unchanged navigation");quit()
