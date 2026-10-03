extends RefCounted
## Prepared test-only inputs and retained actual observations. Never a selector.
## Policy expectations come from literal assertions or the pinned old corpus,
## never from injecting an expected target into a consumer.
const State=preload("res://scripts/game_state.gd")
const Guidance=preload("res://scripts/journal_guidance_rules.gd")
const ORACLE_PATH="res://tests/journal_guidance_frozen_oracle.json"
const ORACLE_SHA="38cb8469799e8169201c06e203cd219901e3d06c159c09998ffc2e577ff0c443"
static func corpus()->Dictionary:
	assert(FileAccess.get_sha256(ORACLE_PATH)==ORACLE_SHA)
	var retained=JSON.parse_string(FileAccess.get_file_as_string(ORACLE_PATH))
	assert(retained is Dictionary and retained.rows.size()==117 and retained.reviewed_target_differences.size()==14)
	return retained
static func retained_row(label:String)->Dictionary:
	for item:Dictionary in corpus().rows:
		if item.label==label:return item.duplicate(true)
	assert(false,"Missing independently retained label: "+label)
	return {}
static func read_state(data:Dictionary):
	var probe=State.new()
	var accepted=probe.inspect_save_bytes(JSON.stringify({"version":16,"player":data}).to_utf8_buffer())
	assert(accepted.ok,"Prepared/retained state must pass the unchanged production reader")
	assert(JSON.parse_string(JSON.stringify(accepted.state.to_dict()))==JSON.parse_string(JSON.stringify(data)),"Reader preserves every canonical JSON value; numeric types from JSON parse are representational only")
	return accepted.state
static func from_retained(label:String):return read_state(retained_row(label).state)
static func retained_context(data:Dictionary)->Dictionary:
	var markers:Dictionary={}
	for id:String in data.markers:
		var item:Dictionary=data.markers[id]
		markers[id]={"pos":Vector2(item.position[0],item.position[1]),"name":item.name,"kind":item.kind}
	return {"map_id":data.map_id,"player_position":Vector2(data.player_position[0],data.player_position[1]),"markers":markers}
static func base(completed:int=0):
	var s=State.new()
	if completed>=1:s.quest_stage=6;s.ending="守望";s.sect="听潮阁";s.sect_rank=1;s.level=3
	if completed>=2:s.side_stage=3;s.side_choice="rescue";s.side_reward_claimed=true;s.side_found.assign(["boatman","ledger"]);s.side_clues=2
	if completed>=3:s.chapter_two_stage=4;s.chapter_two_ending="protect_witness";s.archive_clues.assign(["clerk","inscription"]);s.seal_sequence.assign([2,0,1])
	if completed>=4:s.mist_stage=4;s.mist_approach="duel";s.mist_ending="release_water";s.mist_gauges.assign(["rain","stone","basin"])
	if completed>=5:s.heting_stage=4;s.heting_bridge="east";s.heting_delivered.assign(["meal","sealed","reserve"]);s.heting_draft="short_ferries";s.heting_ending="short_ferries"
	return s
static func consignee(stage:int,side:String="west",plan:String="hold_for_inspection"):
	var s=base(5);s.map_id="heting";s.heting_bridge=side;s.consignee_stage=stage
	s.consignee_observations.assign(State.Consignee.OBSERVATIONS if stage>=2 else [])
	s.consignee_draft=plan if stage>=2 else ""
	s.consignee_cargo_location="" if stage==0 else ("warehouse" if stage<4 else ("cart" if stage==4 else ("public_scale" if plan=="hold_for_inspection" else "grain_boat")))
	s.consignee_ending=plan if stage==5 else ""
	return read_state(s.to_dict())
static func sync_physical(w,s,position:Vector2)->void:
	# Copy only physical/scenic facts. No legacy priority/target fields are set.
	for field:String in ["quest_stage","side_stage","bridge_repaired","heting_stage","heting_bridge","heting_cargo","heting_draft","heting_ending","mist_ending","consignee_stage","consignee_draft","consignee_cargo_location","consignee_ending","capstone_stage","capstone_draft","capstone_ending"]:w.set(field,s.get(field))
	w.heting_delivered=s.heting_delivered.duplicate();w.consignee_observations=s.consignee_observations.duplicate()
	w.chapter_stage=s.chapter_two_stage;w.chapter_ending=s.chapter_two_ending;w.mist_completed=s.mist_stage>=4
	w.capstone_goal=State.Capstone.goal(s);w.capstone_orders=State.Capstone.order_rows(s)
	w.change_map(s.map_id,position);w.refresh_capstone_points();w.refresh_heting_points()
static func project(w,s,arc:String="")->Dictionary:
	# Caller supplies current physical World; expected target is never an input.
	read_state(s.to_dict())
	assert(w.map_id==s.map_id)
	var names:Dictionary={}
	for id:String in w.interactables:names[id]=w.get_npc_name(id)
	var before:Dictionary=s.to_dict();var markers:Dictionary=w.interactables.duplicate(true)
	var result=Guidance.resolve(s,arc,{"map_id":w.map_id,"player_position":w.player_pos,"markers":markers,"marker_names":names})
	assert(s.to_dict()==before and w.interactables==markers)
	w.set_journal_guidance(result)
	return result
static func chart_projection(chart,w,s,result:Dictionary)->void:
	chart.map_id=w.map_id;chart.markers=w.interactables.duplicate(true);chart.player_position=w.player_pos
	chart.heting_bridge=s.heting_bridge;chart.heting_cargo=s.heting_cargo;chart.consignee_cargo_location=s.consignee_cargo_location
	chart.bridge_repaired=s.bridge_repaired;chart.set_journal_guidance(result)
