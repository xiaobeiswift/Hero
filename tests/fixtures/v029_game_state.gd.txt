class_name HeroState
extends RefCounted
## Pure, deterministic rules for 青苇渡. No scene tree or UI dependencies.

const SAVE_VERSION: int = 15
const MAX_SAVE_BYTES: int = 1048576
const SAVE_PATH: String = "user://hero_save.json"
const SECTS: Array[String] = ["听潮阁", "照野堂", "问石门"]
const Patterns=preload("res://scripts/battle_patterns.gd")
const Mist=preload("res://scripts/mistwood_rules.gd")
const Heting=preload("res://scripts/heting_rules.gd")
const Receipt=preload("res://scripts/heting_receipt_rules.gd")
const ReceiptCombat=preload("res://scripts/heting_receipt_combat.gd")
const Consignee = preload("res://scripts/heting_consignee_rules.gd")
const Capstone = preload("res://scripts/volume_one_capstone_rules.gd")
const Lightness=preload("res://scripts/lightness_rules.gd")
const ShenCare=preload("res://scripts/shen_care_rules.gd")
const Companions=preload("res://scripts/companion_rules.gd")
const QinCompanion = preload("res://scripts/qin_companion_rules.gd")
const PartyCatalog = preload("res://scripts/party_actor_catalog.gd")
const PartyCombat = preload("res://scripts/automatic_party_combat.gd")
const UnifiedEncounters = preload("res://scripts/unified_encounter_rules.gd")
const PartyRoster = preload("res://scripts/party_roster_rules.gd")
const Sects=preload("res://scripts/sect_rules.gd")
const Chapter = preload("res://scripts/chapter_rules.gd")
const Items = preload("res://scripts/item_catalog.gd")
const Economy = preload("res://scripts/economy_rules.gd")
const Arts = preload("res://scripts/martial_catalog.gd")
const Advanced = preload("res://scripts/advanced_martial_rules.gd")

var player_name: String = "无名客"
var level: int = 1
var xp: int = 0
var coins: int = 24
var hp: int = 100
var max_hp: int = 100
var qi: int = 2
var max_qi: int = 6
var attack: int = 16
var defense: int = 4
var medicine: int = 3
var herbs: int = 0
var quest_stage: int = 0
var sect: String = "未入门"
var sect_rank:int=0
var sect_merit:int=0
var sect_trial_won:bool=false
var ending: String = ""
var position: Vector2 = Vector2(460, 430)
var victories: int = 0
var companion_unlocked: bool = false
var internal_unlocked: bool = false
var lightness_unlocked:bool=false
var lightness_relics:Array[String]=[]
var shen_care_stage:int=0
var shen_care_choice:String=""
var qin_stage: int = 0
var qin_unlocked: bool = false
var tangqi_unlocked:bool=false
var tangqi_stage:int=0
var tangqi_choice:String=""
var active_companion:String=""
var party_roster: Array[String] = ["hero"]
var party_resources: Dictionary = {}
var party_session
var party_battle_epoch: int = 0
var party_settlement: Dictionary = {}
var _party_pending_token: int = -1
var _party_encounter: String = ""
var _party_sluice_entry: Dictionary = {}
var _party_archive_entry: Dictionary = {}
var _party_extra_entry: Dictionary = {}
var _party_practice_before: Dictionary = {}
var _party_consignee_identity: Dictionary = {}
var _party_capstone_identity: Dictionary = {}
var formation: String = "并肩"
var equipment: String = "旧铁剑"
var heting_stage:int=0
var heting_bridge:String=""
var heting_delivered:Array[String]=[]
var heting_cargo:String=""
var heting_draft:String=""
var heting_ending:String=""
var receipt_stage:int=0
var consignee_stage: int = 0
var consignee_observations: Array[String] = []
var consignee_contributions: Array[String] = []
var consignee_draft: String = ""
var consignee_cargo_location: String = ""
var consignee_ending: String = ""
var capstone_stage: int = 0
var capstone_draft: String = ""
var capstone_ending: String = ""
var mist_stage:int=0
var mist_gauges:Array[String]=[]
var mist_approach:String=""
var mist_ending:String=""
var chapter_two_stage:int=0
var archive_clues:Array[String]=[]
var seal_sequence:Array[int]=[]
var chapter_two_ending:String=""
var bridge_repaired:bool=false
var armor: String = "粗布行衣"
var resources: Dictionary = {"iron":0,"timber":0,"cloth":0,"herb":0}
var gathered_nodes: Array[String] = []
var map_id: String = "qingwei"
var side_stage: int = 0
var side_choice: String = ""
var side_clues: int = 0
var side_reward_claimed: bool = false
var side_found: Array[String] = []
var equipped_art: String = "照夜一线"
var art_uses: Dictionary = {"照夜一线": 0}
var learned_arts: Array[String] = []
var claimed_deeds: Array[String] = []

var enemy_name: String = ""
var enemy_hp: int = 0
var enemy_max_hp: int = 0
var enemy_intent: String = ""
var battle_active: bool = false
var battle_kind: String = "story"
var turn: int = 0
var guard: bool = false
var battle_log: Array[String] = []
var skill_cooldown: int = 0
var enemy_base_attack: int = 9
var enemy_strong_attack: int = 19
var exposed_turns: int = 0
var enemy_weaken_amount: int = 0
var enemy_weaken_strikes: int = 0
var focused_damage: int = 0
var _companion_attack_count: int = 0
var _trial_art_used:bool=false
var _trial_healing:int=0
var _trial_guarded_heavy:bool=false
var receipt_session
var receipt_battle_epoch:int=0
var receipt_settlement:Dictionary={}


func reset_game() -> void:
	player_name = "无名客"
	level = 1
	xp = 0
	coins = 24
	hp = 100
	max_hp = 100
	qi = 2
	max_qi = 6
	attack = 16
	defense = 4
	medicine = 3
	herbs = 0
	quest_stage = 0
	sect = "未入门"
	sect_rank=0;sect_merit=0;sect_trial_won=false
	ending = ""
	position = Vector2(460, 430)
	victories = 0
	companion_unlocked = false
	internal_unlocked = false
	lightness_unlocked=false;lightness_relics.clear()
	shen_care_stage=0;shen_care_choice=""
	tangqi_unlocked=false;tangqi_stage=0;tangqi_choice="";active_companion=""
	qin_stage = 0
	qin_unlocked = false
	party_roster.assign(["hero"])
	party_resources = {}
	formation = "并肩"
	equipment = "旧铁剑"
	heting_stage=0;heting_bridge="";heting_delivered.clear();heting_cargo="";heting_draft="";heting_ending=""
	receipt_stage=0
	consignee_stage = 0
	consignee_observations.clear()
	consignee_contributions.clear()
	consignee_draft = ""
	consignee_cargo_location = ""
	consignee_ending = ""
	capstone_stage = 0
	capstone_draft = ""
	capstone_ending = ""
	mist_stage=0;mist_gauges.clear();mist_approach="";mist_ending=""
	chapter_two_stage=0
	archive_clues.clear()
	seal_sequence.clear()
	chapter_two_ending=""
	bridge_repaired=false
	armor = "粗布行衣"
	resources = {"iron":0,"timber":0,"cloth":0,"herb":0}
	gathered_nodes.clear()
	map_id = "qingwei"
	side_stage = 0
	side_choice = ""
	side_clues = 0
	side_reward_claimed = false
	side_found.clear()
	equipped_art = Arts.BASE_ART
	art_uses = {Arts.BASE_ART: 0}
	learned_arts.clear()
	claimed_deeds.clear()
	_clear_battle()


func xp_to_next() -> int:
	return 60 * level


func gain_xp(amount: int) -> Array[String]:
	if _party_gate():
		return []
	var before = _detached_persistent_state()
	var candidate = _detached_persistent_state()
	var messages: Array[String] = candidate._gain_xp_core(amount)
	var plan: Dictionary = PartyRoster.reconcile_growth(before, candidate, _party_payload())
	if not plan.ok:
		return []
	candidate._apply_party_plan(plan)
	_copy_persistent_from(candidate)
	return messages


func _gain_xp_core(amount: int) -> Array[String]:
	var messages: Array[String] = []
	xp += maxi(0, amount)
	while xp >= xp_to_next() and level < 99:
		xp -= xp_to_next()
		level += 1
		max_hp += 12
		attack += 3
		defense += 1
		hp = max_hp
		qi = max_qi
		messages.append("境界精进！升至 %d 级，气血与真气已恢复。" % level)
	if level >= 99:
		xp = mini(xp, xp_to_next() - 1)
	return messages


func heal_rest() -> void:
	if battle_active or _party_gate():
		return
	var plan: Dictionary = PartyRoster.rest_plan(self, _party_payload())
	if not plan.ok:
		return
	_apply_party_plan(plan)
	skill_cooldown = 0


func use_medicine() -> bool:
	if _party_gate():
		return false
	if medicine <= 0 or hp >= max_hp:
		return false
	medicine -= 1
	var healing: int = 55 if sect == "照野堂" else 45
	hp = mini(max_hp, hp + healing)
	return true


func choose_sect(id: String) -> void:
	if _party_gate():
		return
	# Joining is a one-time choice. Repeated UI events cannot stack bonuses.
	if sect != "未入门" or not SECTS.has(id):
		return
	sect = id
	sect_rank=1
	match id:
		"听潮阁":
			attack += 4
		"照野堂":
			max_hp += 24
			hp = mini(max_hp, hp + 24)
		"问石门":
			defense += 3


func school_art_ids() -> Array[String]:
	return Arts.available_for(sect)


func available_arts() -> Array[String]:
	return Advanced.available(self)


func can_learn_art(id: String) -> bool:
	return Advanced.can_learn(self, id)


func learn_art(id: String) -> bool:
	return Advanced.learn(self, id)


func eligible_sect_deeds() -> Array[String]:
	return Advanced.eligible_deeds(self)


func claim_sect_deed(id: String) -> bool:
	return Advanced.claim_deed(self, id)


func equip_art(id: String) -> bool:
	if battle_active or not available_arts().has(id):
		return false
	equipped_art = id
	# Equipping is pre-battle only and never resets cooldown, qi, or stats.
	return true


