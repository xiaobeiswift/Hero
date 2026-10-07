class_name EncounterRehearsalRules
extends RefCounted
## Earned-only detached factory. Encounter identity selects existing enemy rules;
## resource policy separately prevents real costs, proficiency and settlement.
const Catalog = preload("res://scripts/party_actor_catalog.gd")
const Roster = preload("res://scripts/party_roster_rules.gd")
const Consignee = preload("res://scripts/heting_consignee_combat_data.gd")
const Capstone = preload("res://scripts/volume_one_capstone_combat_data.gd")
const POLICY: String = "encounter_rehearsal"
const RULES_REVISION: String = "earned-encounter-rehearsal-1"
const IDS: Array[String] = ["heting_consignee", "capstone_authorizer"]
const MEDICINE_CHARGES: int = 3
const MEDICINE_HEAL: int = 40


static func _validated(source_state) -> Dictionary:
	if not source_state is RefCounted or source_state.get_script() == null:
		return {"ok": false}
	if source_state.get_script().resource_path != "res://scripts/game_state.gd":
		return {"ok": false}
	return source_state._stage_save_data(source_state.to_dict(), source_state.SAVE_VERSION)


static func _earned(state, encounter_id: String) -> bool:
	if encounter_id == "heting_consignee":
		return state.consignee_stage >= 3 and state.consignee_stage <= 5
	if encounter_id == "capstone_authorizer":
		return state.capstone_stage >= 4 and state.capstone_stage <= 7
	return false


static func options(source_state) -> Dictionary:
	var checked: Dictionary = _validated(source_state)
	var entries: Array[Dictionary] = []
	if checked.get("ok", false):
		for encounter_id: String in IDS:
			if _earned(checked.state, encounter_id):
				entries.append({"encounter_id": encounter_id, "name": "杜晦 · 收货交锋" if encounter_id == "heting_consignee" else "梁缜 · 截令交锋"})
	# Locked identities and enemy data never appear in the result.
	return Catalog.immutable({"ok": bool(checked.get("ok", false)), "options": entries})


static func build(source_state, encounter_id: Variant) -> Dictionary:
	if not encounter_id is String or not IDS.has(encounter_id):
		return _error("请选择已经战胜的交锋。")
	var checked: Dictionary = _validated(source_state)
	if not checked.get("ok", false):
		return _error("当前旅程或出战名单无效，不能演练。")
	if not _earned(checked.state, encounter_id):
		return _error("这场交锋尚未取得真实胜利，不能演练。")
	if source_state.battle_active or source_state._party_gate() or source_state._party_pending_token >= 0:
		return _error("当前交锋尚未结束，不能另开演练。")
	if source_state.map_id != "qingwei":
		return _error("请回到青苇渡南庭开始演练。")
	var baseline = checked.state
	var resources: Dictionary = Roster.battle_resources(baseline, baseline._party_payload())
	if not resources.ok: return _error(resources.reason)
	var built: Dictionary = Catalog.build_team(baseline, baseline.party_roster, resources.resources)
	if not built.ok: return _error(built.reason)
	var team: Dictionary = built.team.duplicate(true)
	var starting: Dictionary = {"actors": {}, "medicine": MEDICINE_CHARGES, "medicine_heal": MEDICINE_HEAL}
	for actor: Dictionary in team.actors:
		actor.hp = int(actor.max_hp)
		actor.qi = int(actor.max_qi)
		starting.actors[actor.id] = {"hp": actor.hp, "qi": actor.qi}
	team.medicine = MEDICINE_CHARGES
	team.medicine_heal = MEDICINE_HEAL
	var provenance: Dictionary = Consignee.endurance() if encounter_id == "heting_consignee" else Capstone.endurance()
	var specs: Array = Consignee.specs(provenance) if encounter_id == "heting_consignee" else Capstone.specs(provenance)
	var identity: Dictionary = {"rules_revision": RULES_REVISION, "resource_policy": POLICY,
		"encounter_id": encounter_id, "team": team, "level": int(baseline.level),
		"learned_arts": baseline.learned_arts.duplicate(true), "installed_fitting": baseline.weapon_fitting,
		"enemy_specs": specs, "enemy_provenance": provenance,
		"enemy_cadence": Consignee.PHASES if encounter_id == "heting_consignee" else Capstone.PHASES,
		"starting_resources": starting}
	var metadata: Dictionary = identity.duplicate(true)
	metadata.comparison_key = JSON.stringify(identity, "", true).sha256_text()
	metadata.name = "杜晦 · 收货交锋复演" if encounter_id == "heting_consignee" else "梁缜 · 截令交锋复演"
	metadata.description = "当前出战队伍与已装配配件；仅演练内满气血、满真气及三份40点虚拟回春散。原交锋招式与节奏，不发奖励，不改变旅程。"
	return Catalog.immutable({"ok": true, "reason": "", "team": team, "metadata": metadata})


static func _error(reason: String) -> Dictionary:
	return Catalog.immutable({"ok": false, "reason": reason, "team": {}, "metadata": {}})
