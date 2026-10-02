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
		prepare(ending=="protect_witness")
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
		interact_near("chapter_archive");_press("仓印")
		_check(game.state.chapter_two_stage==2 and _find_button(game.overlay,"请他让路")!=null,"Final seal unlocks the encounter")
		_test_archive_entry_callbacks()
		game._close_modal();move_near("chapter_archive")
		await key_press(KEY_E)
		_check(_find_button(game.overlay,"请他让路")!=null,"Real exploration E opens nearby archive challenge")
		await key_press(KEY_1)
		_check_archive_party()
		var panel=game.overlay.get_meta("party_battle",null)
		if is_instance_valid(panel):
			panel.art.set_process(false)
			await key_press(KEY_ESCAPE)
			_check(not panel.pending.is_empty() and panel.pending.get("accepted",false),"Real Escape accepts the party flee transaction")
			panel.art._process(panel.art.get_presentation_duration()+0.1)
		_check(game.state.chapter_two_stage==2 and game.state.map_id=="frostbridge","Flee preserves unlocked warehouse")
		var battle_coins:int=game.state.coins
		var battle_xp:int=total_xp()
		interact_near("chapter_archive");_press("请他让路")
		_check_archive_party()
		win()
		_check(game.state.chapter_two_stage==3 and game.state.chapter_two_ending.is_empty(),"Archive victory advances to unresolved ending choice")
		_check(game.state.coins==battle_coins+40 and total_xp()==battle_xp+80,"Archive victory awards exactly eighty XP and forty coins")
		_check(game.state.party_settlement.get("outcome")=="win" and game.state.party_settlement.get("reward_xp")==80 and game.state.party_settlement.get("coin_change")==40,"Real party settlement records only archive battle rewards")
		game._close_modal();game._load()
		_check(game.state.chapter_two_stage==3 and game.state.chapter_two_ending.is_empty() and game.state.coins==battle_coins+40 and total_xp()==battle_xp+80,"Victory saves stage three and resources before any ending choice")
		_test_ending_callbacks()
		interact_near("chapter_host")
		var repeat_choice:Callable=game.modal_actions[0 if ending=="open_records" else 1]
		var coins:int=game.state.coins
		xp=total_xp()
		_press("公示原账" if ending=="open_records" else "隐去姓名")
		_check(game.state.chapter_two_stage==4 and game.state.chapter_two_ending==ending and game.state.coins==coins+65 and total_xp()==xp+100,"Both ending branches separately pay exactly one hundred XP and sixty-five coins")
		var finished:Dictionary=game.state.to_dict().duplicate(true)
		repeat_choice.call()
		_check(game.state.to_dict()==finished,"Repeated ending callback cannot change or reward the completed branch")
		interact_near("chapter_host")
		_check(_find_button(game.overlay,"公示原账")==null,"Completed ending cannot repeat")
		game._close_modal()
		game._interact("frost_timber");_press("小心采集")
		_check(game.state.resources.timber==3,"Material node grants three wood")
		game._interact("frost_timber")
		var depleted_text=""
		for label in game.overlay.find_children("*","Label",true,false):depleted_text+=label.text
		_check(_find_button(game.overlay,"小心采集")==null and depleted_text.contains("已采集"),"Used material node explains depletion without offering a false reward")
		game._close_modal();game.chapter_story.collect("frost_timber")
		_check(game.state.resources.timber==3,"Direct repeat collection still cannot replenish material")
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
func prepare(with_shen:bool) -> void:
	game._new_game()
	game.state.quest_stage=6;game.state.ending="守望"
	game.state.side_stage=3;game.state.side_choice="rescue";game.state.side_reward_claimed=true
	game.state.side_found.assign(["boatman","ledger"]);game.state.side_clues=2
	game.state.gain_xp(180);game.state.choose_sect("听潮阁");game.state.medicine=5
	if with_shen:game.state.recruit_companion()
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
	for attempt in range(120):
		if not game.state.battle_active:break
		if game.current_screen!="party_battle" or not _drive_party_action():break
	_check(not game.state.battle_active and game.state.party_settlement.get("outcome")=="win","Archive fight wins through real PartyUI accepted actions and renderer completion")

func move_near(id:String) -> void:
	_check(game.world.interactables.has(id),"Guarded chapter interaction exists on the current map: "+id)
	if game.world.interactables.has(id):
		game.world.teleport(game.world.interactables[id].pos);game._process(0)

func interact_near(id:String) -> void:
	if game.active_modal:game._close_modal()
	move_near(id);game._interact(id)

func key_press(key:Key) -> void:
	var event=InputEventKey.new()
	event.keycode=key;event.physical_keycode=key;event.pressed=true
	Input.parse_input_event(event);await process_frame
	event.pressed=false;Input.parse_input_event(event);await process_frame

func total_xp() -> int:
	return game.state.xp+30*game.state.level*(game.state.level-1)

