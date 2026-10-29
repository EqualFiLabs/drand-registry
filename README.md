# EqualFi Drand Registry

Shared, permissionless [drand Quicknet](https://drand.love/) verification and permanent randomness caching on Robinhood Chain.

**Any project or protocol on Robinhood Mainnet can use the deployed Registry.** Applications share verified beacons without deploying their own BLS verifier or repeating verification for each consumer.

The Registry is immutable and administrator-free. It has no owner, proxy, allowlist, mutable public key, or randomness replacement mechanism.

## Mainnet deployment

| Network | Chain ID | Registry |
| --- | --- | --- |
| Robinhood Mainnet | 4663 | `0xB1a30ff19243Af135003E541769dD520DA1acC2B` |

Source verified on [Etherscan](https://robin.etherscan.io/address/0xB1a30ff19243Af135003E541769dD520DA1acC2B#code) and [Blockscout](https://robinhoodchain.blockscout.com/address/0xB1a30ff19243Af135003E541769dD520DA1acC2B?tab=contract).

The [deployment manifest](deployments/robinhood-mainnet.json) records the source commit, compiler settings, bytecode hashes, deployment transaction, and Mainnet validation.

## How it works

1. An application selects a future Quicknet round.
2. After publication, anyone obtains that round's signature from drand.
3. A user, application, or relayer submits the signature to the Registry.
4. The Registry verifies it against the fixed Quicknet public key and permanently caches the result.
5. Applications read and use the cached randomness.

Each round requires successful verification only once. Later submissions for a cached round return without changing its randomness or posting timestamp.

There is no Registry fee. Transactions incur normal network gas costs. A dedicated keeper is optional; an application can let users submit signatures through its UI.

## Integration

Use [`IEqualFiDrandRegistry`](src/interfaces/IEqualFiDrandRegistry.sol) with the deployed address.

| Function | Purpose |
| --- | --- |
| `postSig(round, signature)` | Verify and cache a beacon; returns `true` for a new successful write. |
| `hasSig(round)` | Check whether a round is cached. |
| `randomnessOf(round)` | Read its cached randomness. |
| `postedAt(round)` | Read its first posting timestamp. |
| `firstRoundAfter(timestamp)` | Find the first round scheduled strictly after a timestamp. |
| `roundTime(round)` | Read a round's scheduled publication time. |

Check `hasSig` for availability. A zero randomness value is not an absence marker.

Both native **48-byte compressed** signatures and equivalent **96-byte uncompressed** signatures are supported.

## Randomness format

Both encodings normalize to the same canonical 96-byte signature:

```text
randomness = Keccak-256(canonical_signature || big_endian_uint64(round))
```

Use the Registry's returned value when integrating. It differs from drand's API `randomness` field.

## Application responsibilities

For unpredictable outcomes, lock the target round and all outcome-affecting choices before that beacon's scheduled publication.

**An uncached beacon may already be publicly known.** Use its scheduled publication time when designing commitment and settlement rules.

The Registry does not fetch signatures, deliver callbacks, or enforce application deadlines. Applications control round selection, submission liveness, settlement, and prize or outcome calculation.

## Local development

```sh
git clone --recurse-submodules https://github.com/EqualFiLabs/drand-registry.git
cd drand-registry

forge fmt --check
forge build
forge test
```

Builds use Solidity **0.8.38**, the **Osaka** EVM target, optimizer **200 runs**, and IPFS metadata.

For application testing against the deployed Registry:

```sh
anvil --host 127.0.0.1 \
  --fork-url "$ROBINHOOD_MAINNET" \
  --fork-block-number 101164226
```

Use an Anvil version supporting EIP-2537. This block includes the Mainnet validation beacons.

## Security and verification

Verification relies on Quicknet's cryptography and the chain's correct implementation of the required cryptographic precompiles.

The local BLS helpers originate from an experimental, explicitly unaudited upstream library. Formal verification, live-chain checks, and local fork checks have distinct scopes and assumptions.

See:

- [Quicknet trust anchor and signature format](docs/quicknet.md)
- [Dependency provenance](docs/dependencies.md)
- [Verification coverage and assumptions](docs/verification-summary.md)
- [Mainnet deployment manifest](deployments/robinhood-mainnet.json)
- [Reproducing the Certora proofs](formal/certora/README.md)
