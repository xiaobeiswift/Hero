extends "res://tests/visual_smoke.gd"
const Slots=preload("res://scripts/local_save_slots.gd")
class SlotVisualState extends Model:
 var auto_path:String
 func save_game(path:String=SAVE_PATH)->Error:return super.save_game(auto_path if path==SAVE_PATH else path)
 func load_game(path:String=SAVE_PATH)->Error:return super.load_game(auto_path if path==SAVE_PATH else path)
 func has_save()->bool:return FileAccess.file_exists(auto_path)
func _run()->void:
 var folder="user://hero-visual-slots-"+str(Time.get_unix_time_from_system()).replace(".","-")
 DirAccess.make_dir_recursive_absolute(folder)
 app=Scene.instantiate();app.state=SlotVisualState.new();app.state.auto_path=folder.path_join("hero_save.json");root.add_child(app)
 await create_timer(0.5).timeout
 app.save_slots.store=Slots.new(folder);app._stop_audio();app.audio_on=false;app._new_game()
 app.save_slots.perform_save(1)
 app.state.quest_stage=6;app.state.ending="守望";app.state.choose_sect("听潮阁");app.state.gain_xp(600)
 app.state.side_stage=3;app.state.side_choice="rescue";app.state.side_reward_claimed=true;app.state.side_found.assign(["boatman","ledger"]);app.state.side_clues=2
 app.state.chapter_two_stage=4;app.state.chapter_two_ending="open_records";app.state.archive_clues.assign(["clerk","inscription"]);app.state.seal_sequence.assign([2,0,1])
 app._travel("frostbridge",Vector2(400,420));app.save_slots.perform_save(2)
 app.state.begin_mistwood();app._travel("mistwood",Vector2(410,425));app.save_slots.perform_save(3)
 await _capture("46-three-manual-save-slots")
 app.save_slots.load_page();await _capture("47-autosave-and-manual-list")
 app.save_slots.request_save(2);await _capture("48-manual-overwrite-confirmation")
 app.save_slots.perform_save(2);app.save_slots.detail(2);await _capture("49-previous-save-backup")
 app.save_slots.request_load(2,true);await _capture("50-backup-load-confirmation")
 app.save_slots.perform_load(2,true);app._show_title();await _capture("51-title-manual-save-entry")
 app._stop_audio();await create_timer(0.25).timeout;app.queue_free();await process_frame
 print("PASS: 6 isolated manual-save rendered captures saved")
 quit()
