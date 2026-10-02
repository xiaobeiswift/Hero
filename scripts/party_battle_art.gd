class_name PartyBattleArt
extends Control
## Paint-only playback of detached accepted PartyCombatRules facts. No state,
## catalog, or rules object is retained; the host alone acknowledges the token.
## Each action is a distinct grounded windup/contact/return, including enemies.
signal event_presented(event: Dictionary)
signal presentation_finished
signal target_requested(unit_id: String)

const Hero = preload("res://scripts/painted_battle_hero.gd")
const Shen = preload("res://scripts/painted_battle_shen.gd")
const Tang = preload("res://scripts/painted_battle_tang.gd")
const Qin = preload("res://scripts/painted_battle_qin.gd")
const Rival = preload("res://scripts/painted_battle_puheng.gd")
const Backdrop = preload("res://scripts/ferry_battle_backdrop.gd")
const Lantern = preload("res://scripts/painted_lantern_post.gd")
const WOOD = preload("res://assets/generated/environment/qingwei_deck_wood.png")
const FONT = preload("res://assets/fonts/NotoSansSC.otf")
const IDS = ["hero", "shen", "tang", "qin", "puheng", "striker", "bracer", "sluice_scout", "sluice_boss"]
const CELL_SIZE = {"hero": 290.0, "shen": 235.0, "tang": 235.0, "qin": 230.0, "puheng": 300.0, "bracer": 300.0, "striker": 290.0}
const ENEMY_FEET = {"puheng": Vector2(865,580), "bracer": Vector2(865,580), "striker": Vector2(1045,460), "sluice_scout":Vector2(865,580), "sluice_boss":Vector2(865,580)}
const QIN_CHEST = {"idle":Vector2(245,210),"strike":Vector2(775,233),"protect":Vector2(1290,239),"hurt":Vector2(258,711),"down":Vector2(815,837),"recover":Vector2(1312,767)}
const ACTION_DURATION = .86
const ACTION_GAP = .06
const CONTACT_AT = .36
const PREPARE_AT = .10
const RETURN_AT = .76
const GOLD = Color("d4b477")
# Measured original atlas alpha > .08, in the 512px source cells.
const ALPHA_BOUNDS = {
	"hero": {"idle":Rect2(94,153,299,319),"windup":Rect2(54,152,288,320),"strike":Rect2(62,213,437,259),"guard":Rect2(76,135,274,337),"hurt":Rect2(25,167,312,304),"kneel":Rect2(75,230,312,244)},
	"rival": {"idle":Rect2(146,174,312,298),"windup":Rect2(113,153,324,319),"strike":Rect2(21,226,439,246),"guard":Rect2(137,152,319,319),"hurt":Rect2(154,156,271,320),"kneel":Rect2(179,216,305,258)},
	"shen": {"idle":Rect2(74,68,269,403),"assist":Rect2(58,79,402,391),"cover":Rect2(57,83,317,388),"heal":Rect2(52,73,295,397)},
	"tang": {"idle":Rect2(110,61,227,410),"assist":Rect2(57,91,390,380),"cover":Rect2(68,72,311,399),"recover":Rect2(97,52,248,419)},
}
const CHEST = {
	"hero": {"idle":Vector2(238,283),"windup":Vector2(237,282),"strike":Vector2(292,290),"guard":Vector2(245,288),"hurt":Vector2(238,290),"kneel":Vector2(251,355)},
	"rival": {"idle":Vector2(288,294),"windup":Vector2(287,287),"strike":Vector2(326,312),"guard":Vector2(278,305),"hurt":Vector2(282,287),"kneel":Vector2(314,369)},
	"shen": {"idle":Vector2(230,255),"assist":Vector2(238,255),"cover":Vector2(232,256),"heal":Vector2(228,255)},
	"tang": {"idle":Vector2(230,255),"assist":Vector2(232,260),"cover":Vector2(225,255),"recover":Vector2(230,250)},
}
# Weapon/needle tips measured in the original contact cells.
const WEAPON = {"hero": Vector2(495,286), "tang": Vector2(440,316), "shen": Vector2(454,158), "rival": Vector2(22,272)}
var display_snapshot: Dictionary:
	get: return _readonly(_display)
	set(_value): pass
