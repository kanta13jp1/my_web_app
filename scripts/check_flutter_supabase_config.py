#!/usr/bin/env python3
"""Fail when Flutter/web sources embed Supabase project configuration."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEPLOY_WORKFLOWS = (
    ".github/workflows/deploy-dev.yml",
    ".github/workflows/deploy-staging.yml",
    ".github/workflows/deploy-prod.yml",
)

SOURCE_PATTERNS = (
    (
        "concrete Supabase project URL",
        re.compile(r"(?:https?:)?//[a-z0-9]{20}\.supabase\.co", re.IGNORECASE),
    ),
    (
        "JWT-shaped credential",
        re.compile(r"eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}"),
    ),
    ("Supabase secret key", re.compile(r"sb_secret_[A-Za-z0-9_-]{8,}")),
    ("literal Supabase publishable key", re.compile(r"sb_publishable_[A-Za-z0-9_-]{8,}")),
    (
        "server-only Supabase environment variable",
        re.compile(r"SUPABASE_(?:SERVICE_ROLE_KEY|SECRET_KEY)"),
    ),
    (
        "literal Supabase project ref",
        re.compile(
            r"(?:project(?:Ref|Id)|project_(?:ref|id))\s*=\s*['\"][a-z0-9]{20}['\"]",
            re.IGNORECASE,
        ),
    ),
)


def source_violations(label: str, text: str) -> list[str]:
    violations: list[str] = []
    normalized_text = re.sub(r"['\"]\s*['\"]", "", text)
    for description, pattern in SOURCE_PATTERNS:
        if pattern.search(normalized_text):
            violations.append(f"{label}: {description}")
    return violations


def check_runtime_config(text: str) -> list[str]:
    violations: list[str] = []
    for variable in ("SUPABASE_URL", "SUPABASE_PUBLISHABLE_KEY"):
        match = re.search(
            rf"String\.fromEnvironment\(\s*'{variable}'(?P<body>.*?)\)",
            text,
            re.DOTALL,
        )
        if match is None:
            violations.append(f"runtime config does not read {variable}")
        elif "defaultValue" in match.group("body"):
            violations.append(f"runtime config hardcodes a default for {variable}")
    if "String.fromEnvironment(\n      'SUPABASE_ANON_KEY'" in text:
        violations.append("runtime config still reads legacy SUPABASE_ANON_KEY")
    if "sb_secret_" not in text or "service_role" not in text:
        violations.append("runtime config does not reject server-only key forms")
    return violations


def check_repository(root: Path = ROOT) -> list[str]:
    violations: list[str] = []
    source_files = sorted(
        path
        for directory in ("lib", "integration_test", "test_driver")
        for path in (root / directory).rglob("*.dart")
    ) + [root / "web/index.html"]
    for path in source_files:
        violations.extend(
            source_violations(path.relative_to(root).as_posix(), path.read_text(encoding="utf-8"))
        )

    runtime_path = root / "lib/services/supabase_runtime_config.dart"
    violations.extend(check_runtime_config(runtime_path.read_text(encoding="utf-8")))

    web_shell = (root / "web/index.html").read_text(encoding="utf-8")
    if "__SUPABASE_URL__" not in web_shell:
        violations.append("web/index.html does not use the Supabase URL placeholder")

    for relative in DEPLOY_WORKFLOWS:
        workflow = (root / relative).read_text(encoding="utf-8")
        if "SUPABASE_PUBLISHABLE_KEY" not in workflow:
            violations.append(f"{relative}: publishable key is not injected")
        if "render_web_supabase_config.py" not in workflow:
            violations.append(f"{relative}: web URL render step is missing")
        if "validate_flutter_supabase_env.py" not in workflow:
            violations.append(f"{relative}: pre-build public-key validation is missing")
        if "--dart-define=SUPABASE_ANON_KEY" in workflow:
            violations.append(f"{relative}: legacy key variable is injected into Flutter")
        if re.search(
            r"--dart-define=[^\s]*(?:SERVICE_ROLE|SECRET_KEY)",
            workflow,
            re.IGNORECASE,
        ):
            violations.append(f"{relative}: a server-only key is injected into Flutter")
    return violations


def main() -> int:
    violations = check_repository()
    if violations:
        print("Flutter Supabase configuration check failed:")
        for violation in violations:
            print(f"- {violation}")
        return 1
    print("Flutter Supabase configuration check passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
