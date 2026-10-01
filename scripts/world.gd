class_name VillageWorld
extends Node2D
const Mist=preload("res://scripts/mistwood_region.gd")
const Frost=preload("res://scripts/frostbridge_region.gd")

## Original, vector-drawn wuxia village. No imported art or physics assets required.
signal interacted(id: String)
signal moved(position: Vector2)
signal location_changed(name: String)

var active: bool = true
var player_pos: Vector2 = Vector2(460, 430)
var quest_stage: int = 0
var map_id: String = "qingwei"
var mist_target_id:String=""
var chapter_stage:int=0
var chapter_ending:String=""
var mentor_pending:bool=false
var chapter_target_id:String="chapter_host"
var bridge_repaired:bool=false
var resource_depleted:Array[String]=[]
var side_stage: int = 0
var side_target_id: String = ""
var nearby_id: String = ""
var nearby_name: String = ""
var viewport_rect: Rect2 = Rect2(24, 108, 910, 568)
var ui_font: Font
var companion_active: bool = false
var companion_name:String="沈青"
var shen_target_id:String=""
var personal_target_id:String=""
var companion_pos: Vector2 = Vector2(429, 451)

const WORLD_SIZE := Vector2(1600, 1050)
const SPEED := 185.0
const C_INK := Color("223b3c")
const C_ROOF := Color("365652")
const C_ROOF_LIGHT := Color("4a6c62")
const C_PAPER := Color("e4d7b4")
const C_GOLD := Color("dfa856")
const C_TEAL := Color("65aa99")
const C_GROUND := Color("a6b292")

var camera_pos := Vector2.ZERO
var time_passed: float = 0.0
var walk_time: float = 0.0
var moving: bool = false
var facing := Vector2.DOWN
var current_location: String = "青苇渡"
var trees: Array[Dictionary] = []
var stones: Array[Dictionary] = []
var grasses: Array[Dictionary] = []
var buildings: Array[Dictionary] = [
	{"pos": Vector2(186, 199), "size": Vector2(228, 100), "name": "回春堂", "type": "clinic"},
	{"pos": Vector2(510, 175), "size": Vector2(244, 128), "name": "听雨茶肆", "type": "tea"},
	{"pos": Vector2(76, 525), "size": Vector2(265, 123), "name": "青苇客栈", "type": "inn"},
	{"pos": Vector2(546, 587), "size": Vector2(214, 96), "name": "练武堂", "type": "hall"},
	{"pos": Vector2(826, 715), "size": Vector2(152, 80), "name": "山神祠", "type": "shrine"},
]
var interactables: Dictionary = {
	"mentor":{"pos":Vector2(650,720),"name":"岑远","kind":"elder"},
	"elder": {"pos": Vector2(520, 440), "name": "陆伯", "kind": "elder"},
	"healer": {"pos": Vector2(330, 330), "name": "沈青", "kind": "healer"},
	"herb": {"pos": Vector2(1260, 350), "name": "青穗草", "kind": "herb"},
	"bandit": {"pos": Vector2(1260, 740), "name": "蒲横", "kind": "bandit"},
	"board": {"pos": Vector2(720, 480), "name": "村中告示", "kind": "board"},
	"shrine": {"pos": Vector2(900, 820), "name": "无名碑", "kind": "shrine"},
	"exit_sluice": {"pos": Vector2(1480, 560), "name": "废闸古道", "kind": "exit"},
}
var _village_points: Dictionary = {}
var _sluice_points: Dictionary = {
	"exit_frostbridge":{"pos":Vector2(1450,250),"name":"霜桥古道","kind":"exit"},
	"return_village": {"pos": Vector2(150, 520), "name": "返回青苇渡", "kind": "exit"},
	"stranded_boatman": {"pos": Vector2(560, 760), "name": "受困船工", "kind": "elder"},
	"ledger_runner": {"pos": Vector2(1210, 350), "name": "传令人", "kind": "villager"},
	"sluice_boss": {"pos": Vector2(1210, 760), "name": "闸首罗沉", "kind": "bandit"},
	"sluice_cache": {"pos": Vector2(570, 320), "name": "旧仓药棚", "kind": "cache"},
}
var _sluice_buildings: Array[Dictionary] = [
	{"pos": Vector2(335, 180), "size": Vector2(288, 116), "name": "旧 河 仓", "type": "ruin"},
	{"pos": Vector2(1193, 477), "size": Vector2(240, 118), "name": "守 闸 所", "type": "ruin"},
]
var _sluice_trees: Array[Dictionary] = []

func _ready() -> void:
	if _village_points.is_empty():
		_village_points = interactables.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 732981
	for i in range(580):
		var p := Vector2(rng.randf_range(35, 1565), rng.randf_range(120, 1010))
		grasses.append({"pos": p, "length": rng.randf_range(3, 9), "alpha": rng.randf_range(0.08, 0.22)})
	var tree_points: Array[Vector2] = [
		Vector2(82, 179), Vector2(120, 368), Vector2(165, 453), Vector2(55, 450),
		Vector2(426, 209), Vector2(820, 240), Vector2(780, 135), Vector2(967, 158),
		Vector2(1109, 190), Vector2(1148, 285), Vector2(1407, 269), Vector2(1470, 389),
		Vector2(1363, 493), Vector2(1467, 566), Vector2(1357, 611), Vector2(1525, 697),
		Vector2(1437, 827), Vector2(1374, 924), Vector2(1131, 944), Vector2(1050, 830),
		Vector2(783, 933), Vector2(634, 873), Vector2(510, 762), Vector2(374, 846),
		Vector2(190, 840), Vector2(65, 765), Vector2(455, 556), Vector2(793, 596),
		Vector2(66, 1009), Vector2(265, 990), Vector2(449, 967), Vector2(990, 1000),
	]
	for p in tree_points:
		if p.distance_to(Vector2(1480, 560)) < 70:
			continue
		trees.append({"pos": p, "scale": rng.randf_range(0.8, 1.2), "variant": rng.randi_range(0, 2)})
	for i in range(55):
		var p := Vector2(rng.randf_range(35, 1560), rng.randf_range(155, 990))
		stones.append({"pos": p, "size": rng.randf_range(3, 9)})
	for p: Vector2 in [Vector2(124, 240), Vector2(213, 355), Vector2(276, 715), Vector2(404, 930), Vector2(731, 951), Vector2(672, 580), Vector2(696, 360), Vector2(1370, 252), Vector2(1451, 373), Vector2(1091, 166), Vector2(1366, 906), Vector2(1490, 726), Vector2(1110, 948)]:
		_sluice_trees.append({"pos": p, "scale": rng.randf_range(0.7, 1.0), "variant": 2 if _sluice_trees.size() % 3 == 0 else 0})
	camera_pos = _camera_target()
	_update_nearby()
	queue_redraw()

func change_map(id: String, spawn: Vector2) -> void:
	if _village_points.is_empty():
		_village_points = interactables.duplicate(true)
	map_id = id if id in ["qingwei", "sluice", "frostbridge", "mistwood"] else "qingwei"
	interactables = Mist.points() if map_id=="mistwood" else (Frost.points() if map_id=="frostbridge" else (_sluice_points if map_id == "sluice" else _village_points).duplicate(true))
	teleport(spawn)
	current_location = _location_for_position()
	location_changed.emit(current_location)
	queue_redraw()

func get_region_hint() -> String:
	if map_id=="mistwood":return "山雨留在竹尺与石盂。巡哨有三种通行方案，西南营地可调息。"
	if map_id=="frostbridge":return ("南北两桥皆可通行。" if bridge_repaired else "北桥通行，南桥待修。")+"驿馆、碑文与文书房藏着三印的来历。"
	if map_id == "qingwei":
		return "村东古道通向废闸。" if quest_stage >= 6 else "沿土路拜访村人，寻回渡灯。"
	match side_stage:
		0: return "南岸问船夫，北岸寻脚夫，拼起废闸的线索。"
		1: return "另一位见证人还在闸边，两条石桥连通两岸。"
		2: return "证言已齐。前往东南闸台，与守关人对质。"
		_: return "废闸已重归安宁。旧仓尚有遗物，可以继续探索。"

func _safe_spawn() -> Vector2:
	return Vector2(150,550) if map_id=="mistwood" else (Vector2(190,500) if map_id=="frostbridge" else (Vector2(190, 520) if map_id == "sluice" else Vector2(460, 430)))

func teleport(position: Vector2) -> void:
	var destination := position if position.is_finite() else _safe_spawn()
	destination = Vector2(clampf(destination.x, 35, 1565), clampf(destination.y, 155, 1010))
	if not _can_walk(destination):
		var found := false
		for radius in range(12, 253, 12):
			for i in range(24):
				var angle := float(i) * TAU / 24.0
				var candidate := destination + Vector2(cos(angle), sin(angle)) * radius
				if _can_walk(candidate):
					destination = candidate
					found = true
					break
			if found:
				break
		if not found:
			destination = _safe_spawn()
	player_pos = destination
	companion_pos = player_pos + Vector2(-31, 21)
	camera_pos = _camera_target()
	_update_nearby()
	moved.emit(player_pos)
	queue_redraw()

func get_npc_name(id: String) -> String:
	if companion_active and companion_name=="沈青" and id=="healer":return "药铺伙计"
	if companion_active and companion_name=="唐栖" and id=="bridge_worker":return "修桥工位"
	return String(interactables.get(id, {}).get("name", id))

