# Formal Verification Report

## Status

Proof execution is pending for this candidate. This report must be completed with the verified source revision, production runtime bytecode hash, exact tool versions, per-rule terminal results, mutation outcomes, and durable artifact paths before the Registry verification checkpoint can pass.

## Pinned build inputs

- Solidity: `0.8.30`
- EVM target: `osaka`
- optimizer: enabled, `200` runs
- `bls-solidity`: `11af179a8287d978659aae07adb66aa60f64b8a6`
- `forge-std`: `bf647bd6046f2f7da30d0c2bf435e5c76a780c1b`

The final executed report will pin the source commit and `keccak256` of `EqualFiDrandRegistry` deployed runtime bytecode generated from these inputs.

## Proof boundary

The machine-checked package covers complete-domain Quicknet round arithmetic, exact round-message serialization, first-write cache behavior, duplicate non-mutation, round isolation, and storage reachability under the constrained EIP-2537 acceptance relation defined in [formal/README.md](../formal/README.md).

The production parsing, decompression, hash-to-curve inputs/outputs, public-key ordering, exact precompile return-data checks, pairing result, and canonical randomness are connected to the model by official differential vectors and later target-chain conformance evidence. Those runtime checks are not described as solver proofs.

## Results

Per-rule results and mutation evidence will be added after remote execution. No pending, timed-out, unknown, or vacuous rule may be labeled as proved.
