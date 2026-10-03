# Capstone phase 2: independent actual-source continuity review

Reviewed 2026-10-03 UTC. Result: **PASS for the bounded narrative/continuity gate on the exact reviewed source snapshot, following four narrow corrections and one read-only preservation addition. No remaining blocker found in this scope.** This is not a release, full-scene, earned-playthrough, movement, native visual, exact-PCK, or combat-acceptance verdict.

## Scope and provenance

- Actual source: `Hero-recovery-20261002-0918/source`
- Published model baseline: `31ba4221`; earlier playable-story baseline: `606ea478`
- Reviewed the current `volume_one_capstone_story.gd`, current rules, exact lead diffs in main/Frostbridge/consignee/harbor/receipt code, and original companion/old-story evidence
- Read design/draft reviews as constraints, not as evidence that the game already implemented them
- Source was read-only for this reviewer. Tests, copied script snapshots and reports were written only under this staging directory. No credential/session access, Git mutation, network publication, or external state change
- Exact SHA256 bindings, baseline full commits and copied-source equality are in `source-binding.json`. At binding time all 15 reviewed files matched the isolated probe snapshot
- Reviewed story SHA256: `e87e576a1f617361c220ec01a5f89f1c20d5c10df3248408172fa31c5a5329ce`
- Reviewed rules SHA256: `e94be62c7c9afc1bc536be0dd22f4e8915fd2de8de776a1da76006a01a5f98a6`

## Findings corrected during review

1. **Invented Tang teaching history, fixed.** Story variant at line 1622 and rules method description at line 155 formerly said he had taught boatmen a document-copying sequence. Original `companion_story.gd:12,16,56` establishes transmitting the craft notebook to apprentices; the separate consignee method (`heting_consignee_rules.gd:157`) establishes an unloading-force sequence, not a document-copying lesson. Both current capstone strings instead draw on the craft notebook's copying/review practice. No helper prerequisites or reward logic changed
2. **Future book acquisition described as completed during stage 3, fixed.** C9 (`volume_one_capstone_story.gd:559`) formerly described the “later obtained” pending book even when read before battle. Current text distinguishes the two books and explicitly says an unobtained pending book cannot support the prior finding
3. **XP-cap reward receipt, fixed and reproduced.** Original `_homecoming` selected the unqualified “160修为、80铜钱” result solely from the coin delta. A canonical prepared stage-6 state at level 99, XP 5939 and coins 24 completed with XP delta 0 while reporting 160. The current code uses the cap-aware receipt whenever final level is 99 or coins are capped; the same actual Story callback now truthfully reports capped XP and 80 coins. Logs retain before/after proof. Reward rules were unchanged
4. **Optional receipt's permanent “last night / this next morning” wording, fixed.** `heting_receipt_story.gd:62–63,133,165,171` is still reachable after capstone completion. These current texts use 此前 / 交割后的复核, with both branches retaining the historical next-morning event. In particular the open-scale branch says “交割后的次晨已换过轮值”, rather than deleting the original event. No receipt progress requirement was changed

5. **Full original harbor manifest preserved, including declined referral.** `HetingStory.manifest_body()` extracts the exact prior read-only text. The guarded capstone old-story page exposes 查看原交割单, and A0 now offers 另谈鹤汀旧事 before the referral is accepted. This avoids losing old content or reusing unguarded legacy callbacks. Independent execution compares its full output with `31ba4221`'s actual original `manifest()` for both harbor endings at stages 0, 1 and 7; closing/returning/stale callbacks make no progress, resource or save changes

The parent and story owner made those source changes. This reviewer did not edit game source.

## Actual-source continuity results

### Letter, author and player agency: pass

