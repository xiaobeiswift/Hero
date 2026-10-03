extends "res://tests/audit_second_region_test.gd"
class MistAuditState extends AuditState:
 var writes:int=0
 func save_game(path:String=SAVE_PATH)->Error:
  writes+=1
  return super.save_game(path)
func _run()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 await process_frame
 game.state=MistAuditState.new()
 for route in ["duel","repair","records"]:await _route(route)
 game._stop_audio();await create_timer(0.25).timeout;game.queue_free();await process_frame
 if failures==0:print("PASS: %d mistwood scene checks" % checks)
 else:push_error("FAIL: %d of %d mistwood scene checks" % [failures,checks])
 quit(0 if failures==0 else 1)
func _prepare(route:String)->void:
 game._new_game();game.state.quest_stage=6;game.state.ending="守望";game.state.choose_sect("问石门");game.state.gain_xp(600);game.state.equip_art(game.state.sect_art())
 game.state.side_stage=3;game.state.side_choice="rescue";game.state.side_reward_claimed=true;game.state.side_clues=2;game.state.side_found.assign(["boatman","ledger"])
 game.state.chapter_two_stage=4;game.state.chapter_two_ending="open_records" if route=="records" else "protect_witness";game.state.archive_clues.assign(["clerk","inscription"]);game.state.seal_sequence.assign([2,0,1])
 game._travel("frostbridge",Vector2(1450,220));game._refresh()
func _talk(id:String)->void:
 if game.active_modal:game._close_modal()
 game.world.teleport(game.world.interactables[id].pos);game._process(0)
 await _key(KEY_E)
 _check(game.active_modal or (id=="return_frostbridge" and game.world.map_id=="frostbridge"),"Real E handles "+id)
func _battle_win()->void:
 for i in range(120):
  if not game.state.battle_active:break
  UnifiedDriver.step(game)
 _check(not game.state.battle_active and game.state.party_settlement.get("outcome")=="win","Actual phased encounter is winnable")
