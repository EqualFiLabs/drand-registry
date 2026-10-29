# Reproduce the Certora proofs

The repository contains the CVL specifications, Solidity harnesses, configurations,
required rule/method inventory, and runner for all **17 named Certora rules**.
No saved result or private input is needed. Generated results, logs, compiler
scenes, counterexamples, and internal reviews are excluded from version control.

The current inputs target Solidity 0.8.38. The completed fresh-clone replay recorded
in the [coverage summary](../../docs/verification-summary.md) used Solidity 0.8.30
at revision `26cc88b8c3387ac100f461203fa5f08a4d45dc1d`. Check out that revision
to reproduce those historical inputs exactly. A 0.8.38 prover replay is not claimed.

## Clone and toolchain

```bash
git clone --recurse-submodules https://github.com/EqualFiLabs/drand-registry.git
cd drand-registry
```

Check out the revision containing this package. Linux x86-64 is the reference
platform. Use Python 3.10, Git, Java 21 for execution, Z3 4.16.0, CVC5 1.4.2,
and the Solidity 0.8.38 compiler named `solc8.38` on `PATH`. The configurations
select Osaka, optimizer 200, and no via-IR. Certora inputs import only the
repository's own Solidity sources; the Forge-std submodule is needed for the
separate Foundry/Halmos suites.

The runner uses the open-source CertoraProver 8.20.2 revision
`f5f77783430449791186f7812ebd53addf22cabd`. Its matching Python CLI, native helpers,
and JVM JAR are required. A separately installed hosted `certora-cli` package is
not sufficient. This reproduction path needs no Certora account or API key.

## Build the prover