- B0 (`story:100`) begins with Wen's existing custody and takes the original from his box. B1 (`:130`) compares original and retained draft. B2 (`:155`) has his direct authorship admission
- The watermark is a trace from a suspect old order, expressly not his private seal; it is not an identity proof or an invented attachment
- No ancestry, predestination, chosen-person history, planned player path, or advance knowledge of the later Heting batch was introduced
- B3 (`:185`) acknowledges that protecting couriers did not justify withholding authorship; it explicitly leaves forgiveness to the player. The required return action is “收回原信，记下说明”, not forgiveness
- B4/B5/B6 (`:210,240,275`) keep return and later rereading separate. After the accepted stage transition there is no second return/re-taking action. Frostbridge's old long-lived line (`frostbridge_story.gd:35`) is likewise stage-aware
- Reading the letter, asking the optional question, or closing the page does not heal, reward, or advance. Explicit free rest remains offered at B0 and B5

### Separate issued register and pending book: pass

- C1/C2/C3 (`story:320,345,370`) actually expose all four specific authorizations before responsibility is accepted: 甲17改时, 甲18雨录列损, 乙06旧船按损票, 乙09新两篓预结收货
- The responsible office/individual and actions are concrete: 梁缜·签令主事, 核准与交发. Externally retained old-gate orders, Mistwood copy and Heting slips are named separately; a shared watermark alone is rejected
- The new annotation “先按水损撤运，实查后补” supports the specific pre-inspection authorization. The prose does not claim Liang previously knew every true reading, directed every flood, hired the receipt attackers, ordered every lantern action, or bears every old-year responsibility
- The first evidence answer cannot normally bypass C1→C2→C3 (`_show` read-chain guard). Wrong answers give explanations without changing saved resources or progress
- Evidence accepts stage 2→3; only actual battle settlement may produce 3→4. D0/D1/D4 and journal state the fight preserves the distinct pending book and access, rather than establishing guilt. Revisit R1 does not reopen the fixed fight

### Important historical-source boundary

The literal labels `霜签甲17`, `霜签甲18`, `霜签乙06`, `霜签乙09` are **newly authored capstone details**, first expanded by this new register scene. Literal searches of both `606ea478` and `31ba4221` old source returned no matches. Older source established an original/revised order differing by an hour, common watermark, prepaid grain entries, readings/consignment identifiers, dry grain and the southern authorization column; it did not previously print these four exact IDs or name Liang as their authorizer.

The current new scene supplies those missing particulars. The exact lead changes to old stories do not insert these new IDs into earlier testimony or claim that the old chapter already identified Liang. Do not describe these IDs in development/release evidence as pre-existing old-source testimony. `original-source-evidence.md` records exact historical-source lookups.

### Witnesses, grain and old branches: pass

- Protected-name variants retain closed identity pages and use only identifiers/times. Open-record variants acknowledge that earlier publication happened and do not pretend it was reversed
- The old two loads, new two baskets and four pending orders remain different objects/batches
- `hold_for_inspection` retains the full samples in Heting; the record does not transport them remotely to Frostbridge
- `return_to_owner` uses prior inspection, cancellation and return records. It neither recreates a full sealed sample nor takes the already returned grain back
- Both short-ferry/open-scale historical labor allocations survive, including their different costs. No branch receives invented exclusive capstone evidence
- Receipt 0/1/2 do not claim completed verification; receipt 3 is only supplemental evidence about the original two loads. No receipt stage gates capstone completion
- Consignee's post-completion journal and completion text now identify the subsequently verified upstream responsibility at stage ≥3, without waiting for battle victory or falsely announcing the whole case solved
- Lu Bo's old direction no longer says “upstream / go downstream”. Luo's old opening action is not erased by the new upstream signature

### Four finite orders and explicit disposition: pass

