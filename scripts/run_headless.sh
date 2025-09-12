#!/usr/bin/env bash
set -euo pipefail

# Run headless module tests and a quick ASCII console smoke test.
# Assumes `godot4` wrapper is on PATH and points to the 4.4.1 Linux binary.

mkdir -p logs

echo 'Running headless module tests...'
set +e
"$(dirname "$0")/godot4.sh" --headless --disable-dotnet --path . --script scripts/test_runner.gd 2>&1 | tee logs/headless_tests.log
test_exit=${PIPESTATUS[0]}
set -e
echo "Tests finished with exit code ${test_exit}. Log: logs/headless_tests.log"

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

cat logs/ascii_commands.txt | "$(dirname "$0")/godot4.sh" --headless --disable-dotnet --path . --script scripts/tools/ascii_console.gd -- --pipe 2>&1 | tee logs/ascii_smoke.log >/dev/null
echo 'ASCII smoke complete. Log: logs/ascii_smoke.log'

# Generate live event feed by booting the slice briefly, then copy the
# user event log into the repo logs folder for inspection.
echo 'Booting slice headless for event feed (8s)...'
timeout 8s "$(dirname "$0")/godot4.sh" --headless --disable-dotnet --path . scenes/VerticalSlice.tscn 2>&1 | tee logs/boot_headless.log >/dev/null

# Linux user path for Godot app data
USER_EVENT_LOG="$HOME/.local/share/godot/app_userdata/RPGBackendModules/event_feed.log"
if [ -f "$USER_EVENT_LOG" ]; then
  cp -f "$USER_EVENT_LOG" logs/event_feed.log || true
  echo "Event feed copied to logs/event_feed.log ($(wc -c < logs/event_feed.log) bytes)"
else
  echo "No user event log found at $USER_EVENT_LOG yet."
fi

exit ${test_exit}