func _check_archive_party() -> void:
	var snapshot:Dictionary=game.state.party_battle_snapshot()
	_check(game.current_screen=="party_battle" and snapshot.get("encounter_id")=="archive_boss","Ordinary archive challenge enters the actual party controller")
	if snapshot.is_empty():return
	_check(snapshot.enemies.size()==1 and snapshot.enemies[0].max_hp==205 and snapshot.enemies[0].attack==17 and snapshot.enemies[0].heavy_attack==31,"Archive snapshot preserves Han Yan's actual 205HP and seventeen/thirty-one damage")
	var ids:Array=[]
	for actor:Dictionary in snapshot.actors:ids.append(actor.id)
	_check(ids==(["hero","shen"] if game.state.companion_unlocked else ["hero"]) and not game.state.tangqi_unlocked and not game.state.qin_recruited(),"Archive uses only the hero and optionally earned Shen, before Tang or Qin recruitment")

func _test_archive_entry_callbacks() -> void:
	var entry:Callable=game.modal_actions[0]
	game._close_modal()
	var before:Dictionary=game.state.to_dict().duplicate(true)
	entry.call()
	_check(not game.state.battle_active and game.state.to_dict()==before and not game.active_modal,"Canceled archive challenge cannot start or reward a battle")
	interact_near("chapter_archive");entry=game.modal_actions[0]
	game._show_journal();var generation:int=game.modal_generation
	before=game.state.to_dict().duplicate(true);entry.call()
	_check(not game.state.battle_active and game.active_modal and game.modal_generation==generation and game.state.to_dict()==before,"Older archive callback preserves a newer journal modal")
	interact_near("chapter_archive");entry=game.modal_actions[0]
	game.world.teleport(game.world.interactables.chapter_host.pos);game._process(0)
	before=game.state.to_dict().duplicate(true);entry.call()
	_check(not game.state.battle_active and game.state.to_dict()==before,"Archive callback rejects after leaving the actual warehouse")
	game._close_modal()

func _test_ending_callbacks() -> void:
	interact_near("chapter_host")
	var finish:Callable=game.modal_actions[0]
	game._close_modal();var before:Dictionary=game.state.to_dict().duplicate(true)
	finish.call()
	_check(game.state.to_dict()==before and not game.active_modal,"Canceled ending cannot resolve or award the chapter")
	interact_near("chapter_host");finish=game.modal_actions[1]
	game._show_map();var generation:int=game.modal_generation
	before=game.state.to_dict().duplicate(true);finish.call()
	_check(game.state.to_dict()==before and game.active_modal and game.modal_generation==generation,"Older ending callback preserves a newer map modal without resolving or rewarding")
	interact_near("chapter_host");finish=game.modal_actions[0]
	game.world.teleport(game.world.interactables.chapter_archive.pos);game._process(0)
	before=game.state.to_dict().duplicate(true);finish.call()
	_check(game.state.to_dict()==before and game.state.chapter_two_stage==3,"Ending callback rejects after leaving the actual innkeeper")
	game._close_modal()

func _drive_party_action() -> bool:
	var before:Dictionary={"coins":game.state.coins,"xp":total_xp(),"stage":game.state.chapter_two_stage,"ending":game.state.chapter_two_ending}
	var panel=game.overlay.get_meta("party_battle",null)
	if not is_instance_valid(panel):
		_check(false,"Archive fight retains its real party controller")
		return false
	panel.art.set_process(false)
	var snapshot:Dictionary=game.state.party_battle_snapshot()
	var actor:Dictionary={}
	for candidate:Dictionary in snapshot.actors:
		if candidate.id==snapshot.active_actor_id:actor=candidate
	if actor.is_empty():
		_check(false,"Archive fight has a living selected actor")
		return false
	var chosen:Dictionary={};var target:String=""
	for action:Dictionary in actor.actions:
		if action.id=="attack" and action.available:chosen=action
	for action:Dictionary in actor.actions:
		if action.available and action.category=="martial" and action.target_team=="enemy":chosen=action
	for action:Dictionary in actor.actions:
		if action.available and action.category=="martial" and action.target_team=="ally" and action.effects.get("healing",0)>0:
			for ally:Dictionary in snapshot.actors:
				if action.valid_target_ids.has(ally.id) and ally.hp<=ally.max_hp-20:chosen=action;target=ally.id
	for action:Dictionary in actor.actions:
		if action.id=="item" and action.available and actor.hp<45:chosen=action
	if chosen.is_empty():
		_check(false,"Archive actor exposes a legal action")
		return false
	panel.request_command(actor.id,chosen.id)
	if not panel.pending_action.is_empty():panel.select_target(target if not target.is_empty() else String(chosen.valid_target_ids[0]))
	_check(not panel.pending.is_empty() and panel.pending.get("accepted",false),"Archive action accepted by actual PartyUI")
	if panel.pending.is_empty():return false
	_check(game.state.coins==before.coins and total_xp()==before.xp and game.state.chapter_two_stage==before.stage and game.state.chapter_two_ending==before.ending,"Accepted archive action leaves rewards and chapter untouched before renderer completion")
	panel.art._process(panel.art.get_presentation_duration()+0.1)
	return true
