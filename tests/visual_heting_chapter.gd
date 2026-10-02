extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
const Prefs=preload("res://scripts/view_preferences.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
class NoWritePrefs extends Prefs:
	func load_settings(_path:String=PATH)->Error:return OK
	func save_settings(_path:String=PATH)->Error:return OK
var app
func _initialize()->void:run.call_deferred()
func run()->void:
	root.size=Vector2i(1280,800);app=Scene.instantiate();app.state=NoSave.new();app.view_preferences=NoWritePrefs.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false
	var s=app.state
	s.quest_stage=6;s.ending="守望";s.choose_sect("听潮阁");s.gain_xp(600)
	s.side_stage=3;s.side_clues=2;s.side_found.assign(["boatman","ledger"]);s.side_choice="rescue";s.side_reward_claimed=true
	s.chapter_two_stage=4;s.chapter_two_ending="protect_witness";s.archive_clues.assign(["clerk","inscription"]);s.seal_sequence.assign([2,0,1])
	s.mist_stage=4;s.mist_approach="duel";s.mist_ending="warn_ferries";s.mist_gauges.assign(["rain","stone","basin"])
	s.bridge_repaired=true;s.tangqi_stage=3;s.tangqi_choice="teach";s.tangqi_unlocked=true;s.active_companion="唐栖"
	assert(s.begin_heting());app._travel("heting",Vector2(600,375));await capture("223-heting-north-arrival")
	app.world.teleport(Vector2(800,675));await capture("224-heting-working-harbor")
	app.world.teleport(Vector2(665,620));app._interact("heting_cargo");await capture("225-heting-cargo-paper")
	app._close_modal();assert(s.take_heting_cargo("meal"));app._sync_world_state();app.world.teleport(Vector2(820,735));app._interact("heting_winch");await capture("226-heting-winch-choice")
	app._close_modal();assert(s.set_heting_bridge("east"));app._sync_world_state();app._change_view_zoom(1);app.world.teleport(Vector2(1130,735));await capture("227-heting-loaded-east-pontoon")
	app._show_map();await capture("228-heting-paper-chart")
	app._close_modal();assert(s.deliver_heting_base("heting_relief"));assert(s.take_heting_cargo("sealed"));assert(s.deliver_heting_base("heting_scale"));app._sync_world_state();app.world.teleport(Vector2(535,350));app._interact("heting_dispatch");await capture("229-heting-night-choice")
	app._close_modal();assert(s.choose_heting_plan("short_ferries"));assert(s.take_heting_cargo("reserve"));assert(s.finish_heting_delivery("heting_relief","short_ferries"));app._sync_world_state();app.world.teleport(Vector2(235,805));app._refresh();await capture("230-heting-short-ferries-aftermath")
	app.queue_free();await create_timer(.25).timeout;print("PASS:8 prepared actual harbor world/paper/cargo/pontoon/aftermath captures");quit()
func capture(name:String)->void:
	app._refresh();app.toast_time=0;app.hud.quest_notice_time=0;await create_timer(.4).timeout;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/"+name+".png")==OK)
