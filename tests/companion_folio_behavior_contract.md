# Companion folio: new bounded behavior and native proof

This is newly authored validation for the companion folio visual iteration based on source commit `058effd139c1b37dc47c905c9add1c5196eca8e6`. Authorship and static inspection are not execution evidence. No run is claimed in this contract. Existing recovery tests, native driver and reports remain unchanged.

## Files and preserved fixture

- `tests/party_roster_ui_test.gd` retains every prior state/behavior assertion and the save-count adapter. Only its incorrect no-save-API comment and geometry coverage change. Geometry now covers all pairs of actor areas, hero-left/three-rows-right, exact fixed display order, action/error target separation and repeated refresh node count, still at both 1280×800 and direct logical 1179×737.
- `tests/fixtures/companion_folio_20261006/party_roster_ui_test.gd.txt` is the exact pre-edit test (SHA-256 `81c3348c6ab68a1486f7dbec56c0f3d8c41bbeec243f4036c05e4f655acce96c`); adjacent manifest identifies its original source and byte count. This is a retained fixture, not a replacement passing report.
- `tests/companion_folio_behavior_test.gd` instantiates real Main and its exact production HeroState after ownership validation. It contains no game preload, save override, alternate save path, suppressed save callback, or model changes.
- External `../companion-folio-native-staging/companion_folio_native_capture.gd` extends the new behavior helper script. That inherited script contains no game preload and does not boot Main unless its deferred virtual `_run` passes its guard. Both driver and helper hashes are mandatory binding inputs. The original seven-family16-frame driver is unchanged.

## Isolation and reporting

Use only the independently reviewed parent launcher in a fresh externally owned QA root. Required environment variables are `HERO_FOLIO_QA_OWNED_ROOT`, `HERO_FOLIO_QA_USER_DIR`, `HERO_FOLIO_QA_TOKEN`, and `HERO_FOLIO_QA_REPORT`. The token must match `.hero-folio-qa-owner`; userdata must equal actual `user://` and OS user-data resolution. Reports must be fresh, external to source and userdata. Existing symlink ancestors, unexpected user files, incorrect ownership and unsafe paths are rejected before any game load. The outer launcher must verify an entirely empty profile immediately before engine startup; only engine-created `logs` or `shader_cache` directories may appear before the script starts, and their trees must be unlinked.

Behavior report: suite `companion_folio_behavior`, exact sections, checks, failures, raw canonical/transient state, map/position, save byte lengths/SHA-256/base64 and input trace. Each failure emits `ERROR`, writes a failed report and exits nonzero; report/guard failure also exits nonzero. A 150-second watchdog rejects incomplete execution. Raw failure checkpoints persist in the final report even after successful retry. A native subclass has its own180-second watchdog and report implementation.

## Coverage

