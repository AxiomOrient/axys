#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION="${1:-commerce-checkout-default}"
URL="${2:-http://127.0.0.1:8000/}"
OUTDIR="${3:-PreviewApp/evidence/output}"
DRIVER="${4:-$SCRIPT_DIR/../drivers/agent-browser-driver.sh}"

mkdir -p "$OUTDIR"

"$DRIVER" "$SESSION" "$URL" "$OUTDIR"
