extends SceneTree
const Skills = preload("res://scripts/combat_skill_catalog.gd")
const Arts = preload("res://scripts/martial_catalog.gd")
var checks: int = 0
var failures: int = 0


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


func _init() -> void:
	_empty_and_locked_categories()
	_earned_hero_skills()
	_preserved_martial_definitions()
	_recruited_companions()
	_detached_definitions()
	if failures == 0:
		print("PASS: %d combat skill catalog checks" % checks)
	else:
		push_error("FAIL: %d of %d combat skill catalog checks" % [failures, checks])
	quit(0 if failures == 0 else 1)


func _check_shape(actions: Array, label: String) -> void:
	check(actions.size() == 3, label + ": exactly three manual slots")
	var categories: Array = []
	for action: Dictionary in actions:
		categories.append(action.category)
		for key: String in ["id", "category", "name", "target_team", "cost", "cooldown", "description", "effects", "learned", "reason", "learning_source"]:
			check(action.has(key), label + ": complete descriptor " + key)
		check(action.id not in ["attack", "guard", "item", "flee"], label + ": automatic attacks and utilities never occupy skill slots")
	check(categories == ["martial", "internal", "lightness"], label + ": stable semantic category order")


func _empty_and_locked_categories() -> void:
	for actor: Dictionary in [{}, {"id": "unknown", "internal_unlocked": true, "lightness_unlocked": true, "recruited": true}, {"id": "hero"}]:
		var actions: Array = Skills.manual_actions(actor)
		_check_shape(actions, "Empty/unknown/untrained actor")
		for action: Dictionary in actions:
			check(not action.learned and not action.reason.is_empty(), "Unlearned skill is explicitly disabled with a reason")
			check(action.effects.is_empty() and action.target_team == "none", "Unlearned placeholder cannot confer an effect or target")
			check(action.name.contains("未习"), "Unlearned slot visibly tells the truth")
	var hero: Dictionary = {"id": "hero", "equipped_art": Arts.BASE_ART, "level": 99, "sect_rank": 2, "sect": "听潮阁", "companion_unlocked": true}
	var actions: Array = Skills.manual_actions(hero)
	check(actions[0].learned and not actions[1].learned and not actions[2].learned, "Level, sect, rank, and recruitment do not fabricate hero lessons")
	for invalid: Variant in [1, "true", [], {}]:
		hero.internal_unlocked = invalid
		hero.lightness_unlocked = invalid
		actions = Skills.manual_actions(hero)
		check(not actions[1].learned and not actions[2].learned, "Learned flags require an explicit boolean")


func _earned_hero_skills() -> void:
	var hero: Dictionary = {"id": "hero", "equipped_art": Arts.BASE_ART, "internal_unlocked": false, "lightness_unlocked": true}
	var actions: Array = Skills.manual_actions(hero)
	check(not actions[1].learned and actions[2].learned, "Existing traversal lesson unlocks combat footwork without granting an internal lesson")
	check(actions[2].id == Skills.HERO_LIGHTNESS and actions[2].effects == {"next_hit_reduction": 10}, "Hero footwork has its own deterministic next-hit effect")
	hero.internal_unlocked = true
	hero.lightness_unlocked = false
	actions = Skills.manual_actions(hero)
	check(actions[1].learned and not actions[2].learned, "Explicit internal lesson is independent of lightness")
	check(actions[1].id == Skills.HERO_INTERNAL and actions[1].effects == {"healing": 16}, "Hero internal art restores a bounded amount of HP")
	check(actions[1].learning_source.contains("岑远") and actions[1].learning_source.contains("3级"), "Hero internal art has an explicit eligible teaching interaction")
	hero.lightness_unlocked = true
	actions = Skills.manual_actions(hero)
	_check_shape(actions, "Fully trained hero")
	_check_new_skill_budget(actions)
	check(actions[1].description != actions[2].description and actions[1].effects != actions[2].effects, "Internal and lightness have independent descriptions and actual effects")
	check(actions[2].description.contains("本轮") and actions[2].description.contains("轮末失效") and actions[2].description.contains("不会触发守势考法"), "Footwork states deterministic scope, expiration, and trial exclusion")


