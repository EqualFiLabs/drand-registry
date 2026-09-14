# Dependency Record

## BLS12-381 verification

The Registry pins [`randa-mu/bls-solidity`](https://github.com/randa-mu/bls-solidity) at:

```text
11af179a8287d978659aae07adb66aa60f64b8a6
```

The pinned Git tree is:

```text
cff76894383ebcad6e8d4b36d90f0444cc1e43e1
```

The dependency is licensed MIT and implements BLS12-381 verification, G1 decompression, RFC 9380 hash-to-curve wiring, and EIP-2537 precompile calls. The selected revision is the upstream commit that moves its Foundry target to the Osaka EVM version and is compatible with the EIP-2537 execution environment targeted by this project.

### Review and audit lineage

The upstream README labels the implementation **experimental and unaudited**. No upstream audit report is represented as covering this dependency. Pinning it does not promote it to an audited primitive.

The integration review identified the security-sensitive surface that remains inside this project's release gates:

- compressed G1 flag, field-bound, infinity, and square-root handling;
- uncompressed G1 field-bound, infinity, and curve validation through EIP-2537;
- Quicknet G2 public-key coordinate ordering;
- exact Quicknet round serialization and DST binding;
- modular-exponentiation and EIP-2537 call success and return-data handling;
- canonical 96-byte normalization before randomness derivation; and
- equivalence of accepted 48-byte and 96-byte representations.

These points must be covered by official vectors, adversarial and differential tests, target-chain conformance checks, and the Registry formal-verification package before release. Any local adaptation belongs in the Registry integration layer; the pinned cryptographic dependency must remain byte-for-byte at the recorded commit unless a separately reviewed dependency update is approved.

## Foundry standard library

Tests and scripts pin [`foundry-rs/forge-std`](https://github.com/foundry-rs/forge-std) at:

```text
bf647bd6046f2f7da30d0c2bf435e5c76a780c1b
```
