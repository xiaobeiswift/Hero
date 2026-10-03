extends "res://tests/capstone_balance_test.gd"
## Detached fitting contract and full original-model semantic parity. The pinned
## old model is supplied by --legacy-model; no old source is overwritten.
const TrialFactory = preload("res://scripts/weapon_fitting_trial_rules.gd")
var fitting_rows: Array[Dictionary] = []
var legacy_model_path: String = ""

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--legacy-model="):
			legacy_model_path = argument.trim_prefix("--legacy-model=")
	var s = _earned_capstone("听潮阁", true, true)
	if s == null: _finish_fitting("model"); return
	_test_trial_factory(s)
	_test_trial_keys(s)
	_test_trial_rejections(s)
	_test_trial_default_parity(s)
	_finish_fitting("model")

func _new_trial(s, fitting: String = "plain", profile: String = "ordinary"):
	var model = Rules.new()
	check(model.configure_fitting_practice(s, fitting, profile), "Authentic enum-only trial configures " + fitting + "/" + profile)
	return model

func _test_trial_factory(s) -> void:
	for roster: Array in [["hero"], ["hero", "shen"], ["hero", "tang", "shen"], ["hero", "qin", "tang", "shen"]]:
		for formation: String in ["并肩", "护后"]:
			check(s.set_party_roster(["hero", "shen", "tang", "qin"]) and s.set_formation(formation), "Actual formation selection before solo reselection")
			check(s.set_party_roster(roster), "Actual selected owned roster")
			for profile: String in TrialFactory.PROFILES:
				var key: String = ""
				var specs: Array = []
				var original_actors: Array = []
				var before: Dictionary = s.to_dict().duplicate(true)
				for fitting: String in ["plain", "edge", "guard"]:
					var model = _new_trial(s, fitting, profile)
					var metadata: Dictionary = model.fitting_trial_metadata()
					var view: Dictionary = model.snapshot()
					check(_frozen_tree(metadata), "Comparison metadata recursively read only and data only")
					check(_frozen_tree(model.fitting_trial_snapshot()), "Metrics recursively read only and data only")
					check(view.encounter_id == "courtyard_practice" and view.medicine == 3 and view.medicine_heal == 40, "Original practice identity and borrowed medicine")
					check(metadata.borrowed_fitting == fitting and metadata.installed_fitting == s.weapon_fitting, "Installed and borrowed choices are separate")
					var ids: Array = []
					var budget: int = 0
					for actor: Dictionary in metadata.original_baseline.team.actors:
						ids.append(actor.id); budget += int(actor.attack)
					check(ids == roster, "Factory uses exactly selected owned actors and order")
					check(metadata.base_attack_budget == budget, "Frozen budget uses original attacks")
					if fitting == "plain":
						key = metadata.comparison_key; specs = metadata.enemy_specs; original_actors = view.actors
					else:
						check(metadata.comparison_key == key and metadata.enemy_specs == specs, "All candidates share exact specs and comparison key")
						for index: int in view.actors.size():
							var actor: Dictionary = view.actors[index].duplicate(true)
							if index == 0:
								check(actor.attack == original_actors[index].attack + (3 if fitting == "edge" else -3), "Apply exact hero attack once")
								check(actor.defense == original_actors[index].defense + (-2 if fitting == "edge" else 2), "Apply exact hero defense once")
								actor.attack = original_actors[index].attack; actor.defense = original_actors[index].defense
								# Available descriptions disclose projected attack; definitions,
								# costs and effects are unchanged and tested by default parity.
								actor.actions = original_actors[index].actions
							check(actor == original_actors[index], "Only hero attack/defense and truthful descriptions differ")
					for actor: Dictionary in view.actors:
						check(actor.hp == actor.max_hp and actor.qi == actor.max_qi, "Borrowed actor begins at full virtual resources")
					if profile == "ordinary":
						check(specs[0].hp == 96 and specs[1].hp == 64 and specs[0].attack == 14 and specs[0].heavy_attack == 24 and specs[1].attack == 10, "Default profile exact old woodmen")
					else:
						check(specs[0].hp == budget * 36 / 5 and specs[1].hp == budget * 24 / 5, "Independent integer HP truncation")
						check(specs[0].hp + specs[1].hp == 12 * budget - (0 if budget % 5 == 0 else 1), "No hidden remainder redistribution")
						check(specs[0].attack == 40 and specs[0].heavy_attack == 64 and specs[1].attack == 16 and specs[1].heavy_attack == 16, "Accepted pressure attacks only")
					var copy: Dictionary = metadata.duplicate(true)
					copy.enemy_specs[0].hp = 1
					copy.original_baseline.team.actors[0].attack = 1
					check(model.fitting_trial_metadata() == metadata, "Mutating detached metadata copy cannot reforge running trial")
					check(not model.configure_fitting_practice(s, "edge", "pressure"), "Active configuration cannot be replaced")
					check(s.to_dict() == before, "Factory and snapshots never change source State")
	# The live State is not kept alive by the model or metadata.
	var ephemeral = s._detached_persistent_state()
	var reference: WeakRef = weakref(ephemeral)
	var detached_model = _new_trial(ephemeral)
	ephemeral = null
	check(reference.get_ref() == null and detached_model.snapshot().active, "Factory retains no real or staged State reference")

