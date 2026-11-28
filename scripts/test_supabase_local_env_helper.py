#!/usr/bin/env python3
"""Unit tests for scripts/supabase_local_env_helper.py (#2803)."""

from __future__ import annotations

from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))

import supabase_local_env_helper as helper  # noqa: E402


class SupabaseLocalEnvHelperTest(unittest.TestCase):
    def test_validate_supabase_config_accepts_repo_config(self) -> None:
        repo_root = Path(__file__).resolve().parent.parent
        res = helper.validate_supabase_config(
            repo_root / "supabase" / "config.toml",
        )
        self.assertTrue(res.valid)
        self.assertEqual(res.api_port, 54321)
        self.assertEqual(res.db_port, 54322)
        self.assertEqual(res.studio_port, 54323)

    def test_validate_env_file_rejects_remote_url_when_local_required(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            env_path = Path(tmp) / ".env.local"
            env_path.write_text(
                "\n".join(
                    [
                        "SUPABASE_URL=https://prod.supabase.co",
                        "SUPABASE_ANON_KEY=local",
                    ]
                )
                + "\n",
                encoding="utf-8",
            )
            res = helper.validate_env_file(env_path, require_local=True)
            self.assertFalse(res.valid)
            self.assertTrue(res.non_local_url)

    def test_validate_env_file_accepts_localhost_and_detects_placeholders(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            good_path = Path(tmp) / ".env.good"
            good_path.write_text(
                "\n".join(
                    [
                        "SUPABASE_URL=http://127.0.0.1:54321",
                        "SUPABASE_ANON_KEY=local",
                    ]
                )
                + "\n",
                encoding="utf-8",
            )
            good_res = helper.validate_env_file(good_path, require_local=True)
            self.assertTrue(good_res.valid)
            self.assertEqual(good_res.missing_keys, [])

            placeholder_path = Path(tmp) / ".env.placeholder"
            placeholder_path.write_text(
                "\n".join(
                    [
                        "SUPABASE_URL=your_url",
                        "SUPABASE_ANON_KEY=your_key",
                    ]
                )
                + "\n",
                encoding="utf-8",
            )
            ph_res = helper.validate_env_file(
                placeholder_path,
                require_local=False,
            )
            self.assertFalse(ph_res.valid)
            self.assertEqual(
                ph_res.placeholder_keys,
                ["SUPABASE_URL", "SUPABASE_ANON_KEY"],
            )

    def test_build_local_workflow_plan_orders_docker_start_reset_flutter(
        self,
    ) -> None:
        plan = helper.build_local_workflow_plan(env_file=".env.local")
        steps = [item["step"] for item in plan]
        self.assertEqual(
            steps,
            [
                "verify_docker",
                "start_supabase",
                "reset_and_seed_db",
                "inspect_local_keys",
                "serve_edge_functions",
                "run_flutter_web",
            ],
        )


if __name__ == "__main__":
    unittest.main()
