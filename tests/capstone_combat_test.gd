extends "res://tests/heting_consignee_combat_test.gd"
## Synthetic high-HP fixtures isolate mechanics only. Earned victory/balance
## belongs to capstone_balance_test.gd; these values never establish balance.
const Capstone = preload("res://scripts/volume_one_capstone_combat_data.gd")
const OLD_ELEVEN: Array[String] = ["story", "training", "sect_trial", "courtyard_practice", "sluice_scout", "sluice_boss", "archive_boss", "mist_scout", "mist_keeper", "heting_receipt", "heting_consignee"]

func _run() -> void:
	_capstone_fixed_cadence()
	_capstone_guard_opening()
	_capstone_entitlements()
	_capstone_support_timing()
	_capstone_cancel_pause_flee_terminal()
	_capstone_old_eleven_parity()
	print("%s: %d capstone model and old11 parity checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _capstone_fixed_cadence() -> void:
	for count: int in range(1, 5):
		for formation: String in ["并肩", "护后"]:
			var model = _rules(_team(count, 1, 1000, Arts.BASE_ART, formation), Capstone.ENCOUNTER_ID)
			var entry: Dictionary = model.snapshot()
			check(entry.capstone_provenance == Capstone.endurance() and entry.capstone_provenance.is_read_only(), "Fixed detached immutable provenance")
			check(entry.enemies.size() == 1 and entry.enemies[0].id == "liang_zhen" and entry.enemies[0].name == "梁缜·签令主事", "One original authorizer, never recycled named boss")
			for round_number: int in range(1, 7):
				_to_round(model, round_number)
				var view: Dictionary = model.snapshot()
				check(view.enemies.size() == 1 and view.enemies[0].max_hp == Capstone.endurance().liang_zhen_max_hp and view.capstone_provenance == entry.capstone_provenance, "No new wave/scaling/midfight maximum change")
				check(view.enemy_intents.size() == 1, "One living enemy publishes exactly one intent")
				var intent: Dictionary = view.enemy_intents[0]
				var cadence: Dictionary = Capstone.phase("liang_zhen", round_number)
				for key: String in ["phase", "name", "damage", "heavy", "guarded", "opening"]:
					check(intent[key] == cadence[key], "Announced and actual cadence field " + key)
				check(intent.type == "attack" and not intent.exposes, "No extra enemy action or new vulnerability application")
				check(intent.description.contains(str(intent.damage)) and intent.description.contains("入场气血") and intent.description.contains("三轮循环"), "Intent names actual damage, fixed health and cadence")
				check(view.enemies[0].brace == cadence.guarded and view.enemies[0].opening_bonus == cadence.opening, "Snapshot's visible guard/opening equals execution")
				var expected: String = "hero" if formation == "护后" else String(Catalog.IDS[(round_number - 1) % count])
				check(intent.target_id == expected, "Existing formation publishes truthful target")
	check(Capstone.phase("old_boss", 1).is_empty(), "Unknown enemy cannot acquire capstone cadence")
	var detached: Dictionary = Capstone.endurance()
	detached.liang_zhen_max_hp = 1
	check(Capstone.endurance().liang_zhen_max_hp != 1, "Changing returned entry cannot alter authored fixed data")

func _capstone_guard_opening() -> void:
	var model = _rules(_team(1, 11, 1000), Capstone.ENCOUNTER_ID)
	check(_event(_step(model), "damage", "hero", "liang_zhen").amount == 6, "Guard rounds halve damage once and round up")
	_to_round(model, 2)
	check(_event(_step(model), "damage", "hero", "liang_zhen").amount == 11, "Heavy rounds have neither guard nor opening")
	_to_round(model, 3)
	check(_event(_step(model), "damage", "hero", "liang_zhen").amount == 21, "Recovery's public ten-point opening applies to one independent hit")
	var previous: int = model.snapshot().enemies[0].hp
	while model.snapshot().active and model.snapshot().round < 7:
		var tx: Dictionary = _step(model)
		check(tx.after.enemies[0].hp <= previous, "Recovery never heals enemy")
		previous = int(tx.after.enemies[0].hp)
		for actor: Dictionary in tx.after.actors:
			check(int(actor.status.vulnerability_hits) == 0, "Authorizer adds no unannounced exposure")

func _capstone_entitlements() -> void:
	var model = _rules(_team(4, 1, 1000), Capstone.ENCOUNTER_ID)
	check(model.queue_skill("hero", "art:照夜一线", "liang_zhen").ok and model.queue_skill("hero", "lightness:hero_tawei", "hero").ok, "Known fixed slots queue independently")
	var basics: Array[String] = []
	var actions: int = 0
	while model.snapshot().round == 1:
		var tx: Dictionary = model.advance()
		check(tx.accepted and tx.events.is_read_only(), "Accepted immutable action")
		var locked: Dictionary = model.snapshot()
		check(not model.advance().accepted and model.snapshot() == locked, "Presentation gate prevents extra action")
		check(not model.complete_presentation(tx.token - 1), "Wrong token cannot release gate")
		if tx.action_id == "attack": basics.append(tx.source_id)
		if tx.source_id == "liang_zhen": actions += 1
		check(model.complete_presentation(tx.token) and not model.complete_presentation(tx.token), "Exactly one acknowledgement")
	check(basics == ["hero", "shen", "tang", "qin"] and actions == 1, "Exactly once per living actor and one enemy, despite queued categories")
	check(model.snapshot().actors[0].qi == 9, "Three martial plus two lightness Qi spent, basic restores exactly two")
	for actor: Dictionary in model.snapshot().actors:
		check(actor.actions.size() == 5, "Only fixed three slots plus medicine/flee")
		for index: int in 3: check(actor.actions[index].category == Rules.CATEGORIES[index], "Fixed category order")
	var invalid: Dictionary = _team(4)
	invalid.actors.append(invalid.actors[1].duplicate(true))
	check(not Rules.new().configure(invalid, Capstone.ENCOUNTER_ID), "Five actors rejected")
	invalid = _team(); invalid.actors[0].hp = "160"
	check(not Rules.new().configure(invalid, Capstone.ENCOUNTER_ID), "Invalid numeric input cannot configure")
	check(not model.accept_action("attack").accepted and not model.accept_action("guard").accepted, "No extra manual basic or free guard")

func _capstone_support_timing() -> void:
	var model = _rules(_team(4, 1, 1000, "磐石回锋", "护后"), Capstone.ENCOUNTER_ID)
	_to_round(model, 2)
	check(model.queue_skill("hero", "art:磐石回锋", "liang_zhen").ok, "Existing guard queued against announced heavy")
	check(model.queue_skill("hero", "lightness:hero_tawei", "hero").ok, "Existing lightness queued against same heavy")
	check(model.queue_skill("tang", "art:tang_fenjin", "liang_zhen").ok, "Tang weakening uses sole target")
	check(model.queue_skill("qin", "art:qin_shoudu", "hero").ok, "Qin barrier uses announced front actor")
	var heavy: Dictionary = {}
	while model.snapshot().round == 2:
		var tx: Dictionary = _step(model)
		if tx.source_id == "liang_zhen": heavy = tx
	check(not heavy.is_empty() and _event(heavy, "action", "liang_zhen").damage == 46 and _event(heavy, "action", "liang_zhen").weakened == 5, "Announced heavy46 uses real weakening5")
	check(_event(heavy, "damage", "liang_zhen", "hero").amount == 0, "Existing guard/lightness/barrier reduce heavy to zero without new status")
	check(not _event(heavy, "lightness_absorb").is_empty() and not _event(heavy, "barrier_absorb").is_empty(), "Defense order exposes actual lightness then barrier absorption")
	check(_unit(heavy.after, "hero").status.barrier == 0 and _unit(heavy.after, "hero").status.next_hit_reduction == 0, "Consumed one-hit support is not retained")
	var dead_team: Dictionary = _team(4, 1, 1000)
	dead_team.actors[0].hp = 0
	dead_team.actors[1].hp = 0
	var surviving = _rules(dead_team, Capstone.ENCOUNTER_ID)
	check(not surviving.select_actor("hero") and not surviving.queue_skill("shen", "art:shen_xumai", "tang").ok, "Dead actors cannot contribute support")
	check(surviving.snapshot().enemy_intents[0].target_id == "tang", "Formation starts with actually living actor")
	check(_step(surviving).source_id == "tang" and _step(surviving).source_id == "qin", "Each surviving roster member still gets independent basic")

func _capstone_cancel_pause_flee_terminal() -> void:
	var team: Dictionary = _team(2, 1, 1000)
	team.actors[0].hp = 900
	var model = _rules(team, Capstone.ENCOUNTER_ID)
	check(model.queue_skill("shen", "lightness:shen_liuying", "shen").ok and model.cancel_queued("shen", "lightness"), "Queue cancellation spends nothing")
	check(_unit(model.snapshot(), "shen").qi == 12 and not model.cancel_queued("shen", "lightness"), "Cancellation idempotent")
	var item: Dictionary = model.accept_action("item")
	check(item.accepted and item.after.medicine == 2 and item.after.actors[0].hp == 945 and not item.after.actors[0].basic_done, "Finite medicine does not steal automatic basic")
	check(model.set_paused(true) and model.complete_presentation(item.token) and model.snapshot().paused, "Pause at exact presentation boundary")
	check(not model.advance().accepted and model.set_paused(false), "Paused scheduler requires explicit resume")
	var flee: Dictionary = model.accept_action("flee")
	check(flee.after.outcome == "flee" and flee.after.medicine == 2 and flee.after.actors[0].hp == 945, "Flee keeps actual consumption/healing and no victory")
	check(model.complete_presentation(flee.token) and not model.advance().accepted, "Terminal flee has no post-outcome action")
	var killing = _rules(_team(4, 1000, 1000), Capstone.ENCOUNTER_ID)
	check(killing.queue_skill("tang", "art:tang_fenjin", "liang_zhen").ok, "Queue future actor before terminal kill")
	var first: Dictionary = _step(killing)
	var terminal: Dictionary = _step(killing) if first.after.active else first
	check(terminal.after.outcome == "win" and terminal.after.enemies.size() == 1, "Single opponent down is sole victory")
	check(_unit(terminal.after, "tang").qi == 12 and not _unit(terminal.after, "tang").categories.martial.queued, "Terminal cancels future categories without charge")
	check(not killing.advance().accepted, "No extra wave after win")

func _capstone_old_eleven_parity() -> void:
	# Captured before editing Automatic/Unified at exact5e71af1c. Each digest
	# hashes complete canonical JSON of entry plus every snapshot/transaction,
	# with only runtime epoch/token/pending_token counters removed. Full bytes
	# are retained under staged combat/baseline-traces and after-traces.
	for id: String in OLD_ELEVEN:
		for count: int in [1, 4]:
			for formation: String in ["并肩", "护后"]:
				for manual: bool in [false, true]:
					var key: String = "%s-%d-%s-%s" % [id, count, formation, str(manual)]
					check(_legacy_trace(Rules.new(), id, count, formation, manual) == OLD_TRACE_HASHES.get(key), "Old11 complete trace equality: " + key)

const OLD_TRACE_HASHES: Dictionary = {
	"archive_boss-1-并肩-false": "7fd42183e1d0c21a2109012fd057e8634aee8c3dbf7bc549327c65d02fa89aaf",
	"archive_boss-1-并肩-true": "57fa498b83053277b01eebf1b77e8286ff331642a21fb30c7825ee6c6793ca47",
	"archive_boss-1-护后-false": "5e9dbde68e8ce4dc4c4d64db76926e3f8355cb58ee9cd24e45bf6147c4954934",
	"archive_boss-1-护后-true": "baa7e79286e8efdc0cf35867035aafc497ef96ad014d7fb80fe87d79d6353292",
	"archive_boss-4-并肩-false": "0e64cb7fb200177f11614c18231b0940a02b70c5d1c080205dab871c8e6e1806",
	"archive_boss-4-并肩-true": "f11e712c9f10c80a87806a89b2699af5a38ca77ac42a72a2c70093103a0a567f",
	"archive_boss-4-护后-false": "91c605033ed8655c9884cab19e127364c98018aff53427a0595d1ea4de7bfe28",
	"archive_boss-4-护后-true": "da24f920226bcc581536a96b0cd9820c11d5ddf2ce0f1fb2b741d3a66a9f1f8f",
	"courtyard_practice-1-并肩-false": "48e2cf766861ad1aa17790f813e55335e26174cbb144ebb7aa2beaf1918c3dcd",
	"courtyard_practice-1-并肩-true": "d6b053b80a0f570f209d9cd5a45c7f537c3e014d5438b0aa6fb6d00c3a939409",
	"courtyard_practice-1-护后-false": "905ae55f40a048501e810be66a4df4fd93c2e676cea31481e685a4fd041e990e",
	"courtyard_practice-1-护后-true": "a2f644fa4940f71564e157964d425edce16ab606d6a958766b9a049c1c898793",
	"courtyard_practice-4-并肩-false": "9b0c389c3bc4beabc183cb0e5016853a19f2cec441d36c55215b76b0928b09b5",
	"courtyard_practice-4-并肩-true": "6e854af7a34309b5a99db985f227c6e39b328e1ecbb424f29a58d9dd97593335",
	"courtyard_practice-4-护后-false": "d1a5ab2485dea2d1a81279f4a87f0dba77778636cf973c015b78762e74c4e441",
	"courtyard_practice-4-护后-true": "3db83f591eb3772be885c80aeba4fca6c4f9333677c18bb1c1d8abf25cd849be",
	"heting_consignee-1-并肩-false": "ec097d0ae130e2116f4a8e5047da581b8a5b466ece1bca0354c942f95eda8dc0",
	"heting_consignee-1-并肩-true": "f901df9bd257758a4ac5456080c4b0a1a7b179c480e4adfe823b8796a8f51bb5",
	"heting_consignee-1-护后-false": "f28e1a65e299973e5d74275af6163d658aac84018d169d9ab48a8f83bb942ab0",
	"heting_consignee-1-护后-true": "fdb40c9c5c9bf999e9cf571bd755573fa4f32c7c9af8564bfd87efe07e1728e4",
	"heting_consignee-4-并肩-false": "70a3f6a64d13b2f1513e7d113c6617c02872f9672cd1f31736f45b1c4067ed86",
	"heting_consignee-4-并肩-true": "c0f6b157d316ff2912fd69e94cb7c4fe822183923c0716acea97e42c271d34a9",
	"heting_consignee-4-护后-false": "5a7f206344a6e121bf71c41896ff173cd4c2d238fe296b83ed4fa4d99a75d385",
	"heting_consignee-4-护后-true": "c16c6a0b1a2f2a9ac5df0ee41b6cf03489c07944564a288a9d3544f36f6c025d",
	"heting_receipt-1-并肩-false": "a8a6f3bf3cbf772d8b194656b4af0d8e8fb131d774d2521e504887ae3d84c6a5",
	"heting_receipt-1-并肩-true": "a9a486b8309fbc5be2a0b18d508f22c1b3b07b13727c408d164198ce701120d0",
	"heting_receipt-1-护后-false": "8352e2e84c7f0a484a44a509e3628747820f3a742ba1f825ed1900600c86923e",
	"heting_receipt-1-护后-true": "a1dd0b65e1bf1e9c72cf38f53f905c15835ff4fe404214e3ca54b4369d6c8077",
	"heting_receipt-4-并肩-false": "9d8c894589b8f0693007be435275758e971d7772185dba7784654e164c076020",
	"heting_receipt-4-并肩-true": "987a5b5d9b9fcf8f514628f8b6d4719022f7ddc82864c0850b94cbec12add04f",
	"heting_receipt-4-护后-false": "9a113a7c40db8170945e0e7090d35038114b83898da2e39d5d54484b534c6376",
	"heting_receipt-4-护后-true": "4bbb17d52d514828c970b567b06ba036c4f8515e8b5aad58c1df5673fc09547c",
	"mist_keeper-1-并肩-false": "3a217d8e0215d3966c7793259d47f30f2aecd052d8d1e9648ba5026dc1f53c99",
	"mist_keeper-1-并肩-true": "8bfccf5c5af0d9a9c24b8465e7ecb96d0498f7b916cd1cfc3741b22263b7d5cf",
	"mist_keeper-1-护后-false": "1365c79eb70f94943d039e0108e43fca42497c4e0b9d05b87fca777cecd67829",
	"mist_keeper-1-护后-true": "d4fd9c3916b2065e3124d1d705b1a428178bbc759b078654715f36502823027f",
	"mist_keeper-4-并肩-false": "72bf238816bdbdda0df2c82afedf936a4c2e1dd0f25b8f8d266dee2c3e1eaac3",
	"mist_keeper-4-并肩-true": "e79a68dfc20d8543bcd8eac30c7e34bedd2faf0389d45613915db7ff82dc154e",
	"mist_keeper-4-护后-false": "5e9e84098224256b4c839db09210f1e63167c1ad338150203218414bd73def9d",
	"mist_keeper-4-护后-true": "7a77716c91f38af7aa588a16473fa1ccfa616fe971b798fed7f646d1c0f6c2d1",
	"mist_scout-1-并肩-false": "080d4e6b942c8f274b83d32c495f15f519df6007b58dd3e43e6e8d61c7aced62",
	"mist_scout-1-并肩-true": "224c517204bc40d6aa33ad3fe35f320b363c7877ebced5ca462cc9294638e8b1",
	"mist_scout-1-护后-false": "1b3477848839b0e97dc6d5488aa5a77835f95105a572b105fa868e125f81aaf0",
	"mist_scout-1-护后-true": "967475ae606a35956d87f2ae258221f877ce38ad4c0fd3a69a815fc90b2b13e1",
	"mist_scout-4-并肩-false": "676fb49e8658ab4e732003ec7ffbc9e76d8d1df0c5393b77f17c53b56421dc34",
	"mist_scout-4-并肩-true": "2e30d7bb9ec4b73f35e7d7c27280c9e46f464dee69a2be248051d62acd7eb4ee",
	"mist_scout-4-护后-false": "e89ca1e20d6bed741bc0d0742735c1b2dcfa5a5eb63a6d9e1630f47b33af245c",
	"mist_scout-4-护后-true": "a8f1a210e047cb47b9d888b60aa82bf5a446f287a0376f5094c21ede12220eed",
	"sect_trial-1-并肩-false": "e502c0cdba1e660734e829f938c5729b856b0b34b3cba33a2af5ab47a265d5f3",
	"sect_trial-1-并肩-true": "b4c1e5ca953ca62ae321e1866a4c201071aaef5a9cd04c8ec819720e3b60e9bf",
	"sect_trial-1-护后-false": "2c3f8ff2e5195d42c7872079f1aea7e28fb4c17450da6944a911c05cbb05cd0f",
	"sect_trial-1-护后-true": "90ad74388beff04417a648c79fbe9f22ce9ad07a575a1dcc22ec12d2be2d3aaa",
	"sect_trial-4-并肩-false": "39e956ac5b645fc310fd7954857179a815a8267fb1019603cee1bdf07430d6c3",
	"sect_trial-4-并肩-true": "bcf114f8ad7b11ce5be460eb288e61bf576d6ed51f17c3e9488f6af7fdefcfda",
	"sect_trial-4-护后-false": "bf51fb8956c3b5c6261185df99eda93dc1f401cb0d7013c5d30a53f12951f223",
	"sect_trial-4-护后-true": "df9cba381b1a74800b853035e71a46dfbb0196cd8842fe5a86b8d049133a04e0",
	"sluice_boss-1-并肩-false": "7aa86bd49a6c73bb4e02331b1291548ce69d5eaae4d93406a0cdaa74c0c1bf4a",
	"sluice_boss-1-并肩-true": "f5738c1fd0eea1f8e18eee1660e4866b0890f7a23380bef8ea51667a1d11b32c",
	"sluice_boss-1-护后-false": "54adedcab8d15d74352349e5e4a62299f0a3d758c0deeb6982ce52e950088231",
	"sluice_boss-1-护后-true": "f346904ece2d8a459bb49dc0be73a4ba18ad5917a967b7a77b087243aaf111a5",
	"sluice_boss-4-并肩-false": "bf42ca23360ea9a94e20a2cf0fb5d9b1162224a553a3c2f97418f382210626a5",
	"sluice_boss-4-并肩-true": "dff1f2e9f9f554fc065b983852d2d9dbad16c3d97de3efcf75301795b2d1a1b3",
	"sluice_boss-4-护后-false": "10269c42963ef4b0bcbde2e6fbc3bf2ddaa38734380ee6014e0a54fcf0815655",
	"sluice_boss-4-护后-true": "68996de809ef22cb5a7d2f02b1d9e6d74dae3734d7e44e5967d79f4afb4b30dc",
	"sluice_scout-1-并肩-false": "c3a544850eb1dc21c8cd12b646c07fa0ef5886316bbac1ae13b2b10644884894",
	"sluice_scout-1-并肩-true": "8ecfab7835268f7586da15fdd730e63fbc0f801f0f30f3d8c0ffffb00a3372d0",
	"sluice_scout-1-护后-false": "7b9d6599fa6d6e4cead6bd29b62920cb5bc2637551bff4bdb5e660f970eb2860",
	"sluice_scout-1-护后-true": "a542dfa7362e4a19064e4a1ea97b97a0426baba764f80cf0c257216a3a079dc5",
	"sluice_scout-4-并肩-false": "74b63db39a8a00be234a5dd97ddb4a727da359dcb42ceb5543d44e9c689bd4b7",
	"sluice_scout-4-并肩-true": "5ff6e10ba22900dc4144caffc6351bc22bfdb5956419acac660529130959e7b2",
	"sluice_scout-4-护后-false": "9cf1b38a3f412fd801e22b307cfed440c58fc9862feac72d839f0bc4a3e68f89",
	"sluice_scout-4-护后-true": "6a14f3f7f36ccbeaf635d9a8b279188c0f59b2c358ff10ed09815faf0e3a2ee8",
	"story-1-并肩-false": "81fc459825b6c066257cf6279f72f3ec4d0acab30a1f6261277a35355d3c386b",
	"story-1-并肩-true": "8c8dc3282cfdcc7d9355789cc20114eb41773d816e248d4c6be6aa3d5118d41e",
	"story-1-护后-false": "5ce0a4e60de6144035f891830a80de7f813a3f3926f4cdbb3b4038b55b8ce51a",
	"story-1-护后-true": "52cf8a97c28a8d9bf3e8e156f1d5f0dc0501d408ff99af6a8faea59c0450ef20",
	"story-4-并肩-false": "97c90ae9aac56b65ade44a7e3acfd363bf671edcbc47696a42b7358391830083",
	"story-4-并肩-true": "fc746d8abbc261b138e33071907df0c53c4cf47c9719f647282424bddb5f0393",
	"story-4-护后-false": "337e49972035760b8abe770e8f7411c92adde4d5f4ad63648c90b4bbf602a65d",
	"story-4-护后-true": "432356d7e5181ee5c75309667f9528e8628bf6bd401e87a429963cb6eefb4002",
	"training-1-并肩-false": "25f06d020ad7f93f10f6ab91c326cf284c8f3240facf40e372ef002ea7bd01e5",
	"training-1-并肩-true": "c56c935bd946c2f9d5b27ece61d26b631e7372e29daa26bbb1b29ec76108d98f",
	"training-1-护后-false": "10aadb1f959ea1e4b713c3a6657b1e7982a63fc41e219398b735b6844e6b10aa",
	"training-1-护后-true": "abdfb1768a6e22e7f6e59a29d5043ed5a13daa75581d48171a989a8e7a2fe845",
	"training-4-并肩-false": "ac2456c42be397835e53679e001830bf4d5622da3866fba84820db8b8e28ee70",
	"training-4-并肩-true": "ad79e55f985075141f3eabc4977ce745b7c79d7a4f0da6fb538606d2549306a8",
	"training-4-护后-false": "fb038d5a605c07a9cf86bcb787f190525023b43fdc1cb285bcb1a82f74a33ec1",
	"training-4-护后-true": "9ee8140a78e4f7cbc4d171e2fedbb51d992a96cadc06832e9c789deb244d5abe"
}
