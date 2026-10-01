extends "res://tests/visual_smoke.gd"
func _run()->void:
 app=Scene.instantiate();app.state=VisualState.new();root.add_child(app)
 await create_timer(0.5).timeout
 app._stop_audio();app.audio_on=false
 var i=0
 for school in ["听潮阁","照野堂","问石门"]:
  app._new_game();app.state.gain_xp(180);app.state.choose_sect(school);app.state.quest_stage=6;app.state.ending="守望"
  app.state.sect_trial_won=true;app.state.complete_sect_trial()
  app.state.side_stage=3;app.state.side_choice="rescue";app.state.side_reward_claimed=true;app.state.side_clues=2;app.state.side_found.assign(["boatman","ledger"])
  app.state.chapter_two_stage=4;app.state.chapter_two_ending="protect_witness";app.state.archive_clues.assign(["clerk","inscription"]);app.state.seal_sequence.assign([2,0,1])
  app._travel("qingwei",Vector2(650,720));app.advanced_martial.learning()
  await _capture("%d-advanced-school-pages" % (30+i))
  var ids=app.state.school_art_ids()
  app.advanced_martial.learn(ids[2]);app.advanced_martial.deeds()
  if i==2:await _capture("36-earned-deed-merit")
  app.advanced_martial.claim("sluice");app.advanced_martial.claim("archive");app.advanced_martial.learn(ids[3])
  if i==2:
   app._show_martials();await _capture("33-four-move-loadout");app._close_modal()
   app._travel("frostbridge",Vector2(1320,780));app.state.equip_art(ids[2]);app.state.heal_rest()
   app._start_battle("archive_boss");app._battle_action("skill")
   await _capture("34-weakened-enemy-strike")
   app._battle_action("flee");app._close_modal();app.state.equip_art(ids[3]);app.state.heal_rest()
   app._start_battle("archive_boss");app._battle_action("skill")
   await _capture("35-stored-focus-strike")
   app._battle_action("flee");app._close_modal()
  else:app._close_modal()
  i+=1
 app._travel("qingwei",Vector2(650,720));app.advanced_martial.detail("藏锋立岳");await _capture("37-advanced-art-detail")
 app._close_modal();app._stop_audio();await create_timer(0.25).timeout;app.queue_free();await process_frame
 print("PASS: 8 advanced martial rendered captures saved")
 quit()
