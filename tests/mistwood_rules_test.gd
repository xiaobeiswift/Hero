extends SceneTree
const S=preload("res://scripts/game_state.gd")
var checks=0
var failures=0
func check(value:bool,label:String)->void:
 checks+=1
 if not value:failures+=1;push_error(label)
func ready_state():
 var s=S.new();s.quest_stage=6;s.side_stage=3;s.side_choice="rescue";s.side_reward_claimed=true;s.side_found.assign(["boatman","ledger"]);s.side_clues=2
 s.chapter_two_stage=4;s.chapter_two_ending="protect_witness";s.archive_clues.assign(["clerk","inscription"]);s.seal_sequence.assign([2,0,1])
 s.gain_xp(600);s.choose_sect("问石门");s.equip_art(s.sect_art())
 return s
func win(s)->void:
 for i in range(100):
  if not s.battle_active:return
  if s.hp<45 and s.medicine>0:s.battle_action("item")
  elif s.Patterns.phase(s.battle_kind,s.turn).heavy:s.battle_action("guard")
  elif s.qi>=s.active_art_cost() and s.skill_cooldown==0:s.battle_action("skill")
  else:s.battle_action("attack")
func _init()->void:
 var fresh=S.new()
 check(not fresh.begin_mistwood(),"Incomplete previous chapter cannot enter")
 fresh.start_battle("mist_scout");check(not fresh.battle_active,"Scouting battle has a quest gate")
 for route in ["duel","repair","records"]:
  var s=ready_state()
  check(s.begin_mistwood() and s.mist_stage==1,"Start new chapter once")
  check(not s.begin_mistwood(),"Repeated entry cannot reset investigation")
  check(not s.record_mist_gauge("stone"),"Upper gauge requires permission")
  check(s.record_mist_gauge("rain") and s.record_mist_gauge("basin"),"Outer readings can be gathered in either order")
  var before=s.to_dict()
  check(not s.record_mist_gauge("rain") and s.to_dict()==before,"Repeated gauge has no XP reward")
  if route=="duel":
   check(not s.obtain_mist_access("duel"),"Cannot forge a victory permit")
   s.start_battle("mist_scout");s.battle_action("flee")
   check(s.mist_approach.is_empty() and s.mist_stage==1,"Flee leaves patrol retryable")
   s.heal_rest();s.start_battle("mist_scout");win(s)
   check(s.enemy_hp==0 and s.mist_approach=="duel","Actual patrol victory grants passage")
  elif route=="repair":
   check(not s.obtain_mist_access(route),"Missing materials reject repair atomically")
   s.resources.timber=1;s.resources.cloth=1
   check(s.obtain_mist_access(route) and s.resources.timber==0 and s.resources.cloth==0,"Repair costs exactly one wood and cloth")
  else:
   check(not s.obtain_mist_access(route),"Protected witnesses do not expose public-record proof")
   s.chapter_two_ending="open_records"
   check(s.obtain_mist_access(route),"Earlier public-record choice enables noncombat passage")
  before=s.to_dict()
  check(not s.obtain_mist_access(route) and s.to_dict()==before,"Passage reward is one-time across routes")
  check(s.record_mist_gauge("stone") and s.mist_stage==2,"Three readings and permit unlock keeper")
  s.heal_rest();s.start_battle("mist_keeper")
  check(s.enemy_intent.contains("受击减半"),"Keeper announces initial guarded stance")
  var hp=s.enemy_hp;var attack=s.attack
  s.battle_action("attack")
  check(hp-s.enemy_hp==int(ceil(attack*0.5)),"Guarded stance really halves player damage")
  check(s.enemy_intent.contains("重击"),"Second phase telegraphs heavy strike")
  s.battle_action("guard")
  check(s.exposed_turns==0 and s.enemy_intent.contains("+8"),"Guard counters exposure and third phase reveals opening")
  hp=s.enemy_hp;s.battle_action("attack")
  check(hp-s.enemy_hp==attack+8,"Recovery window gives actual bonus damage")
  s.battle_action("flee");check(s.mist_stage==2,"Keeper flee does not consume clues")
  s.heal_rest();s.start_battle("mist_keeper");win(s)
  check(s.enemy_hp==0 and s.mist_stage==3,"Normal level-five build wins phased keeper")
  s.start_battle("mist_keeper");check(not s.battle_active,"Defeated story keeper cannot be farmed")
  var ending="release_water" if route!="records" else "warn_ferries"
  check(s.resolve_mistwood(ending) and s.mist_stage==4,"Evidence can be resolved through both choices")
  before=s.to_dict();check(not s.resolve_mistwood(ending) and s.to_dict()==before,"Chapter finale rewards cannot repeat")
  var path="user://hero-mistwood-rules.json";check(s.save_game(path)==OK,"Save third-chapter progress")
  var loaded=S.new();check(loaded.load_game(path)==OK and loaded.to_dict()==s.to_dict(),"Third-chapter progress roundtrips")
  DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 # Heavy support follows the new three-phase pattern, not old turn parity.
 var s=ready_state();s.begin_mistwood();s.mist_approach="repair";s.mist_stage=2
 s.tangqi_unlocked=true;s.active_companion="唐栖";s.formation="护后";s.start_battle("mist_keeper");s.turn=4
 var before_hp=s.hp;var expected=maxi(1,33-s.defense-5)
 s.battle_action("attack")
 check(s.hp==before_hp-expected,"Tang blocks heavy on turn5 of a three-phase enemy")
 check(s.exposed_turns==2,"Support alone does not negate boss exposure")
 s.battle_action("flee")
 # A support strike is halved by a shield but never receives the recovery bonus.
 s.start_battle("mist_keeper");s._companion_attack_count=1;s.formation="并肩";s.turn=0
 var enemy_hp=s.enemy_hp;s.battle_action("attack")
 check(enemy_hp-s.enemy_hp==int(ceil(s.attack*0.5))+2,"Shield halves Tang's4point assist as well")
 s.turn=2;s._companion_attack_count=1;enemy_hp=s.enemy_hp;s.battle_action("attack")
 check(enemy_hp-s.enemy_hp==s.attack+8+4,"Opening bonus applies once to hero, not again to support")

 var stored=ready_state();stored.begin_mistwood()
 var path="user://hero-mistwood-corrupt.json"
 var data=stored.to_dict()
 for change in [{"mist_stage":1e100},{"mist_stage":"1"},{"mist_gauges":["unknown"]},{"mist_gauges":[2]},{"mist_gauges":{}},{"mist_approach":"wrong"},{"mist_approach":"records"},{"mist_ending":"warn_ferries"}]:
  var changed=data.duplicate(true)
  for key in change:changed[key]=change[key]
  var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify({"version":S.SAVE_VERSION,"player":changed}));file.close()
  var live=S.new();live.start_battle();live.focused_damage=44;var preserved=live.to_dict()
  check(live.load_game(path)==ERR_FILE_CORRUPT and live.to_dict()==preserved and live.battle_active and live.focused_damage==44,"Malformed chapter fields reject atomically: "+str(change))
 var old=data.duplicate(true)
 for key in ["mist_stage","mist_gauges","mist_approach","mist_ending"]:old.erase(key)
 var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify({"version":5,"player":old}));file.close()
 var migrated=S.new()
 check(migrated.load_game(path)==OK and migrated.mist_stage==0 and migrated.mist_gauges.is_empty(),"Real version5 lacking chapter fields still loads")
 file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify({"version":S.SAVE_VERSION,"player":old}));file.close()
 check(migrated.load_game(path)==ERR_FILE_CORRUPT,"Current schema requires all chapter fields")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 if failures==0:print("PASS: %d mistwood rules and phased-encounter checks" % checks)
 else:push_error("FAIL: %d of %d mistwood checks" % [failures,checks])
 quit(0 if failures==0 else 1)
