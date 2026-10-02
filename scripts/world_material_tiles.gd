class_name WorldMaterialTiles
extends RefCounted
## Fixed world-unit texel density. Mirrored UV quads share exact edge samples;
## no image copies, texture-repeat setting changes or per-frame mesh allocations.
static var _cache:Dictionary={}

static func geometry(area:Rect2,tile_size:float)->Dictionary:
	if not area.position.is_finite() or not area.size.is_finite() or not is_finite(tile_size) or tile_size<=0 or not area.has_area():return {}
	if not _cache.has(tile_size):_cache[tile_size]={}
	if _cache[tile_size].has(area):return _cache[tile_size][area]
	var vertices=PackedVector3Array()
	var uvs=PackedVector2Array()
	for y in range(int(floor(area.position.y/tile_size)),int(ceil(area.end.y/tile_size))):
		for x in range(int(floor(area.position.x/tile_size)),int(ceil(area.end.x/tile_size))):
			var tile=Rect2(Vector2(x,y)*tile_size,Vector2.ONE*tile_size)
			var clipped=area.intersection(tile)
			if not clipped.has_area():continue
			var corners=[clipped.position,Vector2(clipped.end.x,clipped.position.y),clipped.end,Vector2(clipped.position.x,clipped.end.y)]
			for index in [0,1,2,0,2,3]:
				var point:Vector2=corners[index]
				var uv=(point-tile.position)/tile_size
				if x%2!=0:uv.x=1.0-uv.x
				if y%2!=0:uv.y=1.0-uv.y
				vertices.append(Vector3(point.x,point.y,0))
				uvs.append(uv)
	var arrays=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_TEX_UV]=uvs
	var mesh=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var result={"mesh":mesh,"vertices":vertices,"uvs":uvs,"tile_size":tile_size}
	_cache[tile_size][area]=result
	return result

static func draw(canvas:CanvasItem,image:Texture2D,area:Rect2,tile_size:float,opacity:float=1.0)->bool:
	if image==null:return false
	var data=geometry(area,tile_size)
	if data.is_empty():return false
	canvas.draw_mesh(data.mesh,image,Transform2D.IDENTITY,Color(1,1,1,opacity))
	return true
