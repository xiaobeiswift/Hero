extends SceneTree
## Maintained phase-two contract test. Original phase-one bytes are retained in
## tests/historical with provenance. Prepared fixtures are not earned journeys.
## Expected policy comes from 117 pinned actual old observations, not current Main.
const State=preload("res://scripts/game_state.gd")
const Scene=preload("res://scenes/main.tscn")
const Prefs=preload("res://scripts/view_preferences.gd")
const Objectives=preload("res://scripts/journal_objective_rules.gd")
const Guidance=preload("res://scripts/journal_guidance_rules.gd")
const Session=preload("res://scripts/journal_guidance_session.gd")
const LateFixture=preload("res://tests/capstone_world_fixture.gd")
const Harbor=preload("res://scripts/heting_region.gd")
const Lightness=preload("res://scripts/lightness_rules.gd")
const MAPS=["qingwei","sluice","frostbridge","mistwood","heting"]
const ARC_IDS=["opening","sluice","frostbridge","south_bridge","tang_notes","shen_care","mistwood","qin_rope","lightness_islet","heting_delivery","heting_receipt","heting_consignee","capstone","mentor_reward"]
const BASELINE_BUNDLE_SHA="aa950207fd293f8b90630677b34753c177d4d50ff281f8aea804d6470f176bed"
const Retained=preload("res://tests/journal_guidance_test_fixture.gd")
const HISTORICAL_PATH="res://tests/historical/journal_guidance_phase1_independent_test.gd.txt"
const HISTORICAL_SHA="37bc5246571ef605518628e879fe7afc12b36a2865ca028b9d938f900415dfd8"
const HISTORICAL_GUIDANCE_RULES_SHA="3994c26adf336ccb1de9c7c6f204f23033e95a04e7e6d79d4ef19e700acd86a9"
# Only successful-local route_note presentation differs from phase1 rules.
const MODEL_BINDINGS={"game_state.gd":"7bea790067170ebd5cf300ed00daefdaa00c27bfc3e3e86e2179019af4fca46a","journal_objective_rules.gd":"3d2494af416392356976a0cd4a756c82a090f52069c1f300ea246b6edbb5402c","journal_guidance_rules.gd":"ff2ae85131409ede43f8bc1b1dd1c33ff507cef2e2a9db14bccd6453418e81cb","journal_guidance_session.gd":"eface8edcbe70c9757c3f48091761b8acd39b16e2ebb11aa5173ed936d619fba"}
var frozen_rows:Dictionary={}
var reviewed_differences:Dictionary={}
var corpus_checks:int=0
class NoSave extends State:
	var save_calls:int=0
	func save_game(_path:String=SAVE_PATH)->Error:save_calls+=1;return OK
	func has_save()->bool:return false
class NoPrefs extends Prefs:
	func load_settings(_path:String=PATH)->Error:return OK
	func save_settings(_path:String=PATH)->Error:return OK
var app
var checks:int=0
var failures:int=0
var failure_labels:Array[String]=[]
var observations:Array=[]
var label:String="setup"
var output:String=""
func _initialize()->void:run.call_deferred()
func check(value:bool,message:String)->void:
	checks+=1
	if not value:
		failures+=1;failure_labels.append(label+": "+message);push_error(label+": "+message)
func run()->void:
	if OS.get_environment("XDG_DATA_HOME").is_empty():quit(2);return
	var args=OS.get_cmdline_user_args()
	if args.size()>0:output=args[0]
	check_history_bindings()
	var corpus=Retained.corpus()
	for retained:Dictionary in corpus.rows:frozen_rows[retained.label]=retained
	for difference:Dictionary in corpus.reviewed_target_differences:reviewed_differences[difference.label]=difference
	check(State.SAVE_VERSION==16,"schema remains16")
	app=Scene.instantiate();app.state=NoSave.new();app.view_preferences=NoPrefs.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false;app.set_process(false);app.world.set_process(false)
	catalog_boundaries()
	automatic_characterization()
	earned_pck_fixtures()
	route_boundaries()
	session_lifetime()
	await replay_complete_frozen_corpus()
	combined_mentor_shen_negative_control()
	check_history_bindings()
	if not output.is_empty():
		var file=FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify({"schema":State.SAVE_VERSION,"historical_guidance_rules_sha256":HISTORICAL_GUIDANCE_RULES_SHA,"checks":checks,"failures":failures,"failure_labels":failure_labels,"observations":observations,"retained_corpus_rows_checked":corpus_checks,"engine":Engine.get_version_info(),"scope":"Maintained Linux-headless model/session and consumer regression. All 117 pinned actual old observations are independently replayed; only 14 pinned Qin/Tang target changes are approved. Prepared NoSave/NoPrefs state matrices retain complete phase1 invariants. Six PCK inputs retain original provenance. This maintenance is not the separate new J safety, genuine earned-walk, native, browser, Windows or packed acceptance gate.","source_bindings":bindings()},"\t"));file.close()
	app._stop_audio();app.queue_free();await process_frame
	print("%s journal_guidance_independent: %d checks, %d failures, %d oracle observations"%["PASS" if failures==0 else "FAIL",checks,failures,observations.size()])
	quit(0 if failures==0 else 1)
func bindings()->Dictionary:
	var result:Dictionary={}
	for path:String in ["scripts/main.gd","scripts/world.gd","scripts/game_state.gd","scripts/journal_objective_rules.gd","scripts/journal_guidance_rules.gd","scripts/journal_guidance_session.gd","tests/journal_guidance_independent_test.gd","tests/journal_guidance_baseline_inputs.json","tests/journal_guidance_frozen_oracle.json","tests/historical/journal_guidance_phase1_independent_test.gd.txt","tests/journal_guidance_test_fixture.gd","project.godot"]:result[path]=FileAccess.get_sha256("res://"+path)
	return result
func base(completed:int=0):
	var s=NoSave.new()
	if completed>=1:s.quest_stage=6;s.ending="守望";s.sect="听潮阁";s.sect_rank=1;s.level=3
	if completed>=2:s.side_stage=3;s.side_choice="rescue";s.side_reward_claimed=true;s.side_found.assign(["boatman","ledger"]);s.side_clues=2
	if completed>=3:s.chapter_two_stage=4;s.chapter_two_ending="protect_witness";s.archive_clues.assign(["clerk","inscription"]);s.seal_sequence.assign([2,0,1])
	if completed>=4:s.mist_stage=4;s.mist_approach="duel";s.mist_ending="release_water";s.mist_gauges.assign(["rain","stone","basin"])
	if completed>=5:s.heting_stage=4;s.heting_bridge="east";s.heting_delivered.assign(["meal","sealed","reserve"]);s.heting_draft="short_ferries";s.heting_ending="short_ferries"
	return s
