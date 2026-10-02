extends SceneTree
## Independent companion increment audit; never writes the player's save.
const State=preload("res://scripts/game_state.gd")
const PATH="user://hero-independent-companion-rules.json"
var checks=0
var failures=0
func _init() -> void:
	_test_gates_and_routes()
	_test_party_and_combat()
	_test_save_migration()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	if failures==0:print("PASS: %d independent companion rules checks" % checks)
	else:push_error("FAIL: %d of %d independent companion rules checks" % [failures,checks])
	quit(0 if failures==0 else 1)
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures+=1;push_error(label)
func completed_chapter():
	var s=State.new()
	s.quest_stage=6;s.side_stage=3;s.side_choice="rescue";s.side_reward_claimed=true;s.side_found.assign(["boatman","ledger"]);s.side_clues=2
	s.chapter_two_stage=4;s.chapter_two_ending="protect_witness";s.bridge_repaired=true;s.archive_clues.assign(["clerk","inscription"]);s.seal_sequence.assign([2,0,1])
	s.level=5;s.xp=0;s.max_hp=1000;s.hp=1000;s.max_qi=6;s.qi=6
	return s
func recruited_tang():
	var s=completed_chapter()
	s.begin_tangqi_quest();s.recover_craft_notes();s.resolve_tangqi_quest("teach");s.recruit_tangqi()
	return s
