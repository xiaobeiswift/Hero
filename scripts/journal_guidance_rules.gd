class_name JournalGuidanceRules
extends RefCounted
## Pure projection. Required context is the synchronized physical map, actual
## world position and current-map markers, never the saved position alone.
const Objectives = preload("res://scripts/journal_objective_rules.gd")
const Lightness = preload("res://scripts/lightness_rules.gd")
const CartRoutes = preload("res://scripts/heting_cart_routes.gd")
const MAPS: Array[String] = ["qingwei", "sluice", "frostbridge", "mistwood", "heting"]
const FORWARD: Dictionary = {"qingwei":"exit_sluice", "sluice":"exit_frostbridge", "frostbridge":"exit_mistwood", "mistwood":"exit_heting"}
const BACKWARD: Dictionary = {"sluice":"return_village", "frostbridge":"return_sluice", "mistwood":"return_frostbridge", "heting":"return_mistwood"}

static func resolve(s, tracked_arc_id: String, context: Dictionary) -> Dictionary:
	var result: Dictionary = _empty()
	if s == null: return result
	var selected: Dictionary = Objectives.row(s, tracked_arc_id)
	var chosen: Dictionary = {}
	if not tracked_arc_id.is_empty():
		if not selected.is_empty() and selected.trackable:
			chosen = selected; result.mode = "manual"; result.valid_tracked_arc_id = tracked_arc_id
		else: result.reset_reason = "completed" if not selected.is_empty() and selected.status == "completed" else "invalid"
	if chosen.is_empty(): chosen = Objectives.automatic(s)
	if chosen.is_empty(): return result
	result.kind = chosen.kind; result.arc_id = chosen.id
	result.source_arc_id = chosen.get("source_arc_id", chosen.id)
	result.arc_title = chosen.display_title; result.step_key = chosen.step_key
	result.next_action = chosen.next_action; result.destination_map = chosen.destination_map
	result.destination_site = _physical(String(chosen.destination_site))
	result.destination_receiver = chosen.destination_site
	result.status = chosen.status
	var map: String = String(context.get("map_id", ""))
	var position: Variant = context.get("player_position")
	var markers: Variant = context.get("markers")
	if map != s.map_id or not MAPS.has(map): return _unavailable(result, "当前场景尚未同步，暂不标出行路位置。")
	if not position is Vector2 or not _bounded(position) or not markers is Dictionary: return _unavailable(result, "当前位置尚未核定，暂不标出行路位置。")
	if s.battle_active: return _unavailable(result, "交锋结束后继续此事；当前追踪保留。")
	var destination: String = String(result.destination_map)
	var target: String = String(result.destination_site)
	if not MAPS.has(destination) or target.is_empty(): return _unavailable(result, "可自由行路，暂无可标出的下一处。")
	if map == "qingwei" and Lightness.on_islet(position) and not (destination == "qingwei" and target == "reed_relic"):
		target = "reed_return"; result.route_status = "via_crossing"; result.route_note = "先由小洲返回岸边；回程不需已学轻功。"
	elif map == "qingwei" and destination == "qingwei" and target == "reed_relic" and not Lightness.on_islet(position):
		if not s.lightness_unlocked: return _unavailable(result, "当前尚不能通过这处行路连接。")
		target = "reed_cross"; result.route_status = "via_crossing"; result.route_note = "先到东南浮石，亲自踏苇渡往小洲。"
	elif map != destination:
		var here: int = MAPS.find(map)
		var there: int = MAPS.find(destination)
		if here < there:
			# Check the complete earned corridor, not merely a numeric direction.
			for edge: int in range(here, there):
				if not _forward_open(s, MAPS[edge]): return _unavailable(result, "这条行路尚未具备通行条件。")
			target = String(FORWARD.get(map, ""))
		else: target = String(BACKWARD.get(map, ""))
		result.route_status = "via_exit"; result.is_exit = true
		result.route_note = "先沿当前古道前往" + String(Objectives.MAP_NAMES.get(MAPS[here + (1 if here < there else -1)], "下一处")) + "。"
	else:
		result.route_status = "local"
		result.route_note = ""
		# Completed onward guidance keeps a local legacy exit, but still gates it.
		if target in FORWARD.values():
			if target != String(FORWARD.get(map, "")) or not _forward_open(s, map): return _unavailable(result, "这条行路尚未具备通行条件。")
			result.is_exit = true
		elif target in BACKWARD.values():
			if target != String(BACKWARD.get(map, "")): return _unavailable(result, "当前场景没有这条行路。")
			result.is_exit = true
	if not markers.has(target) or not markers[target] is Dictionary: return _unavailable(result, "当前场景未找到相应去处；追踪保留。")
	var marker: Dictionary = markers[target]
	var target_position: Variant = marker.get("pos")
	if not target_position is Vector2 or not _bounded(target_position): return _unavailable(result, "相应去处的位置尚未核定；追踪保留。")
	var loaded: bool = map == "heting" and (not s.heting_cargo.is_empty() or s.consignee_cargo_location == "cart")
	if loaded:
		var route: PackedVector2Array = CartRoutes.route(position, target_position, s.heting_bridge)
		if route.is_empty(): return _unavailable(result, "押车路线暂未核定；不可由只通行人的窄步栈过车。")
		result.cart_route = route.duplicate()
		result.route_note = "押车按现有浮栈与北岸通路行进；窄步栈只通行人。"
		if target == "return_mistwood":
			result.route_status = "departure_confirmation"
			result.route_note += "离港须在出口明确确认把车停回" + ("北仓。" if s.consignee_cargo_location == "cart" else "原提货处。")
	if map == "frostbridge" and not s.bridge_repaired and result.route_status == "local":
		result.route_note = "北桥通行，南桥待修；方位标记不表示南桥已通。"
	result.next_target_id = target; result.next_target_map = map
	result.next_target_position = target_position
	var names: Variant = context.get("marker_names", {})
	result.next_target_name = String(names.get(target, marker.get("name", "当前去处"))) if names is Dictionary else String(marker.get("name", "当前去处"))
	if chosen.status == "available" and chosen.id in ["frostbridge", "mistwood", "heting_delivery"] and map == destination and target == result.destination_site:
		result.next_target_name = "初到问路"
	return result.duplicate(true)

