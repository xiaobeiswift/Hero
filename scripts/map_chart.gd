class_name MapChart
extends Control
const Mist=preload("res://scripts/mistwood_region.gd")

## Read-only cartographic overview. Marker names and positions come from the world.
var map_id: String = "qingwei"
var player_position: Vector2 = Vector2(460, 430)
var markers: Dictionary = {}
var ui_font: Font
var current_target: String = ""
var bridge_repaired:bool=false

const CHART_SIZE := Vector2(780, 330)
const MAP_RECT := Rect2(Vector2(40, 20), Vector2(690, 270))
const WORLD_SIZE := Vector2(1600, 1050)
const PAPER := Color("d8d2b3")
const PAPER_LIGHT := Color("e5dfc4")
const INK := Color("324e45")
const MUTED := Color("7f9175")
const JADE := Color("698f80")
const WATER := Color("84a79a")
const GOLD := Color("c88e40")
const ROSE := Color("ae6551")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = CHART_SIZE
	queue_redraw()

func _draw() -> void:
	# A bordered paper chart, with a restrained surveying grid beneath the terrain.
	draw_style_box(_box(Color(0.04, 0.12, 0.11, 0.28), 8), Rect2(5, 5, 770, 315))
	draw_style_box(_box(PAPER, 8), Rect2(0, 0, CHART_SIZE.x, CHART_SIZE.y))
	draw_style_box(_box(Color(0, 0, 0, 0), 6, Color("9b9f7b")), Rect2(7, 7, 766, 316))
	draw_rect(MAP_RECT, Color("c8cbb0"))
	for i in range(9):
		var x := MAP_RECT.position.x + i * MAP_RECT.size.x / 8.0
		draw_line(Vector2(x, MAP_RECT.position.y), Vector2(x, MAP_RECT.end.y), Color(0.39, 0.51, 0.4, 0.10), 1)
	for i in range(6):
		var y := MAP_RECT.position.y + i * MAP_RECT.size.y / 5.0
		draw_line(Vector2(MAP_RECT.position.x, y), Vector2(MAP_RECT.end.x, y), Color(0.39, 0.51, 0.4, 0.10), 1)
	_draw_terrain_hatching()
	if map_id=="mistwood":
		_draw_mistwood_map()
	elif map_id=="frostbridge":
		_draw_frost_map()
	elif map_id == "sluice":
		_draw_sluice_map()
	else:
		_draw_village_map()
	_draw_markers()
	_draw_player()
	_draw_compass()
	_draw_legend()

func _point(world_position: Vector2) -> Vector2:
	return MAP_RECT.position + world_position / WORLD_SIZE * MAP_RECT.size

func _world_rect(position: Vector2, extent: Vector2) -> Rect2:
	return Rect2(_point(position), extent / WORLD_SIZE * MAP_RECT.size)

func _draw_terrain_hatching() -> void:
	# Distant ridgelines and patches of woodland are decorative, never map controls.
	for i in range(9):
		var p := _point(Vector2(86 + i * 173, 70 + sin(i * 2.7) * 22))
		draw_polyline(PackedVector2Array([p + Vector2(-18, 4), p + Vector2(-3, -7), p + Vector2(14, 4)]), Color(0.3, 0.46, 0.34, 0.20), 1.5, true)
	for i in range(18):
		var p := _point(Vector2(66 + fmod(i * 271.0, 1480), 155 + fmod(i * 171.0, 843)))
		draw_circle(p, 7, Color(0.28, 0.48, 0.34, 0.07))
		draw_polyline(PackedVector2Array([p + Vector2(-3, 3), p + Vector2(0, -3), p + Vector2(3, 3)]), Color(0.3, 0.47, 0.33, 0.23), 1, true)

