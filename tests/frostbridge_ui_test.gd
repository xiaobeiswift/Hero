extends "res://tests/audit_progression_test.gd"
func _run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.state=AuditState.new();game._new_game()
	game._interact("exit_frostbridge")
	_check(_find_button(game.overlay,"前往霜桥驿")==null,"Chapter3 region gated before second-region ending")
	game._close_modal()
	for ending in ["open_records","protect_witness"]:
		prepare()
		game._interact("exit_frostbridge");_press("前往霜桥驿")
		_check(game.state.map_id=="frostbridge" and game.world.map_id=="frostbridge" and game.state.chapter_two_stage==1,"New region arrival synchronizes map and chapter")
		await process_frame
		reachability()
		game._interact("chapter_archive")
		_check(_find_button(game.overlay,"驿印")==null,"Seal not offered before clues")
		game._close_modal()
		game._interact("chapter_clerk");_press("记下文书线索")
		game._interact("chapter_inscription");_press("拓下碑文")
		_check(game.state.archive_clues.size()==2,"Both clue interactions recorded")
		var xp=game.state.xp
		game._interact("chapter_inscription");_press("拓下碑文")
		_check(game.state.xp==xp,"Repeated inscription cannot farm XP")
		game._interact("chapter_archive");_press("驿印")
		_check(game.state.seal_sequence.is_empty(),"Incorrect seal input safely resets")
		_press("水印");_press("驿印")
		game._close_modal();game._load()
		_check(game.state.seal_sequence==[2,0] and game.world.map_id=="frostbridge","Partial puzzle saved through dismissal and reload")
		game._interact("chapter_archive");_press("仓印")
		_check(game.state.chapter_two_stage==2 and _find_button(game.overlay,"请他让路")!=null,"Final seal unlocks the encounter")
		_press("请他让路")
		game._battle_action("flee")
		_check(game.state.chapter_two_stage==2 and game.state.map_id=="frostbridge","Flee preserves unlocked warehouse")
		game._interact("chapter_archive");_press("请他让路")
		win()
		_check(game.state.chapter_two_stage==3,"Archive victory advances narrative")
		game._close_modal()
		game._interact("chapter_host")
		var coins=game.state.coins
		_press("公示原账" if ending=="open_records" else "隐去姓名")
		_check(game.state.chapter_two_stage==4 and game.state.chapter_two_ending==ending and game.state.coins==coins+65,"Both ending branches pay exactly once")
		game._interact("chapter_host")
		_check(_find_button(game.overlay,"公示原账")==null,"Completed ending cannot repeat")
		game._close_modal()
		game._interact("frost_timber");_press("小心采集")
		_check(game.state.resources.timber==3,"Material node grants three wood")
		game._interact("frost_timber");_press("小心采集")
		_check(game.state.resources.timber==3,"Material node does not replenish on repeat")
		_check(not game.world._can_walk(Vector2(835,800)),"Broken south bridge is visibly/nonphysically closed")
		game._interact("bridge_worker");_press("交出木料 ×2")
		_check(game.state.bridge_repaired and game.world._can_walk(Vector2(835,800)) and game.state.resources.timber==1,"Repair immediately opens real collision shortcut")
		game.world.teleport(Vector2(835,800));game._save();game._load()
		_check(game.world.player_pos==Vector2(835,800) and game.world.bridge_repaired,"Load on repaired bridge preserves exact safe position")
		var snapshot=game.state.to_dict()
		game._interact("bridge_worker")
		_check(_find_button(game.overlay,"交出木料 ×2")==null,"Repair reward cannot repeat")
		game._close_modal();game._show_map();game._close_modal();game._show_journal();game._close_modal()
		_check(game.state.to_dict()==snapshot,"Read-only maps/journal do not modify completed state")
		game._interact("return_sluice")
		_check(game.state.map_id=="sluice" and game.state.chapter_two_stage==4,"Return travel preserves finished chapter")
		game._interact("exit_frostbridge");_press("前往霜桥驿")
		_check(game.state.chapter_two_stage==4 and game.state.resources.timber==1,"Re-entry cannot reset chapter or gathered nodes")
	game._stop_audio()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AuditState.AUDIT_PATH))
	game.queue_free();await process_frame
	if failures==0:print("PASS: %d frostbridge UI checks" % checks)
	else:push_error("FAIL: %d of %d frostbridge UI checks" % [failures,checks])
	quit(0 if failures==0 else 1)
func prepare() -> void:
	game._new_game()
	game.state.quest_stage=6;game.state.ending="守望"
	game.state.side_stage=3;game.state.side_choice="rescue";game.state.side_reward_claimed=true
	game.state.side_found.assign(["boatman","ledger"]);game.state.side_clues=2
	game.state.gain_xp(180);game.state.choose_sect("听潮阁");game.state.recruit_companion();game.state.medicine=5
	game._process(0)
func reachability() -> void:
	var queue:Array[Vector2]=[Vector2(190,500)];var visited={queue[0]:true};var cursor=0
	while cursor<queue.size():
		var p=queue[cursor];cursor+=1
		for offset in [Vector2(20,0),Vector2(-20,0),Vector2(0,20),Vector2(0,-20)]:
			var next=p+offset
			if not visited.has(next) and game.world._can_walk(next):visited[next]=true;queue.append(next)
	for id in game.world.interactables:
		var reachable=false
		for p in visited:
			if p.distance_to(game.world.interactables[id].pos)<70:reachable=true;break
		_check(reachable,"Third-map target reachable without repairing optional bridge: "+id)
func win() -> void:
	for attempt in range(60):
		if not game.state.battle_active:return
		if game.state.hp<50 and game.state.medicine>0:game._battle_action("item")
		elif game.state.turn%2==1:game._battle_action("guard")
		elif game.state.qi>=game.state.active_art_cost() and game.state.skill_cooldown==0:game._battle_action("skill")
		else:game._battle_action("attack")
	_check(false,"Archive fight resolves")