func late(stage:int):
	var s=NoSave.new();s._copy_persistent_from(LateFixture.state(stage));return s
func valid(s)->void:
	var result=s.inspect_save_bytes(JSON.stringify({"version":State.SAVE_VERSION,"player":s.to_dict()}).to_utf8_buffer())
	check(result.ok,"prepared fixture is accepted by production schema16 reader")
	if result.ok:check(result.state.to_dict()==s.to_dict(),"prepared fixture validation is exact, no normalized surrogate")
func context(s,position:Vector2=Vector2(460,430))->Dictionary:
	app.state=s;app._sync_world_state();app.world.change_map(s.map_id,position);app._sync_world_state();app._refresh()
	return {"map_id":s.map_id,"player_position":position,"markers":app.world.interactables.duplicate(true)}
func serial_context(ctx:Dictionary)->Dictionary:
	var result={"map_id":ctx.map_id,"player_position":[ctx.player_position.x,ctx.player_position.y],"markers":{}}
	for id:String in ctx.markers:
		var marker:Dictionary=ctx.markers[id];result.markers[id]={"position":[marker.pos.x,marker.pos.y],"name":String(marker.get("name","")),"kind":String(marker.get("kind",""))}
	return result
func snapshot(s)->Dictionary:
	return {"canonical":s.to_dict(),"battle_active":s.battle_active,"battle_kind":s.battle_kind,"party_battle_epoch":s.party_battle_epoch,"party_session":s.party_session,"party_settlement":s.party_settlement.duplicate(true),"pending_token":s._party_pending_token,"encounter":s._party_encounter,"companion_count":s._companion_attack_count,"position":s.position,"save_calls":s.save_calls if s is NoSave else -1}
func exercise(s,arc:String,ctx:Dictionary)->Dictionary:
	var before=snapshot(s);var marker_before=ctx.duplicate(true)
	var expected_rows=Objectives.catalog(s);var expected_auto=Objectives.automatic(s)
	var result=Guidance.resolve(s,arc,ctx)
	check(snapshot(s)==before,"catalog/auto/projection do not mutate any observed state")
	check(ctx==marker_before,"projection does not mutate caller context or markers")
	check(Objectives.catalog(s)==expected_rows and Objectives.automatic(s)==expected_auto,"repeat evaluations are stable")
	var copy=result.duplicate(true)
	if result.has("cart_route") and not result.cart_route.is_empty():result.cart_route[0]=Vector2(-999,-999)
	result.next_target_id="caller_tampering"
	if not expected_rows.is_empty():expected_rows[0].display_title="caller_tampering";expected_rows.append({"id":"not_real"})
	check(Guidance.resolve(s,arc,ctx)==copy,"caller result mutation cannot corrupt future projection")
	check(not JSON.stringify(Objectives.catalog(s)).contains("caller_tampering") and Objectives.catalog(s).size()<15,"caller catalog mutation cannot corrupt catalog or state")
	check(snapshot(s)==before,"caller-owned results never alias persistent state")
	if not String(copy.get("next_target_id","")).is_empty():
		check(ctx.markers.has(copy.next_target_id),"nonempty target is a real current-map marker")
		check(copy.next_target_map==s.map_id,"next target map is current map")
	return copy
func row(s,id:String)->Dictionary:return Objectives.row(s,id)
func status(s,id:String,wanted:String)->void:
	var r=row(s,id)
	check(not r.is_empty(),id+" is earned and visible")
	if r.is_empty():return
	check(r.status==wanted,id+" exact status "+wanted)
	check(r.trackable==(wanted!="completed"),id+" completion exactly controls Track")
