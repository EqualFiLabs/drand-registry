# AGENTS.md

## Project Identity

- This repository contains the standalone, shared `EqualFiDrandRegistry`.
- The Registry verifies and permanently caches drand Quicknet randomness. It has no Lottery-specific logic.
- The production contract is immutable and administrator-free: no proxy, owner, privileged poster, mutable trust anchor, or randomness replacement path.

## Cryptographic Boundary

- Support native 48-byte compressed G1 signatures and 96-byte uncompressed G1 signatures.
- Normalize both supported encodings to the same canonical G1 representation before deriving randomness.
- Bind verification to the compiled Quicknet public key, Quicknet DST, and exact big-endian `uint64` round message.
- Treat EIP-2537 precompiles as an explicit external assumption. Validate their concrete behavior separately on the target chain.
- Keep the pinned `bls-solidity` dependency unmodified. Any cryptographic primitive change requires an explicit design and review decision.
- Never claim upstream audit coverage: the pinned dependency describes itself as experimental and unaudited.

## Registry Invariants

- Posting is permissionless.
- A successful first post stores one canonical randomness value and one posting timestamp.
- Cached rounds return without reverification and can never be overwritten.
- Invalid encodings, points, signatures, precompile failures, and malformed return data leave storage unchanged.
- `firstRoundAfter(timestamp)` identifies the minimal Quicknet round whose scheduled time is strictly greater than `timestamp`.
- No fallback randomness, alternate key, administrator override, or consumer-specific entropy belongs in this repository.

## Delivery and Validation

- Use focused local Foundry tests while iterating. Let CI run the complete suite, fuzz profile, and static analysis.
- Run Halmos and Certora only on the dedicated Formal Verification Box under the operator's global instructions; never invoke or probe Halmos locally.
- Keep formal results, differential vectors, and target-chain runtime evidence distinct.
- Pin source, compiler/settings, dependencies, formal tools/configuration, and runtime bytecode hashes in release evidence.
- Do not deploy until the implementation, vector tests, adversarial tests, and required formal rules pass.

## Commit Discipline

- Use narrow Conventional Commits with titles no longer than 72 characters.
- Do not put numbered workflow labels in filenames, contract names, test names, or commit messages.
- Stage explicit paths and keep local configuration, credentials, RPC values, and internal infrastructure out of public history.