- 001 cites the same disproved rain event and ruler position; 002 cites the same disproved inspection/signing sequence. Neither assumes old dry grain proves all future cargo dry
- 003 and 004 are independently numbered unverified matters. The text does not call them false, cleared, automatically dispatched or already inspected
- Stage 4 exposes evidence but does not silently accept classification. Stage 5 preserves accepted classification even when the draft is empty, cancelled or changed
- Both endings cancel 001/002. The remaining two are either held for review or remain in ordinary verification/signoff, with clear handover responsibility to the clerk's office and gate duty team
- No real-time clock, hidden deadline, automatic dispatch on rest/travel/close, retroactive undoing of old orders, duplicate cargo or extra order inventory exists in these rules/callbacks
- Final disposition is at the physical gate desk. G1/G2 list quantities, irreversible consequence, responsible follow-up and reward location. Their **first** option is safe “返回核对”; the committing action is second. Main maps Enter/Space to index 0 (`main.gd:339–345`), so repeated default Enter cannot settle the batch. H0 likewise puts “先看回条” first and explicit homecoming second

### Reward and continued play: pass within tested scope

- Battle/classification/draft/disposition give no completion XP/coins. Stage 6→7 at Lu Bo consumes completion before the reward callback and grants the same base 160 XP / 80 coins in both endings, under existing caps
- The new receipt accurately distinguishes normal reward, cap-aware award and actual level-up recovery. No opening/closing/revelation is described as healing
- Defeat text matches the existing max-8 coin loss, full-HP/at-least-2-QI recovery at the Frostbridge inn exterior; flee does not refund used resources. Existing recruited-party recovery rules were reviewed, not rewritten
- Repeated postgame home/desk/clerk/Wen pages have no re-award, re-fight, second original-letter return or plan-edit action
- The game says the first volume is complete, not that the project is 1.0 or every side story/old case is finished
- Capstone interception is limited to its own six sites. Tang/bridge, Shen care, Qin recruitment, martial study, receipt at the public scale and old free-rest sites retain their existing routing; Wen's free-rest action is explicitly preserved before and after reveal

### Companion methods: pass after Tang wording correction

`available_methods` requires the actual relevant personal-history choice plus recruitment, current deployment and positive HP. Solo is always available for either evidence domain. Scene dispatch rechecks eligibility before using the helper and before accepting the conclusion. A later bench/down state does not undo an accepted fact. Persistent revisits do not invent named helper contribution history because the minimal capstone save model stores none. Qin compares timing records, Tang transfers a recorded craft-copying practice, and Shen compares the actual waiting/transfer consequences; none magically identifies an author or authenticates all paperwork by vocation.

## Independent execution evidence

`probe/` contains a copied current-script snapshot with a minimal project and fake modal host. It executes actual story/rules/state functions, using explicitly prepared canonical states. No game-source writes occurred.

- `continuity-probe.log`: **1,975 checks, 0 failures**, including 128 canonical combinations of opening ending × record privacy × harbor ending × consignee ending × receipt stage × capstone ending, and 1,408 rendered postgame page bodies with no unresolved placeholders
- Runtime checks cover original custody/admission/return, free-rest availability, no changes while reading, mandatory C1–C3 sequence, wrong-answer invariance, classification separate from drafting, both default-safe confirmation paths, exact finite order outcomes, no pre-homecoming reward and once-only postgame behavior
- `reward-cap-before-fix.log`: the real original XP-cap receipt defect
- `reward-cap-after-fix.log`: same canonical state and callback against corrected source, truthful capped-XP output
- Full original manifest equality and guarded reachability were independently checked at inactive stage 0, active stage 1 and completed stage 7 for both harbor endings
- Main's actual default-key mapping and optional-site routing were source-inspected. These prepared-host tests do not claim native input, collision/pathing, visual legibility, genuine earned history, real battle victory, save-disk retry semantics, full regression or exact exported-package acceptance. Those remain the respective phase-2 gates

## Final disposition

The reviewed actual source meets the requested narrative boundaries. All concrete issues raised in this review were fixed and rechecked. Any later edit to the bound files requires a focused recheck; this pass does not authorize publication or replace the remaining scene/combat/package gates.