func hidden(s,id:String)->void:check(row(s,id).is_empty(),id+" stays hidden")
func text_of(r:Dictionary)->String:return String(r.get("display_title",""))+"\n"+String(r.get("next_action",""))+"\n"+String(r.get("earned_history",""))
func catalog_boundaries()->void:
	label="fresh_visibility"
	var s=base();valid(s)
	var ids:Array=[]
	for r:Dictionary in Objectives.catalog(s):ids.append(r.id)
	check(ids==["opening"],"fresh catalog contains only known opening")
	for id:String in ARC_IDS.slice(1):hidden(s,id)
	for word:String in ["尺绳有托","尺上旧痕","未损先收","复签不撤","梁缜","先通缓水渠","先鸣渡船钟"]:check(not text_of(row(s,"opening")).contains(word),"fresh current instruction hides "+word)
	hidden(s,"made_up");hidden(s,"")
	label="available_chapters_redact_contacts"
	for spec:Array in [[1,"sluice","船工"],[2,"frostbridge","温行舟"],[3,"mistwood","秦禾"],[4,"heting_delivery","孟绫"]]:
		s=base(spec[0]);status(s,spec[1],"available")
		if spec[1]!="sluice":check(not text_of(row(s,spec[1])).contains(spec[2]),"unintroduced chapter contact is not exposed")
	label="shen_eligibility"
	s=base(1);s.companion_unlocked=true;hidden(s,"shen_care")
	s=base(2);s.companion_unlocked=true;status(s,"shen_care","available")
	for n:int in range(1,6):
		s.shen_care_stage=n;s.shen_care_choice="shore" if n>=4 else "";status(s,"shen_care","completed" if n==5 else "active")
	for choice:String in ["shore","mobile"]:
		s.shen_care_stage=5;s.shen_care_choice=choice;var earned=text_of(row(s,"shen_care"))
		check(earned.contains("防御提高1") if choice=="shore" else earned.contains("治疗提高2"),"completed care retains existing earned numeric benefit")
		s.shen_care_stage=4;check(not text_of(row(s,"shen_care")).contains("防御提高1") and not text_of(row(s,"shen_care")).contains("治疗提高2"),"care draft does not expose completion benefit")
	label="tang_optional_bridge"
	s=base(3);status(s,"south_bridge","available");hidden(s,"tang_notes")
	s.bridge_repaired=true;status(s,"south_bridge","completed");status(s,"tang_notes","available")
	check(not text_of(row(s,"tang_notes")).contains("尺上旧痕"),"Tang preacceptance hides personal title")
	for n:int in [1,2,3]:
		s.tangqi_stage=n;s.tangqi_choice="teach" if n==3 else "";status(s,"tang_notes","active")
	s.tangqi_unlocked=true;status(s,"tang_notes","completed")
	s=base(2);s.chapter_two_stage=1;s.bridge_repaired=true;hidden(s,"tang_notes")
	label="qin_visibility"
	s=base(3);s.mist_stage=3;s.mist_gauges.assign(["rain","stone","basin"]);s.mist_approach="duel";hidden(s,"qin_rope")
	s=base(4);status(s,"qin_rope","available")
	for word:String in ["尺绳有托","守渡横杖","警水刻线","轮值"]:check(not text_of(row(s,"qin_rope")).contains(word),"Qin offer hides unaccepted detail "+word)
	for n:int in range(1,5):
		s.qin_stage=n;s.qin_unlocked=n==4;status(s,"qin_rope","completed" if n==4 else "active")
		for map:String in MAPS:s.map_id=map;status(s,"qin_rope","completed" if n==4 else "active")
		check(text_of(row(s,"qin_rope")).contains("守渡横杖")==bool(n==4),"Qin ability appears only after actual recruitment and remains readable")
	label="lightness_boundaries"
	for level:int in [2,3]:
		for sect:String in ["未入门","听潮阁","照野堂","问石门"]:
			s=base();s.level=level;s.sect=sect
			if level==3 and sect!="未入门":status(s,"lightness_islet","available")
			else:hidden(s,"lightness_islet")
	s=base(1);s.lightness_unlocked=true;s.position=Lightness.LANDING;status(s,"lightness_islet","active")
	check(not text_of(row(s,"lightness_islet")).contains("18"),"unread relic does not promise reward")
	s.lightness_relics.append("reed_islet");status(s,"lightness_islet","completed")
	label="receipt_consignee_terminal"
	s=base(4);s.heting_stage=3;hidden(s,"heting_receipt");hidden(s,"heting_consignee")
	s=base(5);status(s,"heting_receipt","available");status(s,"heting_consignee","available")
	for word:String in ["复签不撤","假水损","预结粮钱"]:check(not text_of(row(s,"heting_receipt")).contains(word),"receipt offer hides future conclusion "+word)
	for n:int in range(1,4):s.receipt_stage=n;status(s,"heting_receipt","completed" if n==3 else "active")
	for receipt:int in [0,3]:
		s.receipt_stage=receipt
		for n:int in range(1,6):
			s.consignee_stage=n;s.consignee_cargo_location="warehouse" if n<4 else ("cart" if n==4 else "grain_boat")
			s.consignee_observations.assign(State.Consignee.OBSERVATIONS if n>=2 else [])
			s.consignee_draft="return_to_owner" if n>=2 else "";s.consignee_ending="return_to_owner" if n==5 else ""
			status(s,"heting_consignee","completed" if n==5 else "active")
	label="capstone_stage_disclosure"
	for n:int in range(8):
		s=late(n);status(s,"capstone","available" if n==0 else ("completed" if n==7 else "active"))
		var txt=text_of(row(s,"capstone"))
		if n<2:check(not txt.contains("亲笔") and not txt.contains("承认写信"),"authorship is not known before2")
		if n<3:check(not txt.contains("须对") and not txt.contains("负责"),"issued-chain responsibility is not concluded before3")
		if n<5:check(not txt.contains("两条已证伪") and not txt.contains("另两条待核"),"classification result is not concluded before5")
		if n<7:check(not txt.contains("160") and not txt.contains("80文"),"capstone completion reward not previewed")
	label="mentor_reward"
	s=base(1);hidden(s,"mentor_reward");s.sect_trial_won=true;status(s,"mentor_reward","active");s.sect_rank=2;status(s,"mentor_reward","completed")
	label="finite_catalog_detached_order"
	s=late(7);s.bridge_repaired=true;s.receipt_stage=3;s.level=3;s.sect="听潮阁";s.sect_rank=2;s.sect_trial_won=true;s.lightness_unlocked=true;s.lightness_relics.append("reed_islet")
	check(s.recruit_companion(),"full catalog fixture recruits Shen through canonical API");s.shen_care_stage=5;s.shen_care_choice="shore"
	s.tangqi_stage=3;s.tangqi_choice="teach";check(s.recruit_tangqi(),"full catalog fixture recruits Tang through canonical API")
	s.map_id="mistwood";s.qin_stage=3;check(s.recruit_qin(),"full catalog fixture recruits Qin through canonical API");valid(s)
	ids=[]
	for r:Dictionary in Objectives.catalog(s):ids.append(r.id)
	check(ids==ARC_IDS,"finite catalog order and exactly14 earned IDs")
	for map:String in MAPS:
		s.map_id=map;var moved:Array=[]
		for r:Dictionary in Objectives.catalog(s):moved.append(r.id)
		check(moved==ids,"catalog order independent of player map")
		exercise(s,"",context(s))
	label="wounded_benched_fitting_preservation"
	s.party_resources.shen.hp=1;s.party_resources.shen.qi=0;s.party_resources.tang.hp=0;s.party_resources.tang.qi=0;s.party_resources.qin.hp=2;s.party_resources.qin.qi=0
	check(s.set_party_roster(["hero","qin"]),"prepared bench selection uses canonical API")
	for fitting:String in ["plain","edge","guard"]:
		s.weapon_fitting=fitting;s.hp=7;s.qi=0;valid(s);exercise(s,"",context(s))
func golden(s,expected_arc:String,expected_target:String="",check_text:bool=true)->void:
	valid(s)
	var ctx=context(s);var before=snapshot(s);var old:Dictionary=frozen(label)
	var a=Objectives.automatic(s);var r=exercise(s,"",ctx)
	check(snapshot(s)==before,"golden comparison preserves state")
	check(String(a.get("source_arc_id",a.get("id","")))==expected_arc,"automatic preserves frozen winning arc "+expected_arc)
	if check_text:
		check(a.get("display_title","")==old.title,"automatic title matches retained actual frozen Main HUD")
		check(a.get("next_action","")==String(State.Capstone.goal(s).objective) if expected_arc=="capstone" else a.get("next_action","")==old.hint,"automatic instruction exactly matches retained HUD or unchanged capstone goal before route suffix")
	if not expected_target.is_empty():check(r.next_target_id==expected_target,"shared legal target is "+expected_target)
	observations.append({"label":label,"fixture_kind":"prepared canonical; not earned","map":s.map_id,"state":s.to_dict(),"context":serial_context(ctx),"frozen_main":old,"automatic":a,"resolved":r})
