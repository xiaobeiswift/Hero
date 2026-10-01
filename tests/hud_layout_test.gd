extends SceneTree
## Full scene presentation contracts. No user save files are read or written.
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
var app
var checks:int=0
var failures:int=0
func _initialize()->void:run.call_deferred()
func check(value:bool,description:String)->void:
	checks+=1
	if not value:failures+=1;push_error(description)
func run()->void:
	app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame
	check(app.hud!=null,"Main scene owns the presentation helper")
	app._new_game();app._stop_audio();app.audio_on=false;app._process(0)
	check(app.world_view.size==Vector2i(1280,800),"World uses the complete logical viewport")
	check(app.world.viewport_rect==Rect2(0,0,1280,800),"Camera bounds agree with expanded world viewport")
	check(app.hud.exploration.visible,"Exploration HUD appears on starting a journey")
	check(not app.stat_label.visible and not app.exp_label.visible,"Secondary stats do not become a sidebar dashboard")
	check(app.hp_caption.position.y>=app.sect_label.position.y+app.sect_label.size.y,"Sect and health text do not overlap")
	check(app.hp_bar.position.y>=app.hp_caption.position.y+app.hp_caption.size.y,"Health caption clears health bar")
	check(app.qi_bar.position.y>=app.qi_caption.position.y+app.qi_caption.size.y,"Qi caption clears qi bar")
	check(app.hud.nav_buttons.size()==5,"All five exploration quick actions remain reachable")
	for button in app.hud.nav_buttons:
		check(button.get_global_rect().end.x<=1280 and button.get_global_rect().end.y<=800,"Quick action stays inside logical viewport")
		button.pressed.emit();check(app.active_modal,"Quick action opens its original modal")
		app._close_modal()
	var original_audio:bool=app.audio_on
	app.hud.music_button.pressed.emit();app.hud.tick(0)
	check(app.audio_on!=original_audio and app.hud.music_button.text==("乐音 开" if app.audio_on else "乐音 关"),"Nested audio control toggles and reports its actual state")
	app.audio_on=false;app._stop_audio()
	app.world.nearby_id="";app.hud.tick(0)
	check(not app.hud.interaction.visible,"Exploration has no permanent interaction banner")
	app.world.nearby_id="elder";app.world.nearby_name="陆伯";app._process(0)
	check(app.hud.interaction.visible and app.near_label.text.contains("陆伯"),"A nearby person gets a contextual interaction hint")
	app.toast_time=0;app.save_warning=false;app.hud.tick(0)
	check(not app.hud.toast_wash.visible,"Completed toast leaves an uncluttered world")
	app.save_warning=true;app.hud.tick(0)
	check(app.hud.toast_wash.visible and app.status_label.text.contains("F5"),"Save failure stays visible after a toast would expire")
	app.save_warning=false;app._toast("手记已写入");app.hud.tick(0)
	check(app.hud.toast_wash.visible and app.status_label.text.contains("手记已写入"),"Save success feedback is visible")
	app.state.quest_stage=1;app._refresh()
	check(app.hud.quest_notice_time>0 and app.hud.quest_notice.text.contains("行纪有续"),"Changed quest creates a short update notice")
	check(app.hud.quest_wash.tooltip_text.contains(app.hint_label.text),"Complete quest hint remains in the tracker tooltip")
	app.world.teleport(Vector2(70,160));app.hud.tick(1.0)
	check(app.hud.identity_wash.modulate.a<0.3,"HUD fades when it would obscure the player at the map edge")
	app.world.teleport(Vector2(470,615));app.hud.tick(1.0)
	check(app.hud.identity_wash.modulate.a==1.0,"HUD returns to full contrast after player moves clear")
	app._start_battle("training");app._process(0)
	check(not app.hud.exploration.visible and app.battle_layer.visible,"Combat gets a dedicated uncluttered HUD")
	check(not app.world.visible,"Opaque battle keeps exploration renderer hidden")
	check(app.battle_art.scale.x>1.3,"Battle stage fills the new screen width")
	check(app.battle_hp.size.x>=282 and app.battle_player_hp.size.x>=282,"Legacy bar deferral cannot shrink reflowed health bars")
	app.battle_player_hp.max_value=180;app.battle_player_hp.value=37.25
	check(app.hud.battle_player_value.text=="气血  37 / 180","Player numeric health follows the presented bar and its maximum")
	app.battle_hp.max_value=96;app.battle_hp.value=23.9
	check(app.hud.battle_enemy_value.text=="气血  24 / 96","Enemy numeric health follows tween values rather than the already-resolved model")
	app._refresh_battle()
	for i in range(app.battle_buttons.size()):
		var button:Button=app.battle_buttons[i]
		check(button.get_rect().end.x<=1280 and button.get_rect().end.y<=800,"Battle action stays inside logical viewport")
		if i>0:check(not button.get_rect().intersects(app.battle_buttons[i-1].get_rect()),"Adjacent battle actions never overlap")
	app.state.qi=0;app._refresh_battle()
	check(app.battle_buttons[1].disabled and app.battle_buttons[1].tooltip_text.contains("真气"),"Unavailable art reports the missing resource")
	app.state.hp=app.state.max_hp;app._refresh_battle()
	check(app.battle_buttons[3].disabled and app.battle_buttons[3].tooltip_text=="气血已满","Unneeded healing has a readable disabled reason")
	app.battle_busy=true;app.hud.tick(0)
	check(app.hud.battle_hint.text.contains("请稍候"),"Presentation lock is visibly acknowledged")
	app.battle_busy=false
	app._toast("截图已保存 · 本地 screenshots 文件夹");app.hud.tick(0)
	var notice:Rect2=app.hud.toast_wash.get_global_rect()
	check(app.hud.toast_wash.visible and Rect2(0,0,1280,800).encloses(notice),"Battle notice stays within viewport")
	check(not notice.intersects(Rect2(0,145,1280,340)),"Screenshot notice never covers duel actor silhouettes")
	var clear_buttons=true
	for button in app.battle_buttons:clear_buttons=clear_buttons and not notice.intersects(button.get_global_rect())
	check(clear_buttons,"Battle notice never obscures available action buttons")
	app.save_warning=true;app.toast_time=0;app.hud.tick(0)
	check(app.status_label.text.contains("F5") and app.hud.toast_wash.visible and app.status_label.tooltip_text==app.status_label.text,"Persistent save warning survives compact battle presentation")
	app.save_warning=false;app.battle_presentation_enabled=false;app._battle_action("flee");app._close_modal();app._toast("江湖已续");app.hud.tick(0)
	check(app.hud.toast_wash.position==Vector2(330,182) and not app.status_label.clip_text,"Exploration restores wrapping notice placement")
	app._stop_audio();app.queue_free();await process_frame
	print("%s: %d full-world wuxia HUD checks"%["PASS" if failures==0 else "FAIL",checks]);quit(0 if failures==0 else 1)
