#!/usr/bin/env bash
set -euo pipefail
TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
node --test "$TEST_DIR"/*.test.cjs
python3 -B "$TEST_DIR/test_desktop_ui.py"
python3 -B "$TEST_DIR/test_search_navigation_ui.py"