func _test_trial_keys(s) -> void:
	check(s.set_party_roster(["hero", "shen", "tang", "qin"]), "Four-person baseline")
	var key: String = TrialFactory.build(s, "plain", "pressure").metadata.comparison_key
	var changed = s._detached_persistent_state()
	changed.hp = 1; changed.qi = 0; changed.medicine = 0
	changed.party_resources.shen.hp = 0; changed.party_resources.shen.qi = 0
	check(TrialFactory.build(changed, "guard", "pressure").metadata.comparison_key == key, "Real injuries/down/medicine normalize to identical borrowed resources")
	var view: Dictionary = _new_trial(changed, "guard", "pressure").snapshot()
	check(view.actors[1].hp == view.actors[1].max_hp and changed.party_resources.shen.hp == 0, "Borrowed downed ally is full only in detached model")
	changed = s._detached_persistent_state()
	check(changed.set_weapon_fitting("edge").ok, "Explicit installed selection succeeds")
	var prepared: Dictionary = TrialFactory.build(changed, "guard", "pressure")
	check(prepared.metadata.comparison_key == key and prepared.team.actors[0].attack == s.attack - 3, "Installed fitting excluded and never double-applied")
	check(prepared.metadata.installed_fitting == "edge" and prepared.metadata.borrowed_fitting == "guard", "Differing installed/borrowed metadata preserved")
	for field: String in ["attack", "defense", "max_hp", "max_qi", "level"]:
		changed = s._detached_persistent_state(); changed.set(field, changed.get(field) + 1)
		prepared = TrialFactory.build(changed, "plain", "pressure")
		check(prepared.ok and prepared.metadata.comparison_key != key, "Determinant invalidates comparison: " + field)
	for mode: String in ["formation", "roster", "order", "art", "rank", "internal", "lightness", "equipment", "armor"]:
		changed = s._detached_persistent_state()
		match mode:
			"formation": changed.formation = "并肩" if s.formation == "护后" else "护后"
			"roster": changed.set_party_roster(["hero"])
			"order": changed.set_party_roster(["hero", "qin", "tang", "shen"])
			"art": changed.equip_art("照夜一线")
			"rank": changed.art_uses[changed.equipped_art] += 15
			"internal": changed.internal_unlocked = not changed.internal_unlocked
			"lightness": changed.lightness_unlocked = not changed.lightness_unlocked
			"equipment": changed.equipment = "青钢剑"
			"armor": changed.armor = "轻纱内甲"
		prepared = TrialFactory.build(changed, "plain", "pressure")
		check(prepared.ok and prepared.metadata.comparison_key != key, "Determinant invalidates comparison: " + mode)
	for care: String in ["shore", "mobile"]:
		changed = s._detached_persistent_state()
		check(changed.begin_shen_care() and changed.consult_shen_patient() and changed.inspect_shen_shelter() and changed.choose_shen_care(care) and changed.post_shen_notice(), "Genuine companion history " + care)
		prepared = TrialFactory.build(changed, "plain", "pressure")
		check(prepared.ok and prepared.metadata.comparison_key != key, "Companion history bonus invalidates comparison " + care)
		check(prepared.metadata.original_baseline.team.actors[1].care_defense_bonus == (1 if care == "shore" else 0) and prepared.metadata.original_baseline.team.actors[1].care_healing_bonus == (2 if care == "mobile" else 0), "Exact real companion effects enter baseline")
	check(TrialFactory.build(s, "plain", "ordinary").metadata.comparison_key != key, "Profile invalidates comparison")