func _process(delta: float) -> void:
	time_passed += delta
	var direction := Vector2.ZERO
	if active:
		direction.x = float(_pressed("move_right", KEY_D, KEY_RIGHT)) - float(_pressed("move_left", KEY_A, KEY_LEFT))
		direction.y = float(_pressed("move_down", KEY_S, KEY_DOWN)) - float(_pressed("move_up", KEY_W, KEY_UP))
		direction = direction.normalized()
	moving = direction.length_squared() > 0.0
	if moving:
		facing = direction
		walk_time += delta * 10.5
		var target := player_pos + direction * SPEED * delta
		var next_x := Vector2(target.x, player_pos.y)
		if _can_walk(next_x):
			player_pos.x = next_x.x
		var next_y := Vector2(player_pos.x, target.y)
		if _can_walk(next_y):
			player_pos.y = next_y.y
		moved.emit(player_pos)
	if companion_active:
		var companion_target := player_pos - facing * 34.0 + Vector2(-10, 10)
		companion_pos = companion_pos.lerp(companion_target, minf(delta * 4.2, 1.0))
	camera_pos = camera_pos.lerp(_camera_target(), minf(delta * 9.0, 1.0))
	_update_nearby()
	var new_location := _location_for_position()
	if new_location != current_location:
		current_location = new_location
		location_changed.emit(current_location)
	queue_redraw()

func _location_for_position() -> String:
	if map_id=="mistwood":return "雾竹坡 · 听雨关" if player_pos.x>1180 else ("雾竹坡 · 雨池" if player_pos.y<500 else "雾竹坡 · 竹林道")
	if map_id=="frostbridge":return "霜桥驿 · 西街" if player_pos.x<835 else ("霜桥驿 · 文书房" if player_pos.y<550 else "霜桥驿 · 封仓")
	if map_id == "sluice":
		if player_pos.x < 760:
			return "废闸 · 旧仓岸" if player_pos.y < 530 else "废闸 · 断舟滩"
		return "废闸 · 北堤" if player_pos.y < 530 else "废闸 · 守闸台"
	if player_pos.x > 1380 and player_pos.y > 450 and player_pos.y < 610:
		return "废闸古道"
	if player_pos.x > 1100 and player_pos.y < 565:
		return "东北苇岸"
	if player_pos.x > 1080 and player_pos.y >= 565:
		return "旧渡口"
	if player_pos.y > 720:
		return "无名碑庭"
	return "青苇渡"

func _pressed(action: String, letter: Key, arrow: Key) -> bool:
	return (InputMap.has_action(action) and Input.is_action_pressed(action)) or Input.is_physical_key_pressed(letter) or Input.is_physical_key_pressed(arrow)

func _unhandled_input(event: InputEvent) -> void:
	if not active or nearby_id.is_empty():
		return
	var triggered := false
	if InputMap.has_action("interact"):
		triggered = event.is_action_pressed("interact") and not event.is_echo()
	if event is InputEventKey:
		triggered = triggered or (event.pressed and not event.echo and event.keycode in [KEY_E, KEY_ENTER, KEY_KP_ENTER])
	if triggered:
		interacted.emit(nearby_id)
		get_viewport().set_input_as_handled()

func _camera_target() -> Vector2:
	return Vector2(clampf(player_pos.x - viewport_rect.size.x * 0.5, 0, maxf(0, WORLD_SIZE.x - viewport_rect.size.x)), clampf(player_pos.y - viewport_rect.size.y * 0.5, 0, maxf(0, WORLD_SIZE.y - viewport_rect.size.y)))

func _update_nearby() -> void:
	nearby_id = ""
	nearby_name = ""
	var closest := 75.0
	for id: String in interactables:
		var point: Vector2 = interactables[id]["pos"]
		var distance := player_pos.distance_to(point)
		if distance < closest:
			closest = distance
			nearby_id = id
			nearby_name = get_npc_name(id)

func _can_walk(p: Vector2) -> bool:
	if not p.is_finite():
		return false
	if map_id=="mistwood":return Mist.walkable(p)
	if map_id=="frostbridge":return Frost.walkable(p,bridge_repaired)
	if map_id == "sluice":
		return _can_walk_sluice(p)
	if p.x < 30 or p.y < 155 or p.x > 1570 or p.y > 1015:
		return false
	for b in buildings:
		var rect := Rect2(b["pos"], b["size"]).grow(9)
		if rect.has_point(p):
			return false
	var pond_distance := Vector2((p.x - 998.0) / 162.0, (p.y - 484.0) / 118.0).length_squared()
	if pond_distance < 1.0 and not Rect2(827, 437, 122, 40).has_point(p):
		return false
	if p.x > 1440 and p.y > 602 and not Rect2(1350, 737, 196, 78).has_point(p):
		return false
	for tree in trees:
		if p.distance_to(tree["pos"]) < 12.0:
			return false
	return true

func _draw() -> void:
	if map_id=="mistwood":
		Mist.draw(self);return
	if map_id=="frostbridge":
		Frost.draw(self)
		return
	if map_id == "sluice":
		_draw_sluice()
		return
	draw_rect(Rect2(Vector2.ZERO, viewport_rect.size), Color("aeb99b"))
	draw_set_transform(-camera_pos)
	_draw_ground()
	_draw_mountains()
	_draw_paths()
	_path([Vector2(1239, 543), Vector2(1350, 530), Vector2(1480, 560), Vector2(1580, 560)], 43)
	_draw_region_sign(Vector2(1480, 560), "废闸古道", 1)
	_draw_pond()
	_draw_gardens()
	_draw_fences()
	_draw_bamboo(Vector2(1222, 265), 11)
	_draw_bamboo(Vector2(1443, 424), 8)
	_draw_bamboo(Vector2(1390, 902), 8)
	for stone in stones:
		_draw_stone(stone["pos"], stone["size"])
	_draw_world_caption(Vector2(1190, 180), "东  北  苇  岸", "REEDBANK PATH")
	_draw_world_caption(Vector2(1130, 890), "旧  渡  口", "THE OLD FERRY")
	_draw_training_ground()
	_draw_board(Vector2(720, 480))
	_draw_herb(Vector2(1260, 350))
	_draw_old_ferry()
	_draw_memorial()
	_draw_camp()
	var layers: Array[Dictionary] = []
	for b in buildings:
		layers.append({"y": b["pos"].y + b["size"].y, "kind": "building", "data": b})
	for tree in trees:
		layers.append({"y": tree["pos"].y, "kind": "tree", "data": tree})
	for id: String in ["elder", "healer", "bandit", "mentor"]:
		layers.append({"y": interactables[id]["pos"].y, "kind": "npc", "id": id})
	layers.append({"y": player_pos.y, "kind": "player"})
	if companion_active:
		layers.append({"y": companion_pos.y, "kind": "companion"})
	layers.append({"y": 410.0, "kind": "extra", "pos": Vector2(656, 410), "robe": Color("a8754e")})
	layers.append({"y": 561.0, "kind": "extra", "pos": Vector2(379, 561), "robe": Color("727e62")})
	layers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["y"] < b["y"])
	for item in layers:
		match item["kind"]:
			"building": _draw_building(item["data"])
			"tree": _draw_tree(item["data"])
			"npc": _draw_npc(item["id"])
			"player": _draw_person(player_pos, Color("356d66"), true, "player")
			"companion": _draw_companion()
			"extra": _draw_person(item["pos"], item["robe"], false, "villager")
	_draw_lantern_post(Vector2(429, 343))
	_draw_lantern_post(Vector2(782, 350))
	_draw_lantern_post(Vector2(366, 687))
	_draw_lantern_post(Vector2(808, 846))
	_draw_particles()
	_draw_nameplates()
	draw_set_transform(Vector2.ZERO)
	_draw_view_framing()

func _draw_ground() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), C_GROUND)
	_ellipse(Vector2(860, 358), Vector2(590, 330), Color("aeb898"))
	_ellipse(Vector2(271, 664), Vector2(380, 370), Color("a4b191"))
	_ellipse(Vector2(1338, 800), Vector2(320, 275), Color("93a485"))
	_ellipse(Vector2(1264, 330), Vector2(250, 245), Color("9eaf8b"))
	for grass in grasses:
		var p: Vector2 = grass["pos"]
		var length: float = grass["length"]
		var color := Color(0.22, 0.36, 0.25, grass["alpha"])
		draw_line(p, p + Vector2(-2, -length), color, 1.0, true)
		draw_line(p + Vector2(3, 0), p + Vector2(5, -length * 0.8), color, 1.0, true)

