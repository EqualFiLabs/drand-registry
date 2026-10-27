# Verification Coverage Summary

Results recorded on 2026-10-27 for production source
`118a94d2e447055d1a47d1a13488e887aaa4a822`. This expansion changes no
production Solidity.

## Build identity

- Production deployed-runtime Keccak-256:
  `0xa8cf3e27cfd22d31583ec23233283363ea913bf31b0db1bf92aacaa906082e65`.
- Solidity: `0.8.30+commit.73712a01`; Osaka target; optimizer enabled,
  200 runs; no via-IR.
- Forge-std: `bf647bd6046f2f7da30d0c2bf435e5c76a780c1b`.
- Formal execution: Foundry 1.7.1, Halmos 0.3.3, Z3 API 4.12.6 and external solver 4.16.0,
  CVC5 1.4.2, self-hosted Certora revision
  `f5f77783430449791186f7812ebd53addf22cabd`, Java 21.0.12.1.

## Results

| Check | Result |
| --- | --- |
| Existing Halmos properties | 34 passed |
| Additional production/composition Halmos checks | 26 passed |
| Existing Certora rules | 10 passed |
| Additional event/timestamp/calldata Certora rules | 7 passed |
| Deliberate production mutations | All 12 detected by validated counterexamples |
| Positive-domain reachability checks | 12 witnessed |
| Native-event observer checks | 7 passed |
| Root-partition exhaustiveness/disjointness checks | 3 passed |
| Default Foundry tests | 37 passed |
| Additional registry concrete fuzz tests | 2 passed, 256 runs each |
| Oracle-model concrete fuzz tests | 3 passed, 256 runs each |

Every selected verification job passed. Universal Halmos properties report no
counterexamples, unresolved paths, or bounded loops. Every selected Certora rule
and parametric selector has a non-vacuity witness. Failed, interrupted, and
superseded attempts are retained separately and excluded from passing evidence.

The production properties cover both signature transports through actual decoding,
independent XMD expansion and hash-to-curve composition, canonical marshaling,
the complete pairing transcript, round-bound randomness, and first-write storage.
Whole-post properties quantify over arbitrary canonical map/addition outputs
attached to independently constructed primitive inputs. Fixed point fixtures are
not required by those generalized properties.

Unrestricted, well-formed typed byte calldata is covered for unsupported lengths,
round zero, duplicates, and timestamp overflow. The duplicate and overflow rules
prove that production guards prevent verifier entry through an explicit failing
assertion at that entry; they assume no cryptographic result. The other two rules
execute the production verifier. These rules check storage preservation, no
committed events, and no cryptographic precompile calls under their stated branch
conditions. No calldata-length enumeration or optimistic hashing, loop, or fallback
assumption is used for these rules.

Both accepted transports additionally have whole-post symbolic event proofs over
the actual native log: emitter, all four topics, ABI offsets and lengths, every
submitted signature byte, and compressed-payload zero padding. A passive private
observer exposes the engine's existing log records without adding constraints.
Separate checks validate its ABI, rollback behavior, branch copying, and preservation
of symbolic data. Event-payload and sender mutations produce counterexamples.
The compressed proof uses six exhaustive cases: each sign crossed with raw roots
that are zero, nonzero up to half the field modulus, or above half. All six are
required for the full-domain claim. Their external assertion solver is CVC5 1.4.2;
Z3 supplies the engine's branching queries.

Private evidence binds selected jobs to exact production source, reviewed proof
inputs, dependency contents, tool identities, invocation, compiler configuration,
and before/after input hashes. The complete evidence checker requires the full
rule inventory, stable exact inputs, non-vacuity and mutation witnesses, matching
production runtime, and the previously frozen coverage package. New proof sources,
raw execution artifacts, and internal review materials remain outside version control.

## Assumptions and limits

These are conditional implementation proofs. SHA-256 and MODEXP use deterministic
symbolic models; decompression assumes canonical MODEXP outputs. Map, addition,
and pairing summaries are tied to independently constructed inputs. Curve
arithmetic, subgroup checks, cryptographic hardness, precompile implementations,
compiler correctness, and formal-engine correctness remain trusted.

The composition checks use an isolated Halmos model correction for SHA-256/MODEXP
bit widths. Native-event proofs additionally use the passive observer described
above. Existing baseline properties use stock Halmos. Executed model identities,
changes, and validation are retained with private evidence.

Halmos uses loop bound 8; no bounded-loop result is accepted. Accepted transports
have their protocol-defined lengths of 48 and 96 bytes, with symbolic contents.
Earlier length-enumeration tests remain supplemental to the unrestricted calldata
rules. Other symbolic inputs range over their declared types subject to explicit
canonicality and branch conditions. Reachability witnesses exercise all six root
cases, both compressed signs, and permitted zero-coordinate partitions in the symbolic primitive model;
they do not establish mathematical curve validity for arbitrary primitive replies.

The concrete tests are separate from remote formal results and used Foundry
1.8.2-nightly. No new hosted CI, deployment, live-chain check, target-client
conformance, drand liveness, or downstream Lottery verification is implied.
The earlier [formal report](formal-verification.md) and
[release gate](release-gate.md) remain historical evidence for their recorded
revisions.
