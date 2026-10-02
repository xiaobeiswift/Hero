extends SceneTree
const UnifiedDriver = preload("res://tests/unified_ui_test_driver.gd")
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
const ReceiptJourneyChecks=preload("res://tests/receipt_journey_checks.gd")
class JourneyState extends Model:
 const PATH="user://hero-full-journey.json"
 func save_game(path:String=SAVE_PATH)->Error:return super.save_game(PATH if path==SAVE_PATH else path)
 func load_game(path:String=SAVE_PATH)->Error:return super.load_game(PATH if path==SAVE_PATH else path)
 func has_save()->bool:return FileAccess.file_exists(PATH)
var app
var checks=0
var failures=0
var receipt_checks=ReceiptJourneyChecks.new()
func _initialize()->void:_run.call_deferred()
func check(value:bool,label:String)->void:
 checks+=1
 if not value:failures+=1;push_error(label)
func choose(index:int=0)->void:
 if index>=app.modal_actions.size():
  check(false,"Missing real dialogue choice "+str(index));return
 app.modal_actions[index].call()
func interact(id:String)->void:
 if app.active_modal:app._close_modal()
 if id in ["bandit","ledger_runner","sluice_boss","chapter_archive","chapter_host", "mentor", "mist_scout", "mist_gate"]:
  check(app.world.interactables.has(id),"Guarded encounter exists on its actual map: "+id)
  if not app.world.interactables.has(id):return
  app.world.teleport(app.world.interactables[id].pos);app._process(0)
 app._interact(id)
func fight()->void:
 check(app.state.battle_active,"Story action starts battle")
 var independent:bool=app.current_screen=="party_battle"
 for i in range(120):
  if not app.state.battle_active:break
  if app.current_screen=="party_battle":
   if not _drive_party_action():break
  elif app.state.hp<45 and app.state.medicine>0:app._battle_action("item")
  elif bool(app.state.Patterns.phase(app.state.battle_kind,app.state.turn).get("heavy",app.state.turn%2==1)):
   if app.state.qi>=app.state.active_art_cost() and app.state.skill_cooldown==0:app._battle_action("skill")
   else:app._battle_action("guard")
  else:app._battle_action("attack")
 var won:bool=app.state.party_settlement.get("outcome")=="win" if independent else app.state.enemy_hp==0
 check(not app.state.battle_active and won,"Natural stats/resources win the actual selected encounter route")
 if app.active_modal:app._close_modal()
