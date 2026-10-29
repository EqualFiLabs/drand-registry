# Deployment Manifests

Committed deployment manifests belong in this directory. A manifest must identify the chain ID, deployed address, deployment transaction, verified source commit, compiler settings, constructor inputs, and runtime bytecode hash without including credentials or private RPC endpoints.

## Robinhood Mainnet

| Contract | Chain ID | Address | Manifest |
| --- | --- | --- | --- |
| EqualFiDrandRegistry | 4663 | `0xB1a30ff19243Af135003E541769dD520DA1acC2B` | [Deployment manifest](robinhood-mainnet.json) |

The immutable Registry is available for any application or protocol to verify and cache drand Quicknet signatures. Posting is permissionless and requires no administrator approval. Source is verified on [Etherscan](https://robin.etherscan.io/address/0xB1a30ff19243Af135003E541769dD520DA1acC2B#code) and [Blockscout](https://robinhoodchain.blockscout.com/address/0xB1a30ff19243Af135003E541769dD520DA1acC2B?tab=contract).

Mainnet validation posted real Quicknet rounds using both supported signature encodings and checked cached randomness, posting timestamps, duplicate-post immutability, and invalid-proof rejection. The manifest distinguishes mined transactions from read-only calls. Consumers must lock outcome-affecting choices before the selected beacon's scheduled publication; absence from this cache does not mean a beacon is still secret.

For local application testing, fork Mainnet at or after the manifest's `liveValidation.blockNumber` to include both validation beacons. With `ROBINHOOD_MAINNET` configured in your environment:

```sh
anvil --host 127.0.0.1 --fork-url "$ROBINHOOD_MAINNET" --fork-block-number 101164226
```

Anvil provides a local JSON-RPC endpoint at `http://127.0.0.1:8545`. The manifest records the Anvil version used to check forked cache reads and verification of both signature encodings with an empty local cache; use a version that supports EIP-2537 when testing new signature posts.
