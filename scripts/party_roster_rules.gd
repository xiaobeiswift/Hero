class_name PartyRosterRules
extends RefCounted
## Pure schema-12 integration plan. Nothing here writes a file or mutates State.
## Commit payload + hero_resources together only after ok, under the caller's
## existing battle epoch/settlement gate. This does NOT change SAVE_VERSION.
const Catalog = preload("res://scripts/party_actor_catalog.gd")
const Companions = preload("res://scripts/companion_rules.gd")
const PAYLOAD_VERSION: int = 12
const PARTY_KEYS: Array[String] = ["party_roster", "party_resources"]
const RESOURCE_KEYS: Array[String] = ["hp", "qi"]


## State must be the fully normalized candidate for player_data, not the live
## pre-load state. Validate the whole save first, then this plan, then commit.
## Only absent legacy fields migrate. A present pair is validated, never healed.
static func load_plan(state, player_data: Variant, source_version: Variant) -> Dictionary:
	if state == null or not player_data is Dictionary or not _integer(source_version, 1, PAYLOAD_VERSION):
		return _error("存档版本或角色资料无效。")
	if state.battle_active:
		return _error("交锋中不能读取出战名单。")
	if int(state.hp) < 1:
		return _error("非战斗存档的主角必须至少有一点气血。")
	# The old loader clamps hero HP to1. A schema12 HP0 must not get a silent
	# revival through that normalization, so inspect present raw core resources.
	# The whole-save validator owns required core fields; party-only callers may
	# supply this isolated pair with an already validated normalized State.
	if int(source_version) == PAYLOAD_VERSION:
		for key: String in RESOURCE_KEYS:
			var minimum: int = 1 if key == "hp" else 0
			if player_data.has(key) and not _integer(player_data[key], minimum, int(state.get("max_" + key))):
				return _error("新存档的主角气血或真气无效。")
	var present: int = int(player_data.has(PARTY_KEYS[0])) + int(player_data.has(PARTY_KEYS[1]))
	if present == 1 or (int(source_version) == PAYLOAD_VERSION and present != 2):
		return _error("出战名单与同行资源必须成对保存。")
	if present == 2:
		return validate_payload(state, {PARTY_KEYS[0]: player_data[PARTY_KEYS[0]], PARTY_KEYS[1]: player_data[PARTY_KEYS[1]]})
	var catalog: Dictionary = _catalog(state)
	if not catalog.ok:
		return _error(catalog.reason)
	var roster: Array[String] = ["hero"]
	# Keep the schema1–11 fallback explicit: modern active() honors hero-only.
	# Explicit schema12 rosters never go through this compatibility path.
	var available: Array[String] = Companions.available(state)
	var chosen: String = String(state.active_companion)
	if not available.has(chosen):
		chosen = available[0] if not available.is_empty() else ""
	var saved_choice: Variant = player_data.get("active_companion", chosen)
	if not saved_choice is String:
		return _error("旧同行选择无效。")
	if (saved_choice == Companions.SHEN and state.companion_unlocked) or (saved_choice == Companions.TANG and state.tangqi_unlocked):
		chosen = saved_choice
	if chosen == Companions.SHEN:
		roster.append("shen")
	elif chosen == Companions.TANG:
		roster.append("tang")
	return validate_payload(state, {"party_roster": roster, "party_resources": _full_resources(catalog.actors)})


## A payload has exactly these two fields. Every recruited companion has one
## complete hp/qi entry even when not selected; hero never has a resource entry.
## Integral JSON floats normalize to ints, but fractional/nonfinite values fail.
static func validate_payload(state, payload: Variant) -> Dictionary:
	var catalog: Dictionary = _catalog(state)
	if not catalog.ok:
		return _error(catalog.reason)
	if not payload is Dictionary or not _exact_keys(payload, PARTY_KEYS):
		return _error("同行资料只允许名单与资源两个字段。")
	if not payload.party_roster is Array or not payload.party_resources is Dictionary:
		return _error("同行名单或资源格式无效。")
	var roster_result: Dictionary = _validate_roster(payload.party_roster, catalog.actors)
	if not roster_result.ok:
		return _error(roster_result.reason)
	var expected: Array[String] = []
	for id: String in catalog.actors:
		if id != "hero":
			expected.append(id)
	var resources_result: Dictionary = _validate_resources(payload.party_resources, expected, catalog.actors)
	if not resources_result.ok:
		return _error(resources_result.reason)
	return _success({"party_roster": payload.party_roster, "party_resources": resources_result.resources}, catalog.hero_resources)


