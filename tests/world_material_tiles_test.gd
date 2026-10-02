extends SceneTree
const Tiles=preload("res://scripts/world_material_tiles.gd")
const Harbor=preload("res://scripts/heting_region.gd")
func _initialize()->void:
	for spec in [[Harbor.CARGO_ISLAND,Harbor.WOOD_TILE],[Harbor.FOOT_PIER,Harbor.WOOD_TILE],[Harbor.WEST_PONTOON,Harbor.WOOD_TILE],[Harbor.EAST_PONTOON,Harbor.WOOD_TILE],[Rect2(0,150,1600,900),Harbor.WATER_TILE],[Harbor.NORTH_LAND,Harbor.GROUND_TILE],[Rect2(-27,-35,190,227),160.0]]:
		var area:Rect2=spec[0]
		var size:float=spec[1]
		var data=Tiles.geometry(area,size)
		assert(data.mesh==Tiles.geometry(area,size).mesh)
		assert(data.mesh.get_surface_count()==1)
		var points:PackedVector3Array=data.vertices
		var uv:PackedVector2Array=data.uvs
		assert(points.size()==uv.size() and points.size()%6==0)
		var measured_area=0.0
		for i in range(0,points.size(),6):
			var a=Vector2(points[i].x,points[i].y)
			var b=Vector2(points[i+1].x,points[i+1].y)
			var c=Vector2(points[i+2].x,points[i+2].y)
			measured_area+=(b.x-a.x)*(c.y-b.y)
			assert(is_equal_approx(absf(uv[i+1].x-uv[i].x)*size,b.x-a.x))
			assert(is_equal_approx(absf(uv[i+2].y-uv[i+1].y)*size,c.y-b.y))
		for i in range(points.size()):
			assert(area.grow(.001).has_point(Vector2(points[i].x,points[i].y)))
			assert(uv[i].x>=-.001 and uv[i].y>=-.001 and uv[i].x<=1.001 and uv[i].y<=1.001)
		assert(is_equal_approx(measured_area,area.get_area()))
	# Shared seam uses identical texture edge values from each neighboring tile.
	var joined=Tiles.geometry(Rect2(140,30,50,50),160.0)
	var left=[];var right=[]
	for i in range(joined.vertices.size()):
		if is_equal_approx(joined.vertices[i].x,160.0):
			(left if i<6 else right).append(joined.uvs[i])
	assert(left.has(Vector2(1,.1875)) and right.has(Vector2(1,.1875)))
	assert(left.has(Vector2(1,.5)) and right.has(Vector2(1,.5)))
	assert(Tiles.geometry(Rect2(),160).is_empty())
	assert(Tiles.geometry(Rect2(0,0,10,10),0).is_empty())
	print("PASS: fixed world texture density, exact clipped coverage, mirrored seam continuity and cached single-surface meshes")
	quit()
