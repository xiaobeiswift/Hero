extends SceneTree
const State=preload("res://scripts/game_state.gd")
var checks=0
var failures=0
func _init() -> void:
	for choice in ["open_records","protect_witness"]:
		var s=State.new()
		check(not s.begin_chapter_two(),"Chapter gated behind prior stories")
		s.quest_stage=6;s.side_stage=3;s.side_choice="rescue";s.side_reward_claimed=true
		check(s.begin_chapter_two() and s.chapter_two_stage==1,"Start chapter")
		check(not s.begin_chapter_two(),"Cannot restart chapter")
		check(not s.try_seal(2).valid,"Seal requires both clues")
		check(not s.add_archive_clue("unknown"),"Unknown clue rejected")
		check(s.add_archive_clue("inscription"),"Read inscription")
		var xp=s.xp
		check(not s.add_archive_clue("inscription") and s.xp==xp,"No duplicate clue XP")
		check(s.add_archive_clue("clerk"),"Meet clerk")
		for wrong in [-1,3,999]:check(not s.try_seal(wrong).valid,"Invalid seal option")
		check(s.try_seal(0).valid and s.seal_sequence.is_empty(),"Wrong first seal safely resets")
		check(s.try_seal(2).valid and s.seal_sequence==[2],"Correct first seal")
		check(s.try_seal(2).valid and s.seal_sequence.is_empty(),"Wrong repeated seal resets")
		check(not s.resolve_chapter_two(choice),"Cannot claim chapter completion early")
		s.try_seal(2);s.try_seal(0)
		var path="user://hero-chapter-test.json"
		check(s.save_game(path)==OK,"Save partial puzzle")
		var restored=State.new()
		check(restored.load_game(path)==OK and restored.seal_sequence==[2,0],"Puzzle prefix persists")
		s=restored
		check(s.try_seal(1).complete and s.chapter_two_stage==2,"Seal solved")
		check(not s.try_seal(1).valid,"Solved seal cannot replay")
		s.level=3;s.attack=26;s.max_hp=124;s.hp=124;s.defense=6;s.qi=6;s.companion_unlocked=true
		s.start_battle("archive_boss")
		check(s.enemy_hp==205 and s.enemy_base_attack==17,"Archive enemy stats")
		for attempt in range(50):
			if not s.battle_active:break
			if s.hp<45 and s.medicine>0:s.battle_action("item")
			elif s.turn%2==1:s.battle_action("guard")
			elif s.qi>=s.active_art_cost() and s.skill_cooldown==0:s.battle_action("skill")
			else:s.battle_action("attack")
		check(not s.battle_active and s.enemy_hp==0,"Boss winnable with completed-opening stats")
		check(s.mark_archive_victory() and s.chapter_two_stage==3,"Record victory")
		check(not s.mark_archive_victory(),"Victory stage cannot replay")
		var coins=s.coins
		check(s.resolve_chapter_two(choice) and s.chapter_two_stage==4 and s.coins==coins+65,"Resolve chapter exact reward")
		var snapshot=s.to_dict()
		check(not s.resolve_chapter_two(choice) and snapshot==s.to_dict(),"Completion cannot award twice")
		s.resources.timber=3
		coins=s.coins
		check(s.repair_bridge() and s.resources.timber==1 and s.coins==coins+20,"Repair consumes2wood and pays once")
		check(not s.repair_bridge(),"Bridge cannot be repaired repeatedly")
		s.map_id="frostbridge"
		check(s.save_game(path)==OK,"Save completed chapter")
		restored=State.new()
		check(restored.load_game(path)==OK and restored.to_dict()==s.to_dict(),"Chapter,map,bridge all round-trip")
		var doc={"version":1,"player":s.to_dict()}
		doc.player.archive_clues=[];doc.player.seal_sequence=[99]
		write_doc(path,doc)
		check(restored.load_game(path)==OK and restored.archive_clues.size()==2 and restored.seal_sequence==[2,0,1],"Completed save recovers prerequisite flags without regrant")
		var before=restored.to_dict()
		doc.player.chapter_two_ending=""
		write_doc(path,doc)
		check(restored.load_game(path)!=OK and restored.to_dict()==before,"Invalid completed ending rejected atomically")
		for key in ["chapter_two_stage","chapter_two_ending","archive_clues","seal_sequence","bridge_repaired"]:doc.player.erase(key)
		write_doc(path,doc)
		check(restored.load_game(path)==OK and restored.chapter_two_stage==0,"Older saves receive unstarted chapter")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures==0:print("PASS: %d chapter rule checks" % checks)
	else:push_error("FAIL: %d of %d chapter rule checks" % [failures,checks])
	quit(0 if failures==0 else 1)
func check(condition:bool,message:String) -> void:
	checks+=1
	if not condition:failures+=1;push_error(message)
func write_doc(path:String,doc:Dictionary) -> void:
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(doc));file.close()
