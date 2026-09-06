#!/usr/bin/env python3

import tempfile
import unittest
from pathlib import Path

from check_flutter_supabase_config import (
    DEPLOY_WORKFLOWS,
    check_repository,
    check_runtime_config,
    source_violations,
)


class CheckFlutterSupabaseConfigTest(unittest.TestCase):
    def test_detects_project_url_jwt_and_server_key(self) -> None:
        text = """
        const url = 'https://abcdefghijklmnopqrst.supabase.co';
        const jwt = 'eyJabcdefgh.eyJabcdefgh.signature1';
        const secret = 'sb_secret_example1';
        const publishable = 'sb_publishable_example1';
        """

        violations = source_violations("lib/example.dart", text)

        self.assertEqual(len(violations), 4)

    def test_detects_a_split_dart_jwt_without_returning_its_value(self) -> None:
        token = "eyJabcdefgh.'\n          'eyJabcdefgh.'\n          'signature1"

        violations = source_violations("lib/config.dart", token)

        self.assertEqual(violations, ["lib/config.dart: JWT-shaped credential"])
        self.assertNotIn("eyJabcdefgh", violations[0])

    def test_allows_placeholder_and_publishable_key_name(self) -> None:
        text = "const url = '__SUPABASE_URL__'; // SUPABASE_PUBLISHABLE_KEY"

        self.assertEqual(source_violations("web/index.html", text), [])

    def test_runtime_config_must_fail_closed(self) -> None:
        unsafe = """
        String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://example.test')
        String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY')
        """

        violations = check_runtime_config(unsafe)

        self.assertIn("runtime config hardcodes a default for SUPABASE_URL", violations)
        self.assertIn(
            "runtime config does not reject server-only key forms",
            violations,
        )

    def test_repository_check_detects_a_missing_prebuild_gate(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            runtime = root / "lib/services/supabase_runtime_config.dart"
            runtime.parent.mkdir(parents=True)
            runtime.write_text(
                """
                String.fromEnvironment('SUPABASE_URL')
                String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY')
                startsWith('sb_secret_')
                role == 'service_role'
                """,
                encoding="utf-8",
            )
            web = root / "web/index.html"
            web.parent.mkdir(parents=True)
            web.write_text("__SUPABASE_URL__", encoding="utf-8")
            for relative in DEPLOY_WORKFLOWS:
                workflow = root / relative
                workflow.parent.mkdir(parents=True, exist_ok=True)
                workflow.write_text(
                    """
                    validate_flutter_supabase_env.py
                    render_web_supabase_config.py
                    --dart-define=SUPABASE_PUBLISHABLE_KEY=$SUPABASE_PUBLISHABLE_KEY
                    """,
                    encoding="utf-8",
                )

            self.assertEqual(check_repository(root), [])

            for directory in ("integration_test", "test_driver"):
                with self.subTest(directory=directory):
                    fixture = root / directory / "example_test.dart"
                    fixture.parent.mkdir(parents=True, exist_ok=True)
                    fixture.write_text(
                        "const url = 'https://abcdefghijklmnopqrst.supabase.co';",
                        encoding="utf-8",
                    )
                    self.assertIn(
                        f"{directory}/example_test.dart: concrete Supabase project URL",
                        check_repository(root),
                    )
                    fixture.unlink()
            self.assertEqual(check_repository(root), [])
            broken = root / DEPLOY_WORKFLOWS[0]
            broken.write_text(
                broken.read_text(encoding="utf-8").replace(
                    "validate_flutter_supabase_env.py", ""
                ),
                encoding="utf-8",
            )
            self.assertIn(
                f"{DEPLOY_WORKFLOWS[0]}: pre-build public-key validation is missing",
                check_repository(root),
            )


if __name__ == "__main__":
    unittest.main()
