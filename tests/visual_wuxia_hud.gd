extends SceneTree
## Real engine captures at native and compact desktop sizes; no static mockups.
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
var app
func _initialize()->void:run.call_deferred()
func run()->void:
	root.size=Vector2i(1280,800)
	app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false
	app.world.teleport(Vector2(470,615));app.toast_time=0;app.hud.quest_notice_time=0
	await capture("99-wuxia-hud-world-1280")
	app.world.teleport(Vector2(70,160))
	await capture("106-wuxia-hud-corner-visibility")
	app.world.teleport(Vector2(330,365));app.toast_time=0
	await capture("100-wuxia-hud-context")
	app._start_battle("training");app.state.qi=0;app._refresh_battle();app.toast_time=0
	await capture("101-wuxia-hud-battle")
	app.state.qi=6;app.state.hp=60;app._refresh_battle();app._battle_action("attack")
	await create_timer(.35).timeout;await capture("102-wuxia-hud-action",false)
	if app.battle_busy:await app.battle_art.presentation_finished
	app.battle_presentation_enabled=false;app._battle_action("flee");app.toast_time=0
	app.world.teleport(Vector2(470,615));app.hud.quest_notice_time=0
	root.size=Vector2i(1180,737)
	await capture("103-wuxia-hud-world-1180")
	app.save_warning=true;app.toast_time=0
	await capture("104-wuxia-hud-save-warning")
	app.save_warning=false;app._show_inventory()
	await capture("105-wuxia-hud-inventory")
	app._stop_audio();app.queue_free();await create_timer(.25).timeout
	print("PASS: 8 actual-engine wuxia HUD captures at 1280x800 and 1180x737");quit()
func capture(id:String,settle:bool=true)->void:
	if settle:await create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png("res://screenshots/"+id+".png")!=OK:push_error("Capture failed: "+id);quit(1)
