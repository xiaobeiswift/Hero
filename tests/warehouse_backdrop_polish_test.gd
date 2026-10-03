extends SceneTree
## Paint geometry/cache/gradient checks only. Native framebuffer review at both
## window sizes and fixed-state legacy frame comparisons remain separate gates.
const Scenery = preload("res://scripts/party_battle_backdrop.gd")
const Art = preload("res://scripts/party_battle_art.gd")
const Encounters = preload("res://scripts/unified_encounter_rules.gd")
var checks: int = 0
var failures: int = 0

class PaintProbe extends Control:
	var floor_mesh: ArrayMesh
	var encounter: String = "heting_consignee"
	func _draw() -> void:
		Scenery.draw(self,floor_mesh,encounter,.375)

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)

func _sky_at(y: float) -> Color:
	return Scenery._warehouse_sky_colors[0].lerp(Scenery._warehouse_sky_colors[3],clampf(y / 685.0,0.0,1.0))

func _opacity_at(y: float) -> float:
	return Scenery.WAREHOUSE_APRON_OPACITY * clampf((y - 278.0) / Scenery.WAREHOUSE_APRON_FADE,0.0,1.0)

func _max_channel_step(a: Color, b: Color) -> float:
	return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))

func _luminance(c: Color) -> float:
	return .2126 * c.r + .7152 * c.g + .0722 * c.b

func _fixed_context() -> void:
	check(Scenery.ENCOUNTER_STYLES == {"training":"courtyard","sect_trial":"courtyard","courtyard_practice":"courtyard","heting_consignee":"warehouse"},"Only the original bounded style mapping is accepted")
	var legacy: int = 0
	for id: String in Encounters.IDS:
		var expected: String = "warehouse" if id == "heting_consignee" else ("courtyard" if id in ["training","sect_trial","courtyard_practice"] else "ferry")
		check(Scenery.style_for(id) == expected,"Existing encounter keeps its exact style: " + id)
		check(Scenery.floor_texture_for(id) == (Scenery.EARTH if expected in ["courtyard","warehouse"] else Scenery.WOOD),"Original floor material remains selected: " + id)
		if id != "heting_consignee": legacy += 1
	check(legacy == 10,"All ten prior encounter styles are covered; this is not a pixel comparison")
	for id: String in ["","unrecognized","warehouse","heting_consignee_future"]:
		check(Scenery.style_for(id) == "ferry" and Scenery.floor_texture_for(id) == Scenery.WOOD,"Unknown and missing encounters still fall back to ferry")
	check(Scenery.WAREHOUSE == {"type":"hall","pos":Vector2(676,173),"size":Vector2(435,110)},"Warehouse anchor and original dimensions remain exact")
	var scale_factor: float = 485.0 / 568.0
	var expected_rect := Rect2(Vector2(893.5,283) - Vector2(281,340) * scale_factor,Vector2(568,397) * scale_factor)
	check(Scenery._warehouse_rect.is_equal_approx(expected_rect),"Original hall image bounds and threshold remain fixed")
	check(is_equal_approx(Scenery._warehouse_rect.size.x / Scenery._warehouse_rect.size.y,568.0 / 397.0),"Original 568:397 warehouse aspect is preserved")
	check(Scenery._warehouse_plaque.is_equal_approx(Rect2(expected_rect.position + Vector2(208,162) * scale_factor,Vector2(134,31) * scale_factor)),"Original plaque bounds stay aligned to the unchanged hall")
	check(Scenery._hall_texture.get_size() == Vector2(568,397),"The existing hall atlas region is reused without stretching")
	check(Scenery.APRON == Rect2(0,278,1280,407),"Original apron bounds remain exact")
	check(Scenery._apron_mesh == Scenery.Tiles.geometry(Scenery.APRON,512.0).mesh,"Courtyard retains its original cached mesh")

