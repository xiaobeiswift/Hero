extends SceneTree
const Art=preload("res://scripts/painted_bamboo.gd")
const World=preload("res://scripts/world.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
	assert(Art.texture()!=null and Art.texture()==Art.texture() and Art.texture().get_size()==Vector2(1286,1223))
	assert(Rect2(Vector2.ZERO,Art.SOURCE_SIZE).encloses(Art.REGION))
	var foot=Vector2(1222,265);var u=Art.FOOT.x/Art.REGION.size.x;var v=Art.FOOT.y/Art.REGION.size.y
	for height in [132.0,146.0]:
		var base=Art.base_geometry(height);assert(base.points.size()==4 and base.uvs.size()==4 and Art._cache.size()<=2)
		for uv in base.uvs:assert(uv.x>=0 and uv.x<=1 and uv.y>=0 and uv.y<=1)
		for mirror in [false,true]:
			for phase in [0,PI*.5,PI,PI*1.5]:
				var shape=Art.geometry(foot,height,phase,mirror)
				var p=shape.points
				var root=p[0]*(1-u)*(1-v)+p[1]*u*(1-v)+p[2]*u*v+p[3]*(1-u)*v
				assert(root.distance_to(foot)<.001)
				assert(Geometry2D.triangulate_polygon(p).size()==6)
	var world=World.new();root.add_child(world);world.set_process(false)
	var points=[Vector2(1260,350),Vector2(1390,560),Vector2(1450,780),Vector2(1514,930)]
	var before=[]
	for p in points:before.append(world._can_walk(p))
	world.painted_bamboo_enabled=false
	for i in range(points.size()):assert(before[i]==world._can_walk(points[i]))
	world.queue_free();await process_frame
	print("PASS: painted bamboo UV/caches, fixed roots throughout mirrored sway, valid quads and unchanged routes");quit()