func art_description(id: String) -> String:
	var definition: Dictionary = Arts.definition(id)
	if definition.is_empty():
		return ""
	var damage: int = Advanced.direct_damage(definition, attack, art_rank(id))
	var effects: Array[String] = ["造成 %d 点伤害" % damage]
	if int(definition["healing"]) > 0:
		effects.append("恢复 %d 点气血" % int(definition["healing"]))
	if bool(definition["guard"]):
		effects.append("进入守势并清除破绽")
	if int(definition.get("weaken_amount", 0)) > 0:
		effects.append("卸劲：敌方基础伤害 -%d，持续 %d 次攻击" % [int(definition["weaken_amount"]), int(definition["weaken_strikes"])])
	var focus: int = Advanced.focus_damage(definition, attack)
	if focus > 0:
		effects.append("蓄锋：下一次平击额外 +%d" % focus)
	return "%s\n%s · 真气 %d · 调息 %d 回合 · %s" % [
		String(definition["description"]), "，".join(effects), int(definition["cost"]),
		int(definition["cooldown"]), Arts.rank_name(art_rank(id)),
	]


func active_art_cost() -> int:
	return int(_active_art_definition()["cost"])


func active_art_cooldown() -> int:
	return int(_active_art_definition()["cooldown"])


func art_rank(id: String) -> int:
	if not Arts.has_art(id):
		return 0
	var uses: int = _bounded_int(art_uses, id, 0, 0, 9999)
	return 3 if uses >= 15 else (2 if uses >= 5 else 1)


func _active_art_definition() -> Dictionary:
	return Arts.definition(equipped_art if available_arts().has(equipped_art) else Arts.BASE_ART)


func recruit_companion() -> bool:
	# Narrative eligibility is controlled by the healer dialogue in the scene.
	return _recruit_party_companion("shen")


func _recruit_party_companion(id: String) -> bool:
	if battle_active or _party_gate() or not id in ["shen", "tang", "qin"]:
		return false
	if (id == "shen" and companion_unlocked) or (id == "tang" and (tangqi_unlocked or tangqi_stage != 3)):
		return false
	if id == "qin" and (qin_unlocked or qin_stage != 3 or mist_stage != 4 or not mist_ending in Mist.ENDINGS):
		return false
	var candidate = _detached_persistent_state()
	if id == "shen":
		candidate.companion_unlocked = true
	elif id == "tang":
		candidate.tangqi_unlocked = true
	else:
		candidate.qin_stage = 4
		candidate.qin_unlocked = true
	var plan: Dictionary = PartyRoster.reconcile_growth(self, candidate, _party_payload())
	if not plan.ok:
		return false
	candidate._apply_party_plan(plan)
	# An invitation explicitly enrolls that actor and preserves other choices.
	var invited: Array = candidate.party_roster.duplicate()
	invited.append(id)
	# Preserve the legacy follower choice: Tang invitation foregrounds Tang;
	# recruiting Shen later keeps an existing selected companion. Membership
	# remains explicit and this choice never enrolls an unrelated actor.
	if id != "shen" or candidate.current_companion().is_empty():
		candidate.active_companion = {"shen": Companions.SHEN, "tang": Companions.TANG, "qin": Companions.QIN}[id]
	if not candidate.set_party_roster(invited):
		return false
	_copy_persistent_from(candidate)
	_companion_attack_count = 0
	return true


func current_companion() -> String:return Companions.active(self)
func available_companions() -> Array[String]:return Companions.available(self)
func select_companion(id:String) -> bool:return Companions.select(self,id)
func companion_description() -> String:return Companions.description(self)
func learn_internal_skill() -> bool:
	if battle_active or _party_gate() or internal_unlocked or level < 3 or not SECTS.has(sect):
		return false
	internal_unlocked = true
	return true


func learn_lightness() -> bool:return Lightness.learn(self)
func cross_reed_water(outward:bool) -> bool:return Lightness.cross(self,outward)
func discover_reed_islet() -> bool:return Lightness.discover(self)
func begin_shen_care() -> bool:return ShenCare.begin(self)
func consult_shen_patient() -> bool:return ShenCare.consult(self)
func inspect_shen_shelter() -> bool:return ShenCare.inspect(self)
func choose_shen_care(choice:String) -> bool:return ShenCare.choose(self,choice)
func post_shen_notice() -> bool:return ShenCare.post(self)
func begin_tangqi_quest() -> bool:return Companions.begin(self)
func recover_craft_notes() -> bool:return Companions.recover(self)
func resolve_tangqi_quest(choice:String) -> bool:return Companions.resolve(self,choice)
func recruit_tangqi() -> bool:return Companions.recruit(self)
func begin_qin_quest() -> bool:return QinCompanion.begin(self)
func inspect_qin_rope() -> bool:return QinCompanion.inspect_rope(self)
func arrange_qin_handoff() -> bool:return QinCompanion.arrange_handoff(self)
func recruit_qin() -> bool:return QinCompanion.invite(self)

func set_formation(id: String) -> bool:
	if _party_gate():
		return false
	if current_companion().is_empty() or not ["并肩", "护后"].has(id):
		return false
	if formation != id:
		formation = id
		_companion_attack_count = 0
	return true


func buy_equipment() -> bool:
	if _party_gate():
		return false
	if equipment != "旧铁剑" or coins < 45:
		return false
	coins -= 45
	equipment = "青钢剑"
	attack += 4
	return true


func current_region_name() -> String:
	if map_id=="heting":return "鹤汀埠"
	return "雾竹坡" if map_id=="mistwood" else ("霜桥驿" if map_id=="frostbridge" else ("旧闸" if map_id == "sluice" else "青苇渡"))


func choose_side_route(choice: String) -> bool:
	if _party_gate():
		return false
	if not side_choice.is_empty() or side_stage != 0 or not ["rescue", "pursuit"].has(choice):
		return false
	side_choice = choice
	side_stage = 1
	return true


func find_side_clue(id: String) -> bool:
	if _party_gate():
		return false
	if side_stage != 1 or side_choice.is_empty() or not ["boatman", "ledger"].has(id) or side_found.has(id):
		return false
	side_found.append(id)
	side_clues = side_found.size()
	if side_clues == 2:
		side_stage = 2
	return true


func finish_side_quest() -> bool:
	if _party_gate():
		return false
	if side_stage != 2 or side_reward_claimed or side_clues != 2 or not ["rescue", "pursuit"].has(side_choice):
		return false
	side_reward_claimed = true
	side_stage = 3
	coins += 45
	gain_xp(80)
	if side_choice == "rescue":
		medicine += 2
	else:
		coins += 20
	return true


func start_battle(kind: String = "story") -> void:
	# Historical direct model API retained for old fixtures only; unknown IDs reject.
	if kind not in UnifiedEncounters.IDS and kind != "spar": return
	if _party_gate():
		return
	# Group encounters have their own transaction and one-time settlement path.
	if kind=="heting_receipt":return
	if kind=="mist_scout" and (mist_stage!=1 or not mist_approach.is_empty()):return
	if kind=="mist_keeper" and mist_stage!=2:return
	if kind=="sect_trial" and not can_take_sect_trial():return
	if battle_active:
		return
	_clear_battle()
	battle_kind = "training" if kind == "spar" else kind
	match battle_kind:
		"training":
			enemy_name = "蒲横 · 切磋"
			enemy_max_hp = 64
		"sluice_scout":
			enemy_name = "旧闸巡哨"
			enemy_max_hp = 85
			enemy_base_attack = 11
			enemy_strong_attack = 22
		"mist_scout":
			enemy_name="巡坡斥候";enemy_max_hp=155
		"mist_keeper":
			enemy_name="听雨关守令使";enemy_max_hp=300
		"sect_trial":
			enemy_name="岑远 · 代试游师"
			enemy_max_hp=maxi(180,attack*4+30)
			enemy_base_attack=18
			enemy_strong_attack=30
		"archive_boss":
			enemy_name="韩砚 · 仓门执事"
			enemy_max_hp=205
			enemy_base_attack=17
			enemy_strong_attack=31
		"sluice_boss":
			enemy_name = "河帮闸首"
			enemy_max_hp = 150
			enemy_base_attack = 16
			enemy_strong_attack = 28
		_:
			enemy_name = "蒲横 · 河帮执事"
			enemy_max_hp = 96
	enemy_hp = enemy_max_hp
	battle_active = true
	_update_intent()
	battle_log.append("%s拦住去路。看清招式，再作应对。" % enemy_name)


