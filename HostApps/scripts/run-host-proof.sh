#!/usr/bin/env bash
set -euo pipefail

PLATFORM="${1:?platform is required}"
SAMPLE_ROOT="${2:?sample root is required}"
PROOF_ROOT="$SAMPLE_ROOT/HostProof"
MANIFEST="$PROOF_ROOT/proof.manifest.json"
GENERATED_ROOT="$SAMPLE_ROOT/GeneratedUI/$PLATFORM"
WRAPPER_ROOT="$SAMPLE_ROOT/HostSmoke/$PLATFORM"
LOGS_ROOT="$SAMPLE_ROOT/BuildArtifacts/$PLATFORM"
SUMMARY="$PROOF_ROOT/${PLATFORM}.host-proof.summary.txt"

[[ -f "$MANIFEST" ]] || { echo "missing manifest: $MANIFEST" >&2; exit 1; }
[[ -d "$GENERATED_ROOT" ]] || { echo "missing generated mount root" >&2; exit 1; }
[[ -d "$WRAPPER_ROOT" ]] || { echo "missing host smoke root" >&2; exit 1; }
[[ -d "$LOGS_ROOT" ]] || { echo "missing build artifacts root" >&2; exit 1; }

{
  echo "platform=$PLATFORM"
  echo "manifest=$MANIFEST"
  echo "generated_root=$GENERATED_ROOT"
  echo "wrapper_root=$WRAPPER_ROOT"
  echo "logs_root=$LOGS_ROOT"
  echo "runtime_logs:"
  find "$LOGS_ROOT" -type f -name "*.runtime.log" | sort
} >"$SUMMARY"

cat "$SUMMARY"
