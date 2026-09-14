#!/usr/bin/env bash
set -euo pipefail

result_dir="${1:?usage: run-halmos.sh RESULT_DIR}"
mkdir -p "$result_dir"

halmos \
  --match-contract '^(RoundArithmeticHalmosTest|RegistryCacheHalmosTest)$' \
  --solver z3 \
  --solver-timeout-branching 0 \
  --solver-timeout-assertion 0 \
  --json-output "$result_dir/halmos.json"