var acting_unit_id: String:
	get: return String(_current_segment().get("source_id", ""))
	set(_value): pass
var presentation_phase: String:
	get:
		if not _presenting: return "idle"
		var segment: Dictionary = _current_segment()
		if segment.is_empty(): return "settle"
		var t: float = action_time - float(segment.start)
		if t < CONTACT_AT: return "windup"
		if t < .46: return "contact"
		if t < RETURN_AT: return "return"
		return "settle"
	set(_value): pass
var selected_id: String:
	get:
		# Action focus follows each accepted segment, including enemy replies.
		# It never rewrites the player's selection in the detached snapshot.
		if _presenting: return String(_current_segment().get("target_id", ""))
		return String(_display.get("selected_target_id", ""))
	set(_value): pass
var formation: String:
	get: return String(_display.get("formation", "护后"))
	set(_value): pass
var action_time: float = 0.0
var _display: Dictionary = {}
var _after: Dictionary = {}
var _segments: Array[Dictionary] = []
var _schedule: Array[Dictionary] = []
var _floats: Array[Dictionary] = []
var _presenting: bool = false
var _duration: float = 0.0
var _cursor: int = 0
var _epoch: int = 0
var _clock: float = 0.0
var _floor: ArrayMesh

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_floor = _make_floor()
	for atlas in [Hero, Shen, Tang, Rival]:
		for pose: String in atlas.POSES: atlas.texture_for(pose)
	for pose: String in Qin.SOURCE_RECTS: Qin.texture_for(pose)
	Backdrop.texture()

func set_snapshot(snapshot: Dictionary) -> void:
	if _presenting or not _valid_snapshot(snapshot): return
	_display = snapshot.duplicate(true)
	_floats.clear()
	queue_redraw()

func present(transaction: Dictionary) -> bool:
	if _presenting or not _valid_transaction(transaction): return false
	_epoch += 1
	_display = transaction.before.duplicate(true)
	_after = transaction.after.duplicate(true)
	_display.locked = true
	_segments.clear(); _schedule.clear(); _floats.clear()
	_cursor = 0; action_time = 0.0
	_build_schedule(transaction.events)
	_presenting = true
	queue_redraw()
	return true

func reset_presentation() -> void:
	var release: bool = _presenting
	_epoch += 1
	_presenting = false
	# Cancellation removes poses/floating facts. The controller supplies the next
	# snapshot; cancellation must not reveal an unplayed resolved after state.
	_after.clear(); _segments.clear(); _schedule.clear(); _floats.clear()
	_duration = 0.0; action_time = 0.0; _cursor = 0
	queue_redraw()
	if release: presentation_finished.emit()

func is_presenting() -> bool: return _presenting
func get_presentation_duration() -> float: return _duration

func _valid_snapshot(snapshot: Dictionary) -> bool:
	if not _plain(snapshot) or not snapshot.get("actors") is Array or not snapshot.get("enemies") is Array: return false
	var seen: Array = []
	for unit: Variant in snapshot.actors + snapshot.enemies:
		if not unit is Dictionary or not IDS.has(unit.get("id")) or seen.has(unit.id): return false
		if not unit.get("hp") is int or int(unit.hp) < 0: return false
		seen.append(unit.id)
	return seen.has("hero")

func _valid_transaction(tx: Dictionary) -> bool:
	if not _plain(tx) or not bool(tx.get("accepted", false)) or not bool(tx.get("ok", false)): return false
	if not tx.get("before") is Dictionary or not tx.get("after") is Dictionary or not tx.get("events") is Array: return false
	if not _valid_snapshot(tx.before) or not _valid_snapshot(tx.after) or tx.events.is_empty(): return false
	if not tx.events[0] is Dictionary or tx.events[0].get("type", "") != "action": return false
	for event: Variant in tx.events:
		if not event is Dictionary or not event.get("type") is String or not event.get("amount") is int: return false
		if not event.get("source_id") is String or not event.get("target_id") is String: return false
		if event.type == "action" and (_unit(tx.before, event.source_id).is_empty() or int(_unit(tx.before, event.source_id).hp) <= 0): return false
		if event.type not in ["action","damage","heal","qi","guard","medicine","weaken","focus","proficiency","down","outcome","round_start","protect","barrier_grant","barrier_absorb","barrier_expire","vulnerability_apply","vulnerability_consume","vulnerability_expire"]: return false
	return true