func automatic_characterization()->void:
	for stage:int in range(6):
		label="opening_"+str(stage);var s=base();s.quest_stage=stage
		if stage>=5:s.ending="守望"
		if stage==2:s.herbs=1
		golden(s,"opening",["elder","herb","healer","bandit","elder","elder"][stage])
	for stage:int in range(3):
		for map:String in ["qingwei","sluice"]:
			label="sluice_"+str(stage)+"_"+map;var s=base(1);s.map_id=map;s.side_stage=stage
			if stage>=1:s.side_choice="rescue";s.side_found.assign(["boatman"]);s.side_clues=1
			if stage>=2:s.side_found.append("ledger");s.side_clues=2
			golden(s,"sluice","exit_sluice" if map=="qingwei" else ["stranded_boatman","ledger_runner","sluice_boss"][stage])
	for clue:Array in [[],["clerk"],["inscription"],["clerk","inscription"]]:
		label="frost_clues_"+str(clue);var s=base(2);s.map_id="frostbridge";s.chapter_two_stage=1;s.archive_clues.assign(clue)
		golden(s,"frostbridge","chapter_clerk" if not clue.has("clerk") else ("chapter_inscription" if not clue.has("inscription") else "chapter_archive"))
	for stage:int in [2,3]:
		label="frost_"+str(stage);var s=base(2);s.map_id="frostbridge";s.chapter_two_stage=stage;s.archive_clues.assign(["clerk","inscription"]);s.seal_sequence.assign([2,0,1]);golden(s,"frostbridge","chapter_archive" if stage==2 else "chapter_host")
	for spec:Array in [[[],"","mist_rain_gauge"],[["rain"],"","mist_basin"],[["rain","basin"],"","mist_scout"],[["rain","basin"],"duel","mist_stone_gauge"]]:
		label="mist_missing_"+str(spec[0])+str(spec[1]);var s=base(3);s.map_id="mistwood";s.mist_stage=1;s.mist_gauges.assign(spec[0]);s.mist_approach=spec[1];s.bridge_repaired=true;s.tangqi_stage=1;golden(s,"mistwood",spec[2])
	for stage:int in [2,3]:
		label="mist_"+str(stage);var s=base(3);s.map_id="mistwood";s.mist_stage=stage;s.mist_gauges.assign(["rain","stone","basin"]);s.mist_approach="duel";golden(s,"mistwood","mist_gate" if stage==2 else "mist_guide")
	for tang:int in [1,2,3]:
		for qin:int in [1,2,3]:
			label="bounded_qin_tang_fix_"+str(tang)+"_"+str(qin);var s=base(4);s.map_id="mistwood";s.bridge_repaired=true;s.tangqi_stage=tang;s.tangqi_choice="teach" if tang==3 else "";s.qin_stage=qin
			golden(s,"qin_rope",["","mist_rain_gauge","mist_camp","mist_guide"][qin])
			check(frozen(label).target=="return_frostbridge" and app.world._quest_target_id()==["","mist_rain_gauge","mist_camp","mist_guide"][qin],"retained actual mismatch and approved current Qin target are both explicit")
	for shen:int in range(1,5):
		label="shen_"+str(shen);var s=base(3);check(s.recruit_companion(),"prepared Shen recruitment uses actual canonical party API");s.shen_care_stage=shen;s.shen_care_choice="shore" if shen==4 else "";s.map_id="qingwei";golden(s,"shen_care")
	for receipt:int in [1,2]:
		for consignee:int in [1,2,3,4]:
			label="harbor_overlap_"+str(receipt)+"_"+str(consignee);var s=base(5);s.map_id="heting";s.receipt_stage=receipt;s.consignee_stage=consignee;s.consignee_cargo_location="cart" if consignee==4 else "warehouse";s.consignee_observations.assign(State.Consignee.OBSERVATIONS if consignee>=2 else []);s.consignee_draft="hold_for_inspection" if consignee>=2 else "";golden(s,"heting_consignee")
	label="local_mentor_override";var mentor=base(3);mentor.sect_trial_won=true;mentor.map_id="qingwei";mentor.bridge_repaired=true;mentor.tangqi_stage=1;golden(mentor,"mentor_reward","mentor")
	for stage:int in range(8):
		for map:String in MAPS:
			label="capstone_"+str(stage)+"_"+map;var s=late(stage);s.map_id=map
			if stage<7:golden(s,"capstone")
			else:
				valid(s);var ctx=context(s);var old_target=frozen(label).target;var old_title=frozen(label).title;var old_hint=frozen(label).hint;var a=Objectives.automatic(s);var r=exercise(s,"",ctx)
				check(a.kind=="exploration" and r.kind=="exploration" and r.arc_id=="","completed defaults remain exploration without invented active row")
				check(a.display_title==old_title and a.next_action==old_hint,"all-five-map stage7 preserves actual frozen onward text")
				check(r.next_target_id==old_target,"all-five-map stage7 preserves actual optional landmark")
				observations.append({"label":label,"fixture_kind":"prepared canonical; not earned","map":map,"state":s.to_dict(),"context":serial_context(ctx),"frozen_main":{"title":old_title,"hint":old_hint,"target":old_target},"automatic":a,"resolved":r})
	for variant:String in ["tang","shen","qin","receipt","all_pending"]:
		for map:String in MAPS:
			label="post_capstone_"+variant+"_"+map;var s=late(7);s.map_id=map
			if variant in ["tang","all_pending"]:s.bridge_repaired=true;s.tangqi_stage=1
			if variant in ["shen","all_pending"]:check(s.recruit_companion(),"post-capstone fixture uses actual Shen recruitment API");s.shen_care_stage=1
			if variant in ["qin","all_pending"]:s.qin_stage=1
			if variant in ["receipt","all_pending"]:s.receipt_stage=1
			var expected:String="frostbridge"
			if variant=="tang":expected="heting_delivery" if map=="heting" else "tang_notes"
			elif variant=="shen":expected="heting_delivery" if map=="heting" else "shen_care"
			elif variant=="qin":expected="qin_rope" if map=="mistwood" else ("heting_delivery" if map=="heting" else "frostbridge")
			elif variant=="receipt":expected="heting_receipt" if map=="heting" else ("mistwood" if map=="mistwood" else "frostbridge")
			elif variant=="all_pending":expected="qin_rope" if map=="mistwood" else ("heting_receipt" if map=="heting" else "tang_notes")
			golden(s,expected)
			var automatic=Objectives.automatic(s)
			if not automatic.trackable:check(Guidance.resolve(s,"",context(s)).next_target_id==frozen(label).target,"completed ordinary default preserves actual frozen optional landmark without reranking")
