class_name SectRules
extends RefCounted
const TRIALS={
	"听潮阁":{"art":"回潮断浪","requirement":"在本场试招中施展一次回潮断浪，再赢下切磋。"},
	"照野堂":{"art":"青灯续脉","requirement":"在本场试招中以青灯续脉实际恢复气血，再赢下切磋。满血空施不算。"},
	"问石门":{"art":"磐石回锋","requirement":"以磐石回锋实际接下一次重击，再赢下切磋。轻功或同伴护势不代替本门考法；同行时可用护后让主角迎敌。"},
}
static func art(state) -> String:return String(TRIALS.get(state.sect,{}).get("art",""))
static func requirement(state) -> String:return String(TRIALS.get(state.sect,{}).get("requirement","请先获得门派荐帖。"))
static func eligible(state) -> bool:
	return state.sect_rank==1 and state.level>=3 and TRIALS.has(state.sect) and not state.sect_trial_won
static func met(state) -> bool:
	match state.sect:
		"听潮阁":return state._trial_art_used
		"照野堂":return state._trial_healing>0
		"问石门":return state._trial_guarded_heavy
	return false
static func complete(state) -> bool:
	if state.sect_rank!=1 or not state.sect_trial_won:return false
	state.sect_rank=2;state.sect_merit+=3;state.max_qi+=1;state.defense+=1
	state.qi=state.max_qi
	return true
