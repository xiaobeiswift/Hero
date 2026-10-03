extends "res://tests/automatic_party_battle_art_test.gd"
## Phase2 replaces the historical negative art-readiness gate with positive12
## coverage and retains the before-autosave rejection of unknown registrations.
const UI = preload("res://scripts/party_battle_ui.gd")
class ProbeState extends RefCounted:
 var battle_active = false
 func start_party_battle(_id:String)->bool:return false
class ProbeOwner extends RefCounted:
 var current_screen = "explore"
 var quit_pending = false
 var state = ProbeState.new()
 var save_warning = false
 var writes = 0
 func _autosave()->void:writes+=1
func run()->void:
 check(PhaseOneBoundary.READY_IDS==Rules.ENCOUNTER_IDS,"All twelve models have explicit scene/art coverage")
 for id:String in PhaseOneBoundary.READY_IDS:
  check(Rules.ENCOUNTER_IDS.has(id) and UI.ENCOUNTER_TITLES.has(id),"Model/scene registration present: "+id)
 check(Art.IDS.has("liang_zhen"),"Original Liang renderer registered")
 var owner=ProbeOwner.new()
 check(UI.open(owner,"unregistered_capstone")==null and owner.writes==0 and not owner.state.battle_active,"Unknown scene rejects before autosave or controller entry")
 art=Art.new();root.add_child(art);await process_frame;art.set_process(false)
 var rules=model(PhaseOneBoundary.CAPSTONE_ID,4)
 var snapshot=rules.snapshot()
 check(snapshot.enemies.size()==1 and snapshot.enemies[0].id=="liang_zhen","Actual new model identity is sole Liang")
 art.set_snapshot(snapshot)
 check(art.display_snapshot==snapshot,"Renderer accepts exact Liang facts")
 var tx=rules.advance()
 check(tx.get("accepted",false) and art.present(tx) and art.is_presenting(),"Exact accepted model transaction has original presentation")
 advance(art.get_presentation_duration()+.1)
 check(not art.is_presenting(),"Original presentation reaches a real terminal boundary")
 check(rules.complete_presentation(tx.token) and not rules.complete_presentation(tx.token),"Detached driver acknowledges exact token once")
 art.queue_free();await process_frame
 print("%s: %d capstone positive presentation/registration checks; physical scene input tested separately"%["PASS" if failures==0 else "FAIL",checks])
 quit(0 if failures==0 else 1)
