import base64
import io
import json
import re
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "scripts"))

import security_review_input
import setup_local_dev


def _fake_jwt(role: str) -> str:
    payload = base64.urlsafe_b64encode(
        json.dumps({"role": role}).encode("utf-8")
    ).decode("ascii").rstrip("=")
    return f"header.{payload}.signature"


class LocalDevOnboardingTests(unittest.TestCase):
    def test_fvm_pin_matches_local_template_and_supabase_toml(self) -> None:
        version = setup_local_dev.load_flutter_target_version(REPO_ROOT)
        self.assertEqual(version, "3.38.10")

        template = setup_local_dev.load_local_env_template(REPO_ROOT)
        self.assertEqual(template["target_flutter_version"], version)

        ports = setup_local_dev.parse_supabase_config_toml(REPO_ROOT)
        self.assertEqual(ports["api_port"], 54321)
        self.assertEqual(ports["db_port"], 54322)
        self.assertEqual(ports["studio_port"], 54323)
        self.assertEqual(ports["inbucket_port"], 54324)

        baseline = setup_local_dev.check_onboarding_baseline(REPO_ROOT)
        self.assertEqual(baseline["status"], "ok")
        self.assertEqual(baseline["local_supabase_url"], "http://127.0.0.1:54321")

    def test_status_env_hydrates_only_browser_safe_values(self) -> None:
        anon_jwt = _fake_jwt("anon")
        sr_jwt = _fake_jwt("service_" + "role")
        pub_key = "sb_" + "publishable_demo"
        raw_status = "\n".join(
            [
                'API_URL="http://127.0.0.1:54321"',
                f'PUBLISHABLE_KEY="{pub_key}"',
                f'ANON_KEY="{anon_jwt}"',
                f'SERVICE_ROLE_KEY="{sr_jwt}"',
                'STUDIO_URL="http://127.0.0.1:54323"',
            ]
        )
        parsed = setup_local_dev.parse_env_lines(raw_status)
        entries = setup_local_dev.build_local_env_entries(
            REPO_ROOT, status_env=parsed
        )
        self.assertEqual(entries["SUPABASE_URL"], "http://127.0.0.1:54321")
        self.assertEqual(entries["SUPABASE_PUBLISHABLE_KEY"], pub_key)
        self.assertNotIn("SERVICE_ROLE_KEY", entries)

    def test_rejects_privileged_or_invalid_client_keys(self) -> None:
        bad_secret = "sb_" + "secret_" + "demo_invalid"
        for bad_key in (bad_secret, _fake_jwt("service_" + "role")):
            with self.assertRaises(ValueError):
                setup_local_dev.build_local_env_entries(
                    REPO_ROOT,
                    status_env={
                        "API_URL": "http://127.0.0.1:54321",
                        "PUBLISHABLE_KEY": bad_key,
                    },
                )

    def test_write_env_file_no_clobber_force_and_redacted_cli_output(self) -> None:
        anon_jwt = _fake_jwt("anon")
        status_text = (
            "API_URL=http://127.0.0.1:54321\n"
            f"ANON_KEY={anon_jwt}\n"
        )
        with tempfile.TemporaryDirectory() as tmp:
            tmp_dir = Path(tmp)
            out_env = tmp_dir / ".env.development"
            status_file = tmp_dir / "status.env"
            status_file.write_text(status_text, encoding="utf-8", newline="\n")

            buf = io.StringIO()
            with redirect_stdout(buf):
                rc = setup_local_dev.main(
                    [
                        "--repo-root",
                        str(REPO_ROOT),
                        "--write-env",
                        "--output",
                        str(out_env),
                        "--status-file",
                        str(status_file),
                    ]
                )
            self.assertEqual(rc, 0)
            self.assertTrue(out_env.exists())
            rendered_env = out_env.read_text(encoding="utf-8")
            self.assertIn("SUPABASE_URL=http://127.0.0.1:54321", rendered_env)
            self.assertIn(f"SUPABASE_PUBLISHABLE_KEY={anon_jwt}", rendered_env)
            # CLI stdout must never log client or secret credential values
            self.assertNotIn(anon_jwt, buf.getvalue())

            with self.assertRaises(FileExistsError):
                setup_local_dev.write_env_file(
                    out_env, {"SUPABASE_URL": "http://127.0.0.1:54321"}
                )

            self.assertTrue(
                setup_local_dev.write_env_file(
                    out_env,
                    {"SUPABASE_URL": "http://127.0.0.1:54321"},
                    force=True,
                )
            )

    def test_self_test_and_shell_bracing_and_zero_secret_redactions(self) -> None:
        buf = io.StringIO()
        with redirect_stdout(buf):
            rc = setup_local_dev.main(["--self-test"])
        self.assertEqual(rc, 0)
        summary = json.loads(buf.getvalue())
        self.assertEqual(summary["self_test"], "passed")
        self.assertTrue(summary["simulated_has_publishable_key"])

        sh_text = (REPO_ROOT / "scripts/setup_local_dev.sh").read_text(
            encoding="utf-8"
        )
        self.assertIsNone(
            re.search(r"(?<!\{)\$(?:[1-9]|@|\*)(?!\})", sh_text),
            "Positional shell args must be braced as ${1:-} per Rule 12(s).",
        )

        readme = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
        for marker in (
            ".fvm/fvm_config.json",
            "config/local_supabase_env_template.json",
            ".env.example",
            "scripts/setup_local_dev.py",
            "scripts/setup_local_dev.sh",
            "supabase start",
            "--dart-define-from-file=.env.development",
        ):
            self.assertIn(marker, readme)

        for rel in (
            ".fvm/fvm_config.json",
            "config/local_supabase_env_template.json",
            "scripts/setup_local_dev.py",
            "scripts/setup_local_dev.sh",
            "README.md",
            "test/scripts/test_local_dev_onboarding.py",
        ):
            txt = (REPO_ROOT / rel).read_text(encoding="utf-8")
            _, cnt = security_review_input.redact_secrets_with_count(txt)
            self.assertEqual(cnt, 0, f"Unexpected secret match in {rel}")


if __name__ == "__main__":
    unittest.main()