func earned_pck_fixtures()->void:
	var bundle_path=OS.get_environment("JOURNAL_BASELINE_BUNDLE")
	if bundle_path.is_empty():bundle_path="res://tests/journal_guidance_baseline_inputs.json"
	label="earned_fixture_binding"
	check(FileAccess.get_sha256(bundle_path)==BASELINE_BUNDLE_SHA,"portable baseline bundle matches pinned independently derived exact inputs/provenance")
	var bundle=JSON.parse_string(FileAccess.get_file_as_string(bundle_path))
	if not bundle is Dictionary:check(false,"portable baseline bundle parses");return
	check(bundle.provenance.actual_pck_report_sha256=="a0e09c1d863e79d56b7f48eec86da65d7a50d4bdafe1e9b2df2d759fe2cacf15" and bundle.provenance.pack_sha256=="375f03e9fd93c7a799fd0486be2905ec310221b89885bf96d4694902d751d1f6","compact observations retain exact source PCK/report provenance")
	check(bundle.fixtures.size()==6,"portable corpus retains all six PCK cases")
	for observed:Dictionary in bundle.fixtures:
		label="retained_"+observed.label
		var accepted:bool=observed.kind=="actual_gap"
		var bytes:PackedByteArray=String(observed.input_utf8).to_utf8_buffer()
		check(String(observed.input_utf8).sha256_text()==observed.input_sha256 and bytes.size()==observed.input_bytes,"earned input bytes match retained actual PCK fixture hash and size")
		var s=NoSave.new();var inspected=s.inspect_save_bytes(bytes)
		check(inspected.ok,"unchanged production reader accepts portable exact earned bytes")
		if not inspected.ok:continue
		s._copy_persistent_from(inspected.state);valid(s)
		var ctx=context(s,s.position);var result=exercise(s,"",ctx)
		check(app.quest_label.text==observed.observed_hud.title and app.journal_guidance_snapshot.next_action==observed.observed_hud.hint,"integrated Main preserves captured PCK full HUD instruction")
		check(frozen(label).target==observed.observed_world_target and app.world._quest_target_id()=="mist_rain_gauge","captured PCK target retained, current target is approved Qin or unchanged negative Mist")
		check(result.arc_id==("qin_rope" if accepted else "mistwood"),"new shared auto keeps PCK HUD winning arc")
		check(result.next_target_id=="mist_rain_gauge","new shared target fixes only captured Qin mismatch or preserves negative control")
		var manual=exercise(s,"tang_notes",ctx)
		check(manual.arc_id=="tang_notes" and manual.destination_map=="sluice" and manual.destination_site=="sluice_cache" and manual.next_target_id=="return_frostbridge","explicit Tang has correct independent final goal and immediate exit")
		observations.append({"label":label,"fixture_kind":"API-earned preparation; Qin positive accepted by actual frozen PCK E/1; declared placement","fixture_name":observed.filename,"fixture_sha256":observed.input_sha256,"state":s.to_dict(),"context":serial_context(ctx),"frozen_pck":observed.observed_hud,"old_target":observed.observed_world_target,"resolved":result,"manual_tang":manual})
