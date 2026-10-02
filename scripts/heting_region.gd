class_name HetingRegion
extends RefCounted
const WaterArt=preload("res://scripts/qingwei_water_material.gd")
const DeckArt=preload("res://scripts/qingwei_ferry_props.gd")
const BuildingsArt=preload("res://scripts/qingwei_environment_art.gd")
const PeopleArt=preload("res://scripts/painted_village_civilians.gd")
const GroundArt=preload("res://assets/generated/environment/qingwei_moss_earth.png")
## Region V: Heting's broad working harbour, drawn from its collision geometry.
## Pure state input: no GameState reads, writes, inventory or quest transitions.
## draw(host, bridge_side, delivered=[], cargo="", draft="", ending="", mist_ending="")
## Host is VillageWorld: camera/viewport/player/companion/time plus existing
## _ellipse, _ellipse_arc, _label, _draw_person, _draw_companion,
## _draw_region_sign, _draw_nameplates and _draw_view_framing helpers.

const WORLD_SIZE := Vector2(1600, 1050)
const NORTH_LAND := Rect2(30, 155, 1540, 295)
const WEST_LAND := Rect2(30, 435, 330, 580)
const EAST_LAND := Rect2(1280, 435, 290, 580)
const CARGO_ISLAND := Rect2(590, 565, 440, 270)
const FOOT_PIER := Rect2(770, 435, 70, 145)
const WEST_PONTOON := Rect2(345, 690, 260, 76)
const EAST_PONTOON := Rect2(1015, 690, 280, 76)
const BUILDINGS := [Rect2(420, 195, 220, 78), Rect2(90, 618, 215, 90), Rect2(1320, 460, 190, 84)]
const ACTOR_RADIUS := 7.0
const LOADED_SAFE := Vector2(820, 665)
const ENTRY := Vector2(180, 350)
const INK := Color("334b46")
const PAPER := Color("e2d3ad")
const WOOD := Color("ae9971")
const WOOD_DARK := Color("6b6250")
const WATER := Color("709591")
const GOLD := Color("c9a260")
const FOOTPRINT_OFFSETS := [Vector2.ZERO, Vector2(7, 0), Vector2(-7, 0), Vector2(0, 7), Vector2(0, -7), Vector2(4.95, 4.95), Vector2(-4.95, 4.95), Vector2(4.95, -4.95), Vector2(-4.95, -4.95)]

static func points() -> Dictionary:
	return {
		"return_mistwood": {"pos": Vector2(150, 335), "name": "返回雾竹坡", "kind": "exit"},
		"heting_dispatch": {"pos": Vector2(535, 350), "name": "孟绫·交割牌", "kind": "npc"},
		"heting_winch": {"pos": Vector2(820, 735), "name": "双向绞缆机", "kind": "mechanism"},
		"heting_cargo": {"pos": Vector2(665, 620), "name": "中埠粮船", "kind": "cargo"},
		"heting_lighter": {"pos": Vector2(970, 780), "name": "南泊短驳", "kind": "cargo"},
		"heting_relief": {"pos": Vector2(230, 780), "name": "顾婶·粥棚", "kind": "rest"},
		"heting_scale": {"pos": Vector2(1390, 600), "name": "施衡·公秤棚", "kind": "npc"},
	}

static func terrain_rects(bridge_side: String, cart_loaded: bool = false) -> Array[Rect2]:
	# This exact positive union also paints the ground and cartographic overview.
	var result: Array[Rect2] = [NORTH_LAND, WEST_LAND, EAST_LAND, CARGO_ISLAND]
	if not cart_loaded:
		result.append(FOOT_PIER)
	if bridge_side == "west":
		result.append(WEST_PONTOON)
	elif bridge_side == "east":
		result.append(EAST_PONTOON)
	return result

static func _surface_contains(p: Vector2, bridge_side: String, cart_loaded: bool) -> bool:
	for surface in terrain_rects(bridge_side, cart_loaded):
		if surface.has_point(p):
			return true
	return false

static func walkable(p: Vector2, bridge_side: String, cart_loaded: bool = false) -> bool:
	if not p.is_finite():
		return false
	# Test the union before erosion: overlapping shore/deck joints stay open.
	# Buildings grow only once, while water/shore edges use an actor footprint.
	for building in BUILDINGS:
		if building.grow(ACTOR_RADIUS).has_point(p):
			return false
	for offset in FOOTPRINT_OFFSETS:
		if not _surface_contains(p + offset, bridge_side, cart_loaded):
			return false
	return true

static func can_step(start: Vector2, finish: Vector2, bridge_side: String, cart_loaded: bool = false) -> bool:
	if not start.is_finite() or not finish.is_finite() or not walkable(start, bridge_side, cart_loaded):
		return false
	var steps := maxi(1, int(ceil(start.distance_to(finish) / 8.0)))
	for i in range(1, steps + 1):
		if not walkable(start.lerp(finish, float(i) / steps), bridge_side, cart_loaded):
			return false
	return true

static func safe_spawn() -> Vector2:
	return ENTRY

static func valid_cart_position(p: Vector2, bridge_side: String) -> bool:
	return walkable(p, bridge_side, true)

static func repaired_position(p: Vector2, bridge_side: String, cart_loaded: bool = false) -> Vector2:
	# Only repairs coordinates. The caller MUST retain its cargo and delivered state.
	# Do not choose an arbitrary closer shore across water for an invalid loaded save.
	if walkable(p, bridge_side, cart_loaded):
		return p
	return LOADED_SAFE if cart_loaded else ENTRY

static func safe_companion_position(player: Vector2, desired: Vector2, bridge_side: String) -> Vector2:
	# A conservative local follower target; never interpolate across the harbour.
	if can_step(player, desired, bridge_side, false):
		return desired
	return repaired_position(player, bridge_side, false)

static func at_foot_pier(p: Vector2) -> bool:
	# For the caller's one-shot cart-blocked hint; not an additional collision wall.
	return p.is_finite() and FOOT_PIER.grow(28).has_point(p)

