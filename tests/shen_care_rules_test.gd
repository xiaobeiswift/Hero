extends SceneTree
const State=preload("res://scripts/game_state.gd")
var checks=0
var failures=0
const PATH="user://shen-care-rules.json"
func check(value:bool,message:String)->void:
	checks+=1
	if not value:
		failures+=1
		push_error(message)
func ready_state():
	var s=State.new()
	s.quest_stage=6;s.ending="守望";s.choose_sect("听潮阁");s.recruit_companion()
	s.side_stage=3;s.side_choice="rescue";s.side_reward_claimed=true;s.side_clues=2;s.side_found.assign(["boatman","ledger"])
	return s
func write_document(data:Dictionary,version:int=State.SAVE_VERSION)->void:
	var f=FileAccess.open(PATH,FileAccess.WRITE)
	f.store_string(JSON.stringify({"version":version,"player":data}));f.close()
func progress(s,choice:String)->void:
	s.begin_shen_care();s.consult_shen_patient();s.inspect_shen_shelter();s.choose_shen_care(choice)
func _init()->void:
	var fresh=State.new()
	check(not fresh.begin_shen_care(),"Quest needs completed sluice and recruited Shen")
	for key in ["companion_unlocked","quest_stage","side_stage","side_choice","ending"]:
		var blocked=ready_state()
		blocked.set(key,false if key=="companion_unlocked" else ("" if key in ["side_choice","ending"] else 0))
		var original=blocked.to_dict()
		check(not blocked.begin_shen_care() and blocked.to_dict()==original,"Missing gate rejects atomically: "+key)
	for choice in ["shore","mobile"]:
		var s=ready_state();var original=s.to_dict()
		check(not s.consult_shen_patient() and not s.inspect_shen_shelter() and not s.choose_shen_care(choice) and not s.post_shen_notice(),"Cannot skip unstarted story")
		check(s.to_dict()==original,"Out-of-order calls have no side effects")
		check(s.begin_shen_care() and s.shen_care_stage==1,"Story begins")
		check(not s.begin_shen_care() and not s.inspect_shen_shelter(),"Begin and field-stage gates protect progress")
		check(s.consult_shen_patient() and s.shen_care_stage==2,"Patient voice recorded")
		check(not s.consult_shen_patient() and not s.post_shen_notice(),"Duplicate consultation and premature posting rejected")
		check(s.inspect_shen_shelter() and s.shen_care_stage==3,"Shelter capacity inspected")
		check(not s.choose_shen_care("invalid") and s.shen_care_stage==3,"Invalid plan leaves decision open")
		check(s.choose_shen_care(choice) and s.shen_care_stage==4,"Draft plan selected")
		check(s.ShenCare.shore_bonus(s)==0 and s.ShenCare.mobile_heal(s)==0,"Draft has no battle bonus")
		var before=s.to_dict()
		check(not s.choose_shen_care(choice) and s.to_dict()==before,"Identical draft is a no-op")
		var alternate="mobile" if choice=="shore" else "shore"
		check(s.choose_shen_care(alternate) and s.choose_shen_care(choice),"Draft may be revised before posting")
		check(s.xp==original.xp and s.coins==original.coins and s.resources==original.resources,"Draft and free investigation do not grant or consume resources")
		check(s.save_game(PATH)==OK,"Draft saves")
		var copy=State.new()
		check(copy.load_game(PATH)==OK and copy.to_dict()==s.to_dict(),"Draft round-trips exactly")
		check(s.post_shen_notice() and s.shen_care_stage==5,"Posting completes story")
		check(s.xp==40 and s.coins==24 and s.medicine==3,"Only one-time40XP reward; no resource tax")
		before=s.to_dict()
		check(not s.post_shen_notice() and not s.choose_shen_care(alternate) and s.to_dict()==before,"Posted decision and reward cannot be replayed")
		check(s.save_game(PATH)==OK and copy.load_game(PATH)==OK and copy.to_dict()==s.to_dict(),"Completion round-trips")
		check(s.ShenCare.shore_bonus(s)==(1 if choice=="shore" else 0),"Only shore unlocks cover benefit")
		check(s.ShenCare.mobile_heal(s)==(2 if choice=="mobile" else 0),"Only mobile unlocks assist heal")
		s.hp=s.max_hp-10;s.start_battle("spar");s.enemy_hp=999;s.enemy_max_hp=999
		var messages:Array[String]=[]
		s._companion_attack_count=0
		s.Companions.assist(s,messages)
		check(s.hp==s.max_hp-10,"First offensive action cannot trigger care heal")
		s.Companions.assist(s,messages)
		check(s.hp==s.max_hp-(8 if choice=="mobile" else 10),"Second existing assist gets exact branch heal")
		s.hp=s.max_hp-1;s._companion_attack_count=1;s.Companions.assist(s,messages)
		check(s.hp==s.max_hp if choice=="mobile" else s.hp==s.max_hp-1,"Healing is capped at missing HP")
		check(s.Companions.cover(s,10,messages)==(7 if choice=="shore" else 8),"Cover benefit applies only to shore")
		check(s.Companions.cover(s,1,messages)==1,"Cover preserves minimum incoming damage")
		var tick=s._companion_attack_count;s.qi=0
		var hp=s.hp
		check(not s.battle_action("skill").valid and s._companion_attack_count==tick and s.hp==hp,"Invalid skill cannot trigger healing or assist counter")
		s.battle_action("flee")
		check(s.shen_care_stage==5 and s.shen_care_choice==choice,"Battle end keeps persistent story")
		s.tangqi_unlocked=true;s.active_companion="唐栖"
		# This old-combat fixture explicitly selects its newly prepared Tang.
		s._apply_party_plan(s.PartyRoster.load_plan(s,{"active_companion":"唐栖"},11))
		s.start_battle("spar");s.enemy_hp=999;s._companion_attack_count=1;s.hp=s.max_hp-8
		s.Companions.assist(s,messages)
		check(s.hp==s.max_hp-8,"Tang never receives Shen care heal")
		s.battle_action("flee");s.reset_game()
		check(s.shen_care_stage==0 and s.shen_care_choice.is_empty(),"New journey clears only its own story state")
	for stage in range(5):
		var s=ready_state()
		if stage>0:s.begin_shen_care()
		if stage>1:s.consult_shen_patient()
		if stage>2:s.inspect_shen_shelter()
		if stage>3:s.choose_shen_care("shore")
		s.start_battle("spar")
		var before=s.to_dict()
		check(not s.begin_shen_care() and not s.consult_shen_patient() and not s.inspect_shen_shelter() and not s.choose_shen_care("mobile") and not s.post_shen_notice(),"Every story mutation blocked in battle")
		check(before==s.to_dict(),"Battle gate is atomic")
	var complete=ready_state();progress(complete,"shore");complete.post_shen_notice()
	for stage in range(6):
		var data=ready_state().to_dict();data.shen_care_stage=stage;data.shen_care_choice="mobile" if stage>=4 else ""
		write_document(data)
		check(State.new().load_game(PATH)==OK,"Every consistent stage is reloadable")
	for version in range(1,7):
		var old=ready_state().to_dict();old.erase("shen_care_stage");old.erase("shen_care_choice")
		write_document(old,version)
		var loaded=State.new()
		check(loaded.load_game(PATH)==OK and loaded.shen_care_stage==0 and loaded.shen_care_choice.is_empty(),"Legacy version migrates without inventing a quest/reward: "+str(version))
	for bad in [-1,6,0.5,1e99,"1",true,null]:
		var data=complete.to_dict();data.shen_care_stage=bad;write_document(data)
		var before=complete.to_dict()
		check(complete.load_game(PATH)==ERR_FILE_CORRUPT and complete.to_dict()==before,"Malformed stage rejected unchanged: "+str(bad))
	for change in [{"shen_care_choice":"unknown"},{"shen_care_choice":2},{"shen_care_stage":0},{"shen_care_stage":3},{"companion_unlocked":false},{"side_stage":0,"side_reward_claimed":false},{"quest_stage":3},{"side_choice":""},{"ending":"unknown"}]:
		var data=complete.to_dict()
		for key in change:data[key]=change[key]
		write_document(data);var before=complete.to_dict()
		check(complete.load_game(PATH)==ERR_FILE_CORRUPT and complete.to_dict()==before,"Inconsistent story rejected atomically: "+str(change))
	for missing in ["shen_care_stage","shen_care_choice"]:
		var data=complete.to_dict();data.erase(missing);write_document(data)
		check(complete.load_game(PATH)==ERR_FILE_CORRUPT,"Current schema requires new field: "+missing)
	for version in range(1,7):
		var partial=ready_state().to_dict();partial.erase("shen_care_choice");write_document(partial,version)
		check(State.new().load_game(PATH)==ERR_FILE_CORRUPT,"Legacy partial new-field pair is rejected: "+str(version))
	var recovered=complete.to_dict();recovered.side_stage=2;recovered.quest_stage=5
	write_document(recovered,1)
	var repair=State.new()
	check(repair.load_game(PATH)==OK and repair.quest_stage==6 and repair.side_stage==3 and repair.shen_care_stage==5,"Effective legacy completion migrates without softlock or reward replay")
	if failures==0:print("PASS: %d Shen care rules checks" % checks)
	else:push_error("FAIL: Shen care rules checks")
	quit(0 if failures==0 else 1)