func route_boundaries()->void:
	label="local_note_is_not_unavailable"
	var note_state=base();valid(note_state)
	var note_context=context(note_state)
	var local_note=exercise(note_state,"opening",note_context)
	check(local_note.next_target_id=="elder" and local_note.route_status=="local" and local_note.route_note=="","valid local elder guidance never inherits the default unavailable explanation")
	var missing_context=note_context.duplicate(true);missing_context.markers.erase("elder")
	var unavailable_note=exercise(note_state,"opening",missing_context)
	check(unavailable_note.next_target_id=="" and unavailable_note.route_status=="unavailable" and unavailable_note.route_note=="当前场景未找到相应去处；追踪保留。","genuine missing local marker retains exact truthful unavailable explanation")
	local_note=exercise(note_state,"opening",note_context)
	check(local_note.next_target_id=="elder" and local_note.route_note=="","restored real local marker clears unavailable note without changing arc or target")
	label="all_legal_map_pairs"
	var s=base(5);s.bridge_repaired=true;s.tangqi_stage=1;s.qin_stage=1;s.companion_unlocked=true;s.shen_care_stage=3;s.lightness_unlocked=true
	for arc:String in ["tang_notes","qin_rope","shen_care","lightness_islet","heting_receipt","heting_consignee"]:
		for map:String in MAPS:
			label="manual_route_"+arc+"_"+map;s.map_id=map;var ctx=context(s);var r=exercise(s,arc,ctx)
			check(r.mode=="manual" and r.arc_id==arc and r.valid_tracked_arc_id==arc,"earned identity remains selectable on every accessible map")
			var goal=row(s,arc)
			check(r.destination_map==goal.destination_map and r.destination_site==goal.destination_site,"final destination is arc-local independent of map")
			if map!=goal.destination_map:
				check(r.next_target_id==next_exit(map,goal.destination_map),"remote route chooses only adjacent existing exit")
				check(r.route_status=="via_exit" and r.is_exit,"remote route accurately classified")
			elif arc=="lightness_islet":check(r.next_target_id=="reed_cross" and r.route_status=="via_crossing","mainland relic uses legal shore crossing")
			else:check(r.route_status=="local","same-map accessible goal is local")
	label="mist_arc_local_after_qin"
	s=base(4);s.map_id="mistwood";s.qin_stage=2
	var mist=row(s,"mistwood");check(mist.status=="completed" and not text_of(mist).contains("尺绳有托"),"finished Mist row never becomes Qin task")
	var qin=row(s,"qin_rope");check(qin.destination_site=="mist_camp","Qin arc-local adapter follows its own camp step")
	label="harbor_arc_local_during_other_work"
	s=base(5);s.map_id="heting";s.receipt_stage=2;s.consignee_stage=1;s.consignee_cargo_location="warehouse"
	var ctx=context(s)
	var receipt=exercise(s,"heting_receipt",ctx);var consignee=exercise(s,"heting_consignee",ctx)
	check(receipt.next_target_id=="heting_scale" and receipt.arc_id=="heting_receipt","manual receipt cannot be cross-wired to consignee")
	check(consignee.next_target_id=="consignee_warehouse" and consignee.arc_id=="heting_consignee","manual consignee keeps unobserved warehouse")
	check(row(s,"heting_delivery").status=="completed" and not text_of(row(s,"heting_delivery")).contains("未损先收"),"completed base delivery row does not absorb sequel")
	label="islet_return_safety"
	for learned:bool in [false,true]:
		s=base(3);s.map_id="qingwei";s.lightness_unlocked=learned;s.bridge_repaired=true;s.tangqi_stage=1;s.companion_unlocked=true;s.shen_care_stage=3;s.sect_trial_won=true
		for arc:String in ["tang_notes","shen_care","mentor_reward"]:
			var r=exercise(s,arc,context(s,Lightness.LANDING))
			check(r.next_target_id=="reed_return" and r.route_status=="via_crossing","islet always returns before mainland or remote target, even without learned skill")
		s=base();s.map_id="qingwei";s.lightness_unlocked=learned
		var opening=exercise(s,"opening",context(s,Lightness.LANDING));check(opening.next_target_id=="reed_return","opening elder never points straight across islet water")
	label="available_remote_islet_return_name"
	s=base(2);s.map_id="qingwei";var stage0_ctx=context(s,Lightness.LANDING);var stage0_return=exercise(s,"frostbridge",stage0_ctx)
	check(stage0_return.next_target_id=="reed_return" and stage0_return.next_target_name==stage0_ctx.markers.reed_return.name,"first-contact redaction cannot replace actual return-crossing name")
	label="relic_arrival"
	s=base(1);s.lightness_unlocked=true;s.map_id="qingwei"
	var relic=exercise(s,"lightness_islet",context(s,Lightness.LANDING));check(relic.next_target_id=="reed_relic" and relic.route_status=="local","actual islet arrival exposes relic interaction, not another crossing")
	label="missing_and_corrupt_context"
	s=base(4);s.qin_stage=1;s.map_id="mistwood";ctx=context(s)
	var broken:Array=[{}, {"map_id":"heting","player_position":Vector2(400,400),"markers":ctx.markers}, {"map_id":"mistwood","player_position":Vector2(NAN,400),"markers":ctx.markers}, {"map_id":"mistwood","player_position":Vector2(400,400),"markers":{}}]
	for point:Vector2 in [Vector2(NAN,400),Vector2(INF,400),Vector2(-10000,-10000),Vector2(10000,10000)]:
		var bad=ctx.duplicate(true);bad.markers.mist_rain_gauge.pos=point;broken.append(bad)
	for bad:Dictionary in broken:
		var before=snapshot(s);var input=bad.duplicate(true);var r=Guidance.resolve(s,"qin_rope",bad)
		check(r.next_target_id=="" and r.route_status=="unavailable","bad half-frame context suppresses marker")
		check(r.valid_tracked_arc_id=="qin_rope" and r.destination_map=="mistwood","temporary unavailable context preserves earned selection and destination")
		check(snapshot(s)==before,"hostile context does not normalize state")
		# NaN does not compare equal to itself, so use serialized representation here.
		check(var_to_str(bad)==var_to_str(input),"hostile context is not rewritten")
	label="locked_forward_gate_rejection"
	for gate:int in range(4):
		s=base(4);s.qin_stage=1;s.map_id=MAPS[gate]
		if gate==0:s.quest_stage=0
		elif gate==1:s.side_stage=0
		elif gate==2:s.chapter_two_stage=0
		else:s.mist_stage=0;s.qin_stage=0;s.heting_stage=1;s.heting_bridge="west"
		# Deliberately inconsistent hostile-state rejection probe, not a valid or earned route.
		ctx=context(s);var arc="heting_delivery" if gate==3 else "qin_rope";var r=Guidance.resolve(s,arc,ctx)
		check(r.next_target_id!=next_exit(MAPS[gate],"heting"),"inconsistent state never advertises locked forward exit")
	label="unknown_tracking_id"
	s=base();ctx=context(s)
	for id:String in ["unknown","qin_rope","heting_consignee","capstone"]:
		var r=exercise(s,id,ctx);check(r.valid_tracked_arc_id=="" and r.arc_id=="opening","unknown or unearned selection returns safe existing auto")
	cart_routes()
func next_exit(here:String,there:String)->String:
	return {"qingwei":"exit_sluice","sluice":"exit_frostbridge","frostbridge":"exit_mistwood","mistwood":"exit_heting"}.get(here,"") if MAPS.find(here)<MAPS.find(there) else {"sluice":"return_village","frostbridge":"return_sluice","mistwood":"return_frostbridge","heting":"return_mistwood"}.get(here,"")
func cart_routes()->void:
	for kind:String in ["meal","sealed","reserve","consignee_hold","consignee_return"]:
		for bridge:String in ["west","east"]:
			var s=base(4);s.map_id="heting";s.heting_bridge=bridge
			if kind in ["meal","sealed"]:s.heting_stage=1;s.heting_cargo=kind
			elif kind=="reserve":s.heting_stage=3;s.heting_cargo="reserve";s.heting_delivered.assign(["meal","sealed"]);s.heting_draft="short_ferries"
			else:
				s=base(5);s.map_id="heting";s.heting_bridge=bridge;s.consignee_stage=4;s.consignee_cargo_location="cart";s.consignee_observations.assign(State.Consignee.OBSERVATIONS);s.consignee_draft="hold_for_inspection" if kind=="consignee_hold" else "return_to_owner"
			s.qin_stage=1;s.bridge_repaired=true;s.tangqi_stage=1
			label="loaded_"+kind+"_"+bridge;valid(s)
			for position:Vector2 in [Vector2(820,665),Vector2(230,780),Vector2(1390,600),Vector2(680,350)]:
				for arc:String in ["tang_notes","qin_rope","heting_consignee" if kind.begins_with("consignee") else "heting_delivery"]:
					var r=exercise(s,arc,context(s,position))
					if arc in ["tang_notes","qin_rope"]:
						check(r.next_target_id=="return_mistwood" and r.route_status=="departure_confirmation","loaded departure is actual parking-confirm interaction")
						check(String(r.route_note).contains("停") or String(r.route_note).contains("确认"),"loaded departure discloses explicit park/confirmation")
					var route:PackedVector2Array=r.cart_route
					check(not route.is_empty(),"legal sampled loaded start receives actual collision-checked route")
					if not route.is_empty():
						check(route[0]==position and route[-1]==app.world.interactables[r.next_target_id].pos,"cart route starts at actual player and ends at shared marker")
						for i:int in range(1,route.size()):check(Harbor.can_step(route[i-1],route[i],bridge,true),"each route segment uses actual loaded collision and selected bridge")
					if kind=="consignee_return" and arc=="heting_consignee":check(r.destination_receiver=="heting_grain_boat" and r.destination_site=="heting_cargo" and r.next_target_id=="heting_cargo","logical boat receiver aliases once to actual physical marker")
