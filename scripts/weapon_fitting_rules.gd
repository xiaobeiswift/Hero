class_name WeaponFittingRules
extends RefCounted
## Leaf-pure projection: only scalar base values enter; no save validation,
## roster, catalog, resource snapshot, state mutation or filesystem calls.
const INTRODUCED_VERSION: int = 16
const MAX_SUPPORTED_VERSION: int = 16
const PLAIN: String = "plain"
const IDS: Array[String] = [PLAIN, "edge", "guard"]
const SECTS: Array[String] = ["听潮阁", "照野堂", "问石门"]
const LABELS: Dictionary = {PLAIN: "原装", "edge": "进攻配件", "guard": "防护配件"}
const DELTAS: Dictionary = {PLAIN: Vector2i(0, 0), "edge": Vector2i(3, -2), "guard": Vector2i(-3, 2)}


static func project(base_attack: Variant, base_defense: Variant, quest_stage: Variant, sect: Variant, fitting: Variant = PLAIN) -> Dictionary:
	if not fitting is String or not IDS.has(fitting):
		return _error("配件须为原装、进攻配件或防护配件。")
	# The whole-save validator owns the stored999 cap. Retained direct adapters
	# also use synthetic base1000; no projected value is clamped to a save cap.
	if not _integer(base_attack, 1) or not _integer(base_defense, 0):
		return _error("基础攻击与防御须为有效的非负整数，攻击至少为1。")
	var unlocked: bool = _integer(quest_stage, 0) and quest_stage == 6 and sect is String and SECTS.has(sect)
	if fitting != PLAIN and not unlocked:
		return _error("完成青苇渡失灯之事并正式选定门派后，才可选用配件。")
	var delta: Vector2i = DELTAS[fitting]
	var power: int = int(base_attack) + delta.x
	var protection: int = int(base_defense) + delta.y
	if power < 1 or protection < 0:
		return _error("此配件的完整代价会使攻击低于1或防御低于0，不能选用。")
	return _immutable({"ok": true, "reason": "", "fitting": fitting, "name": LABELS[fitting],
		"base_attack": int(base_attack), "base_defense": int(base_defense),
		"attack_delta": delta.x, "defense_delta": delta.y,
		"attack": power, "defense": protection, "unlocked": unlocked})


## A missing property on genuine historical HeroState scripts means original.
## Inspect presence separately: a present null/malformed value must not default.
## This compatibility adapter still only reads scalar properties.
static func from_state(state) -> Dictionary:
	if state == null: return _error("缺少角色状态。")
	var fitting: Variant = PLAIN
	if state is Dictionary:
		fitting = state.get("weapon_fitting", PLAIN)
	else:
		for property: Dictionary in state.get_property_list():
			if property.name == "weapon_fitting":
				fitting = state.get("weapon_fitting")
				break
	return project(state.get("attack"), state.get("defense"), state.get("quest_stage"), state.get("sect"), fitting)


static func attack_for(state) -> int:
	var value: Dictionary = from_state(state)
	return int(value.attack) if value.ok else 0


static func defense_for(state) -> int:
	var value: Dictionary = from_state(state)
	return int(value.defense) if value.ok else -1


static func valid_save(data: Dictionary, version: int) -> bool:
	if version < 1 or version > MAX_SUPPORTED_VERSION: return false
	for key: Variant in data:
		if key is String and key.begins_with("weapon_fitting") and key != "weapon_fitting": return false
	if not data.has("weapon_fitting"):
		return version < INTRODUCED_VERSION
	return project(data.get("attack"), data.get("defense"), data.get("quest_stage"), data.get("sect"), data.weapon_fitting).ok


static func _integer(value: Variant, minimum: int) -> bool:
	# Bound before conversion/addition; normal persistent bases remain <=999.
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= 9007199254740000.0


static func _immutable(value: Dictionary) -> Dictionary:
	value.make_read_only()
	return value


static func _error(reason: String) -> Dictionary:
	return _immutable({"ok": false, "reason": reason})