func _run()->void:
 app=Scene.instantiate();app.state=JourneyState.new();root.add_child(app)
 await process_frame
 for school in range(3):
  app._new_game()
  interact("elder");choose()
  interact("herb");choose()
  interact("healer");choose()
  interact("healer");choose()
  check(app.state.companion_unlocked and app.state.quest_stage==3,"Opening supplies and recruit earned normally")
  interact("bandit");choose();fight()
  interact("elder");choose();choose(school)
  check(app.state.quest_stage==6 and app.state.level>=3,"Opening rewards organically reach mentor level")
  app._show_inventory();choose(2);app._close_modal()
  check(app.state.equipment=="青钢剑","Opening earnings buy the sword without extra currency")
  if school==2:
   app._show_inventory();choose(1);app._close_modal() # Earned formation choice puts the trial hero in the announced heavy lane.
  interact("mentor");choose();fight()
  interact("mentor");choose()
  check(app.state.sect_rank==2,"Actual chosen school trial completed with normal stats")
  interact("exit_sluice");choose()
  interact("stranded_boatman");choose();app._close_modal()
  check(app.state.party_roster==["hero","shen"] and not app.state.tangqi_unlocked and not app.state.qin_recruited(),"Natural sluice chronology has only the earned hero and Shen")
  var before_scout_coins:int=app.state.coins
  var before_scout_xp:int=app.state.xp+30*app.state.level*(app.state.level-1)
  interact("ledger_runner");choose()
  check(app.current_screen=="party_battle" and app.state.party_battle_snapshot().encounter_id=="sluice_scout","Ordinary runner choice enters the actual independent party scout")
  fight()
  check(app.state.side_found==["boatman","ledger"] and app.state.side_clues==2 and app.state.coins==before_scout_coins+14 and app.state.xp+30*app.state.level*(app.state.level-1)==before_scout_xp+25,"Natural scout grants one ledger, fourteen coins and twenty-five XP")
  interact("sluice_cache");choose()
  var before_boss_coins:int=app.state.coins
  var before_boss_xp:int=app.state.xp+30*app.state.level*(app.state.level-1)
  var before_boss_medicine:int=app.state.medicine
  interact("sluice_boss");choose()
  check(app.current_screen=="party_battle" and app.state.party_battle_snapshot().encounter_id=="sluice_boss","Ordinary boss choice enters the actual independent party boss")
  fight()
  check(app.state.side_stage==3 and app.state.side_reward_claimed,"Full sluice route naturally completed")
  check(app.state.coins==before_boss_coins+80 and app.state.xp+30*app.state.level*(app.state.level-1)==before_boss_xp+150 and app.state.medicine==before_boss_medicine+2,"Earned rescue completion grants exact battle and branch rewards once")
  check(app.state.party_settlement.battle_reward_xp==70 and app.state.party_settlement.branch_reward_xp==80 and app.state.party_settlement.branch_reward_claimed,"Boss settlement includes the seventy-XP battle and eighty-XP branch atomically")
  interact("exit_frostbridge");choose()
  interact("chapter_clerk");choose()
  interact("chapter_inscription");choose()
  interact("chapter_host");choose()
  interact("chapter_archive");choose(2);choose(0);choose(1)
  check(app.state.party_roster==["hero","shen"] and not app.state.tangqi_unlocked and not app.state.qin_recruited(),"Natural archive chronology still has only the earned hero and Shen")
  var before_archive_coins:int=app.state.coins
  var before_archive_xp:int=app.state.xp+30*app.state.level*(app.state.level-1)
  choose()
  var archive:Dictionary=app.state.party_battle_snapshot()
  check(app.current_screen=="party_battle" and archive.get("encounter_id")=="archive_boss","Ordinary solved-seal choice enters the actual independent party archive boss")
  if not archive.is_empty():
   check(archive.enemies.size()==1 and archive.enemies[0].max_hp==205 and archive.enemies[0].attack==17 and archive.enemies[0].heavy_attack==31,"Natural archive encounter preserves its 205HP and light/heavy attack stats")
  fight()
  check(app.state.chapter_two_stage==3 and app.state.chapter_two_ending.is_empty() and app.state.coins==before_archive_coins+40 and app.state.xp+30*app.state.level*(app.state.level-1)==before_archive_xp+80,"Natural archive victory settles stage two to three with exactly eighty XP and forty coins")
  check(app.state.party_settlement.get("reward_xp")==80 and app.state.party_settlement.get("coin_change")==40,"Archive party settlement excludes the later narrative choice reward")
  interact("chapter_host");choose(0 if school==0 else 1)
  check(app.state.chapter_two_stage==4 and app.state.chapter_two_ending==("open_records" if school==0 else "protect_witness"),"Both actual innkeeper branches finish the full archive story")
  check(app.state.coins==before_archive_coins+105 and app.state.xp+30*app.state.level*(app.state.level-1)==before_archive_xp+180,"Earned ending separately adds exactly one hundred XP and sixty-five coins")
  interact("frost_timber");choose()
  interact("bridge_worker");choose()
  check(app.state.bridge_repaired and app.state.resources.timber==1,"Gathering supports real bridge cost")
  interact("bridge_worker");choose()
  interact("return_sluice")
  interact("sluice_cache");choose()
  interact("exit_frostbridge");choose()
  interact("bridge_worker");choose(school%2);choose()
  check(app.state.tangqi_unlocked and app.state.current_companion()=="唐栖","Natural chapter rewards unlock complete personal quest")
  # Learn both advanced arts from earned promotion/deed merit, then use a real build.
  interact("return_sluice");interact("return_village")
  interact("mentor");choose();choose(1);choose();choose(2);choose();choose();choose();choose();choose()
  check(app.state.learned_arts.size()==2 and app.state.sect_merit==0,"Actual story deeds fund both advanced arts without injected merit")
  app._close_modal();app._show_martials();choose(3)
  check(app.state.equipped_art==app.state.school_art_ids()[3],"Advanced focus art equipped through real four-move menu")
  interact("exit_sluice");choose();interact("exit_frostbridge");choose();interact("exit_mistwood");choose()
  check(app.state.map_id=="mistwood","Natural journey enters fourth region")
  interact("mist_rain_gauge");choose();interact("mist_basin");choose()
  if school==0:
   interact("mist_scout");choose(2)
  elif school==1:
   app._show_workshop();choose(3);choose();choose(2);app._close_modal()
   interact("mist_scout");choose(1)
  else:
   interact("mist_scout");choose();fight()
  check(not app.state.mist_approach.is_empty(),"All three patrol routes work using actual earlier choices and earned materials")
  interact("mist_stone_gauge");choose();interact("mist_camp");choose()
  interact("mist_gate");choose();fight()
  interact("mist_guide");choose(school%2)
  check(app.state.mist_stage==4,"Third chapter completed with natural progression and advanced art")
  app._save();var before=app.state.to_dict();app.state.reset_game();app._load()
  check(app.state.to_dict()==before,"Complete organic journey round-trips local save")
  # Complete Shen's follow-up using existing roads and earned party, without spending supplies.
  var saved_coins=app.state.coins
  interact("return_frostbridge");interact("return_sluice");interact("return_village")
  interact("healer");choose(3);choose()
  check(app.state.shen_care_stage==1,"Natural journey discovers and accepts Shen follow-up")
  interact("exit_sluice");choose();interact("stranded_boatman");choose()
  interact("sluice_cache");choose();interact("return_village")
  interact("healer");choose(3);choose(school%2);choose()
  interact("board");choose();app._close_modal()
  check(app.state.shen_care_stage==5 and app.state.shen_care_choice==("shore" if school%2==0 else "mobile"),"Natural journey completes care-pact branch")
  check(app.state.coins==saved_coins and app.state.current_companion()=="唐栖","Care quest needs no purchase or forced follower change")
  app._save();before=app.state.to_dict();app.state.reset_game();app._load()
  check(app.state.to_dict()==before,"Care pact round-trips after full journey")
  interact("mentor");choose(4);choose(1);choose()
  check(app.state.lightness_unlocked,"Natural earned level and school allow free lightness lesson")
  app.world.teleport(app.state.Lightness.SHORE)
  interact("reed_cross");choose()
  check(app.state.Lightness.on_islet(app.world.player_pos),"Learned traversal reaches the separated island")
  interact("reed_relic");choose();interact("reed_return");choose()
  check(app.state.lightness_relics==["reed_islet"] and app.state.coins==saved_coins+18,"Natural exploration grants only one island reward")
  app._save();before=app.state.to_dict();app.state.reset_game();app._load()
  check(app.state.to_dict()==before and app.world.player_pos==app.state.Lightness.SHORE,"Island discovery and safe return persist in full journey")
  # Continue existing organically earned party/resources into the harbor.
  var receipt_before_harbor=app.state.to_dict().duplicate(true)
  var before_port_coins=app.state.coins
  var before_port_xp=app.state.xp+30*app.state.level*(app.state.level-1)
  var before_port_resources=app.state.resources.duplicate(true)
  interact("exit_sluice");choose();interact("exit_frostbridge");choose();interact("exit_mistwood");choose()
  port_interact("exit_heting");choose()
  check(app.state.map_id=="heting" and app.state.heting_stage==1,"Natural completed chapter unlocks harbor without injected progress")
  var order=["sealed","meal"] if school==0 else ["meal","sealed"]
  for cargo in order:
   port_interact("heting_cargo")
   choose(1 if cargo=="sealed" and not app.state.heting_delivered.has("meal") else 0)
   check(app.state.heting_cargo==cargo,"Actual finite cargo choice loads expected batch")
   port_interact("heting_relief" if cargo=="meal" else "heting_scale");choose()
  port_interact("heting_dispatch");choose(school%2)
  port_interact("heting_lighter");choose()
  port_interact("heting_relief" if school%2==0 else "heting_scale");choose()
  check(app.state.heting_stage==4 and app.state.heting_ending==("short_ferries" if school%2==0 else "open_scale"),"Natural full journey completes fourth chapter night allocation")
  check(app.state.coins==before_port_coins+60 and app.state.xp+30*app.state.level*(app.state.level-1)==before_port_xp+120 and app.state.resources==before_port_resources,"Harbor costs no injected currency/material and grants only finite rewards")
  app._close_modal();app._save();before=app.state.to_dict();app.state.reset_game();app._load()
  check(app.state.to_dict()==before and app.world.map_id=="heting","Organic four-chapter result persists through current schema13")
  print("JOURNEY: school=%s level=%d hp=%d/%d coins=%d medicines=%d" % [app.state.sect,app.state.level,app.state.hp,app.state.max_hp,app.state.coins,app.state.medicine])
  var scene_checks:int=checks
  receipt_checks.run(app.state,receipt_before_harbor,check)
  print("HISTORICAL RECEIPT COMPATIBILITY: %d checks against the retained legacy receipt model; current scheduler is separately validated" % (checks-scene_checks))
 app._stop_audio();await create_timer(0.25).timeout;app.queue_free();await process_frame
 if failures==0:print("PASS: %d fresh-start current-scene and explicitly historical receipt-compatibility checks across three schools" % checks)
 else:push_error("FAIL: %d of %d full journey checks" % [failures,checks])
 quit(0 if failures==0 else 1)

