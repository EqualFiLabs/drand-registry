# Formal Verification Report

## Status

The release-required Registry formal package passed against source revision
`f8db2a1752d22672d4de1708545e286a32c41497`. All required Halmos and Certora
rules completed without a timeout or unknown result. Halmos reported no bounded
loops, and Certora produced non-vacuity witnesses for every rule.

This result does not include Robinhood runtime conformance. Deployment and
concrete EIP-2537 validation remain a separate release gate and must confirm
that deployed runtime bytecode matches the hash below.

## Pinned build inputs

- source revision: `f8db2a1752d22672d4de1708545e286a32c41497`
- production deployed-runtime `keccak256`:
  `0xde08fa453cee52a32750e6ff4f736d28b2a4378494cc699e62d27eb44164c1fc`
- Solidity: `0.8.30+commit.73712a01.Linux.g++`
- EVM target: `osaka`
- optimizer: enabled, `200` runs
- `bls-solidity`: `11af179a8287d978659aae07adb66aa60f64b8a6`
- `forge-std`: `bf647bd6046f2f7da30d0c2bf435e5c76a780c1b`
- Halmos: `0.3.3`
- Certora CLI: `8.18.0`
- Foundry on the verification host: `1.7.1`
- Java used by Certora CLI: `21.0.12`

The proof harness deployed-runtime hashes are:

| Harness | `keccak256` |
|---|---|
| `RegistryStateHarness` | `0x852d5e89c5f2827883aebac2d4e37caf468827d2dd64b51e2a4e510ec6a1dccd` |
| `RegistryAcceptanceHarness` | `0x87d3e804fc4ccca2d265e63675641fe61b1921a66cdaaf0e1dedd33bfd940562` |
| `QuicknetTransformationHarness` | `0x4f20ea35472a625f38671ee80d60c61fb1c9981cb222e634a6b70eb985eb1082` |

## Specification identity

The following SHA-256 hashes identify the executed proof inputs:

| Input | SHA-256 |
|---|---|
| `formal/certora/RegistryAcceptance.spec` | `1a2545434677cb9454a4f9ef327569a178148fe058565c5fd74718f39f02e1f6` |
| `formal/certora/RegistryRuntime.spec` | `0f6737e0b748a407f0224de9536b5c6c7aa7d703a04df4c41134b87dd118c8a1` |
| `formal/certora/RegistryState.spec` | `7acb00144f7ea40bccf7bfdde809c8b11c6085189a5560742d7ec2a6f19b6e40` |
| `formal/conf/RegistryAcceptance.conf` | `6492f170c96166b9a102d89f8bac4d4b31c2b6422a52f7566e1f785aa35e1130` |
| `formal/conf/RegistryRuntime.conf` | `eaa9207121c727c938e99481aa0fc0a1bacce40a93640f990787391ef55aae4d` |
| `formal/conf/RegistryState.conf` | `55a9b3af000796b0bbfd69e23e00a12b739b60189a3fe10f464c55159a8b491a` |
| `test/formal/QuicknetTransformations.halmos.t.sol` | `320de2adf782c9f6584d34779f21fc1aedd30f9f1ef8a94ac709d0793afdfbb2` |
| `test/formal/RegistryCache.halmos.t.sol` | `28849a857a2a1f3e6124c67be05b57f7933e8445ea81c9123605be278ddc3ec7` |
| `test/formal/RegistryRuntime.halmos.t.sol` | `07c9e52f9c0fb1eab9638d8dce6c684764fc119919f682004f7fcbc2d3b67e72` |
| `test/formal/RoundArithmetic.halmos.t.sol` | `30233d0052c410f3c911828d95029a463454a545c84860b295976968f2a13f4f` |

## Machine-checked boundary

Halmos executed 34 complete-domain rules over the compiled Solidity artifacts.
The rules cover:

- representable Round bounds, timestamp overflow behavior, strict-future
  minimality, and exact eight-byte big-endian Round serialization;