func _route(route:String)->void:
 _prepare(route)
 game.state.chapter_two_stage=3
 await _talk("exit_mistwood")
 _check(_find_button(game.overlay,"走入雾竹坡")==null,"Unresolved prior chapter cannot open new route")
 game._close_modal();game.state.chapter_two_stage=4
 await _talk("exit_mistwood");await _key(KEY_ENTER)
 _check(game.state.map_id=="mistwood" and game.world.map_id=="mistwood" and game.state.mist_stage==1,"Entrance starts third chapter and switches real region")
 _check(game.region_header.text.contains("雾竹坡") and game.chapter_header.text.contains("第三章"),"Region heading reflects fourth map and third chapter")
 await _key(KEY_M)
 var chart=_find_chart(game.overlay)
 _check(chart!=null and chart.map_id=="mistwood" and chart.markers.size()==9,"Map uses new geography and all chapter landmarks and downstream exit")
 _check(chart.current_target=="mist_rain_gauge","Initial world/map target points to rain gauge")
 await _key(KEY_ESCAPE)
 await _talk("mist_stone_gauge")
 _check(_find_button(game.overlay,"拓下读数")==null,"Stone reading remains gated before permit")
 game._close_modal()
 for id in ["mist_rain_gauge","mist_basin"]:
  await _talk(id);await _key(KEY_1)
 _check(game.state.mist_gauges.size()==2,"Actual two outer readings recorded")
 game._load()
 _check(game.state.mist_gauges.size()==2 and game.world.map_id=="mistwood","Readings and map survive immediate reload")
 game._process(0);_check(game.world._quest_target_id()=="mist_scout","Current objective moves to patrol")
 await _talk("mist_scout")
 if route=="duel":
  await _key(KEY_1)
  _check(game.current_screen=="party_battle" and game.overlay.get_meta("party_battle").commands.context.location.contains("雾竹"),"Patrol opens correct battle scene")
  UnifiedDriver.leave(game)
  _check(game.state.mist_approach.is_empty(),"Flee preserves unresolved access")
  await _talk("mist_camp");await _key(KEY_1)
  await _talk("mist_scout");await _key(KEY_1);_battle_win()
  await _key(KEY_ESCAPE);game._load()
 elif route=="repair":
  var before=game.state.to_dict()
  await _key(KEY_2)
  _check(game.state.to_dict()==before and game.active_modal,"Failed material offer has no partial cost")
  game.state.buy_material("timber");game.state.buy_material("cloth")
  await _key(KEY_2)
  _check(game.state.resources.timber==0 and game.state.resources.cloth==0,"Repair consumes bought materials exactly once")
 else:
  await _key(KEY_3)
 _check(game.state.mist_approach==route,"Chosen access route persisted: "+route)
 game._load()
 _check(game.state.mist_approach==route,"Every approach survives save/load")
 var before=game.state.to_dict()
 await _talk("mist_scout")
 _check(_find_button(game.overlay,"较量过关")==null and game.state.to_dict()==before,"Completed patrol cannot be repeated for rewards")
 game._close_modal();await _talk("mist_stone_gauge");await _key(KEY_1)
 _check(game.state.mist_stage==2 and game.state.mist_gauges.size()==3,"Final reading unlocks gate")
 game._load();game._process(0)
 _check(game.world._quest_target_id()=="mist_gate","Gate is targeted after restored readings")
 await _talk("mist_camp");await _key(KEY_1)
 _check(game.state.hp==game.state.max_hp and game.state.qi==game.state.max_qi,"Camp offers genuine free recovery")
 await _talk("mist_gate");await _key(KEY_1)
 var panel=game.overlay.get_meta("party_battle")
 panel.set_process(false);panel.art.set_process(false)
 var view=game.state.party_battle_snapshot()
 _check(view.enemy_intents[0].guarded and panel.unit_plates.mist_keeper.tooltip_text.contains("减半"),"Guarded phase explicitly advertised")
 var enemy_hp=int(view.enemies[0].hp)
 var attack=UnifiedDriver.step(game,false)
 _check(attack.action_id=="attack" and enemy_hp-int(game.state.party_battle_snapshot().enemies[0].hp)==int(ceil(game.state.attack*0.5)),"Real first-phase automatic damage halved")
 UnifiedDriver.step(game,false) # First announced enemy action completes round1.
 _check(game.state.party_battle_snapshot().enemy_intents[0].heavy and panel.unit_plates.mist_keeper.tooltip_text.contains("重击"),"Next phase updates heavy intent")
 await _key(KEY_1) # Slot1 is martial; guard comes only from owned磐石回锋.
 var guard=UnifiedDriver.step(game,false)
 _check(guard.action_id=="art:磐石回锋" and _hero().status.guard,"Queued defensive martial establishes real guard")
 UnifiedDriver.step(game,false) # Automatic basic remains entitled.
 UnifiedDriver.step(game,false) # Actual heavy strike lands against that guard.
 _check(_hero().status.vulnerability_hits==0 and panel.unit_plates.mist_keeper.tooltip_text.contains("+8"),"Defending heavy exposes recovery opportunity")
 enemy_hp=int(game.state.party_battle_snapshot().enemies[0].hp)
 attack=UnifiedDriver.step(game,false)
 _check(attack.action_id=="attack" and enemy_hp-int(game.state.party_battle_snapshot().enemies[0].hp)==game.state.attack+8,"Recovery adds damage in actual automatic scene action")
 UnifiedDriver.leave(game);game._close_modal();game._load()
 _check(game.state.mist_stage==2,"Flee and reload preserve gate retry")
 await _talk("mist_camp");await _key(KEY_1)
 await _talk("mist_gate");await _key(KEY_1);_battle_win()
 _check(game.state.mist_stage==3 and _modal_text().contains("底稿"),"Keeper victory advances story and displays evidence")
 await _key(KEY_ESCAPE);game._load()
 _check(game.state.mist_stage==3,"Escape from victory autosaves evidence")
 await _talk("mist_guide")
 var coins=game.state.coins
 await _key(KEY_2 if route=="repair" else KEY_1)
 _check(game.state.mist_stage==4 and game.state.coins==coins+60,"Guide finale grants one-time chapter reward")
 var ending="warn_ferries" if route=="repair" else "release_water"
 _check(game.state.mist_ending==ending,"Both water choices persist distinctly")
 before=game.state.to_dict();await _talk("mist_guide")
 _check(_find_button(game.overlay,"先通缓水渠")==null and game.state.to_dict()==before,"Repeated finale cannot grant rewards")
 game._close_modal();var journal_before:Dictionary=game.state.to_dict().duplicate(true);var journal_save_bytes:PackedByteArray=FileAccess.get_file_as_bytes(AuditState.AUDIT_PATH);var journal_writes:int=game.state.writes;await _key(KEY_J)
 var journal=game.overlay.get_meta("journal_ui",null)
 _check(is_instance_valid(journal),"Completed Mist has a real earned journal owner")
 journal.action_buttons.history.pressed.emit();await process_frame
 _check(journal.page=="history" and journal.body.is_visible_in_tree() and journal.body.scroll_active,"Actual History control exposes visible scrollable Mist ending")
 var mist_row:Dictionary={}
 for row:Dictionary in journal._catalog:
  if row.id=="mistwood":mist_row=row
 _check(game.state.mist_stage==4 and not mist_row.is_empty() and mist_row.display_title=="竹坡余声" and mist_row.status=="completed" and not mist_row.trackable,"Actual Mist row has its frozen stage4 title and cannot retrack completed work")
 # Old aggregate 听雨辨令 maps to frozen stage4 竹坡余声; the chosen ending literal is unchanged.
 _check(journal.body.text.contains("竹坡余声 · 已完成\n") and journal.body.text.contains("先鸣渡船钟" if ending=="warn_ferries" else "先通缓水渠"),"Journal preserves chapter and ending")
 await _key(KEY_ESCAPE)
 _check(game.active_modal and journal.page=="journal","History Escape returns to Mist J owner")
 await _key(KEY_ESCAPE)
 _check(not game.active_modal and not game.overlay.has_meta("journal_ui"),"Second Escape closes Mist history browsing completely")
 _check(game.state.to_dict()==journal_before and FileAccess.get_file_as_bytes(AuditState.AUDIT_PATH)==journal_save_bytes and game.state.writes==journal_writes,"Complete Mist history flow preserves exact canonical state, isolated save bytes and write count")
 game.state.position=Vector2(277,242);game.state.save_game();game._load()
 _check(game.world._can_walk(game.world.player_pos),"Loading pond coordinate repairs unsafe position")
 await _talk("return_frostbridge")
 _check(game.world.map_id=="frostbridge" and game.state.mist_stage==4,"Return exit preserves chapter completion")
