class_name QinCompanionRules
extends RefCounted
## An optional, resource-free invitation. The state owns atomic recruitment.
const ENDINGS = ["release_water", "warn_ferries"]
const TITLE = "尺绳有托"

static func eligible(s) -> bool:
	return not s.battle_active and s.map_id == "mistwood" and s.mist_stage == 4 and s.mist_ending in ENDINGS

static func can_begin(s) -> bool:
	return eligible(s) and s.qin_stage == 0 and not s.qin_unlocked

static func begin(s) -> bool:
	if not can_begin(s): return false
	s.qin_stage = 1
	return true

static func inspect_rope(s) -> bool:
	if not eligible(s) or s.qin_stage != 1 or s.qin_unlocked: return false
	s.qin_stage = 2
	return true

static func arrange_handoff(s) -> bool:
	if not eligible(s) or s.qin_stage != 2 or s.qin_unlocked: return false
	s.qin_stage = 3
	return true

static func invite(s) -> bool:
	if not eligible(s) or s.qin_stage != 3 or s.qin_unlocked: return false
	return s._recruit_party_companion("qin")

static func hint(s) -> String:
	return ["雾竹坡水势安定后，问秦禾是否愿意同行。", "去北边雨痕竹尺，复核尺绳与警水刻线。", "到西南避雨营地，将尺绳记录交给轮值守坡人。", "回秦禾处，亲口邀请她同行。", "秦禾已可编入队伍；守渡横杖能替一名同伴抵挡下一次来击。"][clampi(s.qin_stage, 0, 4)]

static func target_id(s) -> String:
	if s.qin_stage not in [1, 2, 3]: return ""
	if s.map_id != "mistwood":
		return {"qingwei":"exit_sluice", "sluice":"exit_frostbridge", "frostbridge":"exit_mistwood", "heting":"return_mistwood"}.get(s.map_id, "")
	return ["", "mist_rain_gauge", "mist_camp", "mist_guide"][s.qin_stage]

static func journal(s) -> String:
	if s.qin_stage == 0: return ""
	var text = "\n\n[color=#d3b276]同行机缘 · 尺绳有托[/color]"
	var steps = ["答应复核尺绳", "查验竹尺与警水刻线", "交接营地轮值", "邀请秦禾同行"]
	for i in range(steps.size()): text += "\n" + ("✓ " if s.qin_stage > i else "◇ ") + steps[i]
	return text + "\n" + hint(s)
