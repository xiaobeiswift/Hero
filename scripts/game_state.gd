class_name HeroState
extends RefCounted
## Pure, deterministic rules for 青苇渡. No scene tree or UI dependencies.

const SAVE_VERSION: int = 7
const SAVE_PATH: String = "user://hero_save.json"
const SECTS: Array[String] = ["听潮阁", "照野堂", "问石门"]
const Patterns=preload("res://scripts/battle_patterns.gd")
const Mist=preload("res://scripts/mistwood_rules.gd")
const ShenCare=preload("res://scripts/shen_care_rules.gd")
const Companions=preload("res://scripts/companion_rules.gd")
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
var shen_care_stage:int=0
var shen_care_choice:String=""
var tangqi_unlocked:bool=false
var tangqi_stage:int=0
var tangqi_choice:String=""
var active_companion:String=""
var formation: String = "并肩"
var equipment: String = "旧铁剑"
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
	shen_care_stage=0;shen_care_choice=""
	tangqi_unlocked=false;tangqi_stage=0;tangqi_choice="";active_companion=""
	formation = "并肩"
	equipment = "旧铁剑"
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
	hp = max_hp
	qi = max_qi
	skill_cooldown = 0


func use_medicine() -> bool:
	if medicine <= 0 or hp >= max_hp:
		return false
	medicine -= 1
	var healing: int = 55 if sect == "照野堂" else 45
	hp = mini(max_hp, hp + healing)
	return true


func choose_sect(id: String) -> void:
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
	if companion_unlocked:
		return false
	companion_unlocked = true
	_companion_attack_count = 0
	return true


func current_companion() -> String:return Companions.active(self)
func available_companions() -> Array[String]:return Companions.available(self)
func select_companion(id:String) -> bool:return Companions.select(self,id)
func companion_description() -> String:return Companions.description(self)
func begin_shen_care() -> bool:return ShenCare.begin(self)
func consult_shen_patient() -> bool:return ShenCare.consult(self)
func inspect_shen_shelter() -> bool:return ShenCare.inspect(self)
func choose_shen_care(choice:String) -> bool:return ShenCare.choose(self,choice)
func post_shen_notice() -> bool:return ShenCare.post(self)
func begin_tangqi_quest() -> bool:return Companions.begin(self)
func recover_craft_notes() -> bool:return Companions.recover(self)
func resolve_tangqi_quest(choice:String) -> bool:return Companions.resolve(self,choice)
func recruit_tangqi() -> bool:return Companions.recruit(self)

func set_formation(id: String) -> bool:
	if current_companion().is_empty() or not ["并肩", "护后"].has(id):
		return false
	if formation != id:
		formation = id
		_companion_attack_count = 0
	return true


func buy_equipment() -> bool:
	if equipment != "旧铁剑" or coins < 45:
		return false
	coins -= 45
	equipment = "青钢剑"
	attack += 4
	return true


func current_region_name() -> String:
	return "雾竹坡" if map_id=="mistwood" else ("霜桥驿" if map_id=="frostbridge" else ("旧闸" if map_id == "sluice" else "青苇渡"))


func choose_side_route(choice: String) -> bool:
	if not side_choice.is_empty() or side_stage != 0 or not ["rescue", "pursuit"].has(choice):
		return false
	side_choice = choice
	side_stage = 1
	return true


func find_side_clue(id: String) -> bool:
	if side_stage != 1 or side_choice.is_empty() or not ["boatman", "ledger"].has(id) or side_found.has(id):
		return false
	side_found.append(id)
	side_clues = side_found.size()
	if side_clues == 2:
		side_stage = 2
	return true


func finish_side_quest() -> bool:
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
		"shen_care_stage":shen_care_stage,"shen_care_choice":shen_care_choice,
		"tangqi_unlocked":tangqi_unlocked,"tangqi_stage":tangqi_stage,"tangqi_choice":tangqi_choice,"active_companion":current_companion(),
		"formation": formation, "equipment": equipment,
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
	var temporary: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": SAVE_VERSION, "player": to_dict()}, "\t"))
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
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	# Avoid parsing an unexpectedly large or unrelated file as a save.
	if file.get_length() > 1048576:
		file.close()
		return ERR_FILE_CORRUPT
	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not json.data is Dictionary:
		return ERR_FILE_CORRUPT
	var document: Dictionary = json.data
	if not _is_number(document.get("version")):
		return ERR_FILE_CORRUPT
	if not [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, float(SAVE_VERSION)].has(float(document["version"])):
		return ERR_FILE_UNRECOGNIZED
	if not document.get("player") is Dictionary:
		return ERR_FILE_CORRUPT
	var data: Dictionary = document["player"]
	if not _valid_save_data(data, int(document["version"])):
		return ERR_FILE_CORRUPT
	# Validation completes before touching the current game.
	reset_game()
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
	map_id=String(data.get("map_id","qingwei")) if data.get("map_id","") in ["qingwei","sluice","frostbridge","mistwood"] else "qingwei"
	Chapter.restore(self,data)
	Mist.restore(self,data)
	Companions.restore(self,data)
	ShenCare.restore(self,data)
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
	return OK


func _valid_save_data(data: Dictionary, version: int = SAVE_VERSION) -> bool:
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
	if not Companions.valid(data):return false
	if not ShenCare.valid(data,version):return false
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
	return Chapter.begin(self)
func add_archive_clue(id:String) -> bool:
	return Chapter.clue(self,id)
func try_seal(index:int) -> Dictionary:
	return Chapter.seal(self,index)
func mark_archive_victory() -> bool:
	return Chapter.victory(self)
func resolve_chapter_two(choice:String) -> bool:
	return Chapter.resolve(self,choice)
func repair_bridge() -> bool:
	return Chapter.repair_bridge(self)

func sect_art() -> String:return Sects.art(self)
func sect_trial_requirement() -> String:return Sects.requirement(self)
func can_take_sect_trial() -> bool:return Sects.eligible(self) and not battle_active
func complete_sect_trial() -> bool:return Sects.complete(self)
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
