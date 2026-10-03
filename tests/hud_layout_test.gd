extends SceneTree
const PartyFixture=preload("res://tests/party_exploration_fixture.gd")
const UnifiedUI = preload("res://tests/unified_ui_test_driver.gd")
## Full scene presentation contracts. No user save files are read or written.
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class NoSave extends Model:
	var fail_saves:bool=false
	func save_game(_path:String=SAVE_PATH)->Error:return ERR_CANT_CREATE if fail_saves else OK
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
	app.state.fail_saves=true;app._autosave();app.hud.tick(0)
	check(app.save_warning and app.status_label.text.count("存档失败")==1 and app.status_label.text.count("F5")==1,"Autosave failure displays exactly one recovery warning")
	app._save();app.hud.tick(0)
	check(app.status_label.text.count("存档失败")==1 and app.status_label.text.count("F5")==1 and app.status_label.text.contains("错误码"),"Manual retry failure retains error detail without duplicating the warning")
	app._toast("已接下新的机缘");app.hud.tick(0)
	check(app.status_label.text.contains("已接下新的机缘") and app.status_label.text.count("存档失败")==1,"Unrelated success toast still carries the unresolved save warning")
	app.toast_time=0;app.hud.tick(0)
	check(app.hud.toast_wash.visible and app.status_label.text.count("F5")==1,"Deduplicated warning remains after the transient notice expires")
	app.state.fail_saves=false;app._save();app.hud.tick(0)
	check(not app.save_warning and app.status_label.text.contains("已存档") and not app.status_label.text.contains("F5"),"Successful retry clears failure notice normally")
	app.state.quest_stage=1;app._refresh()
	check(app.hud.quest_notice_time>0 and app.hud.quest_notice.text.contains("行纪有续"),"Changed quest creates a short update notice")
	check(app.hud.quest_wash.tooltip_text.contains(app.hint_label.text),"Complete quest hint remains in the tracker tooltip")
	app.world.teleport(Vector2(70,160));app.hud.tick(1.0)
	check(app.hud.identity_wash.modulate.a<0.3,"HUD fades when it would obscure the player at the map edge")
	app.world.teleport(Vector2(470,615));app.hud.tick(1.0)
	check(app.hud.identity_wash.modulate.a==1.0,"HUD returns to full contrast after player moves clear")
	_follower_visibility()
	var controller = UnifiedUI.open_training(app);app._process(0)
	check(not app.hud.exploration.visible and controller.visible,"Combat gets a dedicated uncluttered HUD")
	check(not app.world.visible,"Opaque battle keeps exploration renderer hidden")
	check(controller.art.scale==Vector2.ONE,"Unified formation stage fills the logical viewport without double scaling")
	for unit:Dictionary in controller.art.display_snapshot.actors+controller.art.display_snapshot.enemies:
		check(controller.unit_plates[unit.id].facts.hp==unit.hp and controller.unit_plates[unit.id].facts.max_hp==unit.max_hp,"Each overhead plate follows exact presented health and maximum")
	for group in controller.commands.groups.values():
		check(Rect2(0,0,1280,800).encloses(group),"Every occupied actor command group stays inside viewport")
	check(controller.commands.groups.size()==1,"Solo battle displays only its real occupied actor group")

	app._toast("截图已保存 · 本地 screenshots 文件夹");app.hud.tick(0)
	var message:String=controller.commands.context.target_prompt
	var notice:Rect2=controller.commands.notice_geometry(message)
	check(message.contains("截图已保存") and Rect2(0,0,1280,800).encloses(notice),"Actual current battle screenshot notice is displayed within viewport")
	var clear_actors:bool=true
	for id:String in controller.art.actor_order():clear_actors=clear_actors and not notice.intersects(controller.art.actor_alpha_rect(id))
	check(clear_actors,"Screenshot notice clears actual current actor silhouettes")
	var clear_buttons=true
	for group in controller.commands.groups.values():clear_buttons=clear_buttons and not notice.intersects(group)
	check(clear_buttons,"Battle notice never obscures available action buttons")
	app.save_warning=true;app.toast_time=0;app.hud.tick(0);controller.refresh()
	check(controller.commands.context.target_prompt.contains("F5") and controller.commands.context.target_prompt==app._save_retry_message(),"Persistent save warning stays visible in the current controller after ordinary toast expiry")
	app.save_warning=false;app.battle_presentation_enabled=false;UnifiedUI.leave(app);app._close_modal();app._toast("江湖已续");app.hud.tick(0)
	check(app.hud.toast_wash.position==Vector2(330,182) and not app.status_label.clip_text,"Exploration restores wrapping notice placement")
	app._stop_audio();app.queue_free();await process_frame
	print("%s: %d full-world wuxia HUD checks"%["PASS" if failures==0 else "FAIL",checks]);quit(0 if failures==0 else 1)

func _follower_visibility() -> void:
	# Prepared render fixtures isolate all-actor HUD occlusion at supported zooms.
	# These cached poses make no movement, recruitment, or saved-resource claim.
	var old_zoom:int=app.view_preferences.zoom_index
	for zoom_index in range(3):
		app.view_preferences.zoom_index=zoom_index;app._apply_view_zoom()
		app.world.teleport(Vector2(600,450))
		var player_point:Vector2=(app.world.player_pos-app.world.camera_pos)*app.view_zoom
		var player_rect:Rect2=Rect2(player_point-Vector2(27,80)*app.view_zoom,Vector2(54,90)*app.view_zoom)
		var panels:Array=[app.hud.identity_wash,app.hud.quest_wash,app.hud.place_wash]
		panels.append_array(app.hud.nav_buttons)
		for panel:Control in panels:
			var panel_rect:Rect2=panel.get_rect()
			check(not panel_rect.intersects(player_rect),"Follower-only HUD fixture keeps player clear at zoom "+str(app.view_zoom))
			var foot:Vector2=app.world.camera_pos+panel_rect.get_center()/app.view_zoom+Vector2(0,35)
			for id in ["shen","tang","qin"]:
				var persistent:Dictionary=app.state.to_dict()
				PartyFixture.prepare_render(app.world,[PartyFixture.render_frame(id,foot)])
				app.hud.tick(1.0)
				check(panel.modulate.a<.3,"HUD corner/quick-action region fades for "+id+" at zoom "+str(app.view_zoom))
				PartyFixture.prepare_render(app.world,[]);app.hud.tick(1.0)
				check(panel.modulate.a==1.0,"HUD region restores contrast after follower clears: "+id)
				check(app.state.to_dict()==persistent,"Prepared follower visibility does not alter player progress or resources")
	app.view_preferences.zoom_index=old_zoom;app._apply_view_zoom()
	app.world.teleport(Vector2(470,615));app.hud.tick(1.0)