static func location(p: Vector2) -> String:
	if FOOT_PIER.has_point(p):
		return "鹤汀埠 · 北步栈"
	if CARGO_ISLAND.has_point(p):
		return "鹤汀埠 · 南泊短驳" if p.y > 755 and p.x > 905 else "鹤汀埠 · 中央卸货台"
	if WEST_PONTOON.has_point(p):
		return "鹤汀埠 · 西浮栈"
	if EAST_PONTOON.has_point(p):
		return "鹤汀埠 · 东浮栈"
	if p.y < 450:
		return "鹤汀埠 · 北岸交割街"
	if p.x < 360:
		return "鹤汀埠 · 西岸粥棚"
	if p.x >= 1280:
		return "鹤汀埠 · 东岸公秤"
	return "鹤汀埠 · 港池"

static func draw(w, bridge_side: String, delivered: Array = [], cargo: String = "", draft: String = "", ending: String = "", mist_ending: String = "") -> void:
	w.draw_rect(Rect2(Vector2.ZERO, w.viewport_rect.size), Color("a8b4a5"))
	w.draw_set_transform(-w.camera_pos)
	w.draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), WATER)
	_water(w, bridge_side)
	_distant_shore(w)
	_ground(w, bridge_side)
	_quays(w)
	_foot_pier(w)
	if bridge_side in ["west", "east"]:
		_pontoon(w, WEST_PONTOON if bridge_side == "west" else EAST_PONTOON)
	_rope_routes(w, bridge_side)
	# Water-bound craft are painted before tall actors and dock structures.
	_boat(w, Vector2(495, 594), Vector2(145, 79), "grain", false)
	_boat(w, Vector2(955, 911), Vector2(160, 76), "lighter", ending == "short_ferries")
	_mist_memory(w, mist_ending)
	_dock_furniture(w, delivered, cargo)
	var layers: Array[Dictionary] = []
	for i in range(BUILDINGS.size()):
		layers.append({"y": BUILDINGS[i].end.y, "kind": "building", "index": i})
	layers.append({"y": 643.0, "kind": "crane"})
	layers.append({"y": 690.0, "kind": "winch"})
	layers.append({"y": 754.0, "kind": "relief"})
	layers.append({"y": 697.0, "kind": "scale"})
	layers.append({"y": 326.0, "kind": "dispatch"})
	var locations := points()
	for id in ["heting_dispatch", "heting_relief", "heting_scale"]:
		layers.append({"y": locations[id].pos.y, "kind": "npc", "id": id})
	layers.append({"y": w.player_pos.y, "kind": "player"})
	if w.companion_active:
		layers.append({"y": w.companion_pos.y, "kind": "companion"})
	layers.sort_custom(func(a, b): return a.y < b.y)
	for layer in layers:
		match layer.kind:
			"building": _warehouse(w, BUILDINGS[layer.index], layer.index)
			"crane": _crane(w, Vector2(995, 643))
			"winch": _winch(w, bridge_side)
			"relief": _relief(w, delivered.has("meal"), ending)
			"scale": _scale(w, delivered.has("sealed"), ending)
			"dispatch": _dispatch_board(w, delivered, draft, ending)
			"npc": _npc(w, layer.id, locations[layer.id].pos)
			"player":
				w._draw_person(w.player_pos, Color("326e69"), true, "player")
				if not cargo.is_empty():
					# Compact cart is centred on the valid actor footprint, not a
					# separate trailing body that swings over the water when turning.
					_cart(w, w.player_pos, cargo)
			"companion":
				w._draw_companion()
				w.draw_set_transform(-w.camera_pos)
	_aftermath(w, ending)
	w._draw_region_sign(Vector2(150, 335), "雾竹坡", -1)
	w._draw_nameplates()
	w.draw_set_transform(Vector2.ZERO)
	w._draw_view_framing()

static func _water(w, bridge_side: String) -> void:
	# Broad, flat tidal basin: no vertical river or round village pond silhouette.
	w.draw_rect(Rect2(360, 450, 920, 600), Color("658b89"))
	var surface=WaterArt.texture()
	if surface!=null:
		var shape=DeckArt.deck_geometry(Rect2(0,150,1600,900))
		w.draw_polygon(shape.points,PackedColorArray([Color(1,1,1,.66)]),shape.uvs,surface)
	for i in range(104):
		var p := Vector2(61 + fmod(i * 233.0, 1490), 470 + fmod(i * 107.0, 567))
		if _surface_contains(p, bridge_side, false):
			continue
		var length := 13.0 + float(i % 5) * 8.0
		var drift := sin(w.time_passed * 0.6 + float(i) * 2.7) * 3.0
		w.draw_line(p + Vector2(drift, 0), p + Vector2(length + drift, 0), Color(0.76, 0.83, 0.74, 0.19), 1.2, true)
		if i % 4 == 0:
			w.draw_line(p + Vector2(5, 5), p + Vector2(length - 8, 5), Color(0.39, 0.53, 0.5, 0.38), 1.0, true)

static func _distant_shore(w) -> void:
	_poly(w, [Vector2(0, 149), Vector2(0, 66), Vector2(145, 112), Vector2(330, 75), Vector2(499, 123), Vector2(710, 81), Vector2(915, 119), Vector2(1215, 71), Vector2(1460, 116), Vector2(1600, 92), Vector2(1600, 158)], Color("809b8d"))
	for i in range(12):
		var p := Vector2(70 + i * 129, 146 + sin(i * 1.7) * 7)
		w.draw_line(p, p + Vector2(0, -29 - i % 3 * 12), Color("627f73"), 3, true)
		w.draw_line(p + Vector2(0, -28), p + Vector2(27, -49), Color("627f73"), 2, true)
		w._ellipse(p + Vector2(0, 5), Vector2(63, 8), Color(0.79, 0.82, 0.68, 0.18))