1. Both inventory I→5 and actual HUD button origins, correct initial focus, Escape return target, actual ordinary inventory close and genuine save reload. Ordinary inventory close is expected to autosave. Save-content equality never claims no same-content write syscall.
2. Four stable cell identities and all four actual actor projections. Fixed visual ordering is independent of actual roster order. Hero remains mandatory and total capacity is four; unknown and duplicate entries are rejected.
3. Unrecruited empty slots, clues, disabled membership controls and no visible portrait/HP/Qi/action leaks. Browsing never calls recruitment or earns story progress.
4. Genuine downed/low independent HP/Qi numbers and bars, native mouse bench, Space rejoin appended at end, preserved resource values, original portrait crops/aspect mode. No healing, reward, resource spend, story advance or accidental membership mutation.
5. Native formation controls change only formation; repeated current formation stays pressed and preserves state/disk content. The retained adapter independently counts exact save calls.
6. Full cyclic Tab, Shift-Tab, Right, Down, Left and Up traversal using real input events. Expected ring explicitly excludes disabled/hidden controls, includes visible retry and ends with return. Enter, Space, pointer and Escape activate actual production controls. Hidden retry success moves focus to visible return.
7. All three story detours, recruited and unrecruited, from both origins. Real numeric story return restores origin. Repeated saved info/back/close, host change/return/story and immediately detached UI methods cannot revive or replace a newer page.
8. Real production FileAccess failure against a newly created empty `user://hero_save.json.tmp` directory, separately for each origin. Exactly one accepted Tang bench stays in memory while original raw disk bytes remain unchanged. Same formation, focus, view/return/reopen and repeated failed explicit retry cannot replay the accepted action. Only the test's own nonsymlink collision, verified empty including hidden files, may be removed.
9. Native retry button success persists the exact accepted roster/resources. A second genuine collision proves one accepted formation change, failed F5, collision removal and successful F5. Fresh real HeroState reload and Main F9 with a memory-only coin sentinel restore the whole saved canonical state, roster, formation and resources. Count adapters complement, never replace, this real-file proof.
10. A production-validator round-trip accepts the actual18-character legal hero name and wide values (level99, HP9998/9999, Qi98/99; level-adjusted companion values). Labels retain exact name and values; after layout settles, the actual maximum-name rectangle must not intersect role, status, portrait, HP/Qi labels or either bar at logical1280×800 and direct1179×737. These assertions use actual Label minimum-size/wrapping results rather than planned font width. Strict containment and font checks remain. Pixel/readability acceptance remains native review work.
11. Invalid live resource snapshots block HUD entry, clear stale portrait/numeric/action displays in the explanatory folio, and reject membership/formation operations. Restoring the valid value restores exact projections.
12. Quit-pending, battle-active flag and real unified training controller guards. Stale callbacks and blocked input preserve entire canonical state, battle/session/effect snapshots, position, save bytes, controller/generation and pending transaction. Actual retreat is separate lifecycle work; battle outcome correctness is outside this test.

## Native10-frame contract

The separate Linux driver requires the normal ownership contract plus fresh `results/native-binding.json`, matching `HERO_FOLIO_QA_NATIVE_BINDING` and its SHA in `HERO_FOLIO_QA_NATIVE_BINDING_SHA256`. It validates suite `companion_folio_native_capture`, exact source path, driver/helper/engine SHA-256, positive runtime entry count, runtime SHA-256, and40-character source commit/tree. The outer launcher owns the exact new runtime manifest and final source binding; the old fixed recovery runtime hash is never inherited. All HOME/XDG paths must resolve inside this owned Linux profile. This is not a Windows-ready claim.

Exactly ten full native PNGs, all under a fresh owned `results/native-frames`:

1. `01-unrecruited-1280` and `02-unrecruited-960`
2. `03-four-selected-1280` and `04-four-selected-960`
3. `05-mixed-order-bench-downed-1280` and `06-mixed-order-bench-downed-960`
4. `07-real-save-failure-1280` and `08-real-save-failure-960`
5. `09-legal-long-name-wide-1280` and `10-legal-long-name-wide-960`

The suffixes identify real physical1280×800 and960×600 framebuffers; logical1280×800 canvas geometry and the actual viewport transform are reported separately. Capture uses `RenderingServer.frame_post_draw` and the live root texture. No mock, baked composite or headless output qualifies. The screenshot report includes exact path/PNG bytes/SHA, framebuffer/window/viewport sizes, native display, complete canonical state, raw save bytes, application file hashes, control text/resources/fonts/rectangles/focus/portrait regions, input trace, prepared fixture provenance, and unchanged binding echo. Engine shader cache is inventoried separately.

The real failure pair contains the actual longest production modal failure notice and native retry focus. Retry button/F5 success and F9 reload are verified in the same run without adding extra screenshots. Both origins and all three story returns have real queued native input trace. Prepared fixture healing, recruitment and resource setup occur before baseline and are explicitly labeled; none is presented as journey progression earned by these tests.

Required success marker: `PASS: NEW companion folio native capture, 10 PNGs / … checks`. Passing process/report alone is not pixel acceptance: all ten files need independent visual inspection for long names, exact values, portrait identities/aspect, cloth/paper contrast, row and focus distinction, disabled controls, zero HP, error area and return.

## Budget and limits

No new engine/assets, source checkout copy, video, release package or cleanup is performed here. Exactly10PNG, at most50MiB per new capture run; retain original failed output and at most two new sets subject to parent review. Targeted logs/profile aim for150MiB, which is not a full-regression cap. Parent manages the overall2GiB iteration reserve and existing4GiB admission/2GiB free-space floor. Final full regression, packages, Web/browser smoke and publication each need their own final-byte binding and evidence.
