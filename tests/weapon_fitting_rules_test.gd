extends SceneTree
## Leaf scalar contract only. No gameplay balance or scene/site proof.
const Rules = preload("res://scripts/weapon_fitting_rules.gd")
const State = preload("res://scripts/game_state.gd")
var checks: int = 0
var failures: int = 0

class HistoricalScalarState extends RefCounted:
	var attack: int = 16
	var defense: int = 4
	var quest_stage: int = 0
	var sect: String = "未入门"

class LeafProbe extends State:
	var touched: bool = false
	func _stage_save_data(_data: Dictionary, _version: int) -> Dictionary:
		touched = true
		return {"ok": false}
	func party_resource_snapshot() -> Dictionary:
		touched = true
		return {"ok": false}

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)

func _init() -> void:
	check(Rules.IDS == ["plain", "edge", "guard"] and Rules.SECTS == State.SECTS, "Exactly three fittings and real sect catalog")
	for stage: int in range(7):
		for sect: String in ["未入门", "unknown", "听潮阁", "照野堂", "问石门"]:
			for fitting: String in Rules.IDS:
				var result: Dictionary = Rules.project(16, 4, stage, sect, fitting)
				var allowed: bool = fitting == "plain" or (stage == 6 and State.SECTS.has(sect))
				check(result.ok == allowed, "Exact opening and sect eligibility:%d/%s/%s" % [stage, sect, fitting])
				if result.ok:
					var delta: Vector2i = Rules.DELTAS[fitting]
					check(result.attack == 16 + delta.x and result.defense == 4 + delta.y and result.base_attack == 16 and result.base_defense == 4, "Once-only full delta")
					check(result.is_read_only(), "Projection is detached read-only scalars")
	for attack: int in [1, 2, 3, 4, 16, 999]:
		for defense: int in [0, 1, 2, 4, 999]:
			for fitting: String in Rules.IDS:
				var result: Dictionary = Rules.project(attack, defense, 6, "听潮阁", fitting)
				var delta: Vector2i = Rules.DELTAS[fitting]
				var allowed: bool = attack + delta.x >= 1 and defense + delta.y >= 0
				check(result.ok == allowed, "Full advertised cost either applies or rejects")
				if result.ok: check(result.attack == attack + delta.x and result.defense == defense + delta.y, "No floor or upper clamp")
	check(Rules.project(999, 999, 6, "听潮阁", "edge").attack == 1002, "Derived1002 allowed above base999")
	check(Rules.project(999, 999, 6, "听潮阁", "guard").defense == 1001, "Derived1001 allowed above base999")
	check(Rules.project(1000, 4, 0, "未入门").attack == 1000, "Retained direct synthetic1000 remains original")
	for malformed: Variant in [null, true, 0, 1.0, [], {}, "", "original", "EDGE", "edge "]:
		check(not Rules.project(16, 4, 6, "听潮阁", malformed).ok, "Malformed enum rejects:" + str(malformed))
	for malformed: Variant in [null, true, "16", [], {}, NAN, INF, -1, 1.5]:
		check(not Rules.project(malformed, 4, 6, "听潮阁", "plain").ok, "Malformed attack rejects")
		check(not Rules.project(16, malformed, 6, "听潮阁", "plain").ok, "Malformed defense rejects")
	for version: int in [0, 17, -1]:
		check(not Rules.valid_save({}, version), "Pure save validator rejects unsupported absent version")
		check(not Rules.valid_save({"attack": 16, "defense": 4, "quest_stage": 6, "sect": "听潮阁", "weapon_fitting": "edge"}, version), "Pure save validator rejects unsupported present version")
	var historical := HistoricalScalarState.new()
	check(Rules.from_state(historical).fitting == "plain" and Rules.attack_for(historical) == 16 and Rules.defense_for(historical) == 4, "Genuinely absent old property defaults plain without new methods")
	var dictionary := {"attack": 16, "defense": 4, "quest_stage": 6, "sect": "听潮阁", "weapon_fitting": null}
	check(not Rules.from_state(dictionary).ok, "Present null never mistaken for absent")
	var probe := LeafProbe.new()
	probe.quest_stage = 6; probe.choose_sect("听潮阁"); probe.weapon_fitting = "edge"
	check(probe.fitting_projection().ok and probe.effective_attack() == probe.attack + 3 and not probe.touched, "Projection never calls whole-state/roster/resource validators")
	check(State.PartyCatalog.build_team(probe, ["hero"]).ok and not probe.touched, "Catalog leaf projection cannot recurse through state validation")
	if failures == 0: print("PASS: %d fitting leaf enum/eligibility/full-cost/bounds/old-property/purity checks" % checks)
	quit(0 if failures == 0 else 1)
