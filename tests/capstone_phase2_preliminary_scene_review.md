# Independent capstone main-scene verification

## Result

- Main six-stop matrix: **PASS 48,348 checks, zero failures, 12/12 routes**
- Separate actual-scene battle/helper boundaries: **PASS 1,916 checks, zero failures, 2/2 boundaries**
- Baseline HEAD: `31ba4221d359a94523ef6a91f4f8a30fd72e87e8`; concurrent phase2 worktree, not a committed or exported/released build
- Only the two new test scripts and their UIDs were added by this worker. No runtime, existing tests, runner, commits, exports, publications, sessions or credentials were changed

## Reproduction

Run engines serially. Give each run an isolated XDG_DATA_HOME and XDG_CACHE_HOME.

```sh
XDG_DATA_HOME=<isolated-test-directory> XDG_CACHE_HOME=<isolated-test-directory> \
 godot --headless --path . --fixed-fps 60 \
 --script res://tests/capstone_independent_earned_scene_test.gd -- \
 --output=/absolute/staging/path/all-routes.json
XDG_DATA_HOME=<isolated-test-directory> XDG_CACHE_HOME=<isolated-test-directory> \
 godot --headless --path . --fixed-fps 60 \
 --script res://tests/capstone_independent_scene_interruptions_test.gd -- \
 --output=/absolute/staging/path/interruptions.json
```

The matrix also supports one exact case, e.g. `--case=听潮阁/solo/pause_batch`. Evidence/result autosaves additionally use a unique process+microsecond subdirectory. Runtime `save_game`/`load_game` are overridden only to isolate disk targets and inject explicit write failure. No production user save is read or written.

## Honest prerequisite and input boundary

Production State methods and actual combat token settlement earn opening, side quest, old archive, Mistwood, old harbor and actual consignee handover. Existing test helpers replay the exact original scene-local opening/sect callback effects where no public State method exists. Old map changes are API-test travel projections and are explicitly recorded as such. They are not walking evidence.

At each matrix route's beginning, that canonical earned state and the corresponding old consignee receiver position are transferred once to an actual main scene. After that point, all six capstone stops and four region transitions use held movement and actual E, numeric-key or mouse events. No scene test calls a capstone mutation wrapper to make progress. All battle commands also use actual keys/mouse, rather than direct `request_command` or model action calls. Actual PartyUI accepts, presents and acknowledges its own tokens naturally.

All six solo routes have never recruited any companion, keep starter sword/armor and starter martial, skip internal/lightness lessons and optional receipt, and leave Frostbridge's south bridge unrepaired. Four-party routes earn Shen/Tang/Qin recruitment and associated histories by production APIs; optional lessons are explicitly earned there, not borrowed by solo routes.

## Twelve-route matrix

Battle HP and medicine columns are before actual Liang fight → after fight/before homecoming. Every boss is one Liang at620HP. Every route receives **zero XP/coins on victory**, then **exactly160XP/80coins once at explicit elder confirmation**. Every case preserves its complete previous story/cargo/receipt snapshot.

| Route | World zoom | Hero HP | Medicine | Unique presented tokens | Real command inputs | Receipt |
|---|---:|---:|---:|---:|---:|---:|
| 听潮阁/solo/pause_batch | 100% | 160→68 | 6→4 | 26 | 5 | 0 |
| 听潮阁/solo/cancel_proven | 125% | 160→68 | 6→4 | 26 | 5 | 0 |
| 听潮阁/four/pause_batch | 160% | 160→138 | 7→7 | 37 | 13 | 0 |
| 听潮阁/four/cancel_proven | 100% | 160→138 | 7→7 | 37 | 13 | 0 |
| 照野堂/solo/pause_batch | 125% | 184→75 | 6→4 | 28 | 6 | 0 |
| 照野堂/solo/cancel_proven | 160% | 184→75 | 6→4 | 28 | 6 | 0 |
| 照野堂/four/pause_batch | 100% | 184→162 | 7→7 | 37 | 13 | 0 |
| 照野堂/four/cancel_proven | 125% | 184→162 | 7→7 | 37 | 13 | 0 |
| 问石门/solo/pause_batch | 160% | 160→100 | 6→3 | 29 | 7 | 0 |
| 问石门/solo/cancel_proven | 100% | 160→100 | 6→3 | 29 | 7 | 0 |
| 问石门/four/pause_batch | 125% | 160→141 | 7→7 | 37 | 13 | 0 |
| 问石门/four/cancel_proven | 160% | 160→141 | 7→7 | 37 | 13 | 3 |

