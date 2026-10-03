class_name JournalGuidanceView
extends RefCounted
## Main owns both this transient projection cache and the separate session.
## Call after synchronizing World facts/points/party; reset after every successful
## applied new/loaded journey, including same-object loads. Storage-only transfers
## do not reset this cache/session. Nothing here writes HeroState.
const Objectives = preload("res://scripts/journal_objective_rules.gd")
const Guidance = preload("res://scripts/journal_guidance_rules.gd")
const Capstone = preload("res://scripts/volume_one_capstone_rules.gd")
const Lightness = preload("res://scripts/lightness_rules.gd")
const Region = preload("res://scripts/heting_region.gd")
const EXTRA_FACTS: Array[String] = ["sect", "sect_rank", "sect_trial_won", "level", "lightness_unlocked", "lightness_relics", "resources", "battle_active"]

var _guidance: Dictionary = {}
# Presentation changes in an untracked row still need a fresh J catalog view.
# This scalar advances only when relevant facts change, never on ordinary motion.
var _facts_revision: int = 0
var _preview: Dictionary = {}
var _catalog_facts: Dictionary = {}
var _catalog_rows: Array[Dictionary] = []
var _catalog_ready: bool = false
var _marker_key: Dictionary = {}
var _marker_view: Dictionary = {}
var _metrics: Dictionary = {"catalog_builds":0, "full_resolves":0, "route_reanchors":0, "preview_resolves":0, "preview_reanchors":0, "marker_view_builds":0}
## Counters are cumulative for this cache object's lifetime, including reset().
## full_resolves counts actual session.refresh calls; previews have their own count.
var metrics: Dictionary:
	get: return _metrics.duplicate(true)

func reset() -> void:
	_guidance.clear()
	_preview.clear()
	_catalog_facts.clear()
	_catalog_rows.clear()
	_catalog_ready = false
	_marker_key.clear()
	_marker_view.clear()

func catalog(state) -> Array[Dictionary]:
	var facts: Dictionary = _facts(state)
	if not _catalog_ready or facts != _catalog_facts:
		_catalog_rows = Objectives.catalog(state)
		_catalog_facts = _detach(facts)
		_catalog_ready = true
		_metrics.catalog_builds += 1
	var result: Array[Dictionary] = []
	for row: Dictionary in _catalog_rows:
		result.append(_detach(row))
	return result

func refresh(state, world, session, force: bool = false, exact_route: bool = false) -> Dictionary:
	var facts: Dictionary = _facts(state)
	if _guidance.is_empty() or _guidance.facts != facts:_facts_revision += 1
	var context: Dictionary = _context(world)
	var physical: Dictionary = _physical(state, world, context)
	physical.session_id = session.get_instance_id()
	var markers: Dictionary = _marker_signatures(context)
	_sync_marker_view(physical, context, markers)
	var arc: String = String(session.tracked_arc_id)
	var rebuild: bool = force or _changed(_guidance, facts, physical, arc, context, markers)
	if not rebuild and _moved_loaded_start(_guidance, physical, context):
		# An explicit M boundary may reuse a route already exact at this start.
		# Otherwise it asks the existing session/resolver, never another solver.
		if exact_route or not _reanchor_cache(_guidance, state, context):
			rebuild = true
		else:
			_metrics.route_reanchors += 1
	if rebuild:
		var resolved: Dictionary = session.refresh(state, context)
		_metrics.full_resolves += 1
		_commit(_guidance, facts, physical, String(session.tracked_arc_id), context, markers, resolved)
	var result: Dictionary = _published(_guidance, physical)
	# Notices are events, not persistent presentation. Every consumer of this one
	# returned publication sees the same notice; the next call cannot repeat it.
	_guidance.result.selection_changed = false
	_guidance.result.selection_notice = ""
	return result

