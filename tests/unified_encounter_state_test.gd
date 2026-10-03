extends SceneTree
const State=preload("res://scripts/game_state.gd")
const Encounters=preload("res://scripts/unified_encounter_rules.gd")
var checks=0
var failures=0
var root_path=""
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func _init()->void:
 if OS.get_environment("XDG_DATA_HOME").is_empty():quit(2);return
 root_path="user://unified-state-%d"%OS.get_process_id();DirAccess.make_dir_recursive_absolute(root_path)
 _run.call_deferred()
func _prepared(id:String,count:int=1):
 var s=State.new()
 if id=="story":
  s.quest_stage=3
 else:
  s.quest_stage=6;s.ending="守望";s.choose_sect("听潮阁");s.gain_xp(900)
  s.side_stage=3;s.side_choice="rescue";s.side_clues=2;s.side_found.assign(["boatman","ledger"]);s.side_reward_claimed=true
  s.chapter_two_stage=4;s.chapter_two_ending="protect_witness";s.archive_clues.assign(["clerk","inscription"]);s.seal_sequence.assign([2,0,1]);s.bridge_repaired=true
 if count>=2:check(s.recruit_companion(),"Explicit Shen invitation")
 if count>=3:
  check(s.begin_tangqi_quest() and s.recover_craft_notes() and s.resolve_tangqi_quest("teach") and s.recruit_tangqi(),"Explicit Tang quest/invitation")
 if count==4:
  # Completed-story capacity fixture, not an early-story recruitment claim.
  s.mist_stage=4;s.mist_approach="duel";s.mist_gauges.assign(["rain","stone","basin"]);s.mist_ending="release_water";s.map_id="mistwood"
  check(s.begin_qin_quest() and s.inspect_qin_rope() and s.arrange_qin_handoff() and s.recruit_qin(),"Actual Qin quest/invitation registers resources on completed-story fixture")
 var ids:Array=["hero","shen","tang","qin"].slice(0,count)
 check(s.set_party_roster(ids),"Explicit occupied roster")
 match id:
  "sluice_scout":s.side_stage=1;s.side_clues=0;s.side_found.clear();s.side_reward_claimed=false;s.chapter_two_stage=0;s.chapter_two_ending="";s.archive_clues.clear();s.seal_sequence.clear();s.bridge_repaired=false
  "sluice_boss":s.side_stage=2;s.side_reward_claimed=false;s.chapter_two_stage=0;s.chapter_two_ending="";s.archive_clues.clear();s.seal_sequence.clear();s.bridge_repaired=false
  "archive_boss":s.chapter_two_stage=2;s.chapter_two_ending="";s.bridge_repaired=false
  "mist_scout":s.mist_stage=1;s.mist_approach="";s.mist_gauges.clear();s.mist_ending=""
  "mist_keeper":s.mist_stage=2;s.mist_approach="duel";s.mist_gauges.assign(["rain","stone","basin"]);s.mist_ending=""
  "heting_receipt":
   s.mist_stage=4;s.mist_approach="duel";s.mist_gauges.assign(["rain","stone","basin"]);s.mist_ending="release_water"
   s.heting_stage=4;s.heting_bridge="east";s.heting_delivered.assign(["meal","sealed","reserve"]);s.heting_draft="short_ferries";s.heting_ending="short_ferries";s.receipt_stage=1
  "heting_consignee":
   s.mist_stage=4;s.mist_approach="duel";s.mist_gauges.assign(["rain","stone","basin"]);s.mist_ending="release_water"
   s.heting_stage=4;s.heting_bridge="east";s.heting_delivered.assign(["meal","sealed","reserve"]);s.heting_draft="short_ferries";s.heting_ending="short_ferries"
   s.map_id="heting";s.position=Vector2(420,450)
   # Phase-one prepared model; this does not assert a playable chapter scene.
   check(s.begin_consignee(),"Prepared completed Heting can begin consignee")
   for observation:String in ["lot_seals","removal_order","southern_counterfoil"]:
    check(s.observe_consignee(observation),"Actual solo observation "+observation)
   check(s.resolve_consignee_contradiction("order_before_inspection").ok,"Actual contradiction resolution")
   check(s.choose_consignee_plan("hold_for_inspection"),"Actual reversible draft before battle")
 s.map_id=Encounters.LOCATIONS[id][0];s.position=Vector2(420,450)
 check(s._stage_save_data(s.to_dict(),State.SAVE_VERSION).ok,"Prepared %s state is canonical"%id)
 return s
