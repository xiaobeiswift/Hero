extends "res://scripts/battle_art.gd"
## Legacy single-enemy action clock/signals, presented on the measured formation
## stage only for the opening Pu Heng duel and repeat spar. No HeroState retained.
## Call set_duel_context(state) immediately BEFORE battle_action and at idle
## refresh. Public label IDs are hero/enemy/support in 1280-wide stage coordinates.
const DuelStage=preload("res://scripts/opening_duel_formation_stage.gd")
var formation_stage
var _duel_context:Dictionary={}
var _formation_presenting:bool=false
var draw_labels:bool=false:
	set(value):
		draw_labels=value
		if is_instance_valid(formation_stage):formation_stage.draw_labels=value
var display_snapshot:Dictionary:
	get:return formation_stage.display_snapshot.duplicate(true) if is_instance_valid(formation_stage) else {}

func _init()->void:
	# This connection precedes controller waiters, so a completion observer sees
	# the settled combat facts before it refreshes rewards/recovery from the model.
	presentation_finished.connect(_finish_formation)

func _ready()->void:
	super._ready()
	_ensure_stage()
	_sync_visibility()

func _ensure_stage()->void:
	if is_instance_valid(formation_stage):return
	formation_stage=DuelStage.new()
	formation_stage.name="OpeningDuelFormationStage"
	formation_stage.draw_labels=draw_labels
	formation_stage.size=Vector2(1280,685)
	add_child(formation_stage)
	formation_stage.set_process(false)
	formation_stage.mouse_filter=Control.MOUSE_FILTER_IGNORE

func set_duel_context(state)->void:
	if _presenting:return
	# Copy only scalar facts and newly constructed containers. Query methods are
	# read-only; storing the model here would make later victory restoration leak.
	var companion:String=String(state.current_companion())
	enemy_identity=String(state.enemy_name)
	companion_name=companion
	companion_active=not companion.is_empty()
	_duel_context={
		"battle_kind":String(state.battle_kind),"enemy_identity":enemy_identity,"turn":int(state.turn),
		"player_name":String(state.player_name),"hp":int(state.hp),"max_hp":int(state.max_hp),
		"qi":int(state.qi),"max_qi":int(state.max_qi),"medicine":int(state.medicine),
		"equipped_art":String(state.equipped_art),"art_cost":int(state.active_art_cost()),
		"formation":String(state.formation),"companion":companion,"selected_id":"bracer",
		"enemy_intent":String(state.enemy_intent),"heavy":int(state.turn)%2==1,
		"units":[{"id":"bracer","name":enemy_identity,"hp":int(state.enemy_hp),"max_hp":int(state.enemy_max_hp),"intent_data":{}}],
	}
	_ensure_stage()
	formation_stage.set_snapshot(_duel_context)
	_sync_visibility()
	queue_redraw()

func uses_formation()->bool:
	if _presenting:return _formation_presenting
	return not _duel_context.is_empty() and _duel_context.get("battle_kind","") in ["story","training"] and String(_duel_context.get("enemy_identity",""))==enemy_identity and uses_painted_enemy() and painted_hero_enabled and painted_support_enabled and painted_backdrop_enabled

func hit(kind:String,details:Dictionary={})->void:
	if details.has("valid") and not bool(details["valid"]):return
	var use_stage:bool=uses_formation()
	if is_instance_valid(formation_stage):formation_stage.reset_presentation()
	super.hit(kind,details)
	_formation_presenting=use_stage
	if use_stage:
		_ensure_stage()
		var accepted:Dictionary=_accepted_presentation(kind,details)
		if formation_stage.present(accepted):
			formation_stage.presentation_duration=presentation_duration
			# Preserve legacy support parsing/poses and explicitly accepted zeroes.
			formation_stage.presentation_details=presentation_details.duplicate(true)
			formation_stage.presentation_details["counter_0"]=int(presentation_details.get("player_damage",0))
		else:_formation_presenting=false
	_sync_visibility()

