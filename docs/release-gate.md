# Shared Randomness Release Gate

## Candidate

- Registry stack candidate: `6c53116a67c3b37183e7a1c0be56a7d1eeec9a8c`
- formally verified production source: `f8db2a1752d22672d4de1708545e286a32c41497`
- deployed-runtime `keccak256`:
  `0xde08fa453cee52a32750e6ff4f736d28b2a4378494cc699e62d27eb44164c1fc`
- linked review stack: PRs
  [#1](https://github.com/EqualFiLabs/drand-registry/pull/1),
  [#2](https://github.com/EqualFiLabs/drand-registry/pull/2),
  [#3](https://github.com/EqualFiLabs/drand-registry/pull/3), and
  [#4](https://github.com/EqualFiLabs/drand-registry/pull/4)

The candidate commit differs from the formally verified source only by the
sanitized proof report and result artifacts. It does not change production
Solidity, proof specifications, compiler configuration, or dependencies.

## CI evidence

[GitHub Actions run 34879127007](https://github.com/EqualFiLabs/drand-registry/actions/runs/34879127007)
completed successfully for the exact candidate commit:

- formatting: PASS
- compilation: PASS
- complete unit, vector, adversarial, and fuzz suite: PASS
- Slither: PASS

Both the official 48-byte compressed Quicknet proof and its equivalent 96-byte
uncompressed representation pass through the production verifier and derive
the same canonical Round-bound randomness.

## Formal evidence

The [formal report](formal-verification.md) pins the source, runtime bytecode,
dependencies, compiler, proof specifications, configurations, tools, trusted
computing base, and exclusions. Its terminal results are:

- Halmos: 34/34 rules pass, with no counterexamples or bounded loops;
- Certora cache state: 3/3 rules pass;
- Certora constrained acceptance: 5/5 rules pass;
- Certora production non-posting ABI: 2/2 parametric rules pass; and
- strict-future, overwrite, and rejected-summary mutations are all detected.

No required proof timed out, returned unknown, or lacked a non-vacuity witness.

## Gate decision

The shared Registry implementation, test, and formal-verification gates pass.
The Lottery implementation may use the candidate above as its pinned Registry
dependency while this unmerged PR stack remains under review.

Robinhood EIP-2537 conformance, a real future Quicknet proof, deployment, and
deployed-bytecode matching remain explicitly pending. They belong to the later
testnet release gate and are not implied by this checkpoint.