static func _ground(w, bridge_side: String) -> void:
	# Shore surfaces use exactly the same rectangles as walkable(). Textures and
	# embedded cart ruts stay within this positive union and never suggest a ford.
	for r in [NORTH_LAND, WEST_LAND, EAST_LAND]:
		w.draw_rect(r, Color("b9b090"))
		w.draw_rect(Rect2(r.position + Vector2(6, 6), r.size - Vector2(12, 12)), Color("c3b794"))
		var soil=DeckArt.deck_geometry(r)
		w.draw_polygon(soil.points,PackedColorArray([Color(1,1,1,.34)]),soil.uvs,GroundArt)
	for i in range(153):
		var p := Vector2(44 + fmod(i * 281.0, 1510), 167 + fmod(i * 149.0, 832))
		if not _surface_contains(p, "", true) or CARGO_ISLAND.has_point(p):
			continue
		w.draw_line(p, p + Vector2(11 + i % 4 * 4, -2), Color(0.45, 0.45, 0.34, 0.15), 1.0, true)
	for path in [[Vector2(80, 350), Vector2(1530, 350), Vector2(1530, 795)], [Vector2(330, 350), Vector2(330, 780), Vector2(230, 780)], [Vector2(1390, 600), Vector2(1530, 600)]]:
		w.draw_polyline(PackedVector2Array(path), Color("b4a985"), 39, true)
		w.draw_polyline(PackedVector2Array(path), Color("d0c29f"), 29, true)
	# Paired wheel ruts make the permanent northern bypass legible.
	for y in [340, 360]:
		w.draw_line(Vector2(305, y), Vector2(1528, y), Color(0.49, 0.48, 0.35, 0.24), 1.5, true)
	for x in [321, 338, 1521, 1538]:
		w.draw_line(Vector2(x, 367), Vector2(x, 787 if x < 400 else 658), Color(0.49, 0.48, 0.35, 0.21), 1.5, true)
	w._label(Vector2(1033, 316), "北岸横街  ·  板车可绕行", 14, Color("77765a"), 297, HORIZONTAL_ALIGNMENT_CENTER)
	# Unloading platform is a built timber deck, never a grassy natural island.
	w.draw_rect(CARGO_ISLAND, Color("a49370"))
	var painted_deck=DeckArt.draw_deck(w,CARGO_ISLAND)
	for y in range(570, 835, 14) if not painted_deck else []:
		w.draw_line(Vector2(592, y), Vector2(1028, y), Color("766e56"), 1.2, true)
		w.draw_line(Vector2(592, y + 2), Vector2(1028, y + 2), Color(0.87, 0.79, 0.59, 0.38), 1.0, true)
		for x in range(620 + ((y / 14) % 2) * 38, 1025, 78):
			w.draw_line(Vector2(x, y), Vector2(x, y + 13), Color("877a5e"), 1, true)
	for x in [610, 750, 891, 1010]:
		for y in [581, 817]:
			w.draw_circle(Vector2(x, y), 1.5, WOOD_DARK)
	w._label(Vector2(698, 807), "中 央 卸 货 台", 14, Color("6d7158"), 210, HORIZONTAL_ALIGNMENT_CENTER)
	# Tiny lead-in boards at the live bridge's shore joints belong to its rect.
	if bridge_side == "west":
		w.draw_line(Vector2(348, 693), Vector2(348, 762), PAPER, 2)
	elif bridge_side == "east":
		w.draw_line(Vector2(1292, 693), Vector2(1292, 762), PAPER, 2)

static func _quays(w) -> void:
	var edges := [
		[Vector2(360, 450), Vector2(770, 450)], [Vector2(840, 450), Vector2(1280, 450)],
		[Vector2(360, 450), Vector2(360, 690)], [Vector2(360, 766), Vector2(360, 1015)],
		[Vector2(1280, 450), Vector2(1280, 690)], [Vector2(1280, 766), Vector2(1280, 1015)],
		[Vector2(590, 565), Vector2(770, 565)], [Vector2(840, 565), Vector2(1030, 565)],
		[Vector2(590, 565), Vector2(590, 690)], [Vector2(590, 766), Vector2(590, 835)],
		[Vector2(1030, 565), Vector2(1030, 690)], [Vector2(1030, 766), Vector2(1030, 835)],
		[Vector2(590, 835), Vector2(1030, 835)],
	]
	for edge in edges:
		w.draw_line(edge[0] + Vector2(0, 6), edge[1] + Vector2(0, 6), Color("476c67"), 10, true)
		w.draw_line(edge[0], edge[1], Color("817f65"), 7, true)
		w.draw_line(edge[0] + Vector2(0, -2), edge[1] + Vector2(0, -2), Color("d4cba8"), 3, true)
	# Quay cap blocks/piles are placed along the physical boundary, not in routes.
	for x in range(610, 1025, 58):
		w.draw_rect(Rect2(x, 834, 10, 17), WOOD_DARK)
		w.draw_line(Vector2(x + 2, 835), Vector2(x + 2, 849), Color("aaa083"), 2)
	for p in [Vector2(361, 479), Vector2(361, 659), Vector2(361, 804), Vector2(1280, 480), Vector2(1280, 663), Vector2(1280, 806), Vector2(610, 565), Vector2(1010, 565), Vector2(611, 820), Vector2(1010, 820)]:
		_bollard(w, p)

static func _foot_pier(w) -> void:
	w.draw_rect(FOOT_PIER, Color("9e906d"))
	DeckArt.draw_deck(w,FOOT_PIER)
	for y in range(440, 580, 11):
		w.draw_line(Vector2(773, y), Vector2(837, y), Color("756f55"), 1.5, true)
	for x in [773, 837]:
		w.draw_line(Vector2(x, 438), Vector2(x, 577), Color("e0d2ae"), 3, true)
		for y in [457, 510, 559]:
			w.draw_line(Vector2(x, y + 1), Vector2(x, y - 23), WOOD_DARK, 5, true)
			w.draw_circle(Vector2(x, y - 23), 3, Color("b8ae86"))
	# Visible narrow staggered anti-cart bollards coincide with loaded exclusion.
	for y in [450, 567]:
		for x in [783, 827]:
			w._ellipse(Vector2(x, y + 1), Vector2(6, 3), Color("6c705b"))
			w.draw_line(Vector2(x, y), Vector2(x, y - 20), Color("5e6451"), 7, true)
			w.draw_circle(Vector2(x, y - 21), 4, Color("c7b890"))
	w._label(Vector2(710, 410), "窄步栈  ·  行人通行", 13, Color("65715c"), 195, HORIZONTAL_ALIGNMENT_CENTER)
	w._label(Vector2(709, 426), "板车走侧浮栈", 11, Color("8d6d46"), 195, HORIZONTAL_ALIGNMENT_CENTER)