func _draw_village_map() -> void:
	_road([Vector2(450, 1040), Vector2(419, 666), Vector2(503, 418), Vector2(632, 367), Vector2(758, 410), Vector2(981, 285), Vector2(1260, 351), Vector2(1535, 270)], 8)
	_road([Vector2(109, 428), Vector2(305, 396), Vector2(503, 418), Vector2(706, 475), Vector2(824, 471)], 7)
	_road([Vector2(209, 672), Vector2(419, 666), Vector2(663, 728), Vector2(900, 844), Vector2(1114, 776), Vector2(1260, 740), Vector2(1430, 970)], 7)
	_road([Vector2(1238, 404), Vector2(1246, 556), Vector2(1260, 740)], 6)
	_road([Vector2(1242, 543), Vector2(1350, 530), Vector2(1480, 560), Vector2(1580, 560)], 6)
	_road([Vector2(313, 396), Vector2(330, 315)], 5)
	_road([Vector2(632, 367), Vector2(632, 300)], 5)
	_ellipse(_point(Vector2(998, 484)), Vector2(174, 124) / WORLD_SIZE * MAP_RECT.size, Color("718e77"))
	_ellipse(_point(Vector2(998, 484)), Vector2(163, 115) / WORLD_SIZE * MAP_RECT.size, WATER)
	_ellipse_arc(_point(Vector2(1014, 479)), Vector2(104, 62) / WORLD_SIZE * MAP_RECT.size, Color(0.89, 0.91, 0.74, 0.5))
	_polygon_world([Vector2(1388, 602), Vector2(1600, 540), Vector2(1600, 1025), Vector2(1510, 955), Vector2(1451, 846), Vector2(1433, 729)], WATER)
	draw_rect(_world_rect(Vector2(823, 435), Vector2(117, 37)), Color("a9996b"))
	draw_rect(_world_rect(Vector2(1353, 746), Vector2(184, 65)), Color("a9996b"))
	_building(Vector2(186, 199), Vector2(228, 100), "药")
	_building(Vector2(510, 175), Vector2(244, 128), "茶")
	_building(Vector2(76, 525), Vector2(265, 123), "栈")
	_building(Vector2(546, 587), Vector2(214, 96), "武")
	_building(Vector2(826, 715), Vector2(152, 80), "祠")
	_text(Vector2(490, 158), "池塘", 10, Color("597f70"), 65, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_sluice_map() -> void:
	_road([Vector2(45, 520), Vector2(406, 510), Vector2(565, 449), Vector2(888, 456), Vector2(1118, 417), Vector2(1220, 350), Vector2(1480, 291)], 8)
	_road([Vector2(563, 311), Vector2(565, 449), Vector2(535, 610), Vector2(560, 759), Vector2(932, 775), Vector2(1220, 760), Vector2(1460, 835)], 8)
	_road([Vector2(1118, 417), Vector2(1114, 592), Vector2(1113, 765)], 6)
	_road([Vector2(298, 975), Vector2(432, 855), Vector2(560, 759)], 5)
	var river := PackedVector2Array()
	for i in range(28):
		var y := 0.0 + i * 38.8
		river.append(_point(Vector2(_channel_x(y) - 90, y)))
	for i in range(27, -1, -1):
		var y := 0.0 + i * 38.8
		river.append(_point(Vector2(_channel_x(y) + 90, y)))
	draw_colored_polygon(river, WATER)
	for y in [175.0, 334.0, 693.0, 929.0]:
		var p := _point(Vector2(_channel_x(y), y))
		draw_line(p + Vector2(-12, 0), p + Vector2(12, 0), Color("bdd0b6"), 1)
	_bridge(Vector2(744, 423), Vector2(283, 68))
	_bridge(Vector2(773, 738), Vector2(293, 70))
	_building(Vector2(335, 180), Vector2(288, 116), "旧仓")
	_building(Vector2(1193, 477), Vector2(240, 118), "闸所")
	var gate := _world_rect(Vector2(795, 488), Vector2(284, 147))
	draw_rect(gate, Color(0.29, 0.41, 0.33, 0.70))
	draw_rect(gate, Color("c2bd92"), false, 1.5)
	_text(gate.position + Vector2(0, 19), "故水闸", 11, PAPER_LIGHT, gate.size.x, HORIZONTAL_ALIGNMENT_CENTER)

func _channel_x(y: float) -> float:
	return 897.0 + sin((y - 145.0) / 900.0 * TAU) * 32.0 + (y - 145.0) * 0.07

func _road(points: Array[Vector2], width: float) -> void:
	var projected := PackedVector2Array()
	for point in points:
		projected.append(_point(point))
	draw_polyline(projected, Color("b6b998"), width + 2, true)
	draw_polyline(projected, PAPER_LIGHT, width, true)
	for point in projected:
		draw_circle(point, width * 0.5, PAPER_LIGHT)

func _building(position: Vector2, extent: Vector2, label: String) -> void:
	var rect := _world_rect(position, extent)
	draw_rect(Rect2(rect.position + Vector2(2, 3), rect.size), Color(0.24, 0.36, 0.28, 0.13))
	draw_rect(rect, JADE)
	draw_rect(rect, Color("4b7260"), false, 1)
	draw_line(rect.position + Vector2(2, 3), rect.position + Vector2(rect.size.x - 2, 3), Color("97ad8c"), 1)
	_text(rect.position + Vector2(0, rect.size.y * 0.5 + 4), label, 11, PAPER_LIGHT, rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)

func _bridge(position: Vector2, extent: Vector2) -> void:
	var rect := _world_rect(position, extent)
	draw_rect(rect, Color("b8b794"))
	draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), INK, 1.5)
	draw_line(rect.position + Vector2(0, rect.size.y), rect.end, INK, 1.5)
	for i in range(6):
		var x := rect.position.x + i * rect.size.x / 5.0
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color(0.34, 0.44, 0.32, 0.3), 1)