Follow the [pinned upstream prerequisites](https://github.com/Certora/CertoraProver/blob/f5f77783430449791186f7812ebd53addf22cabd/README.md),
including Rust and native build tools, LLVM tools and `rustfilt`. The reference
build uses Rust 1.90.0, Temurin JDK 19.0.2+7, and Gradle 7.6.4. Set `JAVA_HOME`
to that build JDK and `GRADLE_BIN` to the Gradle 7.6.4 executable. Use Java 21
for executing proofs after the build; the upstream Gradle 7.2 wrapper is not
compatible with that execution runtime.

```bash
export CERTORA_LOCAL_ROOT="$PWD/.certora-tools"
mkdir -p "$CERTORA_LOCAL_ROOT/install"
git clone https://github.com/Certora/CertoraProver.git "$CERTORA_LOCAL_ROOT/source"
git -C "$CERTORA_LOCAL_ROOT/source" checkout --detach f5f77783430449791186f7812ebd53addf22cabd
git -C "$CERTORA_LOCAL_ROOT/source" submodule update --init --recursive
python3.10 -m venv "$CERTORA_LOCAL_ROOT/venv"
"$CERTORA_LOCAL_ROOT/venv/bin/python" -m pip install -r formal/certora/requirements-local.txt
export CERTORA="$CERTORA_LOCAL_ROOT/install"
export PATH="$JAVA_HOME/bin:$PATH"
export CARGO_BUILD_JOBS=4
(cd "$CERTORA_LOCAL_ROOT/source" && "$GRADLE_BIN" --no-daemon --max-workers=4 assemble)
```

The pinned Python requirements supply the upstream CLI dependencies and the
external Z3 executable. Check that `install` contains `emv.jar`, `certoraRun.py`,
`tac_optimizer`, and the other upstream build outputs. Obtain CVC5 from the
[official 1.4.2 release](https://github.com/cvc5/cvc5/releases/tag/cvc5-1.4.2),
and Solidity from the [official 0.8.38 release](https://github.com/ethereum/solidity/releases/tag/v0.8.38).
Verify downloaded checksums. The reference Linux Solidity executable SHA-256 is
`65c3180a336eabb6bdc4bbd49cc405aeb233976964ae6c11fba2a6c8be8f3243`.
Put `solc8.38`, CVC5, Java 21, and the virtual environment's executables on `PATH`:

```bash
export PATH="$CERTORA_LOCAL_ROOT/venv/bin:$PATH"
java -version
z3 --version
cvc5 --version
solc8.38 --version
```

Source builds can produce different JAR archive bytes. The launcher checks the
clean pinned prover source and matching CLI modules; each run records executed
JAR/tool hashes. Optionally set `CERTORA_JAR_SHA256` to require an operator-chosen
exact JAR hash. This is a source-pinned reproduction, not a promise of bit-for-bit
identical prover binaries across independent builds. Compiler and prover
correctness remain explicit trust assumptions.

## Execute

Use a provisioned verification system. The default JVM heap ceiling is 16 GiB;
suites execute sequentially with two concurrent rules per suite. Set
`JAVA_TOOL_OPTIONS` to adjust resource limits. Each suite has a one-hour outer
limit; timeout is failure. Use a terminal multiplexer or detached job for recovery
from a client disconnect.

```bash
"$CERTORA_LOCAL_ROOT/venv/bin/python" formal/scripts/run-certora.py --list
"$CERTORA_LOCAL_ROOT/venv/bin/python" formal/scripts/run-certora.py
# Select suites when iterating:
"$CERTORA_LOCAL_ROOT/venv/bin/python" formal/scripts/run-certora.py RegistryEvents ProductionCalldataGuards
```

The launcher selects the local JAR, removes `CERTORAKEY`, and blocks hosted and
split-rule submission. It invokes neither Halmos nor an RPC. The older
`formal/scripts/run-certora.sh` is a hosted launcher for individual configurations;
it requires a hosted credential and does not perform the complete inventory and
non-vacuity checks of the Python runner.

Each invocation creates a new ignored `.certora-results/<timestamp>/` directory
and never overwrites previous output. Compiler scenes are generated under ignored
`.certora_internal/` and `emv-*/` directories. Tool output paths are relative to
the repository root to avoid a CLI path-handling ambiguity. Run from committed
inputs: the runner rejects modified tracked proof/source files and source changes
from the declared production target in `suite.json`.

Success requires zero process exit, the exact rule and parametric method inventory,
all envfree checks, every required non-vacuity witness, and unchanged proof/source
and tool hashes during execution. Unknown, timeout, error, vacuous, interrupted,
missing, duplicate, or unexpected results fail validation. Expected sanity
violations ending in `rule_not_vacuous` witness reachability; they are not failures
of the named production rule. `suite.json` declares required obligations and
witness names without containing saved proof results.

The validator's corruption tests use synthetic examples and need no prover:

```bash
python3 formal/scripts/test-certora-runner.py
python3 -O formal/scripts/test-certora-runner.py
```

## Rule scope

| Suite | Named rules | Model boundary |
| --- | --- | --- |
| RegistryState | 3 | Actual first-write cache transition exposed by a harness |
| RegistryAcceptance | 5 | Production post logic under the explicit constrained verification summary |
| RegistryRuntime | 2 | Actual production non-posting ABI, with each declared selector checked |
| RegistryEvents | 3 | Posting topics/data length, duplicate silence, timestamp overflow under the acceptance summary |
| ProductionCalldataRejects | 2 | Actual production unsupported-length and round-zero rejection for unrestricted typed bytes |
| ProductionCalldataGuards | 2 | Actual duplicate/overflow guards for unrestricted typed bytes; verifier entry contains a failing CVL assertion and must be unreachable |

The last two configurations select two rules each from their specification files.
Unused rule definitions are not counted. The guard cutpoint assumes no
cryptographic acceptance/rejection; reaching it fails verification. All six
configurations disable optimistic hashing, loops, and fallback, enable basic rule
sanity, and select installed Z3/CVC5 solvers. Parametric selector obligations and
envfree helpers are additional checks, not additional named rules.

Curve arithmetic, precompile behavior, cryptographic security, compiler/EVM and
formal-engine correctness, drand liveness, and downstream consumers remain outside
these Certora claims. Full native-event byte payloads and generalized cryptographic
composition are covered by separate Halmos proofs; this command reproduces the
Certora portion only. Foundry tests, client conformance, hosted CI, deployment and
live-chain validation remain separate evidence.
