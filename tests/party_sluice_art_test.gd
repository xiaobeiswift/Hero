extends "res://tests/party_battle_art_test.gd"
## Existing original opponent atlas reused with distinct encounter IDs/tints.
## Prepared catalog geometry is not a claim of early four-person recruitment.
func run() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): quit(2); return
	art = Art.new(); art.size = Vector2(1280,800); root.add_child(art); art.set_process(false)
	art.presentation_finished.connect(func(): completions += 1)
	art.event_presented.connect(func(event: Dictionary): emitted.append({"event":event,"snapshot":art.display_snapshot,"time":art.action_time,"acting":art.acting_unit_id}))
	ground = PackedVector2Array([art.ground_point(0,0),art.ground_point(1,0),art.ground_point(1,1),art.ground_point(0,1)])
	for formation in ["护后","并肩"]:
		for count in [1,2,3,4]:
			for encounter in ["sluice_scout","sluice_boss"]:
				var value = team(formation)
				if count == 4: value.actors.append(Catalog._companion("qin",5))
				value.actors = value.actors.slice(0,count)
				var rules = Rules.new()
				check(rules.configure(value,encounter), "Prepared legal catalog geometry configures " + encounter)
				art.set_snapshot(rules.snapshot()); geometry(encounter+" idle "+str(count))
				check(art.actor_order().has(encounter) and not art.actor_order().has("puheng"), "Actual opponent ID remains distinct")
				check(art.target_at(art.target_anchor(encounter)) == encounter, "Enemy torso click resolves actual sluice actor")
				for round_index in range(2):
					var companions = rules.snapshot().actors.slice(1)
					for actor: Dictionary in companions:
						rules.select_actor(actor.id)
						await play(rules.accept_action("guard"),rules,false)
					rules.select_actor("hero")
					await play(rules.accept_action("attack"),rules,count==1 or count==4)
				if encounter == "sluice_boss" and formation == "护后":
					check(unit(art.display_snapshot,"hero").status.vulnerability_hits == 2, "Actual unguarded front actor has shown vulnerability")
					rules.select_actor("hero")
					await play(rules.accept_action("guard"),rules,false)
					check(unit(art.display_snapshot,"hero").status.vulnerability_hits == 0, "Guard event clears actual displayed status")
				await play(rules.accept_action("flee"),rules,false)
				for actor: Dictionary in art.display_snapshot.actors:
					check(actor.status.vulnerability_hits == 0, "Terminal displayed statuses clear")
	check(completions > 30, "Actual transaction completion exercised across legal roster sizes")
	art.queue_free(); await process_frame
	print("%s: %d sluice geometry/event checks; %d headless draw frames" % ["PASS" if failures == 0 else "FAIL",checks,frames])
	quit(0 if failures == 0 else 1)

func check_event_resources(expected: Dictionary, event: Dictionary, shown: Dictionary) -> void:
	super.check_event_resources(expected,event,shown)
	if String(event.type).begins_with("vulnerability_"):
		check(unit(shown,event.target_id).status.vulnerability_hits == event.remaining, "Vulnerability is shown only after its exact accepted fact")
