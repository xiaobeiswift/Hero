# Capstone phase1 state/schema integration

2026-10-03 UTC. Implementation scope only. No scene, movement, art, earned-balance, browser-persistence, package, release, publication or rollout acceptance claim.

## Result

- Clean headless import and git diff --check
- capstone_schema_test.gd: **851 PASS**
- capstone_state_test.gd: **1225 PASS**
- Exact source/dependency/configuration and log hashes are in source-manifest.json
- Compatibility spot checks: existing Consignee State **954 PASS** and story boundary **157 PASS**
- Existing Consignee pure rules initially had **1 failure of18,483**, solely its obsolete expectation that version15 is unsupported. The lead owns adapting that current-ceiling assertion to16 and the aggregate suite. This report does not declare the entire repository suite passed

## Owned source changes

- scripts/game_state.gd: schema15 with explicit14 retained; only capstone_stage/draft/ending persist; reset, serialization, restore, raw validation, whole-state comparison and field completeness integrated
- scripts/party_roster_rules.gd: supported payload ceiling15 only. Recovery, recruitment, rest, growth, roster and resource policies unchanged
- scripts/heting_consignee_rules.gd: INTRODUCED_VERSION14 and MAX_SAVE_VERSION15; compatibility SAVE_VERSION alias remains14. Required six-field completeness remains introduced14, not ceiling15
- scripts/heting_consignee_story.gd: full-state validation uses host.state.SAVE_VERSION
- New tests/capstone_schema_test.gd and tests/capstone_state_test.gd, each with generated UID
- Frozen tests/fixtures/v028_game_state.gd.txt and .provenance.json

No runner, aggregate test, project-version, scene, asset, enemy module, new rules module or repository-document edits made by this worker. Shared module edits belong to their respective workers.

## Atomic progression and resources

Detached, whole-state validated wrappers:
begin_capstone; reveal_capstone_letter; resolve_capstone_evidence; classify_capstone_orders; choose_capstone_plan; confirm_capstone_disposition; finish_capstone_homecoming.

Noncombat commits verify the allowed whole-state delta and explicitly exclude stage3→4. Classification persists stage5 with an empty draft. Draft change/clear has no operational effect. Wrong answers, partitions, maps, stale expected plans and same-state actions have no mutation.

Only a real accepted terminal presentation can commit stage3→4. It binds the same controller instance, host/controller epochs, encounter/battle identity, pending token, exact emitted snapshot, fixed sole enemy ID/spec/provenance, exact roster and accepted HP/Qi/medicine/proficiency, plus every unchanged noncombat entry field. Changed session, transient encounter, enemy spec, progress, resources or forged snapshot rejects without unlocking. Duplicate acknowledgement cannot settle twice.

Victory adds only the ordinary victory statistic, no capstone XP/coins/classification/disposition. Defeat retains existing up-to8-coin loss and recovery semantics; the new encounter alone changes its destination to Frostbridge(405,430). The unchanged existing policy restores all recruited companions on defeat, including benched/downed members. Tests explicitly record that behavior; no capstone exception was invented. Entry, load, roster selection, proof, classification and draft add no healing.

Homecoming consumes stage7 before the XP callback, awards equal160XP/80coins for either plan under existing caps, and independently checks the exact ordinary growth delta. Tests cover no level-up, one/multiple level-ups, capped level99/coins, callback reentry and duplicate actions. Ordinary XP level-up heals the hero; existing companion absolute resources, including zero, remain unchanged.

Same-target save failures are forced with an existing .tmp directory. Each accepted stage retains its in-memory result, the prior valid disk file stays byte-exact, and retry serializes without replaying actions or rewards. This is accepted-in-memory behavior, not crash durability.

## Migration and authentic old reader

The old reader was frozen before editing its source and compared with runtime commit8a8b580fdd03ceaa5ca6be8160a299a12877360a:
- Bytes72931
- SHA256160fe884cd9e80966cf94493020cb2a9454957e54bc7c0def72754bc95e03fd5
- Git blobb5bbe1f304a0e562e77d0a9c2d2a054bcee16b09
- Public source referencee1f8b420

The test removes only the HeroState class-name declaration in memory. Its dependencies resolve from current source. Its own true14 control succeeds; an actual current writer15 document rejects with ERR_FILE_UNRECOGNIZED before any old persistent/transient script variable or subject byte changes. This is an authentic source-reader gate, not full historical runtime proof.

The separate retained Web28 PCK was not copied into source or loaded by this worker. A separate-process full-old-runtime gate remains the lead's optional independently scoped work.

Coverage includes all prior formats1–14, every partial subset of the3-field bundle on each legacy version, present malformed data, canonical15 completeness, every old14 mandatory field including the entire Consignee bundle, schema12–15 strict extras, malformed headers/types/stages/relations, future16, all stages and both plans, unpaid stage6 already at Qingwei, slots/backups, exact-byte transfer and occupied/backup/temp-slot protections. Transfer remains default-off.

Legacy provenance is honest: genuine producers1 and9–14; authored old-layout contracts2–8. Old wounds, roster, resources, stories, cargo destinations and optional receipt state remain exact.

## Defects caught and fixed during integration

1. Active in-memory stages succeeded while every JSON roundtrip failed because the new rules initially compared parsed numeric array [2.0,0.0,1.0] to integer array [2,0,1] using type-sensitive array equality. The rules owner replaced that with exact length plus finite integral element checks. This accepts JSON integral numbers without normalization. All stage/slot/import gates now pass.

2. Independent migration review exercised actual deployed Qin starting at qi0. His ordinary basic regenerated qi, but generic extra-progress equality considered Capstone.progress.party_resources immutable, rejecting an otherwise authenticated terminal. For this encounter only, that redundant generic comparator is skipped after the stronger full-entry/exact-accepted-resource validator. Other11 comparators remain unchanged. New regression uses attack50, actual Qin qi regeneration, downed deployed Shen and wounded benched Tang; victory settles while preserving the latter two.

## Remaining gates outside this worker's scope

Independent migration review completion, genuine earned solo/four-member playthrough and combat balance, aggregate legacy suite adaptation, scene site/proximity/generation guards, actual new defeat movement, dialogue/art/UI and any eventual exact-package/publication acceptance.