## This operation changes selection only. Deselect/reselect never drops damage,
## revives a downed companion, resets qi, or creates an unrecruited actor.
static func select_roster(state, payload: Variant, roster_ids: Variant) -> Dictionary:
	if state == null or state.battle_active:
		return _error("交锋中不能更换出战名单。")
	var prior: Dictionary = validate_payload(state, payload)
	if not prior.ok:
		return prior
	return validate_payload(state, {"party_roster": roster_ids, "party_resources": prior.payload.party_resources})


## Call around an explicit recruitment/stat change, with its real before/after
## normalized states. Existing companion absolute HP/qi is preserved on growth
## and capped on shrink; zero stays zero. A newly recruited member gets real
## catalog maxima and remains unselected. Recruitment cannot be undone here.
## Hero takes the after-state's resources: gain_xp's existing explicit hero
## full-heal policy remains upstream; catalog/stat rebuilding adds no healing.
static func reconcile_growth(before_state, after_state, payload: Variant) -> Dictionary:
	if before_state == null or after_state == null or before_state.battle_active or after_state.battle_active:
		return _error("交锋中不能重建同行持久资源。")
	var prior: Dictionary = validate_payload(before_state, payload)
	if not prior.ok:
		return prior
	var catalog: Dictionary = _catalog(after_state)
	if not catalog.ok:
		return _error(catalog.reason)
	var resources: Dictionary = prior.payload.party_resources.duplicate(true)
	for id: String in resources:
		if not catalog.actors.has(id):
			return _error("不能借资源重建移除已招募同行人。")
	for id: String in catalog.actors:
		if id == "hero":
			continue
		if not resources.has(id):
			resources[id] = _max_resources(catalog.actors[id])
		else:
			for key: String in RESOURCE_KEYS:
				resources[id][key] = mini(int(resources[id][key]), int(catalog.actors[id]["max_" + key]))
	return validate_payload(after_state, {"party_roster": prior.payload.party_roster, "party_resources": resources})


## Catalog build_team accepts selected resources only; this projection retains
## benched resources in payload and emits just the selected actors for combat.
static func battle_resources(state, payload: Variant) -> Dictionary:
	var prior: Dictionary = validate_payload(state, payload)
	if not prior.ok:
		return prior
	var resources: Dictionary = {"hero": prior.hero_resources}
	for id: String in prior.payload.party_roster:
		if id != "hero":
			resources[id] = prior.payload.party_resources[id]
	return Catalog.immutable({"ok": true, "reason": "", "resources": resources})


## Explicit free rest restores ALL recruited members, including benched/downed
## actors, to current catalog maxima. It cannot execute while battle is active.
static func rest_plan(state, payload: Variant) -> Dictionary:
	if state == null or state.battle_active:
		return _error("交锋中不能调息。")
	var prior: Dictionary = validate_payload(state, payload)
	if not prior.ok:
		return prior
	var catalog: Dictionary = _catalog(state)
	return _success({"party_roster": prior.payload.party_roster, "party_resources": _full_resources(catalog.actors)}, _max_resources(catalog.actors.hero))


## terminal_resources is {selected_id: {hp, qi}}, including hero, extracted from
## the completed model. The caller must clear its battle-active gate only after
## the real terminal transaction/epoch is accepted; this pure helper cannot
## establish that provenance or enforce once-only rewards/coin loss itself.
## win/flee: only a surviving selected party may finish; hero HP0 becomes HP1
## here, outside battle, with no companion resurrection or qi refund.
## defeat: all selected actors must be down; explicit safe recovery gives every
## recruited actor max HP and qi at least2 (capped), matching legacy hero recovery.
static func settle_plan(state, payload: Variant, terminal_resources: Variant, outcome: String) -> Dictionary:
	if state == null or state.battle_active:
		return _error("交锋尚未结算，不能恢复倒下的角色。")
	if not outcome in ["win", "flee", "defeat"]:
		return _error("交锋结果无效。")
	var prior: Dictionary = validate_payload(state, payload)
	if not prior.ok:
		return prior
	var catalog: Dictionary = _catalog(state)
	var terminal: Dictionary = _validate_resources(terminal_resources, prior.payload.party_roster, catalog.actors)
	if not terminal.ok:
		return _error(terminal.reason)
	var survivors: int = 0
	for id: String in terminal.resources:
		if terminal.resources[id].hp > 0:
			survivors += 1
	if (outcome == "defeat" and survivors > 0) or (outcome != "defeat" and survivors == 0):
		return _error("交锋结果与存活名单不一致。")
	var resources: Dictionary = prior.payload.party_resources.duplicate(true)
	var hero: Dictionary = terminal.resources.hero.duplicate(true)
	for id: String in terminal.resources:
		if id != "hero":
			resources[id] = terminal.resources[id].duplicate(true)
	if outcome == "defeat":
		for id: String in catalog.actors:
			var current: Dictionary = hero if id == "hero" else resources[id]
			current.hp = int(catalog.actors[id].max_hp)
			current.qi = mini(int(catalog.actors[id].max_qi), maxi(2, int(current.qi)))
	else:
		hero.hp = maxi(1, int(hero.hp))
	return _success({"party_roster": prior.payload.party_roster, "party_resources": resources}, hero)


