class_name HetingReceiptRules
extends RefCounted
## Optional aftermath of either harbor ending; receipt_stage is the sole marker.
## can_begin/begin/settle_victory/compare return bool. A true begin also accepts
## stage 1 for a retry, without paying or advancing it. hint/journal return text.
## The caller owns the transient two-target fight, clears battle_active after a
## verified victory, then settles once and saves the resulting state. A failed
## save must retry persistence of that state, never roll back and settle again.
## valid checks this feature and its harbor prerequisite; HeroState must validate
## the entire save document before reset/restore. Missing legacy stage means 0.
const Heting = preload("res://scripts/heting_rules.gd")
const TITLE: String = "鹤汀余事·复签不撤"
const REWARD_XP: int = 80
const REWARD_COINS: int = 40


static func can_begin(s) -> bool:
	return _at_port(s) and s.receipt_stage in [0, 1]


static func begin(s) -> bool:
	if not can_begin(s):
		return false
	s.receipt_stage = 1
	return true


static func settle_victory(s) -> bool:
	if not _at_port(s) or s.receipt_stage != 1:
		return false
	# Consume the accepted encounter before any reward callback can re-enter.
	s.receipt_stage = 2
	s.coins = mini(999999, s.coins + REWARD_COINS)
	s.victories = mini(999999, s.victories + 1)
	s.gain_xp(REWARD_XP)
	return true


static func compare(s) -> bool:
	if not _at_port(s) or s.receipt_stage != 2:
		return false
	# Evidence is derived from this durable stage, not an item to grant twice.
	s.receipt_stage = 3
	return true


static func hint(s) -> String:
	if s.heting_stage != 4:
		return "先办妥鹤汀交割，再听复称副签的后续。"
	match s.receipt_stage:
		0: return "鹤汀交割已定，可到东岸公秤棚听施衡说次晨复核的事。"
		1: return "复称副签尚未取回。备妥后可再应战，原定的分粮安排照旧。"
		2: return "复称副签已取回，回东岸公秤棚与施衡并看水损票和预结粮钱的记录。"
		3: return "副签已核，实交与票据的先后留在行纪。"
	return "复称记录尚待核实。"


static func journal(s) -> String:
	match s.receipt_stage:
		0:
			return "鹤汀交割办妥后，东岸公秤棚还留着一件次晨复核的事。" if s.heting_stage == 4 else "鹤汀余事尚未听闻。"
		1:
			return "次晨复核，两担封粮复称时仍干，副签却被人扣住，催着撤下柜边的实交记录。施衡请你取回副签，让已经记下的担数与时刻留得住。"
		2:
			return "复称副签已经取回，货号与两担干粮的记号仍清楚。尚须同施衡核对水损票、到港时刻和预结粮钱的记录，不能只凭交锋就替账下结论。"
		3:
			return "施衡将副签与旧抄件并放：同一货号的两担粮封口未湿，水损票却早于到港写成；预结粮钱的交割号又与它相合。三处记号接上了先后，假水损再不能抹去这两担实交。副签只记货号、担数与时刻，不添船工姓名；昨夜既定的分粮安排仍照旧。"
	return "复称记录尚待核实。"


static func valid(data: Dictionary, version: int) -> bool:
	if version >= 11 and not data.has("receipt_stage"):
		return false
	var stage = data.get("receipt_stage", 0)
	# JSON numbers arrive as floats, so accept integral floats but never coerce
	# strings, booleans, fractions, infinities, or out-of-range values.
	if not (stage is int or stage is float) or not is_finite(float(stage)):
		return false
	if float(stage) != floor(float(stage)) or stage < 0 or stage > 3:
		return false
	if stage == 0:
		return true
	return data.get("heting_stage", 0) == 4 and Heting.valid(data, 9)


static func _at_port(s) -> bool:
	return not s.battle_active and s.map_id == "heting" and s.heting_stage == 4 \
		and s.heting_cargo.is_empty() and Heting.valid(_progress(s), 9) \
		and valid(_progress(s), 11)


static func _progress(s) -> Dictionary:
	return {
		"receipt_stage": s.receipt_stage,
		"heting_stage": s.heting_stage, "heting_bridge": s.heting_bridge,
		"heting_delivered": s.heting_delivered, "heting_cargo": s.heting_cargo,
		"heting_draft": s.heting_draft, "heting_ending": s.heting_ending,
		"mist_stage": s.mist_stage, "mist_ending": s.mist_ending, "map_id": s.map_id,
	}
