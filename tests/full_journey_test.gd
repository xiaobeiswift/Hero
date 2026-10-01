extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class JourneyState extends Model:
 const PATH="user://hero-full-journey.json"
 func save_game(path:String=SAVE_PATH)->Error:return super.save_game(PATH if path==SAVE_PATH else path)
 func load_game(path:String=SAVE_PATH)->Error:return super.load_game(PATH if path==SAVE_PATH else path)
 func has_save()->bool:return FileAccess.file_exists(PATH)
var app
var checks=0
var failures=0
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
 app._interact(id)
func fight()->void:
 check(app.state.battle_active,"Story action starts battle")
 for i in range(120):
  if not app.state.battle_active:break
  if app.state.hp<45 and app.state.medicine>0:app._battle_action("item")
  elif bool(app.state.Patterns.phase(app.state.battle_kind,app.state.turn).get("heavy",app.state.turn%2==1)):
   if app.state.qi>=app.state.active_art_cost() and app.state.skill_cooldown==0:app._battle_action("skill")
   else:app._battle_action("guard")
  else:app._battle_action("attack")
 check(not app.state.battle_active and app.state.enemy_hp==0,"Natural stats/resources win "+app.encounter_kind)
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
  interact("mentor");choose();fight()
  interact("mentor");choose()
  check(app.state.sect_rank==2,"Actual chosen school trial completed with normal stats")
  interact("exit_sluice");choose()
  interact("stranded_boatman");choose();app._close_modal()
  interact("ledger_runner");choose();fight()
  interact("sluice_cache");choose()
  interact("sluice_boss");choose();fight()
  check(app.state.side_stage==3,"Full sluice route naturally completed")
  interact("exit_frostbridge");choose()
  interact("chapter_clerk");choose()
  interact("chapter_inscription");choose()
  interact("chapter_host");choose()
  interact("chapter_archive");choose(2);choose(0);choose(1)
  choose();fight()
  interact("chapter_host");choose(0 if school==0 else 1)
  check(app.state.chapter_two_stage==4,"Full archive story resolved")
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
  interact("mentor");choose(4);choose()
  check(app.state.lightness_unlocked,"Natural earned level and school allow free lightness lesson")
  app.world.teleport(app.state.Lightness.SHORE)
  interact("reed_cross");choose()
  check(app.state.Lightness.on_islet(app.world.player_pos),"Learned traversal reaches the separated island")
  interact("reed_relic");choose();interact("reed_return");choose()
  check(app.state.lightness_relics==["reed_islet"] and app.state.coins==saved_coins+18,"Natural exploration grants only one island reward")
  app._save();before=app.state.to_dict();app.state.reset_game();app._load()
  check(app.state.to_dict()==before and app.world.player_pos==app.state.Lightness.SHORE,"Island discovery and safe return persist in full journey")
  print("JOURNEY: school=%s level=%d hp=%d/%d coins=%d medicines=%d" % [app.state.sect,app.state.level,app.state.hp,app.state.max_hp,app.state.coins,app.state.medicine])
 app._stop_audio();await create_timer(0.25).timeout;app.queue_free();await process_frame
 if failures==0:print("PASS: %d full fresh-start journey checks across three schools" % checks)
 else:push_error("FAIL: %d of %d full journey checks" % [failures,checks])
 quit(0 if failures==0 else 1)