func battle_action(action: String) -> Dictionary:
	if _party_gate():
		return _result(false, "独立出战交锋须由当前角色行动。")
	if battle_kind=="heting_receipt":
		return _result(false,"复签交锋需要先选定当前目标。")
	if not battle_active:
		return _result(false, "当前没有战斗。")
	# Validate before changing cooldowns, turn count, resources, or enemy state.
	if not ["attack", "skill", "guard", "item", "flee"].has(action):
		return _result(false, "招式无效。")
	if action == "skill":
		if skill_cooldown > 0:
			return _result(false, "%s尚需调息 %d 回合。" % [String(_active_art_definition()["name"]), skill_cooldown])
		if qi < active_art_cost():
			return _result(false, "真气不足：%s需要 %d 点真气。" % [String(_active_art_definition()["name"]), active_art_cost()])
	if action == "item":
		if medicine <= 0:
			return _result(false, "行囊中没有回春散了。")
		if hp >= max_hp:
			return _result(false, "气血充盈，无需用药。")

	var messages: Array[String] = []
	guard = false
	if action != "skill":
		skill_cooldown = maxi(0, skill_cooldown - 1)
	match action:
		"attack":
			var focus: int = focused_damage
			var damage: int = attack + focus
			focused_damage = 0
			damage=deal_enemy_damage(damage)
			qi = mini(max_qi, qi + 2)
			if focus > 0:
				messages.append("你使出平击，基础 %d + 蓄锋 %d，经敌方架势后造成 %d 点伤害，凝聚 2 点真气。" % [attack, focus, damage])
			else:
				messages.append("你使出平击，造成 %d 点伤害，凝聚 2 点真气。" % damage)
		"skill":
			var definition: Dictionary = _active_art_definition()
			var art_id: String = String(definition["id"])
			var rank_before: int = art_rank(art_id)
			if battle_kind=="sect_trial" and art_id==sect_art():_trial_art_used=true
			qi -= int(definition["cost"])
			skill_cooldown = int(definition["cooldown"])
			var damage: int = Advanced.direct_damage(definition, attack, rank_before)
			damage=deal_enemy_damage(damage)
			messages.append("%s！造成 %d 点伤害。" % [art_id, damage])
			if int(definition["healing"]) > 0:
				var before_hp: int = hp
				hp = mini(max_hp, hp + int(definition["healing"]))
				if battle_kind=="sect_trial" and art_id==sect_art():_trial_healing+=hp-before_hp
				messages.append("%s续接伤脉，恢复 %d 点气血。" % [art_id, hp - before_hp])
			if bool(definition["guard"]):
				guard = true
				exposed_turns = 0
				messages.append("%s稳住架势：进入守势、清除破绽，抵御本回合的七成伤害。" % art_id)
			Advanced.apply_effects(self, definition, messages)
			art_uses[art_id] = mini(9999, _bounded_int(art_uses, art_id, 0, 0, 9999) + 1)
			if art_rank(art_id) > rank_before:
				messages.append("%s熟练精进，已达%s。" % [art_id, Arts.rank_name(art_rank(art_id))])
		"guard":
			guard = true
			if exposed_turns > 0:
				messages.append("你稳住架势，化解了破绽。")
			exposed_turns = 0
			qi = mini(max_qi, qi + 1)
			messages.append("你收势守中，凝聚 1 点真气，抵御本回合的七成伤害。")
		"item":
			var before_hp: int = hp
			use_medicine()
			messages.append("你服下回春散，恢复 %d 点气血。" % (hp - before_hp))
		"flee":
			turn += 1
			battle_active = false
			exposed_turns = 0
			Advanced.clear_effects(self)
			enemy_intent = "已脱离战斗"
			messages.append("你收势退开，暂避锋芒。")
			return _finish_result(messages, true, false)

	if not current_companion().is_empty() and formation=="并肩" and action in ["attack","skill"]:
		Companions.assist(self,messages)
	turn += 1
	if enemy_hp <= 0:
		battle_active = false
		exposed_turns = 0
		guard = false
		Advanced.clear_effects(self)
		enemy_intent = "已被击败"
		victories += 1
		var reward_xp: int = 30 if battle_kind == "training" else 60
		var reward_coins: int = 12 if battle_kind == "training" else 26
		if battle_kind=="mist_scout":
			reward_xp=40;reward_coins=18;Mist.access(self,"duel")
		elif battle_kind=="mist_keeper":
			reward_xp=90;reward_coins=48;Mist.victory(self)
		elif battle_kind == "sluice_scout":
			reward_xp = 25
			reward_coins = 14
		elif battle_kind=="sect_trial":
			reward_xp=45
			reward_coins=20
			sect_trial_won=Sects.met(self)
			messages.append("门中考法已验明。" if sect_trial_won else "切磋虽胜，门中考法尚未验明。")
		elif battle_kind == "archive_boss":
			reward_xp=80
			reward_coins=40
		elif battle_kind in ["sluice_boss","archive_boss"]:
			reward_xp = 70
			reward_coins = 35
		coins += reward_coins
		messages.append("你胜了！获得 %d 点阅历、%d 文钱。" % [reward_xp, reward_coins])
		messages.append_array(gain_xp(reward_xp))
		return _finish_result(messages, true, true)

	# Intent describes the next accepted turn, including each enemy's own damage.
	if battle_kind=="sect_trial" and guard and action=="skill" and equipped_art==sect_art() and turn%2==0:_trial_guarded_heavy=true
	var enemy_phase=Patterns.phase(battle_kind,turn-1)
	var raw_damage: int = int(enemy_phase.damage) if not enemy_phase.is_empty() else (enemy_base_attack if turn % 2 == 1 else enemy_strong_attack)
	var without_weaken: int = maxi(1, raw_damage - defense)
	var weaken: int = enemy_weaken_amount if enemy_weaken_strikes > 0 else 0
	var incoming: int = maxi(1, raw_damage - defense - weaken)
	if enemy_weaken_strikes > 0:
		messages.append("卸劲使本次基础伤害实际减少 %d 点。" % (without_weaken - incoming))
	if exposed_turns > 0:
		incoming += 3
		exposed_turns -= 1
		messages.append("破绽未收，本次额外受到 3 点伤害。")
	if guard:
		incoming = maxi(1, int(ceil(float(incoming) * 0.3)))
	if not current_companion().is_empty() and formation=="护后":
		incoming=Companions.cover(self,incoming,messages)
	hp = maxi(0, hp - incoming)
	Advanced.consume_weaken(self)
	var move_name: String = "疾刃" if turn % 2 == 1 else "蓄势重斩"
	if battle_kind in ["sluice_boss","archive_boss"]:
		move_name = "闸刀横扫" if turn % 2 == 1 else "碎潮重劈"
	if not enemy_phase.is_empty():move_name=enemy_phase.name
	messages.append("%s使出%s，你受到 %d 点伤害。" % [enemy_name, move_name, incoming])
	if ((battle_kind in ["sluice_boss","archive_boss"] and turn % 2 == 0) or bool(enemy_phase.get("exposes",false))) and not guard and hp > 0:
		exposed_turns = 2
		messages.append(move_name+"震乱了你的架势：破绽 2 回合。使用守势可立即化解。")
	guard = false
	if hp <= 0:
		battle_active = false
		exposed_turns = 0
		Advanced.clear_effects(self)
		enemy_intent = "已结束"
		var lost_coins: int = mini(coins, 8)
		coins -= lost_coins
		hp = max_hp
		qi = maxi(qi, 2)
		skill_cooldown = 0
		messages.append("你力竭败退，遗落 %d 文钱。附近行旅将你救起，气血已恢复。" % lost_coins)
		return _finish_result(messages, true, false)
	_update_intent()
	return _finish_result(messages, false, false)


func quest_title() -> String:
	match quest_stage:
		0: return "渡灯失窃"
		1: return "芦岸寻药"
		2: return "一叶为证"
		3: return "码头问刀"
		4: return "灯下真相"
		5: return "江湖初择"
		_: return "青苇渡 · 余响"


func quest_hint() -> String:
	match quest_stage:
		0: return "与渡口长者交谈，打听渡灯失窃之事。"
		1: return "到东侧芦岸采一株青穗草，帮药师救治受伤的船工。"
		2: return "将青穗草交给药师，听取船工留下的证言。"
		3: return "前往南侧码头，击败河帮执事蒲横，夺回渡灯与账册。"
		4: return "带着账册回见长者，揭开河帮借失灯勒索过渡钱的真相。"
		5: return "与长者决定渡灯的去向，再选择一门江湖传承。"
		_: return "渡灯重新照亮青苇渡。还可与游侠切磋，或继续探索。"


func to_dict() -> Dictionary:
	# Only JSON-safe values are persisted. Battles are deliberately transient.
	return {
		"player_name": player_name, "level": level, "xp": xp, "coins": coins,
		"hp": hp, "max_hp": max_hp, "qi": qi, "max_qi": max_qi,
		"attack": attack, "defense": defense, "medicine": medicine,
		"herbs": herbs, "quest_stage": quest_stage, "sect": sect,
		"sect_rank":sect_rank,"sect_merit":sect_merit,"sect_trial_won":sect_trial_won,
		"ending": ending, "position": {"x": position.x, "y": position.y},
		"victories": victories, "companion_unlocked": companion_unlocked,
		"internal_unlocked": internal_unlocked,
		"lightness_unlocked":lightness_unlocked,"lightness_relics":lightness_relics.duplicate(),
		"shen_care_stage":shen_care_stage,"shen_care_choice":shen_care_choice,
		"qin_stage": qin_stage, "qin_unlocked": qin_unlocked,
		"tangqi_unlocked":tangqi_unlocked,"tangqi_stage":tangqi_stage,"tangqi_choice":tangqi_choice,"active_companion":current_companion(),
		"party_roster": party_roster.duplicate(), "party_resources": party_resources.duplicate(true),
		"formation": formation, "equipment": equipment,
		"heting_stage":heting_stage,"heting_bridge":heting_bridge,"heting_delivered":heting_delivered.duplicate(),
		"heting_cargo":heting_cargo,"heting_draft":heting_draft,"heting_ending":heting_ending,
		"receipt_stage":receipt_stage,
		"consignee_stage": consignee_stage, "consignee_observations": consignee_observations.duplicate(),
		"consignee_contributions": consignee_contributions.duplicate(), "consignee_draft": consignee_draft,
		"consignee_cargo_location": consignee_cargo_location, "consignee_ending": consignee_ending,
		"capstone_stage": capstone_stage, "capstone_draft": capstone_draft, "capstone_ending": capstone_ending,
		"mist_stage":mist_stage,"mist_gauges":mist_gauges.duplicate(),"mist_approach":mist_approach,"mist_ending":mist_ending,
		"chapter_two_stage":chapter_two_stage,"archive_clues":archive_clues.duplicate(),"seal_sequence":seal_sequence.duplicate(),"chapter_two_ending":chapter_two_ending,"bridge_repaired":bridge_repaired,
		"armor":armor, "resources":resources.duplicate(true), "gathered_nodes":gathered_nodes.duplicate(),
		"map_id": map_id, "side_stage": side_stage, "side_choice": side_choice,
		"side_clues": side_clues, "side_reward_claimed": side_reward_claimed,
		"side_found": side_found.duplicate(),
		"equipped_art": equipped_art, "art_uses": art_uses.duplicate(true),
		"learned_arts": learned_arts.duplicate(), "claimed_deeds": claimed_deeds.duplicate(),
	}


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game(path: String = SAVE_PATH) -> Error:
	if path.is_empty():
		return ERR_INVALID_PARAMETER
	# This fight is transient. Preserve the pre-entry checkpoint until its
	# accepted action is presented and its terminal outcome has settled.
	if _party_gate() or (battle_active and battle_kind=="heting_receipt"):return ERR_BUSY
	var data: Dictionary = to_dict()
	if not _stage_save_data(data, SAVE_VERSION).ok:
		return ERR_FILE_CORRUPT
	var temporary: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": SAVE_VERSION, "player": data}, "\t"))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return write_error
	var rename_error: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)
	)
	if rename_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
	return rename_error


func load_game(path: String = SAVE_PATH) -> Error:
	if _party_gate() or (battle_active and battle_kind == "heting_receipt"):
		return ERR_BUSY
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	# Both file loading and transfer inspect the same detached candidate. Reading
	# bytes rather than text also lets transfers preserve the original document.
	var length: int = file.get_length()
	if length > MAX_SAVE_BYTES:
		file.close()
		return ERR_FILE_CORRUPT
	var bytes: PackedByteArray = file.get_buffer(length)
	file.close()
	if bytes.size() != length:
		return ERR_FILE_CANT_READ
	var inspected: Dictionary = inspect_save_bytes(bytes)
	if not inspected.ok:
		return inspected.error
	_copy_persistent_from(inspected.state)
	_clear_battle()
	return OK


