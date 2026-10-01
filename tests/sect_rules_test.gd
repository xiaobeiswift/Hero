extends SceneTree
const State=preload("res://scripts/game_state.gd")
var checks=0
var failures=0
func _init() -> void:
	for school in ["听潮阁","照野堂","问石门"]:
		var s=State.new()
		check(not s.can_take_sect_trial(),"Unjoined hero cannot take trial")
		s.choose_sect(school)
		check(s.sect_rank==1 and not s.can_take_sect_trial(),"Trial requires sufficient level")
		s.gain_xp(180)
		check(s.can_take_sect_trial(),"Level3 member eligible")
		check(not s.complete_sect_trial(),"No promotion before earned result")
		s.equip_art(s.sect_art());s.start_battle("sect_trial")
		check(s.enemy_hp==180,"Dedicated trial encounter")
		s.battle_action("attack");s.battle_action("skill")
		check(s._trial_art_used,"Trial registers correct school art")
		if school=="照野堂":check(s._trial_healing>0,"Healing criterion counts real recovery")
		if school=="问石门":check(s._trial_guarded_heavy,"Defensive school must block a heavy strike with its art")
		for step in range(80):
			if not s.battle_active:break
			if s.hp<45 and s.medicine>0:s.battle_action("item")
			elif s.qi>=s.active_art_cost() and s.skill_cooldown==0:s.battle_action("skill")
			elif s.turn%2==1:s.battle_action("guard")
			else:s.battle_action("attack")
		check(not s.battle_active and s.enemy_hp==0 and s.sect_trial_won,"Winning with criterion earns promotion receipt")
		var path="user://hero-sect-audit.json"
		check(s.save_game(path)==OK,"Save pending earned promotion")
		var t=State.new();check(t.load_game(path)==OK and t.sect_trial_won,"Pending result survives reload")
		var defense=t.defense;var qi=t.max_qi
		check(t.complete_sect_trial() and t.sect_rank==2 and t.defense==defense+1 and t.max_qi==qi+1 and t.sect_merit==3,"Rank2 applies exact permanent growth once")
		var before=t.to_dict()
		check(not t.complete_sect_trial() and before==t.to_dict(),"Promotion cannot stack bonuses")
		check(not t.can_take_sect_trial(),"Completed promotion trial closes")
		t.save_game(path);var again=State.new();again.load_game(path)
		check(t.to_dict()==again.to_dict(),"Rank and bonuses survive reload without reapplication")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		# Pure force does not satisfy a school-specific examination.
		s=State.new();s.gain_xp(180);s.choose_sect(school);s.attack=1000;s.start_battle("sect_trial");s.battle_action("attack")
		check(s.enemy_hp==0 and not s.sect_trial_won and not s.complete_sect_trial(),"Winning without school technique does not promote")
		check(s.can_take_sect_trial(),"Unqualified win remains retryable")
		# Defeat/flee discard in-battle proof; they never award a promotion.
		s.attack=22;s.heal_rest();s.equip_art(s.sect_art());s.start_battle("sect_trial");s.battle_action("attack");s.battle_action("skill");s.battle_action("flee")
		check(not s.sect_trial_won and not s.complete_sect_trial(),"Flee cannot convert partial proof into promotion")
		s.start_battle("sect_trial")
		check(not s._trial_art_used and s._trial_healing==0 and not s._trial_guarded_heavy,"Next attempt clears proof counters")
		s.battle_action("flee")
	# Full-health healing and ordinary guarding are not the tested technique.
	var healer=State.new();healer.gain_xp(180);healer.choose_sect("照野堂");healer.equip_art(healer.sect_art());healer.start_battle("sect_trial");healer.battle_action("skill")
	check(healer._trial_healing==0,"Full-health skill does not count as healing")
	var guarder=State.new();guarder.gain_xp(180);guarder.choose_sect("问石门");guarder.start_battle("sect_trial");guarder.battle_action("attack");guarder.battle_action("guard")
	check(not guarder._trial_guarded_heavy,"Generic guard is not school-art proof")
	if failures==0:print("PASS: %d sect progression checks" % checks)
	else:push_error("FAIL: %d of %d sect checks" % [failures,checks])
	quit(0 if failures==0 else 1)
func check(value:bool,message:String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