func _draw_mountains() -> void:
	_poly([Vector2(0, 0), Vector2(1600, 0), Vector2(1600, 165), Vector2(1420, 78), Vector2(1290, 155), Vector2(1120, 32), Vector2(928, 152), Vector2(737, 18), Vector2(553, 126), Vector2(351, 35), Vector2(177, 138), Vector2(0, 67)], Color("607e71"))
	_poly([Vector2(0, 45), Vector2(140, 111), Vector2(278, 76), Vector2(440, 157), Vector2(640, 67), Vector2(806, 176), Vector2(1042, 91), Vector2(1218, 196), Vector2(1372, 102), Vector2(1600, 181), Vector2(1600, 0), Vector2(0, 0)], Color("769083"))
	_poly([Vector2(0, 96), Vector2(141, 161), Vector2(328, 105), Vector2(477, 174), Vector2(650, 130), Vector2(876, 199), Vector2(1040, 143), Vector2(1260, 209), Vector2(1460, 162), Vector2(1600, 213), Vector2(1600, 0), Vector2(0, 0)], Color(0.51, 0.61, 0.53, 0.28))
	for i in range(7):
		_ellipse(Vector2(110 + i * 256, 151 + sin(i * 2.4) * 15), Vector2(175, 20), Color(0.85, 0.86, 0.71, 0.2))

func _draw_paths() -> void:
	_path([Vector2(460, 1040), Vector2(431, 829), Vector2(419, 666), Vector2(478, 526), Vector2(503, 418), Vector2(632, 367), Vector2(758, 410), Vector2(825, 360), Vector2(981, 285), Vector2(1178, 317), Vector2(1260, 351), Vector2(1535, 270)], 63.0)
	_path([Vector2(109, 428), Vector2(305, 396), Vector2(503, 418), Vector2(706, 475), Vector2(824, 471)], 57.0)
	_path([Vector2(321, 316), Vector2(313, 388)], 48.0)
	_path([Vector2(633, 321), Vector2(632, 367)], 51.0)
	_path([Vector2(209, 672), Vector2(219, 711), Vector2(419, 666), Vector2(663, 728), Vector2(900, 844), Vector2(1114, 776), Vector2(1260, 740), Vector2(1500, 1010)], 59.0)
	_path([Vector2(1238, 404), Vector2(1246, 556), Vector2(1260, 740)], 42.0)
	for i in range(27):
		var p := Vector2(482 + sin(i * 1.8) * 24, 480 + i * 16)
		if p.y < 652:
			_poly([p + Vector2(-9, -2), p + Vector2(4, -5), p + Vector2(9, 1), p + Vector2(-6, 4)], Color(0.86, 0.82, 0.66, 0.6))
	for p: Vector2 in [Vector2(487, 409), Vector2(536, 420), Vector2(583, 437), Vector2(629, 450), Vector2(680, 465)]:
		_ellipse(p, Vector2(15, 7), Color("b4b69a"))
		draw_arc(p, 10, 0.3, 2.4, 12, Color("c6c5a5"), 1, true)

func _path(points: Array[Vector2], width: float) -> void:
	var packed := PackedVector2Array(points)
	draw_polyline(packed, Color("899b80"), width + 10, true)
	draw_polyline(packed, Color("c2be9c"), width, true)
	draw_polyline(packed, Color("cbc4a1"), width - 9, true)
	for p in points:
		draw_circle(p, width * 0.5, Color("c2be9c"))
		draw_circle(p, (width - 9) * 0.5, Color("cbc4a1"))

func _draw_pond() -> void:
	_ellipse(Vector2(998, 488), Vector2(174, 124), Color("6e8e79"))
	_ellipse(Vector2(998, 484), Vector2(163, 115), Color("729d91"))
	_ellipse(Vector2(1010, 478), Vector2(148, 100), Color("80aa9b"))
	_ellipse(Vector2(1031, 462), Vector2(126, 69), Color("8bb09e"))
	for i in range(12):
		var p := Vector2(911 + fmod(i * 37.0, 180), 414 + fmod(i * 29.0, 137))
		var ripple_width := 10 + sin(time_passed * 1.3 + i) * 4
		_ellipse_arc(p, Vector2(ripple_width, 2.7), Color(0.85, 0.89, 0.75, 0.28))
	for p: Vector2 in [Vector2(1060, 552), Vector2(1097, 520), Vector2(955, 550), Vector2(1081, 540)]:
		_ellipse(p, Vector2(12, 5), Color("547d60"))
		_poly([p, p + Vector2(12, -4), p + Vector2(12, 1)], Color("80aa9b"))
		if p.x > 1000:
			draw_circle(p + Vector2(0, -5), 3.8, Color("ddc3a0"))
	for i in range(20):
		var angle := float(i) / 20.0 * TAU
		var p := Vector2(998, 484) + Vector2(cos(angle) * 167, sin(angle) * 118)
		_draw_stone(p, 6 + fmod(i * 3.0, 5))
	# Wooden fishing pier, connected to the west shore.
	draw_rect(Rect2(823, 439, 117, 37), Color("4a6256"))
	draw_rect(Rect2(823, 435, 117, 34), Color("a18c64"))
	for i in range(12):
		draw_line(Vector2(825 + i * 10, 436), Vector2(825 + i * 10, 468), Color("6d7155"), 1)
	for p: Vector2 in [Vector2(831, 439), Vector2(930, 439), Vector2(831, 469), Vector2(930, 469)]:
		draw_rect(Rect2(p - Vector2(3, 14), Vector2(6, 18)), Color("5e654d"))
	_ellipse(Vector2(920, 455), Vector2(8, 6), Color("887c56"))
	draw_line(Vector2(919, 448), Vector2(950, 431), C_INK, 1.3, true)
	draw_line(Vector2(950, 431), Vector2(969, 459), Color(0.9, 0.85, 0.7, 0.6), 0.7, true)

func _draw_gardens() -> void:
	# Carefully tended medicinal herb beds beside the clinic.
	for y in range(3):
		draw_rect(Rect2(167, 324 + y * 21, 69, 14), Color("8f9871"))
		for x in range(5):
			var p := Vector2(173 + x * 13, 333 + y * 21)
			draw_line(p, p + Vector2(0, -7), Color("3c7254"), 1.3)
			_ellipse(p + Vector2(-3, -5), Vector2(4, 2), Color("5f9164"))
			_ellipse(p + Vector2(3, -8), Vector2(4, 2), Color("567e55"))
			if (x + y) % 3 == 0:
				draw_circle(p + Vector2(0, -10), 2, Color("dcc69b"))
	# Clay jars and drying racks.
	for p: Vector2 in [Vector2(389, 319), Vector2(406, 322), Vector2(779, 319), Vector2(358, 632)]:
		_ellipse(p + Vector2(2, 2), Vector2(9, 4), Color(0.12, 0.24, 0.21, 0.14))
		_ellipse(p + Vector2(0, -6), Vector2(7, 10), Color("9b7958"))
		_ellipse(p + Vector2(0, -14), Vector2(4, 2), Color("596251"))
	# Tea tables and cushions outside the tea house.
	for p: Vector2 in [Vector2(578, 338), Vector2(710, 355)]:
		_ellipse(p + Vector2(3, 5), Vector2(22, 8), Color(0.18, 0.27, 0.2, 0.15))
		draw_rect(Rect2(p + Vector2(-3, -4), Vector2(6, 12)), Color("62634d"))
		_ellipse(p + Vector2(0, -8), Vector2(20, 9), Color("a88c62"))
		draw_circle(p + Vector2(-5, -10), 3, C_PAPER)
		draw_circle(p + Vector2(7, -8), 2.5, C_PAPER)
		_ellipse(p + Vector2(-27, 2), Vector2(9, 4), Color("738b73"))
		_ellipse(p + Vector2(27, 2), Vector2(9, 4), Color("738b73"))

func _draw_fences() -> void:
	_fence(Vector2(82, 483), Vector2(296, 470), 9)
	_fence(Vector2(177, 398), Vector2(251, 398), 4)
	_fence(Vector2(541, 775), Vector2(719, 824), 8)
	_fence(Vector2(1027, 641), Vector2(1120, 682), 5)

func _fence(a: Vector2, b: Vector2, posts: int) -> void:
	draw_line(a - Vector2(0, 16), b - Vector2(0, 16), Color("6e795b"), 3, true)
	draw_line(a - Vector2(0, 7), b - Vector2(0, 7), Color("81906b"), 2, true)
	for i in range(posts):
		var p := a.lerp(b, float(i) / float(posts - 1))
		draw_line(p, p - Vector2(0, 24), Color("646f55"), 4, true)
		draw_line(p - Vector2(1, 23), p - Vector2(1, 2), Color("9aa27b"), 1, true)