func _plain(value: Variant) -> bool:
	if value is Object or value is Callable or value is Signal: return false
	if value is Dictionary:
		for key: Variant in value:
			if not _plain(key) or not _plain(value[key]): return false
	elif value is Array:
		for entry: Variant in value:
			if not _plain(entry): return false
	return true

func _build_schedule(events: Array) -> void:
	var current: Dictionary = {}
	var previous_at: float = 0.0
	for event: Dictionary in events:
		if event.type == "action":
			var start: float = 0.0 if _segments.is_empty() else float(_segments.back().start) + ACTION_DURATION + ACTION_GAP
			current = {"start":start,"source_id":event.source_id,"target_id":event.target_id,"action_id":event.get("action_id","attack"),"events":[]}
			_segments.append(current)
		current.events.append(event.duplicate(true))
		var offset: float = CONTACT_AT
		match event.type:
			"action": offset = .02
			"qi": offset = PREPARE_AT if int(event.amount) < 0 else CONTACT_AT + .04
			"medicine": offset = PREPARE_AT
			"proficiency", "focus": offset = CONTACT_AT + .08
			"protect": offset = RETURN_AT + .02
			"round_start": offset = ACTION_DURATION
			"outcome": offset = CONTACT_AT + .12
			"barrier_expire":
				if event.get("reason", "") == "round_end": offset = ACTION_DURATION - .02
		var at: float = maxf(previous_at, float(current.start) + offset)
		_schedule.append({"at":at,"event":event.duplicate(true)})
		previous_at = at
	_duration = maxf(previous_at + .12, float(_segments.back().start) + ACTION_DURATION + .10)

func _process(delta: float) -> void:
	if not is_finite(delta) or delta <= 0: return
	_clock += delta
	if not _presenting:
		queue_redraw(); return
	var epoch: int = _epoch
	var destination: float = minf(action_time + delta, _duration)
	while _cursor < _schedule.size() and float(_schedule[_cursor].at) <= destination:
		var beat: Dictionary = _schedule[_cursor]
		_cursor += 1
		action_time = float(beat.at)
		_apply_event(beat.event)
		event_presented.emit(_readonly(beat.event))
		# Signal callbacks may cancel, replace, or free the host's current fight.
		if epoch != _epoch or not _presenting: return
	action_time = destination
	if action_time >= _duration:
		_display = _after.duplicate(true)
		_presenting = false
		_floats.clear()
		queue_redraw()
		presentation_finished.emit()
		return
	queue_redraw()

