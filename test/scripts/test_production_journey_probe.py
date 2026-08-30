#!/usr/bin/env python3
from __future__ import annotations

import json
import shutil
import tempfile
import unittest
from pathlib import Path

from scripts.production_journey_probe import ContractError, run_probe
from scripts.prerender_seo_routes import main as prerender_main


BASE = "https://my-web-app-b67f4.web.app"
ROOT_TITLE = "自分株式会社とは？ | 人生を経営するAIライフマネジメントアプリ"
ROOT_DESCRIPTION = (
    "自分株式会社は、自分自身を一つの会社に見立て、仕事・学習・お金・健康を"
    "整理するライフマネジメントアプリです。登録前にAIの提案を1件試せます。"
)


def render_html(
    *,
    title: str,
    description: str,
    path: str,
    marker: str,
) -> str:
    return f"""<!doctype html>
<html lang="ja"><head>
<title>{title}</title>
<meta name="description" content="{description}">
<link rel="canonical" href="{BASE}{path}">
<meta property="og:url" content="{BASE}{path}">
</head><body>{marker}</body></html>
"""


class ProductionJourneyProbeTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)
        self.root = Path(self.temp_dir.name)
        self.config = self.root / "public-routes.json"
        self.config.write_text(
            json.dumps(
                {
                    "routes": [
                        {
                            "path": "/subscription-billing",
                            "title": "プランと応援 | 自分株式会社",
                            "description": "承認済み料金プランです。",
                            "contract_markers": ["月額980円", "entry=static_pricing"],
                        },
                        {
                            "path": "/privacy",
                            "title": "プライバシーポリシー | 自分株式会社",
                            "description": "承認済みデータ取扱方針です。",
                            "contract_markers": ["ユーザーの権利"],
                        },
                    ]
                },
                ensure_ascii=False,
            ),
            encoding="utf-8",
        )
        (self.root / "index.html").write_text(
            render_html(
                title=ROOT_TITLE,
                description=ROOT_DESCRIPTION,
                path="/",
                marker="登録前にAI提案を1件体験",
            ),
            encoding="utf-8",
        )
        billing = self.root / "subscription-billing"
        billing.mkdir()
        (billing / "index.html").write_text(
            render_html(
                title="プランと応援 | 自分株式会社",
                description="承認済み料金プランです。",
                path="/subscription-billing",
                marker="月額980円 entry=static_pricing",
            ),
            encoding="utf-8",
        )
        privacy = self.root / "privacy"
        privacy.mkdir()
        (privacy / "index.html").write_text(
            render_html(
                title="プライバシーポリシー | 自分株式会社",
                description="承認済みデータ取扱方針です。",
                path="/privacy",
                marker="ユーザーの権利",
            ),
            encoding="utf-8",
        )

    def test_local_build_accepts_unique_route_specific_responses(self) -> None:
        results = run_probe(config_path=self.config, root_dir=self.root)

        self.assertEqual([item["status"] for item in results], [200, 200, 200])
        self.assertEqual(len({item["sha256"] for item in results}), 3)
        self.assertEqual(
            [item["canonical"] for item in results],
            [f"{BASE}/", f"{BASE}/subscription-billing", f"{BASE}/privacy"],
        )

    def test_contract_rejects_missing_approved_content(self) -> None:
        billing = self.root / "subscription-billing" / "index.html"
        billing.write_text(
            billing.read_text(encoding="utf-8").replace("月額980円", "料金未定"),
            encoding="utf-8",
        )

        with self.assertRaisesRegex(
            ContractError,
            "approved content marker missing",
        ):
            run_probe(config_path=self.config, root_dir=self.root)

    def test_contract_rejects_homepage_metadata_leaking_to_subroute(self) -> None:
        billing = self.root / "subscription-billing" / "index.html"
        billing.write_text(
            billing.read_text(encoding="utf-8").replace(
                "プランと応援 | 自分株式会社",
                ROOT_TITLE,
            ),
            encoding="utf-8",
        )

        with self.assertRaisesRegex(ContractError, "title mismatch"):
            run_probe(config_path=self.config, root_dir=self.root)

    def test_release_readiness_runs_live_contract_after_deploy(self) -> None:
        repo_root = Path(__file__).resolve().parents[2]
        workflow = (
            repo_root / ".github" / "workflows" / "release-readiness.yml"
        ).read_text(encoding="utf-8")

        self.assertIn('      - "Deploy to Production"', workflow)
        self.assertEqual(workflow.count("scripts/production_journey_probe.py"), 1)
        self.assertIn("--base-url", workflow)
        self.assertIn("github.event.workflow_run.conclusion == 'success'", workflow)

    def test_deploy_prod_blocks_on_built_static_route_contract(self) -> None:
        repo_root = Path(__file__).resolve().parents[2]
        workflow = (
            repo_root / ".github" / "workflows" / "deploy-prod.yml"
        ).read_text(encoding="utf-8")

        probe_position = workflow.index("scripts/production_journey_probe.py")
        deploy_position = workflow.index("npx -y firebase-tools@latest deploy")
        self.assertLess(probe_position, deploy_position)
        self.assertEqual(workflow.count("scripts/production_journey_probe.py"), 1)
        self.assertIn("--root-dir build/web", workflow)
        self.assertIn("--public-routes web/seo/public-routes.json", workflow)

    def test_real_generator_output_satisfies_the_local_contract(self) -> None:
        repo_root = Path(__file__).resolve().parents[2]
        output = self.root / "real-build"
        output.mkdir()
        shutil.copyfile(repo_root / "web" / "index.html", output / "index.html")

        exit_code = prerender_main(
            [
                "--template",
                str(output / "index.html"),
                "--outdir",
                str(output),
                "--routes",
                str(repo_root / "web" / "seo" / "comparison-routes.json"),
                "--public-routes",
                str(repo_root / "web" / "seo" / "public-routes.json"),
            ]
        )

        self.assertEqual(exit_code, 0)
        results = run_probe(
            config_path=repo_root / "web" / "seo" / "public-routes.json",
            root_dir=output,
        )
        self.assertEqual(len({item["sha256"] for item in results}), 3)


if __name__ == "__main__":
    unittest.main()