func port_interact(id:String)->void:
 if app.active_modal:app._close_modal()
 app.world.teleport(app.world.interactables[id].pos)
 app._process(0)
 app._interact(id)


func _drive_party_action() -> bool:
 var panel = app.overlay.get_meta("party_battle", null)
 if not is_instance_valid(panel):
  check(false, "Active party encounter has its real controller")
  return false
 var snapshot: Dictionary = app.state.party_battle_snapshot()
 var before: Dictionary = app.state.to_dict()
 var tx: Dictionary = UnifiedDriver.begin_step(app)
 check(tx.get("accepted", false), "Actual automatic scheduler accepts one current-controller transaction")
 if not tx.get("accepted", false): return false
 if snapshot.encounter_id in ["sluice_scout","sluice_boss"]:
  check(app.state.coins==before.coins and app.state.xp==before.xp and app.state.level==before.level and app.state.side_stage==before.side_stage and app.state.side_found==before.side_found and app.state.side_reward_claimed==before.side_reward_claimed,"Accepted sluice action cannot award story or economy before renderer completion")
 if snapshot.encounter_id=="archive_boss":
  check(app.state.coins==before.coins and app.state.xp==before.xp and app.state.level==before.level and app.state.chapter_two_stage==before.chapter_two_stage and app.state.chapter_two_ending==before.chapter_two_ending,"Accepted archive action cannot grant economy, progression or ending before renderer completion")
 # Complete the actual renderer timeline so its presentation-finished signal
 # acknowledges the real epoch/token and performs the real state settlement.
 panel.art._process(panel.art.get_presentation_duration() + 0.1)
 return true