func _apply_event(event: Dictionary) -> void:
	var source: Dictionary = _unit(_display, event.source_id)
	var target: Dictionary = _unit(_display, event.target_id)
	var amount: int = int(event.amount)
	_display.phase = event.get("phase", _display.get("phase", "ally"))
	_display.round = event.get("round", _display.get("round", 1))
	match event.type:
		"action":
			if source.get("team", "") == "ally":
				source.acted = true
				_display.active_actor_id = source.id
				var action_id: String = event.get("action_id", "attack")
				for key: String in source.get("cooldowns", {}):
					if key != action_id: source.cooldowns[key] = maxi(0, int(source.cooldowns[key]) - 1)
				for action: Dictionary in source.get("actions", []):
					if action.id == action_id and action.category == "martial": source.cooldowns[action_id] = int(action.cooldown)
		"damage":
			if not target.is_empty(): target.hp = maxi(0, int(target.hp) - amount)
			if source.get("team", "") == "enemy" and int(source.get("status", {}).get("weaken_strikes", 0)) > 0:
				source.status.weaken_strikes -= 1
				if source.status.weaken_strikes == 0: source.status.weaken_amount = 0
			if _current_segment().get("action_id", "") == "attack" and source.get("team", "") == "ally": source.status.focused_damage = 0
		"heal":
			if not target.is_empty(): target.hp = mini(int(target.max_hp), int(target.hp) + amount)
		"qi":
			if not target.is_empty(): target.qi = clampi(int(target.qi) + amount, 0, int(target.max_qi))
		"medicine": _display.medicine = int(_display.get("medicine", 0)) + amount
		"guard":
			if not target.is_empty(): target.status.guard = amount > 0
		"barrier_grant", "barrier_absorb", "barrier_expire":
			if not target.is_empty(): target.status.barrier = int(event.get("remaining",0))
		"vulnerability_apply", "vulnerability_consume", "vulnerability_expire":
			if not target.is_empty(): target.status.vulnerability_hits = int(event.get("remaining",0))
		"weaken":
			if not target.is_empty():
				target.status.weaken_amount = amount
				target.status.weaken_strikes = int(event.get("strikes", 0))
		"focus":
			if not target.is_empty(): target.status.focused_damage = amount
		"proficiency":
			if not target.is_empty():
				var art: String = event.get("art_id", "")
				target.art_uses[art] = int(target.art_uses.get(art, 0)) + amount
				target.art_rank = int(event.get("rank", target.get("art_rank", 1)))
		"down":
			if not target.is_empty(): target.hp = 0
		"outcome":
			_display.outcome = event.get("outcome", "")
			_display.active = false
		"round_start":
			_display.round = amount
			for actor: Dictionary in _display.actors:
				actor.acted = false
				actor.status.guard = false
	# Only actual nonzero amounts produce floating values (including capped XP).
	if amount != 0 and event.type in ["damage","heal","qi","proficiency","medicine","barrier_grant","barrier_absorb","barrier_expire"]:
		_floats.append({"at":action_time,"event":event.duplicate(true),"anchor":target_anchor(event.target_id)})

func _current_segment() -> Dictionary:
	if not _presenting: return {}
	for segment: Dictionary in _segments:
		if action_time >= float(segment.start) and action_time < float(segment.start) + ACTION_DURATION: return segment
	return {}

func _has_event(segment: Dictionary, kind: String) -> bool:
	for event: Dictionary in segment.get("events", []):
		if event.type == kind: return true
	return false

func _is_melee(segment: Dictionary) -> bool:
	return not segment.is_empty() and segment.source_id != "shen" and _has_event(segment, "damage")

func _unit(snapshot: Dictionary, id: String) -> Dictionary:
	for unit: Dictionary in snapshot.get("actors", []) + snapshot.get("enemies", []):
		if unit.id == id: return unit
	return {}

func actor_home(id: String) -> Vector2:
	if ENEMY_FEET.has(id): return ENEMY_FEET[id]
	if _display.get("actors", []).size() == 4:
		var homes: Dictionary = {"hero":Vector2(440,585),"shen":Vector2(160,470),"tang":Vector2(325,350),"qin":Vector2(550,390)} if formation == "护后" else {"hero":Vector2(430,590),"shen":Vector2(180,480),"tang":Vector2(355,345),"qin":Vector2(580,435)}
		return homes.get(id,Vector2.ZERO)
	if id == "hero": return Vector2(440,585) if formation == "护后" else Vector2(420,585)
	if _display.get("actors", []).size() == 2: return Vector2(255,450)
	var companions: Array[String] = []
	for actor: Dictionary in _display.get("actors",[]):
		if actor.id != "hero": companions.append(actor.id)
	if companions.find(id) == 0: return Vector2(200,470) if formation == "护后" else Vector2(255,455)
	if companions.find(id) == 1: return Vector2(345,350) if formation == "护后" else Vector2(475,350)
	return Vector2.ZERO

func actor_foot(id: String) -> Vector2:
	var home: Vector2 = actor_home(id)
	var segment: Dictionary = _current_segment()
	if segment.is_empty(): return home
	var t: float = action_time - float(segment.start)
	if segment.source_id == id and _is_melee(segment):
		var travel: float = _ease(.14, CONTACT_AT, t) * (1.0 - _ease(.46, RETURN_AT, t))
		var contact: Vector2 = target_anchor(segment.target_id) - _weapon_offset(id)
		var pullback: float = 14.0 * _pulse(.025,.105,.18,t) * (-1.0 if _is_ally(id) else 1.0)
		return home.lerp(contact, travel) + Vector2(pullback,0)
	# A grounded recoil begins after contact, never changing the contact anchor.
	if segment.target_id == id and _has_event(segment, "damage") and t > CONTACT_AT:
		return home + Vector2((10.0 if not _is_ally(id) else -10.0) * _pulse(CONTACT_AT, .42, .59, t),0)
	return home

