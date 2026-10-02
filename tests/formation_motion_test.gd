extends SceneTree
## Accepted transactions drive every assertion. Headless canvas coverage is
## separate from native screenshot review of the integrated controller.
const Art=preload("res://scripts/formation_battle_art.gd")
const State=preload("res://scripts/game_state.gd")
const Rules=preload("res://scripts/heting_receipt_combat.gd")
var checks:int=0
var failures:int=0
var completions:int=0
var frames:int=0
var impacts:Array=[]
var requests:Array=[]
var art
var ground:PackedVector2Array

func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures+=1;push_error(label)

func source_for(formation:String="并肩"):
	var state=State.new()
	state.max_hp=180;state.hp=130;state.attack=16;state.defense=4
	state.max_qi=8;state.qi=6;state.medicine=2;state.formation=formation
	state.shen_care_stage=5;state.shen_care_choice="mobile"
	return state

func rules_for(state,companion:String="沈青"):
	var rules=Rules.new();check(rules.configure(state),"Real encounter configures")
	rules.companion=companion;rules._support_count=1
	return rules

func unit(snapshot:Dictionary,id:String)->Dictionary:
	for actor:Dictionary in snapshot.units:
		if actor.id==id:return actor
	return {}

func advance_to(time:float)->void:
	art._process(maxf(0,time-art.action_time))

func check_geometry(context:String)->void:
	var ordered:Array[String]=art.actor_order()
	var previous:float=-INF
	var grounded:bool=true;var sorted:bool=true;var labels_clear:bool=true;var cards_clear:bool=true;var picking:bool=true
	for id:String in ordered:
		var foot:Vector2=art.actor_foot(id)
		sorted=sorted and foot.y>=previous;previous=foot.y
		# The complete visible shadow, not just its center, stays on the dock.
		for offset:Vector2 in [Vector2.ZERO,Vector2(-54,5),Vector2(54,5),Vector2(0,-5),Vector2(0,15)]:
			grounded=grounded and Geometry2D.is_point_in_polygon(foot+offset,ground)
		if art.unit_label_alpha(id)>0:
			var label:Rect2=art.unit_label_rect(id)
			labels_clear=labels_clear and Rect2(0,66,1280,568).encloses(label)
			for other:String in ordered:
				labels_clear=labels_clear and not label.intersects(art.actor_alpha_rect(other).grow(3))
				if other!=id and art.unit_label_alpha(other)>0:
					cards_clear=cards_clear and not label.intersects(art.unit_label_rect(other))
		if id in ["striker","bracer"] and int(unit(art.display_snapshot,id).hp)>0:
			picking=picking and art.target_at(art.target_anchor(id))==id and art.target_at(foot+Vector2(0,9))==id
	check(sorted,"Actual ground Y orders the painted actors: "+context)
	check(grounded,"All feet and complete shadows stay on solid timber: "+context)
	check(labels_clear,"Visible cards stay in the field and clear every current silhouette: "+context)
	check(cards_clear,"Visible compact cards remain distinct: "+context)
	check(picking,"Torso and ring picking follow the actual living actors: "+context)

func check_atlas_bounds()->void:
	for entry:Array in [["hero",Art.Hero],["rival",Art.Rival],["沈青",Art.Shen],["唐栖",Art.Tang]]:
		for pose:String in entry[1].POSES:
			var image:Image=entry[1].texture_for(pose).get_image()
			if image.is_compressed():image.decompress()
			var left:int=512;var top:int=512;var right:int=-1;var bottom:int=-1
			for y in range(512):
				for x in range(512):
					if image.get_pixel(x,y).a>.08:
						left=mini(left,x);top=mini(top,y);right=maxi(right,x);bottom=maxi(bottom,y)
			check(Art.ALPHA_BOUNDS[entry[0]][pose]==Rect2(left,top,right-left+1,bottom-top+1),"Card clearance uses measured original alpha: %s / %s"%[entry[0],pose])