static func _pontoon(w, r: Rect2) -> void:
	# Linked buoyant hulls, transverse sleepers and a low deck: one mobile set.
	for x in range(int(r.position.x) + 23, int(r.end.x) - 10, 51):
		w._ellipse(Vector2(x, r.end.y + 5), Vector2(18, 11), Color("486862"))
		_poly(w, [Vector2(x - 21, r.position.y - 6), Vector2(x + 17, r.position.y - 6), Vector2(x + 22, r.end.y + 3), Vector2(x + 7, r.end.y + 16), Vector2(x - 14, r.end.y + 10)], Color("5e6957"))
		w.draw_line(Vector2(x - 13, r.end.y + 6), Vector2(x + 10, r.end.y + 9), Color("a49b73"), 2, true)
	w.draw_rect(r, WOOD)
	DeckArt.draw_deck(w,r)
	for x in range(int(r.position.x) + 4, int(r.end.x), 13):
		w.draw_line(Vector2(x, r.position.y + 3), Vector2(x, r.end.y - 3), Color("7a7055"), 1.4, true)
	for y in [r.position.y + 3, r.end.y - 3]:
		w.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color("d3c498"), 4, true)
	for x in range(int(r.position.x) + 15, int(r.end.x), 52):
		for y in [r.position.y + 6, r.end.y - 6]:
			w.draw_circle(Vector2(x, y), 2, WOOD_DARK)
	w._label(r.position + Vector2(16, 47), "连 舟 浮 栈", 13, Color("665d45"), r.size.x - 32, HORIZONTAL_ALIGNMENT_CENTER)

static func _rope_routes(w, bridge_side: String) -> void:
	# Slack secondary cable is a thin dark line, never a misleading walkway.
	var shore := Vector2(360, 657) if bridge_side == "west" else Vector2(1280, 657)
	var island := Vector2(600, 672) if bridge_side == "west" else Vector2(1020, 672)
	w.draw_polyline(PackedVector2Array([shore, shore.lerp(island, 0.5) + Vector2(0, 22), island]), Color("5c6250"), 1.8, true)
	for p in [Vector2(623, 659), Vector2(1008, 687), Vector2(339, 856), Vector2(1303, 899)]:
		for i in range(3):
			w._ellipse_arc(p, Vector2(12 - i * 3, 5 - i), Color("776e52"))

static func _boat(w, p: Vector2, size: Vector2, kind: String, lit: bool) -> void:
	if DeckArt.skiff_texture()!=null:
		var extent=Vector2(size.x*1.15,size.x*1.15*DeckArt.SKIFF_REGION.size.y/DeckArt.SKIFF_REGION.size.x)
		w._ellipse(p+Vector2(0,7),extent*Vector2(.48,.24),Color(.18,.31,.3,.23))
		w.draw_texture_rect(DeckArt.skiff_texture(),Rect2(p-extent*.5,extent),false)
		if kind=="grain":
			_basket(w,p+Vector2(-19,-3),true,false,.85)
			_basket(w,p+Vector2(14,-3),true,true,.85)
			w.draw_line(p+Vector2(32,-8),p+Vector2(32,-53),WOOD_DARK,2,true)
			_poly(w,[p+Vector2(33,-53),p+Vector2(51,-43),p+Vector2(33,-35)],PAPER)
		if lit:_lantern(w,p+Vector2(-size.x*.28,-13),true)
		return
	var s := size / Vector2(160, 80)
	var hull := [Vector2(-80, 0), Vector2(-61, -29), Vector2(55, -30), Vector2(81, -8), Vector2(67, 21), Vector2(-53, 29)]
	var vertices: Array = []
	for v in hull:
		vertices.append(p + v * s)
	w._ellipse(p + Vector2(0, 20), size * Vector2(0.56, 0.31), Color(0.22, 0.39, 0.37, 0.23))
	_poly(w, vertices, Color("4e5c4e"))
	vertices = []
	for v in hull:
		vertices.append(p + v * s * Vector2(0.9, 0.72) - Vector2(0, 7))
	_poly(w, vertices, Color("b7a579"))
	w.draw_line(p + Vector2(-60, 10) * s, p + Vector2(59, 5) * s, Color("dcc89c"), 3, true)
	for x in range(-48, 61, 18):
		w.draw_line(p + Vector2(x, -17) * s, p + Vector2(x + 3, 7) * s, Color("887a58"), 2, true)
	if kind == "grain":
		_poly(w, [p + Vector2(-38, -18) * s, p + Vector2(-23, -50) * s, p + Vector2(40, -48) * s, p + Vector2(53, -16) * s], Color("819281"))
		for x in range(-25, 51, 17):
			w.draw_line(p + Vector2(x, -18) * s, p + Vector2(x - 6, -46) * s, Color("b1b6a0"), 1, true)
		w.draw_line(p + Vector2(4, -41) * s, p + Vector2(4, -95) * s, WOOD_DARK, 3, true)
		_poly(w, [p + Vector2(5, -95) * s, p + Vector2(35, -76) * s, p + Vector2(5, -62) * s], Color("d4c9a3"))
	else:
		w.draw_line(p + Vector2(-55, 1) * s, p + Vector2(-90, -33) * s, WOOD_DARK, 3, true)
		w.draw_line(p + Vector2(54, 2) * s, p + Vector2(88, -34) * s, WOOD_DARK, 3, true)
		_basket(w, p + Vector2(4, -10) * s, not lit, false)
	if lit:
		_lantern(w, p + Vector2(-45, -27) * s, true)