func _test_trial_rejections(s) -> void:
	for profile: String in ["", "comparison", "entry", "stronger", "ordinary "]:
		var model = Rules.new()
		check(not model.configure_fitting_practice(s, "plain", profile) and model.snapshot().phase == "unconfigured", "Unknown profile fails before configuration")
	for input: Variant in [null, {}, s.to_dict(), TrialFactory.build(s, "plain")]:
		var model = Rules.new()
		check(not model.configure_fitting_practice(input, "plain") and model.snapshot().phase == "unconfigured", "Serialized/reforged input is not authentic State")
	var model = Rules.new()
	check(not model.configure_fitting_practice(s, "attack") and model.snapshot().phase == "unconfigured", "Unknown fitting fails before configuration")
	for pair: Array in [[1, 0], [3, 1], [4, 2], [999, 999]]:
		var changed = s._detached_persistent_state()
		changed.attack = pair[0]; changed.defense = pair[1]
		for fitting: String in ["plain", "edge", "guard"]:
			var result: Dictionary = TrialFactory.build(changed, fitting, "pressure")
			var valid: bool = fitting == "plain" or (fitting == "edge" and pair[1] >= 2) or (fitting == "guard" and pair[0] >= 4)
			check(result.ok == valid, "Exact full lower-floor acceptance " + str(pair) + "/" + fitting)
			if result.ok:
				check(result.team.actors[0].attack == pair[0] + (3 if fitting == "edge" else (-3 if fitting == "guard" else 0)), "No attack clamp or cost erasure")
				check(result.team.actors[0].defense == pair[1] + (-2 if fitting == "edge" else (2 if fitting == "guard" else 0)), "No defense clamp or cost erasure")
	var changed = State.new()
	check(not TrialFactory.build(changed, "plain").ok and not TrialFactory.build(changed, "edge").ok and not TrialFactory.build(changed, "guard").ok, "Opening/sect lock cannot be bypassed even for borrowed plain")
	var pending = s._detached_persistent_state(); pending._party_pending_token = 99
	check(not TrialFactory.build(pending, "plain").ok, "Pending token without session blocks factory")
	changed.party_roster.append("qin")
	check(not TrialFactory.build(changed, "plain").ok, "Unowned actor cannot enter factory")
	changed = s._detached_persistent_state(); changed.party_roster.append("shen")
	check(not TrialFactory.build(changed, "plain").ok, "Duplicate roster rejected")

func _test_trial_default_parity(s) -> void:
	check(not legacy_model_path.is_empty(), "Pinned old model required for full default parity")
	if legacy_model_path.is_empty(): return
	var old_script = load(legacy_model_path)
	check(old_script != null, "Retained old automatic source loads")
	if old_script == null: return
	for count: int in [1, 4]:
		check(s.set_party_roster(["hero"] if count == 1 else ["hero", "shen", "tang", "qin"]), "Parity authentic roster")
		var built: Dictionary = Catalog.build_team(s, s.party_roster)
		for encounter: String in Rules.ENCOUNTER_IDS:
			for policy: bool in [false, true]:
				var old_model = old_script.new(); var current = Rules.new()
				check(old_model.configure(built.team, encounter) and current.configure(built.team, encounter), "Original encounter configures both pinned/current")
				_compare_fights(old_model, current, policy, encounter + "/" + str(count))
		# Borrowed plain ordinary must retain the entire old virtual combat.
		var original = old_script.new()
		check(original.configure(built.team, "courtyard_practice"), "Original ordinary configures")
		_compare_fights(original, _new_trial(s), true, "ordinary borrowed plain")

func _compare_fights(left, right, policy: bool, label: String) -> void:
	check(_semantic(left.snapshot()) == _semantic(right.snapshot()), "Exact original actors/enemies/intents " + label)
	var steps: int = 0
	var stream: Array = []
	while left.snapshot().active and steps < 600:
		var a: String = _plan(left) if policy else ""
		var b: String = _plan(right) if policy else ""
		check(a == b, "Exact original policy choice")
		var ta: Dictionary; var tb: Dictionary
		if a.is_empty(): ta = left.advance(); tb = right.advance()
		else:
			left.select_actor(a); right.select_actor(b)
			ta = left.accept_action("item"); tb = right.accept_action("item")
		check(ta.accepted and tb.accepted, "Both old/current transactions accepted")
		if not ta.accepted or not tb.accepted: break
		check(_semantic(ta) == _semantic(tb), "Full original before/after/events semantic parity " + label)
		stream.append(_semantic(ta))
		check(left.complete_presentation(ta.token) and right.complete_presentation(tb.token), "Both exact tokens complete")
		steps += 1
	check(not left.snapshot().active and not right.snapshot().active, "Parity fights terminate")
	fitting_rows.append({"label": label, "policy": policy, "transactions": steps, "transcript_sha256": JSON.stringify(stream).sha256_text(), "outcome": left.snapshot().outcome})

func _semantic(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			if key not in ["epoch", "token", "pending_token", "fitting_trial"]:
				result[key] = _semantic(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry: Variant in value: result.append(_semantic(entry))
		return result
	return value

func _frozen_tree(value: Variant) -> bool:
	if value is Object: return false
	if value is Dictionary:
		if not value.is_read_only(): return false
		for entry: Variant in value.values():
			if not _frozen_tree(entry): return false
	if value is Array:
		if not value.is_read_only(): return false
		for entry: Variant in value:
			if not _frozen_tree(entry): return false
	return true

func _finish_fitting(suite: String) -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			var file: FileAccess = FileAccess.open(argument.trim_prefix("--output="), FileAccess.WRITE)
			check(file != null, "Trial report opens")
			if file != null:
				file.store_string(JSON.stringify({"checks": checks, "failures": failures, "suite": suite, "rows": fitting_rows, "scope": "Source-only model/profile/metrics. No native UI, publication, or full regression claim."}, "\t")); file.close()
	print("%s: %d weapon fitting trial %s checks; %d rows" % ["PASS" if failures == 0 else "FAIL", checks, suite, fitting_rows.size()])
	quit(0 if failures == 0 else 1)
