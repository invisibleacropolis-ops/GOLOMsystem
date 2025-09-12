#!/usr/bin/env bash
set -euo pipefail

# Run headless module tests and a quick ASCII console smoke test.
# Assumes `godot4` wrapper is on PATH and points to the 4.4.1 Linux binary.

mkdir -p logs
rm -f logs/headless_tests.log logs/headless_engine.log logs/ascii_smoke.log logs/ascii_smoke_engine.log

echo 'Running headless module tests...'
set +e
"$(dirname "$0")/godot4.sh" --headless --disable-dotnet --verbose --debug-stringnames --log-file logs/headless_engine.log --path . --script scripts/test_runner.gd 2>&1 | tee logs/headless_tests.log
test_exit=${PIPESTATUS[0]}
set -e
echo "Tests finished with exit code ${test_exit}. Logs: logs/headless_tests.log, logs/headless_engine.log"

echo 'Running ASCII console smoke...'
if [ ! -f logs/ascii_commands.txt ]; then
  # Provide a default command script when none exists.
  cat <<'EOF' > logs/ascii_commands.txt
spawn A 0 0
list
select 0 0
move 1 1
target 1 0
clear
remove A
end_turn
quit
EOF
fi

cat logs/ascii_commands.txt | "$(dirname "$0")/godot4.sh" --headless --disable-dotnet --verbose --debug-stringnames --log-file logs/ascii_smoke_engine.log --path . --script scripts/tools/ascii_console.gd -- --pipe 2>&1 | tee logs/ascii_smoke.log >/dev/null
echo 'ASCII smoke complete. Logs: logs/ascii_smoke.log, logs/ascii_smoke_engine.log'

exit ${test_exit}
