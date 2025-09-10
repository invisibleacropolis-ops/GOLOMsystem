#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p logs
ts=$(date -u +%Y%m%d_%H%M%S)
log="logs/editor_launch_linux_${ts}.log"
latest="logs/editor_launch_latest.log"

set +e
"$ROOT_DIR/godot4.sh" --path . --editor --disable-dotnet "$@" 2>&1 | tee "$log"
code=${PIPESTATUS[0]}
set -e
cp -f "$log" "$latest" 2>/dev/null || true

# Summarize PASS/FAIL with basic crash detection
crash=0
if grep -q "handle_crash" "$log" 2>/dev/null; then crash=1; fi
pass=1
if [ "$code" -ne 0 ] || [ "$crash" -eq 1 ]; then pass=0; fi

summary_path="logs/editor_launch_linux_status.json"
summary_ts="logs/editor_launch_linux_status_${ts}.json"
{
  echo "{"
  echo "  \"mode\": \"linux\"," 
  echo "  \"started_at\": \"$(date -u -r \"$log\" +%Y-%m-%dT%H:%M:%SZ)\"," 
  echo "  \"finished_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"," 
  echo "  \"exit_code\": $code,"
  echo "  \"crash_detected\": ${crash},"
  echo "  \"log\": \"$log\"," 
  echo "  \"latest\": \"$latest\"," 
  echo "  \"pass\": ${pass}" 
  echo "}"
} > "$summary_path"
cp -f "$summary_path" "$summary_ts" 2>/dev/null || true

if [ "$pass" -eq 1 ]; then
  echo "EDITOR RUN: PASS (exit=$code) log=$log"
else
  echo "EDITOR RUN: FAIL (exit=$code crash=$crash) log=$log" >&2
fi

exit $code