static func _mist_memory(w, mist_ending: String) -> void:
	if mist_ending == "release_water":
		# Narrow old water marks/pile feet remain even when pontoon later moves west.
		for y in [488, 622, 817, 941]:
			w.draw_rect(Rect2(1260, y, 13, 30), Color("8a8468"))
			w.draw_line(Vector2(1260, y + 12), Vector2(1273, y + 12), Color("bac0a1"), 2)
			w.draw_line(Vector2(1260, y + 21), Vector2(1273, y + 21), Color("565f4b"), 2)
		_boat(w, Vector2(1135, 516), Vector2(141, 70), "grain", false)
		_boat(w, Vector2(1166, 889), Vector2(155, 77), "grain", false)
		w.draw_line(Vector2(1196, 521), Vector2(1280, 480), Color("585f4d"), 1.6, true)
		w.draw_line(Vector2(1237, 891), Vector2(1280, 806), Color("585f4d"), 1.6, true)
		w._label(Vector2(1074, 962), "迟到粮船  ·  平安系缆", 12, Color("b6c6af"), 184, HORIZONTAL_ALIGNMENT_CENTER)
	elif mist_ending == "warn_ferries":
		_boat(w, Vector2(445, 855), Vector2(125, 67), "grain", false)
		_boat(w, Vector2(455, 955), Vector2(151, 72), "grain", false)
		w.draw_line(Vector2(391, 856), Vector2(360, 804), Color("585f4d"), 1.6, true)
		w.draw_line(Vector2(390, 951), Vector2(356, 940), Color("585f4d"), 1.6, true)
		for p in [Vector2(375, 817), Vector2(386, 938)]:
			w.draw_line(p, p - Vector2(0, 42), WOOD_DARK, 2, true)
			var sway := sin(w.time_passed * 1.2 + p.y) * 2.0
			_poly(w, [p + Vector2(0, -43), p + Vector2(22, -39 + sway), p + Vector2(18, -23 + sway), p + Vector2(0, -27)], GOLD)
			w.draw_arc(p + Vector2(8, -33), 4, PI, TAU, 10, WOOD_DARK, 1, true)
		w._label(Vector2(393, 1014), "内湾避船  ·  警铃旗仍在", 12, Color("b6c6af"), 199, HORIZONTAL_ALIGNMENT_CENTER)

static func _dock_furniture(w, delivered: Array, cargo: String) -> void:
	# The two fixed base batches turn into empty baskets independently, in order.
	for i in range(2):
		_basket(w, Vector2(623 + i * 37, 592), not delivered.has("meal") and cargo != "meal", false)
	for i in range(2):
		_basket(w, Vector2(704 + i * 35, 611), not delivered.has("sealed") and cargo != "sealed", true)
	w._label(Vector2(601, 647), "鹤字三号 · 提粮处", 12, Color("5e6b55"), 161, HORIZONTAL_ALIGNMENT_CENTER)
	for i in range(2):
		_basket(w, Vector2(930 + i * 35, 821), not delivered.has("reserve") and cargo != "reserve", false)
	w.draw_line(Vector2(1008, 820), Vector2(1000, 886), WOOD_DARK, 1.6, true)
	w.draw_line(Vector2(935, 835), Vector2(900, 908), WOOD_DARK, 1.6, true)
	# Rolled sailcloth, stacked empty pallets and small hand tools sit at edges.
	for i in range(4):
		w.draw_line(Vector2(861, 590 - i * 4), Vector2(927, 590 - i * 4), Color("8b7d5d"), 3, true)
	for i in range(3):
		w.draw_line(Vector2(82, 918 + i * 10), Vector2(164, 918 + i * 10), Color("9a8863"), 7, true)
		w.draw_circle(Vector2(166, 918 + i * 10), 3, Color("d8c598"))
	w._ellipse(Vector2(1450, 871), Vector2(51, 19), Color(0.34, 0.39, 0.28, 0.12))
	_poly(w, [Vector2(1404, 866), Vector2(1420, 843), Vector2(1489, 845), Vector2(1500, 866)], Color("8a9c86"))
	for x in [1416, 1454, 1488]:
		w.draw_line(Vector2(x, 849), Vector2(x + 4, 865), Color("596c58"), 2, true)

static func warehouse_spec(index:int)->Dictionary:
	var r:Rect2=BUILDINGS[index]
	return {"pos":r.position,"size":r.size,"type":["hall","inn","tea"][index]}

