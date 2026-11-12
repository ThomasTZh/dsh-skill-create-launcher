#!/bin/bash
# Double-click entry point for @@PRODUCT_NAME@@.
# Terminal opens automatically for .command files; it closes when this process
# exits (subject to Terminal > Settings > Profiles > Shell > "When the shell exits").
set -u
cd "$(dirname "$0")/.." || exit 1
exec @@PYTHON@@ launchers/run-@@PRODUCT_SLUG@@.py
