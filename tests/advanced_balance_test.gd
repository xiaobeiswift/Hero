extends SceneTree
const State = preload("res://scripts/game_state.gd")
func _init() -> void:
	var rows: Array[Dictionary] = []
	for school: String in State.SECTS:
		for target_level: int in [3, 5]:
			for gear: bool in [false, true]:
				for companion: String in ["", "沈青", "唐栖"]:
					for mode: String in ["并肩", "护后"]:
						var template = State.new()
						template.choose_sect(school)
						while template.level < target_level:
							template.gain_xp(template.xp_to_next())
						template.sect_trial_won = true
						assert(template.complete_sect_trial())
						if gear:
							template.coins = 200
							template.resources = {"iron":3, "timber":1, "cloth":3, "herb":1}
							assert(template.buy_equipment())
							assert(template.craft("refined_blade").valid)
							assert(template.craft("padded_armor").valid)
						for art: String in template.school_art_ids():
							if art == "照夜一线": continue
							var s = State.new()
							s.choose_sect(school)
							s.sect_rank = 2
							s.sect_merit = 5
							s.learn_art(art)
							assert(s.equip_art(art))
							s.attack=template.attack; s.defense=template.defense
							s.max_hp=template.max_hp; s.hp=s.max_hp-30
							s.max_qi=template.max_qi; s.qi=s.max_qi
							if companion=="沈青": s.companion_unlocked=true
							if companion=="唐栖": s.tangqi_unlocked=true
							s.active_companion=companion; s.formation=mode
							s.start_battle("archive_boss")
							var hp0:int=s.hp
							assert(s.battle_action("skill").valid)
							var direct:int=205-s.enemy_hp
							assert(s.battle_action("attack").valid)
							rows.append({"school":school,"level":target_level,"gear":gear,"companion":companion,"formation":mode,"art":art,"attack":s.attack,"defense":s.defense,"immediate":direct,"two_actions":205-s.enemy_hp,"hp_change":s.hp-hp0,"qi":s.qi})
	var file=FileAccess.open("user://hero-advanced-balance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t"));file.close()
	print("PASS: %d live-engine two-action balance fixtures across schools, levels 3/5, gear, companions, and formations" % rows.size())
	quit()
