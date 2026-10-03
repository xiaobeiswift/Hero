extends SceneTree
## Actual existing HUD/folio nodes, without adding any fitting controls.
## Synthetic programmatic state setup; this is not native-input/pixel acceptance.
const Scene = preload("res://scenes/main.tscn")
const State = preload("res://scripts/game_state.gd")
const Advanced = preload("res://scripts/advanced_martial_rules.gd")
const Fittings = preload("res://scripts/weapon_fitting_rules.gd")
var checks: int = 0
var failures: int = 0
var app

class NoSave extends State:
	func save_game(_path: String = SAVE_PATH) -> Error: return OK
	func has_save() -> bool: return false

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)

func _texts(node: Node) -> String:
	var result: String = node.text if node is Label or node is RichTextLabel else ""
	for child: Node in node.get_children(): result += _texts(child)
	return result

func run() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): quit(2); return
	app = Scene.instantiate(); app.state = NoSave.new(); root.add_child(app)
	await process_frame
	app._new_game(); app._stop_audio(); app.audio_on = false
	for sect: String in State.SECTS:
		app._new_game(); app.state.quest_stage = 6; app.state.ending = "守望"; app.state.choose_sect(sect)
		app.state.sect_rank = 2; app.state.sect_trial_won = true; app.state.sect_merit = 5
		var arts: Array = app.state.school_art_ids()
		check(app.state.learn_art(arts[2]) and app.state.learn_art(arts[3]), "Owned advanced arts for truthful display")
		for fitting: String in Fittings.IDS:
			check(app.state.set_weapon_fitting(fitting).ok, "Explicit model selection for read-consumer test")
			var power: int = app.state.effective_attack(); var defense: int = app.state.effective_defense()
			app._refresh()
			check(app.stat_label.text.contains("攻击 %d" % power) and app.stat_label.text.contains("防御 %d" % defense), "Live HUD agrees with effective model stats")
			var before: Dictionary = app.state.to_dict()
			app._show_inventory()
			var text: String = _texts(app.overlay)
			check(text.contains("攻击 %d" % power) and text.contains("防御 %d" % defense) and text.contains(app.state.equipment), "Inventory shows effective stats and actual sword name")
			check(app.state.to_dict() == before, "Inventory read does not equip or mutate")
			app._close_modal(); app._show_martials()
			for id: String in arts:
				var art: Dictionary = State.Arts.definition(id)
				var card = app.overlay.find_child("ArtCard_" + id, true, false)
				check(card != null, "Real martial folio card exists")
				if card == null: continue
				var expected_damage: int = Advanced.direct_damage(art, power, app.state.art_rank(id))
				var expected_focus: int = Advanced.focus_damage(art, power)
				var effects: String = card.find_child("ArtEffects", true, false).text
				check(effects.contains("基础伤害 %d" % expected_damage), "Folio damage agrees with effective attack")
				if expected_focus > 0: check(effects.contains("下次平击 +%d" % expected_focus), "Folio focus agrees with effective attack")
				var summary: String = app.advanced_martial.summary(id)
				check(summary.contains("伤%d" % expected_damage), "Advanced summary damage agrees with effective attack")
				if expected_focus > 0: check(summary.contains("蓄锋+%d" % expected_focus), "Advanced summary focus agrees with effective attack")
			check(app.state.to_dict() == before, "All folio/summary readers preserve persistent state")
			app._close_modal()
	app._stop_audio(); app.queue_free(); await create_timer(0.25).timeout
	if failures == 0: print("PASS: %d fitted HUD/inventory/martial/advanced-summary read-consumer checks; synthetic scene nodes, no new controls or native-input claim" % checks)
	quit(0 if failures == 0 else 1)