Total actual held-input distance: 128,390.2 world pixels. Every per-frame position was checked against live walkable topology. Frostbridge north bridge and Sluice's existing always-open south stone bridge were physically traversed. No new topology, direct teleport, hidden rest or resource boost was introduced by tests.

Solo/public predecessors use `open_records`, `release_water`, `short_ferries`; four-party/protected predecessors use `protect_witness`, the actual access duel, `warn_ferries`, `open_scale`. Both consignee outcomes are represented in every school/party pair. These are deliberately paired prior branches, not a claim of a full cross-product of all historical choices. Opening ending is秉公 in these tests. One four-party问石门/cancel_proven route independently earns and compares the optional receipt (stage3); the other11 leave it unstarted. It never gates capstone admission.

## Interruptions and persistence in the main routes

- Closed invitation callback, changed modal generation, accepted desk callback and accepted homecoming callback reject replay without another save or resource change
- In-flight Tang/Qin evidence and Shen classification choices reject companions benched by the validated production roster API, refresh the actual methods page and retain the independent solo route; recruitment is never fabricated
- Wrong prewar responsibility answer and wrong four-order partition give feedback without state, cost or save changes
- Independent classification persists stage5 with an empty draft; clearing a draft does not undo classification
- Actual draft A→B→A rejects the first captured final-confirm callback; cancellation and90frames of waiting leave all four orders pending
- Every order keeps its stable ID; both plans cancel001/002, while003/004 are held or continue under existing checks, respectively
- Injected first-route save failure after referral, letter reveal, evidence, actual battle terminal, classification, desk commitment and homecoming preserves the prior exact disk and accepted memory result; retry only serializes
- Battle-entry save failure accepts no battle/cost; successful retry returns to readiness and still requires a separate real start choice
- Actual F9 reloads in every route preserve classified/empty-draft, committed/unpaid, and rewarded completion states
- Map/journal keys and Escape are read-only across active and completed stages; no repeated elder reward; completed goal ownership clears

## Separate actual-scene boundary harness

This harness has an explicit, separate initial API-earned stage3 transfer. It is **not** counted among the12 six-stop routes.

1. Actual P pauses for90frames. Actual key5 retreat keeps stage3 and no rewards. A second battle with no commands naturally defeats the hero; PartyUI settles the standard recovery at Frostbridge(405,430), loses exactly8coins, preserves medicine and pays no XP. The hero explicitly rests at Wen, physically walks back to the archive and wins through real battle input.
2. Hero/Shen fight without commands and retreat via real input. Three genuine retreats accumulate enemy-inflicted resource loss until Shen is0HP while hero survives. No HP write is used. The real four-member roster is restored through the validated API; the next real fight wins while Shen stays down. The party physically walks to the desk. Its actual methods page omits Shen, reports only solo availability, and accepts independent classification without reviving Shen or inventing contribution credit.

## Evidence and limits

- `all-routes.json` / `.log`: complete12-route states, input/position trace,103 interruption records and API-earned history
- `interruptions.json` / `.log`: complete natural defeat/flee/downed-helper boundary evidence
- `solo-first.json` / `.log`: earlier first-route diagnostic, superseded by full matrix
- `completion-inventory.json`: post-completion source/evidence hashes and HEAD. No pre-launch manifest was captured for either run, so before/after runtime byte invariance cannot be assessed. Wording and asset-manifest integration changed concurrently. These preliminary results do not bind an eventual commit; rerun both scripts on frozen bytes for that gate

The main matrix ran in a fixed60Hz headless engine, wall time about353.2s; this is **not human playtime, normal-clock performance, native pixel, browser, WebPCK or deployed acceptance**. Main routes classify at the physical desk; optional advance classification/drafting at the archive is separately covered by the story/controller suite, not by this matrix. Distance75 boundary, direct/malformed state admission, all-stale-map combinations and other adversarial controller checks also remain distinct focused-suite evidence. Native artwork/occlusion/wrapping and exported/browser storage/input require their own review.

An executor transport interruption occurred after the main run had returned exit0. The extra harness's exit status could not be retrieved through its lost session, but its complete retained JSON and terminal log independently record PASS1916/zero failures/two boundaries. A subsequent read confirmed both artifacts intact; no rerun was falsely claimed. Engines were then held for serialized native capture.
