extends "res://tests/record_heting_polish.gd"
## Supplemental prepared native battle invariance when exploration zoom settings
## differ. Actual three supported preference values; same guard snapshot/clock.
func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):out_dir=arg.trim_prefix("--out=")
	if out_dir.is_empty() or OS.get_environment("XDG_DATA_HOME").is_empty():quit(2);return
	DirAccess.make_dir_recursive_absolute(out_dir+"/screenshots")
	fixture="user://zoom-polish-qa";DirAccess.make_dir_recursive_absolute(fixture)
	seed(7531);s=State.new();s.fixture=fixture
	app=load("res://scenes/main.tscn").instantiate();app.set_script(CloseProbe);app.state=s
	root.add_child(app);await process_frame
	app._stop_audio();app.audio_on=false;app.set_process(false);app.world.set_process(false)
	app.view_preferences.full_resolution=true
	for compact: bool in [false,true]:
		await _window(compact)
		for formation_name: String in ["护后","并肩"]:
			var reference: Dictionary={}
			for zoom_index: int in range(3):
				app.view_preferences.zoom_index=zoom_index;app._apply_view_zoom()
				var panel=await _new_battle("heting_consignee",formation_name)
				if panel==null:continue
				await _settle()
				if zoom_index==0:reference=panel.art.display_snapshot.duplicate(true)
				else:check(panel.art.display_snapshot==reference,"Exact frozen battle snapshot unchanged by world zoom")
				await _capture("zoom-battle-%s-%s-z%d"%["protect" if formation_name=="护后" else "side","compact" if compact else "full",[100,125,160][zoom_index]],{"group":"zoom_invariance","formation":formation_name,"compact":compact,"world_zoom":app.view_zoom},panel)
	await _north_matrix()
	var result={"scope":"Supplemental exact frozen source-native battle frame comparison across exploration preference zoom100/125/160; both sizes/formations. No manual play/browser/FPS/export claim.","engine":Engine.get_version_info(),"display_server":DisplayServer.get_name(),"checks":checks,"failures":failures,"captures":captures}
	var file=FileAccess.open(out_dir+"/capture-trace.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("%s native zoom invariance: %d checks; %d frames; %d failures"%["PASS" if failures==0 else "FAIL",checks,captures.size(),failures])
	app.queue_free();await process_frame;quit(0 if failures==0 else 1)

func _north_matrix() -> void:
	s=_prepared("heting_consignee",4);s.fixture=fixture
	check(s.start_party_battle("heting_consignee"),"Actual supplemental cargo combat starts")
	for _turn: int in range(180):
		if not s.battle_active:break
		var tx: Dictionary=s.advance_party_battle()
		check(tx.get("accepted",false),"Actual supplemental transaction")
		if not tx.get("accepted",false):break
		check(s.finish_party_presentation(tx.epoch,tx.token).get("accepted",false),"Actual supplemental token")
	check(not s.battle_active and s.consignee_stage==3,"Actual secured supplemental finite lot")
	check(s.save_game(fixture+"/north-secured.json")==OK,"Isolated actual secured checkpoint")
	for compact: bool in [false,true]:
		await _window(compact)
		for zoom_index: int in range(3):
			for bridge: String in ["west","east"]:
				for loaded: bool in [false,true]:
					s=State.new();s.fixture=fixture;check(s.load_game(fixture+"/north-secured.json")==OK,"Restore north checkpoint")
					s.heting_bridge=bridge
					if loaded:check(s.take_consignee_cargo(s.Consignee.BATCH,s.Consignee.SOURCE),"Actual new paired-hamper load")
					app.state=s;app.current_screen="explore";app.active_modal=false;app._clear_overlay()
					app.view_preferences.zoom_index=zoom_index;app._apply_view_zoom()
					s.position=Vector2(1450,400);s.map_id="heting";app._sync_world_state();app.world.change_map("heting",s.position)
					app.world.camera_pos=app.world._camera_target();app.world._update_nearby();app._process(0);app._refresh()
					check(Harbor.walkable(s.position,bridge,loaded),"Unobstructed north observer on legal terrain")
					check(s._stage_save_data(s.to_dict(),s.SAVE_VERSION).ok,"Canonical north observation state")
					await _settle()
					await _capture("north-clear-%s-z%d-%s-%s"%["compact" if compact else "full",[100,125,160][zoom_index],bridge,"loaded" if loaded else "unloaded"],{"group":"harbor_north_unobstructed","compact":compact,"zoom":app.view_zoom,"bridge":bridge,"loaded":loaded,"view":"north_clear"},null)
