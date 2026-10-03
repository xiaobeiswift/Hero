extends RefCounted
## Prepared canonical projection fixture, never an earned narrative/combat route.
const State=preload("res://scripts/game_state.gd")
const Rules=preload("res://scripts/volume_one_capstone_rules.gd")
static func state(stage:int=0,plan:String="pause_batch"):
	var s=State.new()
	s.quest_stage=6;s.ending="守望"
	s.side_stage=3;s.side_choice="rescue";s.side_reward_claimed=true;s.side_clues=2;s.side_found.assign(["boatman","ledger"])
	s.chapter_two_stage=4;s.chapter_two_ending="protect_witness";s.archive_clues.assign(["clerk","inscription"]);s.seal_sequence.assign([2,0,1])
	s.mist_stage=4;s.mist_approach="duel";s.mist_ending="release_water";s.mist_gauges.assign(["rain","stone","basin"])
	s.heting_stage=4;s.heting_bridge="east";s.heting_delivered.assign(["meal","sealed","reserve"]);s.heting_draft="short_ferries";s.heting_ending="short_ferries"
	s.consignee_stage=5;s.consignee_observations.assign(State.Consignee.OBSERVATIONS);s.consignee_draft="return_to_owner";s.consignee_ending="return_to_owner";s.consignee_cargo_location="grain_boat"
	s.capstone_stage=stage
	if stage>=6:s.capstone_draft=plan;s.capstone_ending=plan
	s.map_id="heting";s.position=Vector2(535,400)
	assert(s._stage_save_data(s.to_dict(),State.SAVE_VERSION).ok)
	return s
static func sync(w,s)->void:
	w.capstone_stage=s.capstone_stage;w.capstone_draft=s.capstone_draft;w.capstone_ending=s.capstone_ending
	w.capstone_goal=Rules.goal(s);w.capstone_orders=Rules.order_rows(s)
	w.refresh_capstone_points()