static func _warehouse(w, r: Rect2, index: int) -> void:
	var building=warehouse_spec(index)
	var actors:Array=[w.player_pos]
	if w.companion_active:actors.append(w.companion_pos)
	if BuildingsArt.draw_building(w,building,BuildingsArt.building_opacity(building,actors)):
		var plaque=BuildingsArt.plaque_rect(building)
		w._label(plaque.position+Vector2(0,plaque.size.y*.80),["交割棚","西岸粥棚","公秤棚"][index],10,PAPER,plaque.size.x,HORIZONTAL_ALIGNMENT_CENTER)
		return
	# Visible solid footprint is exactly BUILDINGS; roof overhang is overhead art.
	var roof := Color("506b60") if index != 1 else Color("879278")
	var top := r.position
	w._ellipse(r.get_center() + Vector2(8, r.size.y * 0.45), Vector2(r.size.x * 0.56, 12), Color(0.21, 0.3, 0.23, 0.17))
	w.draw_rect(r, Color("8d8d70"))
	w.draw_rect(Rect2(top + Vector2(8, 10), r.size - Vector2(16, 16)), Color("c7bb95"))
	for x in [top.x + 8, r.end.x - 12]:
		w.draw_rect(Rect2(x, top.y + 7, 7, r.size.y - 8), WOOD_DARK)
	w.draw_rect(Rect2(top + Vector2(r.size.x * 0.36, 17), Vector2(r.size.x * 0.29, r.size.y - 21)), Color("546455"))
	for i in range(3):
		var x := top.x + r.size.x * 0.4 + i * 14
		w.draw_line(Vector2(x, top.y + 21), Vector2(x, r.end.y - 7), Color("8f9473"), 1.5, true)
	var ridge := top - Vector2(0, 23)
	_poly(w, [top + Vector2(-14, 10), ridge + Vector2(26, -30), ridge + Vector2(r.size.x - 29, -30), top + Vector2(r.size.x + 14, 10), top + Vector2(r.size.x + 3, 20), top + Vector2(-5, 20)], roof)
	w.draw_line(top + Vector2(-12, 10), top + Vector2(r.size.x + 12, 10), Color("b8bd9c"), 5, true)
	w.draw_line(ridge + Vector2(28, -30), ridge + Vector2(r.size.x - 28, -30), Color("8fa48d"), 5, true)
	for i in range(10):
		var t := float(i) / 9
		w.draw_line((ridge + Vector2(28, -27)).lerp(ridge + Vector2(r.size.x - 28, -27), t), (top + Vector2(-7, 8)).lerp(top + Vector2(r.size.x + 7, 8), t), Color(0.72, 0.76, 0.61, 0.25), 1.5, true)
	var title: String = ["交 割 棚", "西 岸 粥 棚", "公 秤 棚"][index]
	w.draw_rect(Rect2(top + Vector2(r.size.x * 0.23, 20), Vector2(r.size.x * 0.54, 23)), Color("465e51"))
	w._label(top + Vector2(r.size.x * 0.23, 37), title, 14, PAPER, r.size.x * 0.54, HORIZONTAL_ALIGNMENT_CENTER)
	if index == 0:
		for i in range(3):
			w.draw_line(Vector2(444 + i * 63, 214), Vector2(444 + i * 63, 247), Color("b4a275"), 1.5, true)
			_poly(w, [Vector2(437 + i * 63, 236), Vector2(451 + i * 63, 236), Vector2(449 + i * 63, 254), Vector2(439 + i * 63, 251)], PAPER)

static func _dispatch_board(w, delivered: Array, draft: String, ending: String) -> void:
	for x in [565, 630]:
		w.draw_line(Vector2(x, 322), Vector2(x, 277), WOOD_DARK, 5, true)
	w.draw_rect(Rect2(555, 276, 86, 47), Color("778671"))
	w.draw_rect(Rect2(561, 280, 74, 36), PAPER)
	for i in range(3):
		var x := 571 + i * 22
		w.draw_line(Vector2(x, 288), Vector2(x + 10, 288), Color("7b8060"), 1, true)
		w.draw_line(Vector2(x, 292), Vector2(x + 9, 292), Color("7b8060"), 1, true)
		if delivered.has(["meal", "sealed", "reserve"][i]):
			w.draw_arc(Vector2(x + 4, 303), 4, 0, TAU, 12, Color("a16e51"), 1.5, true)
	if not draft.is_empty():
		w._label(Vector2(557, 342), "已交割" if not ending.is_empty() else "夜工草案", 10, Color("706449"), 83, HORIZONTAL_ALIGNMENT_CENTER)

static func _crane(w, p: Vector2) -> void:
	# Crane feet sit against the east dock rim, leaving the island's routes open.
	w._ellipse(p, Vector2(21, 7), Color(0.2, 0.29, 0.22, 0.18))
	w.draw_line(p + Vector2(-12, 0), p + Vector2(0, -83), WOOD_DARK, 8, true)
	w.draw_line(p + Vector2(17, 0), p + Vector2(0, -83), Color("9e926c"), 6, true)
	w.draw_line(p + Vector2(-26, -99), p + Vector2(73, -65), WOOD_DARK, 7, true)
	w.draw_line(p + Vector2(-26, -101), p + Vector2(73, -67), Color("bcb18a"), 2, true)
	w.draw_line(p + Vector2(-22, -98), p + Vector2(0, -37), Color("5c614c"), 2, true)
	w.draw_circle(p + Vector2(70, -65), 5, Color("657057"))
	w.draw_line(p + Vector2(70, -64), p + Vector2(70, -13), Color("4e5947"), 1.8, true)
	w.draw_arc(p + Vector2(66, -12), 5, -PI * 0.15, PI * 1.0, 10, WOOD_DARK, 2, true)
	for i in range(4):
		w.draw_line(p + Vector2(-10, -28 + i * 4), p + Vector2(12, -28 + i * 4), Color("716a4e"), 3, true)

static func _winch(w, bridge_side: String) -> void:
	var p := Vector2(820, 681)
	w._ellipse(p, Vector2(42, 12), Color(0.24, 0.29, 0.21, 0.18))
	w.draw_rect(Rect2(p + Vector2(-34, -7), Vector2(68, 14)), WOOD_DARK)
	w.draw_line(p + Vector2(-26, -1), p + Vector2(-26, -31), Color("5c6650"), 6, true)
	w.draw_line(p + Vector2(26, -1), p + Vector2(26, -31), Color("5c6650"), 6, true)
	w.draw_line(p + Vector2(-29, -24), p + Vector2(29, -24), Color("9d946f"), 17, true)
	for x in range(-21, 24, 6):
		w.draw_line(p + Vector2(x, -32), p + Vector2(x, -16), Color("68654d"), 2, true)
	w.draw_arc(p + Vector2(36, -26), 19, 0, TAU, 22, Color("505b48"), 4, true)
	for i in range(4):
		var a := i * PI / 2
		w.draw_line(p + Vector2(36, -26), p + Vector2(36 + cos(a) * 19, -26 + sin(a) * 19), Color("a59d78"), 2, true)
	w.draw_line(p + Vector2(-22, -4), Vector2(620 if bridge_side == "west" else 1010, 687), Color("5b5e47"), 2, true)
	w._label(Vector2(763, 713), "浮栈接西" if bridge_side == "west" else "浮栈接东", 12, Color("615e43"), 122, HORIZONTAL_ALIGNMENT_CENTER)

