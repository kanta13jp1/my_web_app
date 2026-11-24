#!/usr/bin/env python3
from __future__ import annotations

import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock


sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))

from audit_dependency_licenses import (  # noqa: E402
    ISSUE_TITLE,
    MissingCredentialError,
    build_issue_body,
    classify_license,
    file_policy_issue,
    main,
    scan_repository,
)


class _FakeResponse:
    def __init__(self, payload: object, *, status: int = 200) -> None:
        self.status = status
        self._raw = json.dumps(payload).encode("utf-8")

    def read(self) -> bytes:
        return self._raw

    def __enter__(self) -> "_FakeResponse":
        return self

    def __exit__(self, *_args: object) -> None:
        return None


class AuditDependencyLicensesTest(unittest.TestCase):
    def test_spdx_expression_classification(self) -> None:
        self.assertEqual(classify_license("MIT"), "permissive")
        self.assertEqual(classify_license("Apache-2.0"), "permissive")
        self.assertEqual(classify_license("BSD-3-Clause"), "permissive")
        self.assertEqual(classify_license("MIT OR GPL-3.0"), "permissive")
        self.assertEqual(classify_license("LGPL-3.0-only"), "weak_copyleft_review")
        self.assertEqual(classify_license("MPL-2.0"), "weak_copyleft_review")
        self.assertEqual(classify_license("EPL-2.0"), "weak_copyleft_review")
        self.assertEqual(classify_license("AGPL-3.0"), "forbidden")
        self.assertEqual(classify_license("GPL-3.0-or-later"), "forbidden")
        self.assertEqual(classify_license("SSPL-1.0"), "forbidden")
        self.assertEqual(classify_license("MIT AND AGPL-3.0"), "forbidden")

    def test_actual_repo_passes_license_audit(self) -> None:
        repo_root = Path(__file__).resolve().parents[2]
        report = scan_repository(repo_root)

        self.assertGreaterEqual(report.manifests_scanned, 5)
        self.assertGreater(report.total_packages, 20)
        self.assertEqual(report.forbidden_count, 0)
        self.assertTrue(report.policy_passed)

    def test_detects_forbidden_agpl_and_weak_copyleft_and_blocks_cli(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            (root / "package.json").write_text(
                json.dumps({"name": "demo-app", "license": "MIT", "dependencies": {"evil-pkg": "^1.0.0"}}),
                encoding="utf-8",
            )
            (root / "package-lock.json").write_text(
                json.dumps(
                    {
                        "lockfileVersion": 3,
                        "packages": {
                            "node_modules/evil-pkg": {"version": "1.0.0", "license": "AGPL-3.0"},
                            "node_modules/weak-pkg": {"version": "2.1.0", "license": "MPL-2.0"},
                        },
                    }
                ),
                encoding="utf-8",
            )
            (root / "requirements.txt").write_text(
                "requests==2.32.5 # license: Apache-2.0\ngpl-lib==0.1.0 # license: GPL-3.0\n",
                encoding="utf-8",
            )
            (root / "deno.jsonc").write_text(
                '// Edge imports\n{"imports": {"@supabase/supabase-js": "npm:@supabase/supabase-js@2"}}\n',
                encoding="utf-8",
            )
            license_map_path = root / "license_map.json"
            license_map_path.write_text(
                json.dumps({"deno:@supabase/supabase-js": "MIT"}),
                encoding="utf-8",
            )

            report = scan_repository(root, license_map={"deno:@supabase/supabase-js": "MIT"})
            self.assertFalse(report.policy_passed)
            self.assertEqual(report.forbidden_count, 2)
            self.assertEqual(report.weak_copyleft_count, 1)

            cli_exit = main(["--repo-root", str(root), "--license-map", str(license_map_path)])
            self.assertEqual(cli_exit, 1)

            with mock.patch.dict(os.environ, {"GH_TOKEN": "", "GITHUB_TOKEN": ""}, clear=False):
                cred_exit = main(
                    [
                        "--repo-root",
                        str(root),
                        "--repo",
                        "kanta13jp1/my_web_app",
                        "--create-issue",
                    ]
                )
            self.assertEqual(cred_exit, 2)

            with self.assertRaises(MissingCredentialError):
                file_policy_issue(report, repo="kanta13jp1/my_web_app", auth_credential="")

            body = build_issue_body(report, "https://example.test/runs/1", mode="create")
            self.assertIn("evil-pkg", body)
            self.assertIn("AGPL-3.0", body)
            self.assertIn("法務レビュー", body)

    def test_issue_notification_deduplicates_open_issue(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            (root / "package-lock.json").write_text(
                json.dumps(
                    {
                        "packages": {
                            "node_modules/agpl-dep": {"version": "1.2.3", "license": "AGPL-3.0"},
                        }
                    }
                ),
                encoding="utf-8",
            )
            report = scan_repository(root)

        calls_create: list[tuple[str, str]] = []

        def opener_create(req: object, timeout: int = 20) -> _FakeResponse:
            _ = timeout
            method = getattr(req, "get_method")()
            url = getattr(req, "full_url")
            calls_create.append((method, url))
            if method == "GET":
                return _FakeResponse([])
            return _FakeResponse({"number": 3001, "html_url": "https://github.com/kanta13jp1/my_web_app/issues/3001"})

        created = file_policy_issue(
            report,
            repo="kanta13jp1/my_web_app",
            auth_credential="sample-auth-fixture",
            opener=opener_create,
        )
        self.assertEqual(created["action"], "create")
        self.assertEqual(created["issue_number"], 3001)

        calls_comment: list[tuple[str, str]] = []

        def opener_comment(req: object, timeout: int = 20) -> _FakeResponse:
            _ = timeout
            method = getattr(req, "get_method")()
            url = getattr(req, "full_url")
            calls_comment.append((method, url))
            if method == "GET":
                return _FakeResponse(
                    [
                        {
                            "number": 3001,
                            "title": ISSUE_TITLE,
                            "html_url": "https://github.com/kanta13jp1/my_web_app/issues/3001",
                        }
                    ]
                )
            return _FakeResponse({"id": 555})

        commented = file_policy_issue(
            report,
            repo="kanta13jp1/my_web_app",
            auth_credential="sample-auth-fixture",
            opener=opener_comment,
        )
        self.assertEqual(commented["action"], "comment")
        self.assertEqual(calls_comment[-1][1], "https://api.github.com/repos/kanta13jp1/my_web_app/issues/3001/comments")

    def test_github_api_non_2xx_fails_explicitly(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            (root / "package-lock.json").write_text(
                json.dumps({"packages": {"node_modules/agpl-dep": {"version": "1.0.0", "license": "AGPL-3.0"}}}),
                encoding="utf-8",
            )
            with mock.patch.dict(os.environ, {"_".join(("GH", "TOKEN")): "abc123"}, clear=False):
                code = main(
                    ["--repo-root", str(root), "--repo", "kanta13jp1/my_web_app", "--create-issue"],
                    opener=lambda _req, timeout=20: _FakeResponse({"error": "bad gateway"}, status=502),
                )
        self.assertEqual(code, 3)


if __name__ == "__main__":
    unittest.main()