func session_lifetime()->void:
	label="session_tokens"
	var s=base(4);s.qin_stage=1;s.bridge_repaired=true;s.tangqi_stage=1;s.map_id="mistwood"
	var session=Session.new();session.reset(s);var tok=session.token(s);var ctx=context(s)
	var before=snapshot(s)
	check(session.track(s,"tang_notes",tok),"explicit valid Track is accepted")
	check(session.tracked_arc_id=="tang_notes","session owns selected ID")
	check(not session.track(s,"qin_rope",tok),"prior epoch cannot overwrite newer selection")
	var stale=session.token(s);session.invalidate_callbacks();check(not session.restore_auto(s,stale),"invalidated modal callback cannot clear tracking")
	check(session.tracked_arc_id=="tang_notes","callback invalidation preserves selected matter")
	var alien=Session.new();alien.reset(s);check(not session.track(s,"qin_rope",alien.token(s)),"another session cannot authorize selection")
	var repeated=session.token(s);check(not session.track(s,"tang_notes",repeated) and session.token(s)==repeated and session.tracked_arc_id=="tang_notes","re-track is an idempotent no-op preserving epoch and selection")
	check(snapshot(s)==before,"tracking callbacks change no persistent/battle/resource/position fields")
	label="travel_does_not_reset_selection"
	var travel_token=session.token(s);s.map_id="frostbridge";ctx=context(s);var r=session.refresh(s,ctx)
	check(session.tracked_arc_id=="tang_notes" and r.arc_id=="tang_notes","travel retains identity")
	check(not session.restore_auto(s,travel_token),"pre-travel callback is stale before any host invalidation")
	label="temporary_unavailable_keeps_selection"
	before=snapshot(s);r=session.refresh(s,{})
	check(session.tracked_arc_id=="tang_notes" and r.route_status=="unavailable","missing world snapshot does not clear valid selection")
	check(snapshot(s)==before,"unavailable refresh remains read-only")
	s.battle_active=true;r=session.refresh(s,context(s));check(session.tracked_arc_id=="tang_notes","battle does not invalidate earned identity")
	check(not session.track(s,"qin_rope",session.token(s)),"battle rejects new Track callback");s.battle_active=false
	label="failed_load_preserves_selection"
	var corrupt="user://journal-independent-corrupt.json";var f=FileAccess.open(corrupt,FileAccess.WRITE);f.store_string("{broken");f.close();before=snapshot(s)
	check(s.load_game(corrupt)!=OK,"actual production corrupt load is rejected")
	r=session.refresh(s,context(s));check(session.tracked_arc_id=="tang_notes" and snapshot(s)==before,"failed load preserves live state and selected arc")
	label="explicit_success_reset_same_identity"
	var pre_reset=session.token(s);var good="user://journal-independent-success.json";f=FileAccess.open(good,FileAccess.WRITE);f.store_string(JSON.stringify({"version":State.SAVE_VERSION,"player":s.to_dict()}));f.close()
	check(s.load_game(good)==OK,"actual production successful load into same state object")
	before=snapshot(s);session.reset(s)
	check(session.tracked_arc_id=="" and not session.track(s,"qin_rope",pre_reset),"successful host reset clears selection and invalidates same-object callbacks")
	check(snapshot(s)==before,"explicit session reset itself never resets game")
	check(session.track(s,"qin_rope",session.token(s)),"fresh callback can select Qin")
	label="step_retention_completion_once"
	s.map_id="mistwood";s.qin_stage=2;ctx=context(s);r=session.refresh(s,ctx)
	check(session.tracked_arc_id=="qin_rope" and r.next_target_id=="mist_camp","same selected arc follows step advancement")
	s.qin_stage=3;r=session.refresh(s,context(s));check(session.tracked_arc_id=="qin_rope" and r.next_target_id=="mist_guide","invitation due remains unfinished")
	var terminal_token=session.token(s);check(s.recruit_qin(),"actual canonical Qin invitation completes the tracked arc");r=session.refresh(s,context(s))
	check(session.tracked_arc_id=="" and r.selection_changed,"actual completion clears selection once")
	check(not session.track(s,"qin_rope",terminal_token),"stale completion callback cannot resurrect selected completed arc")
	for i:int in range(100):
		r=session.refresh(s,context(s));check(not r.selection_changed,"idle completion refresh never repeats change notice")
	label="identity_invalidation"
	check(session.track(s,"tang_notes",session.token(s)),"can choose remaining valid Tang")
	var prior=session.token(s);var replacement=base(4);replacement.qin_stage=1;replacement.map_id="mistwood"
	r=session.refresh(replacement,context(replacement));check(session.tracked_arc_id=="" and not session.restore_auto(replacement,prior),"state replacement resets and rejects old identity token")
	check(not session.track(replacement,"heting_consignee",session.token(replacement)),"unknown/locked row never tracks through callback")
	check(session.track(replacement,"qin_rope",session.token(replacement)),"earned available identity tracks in new journey")
	replacement.qin_stage=0;replacement.mist_stage=3;replacement.mist_ending="";r=session.refresh(replacement,context(replacement));check(session.tracked_arc_id=="" and r.selection_changed,"genuine earned identity invalidation resets once")
	label="auto_restore_readonly"
	before=snapshot(replacement);check(not session.restore_auto(replacement,session.token(replacement)),"already-auto restore reports no change")
	check(not session.restore_auto(replacement,session.token(replacement)),"repeated already-auto restore remains no change")
	check(snapshot(replacement)==before,"auto restore does not mutate state")
	for key:String in replacement.to_dict():check(not key.contains("tracked") and not key.contains("journal_guidance"),"no transient guidance field serialized: "+key)

func check_history_bindings()->void:
	check(FileAccess.get_sha256(HISTORICAL_PATH)==HISTORICAL_SHA,"original phase1 driver exact bytes remain historical evidence")
	check(FileAccess.get_sha256(Retained.ORACLE_PATH)==Retained.ORACLE_SHA,"all117 actual old observations remain frozen")
	check(FileAccess.get_sha256("res://tests/journal_guidance_baseline_inputs.json")==BASELINE_BUNDLE_SHA,"all six actual PCK fixture bytes remain frozen")
	check(Retained.corpus().source_input_bindings["scripts/journal_guidance_rules.gd"]==HISTORICAL_GUIDANCE_RULES_SHA,"phase1 actual source binding remains historical; local-note correction never rewrites it")
	for file:String in MODEL_BINDINGS:check(FileAccess.get_sha256("res://scripts/"+file)==MODEL_BINDINGS[file],"production model/state matches explicitly reviewed current binding: "+file)