func actor_order() -> Array[String]:
	var ids: Array[String] = []
	for unit: Dictionary in _display.get("actors", []) + _display.get("enemies", []): ids.append(unit.id)
	ids.sort_custom(func(a: String, b: String) -> bool: return actor_foot(a).y < actor_foot(b).y)
	return ids

func actor_visual_pose(id: String) -> String:
	var unit: Dictionary = _unit(_display, id)
	if unit.is_empty(): return "idle"
	var segment: Dictionary = _current_segment()
	var t: float = action_time - float(segment.get("start", 0.0))
	if id == "qin": return _qin_pose(unit,segment,t)
	var hit: bool = not segment.is_empty() and segment.target_id == id and _has_event(segment, "damage") and t >= CONTACT_AT and t < .54
	if int(unit.hp) <= 0 and not hit: return "down" if id in ["shen","tang"] else "kneel"
	if hit: return "cover" if id in ["shen","tang"] else ("guard" if bool(unit.get("status", {}).get("guard", false)) or _has_event(segment,"barrier_absorb") else "hurt")
	if int(unit.hp) <= 0: return "down" if id in ["shen","tang"] else "kneel"
	if not segment.is_empty() and segment.source_id == id and t >= .02 and t < .63:
		if String(segment.action_id) == "guard": return "cover" if id in ["shen","tang"] else "guard"
		if _has_event(segment, "heal") and not _has_event(segment, "damage"):
			if id == "shen": return "heal"
			if id == "tang": return "recover"
			return "guard"
		if _has_event(segment, "damage"):
			if id in ["shen","tang"]: return "assist" if t >= .14 else "cover"
			return "windup" if t < .27 else "strike"
	if bool(unit.get("status", {}).get("guard", false)): return "cover" if id in ["shen","tang"] else "guard"
	# brace belongs to the protected recipient. Only this unit's protect intent
	# justifies a guarding pose while waiting; Pu Heng retains his original art.
	for intent: Dictionary in _display.get("enemy_intents", []):
		if intent.source_id == id and intent.type == "protect" and int(_unit(_display, intent.target_id).get("hp",0)) > 0: return "guard"
	return "idle"

func _qin_pose(unit: Dictionary, segment: Dictionary, t: float) -> String:
	var hit: bool = not segment.is_empty() and segment.target_id == "qin" and _has_event(segment,"damage") and t >= CONTACT_AT and t < .54
	if hit: return "protect" if bool(unit.get("status",{}).get("guard",false)) or _has_event(segment,"barrier_absorb") else "hurt"
	if int(unit.hp) <= 0: return "down"
	if not segment.is_empty() and segment.source_id == "qin" and t >= .02 and t < .63:
		if segment.action_id == "guard" or _has_event(segment,"barrier_grant"): return "protect"
		if _has_event(segment,"damage"): return "recover" if t < .27 else "strike"
		return "recover"
	return "protect" if bool(unit.get("status",{}).get("guard",false)) else "idle"

func _weapon_offset(id: String) -> Vector2:
	if id == "qin": return Qin.weapon_point(Vector2.ZERO,CELL_SIZE.qin,"strike")
	return (Vector2(WEAPON[_kind(id)]) - _source_foot(id)) * _scale(id)

func _is_ally(id: String) -> bool: return id in ["hero","shen","tang","qin"]
func _kind(id: String) -> String: return id if _is_ally(id) else "rival"
func _scale(id: String) -> float: return float(CELL_SIZE.get(id,290.0)) / 512.0
func _source_foot(id: String) -> Vector2: return Hero.FOOT if _is_ally(id) else Rival.FOOT
func actor_rect(id: String) -> Rect2:
	if id == "qin": return Qin.drawing_rect(actor_foot(id),CELL_SIZE.qin,actor_visual_pose(id))
	return Rect2(actor_foot(id) - _source_foot(id) * _scale(id), Vector2.ONE * float(CELL_SIZE.get(id,290.0)))

