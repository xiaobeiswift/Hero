extends "res://tests/unified_combat_ui_test.gd"
## Staged native paint validation. Explicit prepared story eligibility, actual
## combat APIs and finite-lot loading; legal relocated observation points.
## Every root image is an unedited actual Godot framebuffer.
const Harbor = preload("res://scripts/heting_region.gd")
var out_dir := ""
var mode := "native"
var captures: Array[Dictionary] = []
var harbor_base: Dictionary = {}
var captured_labels := [
	{"id":"north_road","p":Vector2(1033,316),"text":"北岸横街  ·  板车可绕行","font_size":14,"width":297.0},
	{"id":"foot_pier","p":Vector2(710,410),"text":"窄步栈  ·  行人通行","font_size":13,"width":195.0},
	{"id":"cart_qualifier","p":Vector2(709,426),"text":"板车走侧浮栈","font_size":13,"width":195.0}]

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_dir=arg.trim_prefix("--out=")
		if arg.begins_with("--mode="): mode=arg.trim_prefix("--mode=")
	if out_dir.is_empty() or OS.get_environment("XDG_DATA_HOME").is_empty():quit(2);return
	DirAccess.make_dir_recursive_absolute(out_dir+"/screenshots")
	fixture="user://polish-qa";DirAccess.make_dir_recursive_absolute(fixture)
	seed(7531)
	s=State.new();s.fixture=fixture
	app=load("res://scenes/main.tscn").instantiate();app.set_script(CloseProbe);app.state=s
	root.add_child(app);await process_frame
	app._stop_audio();app.audio_on=false;app.set_process(false);app.world.set_process(false)
	app.view_preferences.full_resolution=true
	await _legacy_matrix()
	await _warehouse_matrix()
	await _harbor_matrix()
	var result={"scope":"Prepared source-native full-main fixture with actual combat transactions and finite new cargo loading. Frozen clocks; separate baseline/candidate processes. No manual play, browser, audio, export, release or FPS claim.","engine":Engine.get_version_info(),"display_server":DisplayServer.get_name(),"checks":checks,"failures":failures,"captures":captures}
	var file=FileAccess.open(out_dir+"/capture-trace.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("%s native polish: %d checks; %d frames; %d failures"%["PASS" if failures==0 else "FAIL",checks,captures.size(),failures])
	app.queue_free();await process_frame;quit(0 if failures==0 else 1)

func _window(compact: bool) -> void:
	# Godot's canvas-items aspect-kept root produces exactly1179x736 from737.
	root.size=Vector2i(1179,737) if compact else Vector2i(1280,800)
	await process_frame

func _settle() -> void:
	app._process(0)
	app.world.time_passed=.375;app.world.queue_redraw()
	for _i in range(3):await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw

func _new_battle(kind:String, formation_name:String) -> Variant:
	_setup(kind,2 if kind=="story" else (4 if kind in ["heting_receipt","heting_consignee","training","sect_trial","courtyard_practice"] else 2))
	check(s.set_formation(formation_name),"Actual formation API "+kind+" "+formation_name)
	if kind=="heting_consignee":app.active_modal=true
	check(app._start_unified_battle(kind),"Actual full-main battle entry "+kind)
	var panel=app.overlay.get_meta("party_battle",null)
	if panel==null:return null
	panel.set_process(false);panel.art.set_process(false);panel.art._clock=.375
	panel.refresh();app._process(0)
	return panel

func _legacy_matrix() -> void:
	for compact: bool in [false,true]:
		await _window(compact)
		for formation_name: String in ["护后","并肩"]:
			for kind: String in PhaseOneBoundary.READY_IDS:
				if kind=="heting_consignee":continue
				var panel=await _new_battle(kind,formation_name)
				if panel==null:continue
				await _settle()
				await _capture("legacy-%s-%s-%s"%[kind,"protect" if formation_name=="护后" else "side","compact" if compact else "full"],{"group":"legacy","encounter":kind,"formation":formation_name,"compact":compact},panel)

func _warehouse_matrix() -> void:
	for compact: bool in [false,true]:
		await _window(compact)
		for formation_name: String in ["护后","并肩"]:
			var panel=await _new_battle("heting_consignee",formation_name)
			if panel==null:continue
			var prefix="warehouse-%s-%s-"%["protect" if formation_name=="护后" else "side","compact" if compact else "full"]
			var meta={"group":"warehouse","formation":formation_name,"compact":compact}
			await _settle();await _capture(prefix+"guard",meta,panel)
			var found={"windup":false,"contact":false,"return":false,"opening":false,"hurt":false,"kneel":false}
			for turn: int in range(180):
				if not s.battle_active or not is_instance_valid(panel):break
				panel._process(.5)
				if not panel.art.is_presenting():continue
				for stop: float in [.18,.40,.64]:
					panel.art._process(maxf(0,stop-panel.art.action_time));panel.art._clock=.375;panel.refresh()
					var phase="windup" if stop<.3 else ("contact" if stop<.5 else "return")
					if not found[phase]:
						await _settle();await _capture(prefix+phase,meta,panel);found[phase]=true
					for unit: Dictionary in panel.art.display_snapshot.actors+panel.art.display_snapshot.enemies:
						var pose: String=panel.art.actor_visual_pose(unit.id)
						if not found.hurt and pose=="hurt":
							await _settle();await _capture(prefix+"hurt",meta,panel);found.hurt=true
				panel.art._process(panel.art.get_presentation_duration()+.1)
				if not s.battle_active or not is_instance_valid(panel):break
				panel.art._clock=.375;panel.refresh()
				var snap: Dictionary=s.party_battle_snapshot()
				for enemy: Dictionary in snap.enemies:
					if not found.opening and enemy.hp>0 and int(enemy.get("opening_bonus",0))>0:
						await _settle();await _capture(prefix+"opening",meta,panel);found.opening=true
					if not found.kneel and enemy.hp==0:
						await _settle();await _capture(prefix+"kneel",meta,panel);found.kneel=true
				if found.values().all(func(value):return value):break
			for key in found:check(found[key],"Actual consignee pose captured "+key+prefix)

func _harbor_matrix() -> void:
	# Prepared old-story eligibility, then actual accepted battle transactions
	# earn the secured stage and the normal loading API moves the one new lot.
	s=_prepared("heting_consignee",4);s.fixture=fixture
	check(s.start_party_battle("heting_consignee"),"Model starts canonical actual consignee combat for cargo")
	for _turn: int in range(180):
		if not s.battle_active:break
		var tx: Dictionary=s.advance_party_battle()
		check(tx.get("accepted",false),"Actual cargo-earning combat transaction")
		if not tx.get("accepted",false):break
		check(s.finish_party_presentation(tx.epoch,tx.token).get("accepted",false),"Actual token acknowledged once")
	check(not s.battle_active and s.consignee_stage==3,"Unboosted real combat earned secured finite lot")
	harbor_base=s.to_dict().duplicate(true)
	check(s.save_game(fixture+"/secured.json")==OK,"Save genuinely secured isolated checkpoint")
	for compact: bool in [false,true]:
		await _window(compact)
		for zoom_index: int in range(3):
			for bridge: String in ["west","east"]:
				for loaded: bool in [false,true]:
					s=State.new();s.fixture=fixture
					check(s.load_game(fixture+"/secured.json")==OK,"Restore canonical secured harbor fixture")
					s.heting_bridge=bridge
					if loaded:check(s.take_consignee_cargo(s.Consignee.BATCH,s.Consignee.SOURCE),"Normal API loads actual paired-hamper finite lot")
					app.state=s;app.current_screen="explore";app.active_modal=false;app._clear_overlay()
					app.view_preferences.zoom_index=zoom_index;app._apply_view_zoom()
					var views={"north":Vector2(1170,400),"foot":Vector2(980,415),"pontoon":Vector2(315,727) if bridge=="west" else Vector2(1330,727)}
					for view: String in views:
						s.position=views[view];s.map_id="heting";app._sync_world_state();app.world.change_map("heting",s.position)
						app.world.camera_pos=app.world._camera_target();app.world._update_nearby();app._process(0);app._refresh()
						check(Harbor.walkable(s.position,bridge,loaded),"Capture player is on legal terrain")
						check(app.world.heting_cart_loaded()==loaded,"Actual loaded predicate matches matrix")
						check(s._stage_save_data(s.to_dict(),s.SAVE_VERSION).ok,"Matrix state remains canonical")
						await _settle()
						var name="harbor-%s-z%d-%s-%s-%s"%["compact" if compact else "full",[100,125,160][zoom_index],bridge,"loaded" if loaded else "unloaded",view]
						await _capture(name,{"group":"harbor","compact":compact,"zoom":app.view_zoom,"bridge":bridge,"loaded":loaded,"view":view},null)

func _capture(name:String,meta:Dictionary,panel:Variant) -> void:
	var frame: Dictionary=meta.duplicate(true)
	frame.name=name;frame.clock=.375;frame.screen=app.current_screen
	if panel!=null:
		frame.snapshot=panel.art.display_snapshot
		frame.phase=panel.art.presentation_phase;frame.action_time=panel.art.action_time
		frame.units={}
		for unit: Dictionary in panel.art.display_snapshot.actors+panel.art.display_snapshot.enemies:
			frame.units[unit.id]={"pose":panel.art.actor_visual_pose(unit.id),"foot":_vec(panel.art.actor_foot(unit.id)),"label":_area(panel.art.unit_label_rect(unit.id)),"label_alpha":panel.art.unit_label_alpha(unit.id)}
		frame.command_rect=_area(panel.commands.get_global_rect())
	else:
		frame.state=s.to_dict();frame.camera=_vec(app.world.camera_pos);frame.world_viewport=_area(app.world.viewport_rect)
		frame.visual=Harbor.consignee_visual_state(true,s.consignee_stage,s.consignee_cargo_location,s.consignee_ending)
		frame.labels=[]
		var route_script: Script=load("res://scripts/heting_region.gd")
		var route_constants: Dictionary=route_script.get_script_constant_map()
		var actual_route_ink: String=String(route_constants.ROUTE_INK.to_html(false)) if route_constants.has("ROUTE_INK") else "baseline_per_call_colors"
		var actual_route_outline: String=String(route_constants.PAPER.to_html(false)) if route_constants.has("ROUTE_OUTLINE_SIZE") else "none"
		var labels: Array=captured_labels.duplicate(true)
		var rect: Rect2=Harbor.WEST_PONTOON if s.heting_bridge=="west" else Harbor.EAST_PONTOON
		labels.append({"id":"pontoon","p":rect.position+Vector2(16,47),"text":"连 舟 浮 栈","font_size":13,"width":rect.size.x-32})
		for label: Dictionary in labels:
			var p: Vector2=(label.p-app.world.camera_pos)*app.view_zoom
			var extent: Vector2=app.world.ui_font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.font_size)*app.view_zoom
			var left: float=p.x+(label.width*app.view_zoom-extent.x)/2
			frame.labels.append({"id":label.id,"text":label.text,"font_size":label.font_size,"baseline_logical":_vec(p),"logical_rect":[left,p.y-extent.y,extent.x,extent.y+4*app.view_zoom],"render_scale":app.view_zoom,"declared_fill":actual_route_ink,"declared_outline":actual_route_outline})
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var pixels: Image=root.get_texture().get_image()
		check(pixels.get_width()==(1179 if bool(meta.compact) else 1280) and pixels.get_height()==(736 if bool(meta.compact) else 800),"Actual pixel dimensions "+name)
		check(pixels.save_png(out_dir+"/screenshots/"+name+".png")==OK,"Native PNG "+name)
		frame.width=pixels.get_width();frame.height=pixels.get_height()
	captures.append(frame)
	var journal=FileAccess.open(out_dir+"/capture-progress.json",FileAccess.WRITE);journal.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures},"\t"));journal.close()

func _vec(p:Vector2)->Array:return [p.x,p.y]
func _area(r:Rect2)->Array:return [r.position.x,r.position.y,r.size.x,r.size.y]
