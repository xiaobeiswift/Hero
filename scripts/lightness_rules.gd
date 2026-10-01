class_name LightnessRules
extends RefCounted
## Explicit traversal links; lightness never disables ordinary collision.
const RELIC_ID: String = "reed_islet"
const SHORE: Vector2 = Vector2(1420, 930)
const LANDING: Vector2 = Vector2(1514, 930)
const ISLET_CENTER: Vector2 = Vector2(1514, 930)
const ISLET_RADIUS: Vector2 = Vector2(40, 36)
const RELIC_POSITION: Vector2 = Vector2(1537, 947)

static func on_islet(point: Vector2) -> bool:
	if not point.is_finite():
		return false
	return ((point - ISLET_CENTER) / ISLET_RADIUS).length_squared() <= 1.0

static func can_learn(s) -> bool:
	return not s.battle_active and not s.lightness_unlocked and s.level >= 3 and s.sect in ["听潮阁", "照野堂", "问石门"]

static func learn(s) -> bool:
	if not can_learn(s):
		return false
	s.lightness_unlocked = true
	return true

static func can_cross(s, outward: bool) -> bool:
	if s.battle_active or s.map_id != "qingwei" or not s.position.is_finite():
		return false
	if not outward:
		# Never strand a loaded or externally interrupted traveller on the islet.
		return on_islet(s.position)
	return s.lightness_unlocked and not on_islet(s.position) \
		and s.position.distance_to(SHORE) < 75.0 and s.position.x <= 1440.0

static func cross(s, outward: bool) -> bool:
	if not can_cross(s, outward):
		return false
	s.position = LANDING if outward else SHORE
	return true

static func discover(s) -> bool:
	if s.battle_active or not s.lightness_unlocked or s.map_id != "qingwei" \
		or not on_islet(s.position) or s.lightness_relics.has(RELIC_ID):
		return false
	s.lightness_relics.append(RELIC_ID)
	s.coins = mini(999999, s.coins + 18)
	s.resources.herb = mini(9999, int(s.resources.herb) + 1)
	s.gain_xp(30)
	return true

static func restore(s, data: Dictionary) -> void:
	s.lightness_unlocked = bool(data.get("lightness_unlocked", false))
	s.lightness_relics.clear()
	for id in data.get("lightness_relics", []):
		if not s.lightness_relics.has(id):
			s.lightness_relics.append(id)

static func valid(data: Dictionary, version: int) -> bool:
	if version >= 8 and (not data.has("lightness_unlocked") or not data.has("lightness_relics")):
		return false
	if data.has("lightness_unlocked") != data.has("lightness_relics"):
		return false
	var unlocked = data.get("lightness_unlocked", false)
	var relics = data.get("lightness_relics", [])
	if not unlocked is bool or not relics is Array:
		return false
	if relics.size() > 1:
		return false
	for id in relics:
		if not id is String or id != RELIC_ID:
			return false
	if not unlocked and not relics.is_empty():
		return false
	if unlocked and (float(data.get("level", 1)) < 3 or data.get("sect", "") not in ["听潮阁", "照野堂", "问石门"]):
		return false
	return true
