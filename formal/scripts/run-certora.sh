#!/usr/bin/env bash
set -euo pipefail

configuration="${1:?usage: run-certora.sh CONFIGURATION RESULT_DIR}"
result_dir="${2:?usage: run-certora.sh CONFIGURATION RESULT_DIR}"

: "${CERTORAKEY:?CERTORAKEY must be exported as data before this script runs}"
mkdir -p "$result_dir"

name="$(basename "$configuration" .conf)"
set +e
certoraRun "$configuration" 2>&1 | tee "$result_dir/$name.log"
status="${PIPESTATUS[0]}"
set -e

printf '%s\n' "$status" > "$result_dir/$name.exit"
exit "$status"
