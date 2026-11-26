#!/usr/bin/env python3
"""Unit tests for Supabase secrets readiness validator (#2669)."""

from __future__ import annotations

import importlib.util
import io
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/validate_supabase_secrets.py"
SPEC = importlib.util.spec_from_file_location("validate_supabase_secrets", SCRIPT)
assert SPEC and SPEC.loader
validator = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = validator
SPEC.loader.exec_module(validator)


class ValidateSupabaseSecretsTest(unittest.TestCase):
    def test_repository_manifest_covers_4tier_and_ai_hub_keys(self) -> None:
        specs = validator.load_manifest(ROOT / "supabase/required_secrets.json")
        names = {spec.name for spec in specs}
        for key in (
            "DEEPINFRA_API_KEY",
            "LIQUID_API_KEY",
            "REPLICATE_API_TOKEN",
            "COZE_API_KEY",
            "SILICONFLOW_API_KEY",
            "NOVITA_API_KEY",
            "NEBIUS_API_KEY",
            "GROQ_API_KEY",
            "GEMINI_API_KEY",
            "OPENAI_API_KEY",
            "ANTHROPIC_API_KEY",
            "SUPABASE_SERVICE_ROLE_KEY",
        ):
            self.assertIn(key, names)

        refs = validator.scan_edge_function_secret_refs(
            ROOT / "supabase/functions",
            root=ROOT,
        )
        self.assertIn("DEEPINFRA_API_KEY", refs)
        self.assertTrue(
            any("supabase/functions/ai-hub/" in p for p in refs["DEEPINFRA_API_KEY"])
        )

    def test_missing_required_blocks_strict_mode_and_warns_advisory_mode(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            manifest = root / "required.json"
            manifest.write_text(
                json.dumps(
                    {
                        "schema_version": 1,
                        "secrets": [
                            {
                                "name": "DEEPINFRA_API_KEY",
                                "requirement": "required",
                                "category": "ai-tier-budget",
                                "tier": "budget",
                                "description": "DeepInfra provider",
                            },
                            {
                                "name": "ELEVENLABS_API_KEY",
                                "requirement": "recommended",
                                "category": "media-tts",
                                "tier": "media",
                                "description": "ElevenLabs TTS",
                            },
                        ],
                    }
                ),
                encoding="utf-8",
            )
            functions_dir = root / "functions"
            (functions_dir / "ai-hub").mkdir(parents=True)
            (functions_dir / "ai-hub" / "index.ts").write_text(
                'const k = Deno.env.get("DEEPINFRA_API_KEY");\n',
                encoding="utf-8",
            )

            warn_report = validator.evaluate(
                root=root,
                manifest_path=manifest,
                functions_dir=functions_dir,
                strict_mode=False,
                env={"HAS_DEEPINFRA_API_KEY": "false"},
            )
            self.assertEqual(warn_report["status"], "warn")
            self.assertEqual(warn_report["missing_required"], ["DEEPINFRA_API_KEY"])

            fail_report = validator.evaluate(
                root=root,
                manifest_path=manifest,
                functions_dir=functions_dir,
                strict_mode=True,
                env={"HAS_DEEPINFRA_API_KEY": "false"},
            )
            self.assertEqual(fail_report["status"], "fail")
            stderr_buf = io.StringIO()
            with redirect_stderr(stderr_buf):
                validator.emit_annotations(fail_report)
            self.assertIn("::error::", stderr_buf.getvalue())
            self.assertIn("DEEPINFRA_API_KEY", stderr_buf.getvalue())

    def test_present_flags_and_supabase_json_key_list_do_not_expose_values(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            manifest = root / "required.json"
            manifest.write_text(
                json.dumps(
                    {
                        "schema_version": 1,
                        "secrets": [
                            {
                                "name": "DEEPINFRA_API_KEY",
                                "requirement": "required",
                                "category": "ai-tier-budget",
                                "tier": "budget",
                                "description": "DeepInfra host",
                            },
                            {
                                "name": "GROQ_API_KEY",
                                "requirement": "required",
                                "category": "ai-tier-free",
                                "tier": "free",
                                "description": "Groq host",
                            },
                        ],
                    }
                ),
                encoding="utf-8",
            )
            keys_json = root / "supabase_secrets.json"
            keys_json.write_text(
                json.dumps([{"name": "GROQ_API_KEY", "hash_tag": "masked"}]),
                encoding="utf-8",
            )
            parsed_names = validator.parse_present_keys_file(keys_json)
            report = validator.evaluate(
                root=root,
                manifest_path=manifest,
                functions_dir=root / "missing-dir",
                strict_mode=True,
                env={"HAS_DEEPINFRA_API_KEY": "true"},
                present_key_names=parsed_names,
            )
            self.assertEqual(report["status"], "pass")
            self.assertEqual(report["missing_required"], [])
            serialized = json.dumps(report)
            self.assertNotIn("masked", serialized)

    def test_main_strict_cli_outputs_files_and_exit_code(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            out_dir = Path(tmp)
            json_out = out_dir / "report.json"
            md_out = out_dir / "report.md"
            gh_out = out_dir / "github_output.txt"
            stdout_buf = io.StringIO()
            stderr_buf = io.StringIO()
            with mock.patch.dict("os.environ", {"HAS_DEEPINFRA_API_KEY": "false"}, clear=False):
                with redirect_stdout(stdout_buf), redirect_stderr(stderr_buf):
                    rc = validator.main(
                        [
                            "--root",
                            str(ROOT),
                            "--require-secrets",
                            "--dry-run",
                            "--json-out",
                            str(json_out),
                            "--markdown-out",
                            str(md_out),
                            "--github-output",
                            str(gh_out),
                        ]
                    )
            self.assertEqual(rc, 1)
            self.assertTrue(json_out.exists())
            self.assertTrue(md_out.exists())
            self.assertIn("status=fail", gh_out.read_text(encoding="utf-8"))
            self.assertIn("DEEPINFRA_API_KEY", md_out.read_text(encoding="utf-8"))

    def test_ssrf_blocks_private_cgnat_ipv4_mapped_and_pins_public_ip(self) -> None:
        for bad_ip in ("127.0.0.1", "10.0.0.5", "169.254.169.254", "100.64.0.1", "::ffff:127.0.0.1"):
            fake_info = [(2, 1, 6, "", (bad_ip, 443))]
            with mock.patch.object(validator.socket, "getaddrinfo", return_value=fake_info):
                with self.assertRaises(ValueError):
                    validator.validate_and_resolve_https_url("https://hooks.example.com/alert")

        with self.assertRaises(ValueError):
            validator.validate_and_resolve_https_url("http://hooks.example.com/alert")

        public_info = [(2, 1, 6, "", ("93.184.216.34", 443))]
        with mock.patch.object(validator.socket, "getaddrinfo", return_value=public_info):
            parsed, pinned_ip = validator.validate_and_resolve_https_url("https://hooks.example.com/alert")
        self.assertEqual(parsed.hostname, "hooks.example.com")
        self.assertEqual(pinned_ip, "93.184.216.34")

    def test_self_test_passes(self) -> None:
        result = validator.run_self_test()
        self.assertEqual(result["self_test"], "passed")


if __name__ == "__main__":
    unittest.main()