func _draw_markers() -> void:
	var label_rects: Array[Rect2] = []
	for id_value in markers:
		var id := String(id_value)
		var data: Variant = markers[id_value]
		if not data is Dictionary or not data.has("pos") or not data["pos"] is Vector2:
			continue
		var world_position: Vector2 = data["pos"]
		if not world_position.is_finite():
			continue
		var p := _point(world_position.clamp(Vector2.ZERO, WORLD_SIZE))
		var is_target := id == current_target
		if is_target:
			draw_circle(p, 10, Color(0.83, 0.6, 0.26, 0.18))
			draw_arc(p, 9, 0, TAU, 32, GOLD, 2, true)
		var marker_color := GOLD if is_target else INK
		if String(data.get("kind", "")) == "exit" or id in ["exit_sluice", "return_village"]:
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(5, 0), p + Vector2(0, 5), p + Vector2(-5, 0)]), marker_color)
		else:
			draw_circle(p, 4.2, marker_color)
			draw_circle(p, 1.5, PAPER_LIGHT)
		var marker_name := String(data.get("name", id))
		# Keep even unexpected long labels inside the chart and prevent collisions.
		var font := _font()
		while font.get_string_size(marker_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x > 135 and marker_name.length() > 2:
			marker_name = marker_name.left(marker_name.length() - 2) + "…"
		var text_width := maxf(36, font.get_string_size(marker_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14)
		var offset := Vector2(-text_width * 0.5, 10)
		if id in ["elder", "stranded_boatman", "sluice_boss"]:
			offset.y = -29
		if id == "exit_sluice":
			offset = Vector2(-text_width - 10, -11)
		if id == "return_village":
			offset = Vector2(10, -11)
		var rect := Rect2(p + offset, Vector2(text_width, 22))
		rect.position.x = clampf(rect.position.x, MAP_RECT.position.x + 3, MAP_RECT.end.x - rect.size.x - 3)
		rect.position.y = clampf(rect.position.y, MAP_RECT.position.y + 3, MAP_RECT.end.y - rect.size.y - 3)
		for previous in label_rects:
			if rect.intersects(previous.grow(2)):
				rect.position.y = clampf(previous.position.y - 25, MAP_RECT.position.y + 3, MAP_RECT.end.y - rect.size.y - 3)
		label_rects.append(rect)
		draw_style_box(_box(Color(0.89, 0.87, 0.75, 0.93), 4, Color("ba9c61") if is_target else Color(0.44, 0.55, 0.41, 0.32)), rect)
		_text(rect.position + Vector2(0, 15), marker_name, 12, Color("795a2d") if is_target else INK, rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_player() -> void:
	var safe_position := player_position if player_position.is_finite() else Vector2(460, 430)
	var p := _point(safe_position.clamp(Vector2.ZERO, WORLD_SIZE))
	draw_circle(p, 10, Color(0.87, 0.79, 0.55, 0.65))
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -9), p + Vector2(7, 7), p + Vector2(0, 4), p + Vector2(-7, 7)]), ROSE)
	draw_polyline(PackedVector2Array([p + Vector2(-7, 7), p + Vector2(0, -9), p + Vector2(7, 7)]), Color("f0d299"), 1.5, true)

