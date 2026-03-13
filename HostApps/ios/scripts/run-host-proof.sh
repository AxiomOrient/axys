#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

"$REPO_ROOT/HostApps/scripts/run-host-proof.sh" ios "${1:?sample root is required}"
