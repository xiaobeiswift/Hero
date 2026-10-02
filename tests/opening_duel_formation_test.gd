extends SceneTree
## Exact legacy event parity plus detached single-opponent formation facts.
const Art=preload("res://scripts/opening_duel_formation_art.gd")
const Legacy=preload("res://scripts/battle_art.gd")
const State=preload("res://scripts/game_state.gd")
var checks:int=0
var failures:int=0
var completions:int=0
var legacy_completions:int=0
var impacts:Array=[]
var legacy_impacts:Array=[]
var art
var legacy

func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures+=1;push_error(label)

func source_for(kind:String="story",companion:String="",formation:String="并肩",heavy:bool=false):
	var state=State.new()
	state.companion_unlocked=companion=="沈青"
	state.tangqi_unlocked=companion=="唐栖"
	state.active_companion=companion
	state.shen_care_stage=5;state.shen_care_choice="mobile"
	state.formation=formation
	state.start_battle(kind)
	state.hp=40;state.qi=4
	state._companion_attack_count=1
	state.turn=1 if heavy else 0
	state._update_intent()
	return state

func fingerprint(state)->Dictionary:
	var result:Dictionary={}
	for property:Dictionary in state.get_property_list():
		if int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value=state.get(property.name)
			if value is Dictionary or value is Array:value=value.duplicate(true)
			result[property.name]=value
	return result

func start_action(state,kind:String)->Dictionary:
	art.reset_presentation();legacy.reset_presentation()
	var before:Dictionary=fingerprint(state)
	art.set_duel_context(state)
	check(fingerprint(state)==before,"Context read never mutates persistent or transient rules")
	var result:Dictionary=state.battle_action(kind)
	var accepted:Dictionary=result.duplicate(true)
	var committed:Dictionary=fingerprint(state)
	impacts.clear();legacy_impacts.clear()
	art.hit(kind,result);legacy.hit(kind,result)
	check(art.uses_formation(),"Pu Heng story/spar enters formation stage")
	check(art.presentation_details==legacy.presentation_details and art.get_presentation_duration()==legacy.get_presentation_duration(),"Legacy accepted facts and duration remain exact")
	check(result==accepted and fingerprint(state)==committed,"Starting art never changes accepted result or model")
	return {"result":result,"state":committed,"hp":before.hp,"enemy_hp":before.enemy_hp,"qi":before.qi,"max_hp":before.max_hp}

func advance_to(time:float)->void:
	var delta:float=maxf(0,time-art.action_time)
	art._process(delta);legacy._process(delta)

func check_events(before:Dictionary)->void:
	var hp:int=int(before.hp)
	var enemy_hp:int=int(before.enemy_hp)
	var received:Array=[]
	for event:Dictionary in impacts:
		received.append([event.target,event.amount])
		match String(event.target):
			"enemy","companion":enemy_hp=maxi(0,enemy_hp-int(event.amount))
			"healing","support_healing":hp=mini(int(before.max_hp),hp+int(event.amount))
			"player":hp=maxi(0,hp-int(event.amount))
		check(event.display.hp==hp and event.display.units.size()==1 and event.display.units[0].hp==enemy_hp,"Each public impact observes exactly its own HP fact before emission")
	check(received==legacy_impacts,"Signal amounts and chronological order exactly match legacy BattleArt")

func check_slots()->void:
	var stage=art.formation_stage
	check(stage.actor_order().size()==(3 if art.companion_active else 2) and not stage.actor_order().has("striker"),"Only hero, actual support and one Pu Heng are drawn")
	check(stage.selected_id=="bracer" and stage.display_snapshot.units.size()==1,"Only the valid front-right target exists")
	check(stage.fighter_pose("bracer").bracing==0 and stage._shown_unit("bracer").intent_data.is_empty(),"Geometry alias grants Pu Heng no guard role")
	for id:String in ["hero","enemy","support"]:
		check(art.unit_label_rect(id).size.x==160,"Public label ID maps to measured formation geometry: "+id)
	check(art.unit_label_alpha("support")==0 if not art.companion_active else art.unit_label_alpha("support")==1,"Support label visibility follows actual roster")
	check(art.unit_label_rect("striker")==Rect2() and art.unit_label_alpha("striker")==0,"No phantom target label is exposed")

