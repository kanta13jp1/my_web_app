#!/usr/bin/env python3
"""Tests for the NotebookLM video-pipeline secret readiness gate."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/check_video_pipeline_secret_readiness.py"
SPEC = importlib.util.spec_from_file_location("video_pipeline_secret_readiness", SCRIPT)
assert SPEC and SPEC.loader
video_pipeline_secret_readiness = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(video_pipeline_secret_readiness)


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


class VideoPipelineSecretReadinessTest(unittest.TestCase):
    def make_root(self) -> tempfile.TemporaryDirectory[str]:
        temp = tempfile.TemporaryDirectory()
        root = Path(temp.name)
        write(
            root / ".github/workflows/notebooklm-video-pipeline.yml",
            "\n".join(
                (
                    "name: NotebookLM Video Pipeline",
                    "run: python scripts/check_video_pipeline_secret_readiness.py",
                    "name: Check required video pipeline secrets",
                    "HAS_GITHUB_PAT: true",
                    "token: ${{ secrets.GITHUB_PAT || github.token }}",
                )
            ),
        )
        write(
            root / ".github/workflows/video-pipeline-secret-readiness.yml",
            "\n".join(
                (
                    "name: Video Pipeline Secret Readiness",
                    "run: python scripts/check_video_pipeline_secret_readiness.py --require-secrets",
                    "uses: actions/upload-artifact@0123456789012345678901234567890123456789 # v7",
                )
            ),
        )
        write(
            root / "docs/GA_LAUNCH_READINESS_GATE_SPEC.md",
            "GITHUB_PAT NOTEBOOKLM_STORAGE_STATE_JSON ELEVENLABS_API_KEY "
            "YOUTUBE_CLIENT_SECRET_JSON YOUTUBE_TOKEN_JSON",
        )
        write(
            root / "docs/AI_VIDEO_PRINCIPLES.md",
            "#1724 YOUTUBE_TOKEN_JSON NOTEBOOKLM_STORAGE_STATE_JSON",
        )
        return temp

    def test_missing_secrets_warn_without_strict_mode(self) -> None:
        with self.make_root() as temp:
            report = video_pipeline_secret_readiness.evaluate(
                root=Path(temp),
                require_secrets=False,
                env={},
            )

        self.assertEqual(report["status"], "warn")
        self.assertTrue(report["missing_secrets"])

    def test_missing_secrets_fail_with_strict_mode(self) -> None:
        with self.make_root() as temp:
            report = video_pipeline_secret_readiness.evaluate(
                root=Path(temp),
                require_secrets=True,
                env={},
            )

        self.assertEqual(report["status"], "fail")
        self.assertIn("GITHUB_PAT", report["missing_secrets"])
        self.assertIn("YOUTUBE_TOKEN_JSON", report["missing_secrets"])

    def test_secret_flags_pass_strict_mode(self) -> None:
        env = {f"HAS_{name}": "true" for name in video_pipeline_secret_readiness.REQUIRED_SECRETS}
        with self.make_root() as temp:
            report = video_pipeline_secret_readiness.evaluate(
                root=Path(temp),
                require_secrets=True,
                env=env,
            )

        self.assertEqual(report["status"], "pass")
        self.assertEqual(report["missing_secrets"], [])

    def test_missing_workflow_marker_fails(self) -> None:
        with self.make_root() as temp:
            root = Path(temp)
            write(root / ".github/workflows/notebooklm-video-pipeline.yml", "name: NotebookLM Video Pipeline")
            env = {f"HAS_{name}": "true" for name in video_pipeline_secret_readiness.REQUIRED_SECRETS}
            report = video_pipeline_secret_readiness.evaluate(
                root=root,
                require_secrets=True,
                env=env,
            )

        failed = {check["name"] for check in report["checks"] if check["status"] == "fail"}
        self.assertIn("notebooklm video pipeline preflight", failed)


if __name__ == "__main__":
    unittest.main()
