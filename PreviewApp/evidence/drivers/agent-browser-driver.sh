#!/usr/bin/env bash
set -euo pipefail

SESSION="${1:?session is required}"
URL="${2:?url is required}"
OUTDIR="${3:?output directory is required}"

mkdir -p "$OUTDIR"

agent-browser open "$URL" --session "$SESSION"
agent-browser snapshot -i --session "$SESSION"
agent-browser screenshot "$OUTDIR/${SESSION}.png" --session "$SESSION"