func _gradient() -> void:
	check(Scenery._warehouse_sky_points == PackedVector2Array([Vector2(0,0),Vector2(1280,0),Vector2(1280,685),Vector2(0,685)]),"One continuous gradient covers the complete logical field")
	var colors: PackedColorArray = Scenery._warehouse_sky_colors
	check(colors.size() == 4 and colors[0] == colors[1] and colors[2] == colors[3],"Gradient has matching left/right colors and no horizontal band break")
	check(colors[0] == Color("637f75") and colors[3] == Color("858f77"),"Muted teal-to-sage endpoints remain restrained")
	for color: Color in colors: check(color.a == 1.0,"Continuous field remains opaque behind transparent scenery")
	check(Scenery.WAREHOUSE_APRON_FADE >= 48 and Scenery.WAREHOUSE_APRON_FADE <= 72,"Apron transition spans the approved 48–72 logical pixels")
	check(Scenery.WAREHOUSE_APRON_OPACITY <= .28,"Apron never exceeds its original opacity")
	for width: float in [1280.0,1179.0]:
		var row_step: float = 1280.0 / width
		for row: int in range(ceili(685.0 / row_step)):
			var y: float = row * row_step
			var next_y: float = minf(y + row_step,685.0)
			check(_max_channel_step(_sky_at(y),_sky_at(next_y)) <= 4.0 / 255.0,"Off-object analytic gradient row step stays <=4/255")
			# Constant black/white texels bound the extra change caused by the
			# opacity ramp itself; actual texture pixels need native inspection.
			for texture_color: Color in [Color.BLACK,Color.WHITE]:
				check(_max_channel_step(_sky_at(y).lerp(texture_color,_opacity_at(y)),_sky_at(next_y).lerp(texture_color,_opacity_at(next_y))) <= 4.0 / 255.0,"Opacity ramp introduces no analytic row discontinuity")
	for y: float in [180.0,278.0,302.0,342.0]:
		check(_max_channel_step(_sky_at(y-.5),_sky_at(y+.5)) <= 4.0 / 255.0,"Former band/horizon coordinates remain continuous")
	check(is_zero_approx(_opacity_at(278)) and is_equal_approx(_opacity_at(342),.28),"Earth detail fades from zero to its original opacity in exactly 64px")
	check(Scenery._warehouse_shore_points.size() == 11 and Scenery._warehouse_shore_colors.size() == 11,"Only one cached irregular distant shore is introduced")
	for i: int in Scenery._warehouse_shore_points.size():
		var background: Color = _sky_at(Scenery._warehouse_shore_points[i].y)
		var detail: Color = Scenery._warehouse_shore_colors[i]
		var composed: Color = background.lerp(Color(detail.r,detail.g,detail.b),detail.a)
		check(absf(_luminance(composed)-_luminance(background)) <= 12.0 / 255.0,"Distant-shore luminance separation stays below 12/255")
		check(Scenery._warehouse_shore_points[i].y < 278 and detail.a <= .12 + .00001,"Faint shore stays behind the apron and combat floor")
	check(Scenery._warehouse_shore_colors[9].a == 0 and Scenery._warehouse_shore_colors[10].a == 0,"Distant shore fades out instead of drawing a lower hard horizon")