func run()->void:
	if OS.get_environment("XDG_DATA_HOME").is_empty():push_error("Use isolated XDG dirs for opening_duel_formation_test.gd");quit(2);return
	art=Art.new();art.size=Vector2(1280,685);root.add_child(art);art.set_process(false)
	legacy=Legacy.new();root.add_child(legacy);legacy.set_process(false);legacy.visible=false
	art.presentation_finished.connect(func():completions+=1)
	legacy.presentation_finished.connect(func():legacy_completions+=1)
	art.impact_presented.connect(func(target,amount):impacts.append({"target":target,"amount":amount,"display":art.display_snapshot}))
	legacy.impact_presented.connect(func(target,amount):legacy_impacts.append([target,amount]))
	check(not art.uses_formation() and art.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Unconfigured adapter keeps the original input-transparent renderer")
	for encounter:String in ["story","spar"]:
		for formation:String in ["护后","并肩"]:
			for companion:String in ["","沈青","唐栖"]:
				for heavy:bool in [false,true]:
					for kind:String in ["attack","skill","guard","item","flee"]:
						var state=source_for(encounter,companion,formation,heavy)
						var before:Dictionary=start_action(state,kind)
						check_slots()
						var duration:float=art.get_presentation_duration()
						var finished_before:int=completions
						art.set_duel_context(source_for("sluice_boss"))
						check(art.enemy_identity==state.enemy_name and art.formation_stage.formation==formation,"Mid-action context cannot change identity or formation")
						art._process(-1);legacy._process(-1)
						check(art.action_time==0 and art.display_snapshot.hp==before.hp,"No negative-delta or pre-impact HP update")
						for beat:float in [.08,.25,.31,.32,.49,.56,.65,.72,.88,1.0]:
							advance_to(beat)
							if beat==.31:check(art.display_snapshot.units[0].hp==before.enemy_hp,"Enemy HP waits for exact blade contact")
							if beat==.32 and kind in ["attack","skill"]:
								check(art.formation_stage.blade_tip("hero").distance_to(art.formation_stage.event_anchor("hero"))<1,"Hero blade meets the single Pu Heng torso")
								check(art.unit_label_alpha("hero")==0,"Moving hero label clears the actual artwork")
							if beat==.88 and bool(art.presentation_details.get("counter",false)):
								check(art.formation_stage.blade_tip("bracer").distance_to(art.formation_stage.event_anchor("counter"))<1,"Single counter reaches hero torso")
								if kind=="guard":check(art.formation_stage.hero_visual_pose()=="guard","Guard remains visibly held at the real mitigated hit")
							if beat==.65:check(art.formation_stage.support_visual_pose()==legacy.support_visual_pose(),"Accepted Shen/Tang support poses retain legacy timing")
							if beat in [.32,.49,.88]:
								art.formation_stage.queue_redraw();await process_frame
						advance_to(duration+.1)
						check_events(before)
						check(completions==finished_before+1 and not art.is_presenting(),"Exactly one completion uses legacy duration")
						check(art.display_snapshot.hp==state.hp and art.display_snapshot.qi==state.qi and art.display_snapshot.units[0].hp==state.enemy_hp,"Ordinary accepted combat facts equal rules after presentation")
						check(fingerprint(state)==before.state,"Complete playback never mutates any model field")
						var count:int=impacts.size();art._process(2);legacy._process(2)
						check(impacts.size()==count and completions==finished_before+1,"Idle playback never duplicates completion or impact")
	# A single long frame still exposes each intermediate fact, in event order.
	var state=source_for("story","沈青")
	var before:Dictionary=start_action(state,"attack")
	advance_to(2);check_events(before)
	# Outcome restoration belongs to controller refresh, never a fake heal beat.
	for outcome:String in ["victory","defeat"]:
		state=source_for("spar")
		state.hp=1;state.qi=1;state.xp=50
		if outcome=="victory":state.enemy_hp=1
		before=start_action(state,"attack" if outcome=="victory" else "guard")
		check(state.hp==state.max_hp,"Fixture has real level-up or defeat recovery")
		advance_to(2);check_events(before)
		check(art.display_snapshot.hp==(1 if outcome=="victory" else 0) and art.display_snapshot.max_hp==before.max_hp,"Combat depletion stays separate from outcome recovery")
		check(art.display_snapshot.outcome==outcome,"Accepted outcome remains correct")
		art.set_duel_context(state)
		check(art.display_snapshot.hp==state.hp and art.display_snapshot.max_hp==state.max_hp,"Idle refresh applies actual outcome recovery only afterward")
	# Companion finishing blow and healing martial art use actual gross facts.
	state=source_for("story","沈青");state.enemy_hp=state.attack+1
	before=start_action(state,"attack");advance_to(2);check_events(before)
	check(art.display_snapshot.units[0].hp==0 and not art.presentation_details.counter,"Companion can finish without a fabricated counter")
	state=source_for();state.battle_active=false;state.choose_sect("照野堂");state.equip_art(state.sect_art());state.start_battle("story");state.hp=30;state.qi=6
	before=start_action(state,"skill");advance_to(2);check_events(before)
	check(int(art.presentation_details.self_healing)>0,"Healing skill keeps its actual separate recovery")
	# Explicit zeroes, omitted facts and counter overrides retain the old API.
	for details:Dictionary in [{},{"enemy_damage":0,"player_damage":0,"counter":true},{"enemy_damage":0,"player_damage":0,"counter":false},{"enemy_damage":3,"player_damage":4,"counter":false},{"enemy_damage":5,"player_damage":4,"healing":6,"guarded":true,"art_name":"测试"}]:
		state=source_for();art.reset_presentation();legacy.reset_presentation();art.set_duel_context(state)
		impacts.clear();legacy_impacts.clear();art.hit("skill",details);legacy.hit("skill",details)
		check(art.get_presentation_duration()==legacy.get_presentation_duration(),"Explicit zero/no-counter durations retain exact legacy contract")
		advance_to(2);check_events({"hp":state.hp,"enemy_hp":state.enemy_hp,"max_hp":state.max_hp})
		check(art.display_snapshot.qi==state.qi and art.display_snapshot.turn==state.turn,"Unconfirmed legacy payload does not invent resource or turn changes")
	# Cancellation releases waiters once, rejected actions do not disturb state,
	# and repeated encounters can safely reuse the same adapter instance.
	state=source_for();before=start_action(state,"attack");advance_to(.32)
	var active_details:Dictionary=art.presentation_details.duplicate(true)
	art.hit("skill",{"valid":false})
	check(art.action=="attack" and art.action_time==.32 and art.presentation_details==active_details,"Rejected result cannot interrupt accepted presentation")
	var finished_before:int=completions
	var interrupted_count:int=impacts.size()
	art.reset_presentation();art.reset_presentation()
	check(completions==finished_before+1 and not art.is_presenting() and not art.formation_stage.is_presenting(),"Interruption settles and releases one waiter")
	art._process(3);check(impacts.size()==interrupted_count,"Interrupted action never emits stale later hits")
	art.set_duel_context(state);art.hit("attack",{"valid":false})
	check(not art.is_presenting(),"Rejected action does not start either renderer")
	before=start_action(source_for("spar","唐栖","护后"),"guard");advance_to(2);check_events(before)
	state=source_for();art.set_duel_context(state);art.hit("attack",{"enemy_damage":8,"player_damage":3});advance_to(.32)
	finished_before=completions;impacts.clear();legacy_impacts.clear()
	art.hit("guard",{"player_damage":2});legacy.hit("guard",{"player_damage":2});advance_to(2)
	check(completions==finished_before+1 and impacts.size()==1 and impacts[0].target=="player","Legacy action replacement cannot leak the replaced action's later hit")
	# Exact identity and feature-flag fallback keep all other legacy renderers.
	for identity:String in ["旧闸巡哨","河帮闸首","韩砚 · 仓门执事","岑远 · 代试游师","听雨关守令使","蒲横冒名者"]:
		state=source_for();state.enemy_name=identity;art.set_duel_context(state)
		check(not art.uses_formation() and not art.formation_stage.visible and art.unit_label_rect("enemy")==Rect2(),"Other identity keeps unchanged legacy fallback: "+identity)
		impacts.clear();legacy_impacts.clear();var accepted:Dictionary=state.battle_action("attack");art.hit("attack",accepted);legacy.hit("attack",accepted);advance_to(2)
		var received:Array=[]
		for event:Dictionary in impacts:received.append([event.target,event.amount])
		check(received==legacy_impacts,"Fallback still has byte-for-byte legacy impact facts")
	for identity:String in ["蒲横","蒲横 · 切磋","蒲横 · 河帮执事"]:
		state=source_for();state.enemy_name=identity;art.set_duel_context(state);check(art.uses_formation(),"Exact existing Pu Heng identity remains supported")
	for flag:String in ["painted_enemy_enabled","painted_hero_enabled","painted_support_enabled","painted_backdrop_enabled"]:
		art.set(flag,false);check(not art.uses_formation(),"Existing feature flag can return to original renderer: "+flag);art.set(flag,true)
	# Detached read access cannot silently modify the presentation context.
	var detached:Dictionary=art.display_snapshot;detached.hp=-1;detached.units[0].hp=-1
	check(art.display_snapshot.hp>=0 and art.display_snapshot.units[0].hp>=0,"Public display snapshot is a defensive deep copy")
	var reference:WeakRef=weakref(state);state=null
	check(reference.get_ref()==null,"Neither adapter nor stage retains the HeroState object")
	art.draw_labels=true;art.queue_redraw();art.formation_stage.queue_redraw();await process_frame
	art.free();legacy.free()
	print("%s: %d opening duel formation adapter checks"%["PASS" if failures==0 else "FAIL",checks])
	quit(0 if failures==0 else 1)
