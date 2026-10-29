#!/usr/bin/env python3
"""Classify changed paths so CI runs only the relevant expensive toolchains."""

from __future__ import annotations

import argparse
import fnmatch
from pathlib import Path


GROUPS: dict[str, tuple[str, ...]] = {
    "flutter": (
        "lib/**",
        "test/**",
        "integration_test/**",
        "web/**",
        "assets/**",
        "pubspec.yaml",
        "pubspec.lock",
        "analysis_options.yaml",
        "l10n.yaml",
        "firebase.json",
        "playwright.config.ts",
        "playwright.business-execution.config.ts",
        "package.json",
        "package-lock.json",
    ),
    "web": (
        "lib/**",
        "integration_test/**",
        "web/**",
        "assets/**",
        "pubspec.yaml",
        "pubspec.lock",
        "analysis_options.yaml",
        "l10n.yaml",
        "firebase.json",
    ),
    "business_execution": (
        "lib/models/business_execution.dart",
        "lib/pages/virtual_organization_page.dart",
        "lib/services/business_execution*.dart",
        "lib/view_models/business_execution_controller.dart",
        "lib/widgets/business_execution*.dart",
        "test/models/business_execution_test.dart",
        "test/view_models/business_execution_controller_test.dart",
        "test/widgets/business_execution_panel_test.dart",
        "test/web/business_execution_lock_test.dart",
        "test/e2e/business_execution.spec.ts",
        "test/fixtures/business_execution_app.dart",
        "playwright.config.ts",
        "playwright.business-execution.config.ts",
        "package.json",
        "package-lock.json",
        "pubspec.yaml",
        "pubspec.lock",
        "web/**",
        ".github/workflows/ci.yml",
        "scripts/classify_ci_changes.py",
        "scripts/classify_ci_changes_test.py",
        "scripts/serve_business_execution_fixture.py",
        "scripts/serve_business_execution_fixture_test.py",
    ),
    "edge": (
        "supabase/functions/**",
        "supabase/config.toml",
    ),
    "caption": ("services/caption-transcoder/**",),
    "migration": ("supabase/migrations/**",),
    "tiger": ("assets/data/tiger_*",),
}

# These exact Python suites are executed by Agent Skill Contract on every
# matching PR. Keep unknown tests conservative: only this audited allowlist
# can avoid Flutter; Dart tests and mixed application changes still run it.
SKILL_CONTRACT_TESTS = (
    "test/scripts/test_validate_agent_skills.py",
    "test/scripts/test_agent_skill_cli_contract.py",
    "test/scripts/test_design_ssot_contract.py",
    "test/scripts/test_musubi_skill_scripts.py",
    "test/scripts/test_youtube_skill_scripts.py",
)

# Notion Migration Cloud Audit validates these exact suites on matching PRs.
# Do not expand this to test/scripts/**: other tests may require Flutter.
NOTION_AUDIT_TESTS = (
    "test/scripts/test_notion_migration_cloud_audit.py",
    "test/scripts/test_notion_wbs_import_plan.py",
)

IGNORED_PATTERNS: dict[str, tuple[str, ...]] = {
    "flutter": ("assets/data/tiger_*", *SKILL_CONTRACT_TESTS, *NOTION_AUDIT_TESTS),
    "web": ("assets/data/tiger_*",),
}


def classify(paths: list[str], force_all: bool = False) -> dict[str, bool]:
    normalized = [path.strip().replace("\\", "/") for path in paths if path.strip()]
    result = {
        group: force_all
        or any(
            fnmatch.fnmatchcase(path, pattern)
            and not any(
                fnmatch.fnmatchcase(path, ignored)
                for ignored in IGNORED_PATTERNS.get(group, ())
            )
            for path in normalized
            for pattern in patterns
        )
        for group, patterns in GROUPS.items()
    }
    # The fixture needs the existing SDK/dependency steps, but is not a release.
    result["flutter"] = result["flutter"] or result["business_execution"]
    result["deployable"] = result["web"] or result["edge"] or result["migration"]
    return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--changed-files", type=Path, required=True)
    parser.add_argument("--github-output", type=Path)
    parser.add_argument("--all", action="store_true", dest="force_all")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    paths = (
        args.changed_files.read_text(encoding="utf-8").splitlines()
        if args.changed_files.exists()
        else []
    )
    result = classify(paths, force_all=args.force_all)
    lines = [f"{name}={str(enabled).lower()}" for name, enabled in result.items()]
    print("\n".join(lines))
    if args.github_output:
        with args.github_output.open("a", encoding="utf-8") as output:
            output.write("\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
