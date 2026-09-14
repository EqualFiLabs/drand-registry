# EqualFi Drand Registry

`EqualFiDrandRegistry` is a standalone, immutable registry for permissionless verification and permanent caching of [drand Quicknet](https://docs.drand.love/docs/cryptography/#quicknet) randomness on EVM chains with EIP-2537 support.

The contract is shared infrastructure. It contains no Lottery-specific logic, ownership controls, proxy, mutable public key, or randomness replacement path.

## Status

The repository is under active development. The stable consumer interface and project foundation are present; cryptographic verification and deployable Registry behavior are delivered in subsequent reviewed changes. Do not deploy the current foundation branch.

## Development

```sh
git submodule update --init --recursive
forge fmt --check
forge build
forge test
```

CI owns the complete test, fuzz, and static-analysis gates. Formal-verification workloads are run only on the dedicated verification system and are reported separately from Foundry and target-chain results.

## Security

The pinned BLS dependency is experimental and explicitly unaudited upstream. See [docs/dependencies.md](docs/dependencies.md) for its exact revision and review boundary.
