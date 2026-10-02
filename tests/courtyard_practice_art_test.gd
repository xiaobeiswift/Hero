extends SceneTree
## Headless deterministic presentation contracts; no persistence or GUI input.
const Art = preload("res://scripts/courtyard_practice_art.gd")
const State = preload("res://scripts/game_state.gd")
const Rules = preload("res://scripts/courtyard_exercise_rules.gd")
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

func _run() -> void:
	art = Art.new()
	art.size = Vector2(938,355)
	root.add_child(art)
	art.set_process(false)
	art.presentation_finished.connect(func(): completions+=1)
	art.target_requested.connect(func(id): requested.append(id))
	art.impact_presented.connect(func(kind,amount): signals_seen.append({"kind":kind,"amount":amount,"display":art.display_snapshot.duplicate(true)}))
	var source = State.new()
	var original: Dictionary = source.to_dict().duplicate(true)
	var rules = Rules.new()
	rules.configure(source)
	rules.companion = "唐栖"
	rules._support_count = 1
	rules.qi = maxi(0,rules.max_qi-3)
	art.set_snapshot(rules.snapshot())
	check(art.companion_active and art.companion_name=="唐栖" and art.region_style=="training","Snapshot sets stage and companion")
	check(art.target_at(Vector2(650,166))=="striker" and art.target_at(Vector2(790,208))=="bracer","Both body click locators resolve correct IDs")
	check(art.target_at(Vector2(50,10)).is_empty(),"Empty stage is not a target")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = Vector2(790,208)
	art._gui_input(mouse)
	check(requested==["bracer"] and art.selected_id=="striker","Art click emits only a request; rules own selection")
	rules.select_target("bracer")
	var result: Dictionary = rules.accept_action("attack")
	check(art.present(result),"Accepted rule transaction begins animation")
	check(not art.present(result),"Repeated submit cannot replace active presentation")
	art.selected_id = "striker"
	art.set_snapshot({"selected_id":"striker","hp":1,"units":[]})
	art._gui_input(mouse)
	check(art.selected_id=="bracer" and art.locked_target_id=="bracer" and requested.size()==1,"Selection and snapshot writes cannot retarget an active strike")
	check(art.before_snapshot==result.before and art.after_snapshot==result.after,"Before and after are exact detached accepted snapshots")
	art._process(.31)
	check(art._unit(art.display_snapshot,"bracer").hp==result.before.units[1].hp,"No target HP changes before contact")
	check(absf(float(art._pose().x)-(790-102-229))<.1,"Hero dash endpoint follows selected bracer")
	art._process(.02)
	var first_hit: Dictionary = signals_seen[-1]
	check(first_hit.kind=="enemy" and first_hit.amount==result.hero_damage,"Hero contact reports exact accepted damage")
	check(first_hit.display.units[1].hp==int(result.before.units[1].hp)-int(result.hero_damage),"HUD receives updated target HP before hero signal")
	check(first_hit.display.units[0].hp==result.before.units[0].hp,"Unselected striker HP stays unchanged")
	art._process(.17)
	check(signals_seen[-1].kind=="companion" and signals_seen[-1].amount==result.support_damage,"Support hit stays separately timed")
	check(art.display_snapshot.units[1].hp==result.after.units[1].hp and art.display_snapshot.qi==result.after.qi,"Support damage and qi are applied before its HUD signal")
	art._process(.23)
	check(float(art.rig_pose("striker").windup)>.7 and art.rig_pose("bracer").windup==0,"Counter winds up its actual source, not the selected rig")
	art._process(.16)
	check(signals_seen[-1].kind=="player" and signals_seen[-1].amount==result.counters[0].damage,"Incoming impact uses actual counter payload")
	check(signals_seen[-1].display.hp==result.after.hp,"Player HP already changed when counter signal fires")
	art._process(2)
	check(not art.is_presenting() and completions==1 and art.display_snapshot==result.after,"Completion settles exactly to after snapshot once")
	var number_of_events: int = signals_seen.size()
	art._process(2)
	check(signals_seen.size()==number_of_events and completions==1,"Idle processing cannot repeat an impact or completion")
	check(source.to_dict()==original,"All presentation leaves real character data untouched")

	# Independent incoming entries remain independent even if the exercise later
	# adds a turn on which both rigs attack.
	var pair: Dictionary = result.duplicate(true)
	pair.action = "guard"
	pair.hero_damage = 0
	pair.support_damage = 0
	pair.support_qi = 0
	pair.hero_qi_delta = 0
	pair.heal = 0
	pair.support_heal = 0
	pair.counter_damage = 8
	pair.guarded = true
	pair.counters = [{"unit_id":"striker","damage":3,"guarded":true,"heavy":false,"cover":0},{"unit_id":"bracer","damage":5,"guarded":true,"heavy":false,"cover":0}]
	pair.after = pair.before.duplicate(true)
	pair.after.hp = int(pair.before.hp)-8
	art.present(pair)
	check(is_equal_approx(art.presentation_duration,1.52),"Second counter reserves time for its own impact and recovery")
	art._process(.89)
	check(art.display_snapshot.hp==int(pair.before.hp)-3,"Only the first incoming hit has landed")
	check(art.hero_visual_pose()=="guard","Mitigated impact preserves the painted block pose")
	art._process(.18)
	check(art.display_snapshot.hp==int(pair.before.hp)-8,"Second incoming hit lands at its separate beat")
	art.reset_presentation()
	var after_reset: int = completions
	art.reset_presentation()
	check(completions==after_reset and not art.is_presenting() and art.presentation_result.is_empty(),"Cancel releases once and clears transient payloads")
	check(not art.present({"ok":false,"accepted":false}),"Rejected rule actions have no animation")

	# Exercise actual canvas draws through the inherited painting path, not a
	# direct _draw invocation. Headless runs validate commands, not final pixels.
	var draw_cases: int = 0
	for companion: String in ["沈青","唐栖"]:
		for kind: String in ["attack","skill","guard","item","flee"]:
			var sample: Dictionary = result.duplicate(true)
			sample.action = kind
			sample.before.companion = companion
			sample.after.companion = companion
			sample.heal = 4 if kind=="item" else 0
			sample.support_heal = 2 if companion=="沈青" and kind=="attack" else 0
			sample.support_qi = 1 if companion=="唐栖" and kind=="attack" else 0
			sample.guarded = kind=="guard"
			if kind in ["guard","item","flee"]:
				sample.hero_damage = 0
				sample.support_damage = 0
			if kind=="flee": sample.counters = []
			art.present(sample)
			for beat: float in [.13,.34,.52,.90]:
				art.action_time = beat
				art.queue_redraw()
				await process_frame
				draw_cases += 1
			art.reset_presentation()
	check(draw_cases==40,"Forty real canvas draw frames cover five actions and both companions")
	# Death of a particular target is a persistent prop collapse, not a swap.
	var death: Dictionary = result.duplicate(true)
	death.after.units[1].hp = 0
	death.hero_damage = int(death.before.units[1].hp)
	death.support_damage = 0
	death.counters = []
	art.present(death)
	art.action_time = .80
	check(float(art.rig_pose("bracer").defeat)>.95 and art.rig_pose("striker").defeat==0,"Only the defeated target folds toward its grounded base")
	art.queue_redraw()
	await process_frame
	art._process(2)
	check(art.rig_pose("bracer").defeat==1 and art.target_at(Vector2(790,208)).is_empty(),"Collapsed target stays down and ceases being clickable")
	art.free()
	print("%s: %d courtyard presentation contracts; %d headless draw frames" % ["PASS" if failures==0 else "FAIL",checks,draw_cases+1])
	quit(0 if failures==0 else 1)