func _down_transform(id: String) -> Transform2D:
	return Transform2D(PI * .5, Vector2(.38,1), 0.0, actor_foot(id) + Vector2(-87,-28))

func actor_alpha_rect(id: String) -> Rect2:
	if id == "qin": return Qin.opaque_rect(actor_foot(id),CELL_SIZE.qin,actor_visual_pose(id))
	var pose: String = actor_visual_pose(id)
	if pose == "down":
		var original: Rect2 = ALPHA_BOUNDS[id].cover
		var local: Rect2 = Rect2((original.position - _source_foot(id)) * _scale(id), original.size * _scale(id))
		return _down_transform(id) * local
	var bounds: Rect2 = ALPHA_BOUNDS[_kind(id)][pose]
	return Rect2(actor_rect(id).position + bounds.position * _scale(id), bounds.size * _scale(id))

func target_anchor(id: String) -> Vector2:
	if id.is_empty() or not IDS.has(id): return Vector2.ZERO
	var pose: String = actor_visual_pose(id)
	if id == "qin": return actor_foot(id) + (Vector2(QIN_CHEST[pose]) - Vector2(Qin.FOOT_ANCHORS[pose])) * (CELL_SIZE.qin / 512.0 * Qin.NORMALIZATION)
	if pose == "down": return actor_alpha_rect(id).get_center()
	return actor_rect(id).position + Vector2(CHEST[_kind(id)][pose]) * _scale(id)

func blade_tip(id: String) -> Vector2:
	if id == "qin": return Qin.weapon_point(actor_foot(id),CELL_SIZE.qin,actor_visual_pose(id))
	return actor_rect(id).position + Vector2(WEAPON[_kind(id)]) * _scale(id)

func unit_label_rect(id: String) -> Rect2:
	var bounds: Rect2 = actor_alpha_rect(id)
	var extent: Vector2 = Vector2(126,34) if _is_ally(id) else Vector2(156,46)
	var x: float = clampf(actor_foot(id).x - extent.x * .5, 8.0, 1272.0 - extent.x)
	var base: Rect2 = Rect2(Vector2(x,maxf(70.0,bounds.position.y-extent.y-9)),extent)
	for shift: float in [0,24,-24,48,-48,72,-72,96,-96]:
		var candidate: Rect2 = Rect2(Vector2(clampf(base.position.x+shift,8,1272-extent.x),base.position.y),extent)
		var clear: bool = true
		for unit: Dictionary in _display.get("actors",[]) + _display.get("enemies",[]):
			if candidate.intersects(actor_alpha_rect(unit.id).grow(5)):
				clear = false; break
		if clear: return candidate
	return base

func unit_label_alpha(id: String) -> float:
	if _unit(_display,id).is_empty() or actor_foot(id).distance_to(actor_home(id)) > 3.0: return 0.0
	var box: Rect2 = unit_label_rect(id)
	for other: String in actor_order():
		if box.intersects(actor_alpha_rect(other).grow(4)): return 0.0
		if other != id and actor_foot(other).distance_to(actor_home(other)) <= 3.0:
			var other_box: Rect2 = unit_label_rect(other)
			if box.intersects(other_box) and IDS.find(id) > IDS.find(other): return 0.0
	return 1.0

func target_at(point: Vector2) -> String:
	var ids: Array[String] = actor_order(); ids.reverse()
	for id: String in ids:
		if int(_unit(_display,id).get("hp",0)) <= 0: continue
		var ring: Vector2 = (point - actor_foot(id) - Vector2(0,5)) / Vector2(55,11)
		# Torso is deliberately narrower than the full atlas alpha/weapon reach.
		if Rect2(target_anchor(id) - Vector2(29,45),Vector2(58,98)).has_point(point) or ring.length_squared() <= 1.0: return id
	return ""

func _gui_input(event: InputEvent) -> void:
	if _presenting: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id: String = target_at(event.position)
		if not id.is_empty():
			target_requested.emit(id)
			accept_event()

func ground_point(x: float, y: float) -> Vector2:
	return Vector2(lerpf(110.0 - 150.0*y,1170.0 + 150.0*y,x),lerpf(320.0,682.0,y))

