#!/usr/bin/env python3
"""Invoke a source-pinned local Certora JVM; never submit a hosted job."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

PROVER_COMMIT = "f5f77783430449791186f7812ebd53addf22cabd"
CLI_ENTRY_POINTS = {
    "certoraRun.py", "certoraSolanaProver.py", "certoraSorobanProver.py",
    "certoraSuiProver.py", "certoraEVMProver.py", "certoraRanger.py",
    "certoraConcord.py", "certoraConcordance.py", "certoraMutate.py",
    "rustMutator.py", "certoraEqCheck.py", "certoraCVLFormatter.py",
}
CLI_PACKAGES = {"Shared", "CertoraProver", "Mutate", "EquivalenceCheck", "graphcore", "concordance"}


def validate_cli(install, source):
    tracked = set(subprocess.check_output(
        ["git", "-C", str(source), "ls-files", "--recurse-submodules", "scripts"], text=True
    ).splitlines())
    modules = list(install.rglob("*.py"))
    if not modules:
        raise ValueError("Installed CLI Python modules are missing")
    for module in modules:
        relative = module.relative_to(install)
        target = source / "scripts" / relative
        if (str(Path("scripts") / relative) not in tracked or not target.is_file()
                or module.read_bytes() != target.read_bytes()):
            raise ValueError("Installed CLI differs from the pinned prover source")
    # Mirrors the Python assets selected by the pinned upstream Gradle build.
    required = {Path(p).relative_to("scripts") for p in tracked if p.endswith(".py")
                and (Path(p).name in CLI_ENTRY_POINTS
                     or Path(p).relative_to("scripts").parts[0] in CLI_PACKAGES)}
    if required != {p.relative_to(install) for p in modules}:
        raise ValueError("Installed CLI package is incomplete")


def main():
    root = Path(os.environ.get("CERTORA_LOCAL_ROOT", ".certora-tools")).resolve()
    install = root / "install"
    jar = install / "emv.jar"
    source = root / "source"
    if not jar.is_file() or not (install / "certoraRun.py").is_file():
        sys.exit("Build the local prover first; see formal/certora/README.md.")
    commit = subprocess.check_output(
        ["git", "-C", str(source), "rev-parse", "HEAD"], text=True
    ).strip()
    if commit != PROVER_COMMIT:
        sys.exit("The local prover source is not at the required commit.")
    subprocess.run(["git", "-C", str(source), "diff", "--exit-code", "HEAD"],
                   check=True, stdout=subprocess.DEVNULL)
    validate_cli(install, source)
    required_hash = os.environ.get("CERTORA_JAR_SHA256")
    if required_hash and hashlib.sha256(jar.read_bytes()).hexdigest() != required_hash:
        sys.exit("The local prover JAR does not match CERTORA_JAR_SHA256.")
    for arg in sys.argv[1:]:
        if arg.split("=", 1)[0] in {"--server", "--jar", "--split_rules"}:
            sys.exit("Only the pinned local JVM is supported.")
    if len(sys.argv) < 2:
        sys.exit("Provide a Certora configuration file.")
    config = json.loads(Path(sys.argv[1]).read_text())
    if {"server", "jar", "split_rules"} & set(config):
        sys.exit("Hosted, split-rule and JAR overrides in configurations are disabled.")
    os.environ.pop("CERTORAKEY", None)
    os.environ["CERTORA"] = str(install)
    os.environ.setdefault("JAVA_TOOL_OPTIONS", "-Xmx16g -XX:ActiveProcessorCount=8")
    os.environ["PATH"] = str(install) + os.pathsep + os.environ["PATH"]
    sys.path.insert(0, str(install))
    import certoraRun
    from Shared import certoraUtils

    def block_cloud(*args, **kwargs):
        raise certoraUtils.CertoraUserInputError("Hosted proof submission is disabled.")

    certoraRun.run_remote = block_cloud
    certoraRun.splitRules.SplitRulesHandler.generate_runs = block_cloud
    sys.argv = ["certora-local", *sys.argv[1:], "--jar", str(jar)]
    certoraRun.entry_point()


if __name__ == "__main__":
    main()