func inspect_save_bytes(bytes: PackedByteArray) -> Dictionary:
	# Read-only, shared schema/semantic validation. The returned state is a new
	# detached candidate, never this instance. Preserve Godot JSON's historical
	# BOM handling, last-key-wins duplicates, and permissive trailing commas.
	# Transfer's untrusted-byte envelope additionally bounds UTF-8 and nesting.
	if bytes.is_empty() or bytes.size() > MAX_SAVE_BYTES:
		return {"ok": false, "error": ERR_FILE_CORRUPT}
	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(bytes.get_string_from_utf8())
	if parse_error != OK or not json.data is Dictionary:
		return {"ok": false, "error": ERR_FILE_CORRUPT}
	var document: Dictionary = json.data
	if not _is_number(document.get("version")):
		return {"ok": false, "error": ERR_FILE_CORRUPT}
	if not [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, float(SAVE_VERSION)].has(float(document["version"])):
		return {"ok": false, "error": ERR_FILE_UNRECOGNIZED}
	if not document.get("player") is Dictionary:
		return {"ok": false, "error": ERR_FILE_CORRUPT}
	var staged: Dictionary = _stage_save_data(document["player"], int(document["version"]))
	if not staged.ok:
		return {"ok": false, "error": ERR_FILE_CORRUPT}
	return {"ok": true, "error": OK, "state": staged.state, "version": int(document["version"])}


func _stage_save_data(data: Dictionary, version: int) -> Dictionary:
	if not _valid_save_data(data, version):
		return {"ok": false}
	var candidate = get_script().new()
	candidate._restore_save_candidate(data, version)
	# Pass RAW data: schema12 hero HP0 must fail before legacy HP clamping.
	var plan: Dictionary = PartyRoster.load_plan(candidate, data, version)
	if not plan.ok:
		return {"ok": false}
	candidate._apply_party_plan(plan)
	if version >= 12:
		var normalized: Dictionary = candidate.to_dict()
		var original: Dictionary = data.duplicate(true)
		# Only an absent legacy chapter bundle receives neutral defaults. A
		# present bundle remains strictly validated and compared, never dropped.
		if version < 14 and not data.has("consignee_stage"):
			for key: String in Consignee.FIELDS:
				normalized.erase(key)
		if version < 15 and not data.has("capstone_stage"):
			for key: String in Capstone.FIELDS:
				normalized.erase(key)
		if version == 12:
			normalized.erase("internal_unlocked")
			original.erase("internal_unlocked")
		if not _same_save_value(normalized, original):
			return {"ok": false}
	return {"ok": true, "state": candidate}


func _restore_save_candidate(data: Dictionary, version: int = SAVE_VERSION) -> void:
	# This method is used only on a fresh detached candidate, never live state.
	internal_unlocked = bool(data.get("internal_unlocked", false)) if version >= 13 else false
	player_name = String(data.get("player_name", "无名客")).strip_edges().left(18)
	if player_name.is_empty():
		player_name = "无名客"
	level = _bounded_int(data, "level", 1, 1, 99)
	xp = _bounded_int(data, "xp", 0, 0, xp_to_next() - 1)
	coins = _bounded_int(data, "coins", 24, 0, 999999)
	max_hp = _bounded_int(data, "max_hp", 100, 1, 9999)
	hp = _bounded_int(data, "hp", max_hp, 1, max_hp)
	max_qi = _bounded_int(data, "max_qi", 6, 3, 99)
	qi = _bounded_int(data, "qi", 2, 0, max_qi)
	attack = _bounded_int(data, "attack", 16, 1, 999)
	defense = _bounded_int(data, "defense", 4, 0, 999)
	medicine = _bounded_int(data, "medicine", 3, 0, 999)
	herbs = _bounded_int(data, "herbs", 0, 0, 999)
	quest_stage = _bounded_int(data, "quest_stage", 0, 0, 6)
	victories = _bounded_int(data, "victories", 0, 0, 999999)
	companion_unlocked = bool(data.get("companion_unlocked", false))
	var saved_formation: String = String(data.get("formation", "并肩"))
	formation = saved_formation if ["并肩", "护后"].has(saved_formation) else "并肩"
	var saved_equipment: String = String(data.get("equipment", "旧铁剑"))
	equipment = saved_equipment if saved_equipment in ["青钢剑","精锻青钢剑"] else "旧铁剑"
	armor = "轻纱内甲" if data.get("armor","")=="轻纱内甲" else "粗布行衣"
	var saved_resources:Dictionary=data.get("resources",{})
	for id in Items.material_ids(): resources[id]=_bounded_int(saved_resources,id,0,0,9999)
	for id in data.get("gathered_nodes",[]):
		if Items.GATHER_NODES.has(id) and not gathered_nodes.has(id): gathered_nodes.append(id)
	map_id=String(data.get("map_id","qingwei")) if data.get("map_id","") in ["qingwei","sluice","frostbridge","mistwood","heting"] else "qingwei"
	Chapter.restore(self,data)
	Mist.restore(self,data)
	Heting.restore(self,data)
	Consignee.restore(self, data)
	Capstone.restore(self, data)
	receipt_stage=_bounded_int(data,"receipt_stage",0,0,3)
	Companions.restore(self,data)
	qin_stage = int(data.get("qin_stage", 0)) if version >= 12 else 0
	qin_unlocked = bool(data.get("qin_unlocked", false)) if version >= 12 else false
	ShenCare.restore(self,data)
	Lightness.restore(self,data)
	_restore_side_progress(data)
	var saved_sect: String = String(data.get("sect", "未入门"))
	sect = saved_sect if SECTS.has(saved_sect) else "未入门"
	sect_rank=_bounded_int(data,"sect_rank",1,1,2) if sect!="未入门" else 0
	sect_merit=_bounded_int(data,"sect_merit",0,0,9999)
	sect_trial_won=bool(data.get("sect_trial_won",false)) or sect_rank==2
	learned_arts = Advanced.ordered_arts(data.get("learned_arts", []))
	claimed_deeds = Advanced.ordered_deeds(data.get("claimed_deeds", []))
	# Early version-one builds saved a chosen sect at the pre-completion stage.
	if quest_stage == 5 and sect != "未入门":
		quest_stage = 6
	art_uses = {Arts.BASE_ART: 0}
	var saved_uses: Dictionary = data.get("art_uses", {})
	for art_id: String in Arts.all_ids():
		if saved_uses.has(art_id) and (not Advanced.is_advanced(art_id) or learned_arts.has(art_id)):
			art_uses[art_id] = _bounded_int(saved_uses, art_id, 0, 0, 9999)
	var saved_art: String = String(data.get("equipped_art", Arts.BASE_ART))
	equipped_art = saved_art if available_arts().has(saved_art) else Arts.BASE_ART
	ending = String(data.get("ending", "")).left(120)
	var saved_position: Dictionary = data.get("position", {"x": 460, "y": 430})
	position = Vector2(
		clampf(float(saved_position.get("x", 460)), 0.0, 10000.0),
		clampf(float(saved_position.get("y", 430)), 0.0, 10000.0)
	)


func _valid_save_data(data: Dictionary, version: int = SAVE_VERSION) -> bool:
	if version >= 12 and not _valid_schema12_core(data, version):
		return false
	# All original version-one fields are required. Only later feature fields
	# receive compatibility defaults, so truncated saves cannot strand a quest.
	for key: String in ["player_name", "level", "xp", "coins", "hp", "max_hp",
		"qi", "max_qi", "attack", "defense", "medicine", "herbs", "quest_stage",
		"sect", "ending", "position", "victories"]:
		if not data.has(key):
			return false
	for key: String in ["level", "xp", "coins", "hp", "max_hp", "qi", "max_qi",
		"attack", "defense", "medicine", "herbs", "quest_stage", "victories", "side_stage", "side_clues", "chapter_two_stage", "sect_rank", "sect_merit", "tangqi_stage", "mist_stage"]:
		if data.has(key) and not _is_number(data[key]):
			return false
	for key: String in ["player_name", "sect", "ending", "formation", "equipment", "map_id", "side_choice", "equipped_art", "armor", "chapter_two_ending", "tangqi_choice", "active_companion", "mist_approach", "mist_ending"]:
		if data.has(key) and not data[key] is String:
			return false
	var saved_sect: String = String(data.get("sect", "未入门"))
	if not SECTS.has(saved_sect):
		saved_sect = "未入门"
	var saved_rank: int = _bounded_int(data, "sect_rank", 1, 1, 2) if saved_sect != "未入门" else 0
	if not Advanced.valid_save(data, version, saved_sect, saved_rank):
		return false
	if not Mist.valid(data,version):return false
	if not Heting.valid(data,version):return false
	if not Receipt.valid(data,version):return false
	if not Consignee.valid(data, version): return false
	if not Capstone.valid(data, version): return false
	if not Companions.valid(data):return false
	if version >= 12 and not _valid_qin_progress(data):return false
	if not ShenCare.valid(data,version):return false
	if not Lightness.valid(data,version):return false
	if version >= 13:
		if not data.get("internal_unlocked") is bool: return false
		if data.internal_unlocked and (float(data.get("level", 1)) < 3 or not SECTS.has(String(data.get("sect", "")))): return false
	if data.has("companion_unlocked") and not data["companion_unlocked"] is bool:
		return false
	if data.has("side_reward_claimed") and not data["side_reward_claimed"] is bool:
		return false
	if data.has("art_uses"):
		if not data["art_uses"] is Dictionary:
			return false
		for art_id: Variant in data["art_uses"]:
			if not art_id is String or not _is_number(data["art_uses"][art_id]):
				return false
	if data.has("side_found"):
		if not data["side_found"] is Array:
			return false
		for clue: Variant in data["side_found"]:
			if not clue is String:
				return false
	if data.has("sect_trial_won") and not data["sect_trial_won"] is bool:return false
	if data.has("bridge_repaired") and not data["bridge_repaired"] is bool:return false
	for key in ["archive_clues","seal_sequence"]:
		if data.has(key) and not data[key] is Array:return false
	for id in data.get("archive_clues",[]):
		if not id is String:return false
	for index in data.get("seal_sequence",[]):
		if not _is_number(index):return false
	if _bounded_int(data,"chapter_two_stage",0,0,4)==4 and not ["open_records","protect_witness"].has(data.get("chapter_two_ending","")):return false
	if data.has("resources"):
		if not data["resources"] is Dictionary: return false
		for id in data["resources"]:
			if not id is String or not _is_number(data["resources"][id]): return false
	if data.has("gathered_nodes"):
		if not data["gathered_nodes"] is Array: return false
		for id in data["gathered_nodes"]:
			if not id is String: return false
	if data.has("position"):
		if not data["position"] is Dictionary:
			return false
		var coordinates: Dictionary = data["position"]
		for axis: String in ["x", "y"]:
			if coordinates.has(axis) and not _is_number(coordinates[axis]):
				return false
	# Delivery requires the collected herb. Reject inconsistent saves without
	# touching active progress rather than loading an unwinnable chapter.
	if _bounded_int(data, "quest_stage", 0, 0, 6) == 2 and _bounded_int(data, "herbs", 0, 0, 999) < 1:
		return false
	if bool(data.get("side_reward_claimed", false)) or _bounded_int(data, "side_stage", 0, 0, 3) == 3:
		if not ["rescue", "pursuit"].has(data.get("side_choice", "")):
			return false
	return true


