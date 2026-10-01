extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
var app
func _initialize()->void:run.call_deferred()
func run()->void:
	root.size=Vector2i(1280,800);app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false;app.world.teleport(Vector2(485,460));app._interact("elder");await capture("189-paper-dialogue-elder")
	app._close_modal();app.state.quest_stage=3;app.world.teleport(Vector2(355,350));app._interact("healer");await capture("190-paper-dialogue-shen")
	app._close_modal();app.state.quest_stage=6;app.state.choose_sect("听潮阁");app.state.sect_rank=2;app.world.teleport(Vector2(670,725));app._interact("mentor");await capture("191-paper-dialogue-five-choices")
	app._close_modal();root.size=Vector2i(1180,737);app._show_journal();await capture("192-paper-journal-compact")
	app.queue_free();await create_timer(.25).timeout;print("PASS: four actual paper dialogue and journal captures");quit()
func capture(name:String)->void:
	app.toast_time=0;app.hud.quest_notice_time=0;await create_timer(.4).timeout;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/"+name+".png")==OK)
