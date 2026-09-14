# Quicknet Trust Anchor

The Registry is bound to drand Quicknet, identified by chain hash:

```text
52db9ba70e0cc0f6eaf7803dd07447a1f5477735fd3f661792ba94600c84e971
```

The official [Quicknet chain information](https://api.drand.sh/52db9ba70e0cc0f6eaf7803dd07447a1f5477735fd3f661792ba94600c84e971/info) reports:

- beacon ID: `quicknet`
- scheme: `bls-unchained-g1-rfc9380`
- genesis timestamp: `1692803367`
- period: `3` seconds
- compressed G2 public key: `83cf0f2896adee7eb8b5f01fcad3912212c437e0073e911fb90022d3e760183c8c4b450b6a0a6c3ac6a5776a2d1064510d1fec758c921cc22b0e17e63aaf4bcb5ed66304de9cf809bd274ca73bab4af5a6e9c76a4bc09e76eae8991ef5ece45a`

The Registry compiles the corresponding uncompressed G2 coordinates into `QuicknetVerifier.publicKey()`. The domain separation tag is the one used by drand's `bls-unchained-g1-rfc9380` scheme:

```text
BLS_SIG_BLS12381G1_XMD:SHA-256_SSWU_RO_NUL_
```

## Verification message

Quicknet signs an unchained round message:

```text
message = SHA-256(big_endian_uint64(round))
```

The 32-byte message is mapped to G1 using the pinned domain separation tag, then paired against the compiled Quicknet public key through EIP-2537.

## Supported signature representations

The verifier accepts the native 48-byte compressed G1 signature and the equivalent 96-byte uncompressed G1 point. Both are normalized to the same 96-byte representation before Registry randomness is derived:

```text
randomness = Keccak-256(canonical_signature || big_endian_uint64(round))
```

Raw relayer-supplied bytes are never used directly as protocol randomness.

## Anchored vector

The focused verification tests use [official Quicknet round 20791007](https://api.drand.sh/52db9ba70e0cc0f6eaf7803dd07447a1f5477735fd3f661792ba94600c84e971/public/20791007). Its native signature is:

```text
8d2c8bbc37170dbacc5e280a21d4e195cff5f32a19fd6a58633fa4e4670478b5fb39bc13dd8f8c4372c5a76191198ac5
```

The corresponding uncompressed point comes from the pinned `bls-solidity` test corpus. Target-chain EIP-2537 conformance and the formal-verification assumptions remain separate release gates.
