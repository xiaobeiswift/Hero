# Capstone phase-one combat implementation and earned evidence

Date:2026-10-03 UTC. Source baseline:5e71af1c4941eb9b95f25bbba3fe3132bbcad3b7. Scope:model/state-API verification only. No scene walk, rendered identity, art, playable chapter, publication or commit is claimed.

## Result

- Final official Godot4.6.3 run passed with isolated HOME/XDG paths and unchanged source hash brackets
- 3,225 shared automatic scheduler checks;4,715 existing Consignee model/legacy checks;5,934 new capstone model/old11 parity checks
- 67,471 earned-route checks;297 detached comparisons;198/198 active-policy wins;3/3 actual zero-coin/zero-medicine recovery wins
- Full88-case old11 transaction/snapshot JSON replay is byte-identical before and after edits, not merely outcome-equivalent

## Fixed authored encounter

- Encounter:capstone_authorizer at frostbridge/chapter_archive; sole enemy:liang_zhen, 梁缜·签令主事
- Entry HP620, independent of roster count, school, art, formation or previous ending
- Round1 guard:横令守锋26 raw damage; all received hits halve and round up
- Round2 heavy:压签重斩46 raw damage; no extra exposure/status effect
- Round3 recovery:收令回势8 raw damage; each received damage action gains the public10-point opening
- The same three-round cycle repeats; each living enemy executes one action. No wave, hidden healing, maxHP change, roster scaling or extra basic action
- Every living party actor retains exactly one automatic basic per completed round and fixed martial/internal/lightness slots. Existing guard, barrier, weakening, focus, lightness, finite medicine, cooldown and defeat/flee resource policies are reused
- Snapshot capstone_provenance is immutable and entry-stable:{liang_zhen_max_hp:620,reason:authored statement}. Only new-encounter snapshots receive it, preserving exact old snapshot shapes

## Earned entry lineage

Routes replay only documented scene-local opening callbacks and map travel; every battle/reward, invitation, gathered resource, lesson and later quest transition uses production State APIs. All routes retain starter sword/clothes, skip optional receipt, optional trial rewards and training grind.

| Cohort | Earned level/XP | Total earned XP | HP (听潮/照野/问石) | Qi | Medicine | Coins |
|---|---:|---:|---|---:|---:|---:|
| Never recruited, starter art, no lessons |6/135|1035|160/184/160|6|6|537|
| Genuinely recruited all3 companions, starter art |6/210|1110|160/184/160|6|7|557|
| Same recruitment, free lessons + owned school art |6/210|1110|160/184/160|6|7|557|

The cohort difference is actual optional companion-quest XP/rewards; none is used to prove the minimum. Each cohort is separately earned, not patched into another save. Nine full persistent entry documents are in balance-final.json. The minimum never-recruited solo correctly retains default并肩 because the existing State formation selector requires a recruited companion. Both formations, including solo with everyone benched, are covered using genuinely recruited cohorts.

## Minimum solo result

| School | Active timing rounds | Final HP | Medicine used |
|---|---:|---|---:|
|听潮阁|11|68/160|2|
|照野堂|12|75/184|2|
|问石门|12|100/160|3|

The existing immediate-when-useful policy also wins all three minimum routes. Idle solo loses; it is diagnostic and is not an acceptance gate.

## Genuine roster/formation matrix and timing

- Three schools × two builds × all eight genuine roster subsets × two formations × three policies =288 outcomes, plus9 minimum outcomes
- Policies:idle;existing immediate-when-useful queues;cadence-aware reserve pure damage for recovery, guard/lightness/barrier for the published heavy, Tang weakening before heavy, and deficit-based healing
- All99 existing-policy and99 cadence-policy outcomes win. Idle has82 wins and17 losses
- Every active full-party fight takes5–6 rounds, uses zero medicine, and actually presents both heavy and recovery phases. All24 full-party active cases record two real weakening and two barrier absorption events; acquired slots/cooldowns/targets remain ordinary
- The fixed-cadence policy improves at least one of round count, incoming damage or medicine in64/99 comparisons;3 are equal across those metrics,32 are worse. It is not universally optimal. School-art cooldowns and healing make earlier repeated skill use valuable; starter-art timing consistently benefits from the recovery opening
- Examples:minimum听潮 starter improves14→11 rounds and3→2 medicines;full-party听潮 school+lessons immediate policy wins round5 whereas waiting every damage art to recovery needs6;full-party照野护后 school+lessons timing reduces total incoming65→43 at equal6 rounds. Full per-case action/round/support records are retained
- Data620/26/46/8/+10 was an initial provisional candidate, then retained only after the complete earned matrix and spent-stock tests passed. No data tuning or stat inflation was required

