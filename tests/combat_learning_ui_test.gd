extends "res://tests/audit_second_region_test.gd"
func _run()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.state=AuditState.new();game._new_game()
 game.state.quest_stage=6;game.state.ending="守望";game.state.choose_sect("问石门");game.state.gain_xp(180)
 game.world.teleport(game.world.interactables.mentor.pos);game._process(0)
 await _key(KEY_E);_press("内功与轻身");_press("内功 · 调息归元")
 _check(_modal_text().contains("消耗2") and _modal_text().contains("16") and _modal_text().contains("不会替代自动普攻"),"Lesson explains real cost/effect and separate automatic basic")
 var stale=game.modal_actions[0];await _key(KEY_ESCAPE);stale.call()
 _check(not game.state.internal_unlocked,"Cancelled lesson cannot grant internal")
 await _key(KEY_E);_press("内功与轻身");_press("内功 · 调息归元")
 var moved=game.modal_actions[0];game.world.teleport(Vector2(420,450));moved.call()
 _check(not game.state.internal_unlocked,"Distant lesson callback cannot grant internal")
 game._close_modal();game.world.teleport(game.world.interactables.mentor.pos);game._process(0)
 await _key(KEY_E);_press("内功与轻身");_press("内功 · 调息归元")
 var coins=game.state.coins;_press("修习调息归元 · 免费")
 _check(game.state.internal_unlocked and game.state.coins==coins,"Explicit native menu teaching is free")
 game._load();_check(game.state.internal_unlocked,"Learned internal persists by normal save/load")
 await _key(KEY_E);_press("内功与轻身");_press("轻功 · 踏苇行")
 _check(_modal_text().contains("少受10点") and _modal_text().contains("来回不耗"),"One learned lightness explains combat cost separately from traversal")
 _press("修习踏苇行");_check(game.state.lightness_unlocked,"Independent lightness lesson still works")
 game._stop_audio();game.queue_free();await process_frame
 if failures==0:print("PASS: %d explicit internal/lightness menu/save/cancel checks"%checks)
 quit(0 if failures==0 else 1)
