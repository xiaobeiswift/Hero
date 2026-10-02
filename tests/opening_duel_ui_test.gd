extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
const Prefs=preload("res://scripts/view_preferences.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
class NoPrefs extends Prefs:
	func load_settings(_path:String=PATH)->Error:return OK
	func save_settings(_path:String=PATH)->Error:return OK
var app
var checks:int=0
var failures:int=0
func _initialize()->void:run.call_deferred()
func check(value:bool,reason:String)->void:
	checks+=1
	if not value:failures+=1;push_error(reason)
func key(code:int)->void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event);await process_frame
	event=InputEventKey.new();event.physical_keycode=code;event.pressed=false;Input.parse_input_event(event);await process_frame
func finish()->void:
	app.battle_art._process(3.0);app.hud.tick(0)
func settle()->void:
	for tween in app._battle_health_tweens.values():
		if tween.is_valid():tween.pause();tween.custom_step(.3)
func fresh(kind:String,companion:String="",formation:String="护后")->void:
	app._close_modal();app.state=NoSave.new();app.state.companion_unlocked=companion=="沈青";app.state.tangqi_unlocked=companion=="唐栖";app.state.tangqi_stage=3 if companion=="唐栖" else 0
	app.state.active_companion=companion;app.state.formation=formation
	app._start_battle(kind);app._process(0)
func run()->void:
	app=Scene.instantiate();app.state=NoSave.new();app.view_preferences=NoPrefs.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false;app.battle_presentation_enabled=true;app.battle_art.set_process(false)
	var hud=app.hud.duel_hud
	var count:int=app.battle_layer.get_child_count()
	for window in [Vector2i(1280,800),Vector2i(1180,737)]:
		root.size=window
		for companion in ["","沈青","唐栖"]:
			for formation in ["护后","并肩"]:
				fresh("story",companion,formation)
				check(hud.active and app.battle_art.scale==Vector2.ONE,"Opening encounter uses the full logical formation stage")
				check(app.battle_art.get_rect().encloses(Rect2(0,0,1280,635)),"Inherited clip rectangle includes the full floor and all feet")
				check(hud.hero_bar.size.y<=6 and hud.enemy_bar.size.y<=6,"Compact overhead bars do not inherit a tall default theme minimum")
				check(not app.hud.battle_chrome.visible and not app.battle_title.visible,"Legacy oversized chrome is hidden in opening mode")
				check(hud.support_card.visible==not companion.is_empty(),"Solo and recruited support use truthful overhead labels")
				check(hud.enemy_title.text=="蒲横" and not hud.status.text.contains("护手"),"Opening opponent keeps its original identity without fake guard mechanics")
				check(hud.enemy_title.mouse_filter==Control.MOUSE_FILTER_PASS and hud.enemy_title.tooltip_text==app.state.enemy_name,"Full original enemy name remains available on hover")
				check(hud.brief_log.mouse_filter==Control.MOUSE_FILTER_PASS and hud.brief_log.tooltip_text==app.battle_log.text,"Compact log retains mouse access to all recent events")
				check(hud.hero_bar.value==app.state.hp and hud.enemy_bar.value==app.state.enemy_hp,"Overhead health starts from exact existing encounter values")
				check(Rect2(0,65,1280,570).encloses(hud.hero_card.get_rect()) and Rect2(0,65,1280,570).encloses(hud.enemy_card.get_rect()),"Local health cards fit the actual battlefield")
				check(hud.hero_card.modulate.a==1 and hud.enemy_card.modulate.a==1,"Idle cards remain readable")
				for i in range(5):
					var box:Rect2=app.battle_buttons[i].get_rect()
					check(Rect2(0,680,1280,90).encloses(box),"Command stays inside compact action belt")
					if i>0:check(not box.intersects(app.battle_buttons[i-1].get_rect()),"Commands never overlap")
				var original:Dictionary=app.state.to_dict().duplicate(true)
				for i in range(4):app.hud.tick(.1)
				check(app.state.to_dict()==original,"Layout and overhead state tracking do not mutate gameplay")
				app._battle_action("flee");finish()
				check(not hud.active and app.battle_art.scale.x>1.3,"Leaving restores legacy stage geometry for later encounters")
	fresh("training","沈青")
	app.state.hp=40;app.state.qi=0;app._refresh_battle()
	check(app.battle_buttons[1].disabled and app.battle_buttons[1].tooltip_text.contains("真气"),"Skill disabled reason survives compact commands")
	await key(KEY_4);app.hud.tick(0)
	check(app.battle_busy and hud.hero_bar.value==40,"Real medicine key begins at pre-healing HP")
	check(hud.status.text.contains("交锋中"),"Action status acknowledges both sides instead of falsely labeling player attack")
	var after:Dictionary=app.state.to_dict().duplicate(true)
	await key(KEY_1);await key(KEY_3)
	check(app.state.to_dict()==after,"Keyboard input cannot resolve another turn during motion")
	app.battle_art._process(.26);settle();app.hud.tick(0)
	check(hud.hero_bar.value==85 and hud.hero_value.text.contains("85 / 100"),"Overhead HP follows healing impact tween before the counter")
	app.battle_art._process(.63);settle();app.hud.tick(0)
	check(hud.hero_bar.value==app.state.hp,"Counter updates the same overhead health presentation")
	finish();check(not app.battle_busy and not app.battle_buttons[0].disabled,"End of exchange releases existing controls")
	app._battle_action("attack");app.battle_art._process(.33);app.hud.tick(0)
	check(hud.hero_card.modulate.a==0,"Moving attacker plate hides while feet advance to the target")
	finish();check(hud.hero_card.modulate.a==1,"Attacker plate returns to its formation slot after motion")
	app.state.enemy_hp=1;app._battle_action("attack");finish()
	check(app.current_screen=="explore" and app.active_modal and not hud.active,"Finisher returns through the original reward dialog")
	var coins:int=app.state.coins;app._battle_action("attack")
	check(app.state.coins==coins,"Disabled post-result input cannot duplicate rewards")
	fresh("sluice_scout")
	check(not hud.active and app.hud.battle_chrome.visible and app.enemy_title.visible,"Other real opponents retain the original tested layout")
	check(app.battle_art.scale.x>1.3 and app.battle_buttons[0].position==Vector2(58,706),"Legacy command and art geometry restore exactly")
	await key(KEY_1);finish();check(app.state.turn==1,"Fallback opponent still accepts normal combat input")
	app._battle_action("flee");finish();fresh("story")
	check(hud.active and app.battle_layer.get_child_count()==count,"Repeated mode changes never duplicate controls or signal owners")
	app.save_warning=true;app.toast_time=0;app.hud.tick(0)
	check(app.hud.toast_wash.visible and app.status_label.text.contains("F5"),"Persistent save warning stays available outside the action belt")
	for button in app.battle_buttons:check(not app.hud.toast_wash.get_rect().intersects(button.get_rect()),"Save warning does not obstruct battle commands")
	app._stop_audio();app.queue_free();await process_frame
	print("%s: %d opening duel controller and compact HUD checks"%["PASS" if failures==0 else "FAIL",checks]);quit(0 if failures==0 else 1)
