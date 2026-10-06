# New current-folio behavior validation

This staged test is newly authored against the recovered source. It does not recreate unavailable historical tests, recover their evidence, or certify the missing historical run. No engine execution or native capture was performed by its author.

## Files and isolation contract

- Integrated test: `tests/recovery_folio_behavior_test.gd` (same executable bytes as the reviewed staged file)
- Superseded pre-review candidate retained unchanged as `current_folio_behavior_test.reviewed_candidate_d7cde63e.gd`; its reload assertions were insufficient and it must not be treated as an accepted run
- No production file, historical test, or old report is edited
- The launcher runs this tracked test against the recovered checkout in place, independently verifies an empty exact `user://` in a fresh external QA profile, checks source hashes before/after, and supplies the environment contract below
- `HERO_FOLIO_QA_OWNED_ROOT`: fresh launcher-owned absolute QA root
- `HERO_FOLIO_QA_USER_DIR`: exact absolute `OS.get_user_data_dir()` under that root
- `HERO_FOLIO_QA_TOKEN`: at least 24 characters; matches `<owned root>/.hero-folio-qa-owner`
- `HERO_FOLIO_QA_REPORT`: fresh absolute filename under the owned root, outside userdata and the recovered checkout; its parent directory already exists
- The script independently rejects missing/mismatched ownership, symlink ancestors, unexpected userdata entries, and unsafe/existing report paths before any dynamic game load
- There are no game preloads and no save-replacing subclass. Main retains its genuine HeroState
- Check failures produce `ERROR`, a failed report, and nonzero exit. Guard/report failures also exit nonzero. A 120-second watchdog reports incomplete execution as failure

## Intended coverage

- Inventory: original five numeric actions, full-health/poor/no-companion disabled reasons, real pointer sword purchase (45 coins, +4 attack), numeric repeat rejection, both pointer/numeric formation changes, ordinary close persistence, 45/55-point medicine, K/B page switching, stale generations even when a previously unavailable purchase becomes affordable
- Martial: all three schools, unowned and learned pages, authored qi/cooldown/damage display, proficiency at 0/4/5/14/15 uses, every owned numeric equip entry, pointer base equip, preserved qi/cooldown/stats, old callback rejection, invitation and return choices
- Martial sizing: physical windows 1280×800, 1180×737, and 960×600; rectangles use the project's 1280×800 logical canvas. Current left-column boundaries replace the obsolete `x + width < 310` assertion
- Workshop: native menu navigation; three valid repeated iron purchases (8 coins each), timber purchase (5), exact blade/armor/medicine costs and bonuses, legitimate repeated medicine crafting, one-time equipment and insufficient-resource rejection, quest herb separation, saved callbacks after redraw/reopen, real Main reload, inventory reflection, material/coin trade caps
- Cultivation: real nearby mentor key interaction, all three schools, overview/detail/cancel/reopen, two- and three-merit learning, explicit no-autoequip, insufficient-merit rejection, one-point once-only sluice/archive deeds, old callbacks when balance later becomes sufficient, both learned-page navigation and explicit fourth-slot equip
- Failed save/retry: create only a new empty `user://hero_save.json.tmp` directory to make real production FileAccess writes fail; preserve old save bytes and exactly one in-memory purchase; retain the warning through success toast and ordinary close; remove only that verified empty owned directory; use queued F5/F9 to verify recovery without duplicate learning/charges
- Battle: real unified training entry; freeze only its established test-driver presentation scheduler; reject all folio shortcuts/direct opens, saved callbacks, direct learning/deeds; preserve canonical state, battle/effect/session snapshots, position, save bytes, controller and generation; exit through actual retreat and reopen inventory

## Evidence and limits

Each checkpoint records full canonical state, transient fields/session snapshots, world position/map, and save byte length/SHA-256. Assertions compare original save bytes in memory; successful persistence is reloaded with a fresh genuine HeroState. Ordinary modal close is intentionally allowed and expected to autosave.

Main reload checks deliberately perturb an in-memory coin balance while verifying saved bytes remain unchanged, then require `_load` or queued F9 to restore the complete saved baseline. Displayed damage uses exact first-segment comparison, and owned-detail navigation activates the actual `前往武学` pointer callback.

Byte equality verifies unchanged file content, not the absence of a same-content filesystem write. Prepared valid fixtures establish folio behavior, not natural story earning. This suite does not cover advanced combat effect resolution, full journeys, pixel appearance, contrast, or platform-native screenshot acceptance. Geometry alone is not visual acceptance.

## Failed run 01 and test-driver correction

The recovery run executed candidate `63acca579fc1485a96a88512bc49916feeba11d2fe68028c94a84d4f217211a3` against unchanged source. It completed 11,401 checks with 18 cultivation failures (six per school); this is a failed run, not accepted evidence. The exact candidate remains preserved as `current_folio_behavior_test.failed_run01_63acca57.gd`. Raw report and console remain at `../qa-current-folio-01/results/test-result.json` and `../qa-current-folio-01/logs/test.console.log`.

The recorded pre-deed states satisfy both production eligibility rules: inner disciple rank 2, completed/rewarded sluice story, completed archive with `protect_witness`, no prior claims, and one merit. The first pointer action was sampled immediately after synchronous mentor opening, before production `DialogueSheet._fit_npc.call_deferred` measured/recentered the NPC folio. The helper then waited a motion frame, allowing the target to move before its click. The stale coordinate can hit the preceding learning row, leaving the deed controls absent; subsequent direct model-backed claim explains the cascading state mismatches.

The new test-only correction settles a process frame before resolving pointer coordinates and verifies that the target still contains the queued coordinate after the motion frame. It additionally checks exact model eligibility and actual deeds-page navigation before reward assertions. No source fixture, deed cost/reward expectation, or production implementation changed. This revised candidate remains unrun until reviewed and executed.