func write_data(data:Dictionary,version:int=4) -> void:
	var file=FileAccess.open(PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":version,"player":data}));file.close()
func _test_gates_and_routes() -> void:
	for chapter in range(5):
		for repaired in [false,true]:
			var s=State.new();s.chapter_two_stage=chapter;s.bridge_repaired=repaired
			var before=s.to_dict();var expected=chapter==4 and repaired
			check(s.begin_tangqi_quest()==expected,"Personal quest requires both prerequisites: chapter %d repaired %s" % [chapter,str(repaired)])
			check(s.tangqi_stage==1 if expected else s.to_dict()==before,"Gate changes only eligible state")
	for choice in ["teach","preserve"]:
		var s=completed_chapter();var before=s.to_dict()
		check(not s.recover_craft_notes() and not s.resolve_tangqi_quest(choice) and not s.recruit_tangqi() and s.to_dict()==before,"Out-of-order notebook, ending and recruitment are atomic")
		check(s.begin_tangqi_quest(),"Begin quest: "+choice)
		before=s.to_dict()
		check(not s.begin_tangqi_quest() and not s.resolve_tangqi_quest(choice) and not s.recruit_tangqi() and s.to_dict()==before,"Repeated begin and skipped notebook cannot advance")
		check(s.recover_craft_notes() and s.tangqi_stage==2,"Recover notebook")
		before=s.to_dict()
		check(not s.recover_craft_notes() and not s.resolve_tangqi_quest("invalid") and not s.recruit_tangqi() and s.to_dict()==before,"Duplicate notebook and invalid choice cannot reward")
		check(s.resolve_tangqi_quest(choice) and s.tangqi_stage==3 and s.tangqi_choice==choice,"Resolve notebook: "+choice)
		check(s.xp==50 and s.resources.cloth==(2 if choice=="teach" else 0) and s.resources.iron==(2 if choice=="preserve" else 0),"Route grants exactly intended materials and XP")
		check(not s.tangqi_unlocked and s.available_companions().is_empty(),"Resolution can be retained without immediate recruitment")
		before=s.to_dict()
		check(not s.resolve_tangqi_quest("teach") and not s.resolve_tangqi_quest("preserve") and s.to_dict()==before,"Ending cannot change or pay twice")
		check(s.recruit_tangqi() and s.current_companion()=="唐栖" and s.available_companions()==["唐栖"],"Tang can be first companion")
		before=s.to_dict()
		check(not s.recruit_tangqi() and s.to_dict()==before,"Recruitment is one-time and has no additional reward")
		s.reset_game()
		check(s.tangqi_stage==0 and s.tangqi_choice=="" and not s.tangqi_unlocked and s.current_companion()=="" and s.available_companions().is_empty(),"Reset removes all companion progress")
	var capped=completed_chapter();capped.resources.cloth=9998
	capped.begin_tangqi_quest();capped.recover_craft_notes();capped.resolve_tangqi_quest("teach")
	check(capped.resources.cloth==9999,"Reward respects inventory cap")
	for stage in range(4):
		var s=completed_chapter();s.tangqi_stage=stage;s.tangqi_choice="teach" if stage==3 else ""
		s.start_battle();var before=s.to_dict()
		check(not s.begin_tangqi_quest() and not s.recover_craft_notes() and not s.resolve_tangqi_quest("teach") and not s.recruit_tangqi() and s.to_dict()==before,"Battle blocks narrative mutations at stage %d" % stage)
func _test_party_and_combat() -> void:
	var s=recruited_tang()
	check(not s.companion_unlocked and s.set_formation("护后"),"Tang-only roster can use formations")
	check(s.recruit_companion() and s.current_companion()=="唐栖" and s.available_companions()==["沈青","唐栖"],"Recruiting Shen later retains active Tang and both ownerships")
	check(s.select_companion("沈青") and s.current_companion()=="沈青","Select owned Shen")
	var before=s.to_dict()
	check(not s.select_companion("unknown") and s.to_dict()==before,"Unknown selection is atomic")
	s.select_companion("唐栖");s.set_formation("并肩");s.start_battle();s.enemy_hp=1000;s.qi=0
	before=s.to_dict()
	check(not s.select_companion("沈青") and s.to_dict()==before,"Cannot change active companion during battle")
	s.battle_action("attack")
	check(s.enemy_hp==984 and s.qi==2 and s._companion_attack_count==1,"First attack does not trigger Tang support")
	var turn=s.turn;var hp=s.hp
	check(not s.battle_action("skill").valid and not s.battle_action("invalid").valid and s.turn==turn and s.hp==hp and s._companion_attack_count==1,"Rejected actions preserve support cadence")
	s.battle_action("guard")
	check(s._companion_attack_count==1 and s.qi==3,"Guard does not advance support cadence")
	s.battle_action("skill")
	check(s.enemy_hp==940 and s.qi==1 and s._companion_attack_count==2,"Second offensive action adds four damage and one qi after skill cost")
	s.battle_action("flee");s.start_battle();s.enemy_hp=1000;s.qi=6
	s.battle_action("attack");s.battle_action("attack")
	check(s.qi==6 and s.enemy_hp==964,"Tang qi cannot overflow and new battle resets cadence")
	s.battle_action("flee");s.set_formation("护后");s.heal_rest();s.start_battle();s.enemy_hp=1000
	hp=s.hp;s.battle_action("attack")
	check(s.hp==hp-5 and s.enemy_hp==984,"Tang rear formation does not reduce light damage or attack")
	hp=s.hp;s.battle_action("attack")
	check(s.hp==hp-10 and s.enemy_hp==968,"Tang reduces heavy damage by five without offense assist")
	s.battle_action("guard");hp=s.hp;s.battle_action("guard")
	check(s.hp==hp-1,"Tang rear support applies after guard, with one-damage floor")
	s.battle_action("flee");s.select_companion("沈青");s.heal_rest();s.start_battle();s.enemy_hp=1000
	hp=s.hp;s.battle_action("attack")
	check(s.hp==hp-3,"Shen still reduces light damage by two")
	hp=s.hp;s.battle_action("attack")
	check(s.hp==hp-13,"Shen still reduces heavy damage by two")
	s.battle_action("flee");s.select_companion("唐栖");s.set_formation("并肩");s.heal_rest();s.start_battle();s.enemy_hp=1000
	s.battle_action("attack");s.enemy_hp=20;hp=s.hp;var wins=s.victories
	var result=s.battle_action("attack")
	check(result.won and s.enemy_hp==0 and s.victories==wins+1 and s.hp==hp,"Tang's finishing assist prevents retaliation and rewards once")
	s.start_battle();s.enemy_hp=16;s.qi=0;s._companion_attack_count=1
	result=s.battle_action("attack")
	check(result.won and not result.message.contains("唐栖") and s.qi==2,"Direct killing blow does not trigger redundant support or qi")
func _test_save_migration() -> void:
	for version in [1,2,3]:
		for shen in [false,true]:
			var source=completed_chapter()
			if shen:source.recruit_companion();source.set_formation("护后")
			var data=source.to_dict()
			for key in ["tangqi_stage","tangqi_choice","tangqi_unlocked","active_companion"]:data.erase(key)
			write_data(data,version)
			var loaded=recruited_tang()
			check(loaded.load_game(PATH)==OK,"Reads genuine pre-companion schema %d" % version)
			check(loaded.tangqi_stage==0 and not loaded.tangqi_unlocked and loaded.current_companion()==("沈青" if shen else "") and loaded.formation==source.formation,"Legacy migration does not invent Tang or lose Shen formation")
			check(loaded.xp==source.xp and loaded.coins==source.coins and loaded.resources==source.resources,"Legacy migration grants no reward")
	for stage in range(4):
		var source=completed_chapter()
		if stage>=1:source.begin_tangqi_quest()
		if stage>=2:source.recover_craft_notes()
		if stage>=3:source.resolve_tangqi_quest("preserve")
		check(source.save_game(PATH)==OK,"Save pending personal-quest stage %d" % stage)
		var loaded=State.new()
		check(loaded.load_game(PATH)==OK and loaded.to_dict()==source.to_dict(),"Roundtrip pending personal-quest stage %d" % stage)
	var valid=recruited_tang();valid.recruit_companion();valid.select_companion("沈青");valid.set_formation("护后")
	valid.save_game(PATH);var loaded=State.new()
	check(loaded.load_game(PATH)==OK and loaded.to_dict()==valid.to_dict(),"Full roster, active selection and formation roundtrip")
	var variants=[
		{"tangqi_stage":"3"},{"tangqi_unlocked":1},{"tangqi_choice":[]},{"active_companion":[]},
		{"tangqi_stage":2,"tangqi_unlocked":true},{"tangqi_stage":3,"tangqi_choice":""},
		{"tangqi_stage":1,"bridge_repaired":false},{"tangqi_stage":1,"chapter_two_stage":3},
		{"tangqi_stage":1e100,"tangqi_choice":"","tangqi_unlocked":false,"chapter_two_stage":0,"bridge_repaired":false}
	]
	loaded.start_battle();loaded.battle_action("attack")
	for changes in variants:
		var data=valid.to_dict()
		data.merge(changes,true);write_data(data)
		var before=loaded.to_dict();var before_turn=loaded.turn
		check(loaded.load_game(PATH)==ERR_FILE_CORRUPT and loaded.to_dict()==before and loaded.battle_active and loaded.turn==before_turn,"Malformed/inconsistent companion save rejected atomically: "+str(changes))
	var unknown=valid.to_dict();unknown.active_companion="not-recruited"
	write_data(unknown)
	check(loaded.load_game(PATH)==OK and loaded.current_companion()=="沈青" and loaded.available_companions()==["沈青","唐栖"],"Unknown active companion falls back to a real owned companion")
	unknown.companion_unlocked=false
	# This case exercises historical fallback, so omit the modern party pair
	# instead of retaining an explicit roster/resource entry for removed Shen.
	unknown.erase("party_roster");unknown.erase("party_resources")
	write_data(unknown)
	check(loaded.load_game(PATH)==OK and loaded.current_companion()=="唐栖","Fallback supports Tang-only roster")
	check(not loaded.recruit_tangqi() and not loaded.resolve_tangqi_quest("teach"),"Reloaded completed quest cannot reward again")
