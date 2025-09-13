#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-127.0.0.1}"
PORT="${2:-3456}"

mkdir -p logs
ts=$(date -u +%Y%m%d_%H%M%S)
log="logs/ascii_client_linux_${ts}.log"
latest="logs/ascii_client_linux.log"

echo "Connecting to ${HOST}:${PORT} (Ctrl+C to exit)" | tee "$log" >&2

if command -v nc >/dev/null 2>&1; then
  nc "$HOST" "$PORT" | tee -a "$log"
  cp -f "$log" "$latest" 2>/dev/null || true
  exit 0
fi

# Fallback to /dev/tcp if nc not present
exec 3<>"/dev/tcp/${HOST}/${PORT}" || { echo "Failed to connect" >&2; exit 1; }

# Reader
while true; do
  if read -r line <&3; then
    printf '%s\n' "$line" | tee -a "$log"
  else
    break
  fi
done &

# Writer
while IFS= read -r cmd; do
  printf '>> %s\n' "$cmd" | tee -a "$log" >/dev/null
  printf '%s\n' "$cmd" >&3
done

cp -f "$log" "$latest" 2>/dev/null || true

exec 3>&-