## Genuine zero/zero recovery

Each school actually spends all6 medicines after real announced wounds and explicit flee/use_medicine. Each then undergoes68 genuine idle defeats to consume537coins via existing capped8-coin loss. No direct coin/medicine/XP/stat assignment or purchase is used. Every defeat preserves stage3, new-only Frostbridge(405,430), existing HP/Qi recovery, and no consumable refill.

After zero/zero is established:travel to existing lessons, learn internal/lightness and equip the already owned school art. Learning itself leaves HP/Qi/resources/XP unchanged. Explicit free rest alone restores HP/Qi. The retry wins with zero medicine and zero coins, no XP reward and no level/stat change.

| School | Retry rounds | Final HP | Total XP before/after |
|---|---:|---|---:|
|听潮阁|14|27/160|1035|
|照野堂|18|83/184|1035|
|问石门|15|119/160|1035|

## Stage/reward integration exercised

Six actual minimum State/API journeys (3schools ×2plans) prove no entry at stages1/2, issued-chain proof before battle, real terminal win3→4 with book only and0XP/coins, explicit classification4→5, desk disposition5→6 with0reward, and homecoming6→7 paying equal160XP/80coins exactly once. These are State API boundaries, not main-scene proximity tests. Independent state/schema owners own the terminal epoch/token/identity validator and migration.

## Exact old11 parity

Before editing Automatic/Unified, capture_legacy_traces.gd captured all11 historical encounters × solo/full-party × two formations × automatic/queued modes =88 cases. Entry snapshot and every accepted action transaction before round8/terminal are retained as full canonical JSON:68,529,477bytes per side. Only runtime epoch/token/pending_token counters are removed. No schema or gameplay normalization was needed or applied. Every field/event/snapshot/action byte otherwise matches; final diff is empty. The new test embeds the88 baseline hashes so future drift is testable without shipping the staged trace archive.

Legacy before/after model traces do not claim all historical state/save semantics; the independent state/migration reviewer covers old settlement/destination/progression behavior.

## Files and evidence

Owned source files:
- scripts/volume_one_capstone_combat_data.gd +UID
- scripts/automatic_party_combat.gd
- scripts/unified_encounter_rules.gd
- tests/capstone_combat_test.gd +UID
- tests/capstone_balance_test.gd +UID

Primary staged evidence:
- run_final_checks.sh;logs/final-summary.log
- baseline-source.sha256;final-source-before.sha256;final-source-after.sha256
- baseline-traces/ and after-traces/;logs/legacy-byte-diff-final.log
- balance-final.json;logs/balance-final.log
- logs/capstone_combat_test-final.log;logs/automatic_party_combat_test-final.log;logs/heting_consignee_combat_test-final.log

## Preserved failed attempts and limits

- balance-01.log:driver accessed nonexistent party_formation instead of existing formation; corrected test only
- balance-02.json/log:six invalid test assertions tried to select formations on never-recruited solo; existing API correctly rejected. Numerical active/recovery outcomes already passed. Fixed to test real default minimum; both formations remain fully covered on genuinely recruited cohorts
- balance-03.json/log:first clean67,471-check aggregate;final rerun repeats on unchanged hash-bracketed runtime
- No source commits, packages, exports or publication were made. No old tests, state/roster/pure rules/UI/art/runner/source docs were edited by this combat owner
- Generic render loops needing phase-one boundaries were reported to lead:automatic_party_battle_art_test;party_battle_backdrop_test;unified_combat_ui_test;visual_unified_combat;warehouse_backdrop_polish_test;record_heting_polish. unified_encounter_state_test also needs explicit new preparation or retained old11 coverage. Lead owns those boundaries; this report claims no new rendered art or main-scene chapter readiness
