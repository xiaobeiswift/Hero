extends "res://tests/visual_smoke.gd"
func _run()->void:
 app=Scene.instantiate();app.state=VisualState.new();root.add_child(app)
 await create_timer(0.5).timeout
 app._stop_audio();app.audio_on=false;app._new_game()
 app.state.quest_stage=6;app.state.ending="守望";app.state.gain_xp(600);app.state.choose_sect("问石门")
 app.state.side_stage=3;app.state.side_choice="rescue";app.state.side_reward_claimed=true;app.state.side_clues=2;app.state.side_found.assign(["boatman","ledger"])
 app.state.chapter_two_stage=4;app.state.chapter_two_ending="open_records";app.state.archive_clues.assign(["clerk","inscription"]);app.state.seal_sequence.assign([2,0,1])
 app.state.sect_trial_won=true;app.state.complete_sect_trial();app.state.learn_art("藏锋立岳");app.state.equip_art("藏锋立岳");app.state.recruit_companion()
 app.mist_story.enter_region();app.world.teleport(Vector2(410,425));await create_timer(0.4).timeout
 await _capture("38-mistwood-uplands")
 app._show_map();await _capture("39-mistwood-map");app._close_modal()
 app.world.teleport(Vector2(1030,590));app._interact("mist_scout");await _capture("40-three-patrol-approaches")
 app.mist_story.access("records")
 for id in ["rain","basin"]:app.mist_story.record(id)
 app.world.teleport(Vector2(1000,340));app._interact("mist_stone_gauge");await _capture("41-stone-rain-reading")
 app.mist_story.record("stone");app.world.teleport(Vector2(1320,540));app.state.heal_rest()
 app._interact("mist_gate");app.modal_actions[0].call()
 await _capture("42-keeper-guard-phase")
 app._battle_action("attack");app._battle_action("skill")
 await _capture("43-keeper-recovery-window")
 for i in range(120):
  if not app.state.battle_active:break
  var phase=app.state.Patterns.phase(app.state.battle_kind,app.state.turn)
  if app.state.hp<45 and app.state.medicine>0:app._battle_action("item")
  elif phase.heavy:
   if app.state.qi>=app.state.active_art_cost() and app.state.skill_cooldown==0:app._battle_action("skill")
   else:app._battle_action("guard")
  else:app._battle_action("attack")
 if app.state.mist_stage!=3:
  push_error("Graphical Mistwood keeper battle did not win");quit(1);return
 app._close_modal();app.world.teleport(Vector2(350,405));app._interact("mist_guide")
 await _capture("44-rain-order-ending-choice")
 app.mist_story.finish("warn_ferries");app._interact("mist_guide")
 await _capture("45-mistwood-aftermath")
 app._close_modal();app._stop_audio();await create_timer(0.25).timeout;app.queue_free();await process_frame
 print("PASS: 8 actual Mistwood render captures saved")
 quit()