func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


func _restore_side_progress(data: Dictionary) -> void:
	var saved_choice: String = String(data.get("side_choice", ""))
	side_choice = saved_choice if ["rescue", "pursuit"].has(saved_choice) else ""
	side_found.clear()
	for clue: Variant in data.get("side_found", []):
		if ["boatman", "ledger"].has(clue) and not side_found.has(clue):
			side_found.append(String(clue))
	# Treat either completion marker as authoritative to prevent claiming again
	# after loading a damaged but recoverable save. Never award during loading.
	side_reward_claimed = bool(data.get("side_reward_claimed", false)) or _bounded_int(data, "side_stage", 0, 0, 3) == 3
	if side_reward_claimed:
		for clue: String in ["boatman", "ledger"]:
			if not side_found.has(clue):
				side_found.append(clue)
		side_clues = 2
		side_stage = 3
	elif side_choice.is_empty():
		side_found.clear()
		side_clues = 0
		side_stage = 0
	else:
		side_clues = side_found.size()
		side_stage = 2 if side_clues == 2 else 1


func _bounded_int(data: Dictionary, key: String, fallback: int, low: int, high: int) -> int:
	# Clamp before converting to int so huge JSON numbers cannot overflow.
	return int(clampf(float(data.get(key, fallback)), float(low), float(high)))


func _clear_battle() -> void:
	party_battle_epoch += 1
	party_session = null
	party_settlement = {}
	_party_pending_token = -1
	_party_encounter = ""
	_party_sluice_entry = {}
	_party_archive_entry = {}
	_party_extra_entry = {}
	_party_practice_before = {}
	_party_consignee_identity = {}
	_party_capstone_identity = {}
	receipt_battle_epoch+=1
	receipt_session=null
	receipt_settlement={}
	enemy_name = ""
	enemy_hp = 0
	enemy_max_hp = 0
	enemy_intent = ""
	battle_active = false
	battle_kind = "story"
	turn = 0
	guard = false
	battle_log.clear()
	skill_cooldown = 0
	enemy_base_attack = 9
	enemy_strong_attack = 19
	exposed_turns = 0
	_companion_attack_count = 0
	Advanced.clear_effects(self)
	_trial_art_used=false;_trial_healing=0;_trial_guarded_heavy=false


func begin_receipt() -> bool:
	return Receipt.begin(self)


func compare_receipt() -> bool:
	return Receipt.compare(self)


func start_receipt_battle() -> bool:
	if _party_gate():return false
	if receipt_stage!=1 or not Receipt.can_begin(self):return false
	var candidate=ReceiptCombat.new()
	if not candidate.configure(self):return false
	_clear_battle()
	receipt_session=candidate
	battle_kind="heting_receipt"
	battle_active=true
	enemy_name="鹤汀截签人"
	return true


func receipt_battle_snapshot() -> Dictionary:
	return receipt_session.snapshot() if receipt_session!=null else {}


func select_receipt_target(id:String) -> bool:
	return battle_active and battle_kind=="heting_receipt" and receipt_session!=null and receipt_session.select_target(id)


func cycle_receipt_target() -> bool:
	return battle_active and battle_kind=="heting_receipt" and receipt_session!=null and receipt_session.cycle_target()


func receipt_battle_action(action:String) -> Dictionary:
	if not battle_active or battle_kind!="heting_receipt" or receipt_session==null:
		return {"ok":false,"accepted":false,"reason":"当前没有复签交锋。","token":-1,"epoch":receipt_battle_epoch}
	var tx:Dictionary=receipt_session.accept_action(action)
	if not bool(tx.get("accepted",false)):return tx
	var after:Dictionary=tx.after
	hp=int(after.hp);qi=int(after.qi);medicine=int(after.medicine)
	art_uses=after.art_uses.duplicate(true)
	turn=int(after.turn);skill_cooldown=int(after.skill_cooldown)
	battle_log.assign(receipt_session.battle_log)
	# Nested values remain the model's immutable snapshots. The epoch is owned
	# here so a stale presentation callback cannot settle a later attempt.
	var decorated:Dictionary={}
	for key in tx:decorated[key]=tx[key]
	decorated["epoch"]=receipt_battle_epoch
	decorated.make_read_only()
	return decorated


func finish_receipt_presentation(epoch:int,token:int) -> bool:
	if epoch!=receipt_battle_epoch or not battle_active or battle_kind!="heting_receipt" or receipt_session==null:return false
	if not receipt_session.complete_presentation(token):return false
	if receipt_session.active:return true
	# Clear the active gate before the finite story rules settle. A second
	# callback will fail above even if the subsequent disk write fails.
	battle_active=false
	skill_cooldown=0
	var outcome:String=String(receipt_session.outcome)
	var coins_before:int=coins
	var level_before:int=level
	var awarded:bool=false
	if outcome=="win":
		awarded=Receipt.settle_victory(self)
	elif outcome=="defeat":
		coins=maxi(0,coins-mini(coins,8))
		hp=max_hp;qi=maxi(qi,2)
		map_id="heting";position=Vector2(230,735)
	receipt_settlement={"outcome":outcome,"awarded":awarded,"coin_change":coins-coins_before,"level_before":level_before,"level_after":level,"stage":receipt_stage}
	receipt_settlement.make_read_only()
	return true


func _update_intent() -> void:
	var pattern_intent=Patterns.intent(battle_kind,turn)
	if not pattern_intent.is_empty():
		enemy_intent=pattern_intent;return
	if battle_kind in ["sluice_boss","archive_boss"]:
		enemy_intent = "闸刀横扫 · 快击（%d）" % enemy_base_attack if turn % 2 == 0 else "碎潮重劈 · 重击（%d）+ 破绽 2 回合" % enemy_strong_attack
	else:
		enemy_intent = "疾刃 · 轻击（%d）" % enemy_base_attack if turn % 2 == 0 else "蓄势重斩 · 重击（%d）" % enemy_strong_attack


func _result(valid: bool, message: String, finished: bool = false, won: bool = false) -> Dictionary:
	return {"valid": valid, "message": message, "finished": finished, "won": won, "log": []}


func _finish_result(messages: Array[String], finished: bool, won: bool) -> Dictionary:
	battle_log.append_array(messages)
	while battle_log.size() > 48:
		battle_log.pop_front()
	return {
		"valid": true, "message": "\n".join(messages), "finished": finished,
		"won": won, "log": messages,
	}

func buy_material(id:String,quantity:int=1) -> bool:
	return Economy.buy(self,id,quantity)

func sell_material(id:String,quantity:int=1) -> bool:
	return Economy.sell(self,id,quantity)

func can_craft(id:String) -> bool:
	return Economy.can_craft(self,id)

func craft(id:String) -> Dictionary:
	return Economy.craft(self,id)

func gather_resource(id:String) -> Dictionary:
	return Economy.gather(self,id)

func begin_chapter_two() -> bool:
	if _party_gate(): return false
	return Chapter.begin(self)
func add_archive_clue(id:String) -> bool:
	if _party_gate(): return false
	return Chapter.clue(self,id)
func try_seal(index:int) -> Dictionary:
	if _party_gate():
		return {"valid":false,"complete":false,"message":"交锋中不能转动封印。"}
	return Chapter.seal(self,index)
func mark_archive_victory() -> bool:
	if _party_gate(): return false
	return Chapter.victory(self)
func resolve_chapter_two(choice:String) -> bool:
	if _party_gate() or not _stage_save_data(to_dict(), SAVE_VERSION).ok:
		return false
	var candidate = _detached_persistent_state()
	if not Chapter.resolve(candidate, choice):
		return false
	candidate.coins = mini(999999, candidate.coins)
	if not _stage_save_data(candidate.to_dict(), SAVE_VERSION).ok:
		return false
	_copy_persistent_from(candidate)
	return true
func repair_bridge() -> bool:
	if _party_gate(): return false
	return Chapter.repair_bridge(self)

func sect_art() -> String:return Sects.art(self)
func sect_trial_requirement() -> String:return Sects.requirement(self)
func can_take_sect_trial() -> bool:return Sects.eligible(self) and not battle_active
func complete_sect_trial() -> bool:
	if _party_gate(): return false
	return Sects.complete(self)
func sect_rank_name() -> String:return ["未入门","门下弟子","内门弟子"][sect_rank]

func deal_enemy_damage(amount:int,support:bool=false)->int:
	var actual=Patterns.outgoing(battle_kind,turn,amount,support)
	enemy_hp=maxi(0,enemy_hp-actual)
	return actual
func enemy_strike_is_heavy()->bool:
	var phase=Patterns.phase(battle_kind,turn-1)
	return bool(phase.heavy) if not phase.is_empty() else turn%2==0
func begin_mistwood()->bool:return Mist.begin(self)
func obtain_mist_access(route:String)->bool:return Mist.access(self,route)
func record_mist_gauge(id:String)->bool:return Mist.record(self,id)
func resolve_mistwood(choice:String)->bool:return Mist.resolve(self,choice)

func begin_heting()->bool:return Heting.begin(self)
func set_heting_bridge(side:String)->bool:return Heting.set_bridge(self,side)
func available_heting_cargo(source:String)->Array[String]:return Heting.available_cargo(self,source)
func take_heting_cargo(id:String)->bool:return Heting.take_cargo(self,id)
func park_heting_cargo()->bool:return Heting.park_cargo(self)
func deliver_heting_base(receiver:String)->bool:return Heting.deliver_base(self,receiver)
func choose_heting_plan(id:String)->bool:return Heting.choose_plan(self,id)
func finish_heting_delivery(receiver:String,expected_plan:String)->bool:return Heting.finish_delivery(self,receiver,expected_plan)


## Schema12 actor-party boundary. Callers choose a roster outside combat, save a
## pre-entry checkpoint, then acknowledge each accepted presentation token.
func _party_gate() -> bool:
	return party_session != null and (battle_active or _party_pending_token >= 0)


func _party_payload() -> Dictionary:
	return {"party_roster": party_roster.duplicate(), "party_resources": party_resources.duplicate(true)}


func _apply_party_plan(plan: Dictionary) -> void:
	party_roster.assign(plan.payload.party_roster)
	party_resources = plan.payload.party_resources.duplicate(true)
	hp = int(plan.hero_resources.hp)
	qi = int(plan.hero_resources.qi)
	active_companion = active_party_companion()


func _copy_persistent_from(source) -> void:
	for key: String in source.to_dict():
		if key == "position":
			position = source.position
			continue
		var value: Variant = source.get(key)
		# assign preserves the destination's typed Array declaration.
		if value is Array:
			get(key).assign(value)
		else:
			set(key, value.duplicate(true) if value is Dictionary else value)


