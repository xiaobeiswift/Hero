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
