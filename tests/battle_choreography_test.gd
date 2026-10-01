extends SceneTree
## Isolated deterministic animation contract: no saves, scene mutation or timing waits.
const Art = preload("res://scripts/battle_art.gd")
const State = preload("res://scripts/game_state.gd")
var checks: int = 0
var failures: int = 0
var completions: int = 0
var impacts: Array = []
var art

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _run() -> void:
	art = Art.new()
	root.add_child(art)
	art.set_process(false)
	art.presentation_finished.connect(func(): completions += 1)
	art.impact_presented.connect(func(target,amount): impacts.append([target,amount]))
	_check(not art.is_presenting(), "Fresh stage is idle")
	_check(art.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Artwork never consumes button input")
	art.hit("attack")
	_check(art.is_presenting(), "Legacy hit(kind) starts a presentation")
	_check(not art.presentation_details.has("enemy_damage"), "Legacy hit never fabricates a number")
	_check(not art.presentation_details.counter, "Missing outcomes do not fabricate an enemy counter")
	art._process(art.get_presentation_duration()+0.1)
	_check(not art.is_presenting() and completions==1, "Legacy presentation completes once")
	art._process(2)
	_check(completions==1, "Idle frames never repeat completion")
	art.hit("attack",{"valid":false,"message":"rejected"})
	_check(not art.is_presenting(), "Rejected results cannot start action visuals")

	var model = State.new()
	model.start_battle("training")
	var result: Dictionary = model.battle_action("attack")
	var rule_after: Dictionary = model.to_dict().duplicate(true)
	art.hit("attack",result)
	_check(art.presentation_details.enemy_damage == model.attack, "Attack number comes from this turn's actual rule result")
	_check(art.presentation_details.player_damage == model.enemy_base_attack-model.defense, "Counter number comes from the enemy's result log")
	_check(art.presentation_details.counter, "Accepted nonlethal attack includes enemy counter")
	_check(is_equal_approx(art.get_presentation_duration(),1.34), "Counter exchange reserves its full sequence")
	art.action_time=0.12
	_check(art._pose().windup>0.8 and art._pose().x<0, "Windup visibly retracts player and sword")
	art.action_time=0.30
	_check(art._pose().x>350, "Dash physically closes the enemy distance")
	art.action_time=0.36
	_check(art._pose().strike>0.8 and art._pose(true).recoil>0.8, "Cut and victim recoil overlap at impact")
	art.action_time=0.66
	_check(absf(art._pose().x)<1, "Player returns to their original position before the counter")
	art.action_time=0.86
	_check(art._pose(true).x < -340, "Enemy counter closes distance in the reverse direction")
	art.action_time=0.91
	_check(art._pose().recoil>0.7, "Enemy contact visibly recoils the player")
	art.action_time=1.28
	_check(absf(art._pose(true).x)<1, "Enemy returns home before controls unlock")
	art.action_time=0
	impacts.clear()
	art._process(0.31)
	_check(impacts.is_empty(), "No damage number event appears before impact")
	art._process(0.02)
	_check(impacts.size()==1 and impacts[0]==["enemy",16], "Player damage event fires at sword contact")
	art._process(0.56)
	_check(impacts.size()==2 and impacts[1]==["player",5], "Counter event fires at its separate impact")
	art._process(1)
	_check(completions==2 and not art.is_presenting(), "Full exchange emits one terminal signal")
	_check(model.to_dict()==rule_after, "Animation cannot mutate model or persistent state")

	model.hp=50
	result=model.battle_action("item")
	art.hit("item",result)
	_check(art.presentation_details.healing==45, "Medicine displays gross healing rather than misleading net health delta")
	_check(art.presentation_details.player_damage==15 and art.presentation_details.counter, "Medicine keeps separate healing and incoming damage")
	art.action_time=0.25
	_check(art._pose().heal>0.9, "Medicine has a dedicated hand-to-mouth pose")
	art.reset_presentation()
	_check(not art.is_presenting() and art.presentation_details.is_empty() and art.flash==0, "Reset clears every transient presentation field")
	_check(completions==3, "Cancel/reset releases its waiter exactly once")
	art.reset_presentation()
	_check(completions==3, "Resetting an idle presentation does not emit a second signal")
	result=model.battle_action("guard")
	art.hit("guard",result)
	_check(art.presentation_details.guarded and art.presentation_details.player_damage==2, "Guard presents the actual rounded damage after mitigation")
	art.action_time=0.88
	_check(art._pose().guard>0.9, "Guard pose remains held through incoming contact")

	model = State.new()
	model.choose_sect("照野堂")
	model.equip_art(model.sect_art())
	model.hp=30; model.qi=6
	model.start_battle("training")
	model.hp=30
	result=model.battle_action("skill")
	art.hit("skill",result)
	_check(art.presentation_details.has("art_name") and art.presentation_details.art_name==model.equipped_art, "Skill name uses accepted art result")
	_check(int(art.presentation_details.get("healing",0))>0, "Healing martial art carries its own truthful recovery")

	art.hit("attack",{"valid":true,"log":["你使出平击，基础 16 + 蓄锋 9，经敌方架势后造成 22 点伤害，凝聚 2 点真气。","唐栖以短尺拆招，追加4点伤害；为你赢得换气空隙，回复1真气。","沈青与你换步照应，恢复2点气血。","敌方使出疾刃，你受到 3 点伤害。"]})
	_check(art.presentation_details.enemy_damage==22 and art.presentation_details.companion_damage==4, "Bonus descriptions cannot inflate direct damage; companion damage stays separate")
	_check(art.presentation_details.healing==2, "Unspaced companion healing parses correctly")
	art._process(2)
	_check(impacts.slice(-4)==[["enemy",22],["companion",4],["support_healing",2],["player",3]], "A long frame emits crossed impacts once in chronological order")

	model = State.new(); model.start_battle("training");model.enemy_hp=1;model.hp=10;model.xp=50
	result=model.battle_action("attack")
	art.hit("attack",result)
	_check(art.presentation_details.enemy_defeated and not art.presentation_details.counter, "Finishing hit never invents retaliation")
	_check(not art.presentation_details.has("healing"), "Level-up restoration is not mislabeled as combat healing")
	art.action_time=0.94
	_check(art._pose(true).defeat>0.7, "Finishing blow remains visible as an enemy stagger")
	model = State.new();model.start_battle("training");model.hp=1
	result=model.battle_action("guard")
	art.hit("guard",result)
	_check(art.presentation_details.player_defeated and art.presentation_details.player_damage==2, "Defeat/restoration preserves actual incoming hit rather than a health delta")
	art.action_time=1.2
	_check(art._pose().defeat>0.9, "Defeat has a separate player recovery/stagger pose")
	model = State.new();model.start_battle("training")
	art.hit("flee",model.battle_action("flee"))
	_check(not art.presentation_details.counter and not art.presentation_details.player_defeated, "Escape has neither fake damage nor defeat")
	art.action_time=0.6
	_check(art._pose().x < -310, "Escape visibly carries the hero off stage")
	art.action_time=0
	art._process(0.72)
	_check(not art.is_presenting(), "Escape always releases the awaiting caller")
	art.hit("skill",{"enemy_damage":31,"player_damage":8,"healing":9,"guarded":true,"art_name":"测试"})
	_check(art.presentation_details.counter and art.presentation_details.enemy_damage==31 and art.presentation_details.guarded, "Explicit presentation payload is supported")
	art.reset_presentation()
	art.free()
	print("%s: %d battle choreography checks" % ["PASS" if failures==0 else "FAIL",checks])
	quit(0 if failures==0 else 1)