func _detached_persistent_state():
	var candidate = get_script().new()
	candidate._copy_persistent_from(self)
	return candidate


func active_party_companion() -> String:
	var chosen_id: String = {Companions.SHEN: "shen", Companions.TANG: "tang", Companions.QIN: "qin"}.get(active_companion, "")
	if party_roster.has(chosen_id) and ((chosen_id == "shen" and companion_unlocked) or (chosen_id == "tang" and tangqi_unlocked) or (chosen_id == "qin" and qin_recruited())):
		return active_companion
	for id: String in party_roster:
		if id == "shen" and companion_unlocked:
			return Companions.SHEN
		if id == "tang" and tangqi_unlocked:
			return Companions.TANG
		if id == "qin" and qin_recruited():
			return Companions.QIN
	return ""


func set_party_roster(ids: Variant) -> bool:
	if battle_active or _party_gate():
		return false
	var plan: Dictionary = PartyRoster.select_roster(self, _party_payload(), ids)
	if not plan.ok:
		return false
	_apply_party_plan(plan)
	_companion_attack_count = 0
	return true


func party_resource_snapshot() -> Dictionary:
	var plan: Dictionary = PartyRoster.validate_payload(self, _party_payload())
	if not plan.ok:
		return PartyCatalog.immutable({"ok": false, "reason": plan.reason, "actors": []})
	var all_ids: Array = ["hero"]
	var all_resources: Dictionary = party_resources.duplicate(true)
	all_resources["hero"] = {"hp": hp, "qi": qi}
	if companion_unlocked:
		all_ids.append("shen")
	if tangqi_unlocked:
		all_ids.append("tang")
	if qin_recruited():
		all_ids.append("qin")
	var built: Dictionary = PartyCatalog.build_team(self, all_ids, all_resources)
	if not built.ok:
		return PartyCatalog.immutable({"ok": false, "reason": built.reason, "actors": []})
	var actors: Array = built.team.actors.duplicate(true)
	for actor: Dictionary in actors:
		actor.selected = party_roster.has(actor.id)
	return PartyCatalog.immutable({"ok": true, "reason": "", "roster": party_roster, "actors": actors})


func _sluice_party_progress() -> Dictionary:
	return {"quest_stage": quest_stage, "map_id": map_id, "side_stage": side_stage,
		"side_choice": side_choice, "side_clues": side_clues,
		"side_found": side_found.duplicate(), "side_reward_claimed": side_reward_claimed}


func can_start_sluice_party_battle(encounter_id: String) -> bool:
	if battle_active or _party_gate() or hp < 1 or map_id != "sluice" or quest_stage != 6:
		return false
	if side_reward_claimed or not side_choice in ["rescue", "pursuit"] or side_clues != side_found.size():
		return false
	if encounter_id == "sluice_scout":
		# The first route can survive a retreat before either clue is collected.
		return side_stage == 1 and (side_found.is_empty() or side_found == ["boatman"])
	if encounter_id == "sluice_boss":
		return side_stage == 2 and side_clues == 2 and side_found.has("boatman") and side_found.has("ledger")
	return false


func _archive_party_progress() -> Dictionary:
	var progress: Dictionary = _sluice_party_progress()
	progress.chapter_two_stage = chapter_two_stage
	progress.chapter_two_ending = chapter_two_ending
	progress.archive_clues = archive_clues.duplicate()
	progress.seal_sequence = seal_sequence.duplicate()
	return progress


func can_start_archive_party_battle() -> bool:
	if battle_active or _party_gate() or hp < 1 or map_id != "frostbridge" or quest_stage != 6:
		return false
	if side_stage != 3 or not side_reward_claimed or not side_choice in ["rescue", "pursuit"]:
		return false
	if side_clues != 2 or side_found.size() != 2 or not side_found.has("boatman") or not side_found.has("ledger"):
		return false
	if chapter_two_stage != 2 or not chapter_two_ending.is_empty():
		return false
	if archive_clues.size() != 2 or not archive_clues.has("clerk") or not archive_clues.has("inscription") or seal_sequence != Chapter.SEAL_ORDER:
		return false
	# A save-normalizing load must not repair malformed entry prerequisites.
	return _stage_save_data(to_dict(), SAVE_VERSION).ok


func start_party_battle(encounter_id: String) -> bool:
	if not UnifiedEncounters.can_enter(self, encounter_id): return false
	if not _stage_save_data(to_dict(), SAVE_VERSION).ok: return false
	var before: Dictionary = to_dict().duplicate(true)
	var prepared = _detached_persistent_state()
	if encounter_id == "sect_trial":
		prepared.heal_rest()
		if not prepared.equip_art(prepared.sect_art()): return false
	var projection: Dictionary = PartyRoster.battle_resources(prepared, prepared._party_payload())
	if not projection.ok: return false
	var built: Dictionary = PartyCatalog.build_team(prepared, prepared.party_roster, projection.resources)
	if not built.ok: return false
	var team: Dictionary = built.team.duplicate(true)
	if encounter_id == "courtyard_practice": team.medicine = 3; team.medicine_heal = 40
	var candidate = PartyCombat.new()
	if not candidate.configure(team, encounter_id): return false
	_clear_battle()
	if encounter_id == "sect_trial": _copy_persistent_from(prepared)
	party_session = candidate
	_party_encounter = encounter_id
	_party_extra_entry = UnifiedEncounters.progress(self, encounter_id)
	if encounter_id == "heting_consignee":
		_party_consignee_identity = {"persistent": before, "epoch": candidate.snapshot().epoch, "encounter_id": encounter_id, "provenance": candidate.snapshot().get("consignee_provenance", {}).duplicate(true)}
	if encounter_id == "capstone_authorizer":
		_party_capstone_identity = {"persistent": before, "encounter_id": encounter_id, "epoch": candidate.snapshot().epoch, "host_epoch": party_battle_epoch, "session_id": candidate.get_instance_id(), "enemy": candidate.snapshot().enemies[0].duplicate(true), "provenance": candidate.snapshot().get("capstone_provenance", {}).duplicate(true)}
	if encounter_id == "courtyard_practice": _party_practice_before = before
	if encounter_id in ["sluice_scout", "sluice_boss"]: _party_sluice_entry = _sluice_party_progress()
	elif encounter_id == "archive_boss": _party_archive_entry = _archive_party_progress()
	battle_kind = encounter_id
	battle_active = true
	return true


func party_battle_snapshot() -> Dictionary:
	if party_session == null:
		return {}
	var result: Dictionary = party_session.snapshot().duplicate(true)
	result.epoch = party_battle_epoch
	result.pending_token = _party_pending_token
	result.settlement = party_settlement
	return PartyCatalog.immutable(result)


func select_party_actor(id: String) -> bool:
	return _party_gate() and battle_active and party_session.select_actor(id)


func select_party_target(id: String) -> bool:
	return _party_gate() and battle_active and party_session.select_target(id)


func _party_rejection(reason: String) -> Dictionary:
	return PartyCatalog.immutable({"ok": false, "accepted": false, "settled": false, "reason": reason,
		"epoch": party_battle_epoch, "token": -1})


func queue_party_skill(actor_id: String, action: String, target: String = "") -> Dictionary:
	if not _party_gate() or not battle_active: return _party_rejection("当前没有交锋。")
	return party_session.queue_skill(actor_id, action, target)

func cancel_party_skill(actor_id: String, category: String) -> bool:
	return _party_gate() and battle_active and party_session.cancel_queued(actor_id, category)

func pause_party_battle(paused: bool) -> bool:
	return _party_gate() and battle_active and party_session.set_paused(paused)

func advance_party_battle() -> Dictionary:
	if not _party_gate() or not battle_active: return _party_rejection("当前没有交锋。")
	return _accept_party_transaction(party_session.advance())

func party_battle_action(action: String, target: String = "") -> Dictionary:
	if not _party_gate() or not battle_active: return _party_rejection("当前没有交锋。")
	# Only shared medicine/retreat are immediate utilities. Manual attacks and
	# skills cannot bypass the automatic entitlement/queued execution scheduler.
	return _accept_party_transaction(party_session.accept_action(action, target))

func _accept_party_transaction(tx: Dictionary) -> Dictionary:
	var decorated: Dictionary = tx.duplicate(true)
	decorated.epoch = party_battle_epoch
	if not tx.get("accepted", false): return PartyCatalog.immutable(decorated)
	_party_pending_token = int(tx.token)
	if _party_encounter == "courtyard_practice": return PartyCatalog.immutable(decorated)
	medicine = int(tx.after.medicine)
	for actor: Dictionary in tx.after.actors:
		if actor.id == "hero":
			hp = int(actor.hp); qi = int(actor.qi); art_uses = actor.art_uses.duplicate(true)
		else: party_resources[actor.id] = {"hp": int(actor.hp), "qi": int(actor.qi)}
	return PartyCatalog.immutable(decorated)


func finish_party_presentation(epoch: int, token: int) -> Dictionary:
	if epoch != party_battle_epoch or token < 0 or token != _party_pending_token or not _party_gate() or not battle_active:
		return _party_rejection("演绎凭据已失效。")
	var snapshot: Dictionary = party_session.snapshot()
	if not snapshot.locked:
		return _party_rejection("交锋未等待演绎确认。")
	if snapshot.active:
		if not party_session.complete_presentation(token):
			return _party_rejection("演绎凭据已失效。")
		_party_pending_token = -1
		return PartyCatalog.immutable({"ok": true, "accepted": true, "settled": false,
			"reason": "", "epoch": epoch, "token": token, "snapshot": party_battle_snapshot()})
	# Build and validate the entire resource + progression + XP settlement on a
	# detached state before unlocking the accepted terminal transaction.
	var staged: Dictionary = _party_terminal_plan(snapshot)
	if not staged.ok:
		return _party_rejection(staged.reason)
	if not party_session.complete_presentation(token):
		return _party_rejection("演绎凭据已失效。")
	_party_pending_token = -1
	battle_active = false
	_copy_persistent_from(staged.state)
	skill_cooldown = 0
	party_settlement = PartyCatalog.immutable(staged.settlement)
	return PartyCatalog.immutable({"ok": true, "accepted": true, "settled": true,
		"reason": "", "epoch": epoch, "token": token, "outcome": snapshot.outcome,
		"settlement": party_settlement, "snapshot": party_battle_snapshot()})


