extends "res://tests/unified_combat_ui_test.gd"
var captures:Array[String]=[]
func _capture(name:String)->void:
 await process_frame;await RenderingServer.frame_post_draw
 var image=root.get_texture().get_image()
 check(image.get_width()==root.size.x and abs(image.get_height()-root.size.y)<=1,"Native framebuffer fits window within one aspect-rounded pixel")
 print("FRAME ",name," ",image.get_width(),"x",image.get_height())
 var path="res://screenshots/"+name+".png"
 check(image.save_png(path)==OK,"Write actual engine framebuffer")
 captures.append(path)
func _run()->void:
 if OS.get_environment("XDG_DATA_HOME").is_empty():quit(2);return
 fixture="user://unified-native-%d"%OS.get_process_id();DirAccess.make_dir_recursive_absolute(fixture)
 s=State.new();s.fixture=fixture
 app=load("res://scenes/main.tscn").instantiate();app.set_script(CloseProbe);app.state=s
 root.add_child(app);await process_frame;app._stop_audio();app.audio_on=false;app.world.set_process(false)
 root.size=Vector2i(1280,800)
 var index=320
 for kind:String in Encounters.IDS:
  var count=4 if kind in ["training","courtyard_practice","heting_receipt"] else (3 if kind.begins_with("mist_") else 2)
  _setup(kind,count)
  if kind!="story":s.learn_internal_skill();s.learn_lightness()
  check(app._start_unified_battle(kind),"Actual shared entry "+kind)
  var panel=app.overlay.get_meta("party_battle")
  panel.set_process(false);panel.art.set_process(false);panel.set_pause_request(true)
  check(panel.commands.groups.size()==count,"Only actual occupied groups")
  await _capture("%d-unified-%s"%[index,kind]);index+=1
  panel.leave();_finish(panel);await process_frame
 _setup("heting_receipt",4);s.learn_internal_skill();s.learn_lightness()
 check(app._start_unified_battle("heting_receipt"),"Four-party actual shared reentry")
 var panel=app.overlay.get_meta("party_battle");panel.set_process(false);panel.art.set_process(false)
 panel.set_pause_request(true);panel.select_actor("tang");panel.commands.request_slot("tang",2)
 check(_actor(s.party_battle_snapshot(),"tang").categories.lightness.queued,"Actual lightness queue")
 panel.select_actor("qin");panel.commands.request_slot("qin",0);panel.select_target("hero")
 check(_actor(s.party_battle_snapshot(),"qin").categories.martial.queued,"Actual exact ally queue")
 await _capture("330-unified-queued-skills")
 panel.set_pause_request(false);panel._process(.5)
 check(panel.pending.action_id=="attack" and panel.pending.source_id=="hero","Actual autonomous basic without command")
 panel.art._process(.40);panel.refresh()
 await _capture("331-unified-automatic-contact")
 _finish(panel)
 panel.commands.request_slot("hero",0)
 check(_actor(s.party_battle_snapshot(),"hero").categories.martial.queue_round==2,"Already-finished actor queues next round")
 panel.set_pause_request(true)
 root.size=Vector2i(1179,737);await process_frame;panel.refresh()
 await _capture("332-unified-compact-next-round")
 root.size=Vector2i(1280,800)
 panel.select_actor("tang");panel.commands.request_slot("tang",0);panel.set_pause_request(false)
 for wanted in ["lightness:tang_cunbu","art:tang_fenjin"]:
  for step in range(20):
   if panel.pending.is_empty():panel._process(.5)
   if not panel.pending.is_empty() and panel.pending.action_id==wanted:break
   _finish(panel)
  check(not panel.pending.is_empty() and panel.pending.action_id==wanted,"Actual queued category executes before same actor basic")
  panel.art._process(.52);panel.refresh()
  await _capture("333-unified-presented-focus" if wanted.begins_with("lightness") else "334-unified-presented-weaken")
  _finish(panel)
 await _capture("335-unified-weaken-after-return")
 panel.leave();_finish(panel);await process_frame
 app._stop_audio();app.queue_free();await process_frame
 if failures==0:print("PASS: %d actual shared-engine images; scripted entry/queue/input and fixed presentation time; prepared source, no browser/FPS/audio claim"%captures.size())
 quit(0 if failures==0 else 1)