func _draw_compass() -> void:
	var p := Vector2(752, 40)
	_text(Vector2(741, 28), "北", 10, INK, 22, HORIZONTAL_ALIGNMENT_CENTER)
	draw_colored_polygon(PackedVector2Array([p, p + Vector2(-4, 12), p + Vector2(0, 9), p + Vector2(4, 12)]), INK)
	draw_line(p + Vector2(0, 11), p + Vector2(0, 22), MUTED, 1)

func _draw_legend() -> void:
	var y := 309.0
	var p := Vector2(45, y)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(4, 4), p + Vector2(-4, 4)]), ROSE)
	_text(Vector2(57, y + 4), "所在位置", 11, INK)
	draw_circle(Vector2(150, y), 3.5, INK)
	_text(Vector2(162, y + 4), "人物 / 地点", 11, INK)
	draw_arc(Vector2(272, y), 6, 0, TAU, 24, GOLD, 1.7, true)
	_text(Vector2(285, y + 4), "当前机缘", 11, INK)
	var title:String={"qingwei":"青苇渡 · 渡口图","sluice":"废闸古道 · 两岸图","frostbridge":"霜桥驿 · 印台图","mistwood":"雾竹坡 · 听雨图"}.get(map_id,"江湖舆图")
	_text(Vector2(505, y + 4), title + "  /  仅供览图", 11, Color("68795f"), 225, HORIZONTAL_ALIGNMENT_RIGHT)

func _font() -> Font:
	return ui_font if ui_font != null else ThemeDB.fallback_font

func _text(position: Vector2, text: String, font_size: int, color: Color, width: float = -1, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(_font(), position, text, alignment, width, font_size, color)

func _box(color: Color, radius: int, border: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.border_color = border
	box.set_border_width_all(1 if border.a > 0 else 0)
	return box

func _polygon_world(points: Array[Vector2], color: Color) -> void:
	var projected := PackedVector2Array()
	for p in points:
		projected.append(_point(p))
	draw_colored_polygon(projected, color)

func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(32):
		var angle := i * TAU / 32.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)

func _ellipse_arc(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(33):
		var angle := i * TAU / 32.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_polyline(points, color, 1, true)

func _draw_frost_map() -> void:
	_road([Vector2(40,500),Vector2(405,500),Vector2(405,365),Vector2(835,388),Vector2(1150,385),Vector2(1500,385)],8)
	_road([Vector2(405,500),Vector2(405,760),Vector2(835,800),Vector2(1080,800),Vector2(1320,745)],8)
	_road([Vector2(1080,385),Vector2(1080,800)],6)
	draw_rect(_world_rect(Vector2(733,120),Vector2(204,930)),Color("779b9b"))
	draw_rect(_world_rect(Vector2(703,350),Vector2(264,80)),Color("c8c2a2"))
	if bridge_repaired:draw_rect(_world_rect(Vector2(703,760),Vector2(264,80)),Color("c8c2a2"))
	else:
		draw_rect(_world_rect(Vector2(703,760),Vector2(66,80)),Color("a1ac99"))
		draw_rect(_world_rect(Vector2(901,760),Vector2(66,80)),Color("a1ac99"))
	_building(Vector2(290,205),Vector2(248,110),"驿馆")
	_building(Vector2(1030,205),Vector2(246,120),"文书")
	_building(Vector2(1160,565),Vector2(250,132),"封仓")

func _draw_mistwood_map()->void:
	for path in Mist.PATHS:
		var route:Array[Vector2]=[];route.assign(path);_road(route,6)
	_ellipse(_point(Mist.POND_CENTER),Mist.POND_RADII/WORLD_SIZE*MAP_RECT.size,WATER)
	for terrace in Mist.TERRACES:
		draw_rect(_world_rect(terrace.position,terrace.size),Color("86987b"))
	for p in Mist.BAMBOO:
		var at=_point(p)
		draw_line(at+Vector2(-2,4),at+Vector2(-2,-6),Color("638a61"),2)
		draw_line(at+Vector2(2,3),at+Vector2(2,-8),Color("638a61"),2)
	draw_rect(_world_rect(Mist.CAMP_FOOTPRINT.position,Mist.CAMP_FOOTPRINT.size),Color("b8a67c"))
	_text(_point(Vector2(710,635)),"叠石坡",11,INK,70,HORIZONTAL_ALIGNMENT_CENTER)