func preview(state, world, arc_id: String) -> Dictionary:
	var facts: Dictionary = _facts(state)
	var context: Dictionary = _context(world)
	var physical: Dictionary = _physical(state, world, context)
	var markers: Dictionary = _marker_signatures(context)
	_sync_marker_view(physical, context, markers)
	var rebuild: bool = _changed(_preview, facts, physical, arc_id, context, markers)
	if not rebuild and _moved_loaded_start(_preview, physical, context):
		if not _reanchor_cache(_preview, state, context):
			rebuild = true
		else:
			_metrics.preview_reanchors += 1
	if rebuild:
		# Browsing never calls the session or changes its selected arc/epoch.
		var resolved: Dictionary = Guidance.resolve(state, arc_id, context)
		_metrics.preview_resolves += 1
		_commit(_preview, facts, physical, arc_id, context, markers, resolved)
	return _published(_preview, physical)

func _facts(state) -> Dictionary:
	var result: Dictionary = {"state_id":_identity(state)}
	if not is_instance_valid(state): return result
	# Fresh references are compared to a detached committed key, so in-place
	# changes to resources, observations and party arrays cannot hide a change.
	for field: String in Capstone.FIELDS:
		result[field] = state.get(field)
	for field: String in Capstone.CONTEXT:
		result[field] = state.get(field)
	for field: String in EXTRA_FACTS:
		result[field] = state.get(field)
	return result

func _context(world) -> Dictionary:
	if not is_instance_valid(world):
		return {"map_id":"", "player_position":null, "markers":null, "marker_names":{}}
	var markers: Variant = world.interactables
	var names: Dictionary = {}
	if markers is Dictionary:
		for id: Variant in markers:
			if id is String and markers[id] is Dictionary:
				names[id] = world.get_npc_name(id)
	return {"map_id":String(world.map_id), "player_position":world.player_pos, "markers":markers, "marker_names":names}

func _physical(state, world, context: Dictionary) -> Dictionary:
	var state_map: String = String(state.map_id) if is_instance_valid(state) else ""
	var map: String = String(context.map_id)
	var point: Variant = context.player_position
	var point_class: String = _point_class(point)
	var bounded: bool = point_class == "bounded"
	var loaded: bool = is_instance_valid(state) and map == "heting" and (not state.heting_cargo.is_empty() or state.consignee_cargo_location == "cart")
	var walkable: bool = loaded and bounded and state.heting_bridge in ["west", "east"] and Region.walkable(point, state.heting_bridge, true)
	var battle: bool = bool(state.battle_active) if is_instance_valid(state) else false
	return {"state_id":_identity(state), "world_id":_identity(world), "state_map":state_map, "world_map":map,
		"point_class":point_class, "islet":bounded and map == "qingwei" and Lightness.on_islet(point),
		"markers_valid":context.markers is Dictionary, "loaded":loaded, "walkable":walkable, "battle":battle,
		"can_reanchor":loaded and walkable and not battle and state_map == map}