static func _physical(id: String) -> String: return "heting_cargo" if id == "heting_grain_boat" else id
static func _bounded(point: Vector2) -> bool: return point.is_finite() and point.x >= 0.0 and point.x <= 1600.0 and point.y >= 0.0 and point.y <= 1050.0
static func _forward_open(s, map: String) -> bool:
	match map:
		"qingwei": return s.quest_stage >= 6
		"sluice": return s.side_stage >= 3
		"frostbridge": return s.chapter_two_stage >= 4
		"mistwood": return s.mist_stage == 4 and s.mist_ending in ["release_water", "warn_ferries"]
	return false
static func _unavailable(result: Dictionary, note: String) -> Dictionary:
	result.route_status = "unavailable"; result.route_note = note
	result.next_target_id = ""; result.next_target_name = ""; result.next_target_map = ""; result.is_exit = false
	result.cart_route = PackedVector2Array()
	return result.duplicate(true)
static func _empty() -> Dictionary:
	return {"mode":"auto", "kind":"exploration", "arc_id":"", "source_arc_id":"", "arc_title":"自由行路", "step_key":"", "next_action":"", "destination_map":"", "destination_site":"", "destination_receiver":"", "next_target_id":"", "next_target_name":"", "next_target_map":"", "next_target_position":Vector2.ZERO, "route_status":"unavailable", "route_note":"暂无可标出的下一处。", "is_exit":false, "cart_route":PackedVector2Array(), "valid_tracked_arc_id":"", "reset_reason":"", "status":""}