static func _relief(w, meal_delivered: bool, ending: String) -> void:
	# Hearth and bowls are a distinct open-air space south of the solid kitchen.
	var p := Vector2(146, 743)
	w._ellipse(p + Vector2(0, 3), Vector2(29, 12), Color("827b5a"))
	for x in [-17, 16]:
		w.draw_line(p + Vector2(x, 0), p + Vector2(x, -20), Color("6c6950"), 7, true)
	if meal_delivered:
		w._ellipse(p - Vector2(0, 5), Vector2(13, 5), Color("d69c55"))
		_poly(w, [p + Vector2(-9, -6), p + Vector2(-5, -18), p + Vector2(0, -9), p + Vector2(5, -20), p + Vector2(11, -5)], Color("ebc078"))
	w._ellipse(p - Vector2(0, 21), Vector2(25, 12), Color("536257"))
	w._ellipse(p - Vector2(0, 26), Vector2(24, 9), Color("8a9679"))
	w._ellipse(p - Vector2(0, 27), Vector2(20, 6), Color("c6bd94") if meal_delivered else Color("546e63"))
	if meal_delivered:
		for i in range(3):
			var lift := fmod(w.time_passed * 12 + i * 11, 37.0)
			w._ellipse(p + Vector2(sin(w.time_passed + i) * 5 + i * 7 - 7, -36 - lift), Vector2(8 + lift * 0.14, 4 + lift * 0.11), Color(0.9, 0.88, 0.71, (1.0 - lift / 44.0) * 0.4))
		for i in range(5):
			var bowl := Vector2(183 + i * 19, 749)
			w._ellipse(bowl, Vector2(7, 4), Color("d2c8a4"))
			w._ellipse(bowl - Vector2(0, 2), Vector2(7, 3), Color("f0deb1"))
		for i in range(3):
			w.draw_line(Vector2(106, 765 + i * 5), Vector2(133, 762 + i * 5), Color("766c4e"), 4, true)
	if ending == "short_ferries":
		_basket(w, Vector2(141, 845), true, false)
		_basket(w, Vector2(179, 847), true, false)
		w._label(Vector2(83, 884), "短渡分装处", 13, Color("6e6e50"), 160, HORIZONTAL_ALIGNMENT_CENTER)

static func _scale(w, sealed_delivered: bool, ending: String) -> void:
	var p := Vector2(1418, 697)
	w.draw_rect(Rect2(p + Vector2(-65, -11), Vector2(122, 12)), Color("8b7a57"))
	for x in [-54, 45]:
		w.draw_line(p + Vector2(x, -4), p + Vector2(x, 10), WOOD_DARK, 5, true)
	w.draw_line(p + Vector2(0, -13), p + Vector2(0, -80), Color("576650"), 6, true)
	w.draw_line(p + Vector2(-47, -71), p + Vector2(49, -71), Color("56634f"), 5, true)
	w.draw_circle(p + Vector2(0, -74), 5, GOLD)
	for x in [-37, 36]:
		for dx in [-15, 15]:
			w.draw_line(p + Vector2(x, -70), p + Vector2(x + dx, -30), Color("6f6b50"), 1.4, true)
		w._ellipse(p + Vector2(x, -29), Vector2(19, 6), Color("b4a77c"))
	if sealed_delivered:
		_basket(w, p + Vector2(-35, -31), true, true, 0.61)
		_basket(w, p + Vector2(36, -31), true, true, 0.61)
		w.draw_rect(Rect2(1470, 593, 41, 28), PAPER)
		for i in range(3):
			w.draw_line(Vector2(1475, 599 + i * 5), Vector2(1505 - i * 3, 599 + i * 5), Color("70765a"), 1, true)
		w.draw_arc(Vector2(1500, 613), 4, 0, TAU, 12, Color("a16e51"), 1, true)
		w._label(Vector2(1429, 578), "复称签 · 只记货号", 11, Color("6b7057"), 134, HORIZONTAL_ALIGNMENT_CENTER)
	if ending == "short_ferries":
		_poly(w, [p + Vector2(-62, -49), p + Vector2(56, -48), p + Vector2(65, -6), p + Vector2(-66, -6)], Color("809481"))
		w.draw_line(p + Vector2(-51, -45), p + Vector2(-33, -10), Color("b3bba0"), 2, true)
		w._label(Vector2(1321, 737), "夜间覆秤 · 明早复核", 12, Color("64735a"), 192, HORIZONTAL_ALIGNMENT_CENTER)
	elif ending == "open_scale":
		_basket(w, Vector2(1365, 759), true, false)
		_basket(w, Vector2(1404, 759), true, false)
		w._label(Vector2(1317, 794), "共同存粮 · 当面记账", 12, Color("64735a"), 199, HORIZONTAL_ALIGNMENT_CENTER)

static func npc_role(id:String)->String:
	return {"heting_dispatch":"clerk","heting_relief":"resident","heting_scale":"porter"}.get(id,"")

static func _npc(w, id: String, p: Vector2) -> void:
	var role=npc_role(id)
	w._ellipse(p+Vector2(0,2),Vector2(12,4),Color(0.17,0.25,0.20,.2))
	if PeopleArt.draw_idle(w,p,role):return
	match id:
		"heting_dispatch":
			w._draw_person(p, Color("77968a"), false, "villager")
			w.draw_line(p + Vector2(-12, -12), p + Vector2(-13, -26), PAPER, 5, true)
			w.draw_line(p + Vector2(14, -13), p + Vector2(18, -33), Color("7c7050"), 2, true)
		"heting_relief":
			w._draw_person(p, Color("b79873"), false, "healer")
			_poly(w, [p + Vector2(-7, -20), p + Vector2(7, -20), p + Vector2(10, -3), p + Vector2(-10, -3)], Color("d6ceb0"))
			w.draw_line(p + Vector2(13, -11), p + Vector2(17, -31), WOOD_DARK, 2, true)
			w._ellipse(p + Vector2(17, -33), Vector2(5, 3), Color("8d977b"))
		"heting_scale":
			w._draw_person(p, Color("69847b"), false, "villager")
			w.draw_rect(Rect2(p + Vector2(-16, -23), Vector2(13, 17)), PAPER)
			w.draw_line(p + Vector2(10, -21), p + Vector2(16, -31), Color("4f5c45"), 2, true)

