# Capstone phase2 world and navigation implementation

Source baseline: `31ba4221`; source edit scope: `scripts/world.gd`, `scripts/frostbridge_region.gd`, new navigation helper and new owned tests/UIDs only. No commit, export, publication, deployment or permission changes.

## Interface

Main syncs `world.capstone_stage`, `capstone_draft`, `capstone_ending`, `capstone_goal = Rules.goal(state)`, `capstone_orders = Rules.order_rows(state)`, then `refresh_capstone_points()`. Orders are fresh read-only view objects; no saved flag, extra mutable batch, inventory item or pickup loop.

`VolumeOneCapstoneNavigation.resolve(goal, current_map)` returns detached Rules goal facts plus `target_id`, `destination_map`, `is_exit`; `target_id(goal,current_map)` is a convenience. `world.capstone_navigation()` exposes the same resolver. All five maps use existing adjacent exits. Empty stage7 goal releases normal optional priorities. Invalid/empty goals safely return empty.

## World behavior

- Desk `capstone_order_desk` is at(1340,650), legal southern approach(1340,690), visible after acceptance. Stages1–3 show no future book/orders. Stages4+ draw exactly four model-numbered sheets. A draft changes no sheet disposition. Stage6/7 render two cancellations plus two holds/continuations from model rows, with readable semantic captions and backed name labels.
- The desk is Y-sorted with actors and unchanged scenery. All deployed actor feet drive its occlusion and the existing prompt placement. No new collision, map, teleport, bridge, resource policy or follower topology.
- Stage2+ clerk ledger is a small prop attached to the existing clerk site; no overlapping interaction point.
- Archive stage3 uses the original accepted Liang static idle at exactly72 visible pixels from the battle-art helper. It bypasses Han completely. Stages4+ use an empty stand with a book-taken receipt, no duplicate book or repeated enemy. Stage0 restores old art branches and exact old points.

## Verified so far

- `capstone_navigation_main_test.gd`:2,089 checks across8stages×5maps×3zooms×2render qualities; real main HUD objective/next-exit copy, cross-map chapter heading, actual map/chart point names and target, repeated read-only map open/close, completed optional tracking
- `capstone_navigation_test.gd`:389 checks, all8stages×5maps, same-map targets, every existing adjacent exit, detached Rules data, real world/chart consumers, conflicting optional goals, stage7 priority restoration
- `capstone_world_test.gd`:11,188 checks, prepared canonical fixtures; actual held Input actions driving world fixed-step processing and actual E key events at74.9/75/75.1; three followers; legal southern Sluice desk/bridge route; north Frostbridge loop with south bridge unrepaired; old-NPC disambiguation; exact four rows; pending A→B→A/cancel; save/reload/reset; all-map stage0-versus1–7 collision sampling; all-actor opacity/prompt consumers
- `capstone_world_render_consumers_test.gd`:249 draw-call checks; one desk, fixed sheets/stamps, all followers, no Han/Liang stacking, empty-table aftermath, reset actor/label sequence
- Existing `exploration_party_render_consumers_test.gd`:26 checks; `exploration_party_source_collision_test.gd`:660; `exploration_party_adversarial_test.gd`:6020
- Whole editor import succeeded without script errors. Existing navigation_visibility/hud_navigation tests pass; exploration_party_world_integration:91 and independent_party_review:307,211 pass
- `collision-source-audit.json`: exact baseline-source comparison of walkability, steps, river geometry, follower topology/all-actor consumers and Frostbridge building/tree constants, all unchanged

## Evidence limits and remaining gates

Prepared fixtures and fixed-step world input are not earned chapter progress, native pixel review, whole-main interaction safety, real-time performance or browser acceptance. Scene owner handles earned dialogue/battle routes. Native review should inspect desk at the legal southern approach, clerk ledger, Liang standing and book-taken aftermath at100/125/160% zoom; captions intentionally sit above approaching actor bodies. No pixel-parity claim has been made for stage0.
