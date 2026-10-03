class_name HetingConsigneeCombatData
extends RefCounted
## Entry-only endurance and announced per-opponent cadence. This chapter adds
## no status type: guarding, opening damage and ordinary weakening stay shared.
const ENCOUNTER_ID: String = "heting_consignee"
const ENEMY_IDS: Array[String] = ["du_hui", "consignee_guard"]
const PHASES: Dictionary = {
	"du_hui": [
		{"phase": "light", "name": "横契试锋", "damage": 20, "heavy": false, "guarded": true, "opening": 0},
		{"phase": "heavy", "name": "压仓重劈", "damage": 38, "heavy": true, "guarded": false, "opening": 0},
		{"phase": "recovery", "name": "收契回势", "damage": 8, "heavy": false, "guarded": false, "opening": 8}],
	"consignee_guard": [
		{"phase": "heavy", "name": "催运重扫", "damage": 28, "heavy": true, "guarded": false, "opening": 0},
		{"phase": "recovery", "name": "撤步收运", "damage": 6, "heavy": false, "guarded": false, "opening": 6},
		{"phase": "light", "name": "护运试棍", "damage": 16, "heavy": false, "guarded": true, "opening": 0}]
}

static func endurance() -> Dictionary:
	return {"du_hui_max_hp": 260, "consignee_guard_max_hp": 160,
		"reason": "杜晦入场气血260，收运护手160；人数不改变对手气血，交锋中不回血、不改上限。"}

static func specs(entry: Dictionary) -> Array[Dictionary]:
	return [{"id": "du_hui", "name": "杜晦·平川粮栈管事", "hp": int(entry.du_hui_max_hp), "attack": 20, "heavy_attack": 38},
		{"id": "consignee_guard", "name": "收运护手", "hp": int(entry.consignee_guard_max_hp), "attack": 16, "heavy_attack": 28}]

static func phase(enemy_id: String, round_number: int) -> Dictionary:
	if not PHASES.has(enemy_id):
		return {}
	return PHASES[enemy_id][posmod(round_number - 1, 3)].duplicate(true)

static func outgoing(enemy_id: String, round_number: int, amount: int) -> int:
	var current: Dictionary = phase(enemy_id, round_number)
	if current.is_empty():
		return amount
	if bool(current.guarded):
		return maxi(1, int(ceil(float(amount) * 0.5)))
	return maxi(0, amount) + int(current.opening)