func _apron_geometry() -> void:
	var mesh: ArrayMesh = Scenery._warehouse_apron_mesh
	check(mesh != null and mesh != Scenery._apron_mesh and mesh.get_surface_count() == 1,"Warehouse alpha ramp owns one separate cached mesh")
	var arrays: Array = mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	check(points.size() == 54 and uvs.size() == 54 and colors.size() == 54,"Only one extra row splits the original six apron patches")
	var total_area: float = 0.0
	var samples: Dictionary = {}
	for i: int in range(0,points.size(),6):
		var a := Vector2(points[i].x,points[i].y)
		var b := Vector2(points[i+1].x,points[i+1].y)
		var c := Vector2(points[i+2].x,points[i+2].y)
		total_area += (b.x-a.x) * (c.y-b.y)
		check(is_equal_approx(absf(uvs[i+1].x-uvs[i].x) * 512.0,b.x-a.x),"Every apron patch retains original horizontal texel density")
		check(is_equal_approx(absf(uvs[i+2].y-uvs[i+1].y) * 512.0,c.y-b.y),"Every apron patch retains original vertical texel density")
		for offset: int in range(6):
			var index: int = i + offset
			var p := Vector2(points[index].x,points[index].y)
			var expected_uv := Vector2(p.x / 512.0,p.y / 512.0)
			for axis: int in range(2):
				var cell: int = int(floor(expected_uv[axis]))
				expected_uv[axis] -= cell
				if cell % 2 != 0: expected_uv[axis] = 1.0 - expected_uv[axis]
			check(uvs[index].is_equal_approx(expected_uv),"Original mirrored earth samples are exact at every split vertex")
			check(Scenery.APRON.grow(.001).has_point(p),"Paint mesh never grows beyond the existing apron")
			check(colors[index].r == 1 and colors[index].g == 1 and colors[index].b == 1 and absf(colors[index].a-_opacity_at(p.y)) <= 1.0 / 255.0,"Only apron opacity changes; RGB remains neutral")
			if samples.has(p):
				check(samples[p].uv == uvs[index] and samples[p].color == colors[index],"Shared tile and fade seams use identical UV/color samples")
			else: samples[p] = {"uv":uvs[index],"color":colors[index]}
	check(is_equal_approx(total_area,1280.0 * 407.0),"Apportioned triangles cover the original apron exactly without overlap")

func _original_floor() -> ArrayMesh:
	var art := Art.new()
	var mesh: ArrayMesh = art._make_floor()
	art.free()
	var arrays: Array = mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	check(points.size() == 36 and uvs.size() == 36,"Shared combat floor keeps exactly six mirrored UV patches")
	var i: int = 0
	for row: int in range(2):
		for column: int in range(3):
			for corner: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
				var depth: float = (row + corner.y) / 2.0
				var fraction: float = (column + corner.x) / 3.0
				var expected := Vector3(lerpf(110-150*depth,1170+150*depth,fraction),lerpf(320,682,depth),0)
				check(points[i].is_equal_approx(expected),"Existing actor support plane retains every original vertex")
				check(uvs[i] == Vector2(1-corner.x if column%2 else corner.x,1-corner.y if row%2 else corner.y),"Existing floor mirror directions stay exact")
				i += 1
	return mesh

func run() -> void:
	Scenery.prepare()
	_fixed_context()
	_gradient()
	_apron_geometry()
	var floor_mesh: ArrayMesh = _original_floor()
	var original_floor: Array = floor_mesh.surface_get_arrays(0)
	var mesh: ArrayMesh = Scenery._warehouse_apron_mesh
	var original_apron: Array = mesh.surface_get_arrays(0)
	var sky: PackedColorArray = Scenery._warehouse_sky_colors.duplicate()
	var shore: PackedColorArray = Scenery._warehouse_shore_colors.duplicate()
	var probe := PaintProbe.new()
	probe.floor_mesh = floor_mesh
	probe.size = Vector2(1280,685)
	root.add_child(probe)
	for id: String in Encounters.IDS:
		probe.encounter = id
		for repeated: int in range(3):
			Scenery.prepare()
			probe.queue_redraw()
			await process_frame
			check(Scenery._warehouse_apron_mesh == mesh and mesh.surface_get_arrays(0) == original_apron,"Repeated prepare/draw reuses immutable warehouse mesh geometry")
			check(floor_mesh.surface_get_arrays(0) == original_floor,"Backdrop drawing cannot rewrite the supplied floor mesh")
			check(Scenery._warehouse_sky_colors == sky and Scenery._warehouse_shore_colors == shore,"All warehouse gradient arrays remain cached and immutable")
	probe.queue_free()
	await process_frame
	print("%s: %d warehouse style/geometry/cache/analytic-gradient checks; native pixel acceptance is separate" % ["PASS" if failures == 0 else "FAIL",checks])
	quit(0 if failures == 0 else 1)