- supported 48-byte and 96-byte transports and rejection of every other length;
- compressed flags, infinity rejection, field bounds, curve-constant addition,
  the field-derived square-root exponent, sign selection, and canonical output;
- uncompressed parsing, infinity and field rejection, and canonical marshaling;
- equal canonical randomness inputs for equivalent compressed and uncompressed
  representations under the documented modular-exponentiation model;
- exact Quicknet DST and public-key constants;
- exact modular-exponentiation, G1-addition, and pairing calldata layout;
- failed precompile calls, return-data length mismatches, and pairing outputs
  outside `{0, 1}`;
- first-write storage, duplicate non-mutation, and cross-Round isolation; and
- the exact production `postSig` duplicate path, using a symbolic pre-existing
  beacon and symbolic replacement proof.

Certora proved three state-transition rules, five constrained-acceptance rules,
and two parametric rules over every non-`postSig` selector in the compiled
production ABI. Together they establish that only `postSig` can create a
beacon, no other selector can replace one, a duplicate `postSig` is a no-op,
and acceptance cannot write storage for a rejected or mismatched-Round summary.

The acceptance harness returns the same canonical formula as production:

```text
keccak256(canonical 96-byte G1 signature || big-endian uint64 Round)
```

Its precompile summary is constrained to the submitted proof hash, exact Round,
canonical signature point, mapped message point, compiled Quicknet DST,
compiled Quicknet public key, and exact production pairing transcript. An
`accepted` result represents the documented EIP-2537 pairing relation for that
specific transcript; it is not an unconstrained source of randomness or a
success value reusable for another proof or Round.

## Terminal results

| Engine | Scope | Result |
|---|---|---|
| Halmos | 34 rules | PASS; 0 counterexamples; 0 bounded loops |
| Certora | Registry cache state, 3 rules | PASS; non-vacuous; no timeout |
| Certora | constrained acceptance, 5 rules | PASS; non-vacuous; no timeout |
| Certora | production non-posting ABI, 2 parametric rules | PASS; non-vacuous; no timeout |

The durable public artifacts are
`formal/results/f8db2a17/halmos.json` and
`formal/results/f8db2a17/summary.json`. Raw hosted-prover metadata is retained
outside the public repository and is not required to interpret the recorded
per-rule status.

## Mutation evidence

Three mutations were applied only to disposable checkouts at the pinned source
revision. None of the mutated source was committed.

| Mutation | Expected detector | Observed result |
|---|---|---|
| Return the boundary Round instead of the first strictly future Round | `check_firstRoundAfterIsMinimal` | counterexample found |
| Remove the duplicate/overwrite guards | `check_duplicateCannotReplace` | counterexample found |
| Allow a rejected pairing summary to return randomness | `rejectedProofCannotWrite` | property violation found; no timeout |

## Differential and runtime evidence

Official Quicknet Round `20791007` differential tests separately exercise the
concrete message hash, mapped message point, compressed point, uncompressed
point, pairing result, canonical marshaling, and final Round-bound randomness.
The focused Foundry suites pass for both signature transports and adversarial
precompile-return behavior. These are concrete tests, not solver proofs.

Robinhood execution of EIP-2537 and deployed-bytecode matching are intentionally
not claimed here. The testnet conformance gate must exercise an actual future
Quicknet Round and compare the deployed code hash with the pinned production
runtime hash.

## Trusted computing base and exclusions

The formal result trusts:

- the pinned Solidity compiler and its optimizer;
- the EVM semantics implemented by the formal engines;
- the target client's EIP-198 and EIP-2537 implementations;
- EIP-2537 curve/subgroup validation and pairing semantics;
- SHA-256, Keccak-256, BLS12-381, RFC 9380, and their standard cryptographic
  assumptions; and
- authenticity of the compiled Quicknet chain identity, public key, DST,
  genesis timestamp, and period.

The result does not prove drand network liveness, threshold-operator honesty,
cryptographic hardness, Solidity compiler correctness, target-client
correctness, Robinhood execution correctness, or Lottery behavior. Those
boundaries require their respective differential, testnet, audit, or Lottery
verification evidence.