func _party_terminal_plan(snapshot: Dictionary) -> Dictionary:
	if (_party_encounter == "capstone_authorizer" or not _party_capstone_identity.is_empty()) and not _valid_capstone_terminal(snapshot):
		return {"ok": false, "reason": "截令交锋的凭据、进度或已消耗资源已经改变。"}
	if _party_encounter == "heting_consignee" and not _valid_consignee_terminal(snapshot):
		return {"ok": false, "reason": "收货交锋的凭据、进度或已消耗资源已经改变。"}
	var candidate = _detached_persistent_state()
	if _party_encounter == "courtyard_practice":
		if not _same_save_value(to_dict(), _party_practice_before): return {"ok": false, "reason": "演练期间的持久状态发生变化，拒绝覆盖。"}
		return {"ok": true, "state": candidate, "settlement": {"outcome": snapshot.outcome, "encounter_id": _party_encounter, "awarded": false, "reward_xp": 0, "coin_change": 0, "practice": true, "map_id": map_id, "position": position, "resources": candidate.party_resource_snapshot()}}
	# Capstone progress includes live helper resources. Its stronger entry
	# validator above already reconciles exactly the accepted battle resources;
	# comparing those mutable values to entry again would reject genuine costs.
	if _party_encounter != "capstone_authorizer" and not _party_extra_entry.is_empty() and UnifiedEncounters.progress(candidate, _party_encounter) != _party_extra_entry:
		return {"ok": false, "reason": "本次交锋的调查或验艺条件已经改变。"}
	var terminal: Dictionary = {}
	for actor: Dictionary in snapshot.actors:
		terminal[actor.id] = {"hp": int(actor.hp), "qi": int(actor.qi)}
	var plan: Dictionary = PartyRoster.settle_plan(candidate, _party_payload(), terminal, String(snapshot.outcome))
	if not plan.ok:
		return {"ok": false, "reason": plan.reason}
	candidate._apply_party_plan(plan)
	# Validate the recovered boundary before adding rewards. A bonus must not
	# accidentally repair malformed live data (for example medicine -1 +2).
	if not _stage_save_data(candidate.to_dict(), SAVE_VERSION).ok:
		return {"ok": false, "reason": "交锋结算前的完整存档校验未通过。"}
	if _party_encounter == "archive_boss" and (not candidate.can_start_archive_party_battle() or candidate._archive_party_progress() != _party_archive_entry):
		return {"ok": false, "reason": "霜桥的线索或封印进度已改变，不能结算本次交锋。"}
	var coins_before: int = candidate.coins
	var level_before: int = candidate.level
	var awarded: bool = false
	var reward_xp: int = 0
	var branch_reward_xp: int = 0
	var messages: Array[String] = []
	if snapshot.outcome == "win":
		if _party_encounter in ["mist_scout", "mist_keeper", "sect_trial"]:
			var extra: Dictionary = UnifiedEncounters.settle_extra_win(candidate, _party_encounter, snapshot)
			if not extra.get("ok", false): return {"ok": false, "reason": "调查或验艺结算条件已失效。"}
			reward_xp = int(extra.xp); messages.append_array(extra.messages); awarded = true
		elif _party_encounter == "capstone_authorizer":
			if not Capstone.settle_victory(candidate):
				return {"ok": false, "reason": "签令责任或未发簿进度已失效。"}
			# Victory only acquires the book: no classification, plan or award.
			candidate.victories = mini(999999, candidate.victories + 1)
		elif _party_encounter == "heting_consignee":
			if not Consignee.settle_victory(candidate, String(_party_extra_entry.get("consignee_draft", ""))):
				return {"ok": false, "reason": "收货暂缓方案或调查进度已失效。"}
			# Securing this finite lot is not its final disposition or reward.
			candidate.victories = mini(999999, candidate.victories + 1)
		elif _party_encounter == "heting_receipt":
			if not Receipt.settle_victory(candidate):
				return {"ok": false, "reason": "复签进度不再允许本次结算。"}
			reward_xp = Receipt.REWARD_XP
			awarded = true
		elif _party_encounter == "archive_boss":
			if not candidate.mark_archive_victory():
				return {"ok": false, "reason": "封仓原账已经取得，不能重复结算。"}
			reward_xp = 80
			candidate.coins = mini(999999, candidate.coins + 40)
			candidate.victories = mini(999999, candidate.victories + 1)
			messages.append_array(candidate.gain_xp(reward_xp))
			# The later innkeeper ending remains an explicit player choice.
			awarded = true
		elif _party_encounter in ["sluice_scout", "sluice_boss"]:
			if not candidate.can_start_sluice_party_battle(_party_encounter) or candidate._sluice_party_progress() != _party_sluice_entry:
				return {"ok": false, "reason": "废闸的路线或线索已改变，不能结算本次交锋。"}
			var is_boss: bool = _party_encounter == "sluice_boss"
			reward_xp = 70 if is_boss else 25
			candidate.coins = mini(999999, candidate.coins + (35 if is_boss else 14))
			candidate.victories = mini(999999, candidate.victories + 1)
			messages.append_array(candidate.gain_xp(reward_xp))
			if is_boss:
				# Existing branch completion follows the battle award, including its
				# second XP step, so level-up recovery cannot be overwritten by HP/qi.
				var branch_level: int = candidate.level
				if not candidate.finish_side_quest():
					return {"ok": false, "reason": "废闸水令不能重复领取。"}
				branch_reward_xp = 80
				for gained_level: int in range(branch_level + 1, candidate.level + 1):
					messages.append("境界精进！升至 %d 级，气血与真气已恢复。" % gained_level)
				candidate.coins = mini(999999, candidate.coins)
				candidate.medicine = mini(999, candidate.medicine)
			elif not candidate.find_side_clue("ledger"):
				return {"ok": false, "reason": "传令人的账页已被收起，不能重复结算。"}
			awarded = true
		else:
			if (_party_encounter == "story" and candidate.quest_stage != 3) or (_party_encounter == "training" and candidate.quest_stage < 4):
				return {"ok": false, "reason": "交锋进度不再允许本次结算。"}
			reward_xp = 30 if _party_encounter == "training" else 60
			candidate.coins = mini(999999, candidate.coins + (12 if _party_encounter == "training" else 26))
			candidate.victories = mini(999999, candidate.victories + 1)
			if _party_encounter == "story":
				candidate.quest_stage = 4
			messages.append_array(candidate.gain_xp(reward_xp))
			awarded = true
	elif snapshot.outcome == "defeat":
		candidate.coins = maxi(0, candidate.coins - mini(candidate.coins, 8))
		candidate.map_id = "heting" if _party_encounter in ["heting_receipt", "heting_consignee"] else "qingwei"
		candidate.position = Vector2(230, 735) if _party_encounter in ["heting_receipt", "heting_consignee"] else Vector2(420, 450)
		if _party_encounter == "capstone_authorizer":
			candidate.map_id = "frostbridge"
			candidate.position = Vector2(405, 430)
	# gain_xp reconciles growth after its explicit hero refill. Reapplying the
	# pre-XP resource plan here would wrongly erase that refill.
	if not _stage_save_data(candidate.to_dict(), SAVE_VERSION).ok:
		return {"ok": false, "reason": "交锋结算未通过完整存档校验。"}
	var settlement: Dictionary = {"outcome": snapshot.outcome, "encounter_id": _party_encounter,
		"awarded": awarded, "reward_xp": reward_xp + branch_reward_xp,
		"battle_reward_xp": reward_xp, "branch_reward_xp": branch_reward_xp,
		"coin_change": candidate.coins - coins_before,
		"level_before": level_before, "level_after": candidate.level, "quest_stage": candidate.quest_stage,
		"side_stage": candidate.side_stage, "side_choice": candidate.side_choice,
		"side_found": candidate.side_found.duplicate(), "side_reward_claimed": candidate.side_reward_claimed,
		"branch_reward_claimed": branch_reward_xp > 0,
		"chapter_two_stage": candidate.chapter_two_stage, "chapter_two_ending": candidate.chapter_two_ending,
		"archive_clues": candidate.archive_clues.duplicate(), "seal_sequence": candidate.seal_sequence.duplicate(),
		"mist_stage": candidate.mist_stage, "mist_approach": candidate.mist_approach, "sect_trial_won": candidate.sect_trial_won,
		"receipt_stage": candidate.receipt_stage, "map_id": candidate.map_id,
		"position": candidate.position, "messages": messages, "resources": candidate.party_resource_snapshot()}
	if _party_encounter == "heting_consignee":
		settlement["consignee_stage"] = candidate.consignee_stage
		settlement["consignee_ending"] = candidate.consignee_ending
	if _party_encounter == "capstone_authorizer":
		settlement["capstone_stage"] = candidate.capstone_stage
		settlement["capstone_draft"] = candidate.capstone_draft
		settlement["capstone_ending"] = candidate.capstone_ending
	return {"ok": true, "state": candidate, "settlement": settlement}


func _valid_schema12_core(data: Dictionary, version: int = SAVE_VERSION) -> bool:
	# Current saves are complete and canonical. Older versions retain their
	# documented normalization policy; the schema12 reader never silently fixes
	# malformed fields or incomplete party resources.
	for key: String in to_dict():
		if key == "internal_unlocked" and version < 13: continue
		if key in Consignee.FIELDS and version < 14: continue
		if key in Capstone.FIELDS and version < 15: continue
		if not data.has(key):
			return false
	for key: String in ["level", "xp", "coins", "hp", "max_hp", "qi", "max_qi", "attack", "defense", "medicine", "herbs", "quest_stage", "victories", "side_stage", "side_clues", "chapter_two_stage", "sect_rank", "sect_merit", "tangqi_stage", "mist_stage"]:
		if not _is_number(data[key]) or float(data[key]) != floor(float(data[key])):
			return false
	return true


func _same_save_value(normalized: Variant, raw: Variant) -> bool:
	# Godot Dictionary equality distinguishes nested JSON floats from ints.
	# Compare numeric leaves without weakening any shape or field validation.
	if normalized is Dictionary and raw is Dictionary:
		if normalized.size() != raw.size():
			return false
		for key: Variant in normalized:
			if not raw.has(key) or not _same_save_value(normalized[key], raw[key]):
				return false
		return true
	if normalized is Array and raw is Array:
		if normalized.size() != raw.size():
			return false
		for index: int in range(normalized.size()):
			if not _same_save_value(normalized[index], raw[index]):
				return false
		return true
	if normalized is float and raw is float:
		# JSON writes a finite decimal approximation of Vector2 float32 values.
		return JSON.stringify(normalized) == JSON.stringify(raw)
	if _is_number(normalized) and _is_number(raw):
		return float(normalized) == float(raw)
	return typeof(normalized) == typeof(raw) and normalized == raw


func qin_recruited() -> bool:
	return qin_unlocked and qin_stage == 4


func _valid_qin_progress(data: Dictionary) -> bool:
	var stage: Variant = data.get("qin_stage")
	if not _is_number(stage) or float(stage) != floor(float(stage)) or stage < 0 or stage > 4:
		return false
	if not data.get("qin_unlocked") is bool or data.qin_unlocked != (stage == 4):
		return false
	return stage == 0 or (data.get("mist_stage", 0) == 4 and data.get("mist_ending", "") in Mist.ENDINGS)


