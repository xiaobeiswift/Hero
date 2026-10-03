#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
TEST_ROOT="${HERO_TEST_ROOT:-$(mktemp -d /tmp/hero-tests.XXXXXX)}"
mkdir -p "$TEST_ROOT/config" "$TEST_ROOT/data" "$TEST_ROOT/cache"
export XDG_CONFIG_HOME="$TEST_ROOT/config"
export XDG_DATA_HOME="$TEST_ROOT/data"
export XDG_CACHE_HOME="$TEST_ROOT/cache"
ENGINE="${GODOT_BIN:-godot}"
run_checked() {
  local log
  log="$(mktemp "$TEST_ROOT/check.XXXXXX.log")"
  python3 tools/run_godot_check.py "$ENGINE" "$@" 2>&1 | tee "$log"
  if grep -Eq '^(SCRIPT ERROR|ERROR):' "$log"; then
    echo "Godot reported an error; see $log" >&2
    return 1
  fi
}
run_checked --headless --path . --editor --import --quit
# Retired controller contracts are preserved and explicitly mapped to current
# coverage; no failed safety assertion is silently omitted.
python3 - <<'PYMANIFEST'
import hashlib
import json
from pathlib import Path
manifest = json.loads(Path("tests/regression_migration_manifest.json").read_text())
print("Current automatic-combat regression suite; historical controller evidence:")
for item in manifest["historical_controllers"]:
    assert Path(item["path"]).is_file(), item["path"]
    assert hashlib.sha256(Path(item["path"]).read_bytes()).hexdigest() == item["sha256"], item["path"] + " historical source changed"
    for replacement in item["current_replacements"]:
        assert Path(replacement).is_file(), replacement
    print("  Historical only: " + item["path"] + " -> " + ", ".join(item["current_replacements"]))
PYMANIFEST
# 未损先收: isolated quest/state/schema14 models plus real scene/transport/art.
# Exact Web pack and native pixel acceptance remain separately recorded.
run_checked --headless --path . --script tests/heting_consignee_rules_test.gd
run_checked --headless --path . --script tests/heting_consignee_schema_test.gd
run_checked --headless --path . --script tests/heting_consignee_state_test.gd
run_checked --headless --path . --script tests/heting_consignee_combat_test.gd
run_checked --headless --path . --script tests/heting_consignee_balance_test.gd
run_checked --headless --path . --script tests/heting_consignee_minimal_solo_test.gd
run_checked --headless --path . --script tests/heting_consignee_adversarial_test.gd
run_checked --headless --path . --script tests/painted_duhui_test.gd
run_checked --headless --path . --script tests/heting_consignee_art_test.gd
# Bounded paint-only harbor captions and warehouse depth; native pixel gates are separate.
run_checked --headless --path . --script tests/heting_route_label_test.gd
run_checked --headless --path . --script tests/warehouse_backdrop_polish_test.gd
run_checked --headless --path . --script tests/heting_consignee_geometry_test.gd
run_checked --headless --path . --script tests/heting_consignee_world_test.gd
run_checked --headless --path . --script tests/heting_consignee_story_test.gd
run_checked --headless --path . --script tests/heting_consignee_scene_test.gd
run_checked --headless --fixed-fps 60 --path . --script tests/heting_consignee_earned_scene_test.gd
run_checked --headless --fixed-fps 60 --path . --script tests/heting_consignee_earned_party_test.gd
run_checked --headless --path . --script tests/heting_consignee_recovery_test.gd
# Optional read-only old cloud-exported Web25 artifact boundary. This archive
# is not required to clone/run the source suite and is not the live Windows PCK.
if [[ -n "${HERO_WEB25_PCK:-}" ]]; then
  run_checked --headless --path . --script tests/heting_consignee_web25_reader_test.gd -- "$HERO_WEB25_PCK"
