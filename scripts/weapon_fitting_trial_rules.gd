class_name WeaponFittingTrialRules
extends RefCounted
## Whitelisted, detached rehearsal factory. Only a genuine current HeroState
## and catalog enums enter; no actor, modifier, enemy, or comparison payload can
## be supplied by the caller. No live State reference escapes this method.
const Catalog = preload("res://scripts/party_actor_catalog.gd")
const Roster = preload("res://scripts/party_roster_rules.gd")
const Fittings = preload("res://scripts/weapon_fitting_rules.gd")
const RULES_REVISION: String = "weapon-fitting-trial-1"
const PROFILE_REVISION: String = "courtyard-fitting-40-64-16-12b-v1"
const PROFILES: Array[String] = ["ordinary", "pressure"]
const ENCOUNTER_ID: String = "courtyard_practice"
const MEDICINE_CHARGES: int = 3
const MEDICINE_HEAL: int = 40


static func build(source_state, fitting_id: String, profile_id: String = "ordinary") -> Dictionary:
	if not PROFILES.has(profile_id):
		return _error("试配仅支持普通木人与进阶高压两种预设。")
	if not Fittings.IDS.has(fitting_id):
		return _error("借用配件无效。")
	# A serialized save or a forged factory result is not an entry capability.
	# The genuine State owns validation and roster ownership; do not preload it
	# here, since State itself owns the automatic combat model.
	if not source_state is RefCounted or source_state.get_script() == null:
		return _error("试配需要真实角色状态，不能传入队伍或敌人资料。")
	if source_state.get_script().resource_path != "res://scripts/game_state.gd":
		return _error("试配角色状态来源无效。")
	if source_state.battle_active or source_state._party_gate() or source_state._party_pending_token >= 0:
		return _error("当前交锋尚未结束，不能另开试配。")
	var staged: Dictionary = source_state._stage_save_data(source_state.to_dict(), source_state.SAVE_VERSION)
	if not staged.ok:
		return _error("角色或已招募出战名单无效，不能试配。")
	var baseline_state = staged.state
	var projected: Dictionary = Fittings.project(baseline_state.attack, baseline_state.defense,
		baseline_state.quest_stage, baseline_state.sect, fitting_id)
	if not projected.ok:
		return _error(projected.reason)
	if not projected.unlocked:
		return _error("完成青苇渡失灯之事并正式选定门派后，才可借用试配。")
	var installed_fitting: String = baseline_state.weapon_fitting
	# Never derive original values by subtracting a currently installed delta.
	baseline_state.weapon_fitting = Fittings.PLAIN
	var resources: Dictionary = Roster.battle_resources(baseline_state, baseline_state._party_payload())
	if not resources.ok:
		return _error(resources.reason)
	var built: Dictionary = Catalog.build_team(baseline_state, baseline_state.party_roster, resources.resources)
	if not built.ok:
		return _error(built.reason)
	var original: Dictionary = built.team.duplicate(true)
	var budget: int = 0
	var starting_actors: Dictionary = {}
	for actor: Dictionary in original.actors:
		budget += int(actor.attack)
		actor.hp = int(actor.max_hp)
		actor.qi = int(actor.max_qi)
		starting_actors[actor.id] = {"hp": actor.hp, "qi": actor.qi}
	original.medicine = MEDICINE_CHARGES
	original.medicine_heal = MEDICINE_HEAL
	var enemies: Array[Dictionary] = [
		{"id": "striker", "name": "执棍木人", "hp": 96, "attack": 14, "heavy_attack": 24},
		{"id": "bracer", "name": "架盾木人", "hp": 64, "attack": 10, "heavy_attack": 10},
	]
	if profile_id == "pressure":
		# Independent integer truncation is deliberate: the total is12B−1 when
		# B is not divisible by5. Never preserve a remainder or use fitted power.
		enemies[0].hp = budget * 36 / 5
		enemies[1].hp = budget * 24 / 5
		enemies[0].attack = 40
		enemies[0].heavy_attack = 64
		enemies[1].attack = 16
		enemies[1].heavy_attack = 16
	var starting: Dictionary = {"actors": starting_actors, "medicine": MEDICINE_CHARGES, "medicine_heal": MEDICINE_HEAL}
	var baseline: Dictionary = {"level": int(baseline_state.level),
		"learned_arts": baseline_state.learned_arts.duplicate(true), "team": original}
	var identity: Dictionary = {"rules_revision": RULES_REVISION, "profile_revision": PROFILE_REVISION,
		"profile_id": profile_id, "encounter_id": ENCOUNTER_ID, "original_baseline": baseline,
		"enemy_specs": enemies, "starting_resources": starting}
	var metadata: Dictionary = identity.duplicate(true)
	metadata.comparison_key = JSON.stringify(identity, "", true).sha256_text()
	metadata.installed_fitting = installed_fitting
	metadata.borrowed_fitting = fitting_id
	metadata.base_attack_budget = budget
	metadata.profile_name = "普通木人试配" if profile_id == "ordinary" else "进阶试配（未装配队伍基线，高压）"
	metadata.profile_description = "借用满气血、满真气及三份40点回春散；不改变真实资源。"
	if profile_id == "pressure":
		metadata.profile_description += "按未装配队伍攻击总和分别取整木人气血；轻重棍伤害40/64，短盾16。初入门派可能落败，高等级未必能区分配件。"
	var team: Dictionary = original.duplicate(true)
	team.actors[0].attack = projected.attack
	team.actors[0].defense = projected.defense
	return Catalog.immutable({"ok": true, "reason": "", "team": team, "metadata": metadata})


static func _error(reason: String) -> Dictionary:
	return Catalog.immutable({"ok": false, "reason": reason, "team": {}, "metadata": {}})
