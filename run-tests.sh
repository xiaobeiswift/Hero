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
run_checked --headless --path . --script tests/state_test.gd
run_checked --headless --path . --script tests/courtyard_exercise_rules_test.gd
run_checked --headless --path . --script tests/heting_receipt_rules_test.gd
run_checked --headless --path . --script tests/heting_receipt_combat_test.gd
run_checked --headless --path . --script tests/heting_receipt_art_test.gd
run_checked --headless --path . --script tests/formation_layout_test.gd
run_checked --headless --path . --script tests/formation_motion_test.gd
run_checked --headless --path . --script tests/formation_ui_layout_test.gd
run_checked --headless --path . --script tests/opening_duel_formation_test.gd
run_checked --headless --path . --script tests/opening_duel_ui_test.gd
run_checked --headless --path . --script tests/heting_receipt_story_test.gd
run_checked --headless --path . --script tests/audit_receipt_ui_test.gd
run_checked --headless --path . --script tests/courtyard_rig_art_test.gd
run_checked --headless --path . --script tests/courtyard_practice_art_test.gd
run_checked --headless --path . --script tests/courtyard_practice_ui_test.gd
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
run_checked --headless --path . --script tests/battle_presentation_ui_test.gd

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
run_checked --headless --path . --script tests/shen_support_presentation_test.gd

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

run_checked --headless --path . --script tests/tang_support_presentation_test.gd

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
