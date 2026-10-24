# EqualFi Drand Registry

`EqualFiDrandRegistry` is a standalone, immutable registry for permissionless verification and permanent caching of [drand Quicknet](https://docs.drand.love/docs/cryptography/#quicknet) randomness on EVM chains with EIP-2537 support.

The contract is shared infrastructure. It contains no Lottery-specific logic, ownership controls, proxy, mutable public key, or randomness replacement path.

## Status

The Registry implementation is deployable and permanently caches the first valid proof submitted for each Quicknet round. The [formal report](docs/formal-verification.md) records passing gates for a historical revision. The local BLS helper extraction changes source paths, metadata, and proof harnesses; it requires fresh CI and formal release evidence. Target-chain conformance and deployed-bytecode matching remain separate requirements.

## Development

```sh
git submodule update --init --recursive
forge fmt --check
forge build
forge test
```

CI owns the complete test, fuzz, and static-analysis gates. Formal-verification workloads are run only on the dedicated verification system and are reported separately from Foundry and target-chain results.

## Security

The local BLS helpers were extracted from an experimental, explicitly unaudited upstream library. See [docs/dependencies.md](docs/dependencies.md) for their exact provenance and review boundary, and [docs/quicknet.md](docs/quicknet.md) for the immutable trust anchor.
