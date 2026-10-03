extends "res://tests/automatic_party_battle_art_test.gd"
## Existing scheduler/actor geometry across contextual background selection.
## Consignee is model-only: explicitly reject unsupported presentation IDs.
const Scenery=preload("res://scripts/party_battle_backdrop.gd")
const Encounters=preload("res://scripts/unified_encounter_rules.gd")
func run()->void:
 art=Art.new();root.add_child(art);await process_frame;art.set_process(false)
 ground=PackedVector2Array([art.ground_point(0,0),art.ground_point(1,0),art.ground_point(1,1),art.ground_point(0,1)])
 check(Scenery.style_for("unrecognized")=="ferry","Unknown visual key cannot select a special gameplay context")
 for encounter:String in Encounters.IDS:
  var style="courtyard" if encounter in ["training","sect_trial","courtyard_practice"] else "ferry"
  for count:int in [1,2,3,4]:
   for form:String in ["并肩","护后"]:
    var rules=model(encounter,count,form)
    var before=rules.snapshot()
    if encounter == "heting_consignee":
     # Keep all ten shipped presentation routes intact. This is a safe
     # unsupported-ID boundary check, not new chapter visual acceptance.
     var probe=Art.new()
     probe.set_snapshot(before)
     check(probe.display_snapshot.is_empty(),"Phase-one enemy IDs do not fabricate supported art")
     var tx=rules.advance()
     check(tx.get("accepted",false),"Actual phase-one scheduler still accepts action")
     var resolved=rules.snapshot()
     check(not probe.present(tx) and not probe.is_presenting(),"Unsupported chapter presentation fails closed")
     check(rules.snapshot()==resolved,"Rejected art does not mutate prepared model")
     check(rules.complete_presentation(tx.token),"Model owner can acknowledge phase-one transaction")
     probe.free()
     continue
    art.set_snapshot(before)
    check(art.backdrop_style==style and Scenery.style_for(encounter)==style,"Actual renderer context: "+encounter)
    geometry("%s/%d/%s/idle"%[encounter,count,form])
    var transaction:Dictionary=rules.advance()
    check(transaction.ok and transaction.accepted,"Same actual automatic first action")
    var resolved=rules.snapshot().duplicate(true)
    check(art.present(transaction),"Shared presentation accepts the same transaction")
    advance(.40);geometry("%s/%d/%s/contact"%[encounter,count,form])
    advance(art.get_presentation_duration()+.1)
    check(not art.is_presenting() and art.backdrop_style==style,"Context persists through return")
    geometry("%s/%d/%s/return"%[encounter,count,form])
    check(rules.snapshot()==resolved,"Painting cannot alter accepted game facts")
    check(rules.complete_presentation(transaction.token),"Host still owns exactly one presentation acknowledgment")
    check(not rules.complete_presentation(transaction.token),"Background draw does not admit repeated acknowledgment")
    art.reset_presentation()
 art.queue_free();await process_frame
 print("%s: %d contextual background/shared scheduler checks: ten rendered encounters plus phase-one consignee rejection,1–4 actors,both formations"%["PASS" if failures==0 else "FAIL",checks])
 quit(0 if failures==0 else 1)