func _draw_building(b: Dictionary) -> void:
	var p: Vector2 = b["pos"]
	var size: Vector2 = b["size"]
	var name_text: String = b["name"]
	var shrine: bool = b["type"] == "shrine"
	var wall := Color("d3c6a1") if not shrine else Color("bfba94")
	# Long late-afternoon shadow, stepped foundation, plaster and timber frame.
	_poly([p + Vector2(8, size.y), p + Vector2(size.x + 12, size.y), p + Vector2(size.x + 46, size.y + 30), p + Vector2(30, size.y + 30)], Color(0.17, 0.28, 0.23, 0.15))
	draw_rect(Rect2(p + Vector2(-7, size.y - 10), Vector2(size.x + 14, 18)), Color("76816b"))
	draw_rect(Rect2(p + Vector2(-12, size.y + 6), Vector2(size.x + 24, 9)), Color("a3a68a"))
	draw_rect(Rect2(p + Vector2(-15, size.y + 15), Vector2(size.x + 30, 6)), Color("b7b79b"))
	draw_rect(Rect2(p, size), wall)
	draw_rect(Rect2(p + Vector2(0, 22), Vector2(size.x, 15)), Color(0.2, 0.29, 0.24, 0.16))
	for x in [8.0, size.x * 0.32, size.x * 0.68, size.x - 8]:
		draw_rect(Rect2(p + Vector2(x - 3, 20), Vector2(6, size.y - 20)), Color("66705a"))
	draw_rect(Rect2(p + Vector2(0, size.y - 7), Vector2(size.x, 7)), Color("858c70"))
	var door_w := 37.0 if not shrine else 42.0
	var door := p + Vector2(size.x * 0.5 - door_w * 0.5, size.y - 58)
	draw_rect(Rect2(door, Vector2(door_w, 58)), Color("465d50"))
	draw_rect(Rect2(door + Vector2(3, 4), Vector2(door_w - 6, 54)), Color("5a6d57"))
	draw_line(door + Vector2(door_w * 0.5, 0), door + Vector2(door_w * 0.5, 58), Color("c0af81"), 1)
	for side in [0.17, 0.83]:
		var wp := p + Vector2(size.x * side - 18, size.y - 51)
		draw_rect(Rect2(wp, Vector2(36, 29)), Color("8d997b"))
		draw_rect(Rect2(wp + Vector2(3, 3), Vector2(30, 23)), Color("bcbf95"))
		for x in range(4):
			draw_line(wp + Vector2(4 + x * 9, 2), wp + Vector2(4 + x * 9, 28), Color("687a60"), 1.4)
		draw_line(wp + Vector2(1, 14), wp + Vector2(35, 14), Color("687a60"), 1.4)
	# Broad curved eaves and hand-drawn tile courses.
	var roof_top := p.y - 33.0
	var roof_bottom := p.y + 31.0
	_poly([Vector2(p.x - 25, roof_bottom - 10), Vector2(p.x - 8, roof_bottom - 12), Vector2(p.x + 28, roof_top), Vector2(p.x + size.x - 28, roof_top), Vector2(p.x + size.x + 8, roof_bottom - 12), Vector2(p.x + size.x + 25, roof_bottom - 10), Vector2(p.x + size.x + 16, roof_bottom + 2), Vector2(p.x - 16, roof_bottom + 2)], C_ROOF)
	for row in range(6):
		var t := float(row) / 5.0
		var yy := lerpf(roof_top + 6, roof_bottom - 2, t)
		var left := lerpf(p.x + 26, p.x - 13, t)
		var right := lerpf(p.x + size.x - 26, p.x + size.x + 13, t)
		draw_line(Vector2(left, yy), Vector2(right, yy), C_ROOF_LIGHT, 1.7, true)
		for tile in range(int((right - left) / 15.0)):
			var xx := left + 6 + tile * 15 + (row % 2) * 4
			draw_line(Vector2(xx, yy - 6), Vector2(xx - 2, yy - 1), Color(0.15, 0.29, 0.26, 0.4), 1)
	draw_polyline(PackedVector2Array([Vector2(p.x - 26, roof_bottom - 10), Vector2(p.x - 16, roof_bottom + 2), Vector2(p.x + size.x + 16, roof_bottom + 2), Vector2(p.x + size.x + 26, roof_bottom - 10)]), Color("638272"), 3, true)
	draw_line(Vector2(p.x + 25, roof_top), Vector2(p.x + size.x - 25, roof_top), Color("7a927b"), 4, true)
	# Gold-lettered wood plaque.
	var plaque_width := 78.0 if name_text.length() == 3 else 101.0
	var plaque_p := p + Vector2((size.x - plaque_width) * 0.5, 30)
	draw_rect(Rect2(plaque_p, Vector2(plaque_width, 24)), Color("405b50"))
	draw_rect(Rect2(plaque_p + Vector2(2, 2), Vector2(plaque_width - 4, 20)), Color("bba36c"), false, 1)
	_label(plaque_p + Vector2(0, 17), name_text, 15, C_PAPER, plaque_width, HORIZONTAL_ALIGNMENT_CENTER)
	for x in [19.0, size.x - 19]:
		_draw_lantern(p + Vector2(x, 45), 0.75)
	if b["type"] == "tea":
		var flag_p := p + Vector2(size.x + 21, 57)
		draw_line(flag_p - Vector2(0, 21), flag_p + Vector2(0, 55), Color("57694f"), 3)
		_poly([flag_p + Vector2(-18, -16), flag_p + Vector2(14, -16), flag_p + Vector2(14, 34), flag_p + Vector2(-2, 26), flag_p + Vector2(-18, 34)], Color("c7bd91"))
		_label(flag_p + Vector2(-15, 12), "茶", 24, Color("576a51"), 28, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_tree(tree: Dictionary) -> void:
	var p: Vector2 = tree["pos"]
	var s: float = tree["scale"]
	var variant: int = tree["variant"]
	_ellipse(p + Vector2(13, 4), Vector2(33, 11) * s, Color(0.17, 0.28, 0.23, 0.12))
	_poly([p + Vector2(-7, 1) * s, p + Vector2(-3, -43) * s, p + Vector2(4, -55) * s, p + Vector2(6, -11) * s, p + Vector2(12, 2) * s], Color("596d52"))
	draw_line(p + Vector2(0, -23) * s, p + Vector2(-20, -44) * s, Color("596d52"), 4 * s, true)
	draw_line(p + Vector2(3, -32) * s, p + Vector2(22, -55) * s, Color("596d52"), 4 * s, true)
	var dark := Color("4b765d") if variant != 2 else Color("7f875c")
	var light := Color("71916d") if variant != 2 else Color("a6a06c")
	_ellipse(p + Vector2(-17, -51) * s, Vector2(29, 23) * s, dark)
	_ellipse(p + Vector2(20, -56) * s, Vector2(33, 25) * s, dark)
	_ellipse(p + Vector2(2, -73) * s, Vector2(33, 29) * s, dark)
	_ellipse(p + Vector2(-14, -63) * s, Vector2(26, 22) * s, light)
	_ellipse(p + Vector2(17, -70) * s, Vector2(25, 20) * s, light)
	_ellipse(p + Vector2(1, -84) * s, Vector2(24, 18) * s, Color("819b74") if variant != 2 else Color("b6aa75"))
	for i in range(10):
		var dot := p + Vector2(sin(i * 4.7) * 31, -65 + cos(i * 7.2) * 21) * s
		draw_line(dot, dot + Vector2(6, -2) * s, Color(0.76, 0.79, 0.57, 0.22), 1.4, true)

func _draw_bamboo(p: Vector2, count: int) -> void:
	for i in range(count):
		var base := p + Vector2((i - count * 0.5) * 13, sin(i * 4.1) * 17)
		var height := 69 + fmod(i * 13.0, 61)
		var lean := sin(time_passed * 0.6 + i * 1.2) * 2.0 + sin(i * 1.6) * 7
		draw_line(base, base + Vector2(lean, -height), Color("467859"), 3, true)
		for j in range(4):
			var node := base + Vector2(lean * (j + 1) / 5.0, -height * (j + 1) / 5.0)
			draw_line(node + Vector2(-2, 0), node + Vector2(3, 0), Color("9fae7c"), 1, true)
			var side := 1 if (i + j) % 2 == 0 else -1
			draw_line(node, node + Vector2(20 * side, -16), Color("447554"), 1, true)
			_poly([node + Vector2(8 * side, -8), node + Vector2(27 * side, -15), node + Vector2(17 * side, -6)], Color("5a845b"))
			_poly([node + Vector2(12 * side, -10), node + Vector2(14 * side, -27), node + Vector2(20 * side, -16)], Color("648e62"))

func _draw_stone(p: Vector2, size: float) -> void:
	_poly([p + Vector2(-size, 0), p + Vector2(-size * 0.7, -size * 0.5), p + Vector2(size * 0.2, -size * 0.8), p + Vector2(size, -size * 0.2), p + Vector2(size * 0.7, size * 0.35), p + Vector2(-size * 0.4, size * 0.4)], Color("929f83"))
	draw_line(p + Vector2(-size * 0.65, -size * 0.5), p + Vector2(size * 0.2, -size * 0.8), Color("b8bda0"), 1, true)

func _draw_training_ground() -> void:
	# Ring, wooden training dummy and a rack of practice swords.
	_ellipse(Vector2(652, 751), Vector2(73, 31), Color(0.51, 0.58, 0.43, 0.13))
	_ellipse_arc(Vector2(652, 751), Vector2(63, 26), Color(0.83, 0.8, 0.64, 0.7))
	var p := Vector2(721, 733)
	draw_line(p, p - Vector2(0, 41), Color("816e50"), 7)
	draw_line(p - Vector2(19, 22), p + Vector2(19, -22), Color("816e50"), 5)
	draw_circle(p - Vector2(0, 40), 7, Color("aa8e61"))
	for i in range(4):
		p = Vector2(570 + i * 13, 725)
		draw_line(p, p - Vector2(0, 29), Color("536d5c"), 2)
		draw_line(p + Vector2(-4, -22), p + Vector2(4, -22), C_GOLD, 2)
	draw_line(Vector2(563, 717), Vector2(616, 717), Color("8a815c"), 4)

func _draw_board(p: Vector2) -> void:
	_ellipse(p + Vector2(5, 3), Vector2(29, 7), Color(0.2, 0.3, 0.23, 0.13))
	for x in [-20, 20]:
		draw_line(p + Vector2(x, 0), p + Vector2(x, -52), Color("687255"), 4)
	draw_rect(Rect2(p + Vector2(-30, -50), Vector2(60, 38)), Color("7d8060"))
	_poly([p + Vector2(-37, -50), p + Vector2(0, -62), p + Vector2(37, -50)], C_ROOF)
	for i in range(3):
		var sheet := p + Vector2(-24 + i * 18, -44)
		draw_rect(Rect2(sheet, Vector2(14, 24)), Color("d9cfaa"))
		for j in range(4):
			draw_line(sheet + Vector2(3, 5 + j * 4), sheet + Vector2(11, 5 + j * 4), Color("9d9872"), 1)
		draw_circle(sheet + Vector2(7, 2), 1.1, C_GOLD)

func _draw_herb(p: Vector2) -> void:
	_ellipse(p, Vector2(29, 13), Color("879e74"))
	for i in range(5):
		var offset := Vector2(sin(i * 2.3) * 15, cos(i * 1.7) * 6)
		var q := p + offset
		draw_line(q, q + Vector2(0, -18), Color("4b7753"), 2)
		_poly([q + Vector2(0, -6), q + Vector2(-11, -13), q + Vector2(-8, -4)], Color("577f58"))
		_poly([q + Vector2(0, -10), q + Vector2(10, -17), q + Vector2(7, -8)], Color("658d5d"))
		for j in range(5):
			var angle := j * TAU / 5.0
			draw_circle(q + Vector2(0, -20) + Vector2(cos(angle), sin(angle)) * 3.5, 3.3, Color("bfdbc3"))
		draw_circle(q + Vector2(0, -20), 2, C_GOLD)
	if quest_stage > 0:
		for i in range(4):
			var q := p + Vector2(sin(time_passed + i * 1.8) * 28, -28 + cos(time_passed * 1.4 + i) * 15)
			draw_circle(q, 1.7, Color(0.73, 0.97, 0.76, 0.6))

func _draw_old_ferry() -> void:
	# Reeds, river channel and the timber landing behind the ferryman.
	_poly([Vector2(1388, 602), Vector2(1600, 540), Vector2(1600, 1025), Vector2(1510, 955), Vector2(1451, 846), Vector2(1433, 729)], Color("75998a"))
	_poly([Vector2(1410, 618), Vector2(1600, 558), Vector2(1600, 1009), Vector2(1532, 941), Vector2(1474, 842), Vector2(1450, 731)], Color("82a594"))
	for i in range(9):
		var p := Vector2(1480 + fmod(i * 21.0, 104), 645 + i * 31)
		_ellipse_arc(p, Vector2(12 + sin(time_passed + i) * 3, 3), Color(0.78, 0.85, 0.72, 0.35))
	draw_rect(Rect2(1356, 751, 184, 67), Color("596d57"))
	draw_rect(Rect2(1353, 746, 184, 65), Color("a38f64"))
	for i in range(18):
		draw_line(Vector2(1357 + i * 10, 747), Vector2(1357 + i * 10, 810), Color("7d7c55"), 1.2)
	for p: Vector2 in [Vector2(1361, 748), Vector2(1444, 748), Vector2(1525, 748), Vector2(1361, 812), Vector2(1444, 812), Vector2(1525, 812)]:
		draw_line(p, p - Vector2(0, 29), Color("5e6c51"), 5)
		draw_circle(p - Vector2(0, 29), 3.2, Color("a49a71"))
	draw_line(Vector2(1361, 728), Vector2(1525, 728), Color("a69768"), 2)
	# Small moored skiff, painted as an asymmetric tapered silhouette.
	_poly([Vector2(1502, 829), Vector2(1552, 811), Vector2(1574, 825), Vector2(1542, 845), Vector2(1516, 846)], Color("526d58"))
	_poly([Vector2(1509, 829), Vector2(1552, 817), Vector2(1565, 825), Vector2(1537, 840), Vector2(1517, 840)], Color("a79668"))
	draw_line(Vector2(1528, 824), Vector2(1537, 838), Color("6c7757"), 3)
	draw_line(Vector2(1507, 829), Vector2(1485, 809), Color("c6ba86"), 1)
	# River grass along the far bank.
	for i in range(12):
		var p := Vector2(1420 + sin(i * 1.7) * 11, 605 + i * 16)
		for j in range(3):
			draw_line(p + Vector2(j * 3, 0), p + Vector2(j * 4 - 5, -21 - j * 4), Color("5c825b"), 1.4, true)

func _draw_memorial() -> void:
	var p := Vector2(900, 819)
	_ellipse(p + Vector2(5, 0), Vector2(31, 10), Color(0.2, 0.3, 0.24, 0.14))
	draw_rect(Rect2(p + Vector2(-24, -7), Vector2(48, 8)), Color("8c987c"))
	_poly([p + Vector2(-15, -9), p + Vector2(-15, -40), p + Vector2(-9, -46), p + Vector2(11, -46), p + Vector2(17, -40), p + Vector2(17, -9)], Color("96a388"))
	draw_line(p + Vector2(-13, -39), p + Vector2(-13, -11), Color("b8bea0"), 2)
	_label(p + Vector2(-14, -20), "归", 20, Color("667d67"), 28, HORIZONTAL_ALIGNMENT_CENTER)
	for i in range(3):
		draw_line(p + Vector2(-6 + i * 6, -1), p + Vector2(-6 + i * 6, -14), Color("a17f4e"), 1)
		draw_circle(p + Vector2(-6 + i * 6, -15), 1, Color("d7b678"))

func _draw_camp() -> void:
	var p := Vector2(1328, 733)
	_poly([p + Vector2(-38, -6), p + Vector2(2, -64), p + Vector2(62, -2)], Color("727653"))
	_poly([p + Vector2(2, -64), p + Vector2(7, -6), p + Vector2(62, -2)], Color("8e8c5c"))
	_poly([p + Vector2(-9, -23), p + Vector2(2, -59), p + Vector2(10, -7), p + Vector2(-11, -5)], Color("4c6450"))
	for offset in [Vector2(-25, 8), Vector2(54, 7)]:
		draw_line(p + offset, p + offset + Vector2(3, -17), Color("6d7051"), 2)
	var fire := Vector2(1303, 795)
	for i in range(7):
		var a := i * TAU / 7.0
		_draw_stone(fire + Vector2(cos(a) * 15, sin(a) * 8), 4)
	draw_line(fire + Vector2(-8, -2), fire + Vector2(9, 3), Color("655d41"), 4)
	draw_line(fire + Vector2(8, -2), fire + Vector2(-7, 4), Color("75664b"), 4)
	_poly([fire + Vector2(-7, 0), fire + Vector2(-2, -13 - sin(time_passed * 8) * 3), fire + Vector2(2, -6), fire + Vector2(5, -19), fire + Vector2(8, 0)], Color("d59a52"))
	draw_circle(fire + Vector2(0, -3), 4, Color("e5bf71"))

func _draw_npc(id: String) -> void:
	var p: Vector2 = interactables[id]["pos"]
	var robe := Color("8d8163")
	if id == "healer": robe = Color("c1c4a5")
	if id == "healer" and companion_active and companion_name=="沈青":
		_draw_person(p, Color("9a9676"), false, "villager")
		return
	if id == "bandit": robe = Color("8e6853")
	if id == "mentor": robe=Color("6b7e94")
	_draw_person(p, robe, false, id)

func _draw_person(p: Vector2, robe: Color, is_player: bool, kind: String) -> void:
	var bob := sin(walk_time) * 1.6 if is_player and moving else sin(time_passed * 2.0 + p.x) * 0.35
	var stride := sin(walk_time) * 4.0 if is_player and moving else 0.0
	_ellipse(p + Vector2(1, 2), Vector2(12, 5), Color(0.12, 0.25, 0.22, 0.24))
	if is_player:
		_ellipse_arc(p + Vector2(0, 2), Vector2(17, 7), Color(0.85, 0.76, 0.49, 0.55))
	var q := p + Vector2(0, bob)
	# Boots, trailing cloak and folded robe.
	draw_line(q + Vector2(-4, -10), q + Vector2(-5, stride), Color("314842"), 4.5, true)
	draw_line(q + Vector2(4, -10), q + Vector2(5, -stride), Color("314842"), 4.5, true)
	if is_player:
		_poly([q + Vector2(-8, -29), q + Vector2(6, -27), q + Vector2(14 + sin(walk_time) * 2, -4), q + Vector2(0, -9), q + Vector2(-15 - sin(walk_time) * 2, -3)], Color("315d58"))
	_poly([q + Vector2(-7, -28), q + Vector2(7, -28), q + Vector2(11, -7), q + Vector2(-10, -7)], robe)
	_poly([q + Vector2(-5, -27), q + Vector2(5, -22), q + Vector2(-2, -10), q + Vector2(-8, -8)], robe.lightened(0.17))
	draw_line(q + Vector2(-7, -15), q + Vector2(8, -15), Color("bca774") if is_player else Color("6d785b"), 2.4, true)
	draw_line(q + Vector2(-7, -24), q + Vector2(-11, -12 - stride * 0.3), robe, 5, true)
	draw_line(q + Vector2(7, -24), q + Vector2(11, -12 + stride * 0.3), robe, 5, true)
	draw_circle(q + Vector2(0, -33), 7, Color("d5b78c"))
	# Ink-black tied hair and topknot silhouette.
	draw_arc(q + Vector2(0, -34), 6.5, PI, TAU + 0.25, 12, Color("314741"), 4, true)
	draw_circle(q + Vector2(-1, -42), 3.3, Color("314741"))
	if is_player:
		draw_line(q + Vector2(-3, -41), q + Vector2(4, -41), C_GOLD, 1.3, true)
		# Diagonal scabbard, gold guard and light pommel.
		draw_line(q + Vector2(-10, -5), q + Vector2(13, -35), Color("213f3c"), 3.8, true)
		draw_line(q + Vector2(7, -32), q + Vector2(15, -26), C_GOLD, 2.1, true)
		draw_line(q + Vector2(11, -32), q + Vector2(16, -39), Color("d7c79d"), 2.5, true)
		_poly([q + Vector2(-6, -29), q + Vector2(-12, -24), q + Vector2(-16 - sin(time_passed * 2) * 2, -15), q + Vector2(-9, -20)], Color("74a391"))
	elif kind == "elder":
		draw_line(q + Vector2(16, 0), q + Vector2(16, -31), Color("796b4d"), 2.5, true)
		_poly([q + Vector2(-4, -31), q + Vector2(4, -31), q + Vector2(1, -21)], Color("ddd8bd"))
		draw_arc(q + Vector2(0, -35), 7.0, PI, TAU, 12, Color("c0c6ab"), 3, true)
	elif kind == "healer":
		draw_line(q + Vector2(-7, -32), q + Vector2(7, -32), Color("5f866b"), 2)
		draw_rect(Rect2(q + Vector2(7, -15), Vector2(8, 9)), Color("927d57"))
	elif kind == "bandit":
		_poly([q + Vector2(-12, -34), q + Vector2(0, -42), q + Vector2(13, -34)], Color("7d7454"))
		draw_line(q + Vector2(13, -8), q + Vector2(19, -29), Color("bfc0a2"), 3, true)
		draw_line(q + Vector2(9, -10), q + Vector2(17, -8), Color("656b51"), 2)

func _draw_companion() -> void:
	# A compact travelling healer: pale robe, jade scarf and medicine satchel.
	draw_set_transform(-camera_pos + companion_pos, 0, Vector2(0.87, 0.87))
	if companion_name=="唐栖":
		_draw_person(Vector2.ZERO,Color("82978c"),false,"companion")
		draw_line(Vector2(-8,-28),Vector2(9,-12),Color("715b43"),3)
		draw_rect(Rect2(6,-22,6,17),Color("c2a976"))
		for y in range(-20,-6,3):draw_line(Vector2(6,y),Vector2(9,y),Color("786246"),1)
		draw_set_transform(-camera_pos)
		return
	_draw_person(Vector2.ZERO, Color("cbd0b0"), false, "companion")
	_poly([Vector2(-7, -28), Vector2(6, -26), Vector2(3, -21), Vector2(-4, -23), Vector2(-8, -13), Vector2(-10, -20)], Color("619483"))
	draw_line(Vector2(-4, -27), Vector2(10, -13), Color("7c8060"), 1.7, true)
	draw_style_box(_round_box(Color("e3d8b8"), 2), Rect2(6, -17, 12, 12))
	draw_line(Vector2(9, -11), Vector2(15, -11), Color("548575"), 1.7)
	draw_line(Vector2(12, -14), Vector2(12, -8), Color("548575"), 1.7)
	draw_circle(Vector2(-6, -37), 2, C_GOLD)
	draw_set_transform(-camera_pos)

func _draw_lantern_post(p: Vector2) -> void:
	draw_line(p, p - Vector2(0, 61), Color("617359"), 4, true)
	draw_line(p - Vector2(0, 60), p + Vector2(20, -60), Color("617359"), 3, true)
	_draw_lantern(p + Vector2(17, -42), 0.9)

func _draw_lantern(p: Vector2, scale_factor: float) -> void:
	var sway := sin(time_passed * 1.5 + p.x * 0.02) * 1.1
	var q := p + Vector2(sway, 0)
	draw_line(q - Vector2(0, 15) * scale_factor, q - Vector2(0, 6) * scale_factor, Color("7d7550"), 1, true)
	_ellipse(q, Vector2(9, 12) * scale_factor, Color("c89253"))
	_ellipse(q - Vector2(2, 0) * scale_factor, Vector2(5, 10) * scale_factor, Color("dfb46d"))
	draw_line(q - Vector2(6, 10) * scale_factor, q + Vector2(6, -10) * scale_factor, Color("82734d"), 2)
	draw_line(q - Vector2(5, -10) * scale_factor, q + Vector2(5, 10) * scale_factor, Color("82734d"), 2)
	draw_line(q + Vector2(0, 10) * scale_factor, q + Vector2(0, 18) * scale_factor, Color("b48f52"), 1.5)

func _draw_nameplates() -> void:
	var visible_ids: Array = ["chapter_host","chapter_clerk","chapter_archive","bridge_worker"] if map_id=="frostbridge" else (["stranded_boatman", "ledger_runner", "sluice_boss"] if map_id == "sluice" else ["elder", "healer", "bandit", "mentor"])
	if map_id=="mistwood":visible_ids=["mist_guide","mist_scout","mist_gate"]
	for id: String in visible_ids:
		var p: Vector2 = interactables[id]["pos"]
		var selected := nearby_id == id
		if selected:
			_ellipse_arc(p + Vector2(0, 1), Vector2(21, 8), Color("ecd298"))
		var width := 80.0
		var display_name: String = get_npc_name(id)
		var display_color := Color("e9dfbc") if map_id == "sluice" else C_INK
		_label(p + Vector2(-width * 0.5, -83 if id=="mist_guide" else -53), display_name, 13, display_color, width, HORIZONTAL_ALIGNMENT_CENTER, true)
	var target_id := _quest_target_id()
	if not target_id.is_empty():
		var target_p: Vector2 = interactables[target_id]["pos"]
		var yy := (-47.0 if target_id in ["herb", "exit_sluice", "return_village", "sluice_cache", "exit_frostbridge", "return_sluice"] else -73.0) + sin(time_passed * 2.5) * 3
		_poly([target_p + Vector2(0, yy - 7), target_p + Vector2(6, yy), target_p + Vector2(0, yy + 7), target_p + Vector2(-6, yy)], C_GOLD)
		draw_line(target_p + Vector2(0, yy - 3), target_p + Vector2(0, yy + 1), C_INK, 1.4)
	if not nearby_id.is_empty() and active:
		var p: Vector2 = interactables[nearby_id]["pos"]
		var label_text := "E  " + ("采集" if (nearby_id == "herb" or nearby_id.begins_with("frost_")) else "前往" if nearby_id in ["exit_sluice", "return_village", "exit_frostbridge", "return_sluice"] else "查看" if nearby_id in ["board", "shrine", "sluice_cache"] else "交谈")
		var r := Rect2(p + Vector2(-36, 16), Vector2(72, 23))
		draw_style_box(_round_box(Color("294942"), 5), r)
		_label(r.position + Vector2(0, 16), label_text, 12, C_PAPER, 72, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_world_caption(p: Vector2, title: String, subtitle: String) -> void:
	_label(p, title, 17, Color(0.2, 0.35, 0.28, 0.52), 240, HORIZONTAL_ALIGNMENT_CENTER)
	_label(p + Vector2(0, 18), subtitle, 8, Color(0.2, 0.35, 0.28, 0.42), 240, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_particles() -> void:
	for i in range(20):
		var x := fmod(i * 97.7 + time_passed * (3 + i % 3), WORLD_SIZE.x)
		var y := 175 + fmod(i * 113.0 + time_passed * 4.0, 800)
		var p := Vector2(x + sin(time_passed + i) * 9, y)
		var alpha := 0.15 + sin(time_passed * 1.5 + i) * 0.12
		_poly([p + Vector2(-3, 0), p + Vector2(0, -2), p + Vector2(4, 0), p + Vector2(0, 2)], Color(0.88, 0.81, 0.51, alpha))

func _draw_view_framing() -> void:
	var s := viewport_rect.size
	# Subtle scene-edge ink wash, like a moving painted scroll.
	for i in range(12):
		var alpha := (1.0 - float(i) / 12.0) * 0.012
		draw_rect(Rect2(i, i, s.x - i * 2, s.y - i * 2), Color(0.1, 0.22, 0.19, alpha), false, 2)
	var target_id := _quest_target_id()
	if target_id.is_empty():
		return
	var target: Vector2 = interactables[target_id]["pos"] - camera_pos
	if Rect2(35, 45, s.x - 70, s.y - 115).has_point(target):
		return
	var edge := Vector2(clampf(target.x, 68, s.x - 68), clampf(target.y, 80, s.y - 100))
	var direction := (target - s * 0.5).normalized()
	var angle := direction.angle()
	var arrow := PackedVector2Array()
	for point: Vector2 in [Vector2(11, 0), Vector2(-5, -6), Vector2(-2, 0), Vector2(-5, 6)]:
		arrow.append(edge + point.rotated(angle))
	draw_circle(edge, 19, Color(0.13, 0.27, 0.23, 0.88))
	draw_arc(edge, 19, 0, TAU, 32, Color(0.84, 0.7, 0.43, 0.8), 1.2, true)
	draw_colored_polygon(arrow, C_GOLD)
	var label_p := edge + Vector2(-56, 26)
	draw_style_box(_round_box(Color(0.13, 0.27, 0.23, 0.9), 4), Rect2(label_p - Vector2(0, 1), Vector2(112, 23)))
	_label(label_p + Vector2(0, 15), get_npc_name(target_id) + "  ·  " + str(int(player_pos.distance_to(interactables[target_id]["pos"]) / 10.0)) + "步", 11, C_PAPER, 112, HORIZONTAL_ALIGNMENT_CENTER)

func _quest_target_id() -> String:
	if interactables.has(shen_target_id):return shen_target_id
	if map_id=="mistwood":return mist_target_id if interactables.has(mist_target_id) else "mist_guide"
	if map_id=="qingwei" and mentor_pending:return "mentor"
	if interactables.has(personal_target_id):return personal_target_id
	if interactables.has(mist_target_id):return mist_target_id
	if map_id=="frostbridge":return chapter_target_id if interactables.has(chapter_target_id) else "chapter_host"
	if map_id == "sluice":
		if interactables.has(side_target_id):
			return side_target_id
		match side_stage:
			0: return "stranded_boatman"
			1: return "ledger_runner"
			2: return "sluice_boss"
			_: return "exit_frostbridge" if chapter_stage<4 else "return_village"
	match quest_stage:
		0, 4, 5: return "elder"
		1: return "herb"
		2: return "healer"
		3: return "bandit"
		_: return "exit_sluice" if side_stage < 3 else ""

# -----------------------------------------------------------------------------
# Region II: the abandoned floodgate. Coordinates and collision match its canals.
# -----------------------------------------------------------------------------
func _sluice_channel_x(y: float) -> float:
	return 897.0 + sin((y - 145.0) / 900.0 * TAU) * 32.0 + (y - 145.0) * 0.07

func _can_walk_sluice(p: Vector2) -> bool:
	if p.x < 30 or p.y < 155 or p.x > 1570 or p.y > 1015:
		return false
	for building in _sluice_buildings:
		if Rect2(building["pos"], building["size"]).grow(9).has_point(p):
			return false
	var on_bridge := Rect2(744, 423, 283, 68).has_point(p) or Rect2(773, 738, 293, 70).has_point(p)
	if absf(p.x - _sluice_channel_x(p.y)) < 83 and not on_bridge:
		return false
	if Rect2(795, 488, 47, 147).grow(6).has_point(p) or Rect2(1032, 488, 47, 147).grow(6).has_point(p):
		return false
	for tree in _sluice_trees:
		if p.distance_to(tree["pos"]) < 12:
			return false
	return true

func _draw_sluice() -> void:
	draw_rect(Rect2(Vector2.ZERO, viewport_rect.size), Color("7c9186"))
	draw_set_transform(-camera_pos)
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("7c9186"))
	_ellipse(Vector2(442, 702), Vector2(460, 430), Color("849584"))
	_ellipse(Vector2(1293, 553), Vector2(350, 451), Color("758a7c"))
	_draw_mountains()
	# Sparse marsh vegetation catches the last light.
	for grass in grasses:
		var p: Vector2 = grass["pos"]
		if absf(p.x - _sluice_channel_x(p.y)) < 107:
			continue
		var length: float = grass["length"]
		draw_line(p, p + Vector2(-3, -length), Color(0.26, 0.39, 0.28, 0.24), 1, true)
		draw_line(p + Vector2(3, 0), p + Vector2(5, -length * 0.7), Color(0.55, 0.6, 0.43, 0.25), 1, true)
	_sluice_path([Vector2(45, 520), Vector2(185, 521), Vector2(406, 510), Vector2(565, 449), Vector2(888, 456), Vector2(1118, 417), Vector2(1220, 350), Vector2(1480, 291)], 58)
	_sluice_path([Vector2(563, 311), Vector2(565, 449), Vector2(535, 610), Vector2(560, 759), Vector2(707, 771), Vector2(932, 775), Vector2(1113, 765), Vector2(1220, 760), Vector2(1460, 835)], 58)
	_sluice_path([Vector2(1118, 417), Vector2(1114, 592), Vector2(1113, 765)], 41)
	_sluice_path([Vector2(298, 975), Vector2(432, 855), Vector2(560, 759)], 38)
	_draw_sluice_channel()
	_draw_stone_bridge(Rect2(744, 423, 283, 68))
	_draw_stone_bridge(Rect2(773, 738, 293, 70))
	_draw_floodgate()
	_draw_region_sign(Vector2(150, 520), "青苇渡", -1)
	_draw_sluice_cache(Vector2(570, 320))
	_draw_sluice_boat(Vector2(742, 829))
	for i in range(12):
		var y := 200 + i * 66.0
		_draw_reeds(Vector2(_sluice_channel_x(y) - 112, y), 5)
		if i % 2 == 0:
			_draw_reeds(Vector2(_sluice_channel_x(y) + 108, y + 19), 6)
	for p: Vector2 in [Vector2(370, 418), Vector2(1150, 348), Vector2(1383, 706), Vector2(456, 698), Vector2(1210, 861), Vector2(706, 232)]:
		_draw_stone(p, 13)
		_draw_stone(p + Vector2(12, 7), 6)
	# Broken boundary walls, whose low stones remain walkable.
	_draw_ruined_wall(Vector2(220, 661), 173)
	_draw_ruined_wall(Vector2(1038, 279), 201)
	_draw_ruined_wall(Vector2(1225, 919), 206)
	var layers: Array[Dictionary] = []
	for building in _sluice_buildings:
		layers.append({"y": building["pos"].y + building["size"].y, "kind": "ruin", "data": building})
	for tree in _sluice_trees:
		layers.append({"y": tree["pos"].y, "kind": "tree", "data": tree})
	for id: String in ["stranded_boatman", "ledger_runner", "sluice_boss"]:
		layers.append({"y": interactables[id]["pos"].y, "kind": "npc", "id": id})
	layers.append({"y": player_pos.y, "kind": "player"})
	if companion_active:
		layers.append({"y": companion_pos.y, "kind": "companion"})
	layers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["y"] < b["y"])
	for item in layers:
		match item["kind"]:
			"ruin": _draw_ruined_storehouse(item["data"])
			"tree": _draw_tree(item["data"])
			"npc":
				var id: String = item["id"]
				var robe := Color("a39c80") if id == "stranded_boatman" else Color("838c6b") if id == "ledger_runner" else Color("8a6351")
				_draw_person(interactables[id]["pos"], robe, false, interactables[id]["kind"])
			"player": _draw_person(player_pos, Color("356d66"), true, "player")
			"companion": _draw_companion()
	_draw_lantern_post(Vector2(728, 490))
	_draw_lantern_post(Vector2(1088, 821))
	_draw_lantern_post(Vector2(1307, 731))
	# Ground mist and slow fireflies, with no screen-space obscuring overlay.
	for i in range(5):
		var p := Vector2(240 + i * 272 + sin(time_passed * 0.1 + i) * 14, 898 + sin(i * 4.0) * 62)
		_ellipse(p, Vector2(151, 12), Color(0.79, 0.83, 0.7, 0.055))
	for i in range(15):
		var p := Vector2(540 + sin(i * 3.71 + time_passed * 0.11) * 397, 580 + cos(i * 4.6) * 336)
		draw_circle(p, 1.6, Color(0.92, 0.81, 0.48, maxf(0, sin(time_passed * 1.2 + i)) * 0.6))
	_label(Vector2(263, 155), "废  闸  ·  旧  河  仓", 20, Color(0.85, 0.84, 0.68, 0.6), 345, HORIZONTAL_ALIGNMENT_CENTER)
	_label(Vector2(1120, 948), "水 落 石 出  /  THE ABANDONED SLUICE", 11, Color(0.85, 0.84, 0.68, 0.48), 340, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_region_sign(Vector2(1450,250),"霜桥古道",1)
	_draw_nameplates()
	draw_set_transform(Vector2.ZERO)
	_draw_view_framing()

func _sluice_path(points: Array[Vector2], width: float) -> void:
	draw_polyline(PackedVector2Array(points), Color("6d8273"), width + 9, true)
	draw_polyline(PackedVector2Array(points), Color("9aa28a"), width, true)
	for p in points:
		draw_circle(p, width * 0.5, Color("9aa28a"))
	for i in range(points.size() - 1):
		var distance := points[i].distance_to(points[i + 1])
		for step in range(0, int(distance), 24):
			var p := points[i].lerp(points[i + 1], float(step) / distance)
			_poly([p + Vector2(-11, 0), p + Vector2(-5, -7), p + Vector2(10, -5), p + Vector2(14, 3), p + Vector2(-4, 6)], Color("aeb098"))

func _draw_sluice_channel() -> void:
	for layer in range(3):
		var polygon := PackedVector2Array()
		var width := 97.0 - layer * 7.0
		for i in range(49):
			var y := 120.0 + i * 20.0
			polygon.append(Vector2(_sluice_channel_x(y) - width, y))
		for i in range(48, -1, -1):
			var y := 120.0 + i * 20.0
			polygon.append(Vector2(_sluice_channel_x(y) + width, y))
		draw_colored_polygon(polygon, [Color("566f63"), Color("7c9281"), Color("476f6b")][layer])
	for i in range(27):
		var y := 167 + i * 31.0
		var center := Vector2(_sluice_channel_x(y), y)
		var xx := sin(i * 3.7) * 51
		var drift := fmod(time_passed * 7 + i * 13, 30)
		_ellipse_arc(center + Vector2(xx, drift), Vector2(12 + sin(time_passed + i) * 4, 2.5), Color(0.67, 0.8, 0.71, 0.3))
		for side in [-1, 1]:
			var p := center + Vector2(side * 92, 0)
			draw_rect(Rect2(p - Vector2(5, 12), Vector2(10, 24)), Color("859580"))
			draw_line(p + Vector2(-5, -12), p + Vector2(5, -12), Color("acb098"), 1)

func _draw_stone_bridge(rect: Rect2) -> void:
	var p := rect.position
	var s := rect.size
	draw_rect(Rect2(p + Vector2(-7, 5), s + Vector2(14, 8)), Color("465f55"))
	draw_rect(rect, Color("a1a68e"))
	for i in range(int(s.x / 22)):
		var xx := p.x + i * 22
		draw_line(Vector2(xx, p.y + 2), Vector2(xx, p.y + s.y - 2), Color("828f7a"), 1)
		draw_line(Vector2(xx, p.y + s.y * 0.5), Vector2(xx + 22, p.y + s.y * 0.5), Color("88937d"), 1)
	for side in [0.0, s.y]:
		draw_line(p + Vector2(-4, side - 11), p + Vector2(s.x + 4, side - 11), Color("849680"), 5)
		draw_line(p + Vector2(-4, side - 14), p + Vector2(s.x + 4, side - 14), Color("b3b59a"), 2)
		for i in range(7):
			var post := p + Vector2(float(i) * s.x / 6.0, side)
			draw_rect(Rect2(post + Vector2(-4, -22), Vector2(8, 26)), Color("7a8e78"))
			draw_circle(post + Vector2(0, -23), 5, Color("a9af93"))

func _draw_floodgate() -> void:
	# Weathered stone towers support a suspended timber gate and wooden winch.
	for xx in [795.0, 1032.0]:
		var p := Vector2(xx, 488)
		draw_rect(Rect2(p + Vector2(4, 8), Vector2(47, 147)), Color("4c675b"))
		draw_rect(Rect2(p, Vector2(47, 147)), Color("899a81"))
		for row in range(7):
			draw_line(p + Vector2(0, row * 20), p + Vector2(47, row * 20), Color("627d6b"), 1)
			draw_line(p + Vector2(14 + (row % 2) * 17, row * 20), p + Vector2(14 + (row % 2) * 17, row * 20 + 20), Color("627d6b"), 1)
		draw_rect(Rect2(p + Vector2(-5, -7), Vector2(57, 13)), Color("a1ac90"))
		draw_line(p + Vector2(5, 12), p + Vector2(5, 140), Color("a8b196"), 2)
	draw_rect(Rect2(808, 500, 260, 16), Color("6b7860"))
	draw_line(Vector2(810, 500), Vector2(1069, 500), Color("a2a587"), 3)
	for i in range(11):
		var xx := 846 + i * 17.0
		draw_rect(Rect2(xx, 545, 15, 91), Color("5c7260") if i % 2 == 0 else Color("667c64"))
		draw_line(Vector2(xx + 3, 549), Vector2(xx + 3, 629), Color("7d8a6b"), 1)
	draw_line(Vector2(845, 570), Vector2(1029, 570), Color("3e5b50"), 7)
	draw_line(Vector2(845, 617), Vector2(1029, 617), Color("3e5b50"), 7)
	for xx in [885.0, 986.0]:
		draw_line(Vector2(xx, 492), Vector2(xx, 553), Color("b1a77a"), 2)
	var hub := Vector2(931, 488)
	draw_circle(hub, 22, Color("667963"))
	draw_arc(hub, 21, 0, TAU, 32, Color("a39b73"), 3, true)
	for i in range(8):
		var angle := i * TAU / 8.0
		draw_line(hub, hub + Vector2(cos(angle), sin(angle)) * 27, Color("a39b73"), 3, true)
	draw_circle(hub, 6, Color("c2b17b"))
	_label(Vector2(880, 540), "故  水  闸", 14, C_PAPER, 109, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_ruined_storehouse(building: Dictionary) -> void:
	_draw_building(building)
	var p: Vector2 = building["pos"]
	var s: Vector2 = building["size"]
	# Missing eaves and plaster fissures distinguish these from village buildings.
	_poly([p + Vector2(s.x - 49, -21), p + Vector2(s.x - 23, -7), p + Vector2(s.x - 12, 30), p + Vector2(s.x - 68, 26), p + Vector2(s.x - 46, 12)], Color("3f5e53"))
	for offset in [Vector2(20, 43), Vector2(s.x - 38, 62)]:
		draw_polyline(PackedVector2Array([p + offset, p + offset + Vector2(5, 9), p + offset + Vector2(-2, 17), p + offset + Vector2(7, 28)]), Color("83937a"), 1.3, true)
	_draw_reeds(p + Vector2(4, s.y + 8), 4)
	_draw_reeds(p + Vector2(s.x - 7, s.y + 6), 5)
	for i in range(4):
		_draw_stone(p + Vector2(s.x + 9 + i * 9, s.y + sin(i * 2.7) * 9), 7)

func _draw_reeds(p: Vector2, count: int) -> void:
	for i in range(count):
		var base := p + Vector2((i - count * 0.5) * 5, sin(i * 2.1) * 4)
		var height := 22 + fmod(i * 11.0, 21)
		var tip := base + Vector2(sin(time_passed * 0.8 + i) * 2 + 3, -height)
		draw_line(base, tip, Color("6d815b"), 1.5, true)
		draw_line(tip - Vector2(0, 5), tip + Vector2(0, 4), Color("b6ad7d"), 3, true)
		draw_line(base - Vector2(0, 6), base + Vector2(-9, -height * 0.5), Color("789067"), 1.4, true)

func _draw_ruined_wall(p: Vector2, width: float) -> void:
	for i in range(int(width / 22)):
		var height := 15.0 if i % 4 != 2 else 7.0
		var base := p + Vector2(i * 22, sin(i * 1.8) * 3)
		draw_rect(Rect2(base - Vector2(0, height), Vector2(20, height)), Color("6f8571"))
		draw_line(base - Vector2(0, height), base + Vector2(20, -height), Color("a3ac91"), 2)

func _draw_sluice_cache(p: Vector2) -> void:
	_ellipse(p + Vector2(2, 1), Vector2(24, 8), Color(0.2, 0.31, 0.23, 0.22))
	draw_rect(Rect2(p + Vector2(-21, -23), Vector2(42, 25)), Color("796f4d"))
	_poly([p + Vector2(-21, -23), p + Vector2(-15, -32), p + Vector2(15, -32), p + Vector2(21, -23)], Color("9d9267"))
	for xx in [-12, 11]:
		draw_rect(Rect2(p + Vector2(xx, -30), Vector2(4, 31)), Color("b3a575"))
	draw_rect(Rect2(p + Vector2(-3, -19), Vector2(6, 8)), C_GOLD)

func _draw_sluice_boat(p: Vector2) -> void:
	_poly([p + Vector2(-49, -2), p + Vector2(-31, -20), p + Vector2(38, -18), p + Vector2(60, -4), p + Vector2(22, 14), p + Vector2(-27, 12)], Color("536956"))
	_poly([p + Vector2(-37, -3), p + Vector2(-27, -13), p + Vector2(33, -12), p + Vector2(47, -4), p + Vector2(17, 7), p + Vector2(-24, 6)], Color("a39a70"))
	for x in [-21, 3, 23]:
		draw_line(p + Vector2(x, -11), p + Vector2(x + 4, 7), Color("738263"), 4)
	draw_line(p + Vector2(-45, -2), p + Vector2(-75, -26), Color("c5ba89"), 1.4)
	_draw_reeds(p + Vector2(-51, 17), 7)

func _draw_region_sign(p: Vector2, title: String, direction: int) -> void:
	draw_line(p, p - Vector2(0, 58), Color("5c7055"), 5, true)
	var board := p - Vector2(0, 45)
	_poly([board + Vector2(-53, -13), board + Vector2(43, -13), board + Vector2(56, 0), board + Vector2(43, 13), board + Vector2(-53, 13)], Color("425f50"))
	_label(board + Vector2(-45, 5), title, 14, C_PAPER, 86, HORIZONTAL_ALIGNMENT_CENTER)
	var arrow := p + Vector2(0, -14)
	_poly([arrow + Vector2(-16 * direction, -6), arrow + Vector2(7 * direction, -6), arrow + Vector2(15 * direction, 0), arrow + Vector2(7 * direction, 6), arrow + Vector2(-16 * direction, 6)], Color("a5a272"))

func _round_box(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	return box

func _label(p: Vector2, text: String, size: int, color: Color, width: float = -1, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, shadow: bool = false) -> void:
	var font: Font = ui_font if ui_font != null else ThemeDB.fallback_font
	if shadow:
		draw_string(font, p + Vector2(0, 1), text, alignment, width, size, Color(0.87, 0.85, 0.68, 0.8))
	draw_string(font, p, text, alignment, width, size, color)

func _poly(points: Array[Vector2], color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)

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