func frozen(case_label:String)->Dictionary:
	check(frozen_rows.has(case_label),"old-source label retained: "+case_label)
	return frozen_rows.get(case_label,{}).get("frozen_observation",{})
func semantic(result:Dictionary)->Dictionary:
	var tuple:Dictionary={}
	for field:String in ["mode","kind","arc_id","step_key","destination_map","destination_site","next_target_id","next_target_map","next_target_position","route_status","arc_title","next_action"]:tuple[field]=result.get(field)
	return tuple
func replay_complete_frozen_corpus()->void:
	var seen:Dictionary={};var changed:int=0;var unchanged:int=0
	for case_label:String in frozen_rows:
		label="corpus/"+case_label
		var retained:Dictionary=frozen_rows[case_label];var old:Dictionary=retained.frozen_observation
		var accepted=Retained.read_state(retained.state);var s=NoSave.new();s._copy_persistent_from(accepted)
		check(JSON.parse_string(JSON.stringify(s.to_dict()))==retained.state,"full actual old input materializes exactly through production reader")
		var frozen_ctx=Retained.retained_context(retained.context)
		var expected_target:String=old.target
		if reviewed_differences.has(case_label):
			var difference:Dictionary=reviewed_differences[case_label]
			check(old.target==difference.old_target and difference.old_target=="return_frostbridge" and difference.winning_arc=="qin_rope","reviewed exception retains actual old Tang target and Qin winner")
			expected_target=difference.new_target;changed+=1
		else:unchanged+=1
		var expected_instruction:String=old.hint
		if case_label.begins_with("capstone_") and s.capstone_stage<7:expected_instruction=expected_instruction.split(" 先沿")[0]
		var before=snapshot(s)
		var model=Guidance.resolve(s,"",frozen_ctx)
		check(model.arc_title==old.title and model.next_action==expected_instruction,"model title and full instruction agree with actual old output")
		check(model.next_target_id==expected_target,"model target matches exact frozen policy or one of14 named Qin changes")
		if model.route_status=="local" and not model.next_target_id.is_empty():check(model.route_note!="暂无可标出的下一处。","valid local corpus projection never claims there is no next target")
		if reviewed_differences.has(case_label):check(model.arc_id=="qin_rope","approved fix never changes winning Qin arc")
		check(snapshot(s)==before,"independent corpus projection preserves all observed state")
		context(s,frozen_ctx.player_position)
		check(app.quest_label.text==old.title and app.journal_guidance_snapshot.next_action==expected_instruction,"live HUD title/full instruction preserve independent expectation")
		check(app.world._quest_target_id()==expected_target,"live World/diamond/compass target matches independent expectation")
		check(semantic(app.journal_guidance_snapshot)==semantic(model),"host publishes complete independently checked semantic tuple")
		check(semantic(app.world.journal_guidance_snapshot)==semantic(model) and semantic(app.hud.journal_guidance_snapshot)==semantic(model),"World and HUD consume identical checked tuple")
		app._show_map();var chart=app.overlay.find_child("RegionChart",true,false)
		check(chart!=null and chart.current_target==expected_target,"real M consumer matches independent target")
		if chart!=null:check(semantic(chart.journal_guidance_snapshot)==semantic(model),"real M consumes checked tuple")
		app._close_modal();app._show_journal()
		var journal=app.overlay.get_meta("journal_ui",null)
		check(is_instance_valid(journal) and app.modal_actions.is_empty(),"real J has dedicated owner and no generic action fallback")
		if is_instance_valid(journal):check(semantic(journal.guidance_snapshot)==semantic(model),"real J current-guidance strip consumes checked tuple")
		app._close_modal()
		check(snapshot(s)==before,"consumer refresh and real M/J open/close retain complete state and zero saves")
		check(not seen.has(case_label),"each old observation is replayed exactly once")
		seen[case_label]=true;corpus_checks+=1
		await process_frame
	check(corpus_checks==117 and seen.size()==117,"all117 retained observations replayed; no skipped cases")
	check(changed==14 and unchanged==103,"exact14 reviewed changes and103 preserved targets; allowlist never broadened")

func combined_mentor_shen_negative_control()->void:
	# Additional actual-PCK characterized negative control, outside unchanged117
	# historical rows and exactly14 Qin fixes. Old full Main suppressed Shen's
	# legacy target when local mentor was pending; arbitrary World injection did not.
	label="combined_mentor_shen_negative_control"
	var s=NoSave.new();s._copy_persistent_from(Retained.from_retained("capstone_7_qingwei"))
	s.sect="听潮阁";s.sect_rank=1;s.sect_trial_won=true;s.level=3
	check(s.recruit_companion(),"combined negative control uses canonical earned Shen invitation")
	s.shen_care_stage=3;valid(s);context(s,Vector2(500,450));var before=snapshot(s)
	check(app.journal_guidance_snapshot.arc_id=="mentor_reward" and app.quest_label.text=="待领门中荐记" and app.world._quest_target_id()=="mentor","actual full-Main automatic mentor+Shen stays coherently mentor as old PCK")
	app._show_map();var chart=app.overlay.find_child("RegionChart",true,false)
	check(chart!=null and chart.current_target=="mentor","real M retains actual old combined mentor target")
	app._close_modal();app._show_journal();var journal=app.overlay.get_meta("journal_ui",null)
	check(is_instance_valid(journal),"combined prepared case opens real earned J")
	journal.browse("shen_care");journal.action_buttons.track.pressed.emit()
	check(app.journal_session.tracked_arc_id=="shen_care" and app.quest_label.text=="药箱之外" and app.world._quest_target_id()=="healer" and journal.guidance_snapshot.next_target_id=="healer","explicit real Track changes combined case coherently to earned Shen healer")
	app._close_modal();app._show_map();chart=app.overlay.find_child("RegionChart",true,false)
	check(chart!=null and chart.current_target=="healer","real M follows explicit Shen despite pending mentor")
	app._close_modal();app._show_journal();journal=app.overlay.get_meta("journal_ui",null)
	journal.action_buttons.auto.pressed.emit()
	check(app.journal_session.tracked_arc_id.is_empty() and app.world._quest_target_id()=="mentor" and journal.guidance_snapshot.arc_id=="mentor_reward","real Restore auto returns unchanged old combined mentor policy")
	app._close_modal();check(snapshot(s)==before,"combined auto/manual/auto does not claim reward, complete care, recruit, spend or save")
