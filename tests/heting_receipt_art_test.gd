extends SceneTree
## Headless presentation checks use real immutable combat transactions.
## Canvas frames validate drawing commands; native pixel review is separate.
const Art = preload("res://scripts/heting_receipt_art.gd")
const State = preload("res://scripts/game_state.gd")
const Rules = preload("res://scripts/heting_receipt_combat.gd")
const Uniform = preload("res://scripts/painted_battle_puheng.gd")
const Hero = preload("res://scripts/painted_battle_hero.gd")
const Backdrop = preload("res://scripts/ferry_battle_backdrop.gd")
const Duel = preload("res://scripts/battle_art.gd")
var checks: int = 0
var failures: int = 0
var completions: int = 0
var signals_seen: Array = []
var requested: Array = []
var art

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _source():
	var source = State.new()
	source.max_hp = 180
	source.hp = 130
	source.attack = 16
	source.defense = 4
	source.qi = maxi(0,source.max_qi-2)
	source.medicine = 2
	return source

func _rules(source, companion: String = "唐栖"):
	var rules = Rules.new()
	rules.configure(source)
	rules.companion = companion
	rules._support_count = 1
	return rules

func _run() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty():
		push_error("Run heting_receipt_art_test.gd with an isolated XDG_DATA_HOME")
		quit(2)
		return
	art = Art.new()
	art.size = Vector2(938,355)
	root.add_child(art)
	art.set_process(false)
	art.presentation_finished.connect(func(): completions+=1)
	art.target_requested.connect(func(id): requested.append(id))
	art.impact_presented.connect(func(kind,amount): signals_seen.append({"kind":kind,"amount":amount,"display":art.display_snapshot.duplicate(true)}))
	var source = _source()
	var original: Dictionary = source.to_dict().duplicate(true)
	var rules = _rules(source)
	art.set_snapshot(rules.snapshot())
	check(art.companion_active and art.companion_name=="唐栖" and art.region_style=="qingwei","Receipt snapshot selects painted waterfront and current companion")
	check(art.fighter_visual_pose("striker")=="idle" and art.fighter_visual_pose("bracer")=="guard","Distinct real fighters start with attack/protector silhouettes")
	check(Art.FIGHTER_TINT.striker!=Art.FIGHTER_TINT.bracer and Art.FIGHTER_SIZE.striker!=Art.FIGHTER_SIZE.bracer,"Uniform reuse retains distinct tint and scale")
	for pose: String in Uniform.POSES:
		var frame: AtlasTexture = Uniform.texture_for(pose)
		var index: int = Uniform.POSES[pose]
		check(frame!=null and frame==Uniform.texture_for(pose) and frame.region==Rect2((index%3)*512,(index/3)*512,512,512),"Cached real fighter pose: "+pose)
		check(frame.atlas!=Hero.texture_for(pose).atlas,"Hero and reused uniform remain independent: "+pose)
	var legacy = Duel.new()
	for identity: String in ["截签刀客","架刀护手","蒲横的徒弟"]:
		legacy.enemy_identity = identity
		check(not legacy.uses_painted_enemy(),"New role does not broaden Pu Heng identity matching: "+identity)
	legacy.enemy_identity = "蒲横"
	check(legacy.uses_painted_enemy(),"Original Pu Heng identity still resolves")
	legacy.free()
	var stage: Rect2 = Backdrop.cover_rect(Backdrop.texture().get_size(),Vector2(938,355))
	var deck_top: float = stage.position.y+567*stage.size.y/Backdrop.texture().get_height()
	var deck_front: float = stage.position.y+690*stage.size.y/Backdrop.texture().get_height()
	for id: String in Art.FIGHTER_FEET:
		var foot: Vector2 = art.fighter_foot(id)
		check(foot.y-7>deck_top and foot.y+11<deck_front,"Actual fighter boots and complete shadow rest on solid deck: "+id)
		check((art.fighter_rect(id).position+Uniform.FOOT*(float(Art.FIGHTER_SIZE[id])/512)).distance_to(foot)<.001,"Atlas foot registration agrees with shadow: "+id)
		check(art.target_at(art.target_anchor(id))==id,"Real fighter chest click resolves: "+id)
		check(not art.fighter_hit_rect(id).has_point(art.fighter_rect(id).position+Vector2(3,3)),"Transparent cell corner is not a body click: "+id)
	check(art.target_at(Vector2(50,10)).is_empty(),"Empty waterfront is not a target")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = art.target_anchor("bracer")
	art._gui_input(mouse)
	check(requested==["bracer"] and art.selected_id=="striker","Click requests the actual fighter without selecting in the model")
	rules.select_target("bracer")
	var result: Dictionary = rules.accept_action("attack")
	var original_result: Dictionary = result.duplicate(true)
	var resolved: Dictionary = rules.snapshot()
	check(art.present(result) and not art.present(result),"One accepted immutable transaction owns the whole presentation")
	art.selected_id = "striker"
	art.set_snapshot({"selected_id":"striker","hp":1,"units":[]})
	art._gui_input(mouse)
	check(art.selected_id=="bracer" and art.locked_target_id=="bracer" and requested.size()==1,"Selection, clicks and replacement snapshot cannot retarget a locked hit")
	check(art.before_snapshot==result.before and art.after_snapshot==result.after,"Accepted before/after snapshots stay detached and exact")
	art._process(.31)
	check(art.display_snapshot.units[1].hp==result.before.units[1].hp,"Pre-impact target HP remains unchanged")
	check(absf(float(art._pose().x)-(Art.FIGHTER_FEET.bracer.x-106-Art.HERO_HOME.x))<.1,"Hero lunges to the selected fighter on the ferry deck")
	check(art.event_anchor("hero")==art.target_anchor("bracer") and art.event_anchor("hero").distance_to(art.target_anchor("striker"))>100,"Hero effect points to selected bracer torso")
	art._process(.02)
	var hit: Dictionary = signals_seen[-1]
	check(hit.kind=="enemy" and hit.amount==result.hero_damage and hit.display.units[1].hp==int(result.before.units[1].hp)-int(result.hero_damage),"Hero contact updates exact HP before emitting its HUD signal")
	check(hit.display.units[0].hp==result.before.units[0].hp,"Unselected fighter HP is untouched")
	art._process(.03)
	check(art.fighter_visual_pose("bracer")=="hurt" and art.fighter_visual_pose("striker")=="idle","Only selected fighter shows hero-hit recoil")
	art._process(.14)
	check(signals_seen[-1].kind=="companion" and signals_seen[-1].amount==result.support_damage,"Support impact has its own accepted amount and beat")
	check(art.event_anchor("support")==art.target_anchor("bracer") and art.display_snapshot.units[1].hp==result.after.units[1].hp and art.display_snapshot.qi==result.after.qi,"Support effect and updated target HP remain on the locked fighter")
	art._process(.22)
	check(art.fighter_visual_pose("striker")=="windup" and art.fighter_visual_pose("bracer")=="guard","Nonselected real attacker winds up while protector guards")
	art._process(.17)
	check(art.fighter_visual_pose("striker")=="strike" and art.fighter_foot("striker").x<400,"Actual countering fighter lunges across the deck")
	check(art.event_anchor("counter_source","striker")==art.target_anchor("striker") and art.event_anchor("counter").distance_to(Art.HERO_HOME+Vector2(0,-65))<28,"Counter source and impact follow actual attacker and hero")
	check(signals_seen[-1].kind=="player" and signals_seen[-1].amount==result.counters[0].damage and signals_seen[-1].display.hp==result.after.hp,"Counter contact exposes accepted player HP before its signal")
	art._process(2)
	check(not art.is_presenting() and completions==1 and art.display_snapshot==result.after,"Finished display settles once to exact accepted after snapshot")
	var signal_count: int = signals_seen.size()
	art._process(2)
	check(signals_seen.size()==signal_count and completions==1,"Idle presentation cannot repeat HP changes or completion")
	check(rules.snapshot()==resolved and rules.locked and source.to_dict()==original and result==original_result,"Drawing and timing do not mutate rules, unlock model, modify source or reapply real damage")
	# Resetting also detaches all input containers, including a mutable caller.
	art.reset_presentation()
	var mutable: Dictionary = result.duplicate(true)
	art.present(mutable)
	mutable.before.units[1].hp = 999
	mutable.after.units[1].hp = 999
	mutable.hero_damage = 999
	check(art.before_snapshot==result.before and art.after_snapshot==result.after and art.presentation_result.hero_damage==result.hero_damage,"Later caller payload changes cannot corrupt playback")
	art.reset_presentation()
	var reset_count: int = completions
	art.reset_presentation()
	check(completions==reset_count and not art.is_presenting() and art.presentation_result.is_empty(),"Repeated interruption releases only once and clears transient facts")
	check(not art.present({"ok":false,"accepted":false}) and not art.present({"ok":true,"accepted":true,"action":"unknown"}),"Rejected or unsupported actions never start presentation")
	# Test both target choices with real transactions and every supported action.
	var draw_cases: int = 0
	for companion: String in ["沈青","唐栖"]:
		for target: String in ["striker","bracer"]:
			for kind: String in ["attack","skill","guard","item","flee"]:
				var local = _rules(_source(),companion)
				local.select_target(target)
				var sample: Dictionary = local.accept_action(kind)
				var before_art: Dictionary = local.snapshot()
				check(art.present(sample),"Real action begins: %s/%s/%s"%[companion,target,kind])
				for beat: float in [.13,.34,.52,.90]:
					art.action_time = minf(beat,art.presentation_duration)
					art.queue_redraw()
					await process_frame
					draw_cases += 1
					for id: String in Art.FIGHTER_FEET:
						var moving_foot: Vector2 = art.fighter_foot(id)
						check(moving_foot.y-7>deck_top and moving_foot.y+11<deck_front,"Animated opponent boots and shadow remain grounded: %s/%s/%s"%[kind,target,id])
				art._process(2)
				check(art.display_snapshot==sample.after and local.snapshot()==before_art,"Draw completion retains accepted state without mutation: "+kind)
				art.reset_presentation()
	check(draw_cases==80,"Eighty actual canvas frames cover both targets, both companions and all five actions")
	# Healing advances on its own contact beat, rather than immediately at accept.
	var medicine_rules = _rules(_source())
	var medicine: Dictionary = medicine_rules.accept_action("item")
	art.present(medicine)
	art._process(.24)
	check(art.display_snapshot.hp==medicine.before.hp and art.display_snapshot.medicine==medicine.before.medicine,"Medicine keeps pre-impact HP and count")
	art._process(.02)
	check(art.display_snapshot.hp==int(medicine.before.hp)+int(medicine.heal) and art.display_snapshot.medicine==medicine.after.medicine,"Medicine contact updates accepted healing and consumed count")
	art.reset_presentation()
	# Real deaths stay kneeling after finish and are no longer clickable.
	for target: String in ["striker","bracer"]:
		var local = _rules(_source())
		local._unit(target).hp = 1
		local.select_target(target)
		var death: Dictionary = local.accept_action("attack")
		art.present(death)
		art._process(.31)
		check(art.fighter_visual_pose(target)!="kneel" and art.target_at(art.target_anchor(target))==target,"Target does not die before contact: "+target)
		art._process(.50)
		check(art.fighter_visual_pose(target)=="kneel" and art.target_at(art.target_anchor(target)).is_empty(),"Actual defeated fighter kneels and stops accepting clicks: "+target)
		art.queue_redraw()
		await process_frame
		art._process(2)
		check(art.fighter_visual_pose(target)=="kneel" and art.display_snapshot==death.after,"Kneeling defeat remains visible after presentation: "+target)
		art.reset_presentation()
	var fragile = _source()
	fragile.hp = 1
	var defeat_rules = _rules(fragile)
	var defeat: Dictionary = defeat_rules.accept_action("guard")
	art.present(defeat)
	art._process(.89)
	check(art.hero_visual_pose()=="guard" and art.display_snapshot.hp==0,"Guard remains readable at mitigated lethal contact")
	art._process(2)
	check(art.hero_visual_pose()=="kneel" and art.display_snapshot.outcome=="defeat","Actual player defeat remains kneeling after finish")
	art.free()
	print("%s: %d receipt presentation checks; %d headless canvas frames"%["PASS" if failures==0 else "FAIL",checks,draw_cases+2])
	quit(0 if failures==0 else 1)
