#!/usr/bin/env python3
"""Replay the declared Certora obligations with fresh, ignored output files."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "formal/certora/suite.json"
STATUSES = {"SUCCESS", "FAIL", "TIMEOUT", "UNKNOWN", "ERROR", "SKIPPED"}
REQUIRED_SUITES = {"RegistryState": 3, "RegistryAcceptance": 5, "RegistryRuntime": 2,
                   "RegistryEvents": 3, "ProductionCalldataRejects": 2,
                   "ProductionCalldataGuards": 2}


def execute(command, cwd, env, log, timeout):
    # A timeout must terminate the JVM and solver children as well as the CLI.
    process = subprocess.Popen(command, cwd=cwd, env=env, stdout=log,
                               stderr=subprocess.STDOUT, start_new_session=True)
    try:
        return process.wait(timeout=timeout)
    except (subprocess.TimeoutExpired, KeyboardInterrupt) as error:
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            pass
        finally:
            # The CLI may exit on TERM before a child JVM or solver exits.
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        process.wait()
        if isinstance(error, KeyboardInterrupt):
            raise
        return 124


def load_json(path):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"Duplicate JSON key: {key}")
            result[key] = value
        return result
    return json.loads(path.read_text(), object_pairs_hook=unique)


def obligations(tree, path=()):
    """Reject every non-success status and retain every method/context."""
    if isinstance(tree, str):
        if tree != "SUCCESS":
            raise ValueError(f"Unproved obligation {path}: {tree}")
        return [{"context": list(path)}]
    if not isinstance(tree, dict) or not tree:
        raise ValueError(f"Invalid or empty obligation at {path}")
    result = []
    for key, value in sorted(tree.items()):
        if key in STATUSES:
            if key != "SUCCESS" or not isinstance(value, list) or not value:
                raise ValueError(f"Unproved methods at {path}: {key}")
            if len(value) != len(set(value)) or not all(isinstance(v, str) for v in value):
                raise ValueError(f"Duplicate or invalid methods at {path}")
            result.append({"context": list(path), "methods": sorted(value)})
        else:
            result.extend(obligations(value, (*path, key)))
    return result


def validate(suite, result_path, log_path, exit_code):
    if exit_code != 0:
        raise ValueError(f"Prover process exited with status {exit_code}")
    result = load_json(result_path)
    if set(result) != {"rules"}:
        raise ValueError("Unexpected result schema")
    expected = sorted(suite["obligations"], key=lambda v: json.dumps(v, sort_keys=True))
    actual = sorted(obligations(result["rules"]), key=lambda v: json.dumps(v, sort_keys=True))
    if actual != expected:
        raise ValueError("Exact rule, constructor, method or helper inventory differs")
    log = log_path.read_text()
    if any(marker in log for marker in ["SystemExit: 143", "SystemExit: 130",
                                       "Exception ignored in:", "Traceback (most recent call last):"]):
        raise ValueError("Interrupted or errored proof execution")
    for suffix in ["rule_not_vacuous", "invariant_not_trivial_postcondition"]:
        expected_names = set(suite["sanity"].get(suffix, []))
        start_lines = re.findall(r"^Starting to run on rule (.*" + suffix + r")$", log, re.M)
        witness_lines = re.findall(r"^Violated: (.*" + suffix + r")$", log, re.M)
        starts, witnesses = set(start_lines), set(witness_lines)
        if len(start_lines) != len(starts) or len(witness_lines) != len(witnesses):
            raise ValueError(f"Duplicate {suffix} marker")
        if starts != expected_names or witnesses != expected_names:
            raise ValueError(f"Missing or unexpected {suffix} witness")
        if re.search(r"^Verified: .*" + suffix + r"$", log, re.M):
            raise ValueError(f"Vacuous or contradictory {suffix} outcome")


def input_hashes():
    return {
        str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
        for directory in [ROOT / "src", ROOT / "formal/certora", ROOT / "formal/conf",
                          ROOT / "formal/harness", ROOT / "formal/scripts"]
        for p in sorted(directory.rglob("*"))
        if p.is_file() and "__pycache__" not in p.parts
    }


def tool_hashes(env):
    install = Path(env["CERTORA_LOCAL_ROOT"]) / "install"
    files = [Path(sys.executable).resolve(), install / "emv.jar", install / "tac_optimizer"]
    files += list(install.rglob("*.py"))
    for tool in ["java", "z3", "cvc5", "solc8.30"]:
        path = shutil.which(tool, path=env["PATH"])
        if path is None:
            raise ValueError(f"Required executable missing: {tool}")
        files.append(Path(path).resolve())
    return {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(set(files))}


def validate_manifest(manifest):
    if type(manifest.get("schema")) is not int or manifest["schema"] != 1:
        raise ValueError("Unsupported suite manifest schema")
    suites = manifest.get("suites")
    if not isinstance(suites, list) or not suites:
        raise ValueError("Suite manifest must be nonempty")
    names = [s["name"] for s in suites]
    if len(names) != len(set(names)) or set(names) != set(REQUIRED_SUITES):
        raise ValueError("The complete six-suite inventory is required")
    for suite in suites:
        named = [o["context"][0] for o in suite["obligations"]
                 if o["context"] != ["envfreeFuncsStaticCheck"]]
        if len(named) != REQUIRED_SUITES[suite["name"]] or len(set(named)) != len(named):
            raise ValueError("Named rule inventory differs from the declared 17-rule package")
    return suites


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("suites", nargs="*", help="Suite names; default: all")
    parser.add_argument("--list", action="store_true")
    args = parser.parse_args()
    manifest = load_json(MANIFEST)
    try:
        suites = validate_manifest(manifest)
    except (KeyError, TypeError, ValueError) as error:
        parser.error(str(error))
    names = [s["name"] for s in suites]
    if args.list:
        print("\n".join(names))
        return
    if len(args.suites) != len(set(args.suites)) or set(args.suites) - set(names):
        parser.error("Unknown suite name")
    selected = [s for s in suites if not args.suites or s["name"] in args.suites]
    actual_source = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                     for p in sorted((ROOT / "src").rglob("*.sol"))}
    if actual_source != manifest["source_sha256"]:
        parser.error("Production source differs from the declared proof target")
    if subprocess.check_output(["git", "status", "--porcelain", "--untracked-files=no",
                                "--", "src", "formal"], cwd=ROOT, text=True).strip():
        parser.error("Commit the proof inputs before executing a reproduction run")
    for suite in selected:
        config = load_json(ROOT / suite["configuration"])
        rules = {o["context"][0] for o in suite["obligations"]
                 if o["context"] != ["envfreeFuncsStaticCheck"]}
        if set(config["rule"]) != rules or len(config["rule"]) != len(rules):
            parser.error("Configuration and declared rule inventory differ")
        if config.get("rule_sanity") != "basic" or any(config.get(k) is not False for k in
                ["optimistic_hashing", "optimistic_loop", "optimistic_fallback"]):
            parser.error("Sanity and non-optimistic proof settings are required")
    run_dir = ROOT / ".certora-results" / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    run_dir.mkdir(parents=True, exist_ok=False)
    env = os.environ.copy()
    env.pop("CERTORAKEY", None)
    env["CERTORA_LOCAL_ROOT"] = str(Path(env.get("CERTORA_LOCAL_ROOT", ROOT / ".certora-tools")).resolve())
    record = {"source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "suite_sha256": hashlib.sha256(MANIFEST.read_bytes()).hexdigest(), "suites": {}}
    record["prover_commit"] = subprocess.check_output(
        ["git", "-C", str(Path(env["CERTORA_LOCAL_ROOT"]) / "source"), "rev-parse", "HEAD"],
        text=True).strip()
    record["tools"] = {}
    for tool, pattern in [("java", r'"21\.'), ("z3", r'\b4\.16\.0\b'),
                          ("cvc5", r'\b1\.4\.2\b'), ("solc8.30", r'0\.8\.30\+commit\.73712a01')]:
        version = subprocess.check_output([tool, "-version" if tool == "java" else "--version"],
                                          text=True, stderr=subprocess.STDOUT, env=env)
        if not re.search(pattern, version):
            parser.error(f"Unexpected tool version: {tool}")
        record["tools"][tool] = version.strip()
    record["input_sha256"] = input_hashes()
    record["tool_sha256"] = tool_hashes(env)
    record["python_version"] = sys.version
    failed = False
    for suite in selected:
        name = suite["name"]
        cwd = ROOT / suite.get("cwd", ".")
        config = ROOT / suite["configuration"]
        result_path = run_dir / (name + ".json")
        log_path = run_dir / (name + ".log")
        command = [sys.executable, str(ROOT / "formal/scripts/certora-local.py"),
                   os.path.relpath(config, cwd), "--max_concurrent_rules", str(suite["concurrent_rules"]),
                   "--tool_output", os.path.relpath(result_path, cwd)]
        print(f"Running {name}; output: {log_path.relative_to(ROOT)}", flush=True)
        try:
            with log_path.open("w") as log:
                code = execute(command, cwd, env, log, suite["timeout_seconds"])
            (run_dir / (name + ".exit")).write_text(str(code) + "\n")
            validate(suite, result_path, log_path, code)
            if input_hashes() != record["input_sha256"] or tool_hashes(env) != record["tool_sha256"]:
                raise ValueError("Source, proof inputs, or executed tools changed during execution")
            record["suites"][name] = {"status": "PASS", "exit": code, "command": command}
            print(f"PASS {name}", flush=True)
        except (ValueError, OSError) as error:
            record["suites"][name] = {"status": "INCOMPLETE_OR_FAILED", "reason": str(error)}
            failed = True
            print(f"INCOMPLETE_OR_FAILED {name}: {error}", flush=True)
        (run_dir / "run.json").write_text(json.dumps(record, indent=2) + "\n")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
