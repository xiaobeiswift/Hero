extends "res://tests/visual_smoke.gd"
func _run() -> void:
 app=Scene.instantiate();app.state=VisualState.new();root.add_child(app)
 await create_timer(0.5).timeout
 app._stop_audio();app.audio_on=false;app._new_game()
 app.state.quest_stage=6;app.state.gain_xp(180);app.state.choose_sect("问石门")
 app.state.recruit_companion();app.toast_time=0;app.status_label.text="南庭验艺 · 以武明心";app.world.teleport(Vector2(650,675));app._refresh()
 await create_timer(0.3).timeout
 await _capture("19-south-court-mentor")
 app._interact("mentor");await _capture("20-sect-trial-briefing")
 app.sect_progress.begin();await _capture("21-sect-trial-battle")
 for turn in range(80):
  if not app.state.battle_active:break
  if app.state.hp<45 and app.state.medicine>0:app._battle_action("item")
  elif app.state.turn%2==1 and app.state.qi>=app.state.active_art_cost() and app.state.skill_cooldown==0:app._battle_action("skill")
  elif app.state.turn%2==1:app._battle_action("guard")
  else:app._battle_action("attack")
 if not app.state.sect_trial_won:
  push_error("Graphical trial did not satisfy real school conditions");quit(1);return
 await _capture("22-inner-disciple-earned")
 app.sect_progress.promote();app._show_martials()
 await _capture("23-inner-disciple-arts")
 app._close_modal();app._stop_audio();await create_timer(0.25).timeout
 app.queue_free();await process_frame
 print("PASS: 5 real rendered mentor progression captures saved to res://screenshots")
 quit()
