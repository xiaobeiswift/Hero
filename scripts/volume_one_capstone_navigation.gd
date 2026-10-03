class_name VolumeOneCapstoneNavigation
extends RefCounted
## Read-only projection of VolumeOneCapstoneRules.goal through existing exits.
## Never recomputes quest eligibility/stage or changes maps, state or resources.
const MAPS: Array[String] = ["qingwei", "sluice", "frostbridge", "mistwood", "heting"]
const FORWARD: Dictionary = {"qingwei":"exit_sluice", "sluice":"exit_frostbridge", "frostbridge":"exit_mistwood", "mistwood":"exit_heting"}
const BACKWARD: Dictionary = {"sluice":"return_village", "frostbridge":"return_sluice", "mistwood":"return_frostbridge", "heting":"return_mistwood"}

static func resolve(goal: Dictionary, current_map: String) -> Dictionary:
	if goal.is_empty() or not MAPS.has(current_map): return {}
	var destination: String = String(goal.get("map_id", ""))
	var site: String = String(goal.get("site_id", ""))
	if not MAPS.has(destination) or site.is_empty(): return {}
	var result: Dictionary = goal.duplicate(true)
	var here: int = MAPS.find(current_map)
	var there: int = MAPS.find(destination)
	result.target_id = site if here == there else String(FORWARD.get(current_map, "") if here < there else BACKWARD.get(current_map, ""))
	result.destination_map = destination
	result.is_exit = here != there
	return result

static func target_id(goal: Dictionary, current_map: String) -> String:
	return String(resolve(goal, current_map).get("target_id", ""))
