#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_DIR="${1:?rendered preview bundle directory is required}"
SESSION="${2:-preview-shell-smoke}"
PORT="${3:-4173}"
OUTDIR="${4:-PreviewApp/evidence/output}"
DRIVER="${5:-}"
SERVER_LOG="${OUTDIR}/${SESSION}.server.log"
SERVER_URL="http://127.0.0.1:${PORT}/"

mkdir -p "$OUTDIR"

python3 -m http.server "$PORT" --directory "$BUNDLE_DIR" >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!
trap 'kill "$SERVER_PID" >/dev/null 2>&1 || true' EXIT

for _ in $(seq 1 50); do
  if python3 -c 'import sys, urllib.request; urllib.request.urlopen(sys.argv[1], timeout=0.2).read(1)' "$SERVER_URL" >/dev/null 2>&1; then
    if [[ -n "$DRIVER" ]]; then
      "$SCRIPT_DIR/run-preview-evidence.sh" "$SESSION" "$SERVER_URL" "$OUTDIR" "$DRIVER"
    else
      "$SCRIPT_DIR/run-preview-evidence.sh" "$SESSION" "$SERVER_URL" "$OUTDIR"
    fi
    exit 0
  fi
  sleep 0.1
done

echo "preview shell server did not become ready: $SERVER_URL" >&2
exit 1