static func _aftermath(w, ending: String) -> void:
	if ending == "short_ferries":
		_lantern(w, Vector2(302, 852), true)
		_boat(w, Vector2(433, 811), Vector2(103, 53), "lighter", true)
		# Two local night workers, no extra named NPC or interaction marker.
		_worker(w, Vector2(296, 826), Color("7d9078"))
		_worker(w, Vector2(322, 856), Color("9a9872"))
		w._label(Vector2(65, 967), "短渡已排顺序 · 不便上岸者先送", 12, Color("717553"), 271, HORIZONTAL_ALIGNMENT_CENTER)
	elif ending == "open_scale":
		_lantern(w, Vector2(1315, 650), true)
		_lantern(w, Vector2(1502, 651), true)
		_worker(w, Vector2(1318, 699), Color("7d9078"))
		_worker(w, Vector2(1480, 716), Color("9a9872"))
		w._label(Vector2(1294, 922), "公秤今夜留人 · 短渡明日再行", 12, Color("717553"), 253, HORIZONTAL_ALIGNMENT_CENTER)

static func _worker(w, p: Vector2, color: Color) -> void:
	w._ellipse(p, Vector2(9, 4), Color(0.25, 0.34, 0.27, 0.18))
	_poly(w, [p + Vector2(-8, -4), p + Vector2(-5, -23), p + Vector2(5, -23), p + Vector2(8, -4)], color)
	w.draw_circle(p - Vector2(0, 28), 5, Color("b8ad88"))
	w.draw_line(p + Vector2(-4, -4), p + Vector2(-5, 1), WOOD_DARK, 3, true)
	w.draw_line(p + Vector2(4, -4), p + Vector2(5, 1), WOOD_DARK, 3, true)

static func _cart(w, p: Vector2, cargo: String) -> void:
	# Ground contact stays within 6 px of its owner's centre even on narrow decks.
	w._ellipse(p + Vector2(0, 1), Vector2(11, 4), Color(0.2, 0.29, 0.22, 0.2))
	w.draw_line(p + Vector2(-5, -2), p + Vector2(-5, 4), WOOD_DARK, 3, true)
	w.draw_line(p + Vector2(5, -2), p + Vector2(5, 4), WOOD_DARK, 3, true)
	w.draw_rect(Rect2(p + Vector2(-14, -22), Vector2(28, 19)), Color("8a7b57"))
	w.draw_line(p + Vector2(-13, -4), p + Vector2(13, -4), Color("d0bd8d"), 3, true)
	_basket(w, p - Vector2(0, 14), true, cargo == "sealed", 0.6)
	w.draw_line(p + Vector2(-10, -5), p + Vector2(-6, -30), WOOD_DARK, 2, true)
	w.draw_line(p + Vector2(10, -5), p + Vector2(6, -30), WOOD_DARK, 2, true)
	w.draw_rect(Rect2(p + Vector2(10, -19), Vector2(7, 10)), Color("d8c591") if cargo != "sealed" else Color("dfd2ac"))

static func _basket(w, p: Vector2, full: bool, sealed: bool, scale: float = 1.0) -> void:
	var rx := 15.0 * scale
	var height := 20.0 * scale
	w._ellipse(p, Vector2(rx + 2, 5 * scale), Color(0.29, 0.32, 0.23, 0.17))
	_poly(w, [p + Vector2(-rx, -height), p + Vector2(rx, -height), p + Vector2(rx - 2, 0), p + Vector2(-rx + 2, 0)], Color("a48f60"))
	for i in range(3):
		var y := -height + 5 * scale + i * 5 * scale
		w.draw_line(p + Vector2(-rx + 1, y), p + Vector2(rx - 1, y), Color("746d4a"), 1, true)
	w._ellipse(p - Vector2(0, height), Vector2(rx, 5 * scale), Color("d1bd87") if full else Color("6e6e4e"))
	if full:
		w._ellipse(p - Vector2(0, height + 3 * scale), Vector2(rx - 3, 7 * scale), Color("d2c090"))
		w.draw_line(p + Vector2(0, -height - 9 * scale), p + Vector2(0, -3 * scale), Color("81744c"), 2, true)
	if sealed and full:
		w.draw_rect(Rect2(p + Vector2(-4, -height - 7) * scale, Vector2(8, 15) * scale), PAPER)
		w.draw_circle(p + Vector2(0, -height) * Vector2(1, 1), 2 * scale, Color("ae7758"))

static func _bollard(w, p: Vector2) -> void:
	w._ellipse(p + Vector2(0, 2), Vector2(8, 4), Color("647461"))
	w.draw_line(p, p - Vector2(0, 17), WOOD_DARK, 7, true)
	w._ellipse(p - Vector2(0, 18), Vector2(7, 3), Color("b5ac84"))
	w.draw_line(p + Vector2(-5, -6), p + Vector2(5, -6), Color("a99a71"), 2, true)

static func _lantern(w, p: Vector2, lit: bool) -> void:
	w.draw_line(p, p - Vector2(0, 37), WOOD_DARK, 3, true)
	w.draw_line(p - Vector2(0, 37), p + Vector2(14, -37), WOOD_DARK, 2, true)
	if lit:
		w._ellipse(p + Vector2(12, -23), Vector2(20, 19), Color(0.89, 0.7, 0.35, 0.1))
	w.draw_rect(Rect2(p + Vector2(6, -32), Vector2(13, 18)), Color("dac083") if lit else Color("9c9d7a"))
	for y in [-31, -16]:
		w.draw_line(p + Vector2(5, y), p + Vector2(20, y), Color("706d4e"), 2, true)

static func _poly(w, vertices: Array, color: Color) -> void:
	w.draw_colored_polygon(PackedVector2Array(vertices), color)
