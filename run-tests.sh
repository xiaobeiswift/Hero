#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
TEST_ROOT="${HERO_TEST_ROOT:-$(mktemp -d /tmp/hero-tests.XXXXXX)}"
mkdir -p "$TEST_ROOT/config" "$TEST_ROOT/data" "$TEST_ROOT/cache"
export XDG_CONFIG_HOME="$TEST_ROOT/config"
export XDG_DATA_HOME="$TEST_ROOT/data"
export XDG_CACHE_HOME="$TEST_ROOT/cache"
ENGINE="${GODOT_BIN:-godot}"
"$ENGINE" --headless --path . --editor --import --quit
"$ENGINE" --headless --path . --script tests/state_test.gd
"$ENGINE" --headless --path . --script tests/audit_progression_test.gd

"$ENGINE" --headless --path . --script tests/audit_second_region_test.gd