## Format14 chapter mutations are detached whole-state transactions. Pending
## presentation tokens block them even if a stale caller clears battle_active.
func _consignee_candidate():
	if battle_active or _party_pending_token >= 0 or _party_gate(): return null
	if not _stage_save_data(to_dict(), SAVE_VERSION).ok: return null
	return _detached_persistent_state()


func _commit_consignee_candidate(candidate) -> bool:
	if candidate == null or battle_active or _party_pending_token >= 0 or _party_gate(): return false
	if not _stage_save_data(candidate.to_dict(), SAVE_VERSION).ok: return false
	_copy_persistent_from(candidate)
	return true


func begin_consignee() -> bool:
	var candidate = _consignee_candidate()
	return candidate != null and Consignee.begin(candidate) and _commit_consignee_candidate(candidate)


func observe_consignee(id: String, method: String = "solo") -> bool:
	var candidate = _consignee_candidate()
	return candidate != null and Consignee.observe(candidate, id, method) and _commit_consignee_candidate(candidate)


func resolve_consignee_contradiction(answer: String) -> Dictionary:
	var candidate = _consignee_candidate()
	if candidate == null: return {"ok": false, "correct": false, "reason": "当前不能核对收货凭据。"}
	var result: Dictionary = Consignee.resolve_contradiction(candidate, answer)
	if result.get("ok", false) and not _commit_consignee_candidate(candidate):
		return {"ok": false, "correct": false, "reason": "完整进度校验未通过。"}
	return result


func choose_consignee_plan(id: String) -> bool:
	var candidate = _consignee_candidate()
	return candidate != null and Consignee.choose_plan(candidate, id) and _commit_consignee_candidate(candidate)


func available_consignee_cargo(source: String) -> Array[String]:
	return Consignee.available_cargo(self, source)


func take_consignee_cargo(id: String, source: String) -> bool:
	var candidate = _consignee_candidate()
	return candidate != null and Consignee.take_cargo(candidate, id, source) and _commit_consignee_candidate(candidate)


func park_consignee_cargo() -> bool:
	var candidate = _consignee_candidate()
	return candidate != null and Consignee.park_cargo(candidate) and _commit_consignee_candidate(candidate)


func finish_consignee_delivery(receiver: String, expected_plan: String) -> bool:
	var candidate = _consignee_candidate()
	return candidate != null and Consignee.finish_delivery(candidate, receiver, expected_plan) and _commit_consignee_candidate(candidate)


## This new encounter accepts only its real controller snapshot. The entry
## document is immutable evidence of every non-battle field; current HP, qi,
## medicine and proficiency must be precisely the accepted model's resources.
## Validate before defeat recovery or any XP award can conceal malformed data.
func _valid_consignee_terminal(snapshot: Dictionary) -> bool:
	if party_session == null or _party_consignee_identity.is_empty(): return false
	if snapshot.get("encounter_id") != "heting_consignee" or snapshot.get("epoch") != _party_consignee_identity.epoch: return false
	if not _same_save_value(snapshot.get("consignee_provenance", {}), _party_consignee_identity.provenance): return false
	if snapshot.get("active", true) or not snapshot.get("locked", false): return false
	if snapshot.get("pending_token", -1) != _party_pending_token or _party_pending_token < 0: return false
	if not _same_save_value(snapshot, party_session.snapshot()): return false
	if not snapshot.get("actors") is Array or not snapshot.get("enemies") is Array: return false
	var expected: Dictionary = _party_consignee_identity.persistent.duplicate(true)
	var ids: Array[String] = []
	for actor: Dictionary in snapshot.actors:
		if ids.has(String(actor.id)): return false
		ids.append(String(actor.id))
		if actor.id == "hero":
			expected.hp = actor.hp
			expected.qi = actor.qi
			expected.art_uses = actor.art_uses.duplicate(true)
		else:
			if not expected.party_resources.has(actor.id): return false
			expected.party_resources[actor.id] = {"hp": actor.hp, "qi": actor.qi}
	if ids != expected.party_roster: return false
	expected.medicine = snapshot.medicine
	if not _same_save_value(to_dict(), expected): return false
	if snapshot.outcome == "win":
		for enemy: Dictionary in snapshot.enemies:
			if enemy.hp != 0: return false
	return snapshot.outcome in ["win", "flee", "defeat"]


## Format15 mutations validate a complete detached state before committing.
## Map guards are model scope; the scene host must separately prove the live
## site, proximity and explicit input. Saving retries serialize accepted state.
func _capstone_candidate():
	if battle_active or _party_pending_token >= 0 or _party_gate(): return null
	if not _stage_save_data(to_dict(), SAVE_VERSION).ok: return null
	return _detached_persistent_state()


func _commit_capstone_candidate(candidate, homecoming: bool = false) -> bool:
	if candidate == null or battle_active or _party_pending_token >= 0 or _party_gate(): return false
	if not _stage_save_data(candidate.to_dict(), SAVE_VERSION).ok: return false
	if not homecoming:
		# In particular 3→4 is excluded: only authenticated battle settlement
		# commits that transition, never a generic noncombat candidate.
		var step: Vector2i = Vector2i(capstone_stage, candidate.capstone_stage)
		if step not in [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(4, 5), Vector2i(5, 5), Vector2i(5, 6)]: return false
		if step == Vector2i(5, 5) and candidate.capstone_draft == capstone_draft: return false
	var expected = _detached_persistent_state()
	for key: String in Capstone.FIELDS: expected.set(key, candidate.get(key))
	if homecoming:
		if capstone_stage != 6 or candidate.capstone_stage != 7 or candidate.capstone_draft != capstone_draft or candidate.capstone_ending != capstone_ending: return false
		# Independently compute only the ordinary capped XP/growth delta. Do not
		# invoke another reward callback or grant a second live award.
		expected.coins = mini(999999, expected.coins + Capstone.REWARD_COINS)
		var before_growth = expected._detached_persistent_state()
		expected._gain_xp_core(Capstone.REWARD_XP)
		var growth: Dictionary = PartyRoster.reconcile_growth(before_growth, expected, _party_payload())
		if not growth.ok: return false
		expected._apply_party_plan(growth)
	if not _same_save_value(candidate.to_dict(), expected.to_dict()): return false
	_copy_persistent_from(candidate)
	return true


func begin_capstone() -> bool:
	var candidate = _capstone_candidate()
	return candidate != null and Capstone.begin(candidate) and _commit_capstone_candidate(candidate)


func reveal_capstone_letter() -> bool:
	var candidate = _capstone_candidate()
	return candidate != null and Capstone.reveal_letter(candidate) and _commit_capstone_candidate(candidate)


func resolve_capstone_evidence(answer: String, method: String = "solo") -> Dictionary:
	var candidate = _capstone_candidate()
	if candidate == null: return {"ok": false, "correct": false, "reason": "当前不能核定签令责任。"}
	var result: Dictionary = Capstone.resolve_evidence(candidate, answer, method)
	if result.get("ok", false) and not _commit_capstone_candidate(candidate):
		return {"ok": false, "correct": false, "reason": "完整进度校验未通过。"}
	return result


func classify_capstone_orders(partition: Variant, method: String = "solo") -> Dictionary:
	var candidate = _capstone_candidate()
	if candidate == null: return {"ok": false, "correct": false, "reason": "当前不能分类四号未发令。"}
	var result: Dictionary = Capstone.classify_orders(candidate, partition, method)
	if result.get("ok", false) and not _commit_capstone_candidate(candidate):
		return {"ok": false, "correct": false, "reason": "完整进度校验未通过。"}
	return result


func choose_capstone_plan(plan: String) -> bool:
	var candidate = _capstone_candidate()
	return candidate != null and Capstone.choose_plan(candidate, plan) and _commit_capstone_candidate(candidate)


func confirm_capstone_disposition(expected_plan: String) -> bool:
	var candidate = _capstone_candidate()
	return candidate != null and Capstone.confirm_disposition(candidate, expected_plan) and _commit_capstone_candidate(candidate)


func finish_capstone_homecoming() -> bool:
	var candidate = _capstone_candidate()
	return candidate != null and Capstone.finish_homecoming(candidate) and _commit_capstone_candidate(candidate, true)


## No direct capstone victory wrapper exists. Only this exact accepted terminal
## from the controller entered by start_party_battle may earn the book. Whole
## entry identity is checked before recovery/rewards can conceal corruption.
func _valid_capstone_terminal(snapshot: Dictionary) -> bool:
	if party_session == null or _party_capstone_identity.is_empty(): return false
	if _party_encounter != "capstone_authorizer" or battle_kind != "capstone_authorizer": return false
	if party_session.get_instance_id() != _party_capstone_identity.session_id: return false
	if party_battle_epoch != _party_capstone_identity.host_epoch: return false
	if snapshot.get("encounter_id") != "capstone_authorizer" or snapshot.get("epoch") != _party_capstone_identity.epoch: return false
	if not _same_save_value(snapshot.get("capstone_provenance", {}), _party_capstone_identity.provenance): return false
	if snapshot.get("active", true) or not snapshot.get("locked", false): return false
	if snapshot.get("pending_token", -1) != _party_pending_token or _party_pending_token < 0: return false
	if not _same_save_value(snapshot, party_session.snapshot()): return false
	if not snapshot.get("actors") is Array or not snapshot.get("enemies") is Array: return false
	if snapshot.enemies.size() != 1 or snapshot.enemies[0].get("id") != "liang_zhen": return false
	if snapshot.enemies[0].get("max_hp") != _party_capstone_identity.provenance.get("liang_zhen_max_hp"): return false
	for key: String in ["id", "name", "team", "max_hp", "attack", "heavy_attack"]:
		if not _same_save_value(snapshot.enemies[0].get(key), _party_capstone_identity.enemy.get(key)): return false
	var expected: Dictionary = _party_capstone_identity.persistent.duplicate(true)
	var ids: Array[String] = []
	for actor: Dictionary in snapshot.actors:
		if ids.has(String(actor.id)): return false
		ids.append(String(actor.id))
		if actor.id == "hero":
			expected.hp = actor.hp
			expected.qi = actor.qi
			expected.art_uses = actor.art_uses.duplicate(true)
		else:
			if not expected.party_resources.has(actor.id): return false
			expected.party_resources[actor.id] = {"hp": actor.hp, "qi": actor.qi}
	if ids != expected.party_roster: return false
	expected.medicine = snapshot.medicine
	if not _same_save_value(to_dict(), expected): return false
	if snapshot.outcome == "win" and snapshot.enemies[0].hp != 0: return false
	return snapshot.outcome in ["win", "flee", "defeat"]