func _step(s)->Dictionary:
 var tx=s.advance_party_battle();check(tx.get("accepted",false),"Scheduler accepts next action")
 if tx.get("accepted",false):
  var before=s.to_dict();check(not s.advance_party_battle().get("accepted",false) and s.to_dict()==before,"Locked duplicate advance cannot mutate resources")
  var result=s.finish_party_presentation(tx.epoch,tx.token);check(result.get("accepted",false),"Exact presentation acknowledges")
  check(not s.finish_party_presentation(tx.epoch,tx.token).get("accepted",false),"Duplicate ack cannot settle twice")
 return tx
func _run()->void:
 for id:String in Encounters.IDS:
  var s=_prepared(id,2 if id=="story" else 1)
  check(s.start_party_battle(id),"All authored encounter ids enter shared model: "+id)
  if not s.battle_active:continue
  check(s.party_session.get_script().resource_path.ends_with("automatic_party_combat.gd"),"Same automatic model")
  var before=s.to_dict();var basics={};var attempts=0
  while s.battle_active and attempts<400:
   var tx=_step(s);attempts+=1
   if not tx.get("accepted",false):break
   if tx.action_id=="attack":
    var key="%s:%d"%[tx.source_id,tx.before.round];check(not basics.has(key),"State wrapper keeps one basic per round");basics[key]=true
  check(not s.battle_active,"No-input terminates without manual turn command: "+id)
  if id=="courtyard_practice":check(s.to_dict()==before,"Practice leaves all persistent bytes unchanged on terminal")
  else:
   check(s.save_game(root_path+"/"+id+".json")==OK,"Every terminal state saves canonically")
   if s.party_settlement.get("outcome")=="win":
    match id:
     "mist_scout":check(s.mist_approach=="duel" and s.party_settlement.reward_xp==40,"Scout grants proven access/reward once")
     "mist_keeper":check(s.mist_stage==3 and s.mist_ending=="" and s.party_settlement.reward_xp==90,"Keeper leaves ending choice pending")
     "archive_boss":check(s.chapter_two_stage==3 and s.chapter_two_ending=="","Archive leaves ending choice pending")
     "sect_trial":check(not s.sect_trial_won and s.party_settlement.reward_xp==45,"Winning on basics does not fabricate trial objective")
 for count in range(1,5):
  var s=_prepared("courtyard_practice",count);var before=s.to_dict()
  check(s.start_party_battle("courtyard_practice"),"Practice supports occupied roster%d"%count)
  var tx=s.advance_party_battle();check(tx.accepted,"Practice accepts actual action")
  check(s.save_game(root_path+"/busy.json")==ERR_BUSY,"Pending practice cannot overwrite real save")
  check(s.finish_party_presentation(tx.epoch,tx.token).accepted,"Practice ack")
  var flee=s.party_battle_action("flee");check(flee.accepted and s.finish_party_presentation(flee.epoch,flee.token).accepted,"Practice explicit exit")
  check(s.to_dict()==before,"Practice action/flee resources/proficiency unchanged for%d"%count)
 var unknown=State.new();var original=unknown.to_dict();unknown.start_battle("not-a-real-encounter")
 check(not unknown.battle_active and unknown.to_dict()==original and not unknown.start_party_battle("typo"),"Unknown encounter never defaults to story")
 var s=_prepared("training",4);check(s.start_party_battle("training"),"Four-person real repeat encounter")
 var tx=s.advance_party_battle();check(tx.accepted,"Real action accepted")
 check(not s.party_battle_action("attack").accepted,"Manual attack bypass is rejected")
 check(s.save_game(root_path+"/busy.json")==ERR_BUSY,"Accepted battle cannot save halfway")
 check(s.finish_party_presentation(tx.epoch,tx.token).accepted,"Accepted action settles once")
 var flee=s.party_battle_action("flee");check(flee.accepted,"Retreat accepted at boundary")
 var result=s.finish_party_presentation(flee.epoch,flee.token);check(result.accepted and not result.settlement.awarded,"Retreat has no reward")
 var bytes=s.to_dict();check(s.save_game(root_path+"/missing/save.json")!=OK and s.to_dict()==bytes,"Failed save preserves terminal resources")
 check(s.save_game(root_path+"/retry.json")==OK,"Retry succeeds with same settled state")
 for name in DirAccess.get_files_at(root_path):DirAccess.remove_absolute(root_path+"/"+name)
 DirAccess.remove_absolute(root_path)
 if failures==0:print("PASS: %d unified encounter state/settlement/practice/save checks"%checks)
 quit(0 if failures==0 else 1)
