class_name ChapterRules
extends RefCounted
const SEAL_ORDER: Array[int]=[2,0,1]
const CLUES: Array[String]=["clerk","inscription"]
static func begin(state) -> bool:
	if state.quest_stage<6 or state.side_stage<3 or state.chapter_two_stage!=0: return false
	state.chapter_two_stage=1
	return true
static func clue(state,id:String) -> bool:
	if state.chapter_two_stage!=1 or not CLUES.has(id) or state.archive_clues.has(id): return false
	state.archive_clues.append(id)
	state.gain_xp(10)
	return true
static func seal(state,index:int) -> Dictionary:
	if state.chapter_two_stage!=1 or state.archive_clues.size()!=2 or index<0 or index>2:
		return {"valid":false,"complete":false,"message":"先问清印记的来历，再试着启封。"}
	if index!=SEAL_ORDER[state.seal_sequence.size()]:
		state.seal_sequence.clear()
		return {"valid":true,"complete":false,"message":"印扣没有响应。顺序已重置；石碑上的话还记得吗？"}
	state.seal_sequence.append(index)
	if state.seal_sequence.size()==3:
		state.chapter_two_stage=2
		return {"valid":true,"complete":true,"message":"三印相合，封仓的机关松开了。"}
	return {"valid":true,"complete":false,"message":"一枚印扣亮起，还需下一枚。"}
static func victory(state) -> bool:
	if state.chapter_two_stage!=2: return false
	state.chapter_two_stage=3
	return true
static func resolve(state,choice:String) -> bool:
	if state.chapter_two_stage!=3 or not ["open_records","protect_witness"].has(choice):return false
	state.chapter_two_stage=4;state.chapter_two_ending=choice
	state.coins+=65;state.gain_xp(100)
	return true
static func repair_bridge(state) -> bool:
	if state.bridge_repaired or int(state.resources.get("timber",0))<2:return false
	state.resources.timber-=2;state.bridge_repaired=true
	state.coins+=20;state.gain_xp(25)
	return true
static func restore(state,data:Dictionary) -> void:
	state.chapter_two_stage=state._bounded_int(data,"chapter_two_stage",0,0,4)
	state.chapter_two_ending=String(data.get("chapter_two_ending",""))
	state.bridge_repaired=bool(data.get("bridge_repaired",false))
	state.archive_clues.clear()
	for id in data.get("archive_clues",[]):
		if CLUES.has(id) and not state.archive_clues.has(id):state.archive_clues.append(id)
	state.seal_sequence.clear()
	if state.chapter_two_stage>=2:
		for id in CLUES:
			if not state.archive_clues.has(id):state.archive_clues.append(id)
		state.seal_sequence.assign(SEAL_ORDER)
	elif state.chapter_two_stage==1 and state.archive_clues.size()==2:
		for i in range(mini(data.get("seal_sequence",[]).size(),3)):
			if float(data.seal_sequence[i])!=float(SEAL_ORDER[i]):
				state.seal_sequence.clear();break
			state.seal_sequence.append(SEAL_ORDER[i])
		if state.seal_sequence.size()==3:state.chapter_two_stage=2
	if state.chapter_two_stage==0:
		state.archive_clues.clear();state.seal_sequence.clear();state.chapter_two_ending=""
