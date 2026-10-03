class_name VolumeOneCapstoneCombatData
extends RefCounted
## One original authorizer. Entry endurance is authored and roster-independent;
## the public cadence reuses guard, damage opening and ordinary weakening only.
const ENCOUNTER_ID: String = "capstone_authorizer"
const ENEMY_IDS: Array[String] = ["liang_zhen"]
const PHASES: Array[Dictionary] = [
	{"phase": "guard", "name": "横令守锋", "damage": 26, "heavy": false, "guarded": true, "opening": 0},
	{"phase": "heavy", "name": "压签重斩", "damage": 46, "heavy": true, "guarded": false, "opening": 0},
	{"phase": "recovery", "name": "收令回势", "damage": 8, "heavy": false, "guarded": false, "opening": 10}
]

static func endurance() -> Dictionary:
	return {"liang_zhen_max_hp": 620,
		"reason": "梁缜入场气血620；人数不改变对手气血，交锋中不回血、不改上限。"}

static func specs(entry: Dictionary) -> Array[Dictionary]:
	return [{"id": "liang_zhen", "name": "梁缜·签令主事", "hp": int(entry.liang_zhen_max_hp), "attack": 26, "heavy_attack": 46}]

static func phase(enemy_id: String, round_number: int) -> Dictionary:
	if enemy_id not in ENEMY_IDS:
		return {}
	return PHASES[posmod(round_number - 1, PHASES.size())].duplicate(true)

static func outgoing(enemy_id: String, round_number: int, amount: int) -> int:
	var current: Dictionary = phase(enemy_id, round_number)
	if current.is_empty():
		return amount
	if bool(current.guarded):
		return maxi(1, int(ceil(float(amount) * 0.5)))
	return maxi(0, amount) + int(current.opening)
