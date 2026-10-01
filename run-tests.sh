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
  "$ENGINE" "$@" 2>&1 | tee "$log"
  if grep -Eq '^(SCRIPT ERROR|ERROR):' "$log"; then
    echo "Godot reported an error; see $log" >&2
    return 1
  fi
}
run_checked --headless --path . --editor --import --quit
run_checked --headless --path . --script tests/state_test.gd
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

run_checked --headless --path . --script tests/environment_visual_test.gd
run_checked --headless --path . --script tests/battle_choreography_test.gd
run_checked --headless --path . --script tests/battle_presentation_ui_test.gd

run_checked --headless --path . --script tests/painted_traveler_asset_test.gd

run_checked --headless --path . --script tests/render_visibility_test.gd

run_checked --headless --path . --script tests/painted_cast_test.gd
