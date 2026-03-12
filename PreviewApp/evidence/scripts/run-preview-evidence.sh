#!/usr/bin/env bash
set -euo pipefail

SESSION="${1:-commerce-checkout-default}"
URL="${2:-http://127.0.0.1:8000/index.html}"
OUTDIR="${3:-PreviewApp/evidence/output}"

mkdir -p "$OUTDIR"

agent-browser open "$URL" --session "$SESSION"
agent-browser snapshot -i --session "$SESSION"
agent-browser screenshot "$OUTDIR/${SESSION}.png" --session "$SESSION"