func _marker_signatures(context: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var markers: Variant = context.markers
	if not markers is Dictionary: return result
	for id: Variant in markers:
		var marker: Variant = markers[id]
		if not marker is Dictionary:
			result[id] = {"type":typeof(marker)}
			continue
		var point: Variant = marker.get("pos")
		var point_class: String = _point_class(point)
		result[id] = {"type":TYPE_DICTIONARY, "point_class":point_class,
			"pos":point if point_class == "bounded" else null,
			"name":context.marker_names.get(id, marker.get("name", "当前去处")), "kind":marker.get("kind", "")}
	return result

func _sync_marker_view(physical: Dictionary, context: Dictionary, markers: Dictionary) -> void:
	var key: Dictionary = {"world_id":physical.world_id, "map_id":context.map_id, "markers_valid":physical.markers_valid, "markers":markers}
	if not _marker_view.is_empty() and key == _marker_key: return
	_marker_key = _detach(key)
	_marker_view = {"map_id":context.map_id, "markers":_detach(context.markers) if context.markers is Dictionary else {}, "marker_names":_detach(context.marker_names)}
	_metrics.marker_view_builds += 1

func _changed(cache: Dictionary, facts: Dictionary, physical: Dictionary, arc: String, context: Dictionary, markers: Dictionary) -> bool:
	if cache.is_empty() or cache.facts != facts or cache.physical != physical or cache.arc != arc: return true
	return cache.dependencies != _dependencies(cache.result, context, markers)

func _dependencies(result: Dictionary, context: Dictionary, markers: Dictionary) -> Dictionary:
	var ids: Array[String] = []
	var target: String = String(result.get("next_target_id", ""))
	if not target.is_empty():
		ids.append(target)
	else:
		# An unavailable model result deliberately clears next_target_id. Watch
		# its possible physical dependencies only to retry that same model when a
		# point materializes. This list never selects or fabricates a target.
		ids.append(String(result.get("destination_site", "")))
		ids.append(String(Guidance.FORWARD.get(context.map_id, "")))
		ids.append(String(Guidance.BACKWARD.get(context.map_id, "")))
		if context.map_id == "qingwei":
			ids.append("reed_cross")
			ids.append("reed_return")
	var watched: Dictionary = {}
	for id: String in ids:
		if not id.is_empty(): watched[id] = markers.get(id, {"missing":true})
	return watched

func _commit(cache: Dictionary, facts: Dictionary, physical: Dictionary, arc: String, context: Dictionary, markers: Dictionary, resolved: Dictionary) -> void:
	cache.facts = _detach(facts)
	cache.physical = _detach(physical)
	cache.arc = arc
	cache.result = _detach(resolved)
	cache.dependencies = _detach(_dependencies(resolved, context, markers))
	cache.start = context.player_position

func _moved_loaded_start(cache: Dictionary, physical: Dictionary, context: Dictionary) -> bool:
	# Invalid/battle/mismatched classifications retain safe unavailable results
	# until classification/facts change, rather than resolving every bad frame.
	return bool(physical.can_reanchor) and cache.start != context.player_position

func _reanchor_cache(cache: Dictionary, state, context: Dictionary) -> bool:
	var route: Variant = cache.result.get("cart_route")
	if not route is PackedVector2Array or route.is_empty(): return false
	var start: Vector2 = context.player_position
	var target: Variant = cache.result.get("next_target_position")
	if not target is Vector2 or route[route.size() - 1] != target: return false
	# Furthest legal suffix first. Every inserted edge is checked by the same
	# loaded-cart collision predicate as movement. Existing suffixes came from
	# the full resolver under exactly the same bridge/load/target signatures.
	for index: int in range(route.size() - 1, -1, -1):
		if not Region.can_step(start, route[index], state.heting_bridge, true): continue
		var anchored: PackedVector2Array = PackedVector2Array([start])
		for suffix: int in range(index, route.size()):
			if anchored[anchored.size() - 1] != route[suffix]: anchored.append(route[suffix])
		cache.result.cart_route = anchored
		cache.start = start
		return true
	return false

func _published(cache: Dictionary, physical: Dictionary) -> Dictionary:
	var result: Dictionary = _detach(cache.result)
	result.source_facts_revision = _facts_revision
	result.source_state_id = physical.state_id
	result.source_world_id = physical.world_id
	result.source_map_id = physical.state_map
	result.context_map_id = physical.world_map
	result.marker_view = _detach(_marker_view)
	return result

func _point_class(point: Variant) -> String:
	if not point is Vector2: return "not_vector"
	if not point.is_finite(): return "non_finite"
	if not Guidance._bounded(point): return "out_of_bounds"
	return "bounded"

func _identity(value) -> int:
	return value.get_instance_id() if is_instance_valid(value) else 0

func _detach(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[key] = _detach(value[key])
		return result
	if value is Array:
		var result: Array = value.duplicate()
		for index: int in range(result.size()): result[index] = _detach(result[index])
		return result
	if typeof(value) in [TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY,
			TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY,
			TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY]:
		return value.duplicate()
	return value
