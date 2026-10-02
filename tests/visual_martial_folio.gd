extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
var app
func _initialize()->void:run.call_deferred()
func run()->void:
	root.size=Vector2i(1280,800);app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame;app._new_game();app._stop_audio();app.audio_on=false
	app._show_martials();await capture("213-martial-folio-first-journey");app._close_modal()
	app.state.quest_stage=6;app.state.choose_sect("听潮阁");app.state.gain_xp(180);app.state.art_uses["回潮断浪"]=4;app._refresh();app._show_martials();await capture("214-martial-folio-school-pages");app._close_modal()
	root.size=Vector2i(1180,737);app.state.sect_trial_won=true;assert(app.state.complete_sect_trial());app.state.sect_merit=5
	var ids=app.state.school_art_ids();assert(app.state.learn_art(ids[2]) and app.state.learn_art(ids[3]));app.state.art_uses[ids[1]]=15;app.state.art_uses[ids[2]]=7;app.state.equip_art(ids[3]);app._refresh();app._show_martials();await capture("215-martial-folio-four-moves-compact")
	app.queue_free();await create_timer(.25).timeout;print("PASS: martial loadout folio native captures");quit()
func capture(name:String)->void:
	await create_timer(.4).timeout;await RenderingServer.frame_post_draw;assert(root.get_texture().get_image().save_png("res://screenshots/"+name+".png")==OK)