func _make_floor() -> ArrayMesh:
	var vertices = PackedVector3Array(); var uvs = PackedVector2Array(); var colors = PackedColorArray()
	for y in range(2):
		for x in range(3):
			for corner: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
				var depth: float = (y + corner.y) / 2.0
				var p: Vector2 = ground_point((x + corner.x) / 3.0,depth)
				vertices.append(Vector3(p.x,p.y,0))
				uvs.append(Vector2(1-corner.x if x%2 else corner.x,1-corner.y if y%2 else corner.y))
				colors.append(Color(.60,.66,.65).lerp(Color(.88,.91,.88),depth))
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_TEX_UV] = uvs; arrays[Mesh.ARRAY_COLOR] = colors
	var mesh = ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays); return mesh

func _draw() -> void:
	draw_rect(Rect2(0,0,1280,685),Color("10272a"))
	var background = Backdrop.texture()
	if background: draw_texture_rect(background,Rect2(0,-25,1280,486),false,Color(.83,.92,.94))
	if _floor: draw_mesh(_floor,WOOD)
	draw_line(ground_point(0,0),ground_point(1,0),Color("4a5046"),13,true)
	draw_line(ground_point(0,0)+Vector2(0,3),ground_point(1,0)+Vector2(0,3),Color("92927a"),2,true)
	for y: float in [.32,.68]: draw_line(ground_point(0,y),ground_point(1,y),Color(.05,.12,.13,.25),2,true)
	for foot: Vector2 in [Vector2(115,337),Vector2(1165,337)]:
		draw_set_transform(foot,0,Vector2.ONE*2.05); Lantern.draw(self,Vector2.ZERO,_clock); draw_set_transform(Vector2.ZERO)
	var ids: Array[String] = actor_order()
	# Every shadow/ring is below every body; actual moving Y controls occlusion.
	for id: String in ids:
		var foot: Vector2 = actor_foot(id)
		_ellipse(foot+Vector2(0,5),Vector2(51,9),Color(.015,.05,.055,.5))
		if id == selected_id and int(_unit(_display,id).hp) > 0:
			for i: int in range(48):
				var a: float = i*TAU/48
				draw_line(foot+Vector2(cos(a)*55,sin(a)*11+5),foot+Vector2(cos(a+.10)*55,sin(a+.10)*11+5),GOLD,1.8,true)
	for id: String in ids: _draw_actor(id)
	for id: String in ids:
		if int(_unit(_display,id).get("status",{}).get("barrier",0)) > 0:
			draw_arc(target_anchor(id),47,-1.5,1.5,30,Color(.51,.82,.90,.48),2.2,true)
	if _presenting: _draw_effects()

func _draw_actor(id: String) -> void:
	if id == "qin":
		Qin.draw(self,actor_foot(id),actor_visual_pose(id),.78 if int(_unit(_display,id).get("hp",0)) <= 0 else 1.0,CELL_SIZE.qin)
		return
	var pose: String = actor_visual_pose(id)
	var atlas = Hero if id == "hero" else (Shen if id == "shen" else (Tang if id == "tang" else Rival))
	var texture: AtlasTexture = atlas.texture_for("cover" if pose == "down" else pose)
	if texture == null: return
	var tint: Color = Color.WHITE
	if id == "bracer": tint = Color(.70,.88,.91)
	elif id == "striker": tint = Color(1,.88,.76)
	elif id == "sluice_scout": tint = Color(.67,.73,.79)
	elif id == "sluice_boss": tint = Color(.91,.77,.65)
	if int(_unit(_display,id).get("hp",0)) <= 0 and pose in ["down","kneel"]: tint = tint.darkened(.22)
	if pose == "down":
		draw_set_transform_matrix(_down_transform(id))
		draw_texture_rect(texture,Rect2(-_source_foot(id)*_scale(id),Vector2.ONE*float(CELL_SIZE[id])),false,tint)
		draw_set_transform(Vector2.ZERO)
	else: draw_texture_rect(texture,actor_rect(id),false,tint)

