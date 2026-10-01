extends "res://tests/visual_smoke.gd"
func _run() -> void:
 app=Scene.instantiate();app.state=VisualState.new();root.add_child(app)
 await create_timer(0.5).timeout
 app._stop_audio();app.audio_on=false;app._new_game()
 app.state.quest_stage=6;app.state.side_stage=3;app.state.side_choice="rescue";app.state.side_reward_claimed=true
 app.state.gain_xp(180);app.state.choose_sect("听潮阁")
 app.state.chapter_two_stage=4;app.state.chapter_two_ending="protect_witness";app.state.bridge_repaired=true
 app._travel("frostbridge",Vector2(650,810));app._interact("bridge_worker")
 await _capture("24-craft-notebook-request")
 app.companion_story.begin();app._travel("sluice",Vector2(570,360));app._interact("sluice_cache")
 await _capture("25-old-craft-notebook")
 app.companion_story.recover();app._travel("frostbridge",Vector2(650,810));app._interact("bridge_worker")
 await _capture("26-craft-legacy-choice")
 app.companion_story.resolve("teach");app.companion_story.recruit()
 app.companion_story.roster();await _capture("27-companion-roster")
 app._close_modal();app.world.teleport(Vector2(830,800));app.world.facing=Vector2.RIGHT;await create_timer(0.5).timeout;await _capture("28-travelling-craftsman")
 app._travel("qingwei",Vector2(1260,780));app.state.heal_rest();app.state.qi=0;app._start_battle("training");app._battle_action("attack");app._battle_action("attack")
 await _capture("29-craftsman-battle-support")
 app._battle_action("flee");app._close_modal();app._stop_audio();await create_timer(0.25).timeout
 app.queue_free();await process_frame
 print("PASS: 6 actual companion-story render captures saved")
 quit()
