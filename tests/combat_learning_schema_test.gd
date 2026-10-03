extends SceneTree
const State=preload("res://scripts/game_state.gd")
const Catalog=preload("res://scripts/party_actor_catalog.gd")
var checks=0
var failures=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok: failures+=1;push_error(message)
func _init()->void:
 if OS.get_environment("XDG_DATA_HOME").is_empty():quit(2);return
 var fresh=State.new()
 check(State.SAVE_VERSION==16 and not fresh.internal_unlocked,"New schema16 has no unearned internal lesson")
 check(not fresh.learn_internal_skill(),"Lesson rejects level1/unjoined")
 var legacy=fresh.to_dict();legacy.erase("internal_unlocked");legacy.erase("weapon_fitting")
 for field:String in State.Consignee.FIELDS+State.Capstone.FIELDS:legacy.erase(field)
 for version in range(1,13):
  var migrated=fresh._stage_save_data(legacy,version)
  check(migrated.ok,"Legacy%d loads"%version)
  if migrated.ok:check(not migrated.state.internal_unlocked,"Legacy%d never gains internal lesson"%version)
 var trained=State.new();trained.level=3;trained.sect="听潮阁";trained.sect_rank=1
 check(trained.learn_internal_skill(),"Explicit eligible lesson succeeds")
 check(not trained.learn_internal_skill(),"Repeated lesson is idempotent")
 var built=Catalog.build_team(trained,["hero"])
 check(built.ok and built.team.actors[0].internal_unlocked,"Only trained actor receives internal flag")
 check(not built.team.actors[0].lightness_unlocked,"Internal lesson does not fabricate lightness")
 trained.battle_active=true;trained.internal_unlocked=false
 check(not trained.learn_internal_skill(),"Lesson refuses during combat")
 var schema13:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/legacy_saves/schema_13_default.json")).player
 check(not schema13.has("consignee_stage") and schema13.has("internal_unlocked"),"Genuine schema13 fixture has internal lesson and no consignee bundle")
 var prior13=fresh._stage_save_data(schema13,13)
 check(prior13.ok and not prior13.state.internal_unlocked and prior13.state.consignee_stage==0,"Genuine schema13 migrates without either unearned progression")
 for version:int in [13,14,15,State.SAVE_VERSION]:
  var current:Dictionary=schema13 if version==13 else fresh.to_dict()
  if version==14:
   for field:String in State.Capstone.FIELDS:current.erase(field)
  for malformed in [null,1,"true",{},[]]:
   var data=current.duplicate(true);data.internal_unlocked=malformed
   check(not fresh._stage_save_data(data,version).ok,"Schema%d lesson flag is strict boolean"%version)
  var missing=current.duplicate(true);missing.erase("internal_unlocked")
  check(not fresh._stage_save_data(missing,version).ok,"Schema%d lesson flag is required"%version)
  var unearned=current.duplicate(true);unearned.internal_unlocked=true
  check(not fresh._stage_save_data(unearned,version).ok,"Schema%d unearned lesson rejects"%version)
 var root="user://schema16-%d"%OS.get_process_id();DirAccess.make_dir_recursive_absolute(root)
 var path=root+"/new.json"
 check(fresh.save_game(path)==OK,"Current complete save writes")
 var prior=GDScript.new();prior.source_code=FileAccess.get_file_as_string("res://tests/fixtures/v022_game_state.gd.txt").replace("class_name HeroState\n","")
 check(prior.reload()==OK,"Frozen schema12 reader parses")
 var old=prior.new();var before=old.to_dict()
 check(old.load_game(path)==ERR_FILE_UNRECOGNIZED and old.to_dict()==before,"Old reader rejects current16 without mutation")
 var reader=State.new();check(reader.load_game(path)==OK and reader.to_dict()==fresh.to_dict(),"New reader round trips")
 DirAccess.remove_absolute(path);DirAccess.remove_absolute(root)
 if failures==0:print("PASS: %d explicit internal-learning/schema13–16 compatibility checks"%checks)
 quit(0 if failures==0 else 1)
