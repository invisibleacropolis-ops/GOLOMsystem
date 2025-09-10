#!/usr/bin/env bash
set -euo pipefail

# Run headless module tests and a quick ASCII console smoke test.
# Assumes `godot4` wrapper is on PATH and points to the 4.4.1 Linux binary.

mkdir -p logs

echo 'Running headless module tests...'
set +e
godot4 --headless --path . --script scripts/test_runner.gd 2>&1 | tee logs/headless_tests.log
test_exit=${PIPESTATUS[0]}
set -e
echo "Tests finished with exit code ${test_exit}. Log: logs/headless_tests.log"

echo 'Running ASCII console smoke...'
{
  echo 'spawn A 0 0'
  echo 'list'
  echo 'select 0 0'
  echo 'move 1 1'
  echo 'target 1 0'
  echo 'clear'
  echo 'remove A'
  echo 'end_turn'
  echo 'quit'
} > logs/ascii_commands.txt

cat logs/ascii_commands.txt | godot4 --headless --path . --script scripts/tools/ascii_console.gd 2>&1 | tee logs/ascii_smoke.log >/dev/null
echo 'ASCII smoke complete. Log: logs/ascii_smoke.log'

exit ${test_exit}