func _preserved_martial_definitions() -> void:
	for art_id: String in Arts.all_ids():
		var original: Dictionary = Arts.definition(art_id)
		var actions: Array = Skills.manual_actions({"id": "hero", "equipped_art": art_id})
		var action: Dictionary = actions[0]
		check(action.learned and action.id == "art:" + art_id and action.name == original.name, "Equipped martial identity retained: " + art_id)
		check(action.effects == original, "Every original martial effect retained: " + art_id)
		check(action.cost == original.cost and action.cooldown == original.cooldown, "Original martial resource budget retained: " + art_id)
		check(action.target_team == "enemy", "Martial trial strike keeps its enemy target: " + art_id)
		check(not actions[1].learned and not actions[2].learned, "Martial ownership cannot masquerade as other categories: " + art_id)
	check(Skills.manual_actions({"id": "hero", "equipped_art": "青灯续脉"})[0].effects.healing == 30, "Actual school-trial healing is preserved")
	check(Skills.manual_actions({"id": "hero", "equipped_art": "磐石回锋"})[0].effects.guard, "Actual school-trial guard is preserved inside martial skill")
	check(not Skills.manual_actions({"id": "hero", "equipped_art": "missing"})[0].learned, "Unknown equipped art cannot silently receive a fabricated basic art")


func _recruited_companions() -> void:
	var signatures: Dictionary = {"shen": "art:shen_xumai", "tang": "art:tang_fenjin", "qin": "art:qin_shoudu"}
	var all_ids: Array[String] = []
	for id: String in ["shen", "tang", "qin"]:
		for recruited: Variant in [false, 1, "true"]:
			for action: Dictionary in Skills.manual_actions({"id": id, "recruited": recruited, "internal_unlocked": true, "lightness_unlocked": true}):
				check(not action.learned, "No companion skill exists before actual recruitment: " + id)
		var actions: Array = Skills.manual_actions({"id": id, "recruited": true})
		_check_shape(actions, "Recruited " + id)
		check(actions[0].id == signatures[id], "Companion martial signature is unchanged: " + id)
		for action: Dictionary in actions:
			check(action.learned and action.reason.is_empty(), "Actual recruit can use trained skill: " + id)
			check(not action.learning_source.is_empty(), "Every companion skill explains its training: " + id)
			check(not all_ids.has(action.id), "All trained companion IDs remain distinct")
			all_ids.append(action.id)
		_check_new_skill_budget(actions)
		check(actions[1].description != actions[2].description and actions[1].effects != actions[2].effects, "Companion internal/lightness are independent skills: " + id)
	check(Skills.manual_actions({"id": "shen", "recruited": true})[0].effects.healing == 28, "Shen original ally healing is preserved")
	check(Skills.manual_actions({"id": "shen", "recruited": true, "care_healing_bonus": 2})[0].effects.healing == 30, "Shen earned mobile-care bonus is preserved")
	check(Skills.manual_actions({"id": "shen", "recruited": true, "care_healing_bonus": 99})[0].effects.healing == 30, "Shen care bonus remains bounded")
	check(Skills.manual_actions({"id": "tang", "recruited": true})[0].effects.weaken_strikes == 2, "Tang original weakening duration is preserved")
	check(Skills.manual_actions({"id": "qin", "recruited": true})[0].effects == {"barrier": 18}, "Qin original targeted protection is preserved")


func _check_new_skill_budget(actions: Array) -> void:
	for index: int in [1, 2]:
		var action: Dictionary = actions[index]
		check(action.target_team == "self" and action.cost == 2, "New skill has an explicit self target and actual qi cost")
		check(action.cooldown == (3 if index == 1 else 2), "New skill has a bounded completed-round cooldown")
		check(not action.effects.has("qi_restore") and not action.effects.has("attack_multiplier") and not action.effects.has("guard"), "New skill cannot refund itself or disguise ordinary attack/guard")
		if index == 1:
			check(action.effects.healing > 0 and action.effects.healing <= 20, "Internal healing is finite")
		else:
			check(action.effects.next_hit_reduction > 0 and action.effects.next_hit_reduction <= 12, "Lightness has finite deterministic reduction")
			check(not action.effects.has("barrier"), "Personal footwork remains distinct from Qin's ally barrier")


func _detached_definitions() -> void:
	var actor: Dictionary = {"id": "hero", "equipped_art": Arts.BASE_ART, "internal_unlocked": true, "lightness_unlocked": true}
	var before: Dictionary = actor.duplicate(true)
	var actions: Array = Skills.manual_actions(actor)
	check(actor == before, "Reading the catalog does not mutate actor input")
	check(actions.is_read_only(), "Returned category array is immutable")
	for action: Dictionary in actions:
		check(action.is_read_only() and action.effects.is_read_only(), "Nested descriptors and effects are immutable")
	var copied: Array = actions.duplicate(true)
	copied[1].effects.healing = 999
	check(Skills.manual_actions(actor)[1].effects.healing == 16, "A mutable scheduler copy cannot modify catalog definitions")
	actor.internal_unlocked = false
	check(actions[1].learned and not Skills.manual_actions(actor)[1].learned, "Previously generated snapshots retain their detached learning state")
