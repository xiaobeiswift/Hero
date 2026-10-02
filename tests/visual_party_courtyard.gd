extends "res://tests/unified_combat_ui_test.gd"
## Prepared full-game source, actual shared controller and scripted safe pause.
var captured:Array[String]=[]
func _capture(name:String)->void:
 await process_frame;await RenderingServer.frame_post_draw
 var image=root.get_texture().get_image()
 check(image.get_width()==root.size.x and abs(image.get_height()-root.size.y)<=1,"Native aspect-rounded framebuffer")
 check(image.save_png("res://screenshots/"+name+".png")==OK,"Write actual framebuffer")
 captured.append(name);print("FRAME ",name," ",image.get_width(),"x",image.get_height())
func _run()->void:
 if OS.get_environment("XDG_DATA_HOME").is_empty():quit(2);return
 fixture="user://courtyard-scenery-%d"%OS.get_process_id();DirAccess.make_dir_recursive_absolute(fixture)
 s=State.new();s.fixture=fixture
 app=load("res://scenes/main.tscn").instantiate();app.set_script(CloseProbe);app.state=s
 root.add_child(app);await process_frame;app._stop_audio();app.audio_on=false;app.world.set_process(false)
 root.size=Vector2i(1280,800)
 var index=336
 for kind:String in ["training","sect_trial","courtyard_practice","heting_receipt"]:
  _setup(kind,4);s.learn_internal_skill();s.learn_lightness()
  check(app._start_unified_battle(kind),"Same shared entry "+kind)
  var panel=app.overlay.get_meta("party_battle")
  panel.set_process(false);panel.art.set_process(false);panel.set_pause_request(true)
  check(panel.commands.groups.size()==4,"Four actual occupied groups")
  await _capture("%d-context-%s"%[index,kind]);index+=1
  if kind=="courtyard_practice":
   root.size=Vector2i(1179,737);await process_frame;panel.refresh()
   await _capture("340-context-practice-compact")
   root.size=Vector2i(1280,800);await process_frame;panel.refresh()
   panel.set_pause_request(false);panel._process(.5)
   check(panel.pending.action_id=="attack" and panel.pending.source_id=="hero","Actual automatic basic unchanged")
   panel.art._process(.40);panel.refresh();await _capture("341-context-practice-contact");_finish(panel)
  panel.leave();_finish(panel);await process_frame
 app._stop_audio();app.queue_free();await process_frame
 print("%s: %d court/ferry native frames; prepared source, fixed presentation times, no browser/audio/FPS claim"%["PASS" if failures==0 else "FAIL",captured.size()])
 quit(0 if failures==0 else 1)
