extends "res://tests/automatic_party_battle_art_test.gd"
## Explicit phase-one readiness gate. Model acceptance is not scene/art acceptance.
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
 check(PhaseOneBoundary.READY_IDS.size()==11,"All eleven shipped scenes remain explicit positive scope")
 for id:String in PhaseOneBoundary.READY_IDS:
  check(Rules.ENCOUNTER_IDS.has(id) and UI.ENCOUNTER_TITLES.has(id),"Shipped model/scene registration stays present: "+id)
 check(Rules.ENCOUNTER_IDS.has(PhaseOneBoundary.MODEL_ONLY_ID),"New model really exists")
 check(not UI.ENCOUNTER_TITLES.has(PhaseOneBoundary.MODEL_ONLY_ID) and not Art.IDS.has("liang_zhen"),"No fake scene title or reused named-boss art is accepted")
 var owner=ProbeOwner.new()
 check(UI.open(owner,PhaseOneBoundary.MODEL_ONLY_ID)==null and owner.writes==0 and not owner.state.battle_active,"Unready scene rejects before autosave or controller entry")
 art=Art.new();root.add_child(art);await process_frame;art.set_process(false)
 var rules=model(PhaseOneBoundary.MODEL_ONLY_ID,4)
 var snapshot=rules.snapshot()
 check(snapshot.enemies.size()==1 and snapshot.enemies[0].id=="liang_zhen","Actual detached new model identity")
 art.set_snapshot(snapshot)
 check(art.display_snapshot.is_empty(),"Renderer refuses unintegrated original character instead of impersonating old boss")
 var tx=rules.advance()
 check(tx.get("accepted",false) and not art.present(tx) and not art.is_presenting(),"Accepted model transaction is not falsely rendered")
 check(rules.complete_presentation(tx.token),"Detached test driver releases its accepted model token")
 art.queue_free();await process_frame
 print("%s: %d capstone model-only presentation boundary checks; shipped11 positive suites remain separate"%["PASS" if failures==0 else "FAIL",checks])
 quit(0 if failures==0 else 1)