static func _catalog(state) -> Dictionary:
	if state == null:
		return {"ok": false, "reason": "缺少角色状态。"}
	var ids: Array[String] = ["hero"]
	if state.companion_unlocked:
		ids.append("shen")
	if state.tangqi_unlocked:
		ids.append("tang")
	if state.has_method("qin_recruited") and state.qin_recruited():
		ids.append("qin")
	var built: Dictionary = Catalog.build_team(state, ids)
	if not built.ok:
		return {"ok": false, "reason": built.reason}
	var actors: Dictionary = {}
	for actor: Dictionary in built.team.actors:
		actors[actor.id] = actor
	# Do not inherit the catalog's defensive hero clamping as save validation.
	if not _integer(state.hp, 0, int(actors.hero.max_hp)) or not _integer(state.qi, 0, int(actors.hero.max_qi)):
		return {"ok": false, "reason": "主角气血或真气超出有效范围。"}
	return {"ok": true, "reason": "", "actors": actors, "hero_resources": {"hp": int(state.hp), "qi": int(state.qi)}}


static func _validate_roster(roster: Variant, actors: Dictionary) -> Dictionary:
	if not roster is Array or roster.is_empty() or roster.size() > Catalog.MAX_PARTY_SIZE or roster[0] != "hero":
		return {"ok": false, "reason": "名单须以主角为首，最多四人。"}
	var seen: Array[String] = []
	for id: Variant in roster:
		if not id is String or not actors.has(id) or seen.has(id):
			return {"ok": false, "reason": "名单含未知、重复或未招募角色。"}
		seen.append(id)
	return {"ok": true, "reason": ""}


static func _validate_resources(resources: Variant, ids: Array, actors: Dictionary) -> Dictionary:
	if not resources is Dictionary or not _exact_keys(resources, ids):
		return {"ok": false, "reason": "资源必须完整对应所需角色。"}
	var normalized: Dictionary = {}
	for id: String in ids:
		var entry: Variant = resources[id]
		if not entry is Dictionary or not _exact_keys(entry, RESOURCE_KEYS):
			return {"ok": false, "reason": "每位角色仅能保存气血与真气。"}
		normalized[id] = {}
		for key: String in RESOURCE_KEYS:
			if not _integer(entry[key], 0, int(actors[id]["max_" + key])):
				return {"ok": false, "reason": "气血与真气须为上限内的有限非负整数。"}
			normalized[id][key] = int(entry[key])
	return {"ok": true, "reason": "", "resources": normalized}


static func _exact_keys(data: Dictionary, keys: Array) -> bool:
	if data.size() != keys.size():
		return false
	for key: Variant in data:
		if not key is String or not keys.has(key):
			return false
	return true


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= maximum


static func _max_resources(actor: Dictionary) -> Dictionary:
	return {"hp": int(actor.max_hp), "qi": int(actor.max_qi)}


static func _full_resources(actors: Dictionary) -> Dictionary:
	var resources: Dictionary = {}
	for id: String in actors:
		if id != "hero":
			resources[id] = _max_resources(actors[id])
	return resources


static func _success(payload: Dictionary, hero_resources: Dictionary) -> Dictionary:
	return Catalog.immutable({"ok": true, "reason": "", "payload": payload, "hero_resources": hero_resources})


static func _error(reason: String) -> Dictionary:
	return Catalog.immutable({"ok": false, "reason": reason, "payload": {}, "hero_resources": {}})
