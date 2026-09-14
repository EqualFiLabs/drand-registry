# Registry Formal Verification

This package separates four evidence classes:

1. Halmos proves complete-domain arithmetic and the isolated first-write state transition.
2. Certora proves the compiled state harness and compiled acceptance harness rules.
3. Official Quicknet vectors differentially test the concrete parsing, hashing, mapping, pairing, and normalization path.
4. Robinhood runtime validation checks the actual EIP-2537 implementation and is reported separately.

No one class is presented as a substitute for another.

## EIP-2537 summaries

The acceptance harness replaces cryptographic precompiles with a constrained relation. Its `accepted` branch means all of the following are true:

- the submitted 48-byte or 96-byte representation decodes to the modeled canonical G1 point;
- the point is finite, canonical, on BLS12-381 G1, and in the prime-order subgroup;
- the exact big-endian `uint64` round is SHA-256 hashed and mapped with the compiled Quicknet DST;
- the compiled Quicknet G2 public key is used; and
- the EIP-2537 pairing relation `e(signature, -G2) * e(messagePoint, publicKey) == 1` holds.

The summary binds its result to the exact round, modeled canonical point, submitted-proof hash, Quicknet DST, and Quicknet chain identity. It cannot write storage when the modeled pairing rejects.

For concrete execution, the production verifier requires these precompile contracts:

| Precompile | Required success condition | Required output |
|---|---|---|
| EIP-198 modular exponentiation | Computes `base^exponent mod p` for the encoded lengths and BLS12-381 field modulus | Exactly 64 bytes |
| EIP-2537 map FP to G1 | Maps one canonical field element using the specified EIP map | Exactly 128 bytes |
| EIP-2537 G1 addition | Adds the two mapped G1 points | Exactly 128 bytes |
| EIP-2537 pairing | Accepts only valid curve/subgroup inputs and evaluates the two-pair relation | Exactly 32 bytes containing `0` or `1` |

Production code rejects failed calls, short or long return data, and pairing results outside `{0, 1}`.

## Trusted computing base and exclusions

The proof trusts:

- correctness of the Solidity 0.8.30 compiler with the pinned optimizer and Osaka target;
- correctness of EVM execution and the target client's EIP-198/EIP-2537 implementations;
- SHA-256, Keccak-256, BLS12-381, RFC 9380, and standard cryptographic assumptions;
- authenticity of the compiled Quicknet chain identity, public key, DST, genesis timestamp, and period; and
- the constrained precompile relation stated above.

The proof does not establish drand network liveness, threshold-operator honesty, cryptographic hardness, compiler correctness, target-client correctness, or Lottery correctness.

## Required rules

Halmos:

- `check_roundTimeFormula`
- `check_firstRoundAfterIsMinimal`
- `check_preGenesisMapsToFirstRound`
- `check_roundMessageSerialization`
- `check_firstWriteStoresExactly`
- `check_duplicateCannotReplace`
- `check_distinctRoundsRemainIsolated`

Certora state transition:

- `firstWriteStoresExactly`
- `duplicateCannotReplace`
- `roundsRemainIsolated`

Certora constrained acceptance:

- `acceptedProofStoresBoundRandomness`
- `rejectedProofCannotWrite`
- `duplicateSkipsReplacementVerification`
- `summarizedRandomnessIsRoundBound`

Every required rule must finish proved with sanity checks enabled. Timeout, unknown, vacuous, or violated results fail the release gate.

## Mutation checks

Proof soundness is checked on disposable remote copies. At minimum, the following mutations must cause the named proof to fail:

- change strict-future selection so an exact boundary may return the current round;
- permit `_cacheVerified` to overwrite a stored beacon; and
- permit the constrained rejection branch to return randomness.

Mutation results are recorded with the successful proof results; mutated source is never committed to the release branch.
