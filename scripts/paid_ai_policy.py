#!/usr/bin/env python3
"""Fail-closed billing policy for paid Claude and Codex automation.

The owner-controlled repository variable is necessary but not sufficient:
paid credentials are exposed only when the variable is explicitly ``true``
and GitHub reports zero open Issues.  A failed Issue-count lookup disables the
paid path while allowing deterministic or free-provider fallbacks to continue.
"""

from __future__ import annotations

import argparse
import json
import os
from dataclasses import dataclass
from pathlib import Path
import sys
from typing import Callable
import urllib.error
import urllib.parse
import urllib.request


PAID_AI_VARIABLE = "PAID_AI_CLAUDE_CODEX_ENABLED"
EXEMPT_ADMIN_WORKFLOWS = {"shared-secret-environment-migration.yml"}
PAID_PROVIDER_ENDPOINTS = (
    "api.anthropic.com",
    "api.openai.com",
)
PROTECTED_REFERENCES = (
    "secrets.ANTHROPIC_API_KEY",
    "secrets.CLAUDE_CODE_OAUTH_TOKEN",
    "secrets.OPENAI_API_KEY",
    "vars.OPENAI_WIF_AUDIENCE",
    "vars.OPENAI_IDENTITY_PROVIDER_ID",
    "vars.OPENAI_SERVICE_ACCOUNT_ID",
)
REQUIRED_GUARDS = (
    f"vars.{PAID_AI_VARIABLE} == 'true'",
    "steps.paid_ai_policy.outputs.enabled == 'true'",
)


@dataclass(frozen=True)
class PolicyDecision:
    enabled: bool
    reason: str
    open_issue_count: int | None
    detail: str = ""


def decide_policy(
    requested: str | bool | None,
    open_issue_count: int | None = None,
    *,
    lookup_error: str = "",
) -> PolicyDecision:
    """Return the fail-closed paid-AI decision."""

    requested_enabled = (
        requested if isinstance(requested, bool) else str(requested or "").lower() == "true"
    )
    if not requested_enabled:
        return PolicyDecision(False, "owner-disabled", None)
    if lookup_error or open_issue_count is None:
        return PolicyDecision(
            False,
            "issue-count-unavailable",
            None,
            lookup_error or "GitHub did not return an open-Issue count.",
        )
    if open_issue_count < 0:
        return PolicyDecision(False, "invalid-issue-count", None)
    if open_issue_count > 0:
        return PolicyDecision(False, "open-issues-remain", open_issue_count)
    return PolicyDecision(True, "enabled-after-issues-zero", 0)


def fetch_open_issue_count(
    repository: str,
    token: str,
    *,
    opener: Callable[..., object] = urllib.request.urlopen,
) -> int:
    """Fetch the number of open GitHub Issues, excluding pull requests."""

    if not repository or "/" not in repository:
        raise ValueError("repository must be in owner/name form")
    query = urllib.parse.urlencode({"q": f"repo:{repository} is:issue is:open"})
    request = urllib.request.Request(
        f"https://api.github.com/search/issues?{query}",
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "my-web-app-paid-ai-policy",
        },
    )
    with opener(request, timeout=20) as response:  # type: ignore[attr-defined]
        payload = json.loads(response.read().decode("utf-8"))
    count = payload.get("total_count")
    if not isinstance(count, int):
        raise ValueError("GitHub search response omitted total_count")
    return count


def append_output(path: str, decision: PolicyDecision) -> None:
    if not path:
        return
    count = "unknown" if decision.open_issue_count is None else str(decision.open_issue_count)
    with Path(path).open("a", encoding="utf-8", newline="\n") as handle:
        handle.write(f"enabled={str(decision.enabled).lower()}\n")
        handle.write(f"reason={decision.reason}\n")
        handle.write(f"open_issue_count={count}\n")


def append_summary(path: str, decision: PolicyDecision) -> None:
    if not path:
        return
    count = "not checked" if decision.open_issue_count is None else str(decision.open_issue_count)
    state = "ENABLED" if decision.enabled else "DISABLED"
    lines = [
        "## Paid Claude/Codex billing policy",
        "",
        f"- State: **{state}**",
        f"- Reason: `{decision.reason}`",
        f"- Open Issues: `{count}`",
        f"- Owner variable: `{PAID_AI_VARIABLE}`",
    ]
    if decision.detail:
        lines.append(f"- Detail: `{decision.detail[:300]}`")
    lines.extend(
        [
            "",
            "Reactivation is manual and is allowed only after the repository reaches zero open Issues.",
            "",
        ]
    )
    with Path(path).open("a", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines))


def gate_command(args: argparse.Namespace) -> int:
    requested = args.requested
    if str(requested or "").lower() != "true":
        decision = decide_policy(requested)
    else:
        try:
            count = fetch_open_issue_count(args.repository, os.environ.get("GH_TOKEN", ""))
            decision = decide_policy(requested, count)
        except (OSError, ValueError, urllib.error.URLError, json.JSONDecodeError) as exc:
            decision = decide_policy(requested, lookup_error=str(exc))

    append_output(args.github_output, decision)
    append_summary(args.step_summary, decision)
    print(
        f"paid Claude/Codex: {decision.reason}; "
        f"enabled={str(decision.enabled).lower()}; "
        f"open_issues={decision.open_issue_count}"
    )
    return 0


def audit_workflows(workflows_dir: Path) -> list[str]:
    """Find paid credential references that bypass the central policy gate."""

    errors: list[str] = []
    for path in sorted((*workflows_dir.glob("*.yml"), *workflows_dir.glob("*.yaml"))):
        text = path.read_text(encoding="utf-8")
        if path.name in EXEMPT_ADMIN_WORKFLOWS:
            if any(endpoint in text for endpoint in PAID_PROVIDER_ENDPOINTS):
                errors.append(
                    f"{path}: administrative migration workflow must not call a paid provider"
                )
            continue
        protected_lines: list[tuple[int, str]] = []
        for line_number, line in enumerate(text.splitlines(), 1):
            if any(reference in line for reference in PROTECTED_REFERENCES):
                protected_lines.append((line_number, line))
                missing = [guard for guard in REQUIRED_GUARDS if guard not in line]
                if missing:
                    errors.append(
                        f"{path}:{line_number}: paid credential reference is missing "
                        f"guard(s): {', '.join(missing)}"
                    )
        if protected_lines and "id: paid_ai_policy" not in text:
            errors.append(f"{path}: missing paid_ai_policy step")
    return errors


def audit_command(args: argparse.Namespace) -> int:
    errors = audit_workflows(Path(args.workflows_dir))
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print("Paid Claude/Codex workflow credential audit passed.")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    gate = subparsers.add_parser("gate", help="Resolve the live paid-AI policy")
    gate.add_argument("--requested", default="false")
    gate.add_argument("--repository", required=True)
    gate.add_argument("--github-output", default=os.environ.get("GITHUB_OUTPUT", ""))
    gate.add_argument("--step-summary", default=os.environ.get("GITHUB_STEP_SUMMARY", ""))
    gate.set_defaults(func=gate_command)

    audit = subparsers.add_parser("audit", help="Audit workflow credential guards")
    audit.add_argument("--workflows-dir", default=".github/workflows")
    audit.set_defaults(func=audit_command)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
