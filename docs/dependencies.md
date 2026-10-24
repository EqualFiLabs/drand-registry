# Dependency Record

## Local BLS12-381 helpers

`src/libraries/Bls12381.sol` contains the minimal helper subset used by the
Quicknet verifier. There is no external `bls-solidity` build dependency.

The source is [`randa-mu/bls-solidity`](https://github.com/randa-mu/bls-solidity)
at commit `11af179a8287d978659aae07adb66aa60f64b8a6`, Git tree
`cff76894383ebcad6e8d4b36d90f0444cc1e43e1`:

- [`src/libraries/BLS2.sol`](https://github.com/randa-mu/bls-solidity/blob/11af179a8287d978659aae07adb66aa60f64b8a6/src/libraries/BLS2.sol):
  `PointG1`, `PointG2`, `InvalidDSTLength`, `g1Marshal`, and `expandMsg`.
- [`src/libraries/Precompiles.sol`](https://github.com/randa-mu/bls-solidity/blob/11af179a8287d978659aae07adb66aa60f64b8a6/src/libraries/Precompiles.sol):
  the MODEXP, G1 addition, pairing, and map-to-G1 precompile addresses.

The point layouts and helper function bodies preserve the upstream implementation,
with local naming and formatting. The complete MIT license, including the
Copyright (c) 2025 Randamu notice, is retained in
[`licenses/bls-solidity-MIT.txt`](../licenses/bls-solidity-MIT.txt).

The production caller uses `expandMsg` only with the compiled Quicknet DST,
a 32-byte round digest, and 128-byte output. This is an internal Quicknet helper
subset, not a general-purpose BLS library. It includes no BN254 implementation,
generic verifier, proxy, scheduled upgrade, or demonstration contracts.

Test and formal harnesses serialize the fixed G2 public key with explicit
`abi.encodePacked` in the original x1, x0, y1, y0 coordinate order. The unused
upstream `g2Marshal` helper is not retained in production.

### Review and audit lineage

The upstream README labels the implementation **experimental and unaudited**.
Extraction does not create upstream audit coverage or independent third-party
assurance. Future changes to these helpers are maintained and reviewed here.

The security-sensitive release boundary includes:

- compressed G1 flags, field bounds, infinity, and square-root handling;
- uncompressed G1 field bounds, infinity, and curve validation through EIP-2537;
- Quicknet G2 public-key coordinate ordering;
- exact Quicknet round serialization, DST binding, and XMD expansion;
- modular-exponentiation and EIP-2537 call success and return-data handling;
- canonical 96-byte normalization before randomness derivation; and
- equivalence of accepted 48-byte and 96-byte representations.

Official vectors, adversarial and differential tests, target-chain conformance,
and the Registry formal-verification package remain release requirements.
Historical reports retain their original dependency pins and bytecode hashes;
they are not relabeled as results for this extraction.

## Foundry standard library

Tests and scripts pin [`foundry-rs/forge-std`](https://github.com/foundry-rs/forge-std) at:

```text
bf647bd6046f2f7da30d0c2bf435e5c76a780c1b
```
