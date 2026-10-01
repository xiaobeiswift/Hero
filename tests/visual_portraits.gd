extends "res://tests/visual_smoke.gd"
func _run()->void:
 app=Scene.instantiate();app.state=VisualState.new();root.add_child(app)
 await create_timer(0.5).timeout
 app._stop_audio();app.audio_on=false;app._new_game()
 await _capture("52-original-hero-portrait")
 app.world.teleport(Vector2(330,365));app._interact("healer")
 await _capture("53-shen-dialogue-portrait");app._close_modal()
 app.state.quest_stage=6;app.state.ending="守望";app.state.choose_sect("听潮阁");app.state.gain_xp(600)
 app.state.side_stage=3;app.state.side_choice="rescue";app.state.side_reward_claimed=true;app.state.side_found.assign(["boatman","ledger"]);app.state.side_clues=2
 app.state.chapter_two_stage=4;app.state.chapter_two_ending="open_records";app.state.archive_clues.assign(["clerk","inscription"]);app.state.seal_sequence.assign([2,0,1]);app.state.bridge_repaired=true
 app._travel("frostbridge",Vector2(650,800));app._interact("bridge_worker")
 await _capture("54-tang-dialogue-portrait");app._close_modal()
 app.mist_story.enter_region();app.world.teleport(Vector2(350,405));app._interact("mist_guide")
 await _capture("55-qin-dialogue-portrait");app._close_modal()
 app._stop_audio();await create_timer(0.25).timeout;app.queue_free();await process_frame
 print("PASS: 4 original portrait captures saved")
 quit()
