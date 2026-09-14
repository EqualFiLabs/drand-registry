#!/usr/bin/env bash
set -euo pipefail

result_dir="${1:?usage: run-halmos.sh RESULT_DIR}"
mkdir -p "$result_dir"

set +e
halmos \
  --match-contract '^(RoundArithmeticHalmosTest|RegistryCacheHalmosTest|QuicknetTransformationsHalmosTest)$' \
  --solver z3 \
  --solver-timeout-branching 0 \
  --solver-timeout-assertion 0 \
  --json-output "$result_dir/halmos.json" \
  2>&1 | tee "$result_dir/halmos.log"
status="${PIPESTATUS[0]}"
set -e

printf '%s\n' "$status" > "$result_dir/halmos.exit"
exit "$status"