func run()->void:
	if OS.get_environment("XDG_DATA_HOME").is_empty():push_error("Use isolated XDG dirs for formation_motion_test.gd");quit(2);return
	art=Art.new();art.size=Vector2(1280,685);root.add_child(art);art.set_process(false)
	art.presentation_finished.connect(func():completions+=1)
	art.impact_presented.connect(func(kind,amount):impacts.append({"kind":kind,"amount":amount,"display":art.display_snapshot.duplicate(true)}))
	art.target_requested.connect(func(id):requests.append(id))
	ground=PackedVector2Array([art.ground_point(0,0),art.ground_point(1,0),art.ground_point(1,1),art.ground_point(0,1)])
	check_atlas_bounds()
	var rules=rules_for(source_for())
	art.set_snapshot(rules.snapshot())
	var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=art.target_anchor("bracer")
	art._gui_input(click)
	check(requests==["bracer"] and art.selected_id=="striker" and rules.selected_id=="striker","A body click requests a target without changing selection or model")
	check(art.target_at(Vector2(50,80)).is_empty(),"Open water never selects a target")
	for id:String in Art.ENEMY_FEET:
		check(art.target_at(art.fighter_rect(id).position+Vector2(3,3)).is_empty(),"Transparent atlas corners never select "+id)
	# Every real action, both targets and formations, with no/Shen/Tang companion.
	for formation:String in ["护后","并肩"]:
		for companion:String in ["","沈青","唐栖"]:
			for target:String in ["bracer","striker"]:
				for kind:String in ["attack","skill","guard","item","flee"]:
					var state=source_for(formation)
					var original_state:Dictionary=state.to_dict().duplicate(true)
					var local=rules_for(state,companion);local.select_target(target)
					var transaction:Dictionary=local.accept_action(kind)
					var original:Dictionary=transaction.duplicate(true)
					var committed:Dictionary=local.snapshot()
					var finished_before:int=completions
					impacts.clear()
					check(art.present(transaction),"Real formation transaction starts: %s/%s/%s/%s"%[formation,companion,target,kind])
					check(not art.present(transaction),"Repeated accepted action cannot duplicate a turn")
					art.selected_id="striker" if target=="bracer" else "bracer"
					art.formation="并肩" if formation=="护后" else "护后"
					art.set_snapshot({"selected_id":"invalid","formation":"invalid","units":[]})
					art._gui_input(click);art._process(-1)
					check(art.selected_id==target and art.locked_target_id==target and art.formation==formation and requests.size()==1,"Accepted target/formation/snapshot/input remain locked")
					check(art.display_snapshot.hp==transaction.before.hp and art.action_time==0,"Accept and negative delta do not present future HP")
					var context:String="%s/%s/%s/%s"%[formation,companion,target,kind]
					for beat:float in [.08,.13,.24,.25,.31,.32,.36,.48,.49,.56,.65,.72,.88,1.06,1.25]:
						advance_to(beat)
						check_geometry(context+" @ "+str(beat))
						if beat in [.13,.32,.49,.88]:
							art.queue_redraw();await process_frame;frames+=1
						if kind in ["attack","skill"]:
							if beat==.31:check(unit(art.display_snapshot,target).hp==unit(transaction.before,target).hp,"Target HP waits for blade contact")
							if beat==.32:
								check(art.hero_visual_pose()=="strike" and art.blade_tip("hero").distance_to(art.event_anchor("hero"))<1,"Actual hero blade reaches the locked torso at HP contact: "+context)
								check(unit(art.display_snapshot,target).hp==int(unit(transaction.before,target).hp)-int(transaction.hero_damage),"Hero contact applies only accepted hero damage")
								check(art.hero_foot().distance_to(art.hero_home())>180 and art.unit_label_alpha("hero")==0,"Hero closes actual formation distance and moving card clears him")
							if beat==.49:
								check(unit(art.display_snapshot,target).hp==unit(transaction.after,target).hp,"Companion damage lands only on the same locked target")
								if int(transaction.support_damage)>0:check(art.support_visual_pose()=="assist","Real support damage has its assist pose")
								check(art.event_anchor("support")==art.target_anchor(target),"Support effect follows the actual target torso")
							if beat==.56 and int(transaction.support_heal)>0:check(art.support_visual_pose()=="heal","Shen's accepted healing uses the heal pose at healing contact")
							if beat==.65 and int(transaction.support_qi)>0:check(art.support_visual_pose()=="recover","Tang's accepted qi support has a recovery follow-through")
							if beat==.72:check(art.hero_foot()==art.hero_home(),"Hero returns to the exact formation slot before counters")
						if kind=="skill" and beat==.08:check(art.display_snapshot.qi==int(transaction.before.qi)+int(transaction.hero_qi_delta),"Skill windup displays the exact accepted qi cost")
						if kind=="item" and beat==.24:check(art.display_snapshot.hp==transaction.before.hp and art.display_snapshot.medicine==transaction.before.medicine,"Healing and medicine count wait for use contact")
						if kind=="item" and beat==.25:check(art.display_snapshot.hp==int(transaction.before.hp)+int(transaction.heal) and art.display_snapshot.medicine==transaction.after.medicine,"Use contact displays actual healing and one accepted medicine cost")
						if beat==.88 and not transaction.counters.is_empty():
							var counter:Dictionary=transaction.counters[0]
							check(art.fighter_visual_pose(counter.unit_id)=="strike" and art.fighter_foot(counter.unit_id).distance_to(Art.ENEMY_FEET[counter.unit_id])>150,"Actual countering opponent closes formation distance")
							check(art.blade_tip(counter.unit_id).distance_to(art.event_anchor("counter"))<1,"Counter blade reaches the actual hero torso at HP contact")
							check(art.display_snapshot.hp==transaction.after.hp,"Counter displays actual accepted HP at impact")
							if kind=="guard":check(art.hero_visual_pose()=="guard","Guard remains readable at the mitigated hit")
							if int(counter.cover)>0:check(art.support_visual_pose()=="cover","Cover pose coincides with this counter's real reduction")
					art._process(2)
					check(completions==finished_before+1 and not art.is_presenting() and art.display_snapshot==transaction.after,"Each presentation completes exactly once at accepted after facts")
					for id:String in art.actor_order():check(art.actor_foot(id)==art.actor_home(id) and art.unit_label_alpha(id)==1,"Complete action restores exact formation slot and card: "+id)
					var signal_count:int=impacts.size();art._process(2)
					check(signal_count==impacts.size() and completions==finished_before+1,"Idle processing cannot repeat impacts or completion")
					for hit:Dictionary in impacts:
						if hit.kind=="enemy":check(unit(hit.display,target).hp==int(unit(transaction.before,target).hp)-int(transaction.hero_damage),"HUD impact listener sees updated target HP")
						if hit.kind=="player":check(hit.display.hp==transaction.after.hp,"HUD impact listener sees updated player HP")
					check(local.snapshot()==committed and local.locked and state.to_dict()==original_state and transaction==original,"Presentation cannot change model, source, real costs or accepted transaction")
					art.reset_presentation()
	# The front protector only counters once the actual rear attacker is down.
	for formation:String in ["护后","并肩"]:
		var solo=rules_for(source_for(formation),"唐栖")
		solo._unit("striker").hp=0;solo._refresh_units();solo.select_target("bracer")
		var turn:Dictionary=solo.accept_action("guard")
		check(turn.counters.size()==1 and turn.counters[0].unit_id=="bracer","Real surviving protector supplies its own counter")
		art.present(turn);advance_to(.88)
		check(art.fighter_visual_pose("bracer")=="strike" and art.blade_tip("bracer").distance_to(art.event_anchor("counter"))<1,"Front protector's real counter reaches guarded hero")
		check_geometry("surviving bracer counter");art.queue_redraw();await process_frame;frames+=1
		art._process(2);check(art.fighter_foot("bracer")==Art.ENEMY_FEET.bracer,"Protector counter returns to exact front slot");art.reset_presentation()
	# Defeat is presented at the actual hit, and only the model chooses a new target.
	for target:String in ["striker","bracer"]:
		var lethal=rules_for(source_for())
		lethal._unit(target).hp=1;lethal.select_target(target)
		var turn:Dictionary=lethal.accept_action("attack")
		art.present(turn);advance_to(.31)
		check(art.fighter_visual_pose(target)!="kneel" and art.target_at(art.target_anchor(target))==target,"Defeat cannot appear before blade contact")
		advance_to(.32);check(art.target_at(art.target_anchor(target)).is_empty(),"A defeated actor loses its body and ring selection at contact")
		advance_to(.81);check(art.fighter_visual_pose(target)=="kneel" and art.selected_id==target,"Defeated target kneels while accepted target remains locked")
		art._process(2);check(art.display_snapshot==turn.after and lethal.locked,"Visual completion leaves model completion to the controller")
		lethal.complete_presentation(turn.token);art.set_snapshot(lethal.snapshot())
		check(art.selected_id!=target and art.fighter_visual_pose(target)=="kneel" and art.target_at(art.target_anchor(target)).is_empty(),"Model retarget updates ring without reviving the defeated actor")
		check_geometry("defeated target "+target);art.reset_presentation()
	var assisted=rules_for(source_for())
	assisted._unit("bracer").hp=17;assisted.select_target("bracer")
	var support_finish:Dictionary=assisted.accept_action("attack")
	check(support_finish.support_damage>0 and unit(support_finish.after,"bracer").hp==0,"Real companion transaction supplies the finishing hit")
	art.present(support_finish);advance_to(.48)
	check(art.fighter_visual_pose("bracer")!="kneel" and unit(art.display_snapshot,"bracer").hp==1,"Companion finisher waits for its own contact")
	advance_to(.49);check(unit(art.display_snapshot,"bracer").hp==0,"Companion finisher presents at support contact")
	advance_to(1);check(art.fighter_visual_pose("bracer")=="kneel","Companion finisher reaches kneeling pose");art.reset_presentation()
	var fragile=source_for();fragile.hp=1
	var defeated=rules_for(fragile)
	var last:Dictionary=defeated.accept_action("guard")
	art.present(last);advance_to(.88);check(art.hero_visual_pose()=="guard" and art.display_snapshot.hp==0,"Lethal guarded contact still shows the block")
	art._process(2);check(art.hero_visual_pose()=="kneel" and art.display_snapshot.outcome=="defeat","Real hero defeat remains kneeling after return");art.reset_presentation()
	# Detached payloads and interruption cannot corrupt or replay committed state.
	var mutable:Dictionary=last.duplicate(true);art.present(mutable)
	mutable.before.hp=999;mutable.after.hp=999;mutable.counters[0].damage=999
	check(art.before_snapshot==last.before and art.after_snapshot==last.after and art.presentation_result.counters==last.counters,"Caller edits cannot rewrite presentation facts")
	var count:int=completions;art.reset_presentation();art.reset_presentation()
	check(completions==count+1 and not art.is_presenting() and art.presentation_result.is_empty(),"Repeated interruption releases presentation only once")
	check(not art.present({"ok":false,"accepted":false}) and not art.present({"ok":true,"accepted":true,"action":"unknown"}),"Rejected or unsupported actions have no presentation")
	art.free()
	print("%s: %d formation transaction/motion/ground/label checks; %d headless canvas frames"%["PASS" if failures==0 else "FAIL",checks,frames])
	quit(0 if failures==0 else 1)