fi
# Save transfer is shipped default-off; opt-in tests use isolated synthetic bytes.
run_checked --headless --path . --script tests/local_save_transfer_test.gd
run_checked --headless --path . --script tests/save_transfer_ui_test.gd
run_checked --headless --path . --script tests/save_transfer_independent_test.gd
run_checked --headless --path . --script tests/save_transfer_independent_ui_test.gd
run_checked --headless --path . --script tests/browser_save_transfer_adapter_independent_test.gd
node tests/test_browser_save_transfer_dom.cjs
run_checked --headless --path . --script tests/companion_condition_display_test.gd
run_checked --headless --path . --script tests/companion_condition_independent_test.gd
run_checked --headless --path . --script tests/exploration_party_trail_test.gd
run_checked --headless --path . --script tests/exploration_party_adversarial_test.gd
run_checked --headless --path . --script tests/exploration_party_source_collision_test.gd
run_checked --headless --path . --script tests/exploration_party_world_integration_test.gd
run_checked --headless --path . --script tests/exploration_party_independent_review_test.gd
run_checked --headless --path . --script tests/exploration_party_render_consumers_test.gd
run_checked --headless --path . --script tests/painted_qin_walk_test.gd
run_checked --headless --path . --script tests/automatic_party_combat_test.gd
run_checked --headless --path . --script tests/automatic_party_battle_art_test.gd
run_checked --headless --path . --script tests/party_battle_backdrop_test.gd
run_checked --headless --path . --script tests/unified_encounter_state_test.gd
run_checked --headless --path . --script tests/unified_combat_ui_test.gd
run_checked --headless --path . --script tests/unified_practice_lifecycle_test.gd
run_checked --headless --path . --script tests/unified_terminal_close_test.gd
run_checked --headless --path . --script tests/automatic_combat_balance_test.gd
run_checked --headless --path . --script tests/automatic_trial_balance_test.gd
run_checked --headless --path . --script tests/category_status_badges_test.gd
run_checked --headless --path . --script tests/combat_skill_catalog_test.gd
run_checked --headless --path . --script tests/combat_learning_schema_test.gd
run_checked --headless --path . --script tests/combat_learning_ui_test.gd
# Retained direct legacy model/rules tests below are compatibility coverage.
# Actual current gameplay is established by automatic/unified suites above.
run_checked --headless --path . --script tests/state_test.gd
run_checked --headless --path . --script tests/party_combat_rules_test.gd
run_checked --headless --path . --script tests/party_roster_rules_test.gd
run_checked --headless --path . --script tests/party_state_integration_test.gd
run_checked --headless --path . --script tests/party_sluice_rules_test.gd
run_checked --headless --path . --script tests/party_sluice_state_test.gd
run_checked --headless --path . --script tests/party_archive_state_test.gd
run_checked --headless --path . --script tests/party_two_person_formation_test.gd
run_checked --headless --path . --script tests/party_sluice_art_test.gd
run_checked --headless --path . --script tests/party_battle_art_test.gd
run_checked --headless --path . --script tests/party_roster_ui_test.gd
run_checked --headless --path . --script tests/qin_companion_scene_test.gd
run_checked --headless --path . --script tests/audit_party_model_test.gd
run_checked --headless --path . --script tests/courtyard_exercise_rules_test.gd
run_checked --headless --path . --script tests/heting_receipt_rules_test.gd
run_checked --headless --path . --script tests/heting_receipt_combat_test.gd
run_checked --headless --path . --script tests/heting_receipt_art_test.gd
run_checked --headless --path . --script tests/formation_layout_test.gd
run_checked --headless --path . --script tests/formation_motion_test.gd
run_checked --headless --path . --script tests/opening_duel_formation_test.gd
run_checked --headless --path . --script tests/heting_receipt_story_test.gd
run_checked --headless --path . --script tests/courtyard_rig_art_test.gd
run_checked --headless --path . --script tests/courtyard_practice_art_test.gd
run_checked --headless --path . --script tests/browser_runtime_ui_test.gd
run_checked --headless --path . --script tests/audit_progression_test.gd

run_checked --headless --path . --script tests/audit_second_region_test.gd
run_checked --headless --path . --script tests/economy_test.gd
run_checked --headless --path . --script tests/workshop_ui_test.gd
run_checked --headless --path . --script tests/chapter_rules_test.gd
run_checked --headless --path . --script tests/frostbridge_ui_test.gd
run_checked --headless --path . --script tests/save_version_test.gd
run_checked --headless --path . --script tests/sect_rules_test.gd
run_checked --headless --path . --script tests/sect_ui_test.gd

run_checked --headless --path . --script tests/audit_companion_rules_test.gd

run_checked --headless --path . --script tests/audit_companion_increment_test.gd

run_checked --headless --path . --script tests/full_journey_test.gd

run_checked --headless --path . --script tests/advanced_balance_test.gd

run_checked --headless --path . --script tests/advanced_martial_rules_test.gd
run_checked --headless --path . --script tests/advanced_martial_ui_test.gd

run_checked --headless --path . --script tests/mistwood_rules_test.gd
run_checked --headless --path . --script tests/mistwood_geometry_test.gd