func _accepted_presentation(kind:String,details:Dictionary)->Dictionary:
	var before:Dictionary=_duel_context.duplicate(true)
	var after:Dictionary=before.duplicate(true)
	var support:Dictionary=presentation_details.get("support",{})
	var self_heal:int=int(presentation_details.get("self_healing",0))
	var support_heal:int=int(presentation_details.get("support_healing",0))
	var hero_damage:int=int(presentation_details.get("enemy_damage",0))
	var support_damage:int=int(presentation_details.get("companion_damage",0))
	var incoming:int=int(presentation_details.get("player_damage",0))
	var qi_delta:int=0
	# The real rule result confirms resource use. Bare legacy hit(kind) calls
	# may animate, but must not fabricate a qi or medicine transaction.
	if bool(details.get("valid",false)):
		after.turn=int(before.turn)+1
		match kind:
			"attack":qi_delta=mini(2,int(before.max_qi)-int(before.qi))
			"guard":qi_delta=mini(1,int(before.max_qi)-int(before.qi))
			"skill":qi_delta=-int(before.art_cost)
	after.qi=clampi(int(before.qi)+qi_delta+int(support.get("qi",0)),0,int(before.max_qi))
	after.hp=maxi(0,mini(int(before.max_hp),int(before.hp)+self_heal+support_heal)-incoming)
	after.units[0].hp=maxi(0,int(before.units[0].hp)-hero_damage-support_damage)
	if kind=="item" and bool(details.get("valid",false)):after.medicine=maxi(0,int(before.medicine)-1)
	after["outcome"]="fled" if kind=="flee" else ("victory" if bool(presentation_details.get("enemy_defeated",false)) else ("defeat" if bool(presentation_details.get("player_defeated",false)) else ""))
	var counters:Array=[]
	if bool(presentation_details.get("counter",false)):
		counters.append({"unit_id":"bracer","damage":incoming,"guarded":bool(presentation_details.get("guarded",false)),"cover":int(support.get("cover",0)),"heavy":bool(before.heavy)})
	return {"accepted":true,"ok":true,"action":kind,"target_id":"bracer","before":before,"after":after,
		"hero_damage":hero_damage,"support_damage":support_damage,"counter_damage":incoming,
		"heal":self_heal,"support_heal":support_heal,"support_qi":int(support.get("qi",0)),
		"hero_qi_delta":qi_delta,"guarded":bool(presentation_details.get("guarded",false)),"counters":counters}

func _process(delta:float)->void:
	super._process(delta)
	if uses_formation() and is_instance_valid(formation_stage):
		_sync_stage_clock(action_time)
		formation_stage.phase=phase
		formation_stage.queue_redraw()
	_sync_visibility()

func _emit_impact(target:String,key:String,at:float,previous:float)->void:
	if _formation_presenting and previous<at and action_time>=at:
		# Advance one beat at a time even if this frame crosses the entire action.
		# The inherited signal retains its exact name, amount, order and timestamp.
		_sync_stage_clock(at)
	super._emit_impact(target,key,at,previous)

func _sync_stage_clock(time:float)->void:
	if not is_instance_valid(formation_stage) or not formation_stage.is_presenting():return
	formation_stage.action_time=time
	formation_stage._advance_display()
	formation_stage.flash=flash

func _finish_formation()->void:
	if not _formation_presenting or not is_instance_valid(formation_stage):return
	_sync_stage_clock(action_time)
	formation_stage.display_snapshot=formation_stage.after_snapshot.duplicate(true)
	formation_stage._presenting=false
	formation_stage.flash=0.0
	formation_stage.queue_redraw()

func reset_presentation()->void:
	# Reset child first so inherited cancellation signals never expose stale art.
	if is_instance_valid(formation_stage):formation_stage.reset_presentation()
	_formation_presenting=false
	super.reset_presentation()
	_sync_visibility()

func _sync_visibility()->void:
	if is_instance_valid(formation_stage):formation_stage.visible=uses_formation()

func unit_label_rect(id:String)->Rect2:
	if not uses_formation() or id not in ["hero","enemy","support"]:return Rect2()
	return formation_stage.unit_label_rect("bracer" if id=="enemy" else id)

func unit_label_alpha(id:String)->float:
	if not uses_formation() or id not in ["hero","enemy","support"]:return 0.0
	return formation_stage.unit_label_alpha("bracer" if id=="enemy" else id)

func _draw()->void:
	if not uses_formation():super._draw()