func _draw_effects() -> void:
	var segment: Dictionary = _current_segment()
	if not segment.is_empty():
		var t: float = action_time - float(segment.start)
		var target: Vector2 = target_anchor(segment.target_id)
		if _has_event(segment,"damage"):
			if segment.source_id == "shen" and t >= .16 and t <= CONTACT_AT + .06:
				var origin: Vector2 = blade_tip("shen")
				var tip: Vector2 = origin.lerp(target,_ease(.16,CONTACT_AT,t))
				var direction: Vector2 = (target-origin).normalized()
				for offset: float in [-3,0,3]: draw_line(tip-direction*28+Vector2(0,offset),tip+Vector2(0,offset),Color("d8e9bd"),1.7,true)
			var impact: float = _pulse(CONTACT_AT-.03,CONTACT_AT+.02,.58,t)
			if impact > 0:
				draw_arc(target,21+12*(1-impact),-.8,2.3,20,Color(.98,.83,.57,impact),2,true)
				for offset: float in [-1,0,1]: draw_line(target+Vector2(-22,20+offset*6),target+Vector2(24,-16+offset*6),Color(.95,.88,.66,impact*.65),2,true)
		if _has_event(segment,"barrier_grant") or _has_event(segment,"barrier_absorb"):
			for event: Dictionary in segment.events:
				if event.type not in ["barrier_grant","barrier_absorb"]: continue
				var protected: Vector2 = target_anchor(event.target_id)
				var strength: float = _pulse(.20,CONTACT_AT,.65,t)
				draw_arc(protected,46,-1.7,1.7,30,Color(.51,.84,.93,strength),3,true)
		if _has_event(segment,"heal"):
			for event: Dictionary in segment.events:
				if event.type != "heal": continue
				var heal_target: Vector2 = target_anchor(event.target_id)
				var glow: float = _pulse(.18,CONTACT_AT,.68,t)
				draw_arc(heal_target+Vector2(0,25),43,-PI,0,28,Color(.57,.87,.67,glow*.8),3,true)
				if segment.source_id == "shen" and event.target_id != "shen": draw_line(blade_tip("shen"),heal_target,Color(.63,.88,.69,glow*.25),2,true)
	for fact: Dictionary in _floats:
		var age: float = action_time - float(fact.at)
		if age < 0 or age > .62: continue
		var event: Dictionary = fact.event
		var value: String = ""
		var color: Color = Color("d5d6a0")
		match event.type:
			"damage": value = "−%d" % int(event.amount); color = Color("f1ba8f")
			"heal": value = "+%d" % int(event.amount); color = Color("b8e2a0")
			"qi": value = "气 %+d" % int(event.amount)
			"proficiency": value = "熟练 +%d" % int(event.amount)
			"medicine": value = "药 %d" % int(event.amount)
			"barrier_grant": value = "护 +%d" % int(event.amount); color = Color("9bd4e7")
			"barrier_absorb": value = "抵 %d" % int(event.amount); color = Color("9bd4e7")
			"barrier_expire": value = "护障消散"; color = Color("9bd4e7")
		color.a = 1.0 - _ease(.34,.62,age)
		var offset: Vector2 = Vector2(34,-52-age*35)
		if event.type in ["qi","medicine","proficiency"]: offset += Vector2(-36,-25)
		draw_string(FONT,Vector2(fact.anchor)+offset,value,HORIZONTAL_ALIGNMENT_LEFT,-1,19 if event.type in ["damage","heal"] else 14,color)

func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points = PackedVector2Array()
	for i: int in range(40): points.append(center+Vector2(cos(i*TAU/40)*radius.x,sin(i*TAU/40)*radius.y))
	draw_colored_polygon(points,color)

func _ease(start: float, end: float, time: float) -> float:
	var t: float = clampf((time-start)/maxf(.001,end-start),0,1)
	return t*t*(3-2*t)

func _pulse(start: float, peak: float, end: float, time: float) -> float:
	return _ease(start,peak,time)*(1-_ease(peak,end,time))

func _readonly(value: Dictionary) -> Dictionary:
	var copy: Dictionary = value.duplicate(true)
	_freeze(copy)
	return copy

func _freeze(value: Variant) -> void:
	if value is Dictionary:
		for key: Variant in value: _freeze(value[key])
		value.make_read_only()
	elif value is Array:
		for item: Variant in value: _freeze(item)
		value.make_read_only()
