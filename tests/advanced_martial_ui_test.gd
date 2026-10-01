extends "res://tests/audit_second_region_test.gd"
class FailState extends AuditState:
 var fail_write=false
 func save_game(path:String=SAVE_PATH)->Error:
  return ERR_CANT_CREATE if fail_write else super.save_game(path)
func _run()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 await process_frame
 game.state=AuditState.new()
 for school in ["听潮阁","照野堂","问石门"]:await _school_flow(school)
 await _failure_flow()
 game._stop_audio();await create_timer(0.25).timeout;game.queue_free();await process_frame
 if failures==0:print("PASS: %d advanced martial UI checks" % checks)
 else:push_error("FAIL: %d of %d advanced martial UI checks" % [failures,checks])
 quit(0 if failures==0 else 1)
func _prepare_school(school:String)->void:
 game._new_game();game.state.gain_xp(180);game.state.choose_sect(school);game.state.quest_stage=6;game.state.ending="守望"
 game.state.sect_trial_won=true;game.state.complete_sect_trial()
 game.state.side_stage=3;game.state.side_choice="rescue";game.state.side_reward_claimed=true;game.state.side_clues=2;game.state.side_found.assign(["boatman","ledger"])
 game.state.chapter_two_stage=4;game.state.chapter_two_ending="protect_witness";game.state.archive_clues.assign(["clerk","inscription"]);game.state.seal_sequence.assign([2,0,1])
 game.world.teleport(Vector2(650,720));game._refresh()
func _school_flow(school:String)->void:
 _prepare_school(school)
 var arts=game.state.school_art_ids()
 _check(arts.size()==4 and game.state.available_arts().size()==2,"School browse includes locked arts without gifting them")
 var cheap=arts[2];var costly=arts[3]
 await _key(KEY_E)
 _check(_find_button(game.overlay,"研习藏页")!=null,"Native mentor interaction opens inner-disciple services")
 await _key(KEY_1)
 _check(_modal_text().contains(cheap) and _modal_text().contains(costly),"Both exact school pages visible")
 var original=game.state.equipped_art
 await _key(KEY_1)
 _check(game.state.learned_arts.is_empty(),"Browsing detail is not a purchase")
 await _key(KEY_ENTER)
 _check(game.state.learned_arts.has(cheap) and game.state.sect_merit==1,"Learning charges correct2merit")
 _check(game.state.equipped_art==original,"Learning never silently equips")
 var before=game.state.to_dict()
 game.advanced_martial.learn(cheap)
 _check(game.state.to_dict()==before,"Stale repeat learning callback cannot charge twice")
 game.advanced_martial.learn(costly)
 _check(game.state.to_dict()==before,"Insufficient merit leaves state unchanged")
 await _key(KEY_ESCAPE);game._load()
 _check(game.state.learned_arts.has(cheap) and game.state.sect_merit==1,"Escape/reload preserves learned art and balance")
 game._interact("mentor");_press("江湖复命")
 _check(_modal_text().contains("可领取1考绩"),"Existing completed stories become eligible deed awards")
 _press("复命·废闸水令查证")
 _check(game.state.sect_merit==2 and game.state.claimed_deeds.has("sluice"),"First deed awards exactly1")
 _press("复命·霜桥原账归处")
 _check(game.state.sect_merit==3 and game.state.claimed_deeds.size()==2,"Second deed awards exactly1")
 before=game.state.to_dict();game.advanced_martial.claim("archive")
 _check(game.state.to_dict()==before,"Stale duplicate deed callback is replay-safe")
 _press("返回藏页");await _key(KEY_2);await _key(KEY_ENTER)
 _check(game.state.learned_arts.size()==2 and game.state.sect_merit==0,"Five total merit unlocks both school pages")
 _check(game.state.equipped_art==original,"Second learning also preserves equipped move")
 await _key(KEY_ESCAPE);await _key(KEY_K)
 _check(game.modal_actions.size()==5,"All four learned moves plusReturn fit five keyboard choices")
 await _key(KEY_4)
 _check(game.state.equipped_art==costly and not game.active_modal,"Fourth martial key equips advanced focus move")
 game.state.heal_rest();game._start_battle("spar");game.state.enemy_max_hp=1000;game.state.enemy_hp=1000
 await _key(KEY_2)
 _check(game.state.focused_damage>0 and game.battle_status.text.contains("蓄锋"),"Real battle shows stored focus amount")
 var focus=game.state.focused_damage
 _check(game.battle_status.text.contains(str(focus)),"Displayed focus equals model amount")
 var qi=game.state.qi
 await _key(KEY_K);game.advanced_martial.learning()
 _check(not game.active_modal and game.state.qi==qi,"Battle blocks martial/learning menus")
 await _key(KEY_1)
 _check(game.state.focused_damage==0 and not game.battle_status.text.contains("蓄锋"),"Actual basic attack consumes and removes focus label")
 game._battle_action("flee");game._close_modal()
 game.state.equip_art(cheap);game.state.heal_rest();game._start_battle("spar");game.state.enemy_max_hp=1000;game.state.enemy_hp=1000
 await _key(KEY_2)
 _check(game.state.enemy_weaken_strikes==1 and game.battle_status.text.contains("卸劲"),"Skill immediately affects first incoming strike and shows remaining one")
 _check(game.battle_status.text.contains(str(game.state.enemy_weaken_amount)),"Displayed weaken magnitude matches rules")
 await _key(KEY_3)
 _check(game.state.enemy_weaken_strikes==0 and not game.battle_status.text.contains("卸劲"),"Next incoming strike consumes final weaken and clears label")
 game._battle_action("flee");game._close_modal();game._save();before=game.state.to_dict();game._load()
 _check(game.state.to_dict()==before,"Learned arts,deeds,equipped art and balances round-trip after real combats")
func _failure_flow()->void:
 game.state=FailState.new();_prepare_school("听潮阁")
 var id=game.state.school_art_ids()[2]
 game.state.fail_write=true
 game.advanced_martial.learning();game.advanced_martial.learn(id)
 _check(game.state.learned_arts.has(id) and game.state.sect_merit==1,"Failed disk save does not rerun or undo in-memory purchase")
 _check(game.save_warning and game.status_label.text.contains("存档失败"),"Learning success toast retains save-failure warning")
 game._close_modal();game.state.fail_write=false;game._save()
 _check(not game.save_warning,"Successful save retry clears warning")
 game._load()
 _check(game.state.learned_arts.has(id) and game.state.sect_merit==1,"Retry persists exact purchase without charging again")