run_checked --headless --path . --script tests/mistwood_ui_test.gd

run_checked --headless --path . --script tests/local_save_slots_test.gd

run_checked --headless --path . --script tests/save_slots_ui_test.gd

run_checked --headless --path . --script tests/audit_manual_save_ui_test.gd -- --exercise-stale-callback-replay

run_checked --headless --path . --script tests/portrait_ui_test.gd

run_checked --headless --path . --script tests/shen_care_rules_test.gd

run_checked --headless --path . --script tests/shen_care_ui_test.gd

run_checked --headless --path . --script tests/lightness_rules_test.gd

run_checked --headless --path . --script tests/audit_shen_care_test.gd

run_checked --headless --path . --script tests/lightness_ui_test.gd

run_checked --headless --path . --script tests/audit_lightness_geometry_test.gd

run_checked --headless --path . --script tests/heting_rules_test.gd
run_checked --headless --path . --script tests/heting_geometry_test.gd
run_checked --headless --path . --script tests/heting_material_test.gd
run_checked --headless --path . --script tests/world_material_tiles_test.gd
run_checked --headless --path . --script tests/heting_machinery_test.gd
run_checked --headless --path . --script tests/heting_worksites_test.gd
run_checked --headless --path . --script tests/heting_world_test.gd
run_checked --headless --path . --script tests/audit_heting_scene_test.gd
run_checked --headless --path . --script tests/audit_heting_current_test.gd

run_checked --headless --path . --script tests/environment_visual_test.gd
run_checked --headless --path . --script tests/battle_choreography_test.gd

run_checked --headless --path . --script tests/painted_traveler_asset_test.gd

run_checked --headless --path . --script tests/render_visibility_test.gd

run_checked --headless --path . --script tests/painted_cast_test.gd

run_checked --headless --path . --script tests/hud_layout_test.gd
run_checked --headless --path . --script tests/hud_navigation_test.gd

run_checked --headless --path . --script tests/screenshot_feedback_test.gd

run_checked --headless --path . --script tests/painted_shen_walk_test.gd

run_checked --headless --path . --script tests/inventory_layout_test.gd

run_checked --headless --path . --script tests/painted_battle_hero_test.gd

run_checked --headless --path . --script tests/painted_battle_integration_test.gd

run_checked --headless --path . --script tests/painted_rival_test.gd

run_checked --headless --path . --script tests/ferry_backdrop_test.gd

run_checked --headless --path . --script tests/pause_menu_test.gd

run_checked --headless --path . --script tests/companion_feedback_test.gd
run_checked --headless --path . --script tests/painted_shen_combat_test.gd

run_checked --headless --path . --script tests/water_material_test.gd
run_checked --headless --path . --script tests/ferry_props_test.gd

run_checked --headless --path . --script tests/view_zoom_test.gd
run_checked --headless --path . --script tests/village_civilians_test.gd

run_checked --headless --path . --script tests/noticeboard_art_test.gd

run_checked --headless --path . --script tests/camp_shelter_test.gd

run_checked --headless --path . --script tests/painted_bamboo_test.gd

run_checked --headless --path . --script tests/tea_table_art_test.gd

run_checked --headless --path . --script tests/lantern_post_art_test.gd

python3 -m unittest discover -s tests -p test_export_archives.py
python3 -m unittest discover -s tests -p test_export_versions.py
python3 -m unittest discover -s tests -p test_sequential_exports.py
python3 -m unittest discover -s tests -p test_check_timeout.py
python3 -m unittest discover -s tests -p 'test_web*.py'

run_checked --headless --path . --script tests/dialogue_sheet_test.gd

run_checked --headless --path . --script tests/painted_tang_walk_test.gd


run_checked --headless --path . --script tests/view_detail_test.gd

run_checked --headless --path . --script tests/building_visibility_test.gd

run_checked --headless --path . --script tests/navigation_visibility_test.gd

run_checked --headless --path . --script tests/map_layout_test.gd

run_checked --headless --path . --script tests/martial_folio_test.gd

run_checked --headless --path . --script tests/audio_preferences_test.gd

run_checked --headless --path . --script tests/interaction_verbs_test.gd

run_checked --headless --path . --script tests/window_close_test.gd

run_checked --headless --path . --script tests/heting_notice_timing_test.gd

run_checked --headless --path . --script tests/heting_interaction_hints_test.gd

run_checked --headless --path . --script tests/heting_cart_routes_test.gd
run_checked --headless --path . --script tests/heting_cart_map_test.gd
