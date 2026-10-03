class_name JournalGuidanceSession
extends RefCounted
## Transient controller state only. Never attach this to HeroState or save it.
## The host also checks journal ownership, exploration and modal generation.
## Successful new/load/import MUST call reset, even on the same state object;
## failed/cancelled loads call nothing and leave this session untouched.
const Objectives = preload("res://scripts/journal_objective_rules.gd")
const Guidance = preload("res://scripts/journal_guidance_rules.gd")
var _tracked_arc_id: String = ""
var tracked_arc_id: String:
	get: return _tracked_arc_id
var _state_id: int = 0
var _epoch: int = 0
var _map_id: String = ""

func reset(s) -> void:
	_tracked_arc_id = ""
	_state_id = s.get_instance_id() if is_instance_valid(s) else 0
	_map_id = String(s.map_id) if is_instance_valid(s) else ""
	_epoch += 1

func invalidate_callbacks() -> void: _epoch += 1

func token(s) -> Dictionary:
	if not is_instance_valid(s) or s.get_instance_id() != _state_id: return {}
	return {"session_id":get_instance_id(), "state_id":_state_id, "epoch":_epoch, "map_id":String(s.map_id)}

func track(s, arc_id: String, expected: Dictionary) -> bool:
	if not _current(s, expected): return false
	var selected: Dictionary = Objectives.row(s, arc_id)
	if selected.is_empty() or not selected.trackable or _tracked_arc_id == arc_id: return false
	_tracked_arc_id = arc_id
	_epoch += 1
	return true

func restore_auto(s, expected: Dictionary) -> bool:
	if not _current(s, expected) or _tracked_arc_id.is_empty(): return false
	_tracked_arc_id = ""; _epoch += 1
	return true

func refresh(s, context: Dictionary) -> Dictionary:
	var prior: String = _tracked_arc_id
	var replacement: bool = not is_instance_valid(s) or s.get_instance_id() != _state_id
	if replacement: reset(s)
	elif _map_id != String(s.map_id):
		_map_id = String(s.map_id); _epoch += 1
	var result: Dictionary = Guidance.resolve(s, _tracked_arc_id, context)
	var changed: bool = prior != String(result.valid_tracked_arc_id)
	var notice: String = ""
	if changed:
		if replacement:
			notice = "旅程已更新，已恢复自动指引。"
			result.reset_reason = "state_replaced"
		else:
			var previous_row: Dictionary = Objectives.row(s, prior)
			notice = (String(previous_row.get("display_title", "此事")) + "已完成，已恢复自动指引。") if result.reset_reason == "completed" else "原追踪已不适用，已恢复自动指引。"
		_tracked_arc_id = String(result.valid_tracked_arc_id)
		_epoch += 1
	result.selection_changed = changed; result.selection_notice = notice
	return result.duplicate(true)

func _current(s, expected: Dictionary) -> bool:
	return is_instance_valid(s) and not s.battle_active and s.get_instance_id() == _state_id \
		and expected.get("session_id", 0) == get_instance_id() and expected.get("state_id", 0) == _state_id \
		and expected.get("epoch", -1) == _epoch and expected.get("map_id", "") == String(s.map_id)
