#!/usr/bin/env python3
"""Exercise failure detection without invoking any prover or consuming saved results."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

module = importlib.util.spec_from_file_location("runner", Path(__file__).with_name("run-certora.py"))
runner = importlib.util.module_from_spec(module)
module.loader.exec_module(runner)
launcher_module = importlib.util.spec_from_file_location("launcher", Path(__file__).with_name("certora-local.py"))
launcher = importlib.util.module_from_spec(launcher_module)
launcher_module.loader.exec_module(launcher)


class EvidenceValidation(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.result = Path(self.directory.name) / "result.json"
        self.log = Path(self.directory.name) / "proof.log"
        self.suite = {"obligations": [{"context": ["accounting"], "methods": ["claim()", "settle()"]}],
                      "sanity": {"rule_not_vacuous": ["accounting-rule_not_vacuous"]}}
        self.result.write_text(json.dumps({"rules": {"accounting": {"SUCCESS": ["claim()", "settle()"]}}}))
        self.log.write_text("Starting to run on rule accounting-rule_not_vacuous\n"
                            "Violated: accounting-rule_not_vacuous\n")

    def check(self, code=0):
        runner.validate(self.suite, self.result, self.log, code)

    def test_complete_obligations(self):
        self.check()

    def test_nonzero_exit(self):
        with self.assertRaises(ValueError):
            self.check(1)

    def test_missing_method(self):
        self.result.write_text('{"rules":{"accounting":{"SUCCESS":["claim()"]}}}')
        with self.assertRaises(ValueError):
            self.check()

    def test_duplicate_method(self):
        self.result.write_text('{"rules":{"accounting":{"SUCCESS":["claim()","claim()"]}}}')
        with self.assertRaises(ValueError):
            self.check()

    def test_duplicate_rule_key(self):
        self.result.write_text('{"rules":{"accounting":"SUCCESS","accounting":"SUCCESS"}}')
        with self.assertRaises(ValueError):
            self.check()

    def test_unproved_statuses(self):
        for state in ["FAIL", "UNKNOWN", "TIMEOUT", "ERROR", "SKIPPED"]:
            with self.subTest(state=state):
                self.result.write_text(json.dumps({"rules": {"accounting": {state: ["claim()", "settle()"]}}}))
                with self.assertRaises(ValueError):
                    self.check()

    def test_missing_sanity(self):
        self.log.write_text("")
        with self.assertRaises(ValueError):
            self.check()

    def test_vacuous_or_contradictory_sanity(self):
        self.log.write_text(self.log.read_text() + "Verified: accounting-rule_not_vacuous\n")
        with self.assertRaises(ValueError):
            self.check()

    def test_duplicate_sanity(self):
        self.log.write_text(self.log.read_text() + "Violated: accounting-rule_not_vacuous\n")
        with self.assertRaises(ValueError):
            self.check()

    def test_empty_inventory(self):
        self.result.write_text('{"rules":{}}')
        with self.assertRaises(ValueError):
            self.check()

    def test_unexpected_rule(self):
        data = json.loads(self.result.read_text())
        data["rules"]["unexpected"] = "SUCCESS"
        self.result.write_text(json.dumps(data))
        with self.assertRaises(ValueError):
            self.check()

    def test_interrupted_zero_exit(self):
        self.log.write_text(self.log.read_text() + "Exception ignored in: cleanup\nSystemExit: 143\n")
        with self.assertRaises(ValueError):
            self.check()

    def test_missing_envfree_method(self):
        self.suite["obligations"].append({"context": ["envfreeFuncsStaticCheck"],
                                          "methods": ["hasSig(uint64)"]})
        with self.assertRaises(ValueError):
            self.check()

    def test_manifest_requires_complete_inventory(self):
        manifest = runner.load_json(runner.MANIFEST)
        self.assertEqual(len(runner.validate_manifest(manifest)), 6)
        for broken in [{**manifest, "schema": 2}, {**manifest, "suites": []},
                       {**manifest, "suites": manifest["suites"][:-1]}]:
            with self.subTest(broken=broken.get("schema")):
                with self.assertRaises(ValueError):
                    runner.validate_manifest(broken)


class CliIntegrity(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        root = Path(self.directory.name)
        self.install, self.source = root / "install", root / "source"
        for name in ["certoraRun.py", "CertoraProver/certoraBuild.py"]:
            for base in [self.install, self.source / "scripts"]:
                path = base / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("# pinned module\n")
        self.tracked = "scripts/certoraRun.py\nscripts/CertoraProver/certoraBuild.py\n"

    def check(self):
        with mock.patch.object(launcher.subprocess, "check_output", return_value=self.tracked):
            launcher.validate_cli(self.install, self.source)

    def test_matching_cli(self):
        self.check()

    def test_stale_build_module(self):
        (self.install / "CertoraProver/certoraBuild.py").write_text("# stale\n")
        with self.assertRaises(ValueError):
            self.check()

    def test_missing_build_module(self):
        (self.install / "CertoraProver/certoraBuild.py").unlink()
        with self.assertRaises(ValueError):
            self.check()

    def test_extra_module(self):
        (self.install / "unknown.py").write_text("# extra\n")
        with self.assertRaises(ValueError):
            self.check()


if __name__ == "__main__":
    unittest.main()
