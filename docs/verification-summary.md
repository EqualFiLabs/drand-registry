# Verification Coverage Summary

Results recorded on 2026-10-26 for production source
`118a94d2e447055d1a47d1a13488e887aaa4a822`. This expansion changes no
production Solidity.

## Build identity

- Production deployed-runtime Keccak-256:
  `0xa8cf3e27cfd22d31583ec23233283363ea913bf31b0db1bf92aacaa906082e65`.
- Solidity: `0.8.30+commit.73712a01`; Osaka target; optimizer enabled,
  200 runs; no via-IR.
- Forge-std: `bf647bd6046f2f7da30d0c2bf435e5c76a780c1b`.
- Formal execution: Foundry 1.7.1, Halmos 0.3.3, Z3 4.16.0,
  self-hosted Certora revision
  `f5f77783430449791186f7812ebd53addf22cabd`, Java 21.0.12.1.

## Results

| Check | Result |
| --- | --- |
| Existing Halmos properties | 34 passed |
| Additional production/composition Halmos properties | 18 passed |
| Existing Certora rules | 10 passed |
| Additional event/timestamp Certora rules | 3 passed |
| Deliberate production mutations | All 10 detected by counterexamples |
| Default Foundry tests | 37 passed |
| Additional registry concrete fuzz tests | 2 passed, 256 runs each |
| Oracle-model concrete fuzz tests | 3 passed, 256 runs each |

Every selected verification job passed. Non-mutated Halmos verification
properties reported no counterexamples, unresolved paths, or bounded loops.
All ten selected mutation jobs produced validated counterexamples. Every
Certora rule and parametric selector had a non-vacuity witness. Failed and superseded attempts
are retained separately and are excluded from passing evidence.

The added properties exercise actual production decoding and posting for both
signature transports; canonical marshaling; the complete pairing transcript;
independent XMD expansion and hash-to-curve composition; duplicate immutability;
timestamp overflow; and invalid inputs or primitive responses. Event rules
check topics and ABI data length under the acceptance summary. Concrete tests
separately check the full event payload and emitter using the official Quicknet
vector in both transports.

Private evidence binds each selected job to its exact production source,
proof inputs, dependency revisions, tool identities, invocation, compiler
configuration, and before/after input hashes. Independently frozen proof
bundles are recorded separately. The complete evidence checker requires the
full rule inventory, validated mutation counterexamples, stable exact inputs, and matching production runtime.
New proof sources, raw execution artifacts, and internal review materials remain
outside version control.

## Assumptions and limits

These are conditional implementation proofs. SHA-256 and MODEXP use
deterministic symbolic models; decompression assumes canonical MODEXP outputs.
Map, addition, and pairing summaries are tied to independently constructed
inputs. Whole-post integration uses fixed map/add point fixtures; arbitrary
canonical primitive point outputs are covered by a separate composition property.
Curve arithmetic, subgroup checks, cryptographic hardness, precompile
implementations, and compiler correctness remain trusted.

The new composition checks use an isolated Halmos model correction for
SHA-256/MODEXP bit widths. The existing properties use stock Halmos. The
correction and all executed model identities are retained with private evidence.

Halmos uses loop bound 8 with no bounded-loop result accepted. Dynamic byte
inputs in the added checks enumerate lengths
`0, 1, 31, 32, 47, 48, 49, 95, 96, 97, 256`; this does not establish arbitrary
unbounded calldata coverage. Other symbolic inputs range over their declared
types subject to the recorded assumptions. Full dynamic event-payload bytes
are checked concretely, rather than by the event specification.

The concrete tests are separate from remote formal results and used Foundry
1.8.2-nightly. No new hosted CI, deployment, live-chain check, target-client
conformance, drand liveness, or downstream Lottery verification is implied.
The earlier [formal report](formal-verification.md) and
[release gate](release-gate.md) remain historical evidence for their recorded
revisions.
