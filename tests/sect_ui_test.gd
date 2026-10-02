extends "res://tests/audit_second_region_test.gd"
func _run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.state=AuditState.new();game._new_game()
	game._interact("mentor")
	_check(_find_button(game.overlay,"开始受试")==null,"Unjoined hero receives guidance rather than inaccessible combat")
	game._close_modal()
	for school in ["听潮阁","照野堂","问石门"]:
		game._new_game();game.state.gain_xp(180);game.state.choose_sect(school);game.state.quest_stage=6;game.state.ending="守望"
		game.world.teleport(Vector2(650,720));game._refresh()
		_check(game.world._can_walk(game.world.player_pos),"Mentor reachable outside practice hall")
		await _key(KEY_E)
		_check(_find_button(game.overlay,"开始受试")!=null,"Real E interaction opens mentor")
		_press("开始受试")
		_check(game.current_screen=="battle" and game.state.equipped_art==game.state.sect_art(),"Trial restores hero and equips the appropriate school art")
		_check(game.battle_title.text.contains("验"),"Trial uses correct location heading")
		game._battle_action("attack");game._battle_action("skill")
		for step in range(80):
			if not game.state.battle_active:break
			if game.state.hp<45 and game.state.medicine>0:game._battle_action("item")
			elif game.state.qi>=game.state.active_art_cost() and game.state.skill_cooldown==0:game._battle_action("skill")
			elif game.state.turn%2==1:game._battle_action("guard")
			else:game._battle_action("attack")
		_check(game.state.sect_trial_won and _find_button(game.overlay,"领取内门荐记")!=null,"Each school's real battle proof unlocks earned result")
		_press("稍后领取");game._load()
		_check(game.state.sect_rank==1 and game.state.sect_trial_won,"Postponed promotion survives save and load")
		_check(game.world._quest_target_id()=="mentor" and game.quest_label.text.contains("荐记"),"Pending promotion has a navigable world and journal hint")
		game._interact("mentor")
		var defense=game.state.defense;var qi=game.state.max_qi
		_press("领取内门荐记")
		_check(game.state.sect_rank==2 and game.state.defense==defense+1 and game.state.max_qi==qi+1,"Claim grants exact rank benefits")
		_check(game.sect_label.text.contains("内门"),"Character panel reflects earned rank")
		var before=game.state.to_dict()
		game._interact("mentor")
		_check(_find_button(game.overlay,"开始受试")==null and _find_button(game.overlay,"领取内门荐记")==null,"Completed trial cannot be replayed for duplicate permanent bonuses")
		_press("研读武学")
		var rank_label=game.overlay.find_child("MartialRank",true,false)
		_check(rank_label!=null and rank_label.text=="内门弟子 · 考绩 3","Martial panel shows the earned rank and exact merit")
		game._close_modal();game._load()
		_check(game.state.to_dict()==before,"Rank survives subsequent menu and reload without duplication")
	# A brute-force win earns ordinary encounter rewards but not a school rank.
	game._new_game();game.state.gain_xp(180);game.state.choose_sect("照野堂");game.state.attack=1000
	game._interact("mentor");_press("开始受试")
	for step in range(8):
		if not game.state.battle_active:break
		game._battle_action("attack")
	_check(not game.state.sect_trial_won and _find_button(game.overlay,"再试一次")!=null,"Wrong-method win shows actionable retry")
	_press("再试一次")
	_check(game.state.battle_active and game.state.hp==game.state.max_hp,"Retry restores health and remains playable")
	game._battle_action("flee")
	_check(game.state.sect_rank==1 and not game.state.sect_trial_won,"Retreat never promotes")
	game._stop_audio();DirAccess.remove_absolute(ProjectSettings.globalize_path(AuditState.AUDIT_PATH))
	game.queue_free();await process_frame
	if failures==0:print("PASS: %d sect UI checks" % checks)
	else:push_error("FAIL: %d of %d sect UI checks" % [failures,checks])
	quit(0 if failures==0 else 1)
