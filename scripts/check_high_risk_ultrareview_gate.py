#!/usr/bin/env python3
"""Require Claude Code #1 ultrareview evidence for high-risk PRs.

The gate is intentionally deterministic: it detects high-risk labels, paths, and
PR text, then checks that the PR body records Claude Code #1 ultrareview
evidence or a visible exception reason. It does not call an AI model itself.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


HIGH_RISK_LABELS = {
    "security",
    "supabase",
    "edge-function",
    "workflow-failure",
    "priority:critical",
    "deploy",
    "production",
}

HIGH_RISK_PATH_PATTERNS = (
    r"^supabase/migrations/",
    r"^supabase/functions/",
    r"^lib/(auth|billing|payments|subscription|firebase|supabase)/",
    r"^\.github/workflows/(deploy|.*deploy.*|ci-auto-fix|claude-agent-review|workflow-failure-handler).*\.yml$",
    r"^firebase\.json$",
    r"^firestore\.",
    r"^storage\.",
    r"(^|/)\.env",
    r"secret",
    r"credential",
    r"service[_-]?role",
    r"rls",
)

HIGH_RISK_TEXT_PATTERNS = (
    r"\bsecret\b",
    r"\bcredential\b",
    r"\btoken\b",
    r"\bauth\b",
    r"\bpayment\b",
    r"\bbilling\b",
    r"\bstripe\b",
    r"\bsubscription\b",
    r"\bproduction\b",
    r"\bdeploy\b",
    r"\bmigration\b",
    r"\brls\b",
    r"\bservice[_ -]?role\b",
)

ULTRAREVIEW_PATTERNS = (
    r"\bclaude\s+ultrareview\b",
    r"/ultrareview\b",
    r"\bultrareview\b",
)

INSTANCE_PATTERNS = (
    r"\bClaude Code #1\b",
    r"\bClaude Code 1\b",
)

NO_UNRESOLVED_PATTERNS = (
    r"\bno unresolved\b",
    r"\bunresolved\s+(findings?|items?|comments?)\s*[:=-]?\s*(0|none|no)\b",
    r"\bunresolved\s*[:=-]\s*(0|none|no)\b",
)

REQUIRED_PERSPECTIVES = {
    "security": r"\bsecurity\b",
    "rollback": r"\brollback\b",
    "data migration": r"\bdata[- ]migration\b|\bmigration\b",
    "prod smoke": r"\bprod(?:uction)?[- ]smoke\b|\bprod(?:uction)? smoke\b",
    "observability": r"\bobservability\b",
}

EXCEPTION_PATTERNS = (
    r"high[- ]risk[- ]ultrareview[- ]exception",
    r"ultrareview[- ]exception",
)

# Minimum length the cleaned exception reason must reach to count as visible.
# Mirrors the threshold enforced in has_visible_exception_reason().
EXCEPTION_REASON_MIN_LENGTH = 12


def passing_exception_block(reason: str) -> str:
    """Return a high-risk gate block that passes via the *exception* route.

    This is the honest \u6b63\u653b\u6cd5 for an AI-authored PR that did not run
    `/ultrareview`: it names Claude Code #1 as the review owner and records a
    visible exception reason. Paste the output verbatim instead of rediscovering
    the exact phrasing after a gate FAIL (editing a PR body does not re-run the
    check, so the usual recovery is a wasteful close/reopen).

    The ``reason`` must be at least EXCEPTION_REASON_MIN_LENGTH characters once
    the ``High-Risk-Ultrareview-Exception`` label is stripped, or the gate will
    not treat it as visible. The wording lives next to the pattern tables it
    must satisfy and is pinned by a round-trip test so it cannot drift.
    """
    return (
        "## High-risk Ultrareview Gate\n"
        "- Reviewer: Claude Code #1\n"
        f"- High-Risk-Ultrareview-Exception: {reason.strip()}\n"
    )


def passing_evidence_block(pr_ref: str = "this PR") -> str:
    """Return a high-risk gate block that passes via the *evidence* route.

    Use this only after Claude Code #1 has actually run `/ultrareview`; pasting
    it without a real run would falsely claim review evidence. The perspective
    list is derived from REQUIRED_PERSPECTIVES so it can never fall out of sync
    with what the validator demands.
    """
    perspectives = ", ".join(REQUIRED_PERSPECTIVES)
    return (
        "## High-risk Ultrareview Gate\n"
        "- Reviewer: Claude Code #1\n"
        f"- Evidence: Claude ultrareview completed for {pr_ref}.\n"
        f"- Perspectives covered: {perspectives}.\n"
        "- Unresolved findings: none.\n"
    )


def normalize_path(path: str) -> str:
    path = path.replace("\ufeff", "").replace("\\", "/")
    return path[2:] if path.startswith("./") else path


def has_any(patterns: tuple[str, ...], text: str) -> bool:
    return any(re.search(pattern, text, flags=re.IGNORECASE) for pattern in patterns)


def read_changed_files(path: str | None) -> list[str]:
    if not path:
        return []
    source = Path(path)
    if not source.exists():
        return []
    return [
        normalize_path(line.strip())
        for line in source.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]


def event_payload(path: str | None) -> dict[str, Any]:
    if not path:
        return {}
    source = Path(path)
    if not source.exists():
        return {}
    return json.loads(source.read_text(encoding="utf-8"))


def pr_body(payload: dict[str, Any], body_file: str | None) -> str:
    if body_file:
        source = Path(body_file)
        if source.exists():
            return source.read_text(encoding="utf-8")
    pr = payload.get("pull_request")
    if isinstance(pr, dict):
        body = pr.get("body")
        return body if isinstance(body, str) else ""
    return ""


def pr_title(payload: dict[str, Any]) -> str:
    pr = payload.get("pull_request")
    if isinstance(pr, dict):
        title = pr.get("title")
        return title if isinstance(title, str) else ""
    return ""


def pr_labels(payload: dict[str, Any]) -> set[str]:
    pr = payload.get("pull_request")
    labels = pr.get("labels", []) if isinstance(pr, dict) else []
    names: set[str] = set()
    for item in labels:
        if isinstance(item, dict) and isinstance(item.get("name"), str):
            names.add(item["name"].lower())
    return names


def path_risk_reasons(changed_files: list[str]) -> list[str]:
    reasons: list[str] = []
    for raw_path in changed_files:
        path = normalize_path(raw_path)
        if has_any(HIGH_RISK_PATH_PATTERNS, path):
            reasons.append(f"High-risk path: {path}")
    return reasons


# Dependency-bump PRs (dependabot etc.) paste the upstream project's release
# notes and changelog into the body inside <details> blocks. Those are not words
# the PR author wrote about *this* change, but the keyword scan used to read them
# and flag the PR high-risk on its own.
#
# Measured on #4257 (a one-line `google-genai` version bump): the body contained
# `token` x1 and `auth` x2, and **all three hits sat inside <details> blocks** --
# upstream commit subjects like "Support mTLS in custom client using google auth
# mtls.get_default_ssl_context". The PR touched no risky path and carried no
# risky label, yet the gate demanded an ultrareview declaration.
#
# Collapsed sections are therefore excluded before matching. Text the author
# actually wrote in the visible description still counts, so a genuinely risky
# PR is unaffected; path and label signals are untouched either way.
COLLAPSED_SECTION_RE = re.compile(
    r"<details\b.*?</details\s*>",
    flags=re.IGNORECASE | re.DOTALL,
)


def strip_collapsed_sections(body: str) -> str:
    """Drop <details>…</details> regions so quoted upstream notes are not scanned.

    An unclosed <details> (truncated body) drops the remainder as well, which is
    the safe direction here: everything after the marker is quoted material.
    """
    stripped = COLLAPSED_SECTION_RE.sub(" ", body)
    opener = re.search(r"<details\b", stripped, flags=re.IGNORECASE)
    return stripped[: opener.start()] if opener else stripped


def text_risk_reasons(title: str, body: str) -> list[str]:
    text = f"{title}\n{strip_collapsed_sections(body)}"
    if has_any(HIGH_RISK_TEXT_PATTERNS, text):
        return ["Title/body contains high-risk keywords."]
    return []


def label_risk_reasons(labels: set[str]) -> list[str]:
    hits = sorted(labels & HIGH_RISK_LABELS)
    return ["High-risk labels: " + ", ".join(hits)] if hits else []


def has_visible_exception_reason(body: str) -> bool:
    for line in body.splitlines():
        if not has_any(EXCEPTION_PATTERNS, line):
            continue
        cleaned = re.sub(r"<!--.*?-->", "", line).strip()
        cleaned = re.sub(
            r"(?i)high[- ]risk[- ]ultrareview[- ]exception|ultrareview[- ]exception",
            "",
            cleaned,
        )
        cleaned = cleaned.strip(" :-[]\t")
        if len(cleaned) >= 12:
            return True
    return False


def has_exception_marker(body: str) -> bool:
    return has_any(EXCEPTION_PATTERNS, body)


def missing_perspectives(body: str) -> list[str]:
    return [
        name
        for name, pattern in REQUIRED_PERSPECTIVES.items()
        if not re.search(pattern, body, flags=re.IGNORECASE)
    ]


def validate(
    body: str,
    changed_files: list[str],
    labels: set[str],
    title: str = "",
) -> tuple[bool, list[str], bool, list[str]]:
    risk_reasons: list[str] = []
    risk_reasons.extend(path_risk_reasons(changed_files))
    risk_reasons.extend(label_risk_reasons(labels))
    risk_reasons.extend(text_risk_reasons(title, body))

    high_risk = bool(risk_reasons)
    if not high_risk:
        return True, ["No high-risk triggers detected."], False, []

    messages: list[str] = []
    exception_declared = has_visible_exception_reason(body)
    exception_marker = has_exception_marker(body)

    if not has_any(INSTANCE_PATTERNS, body):
        messages.append("High-risk PR body must name Claude Code #1 as the review owner.")
    if exception_marker and not exception_declared:
        messages.append("High-risk ultrareview exception reason must be visible.")

    if exception_declared:
        return not messages, messages or ["Visible ultrareview exception declared."], True, risk_reasons

    if not has_any(ULTRAREVIEW_PATTERNS, body):
        messages.append("High-risk PR body must include Claude ultrareview evidence or an exception reason.")

    missing = missing_perspectives(body)
    if missing:
        messages.append(
            "High-risk ultrareview evidence must cover: " + ", ".join(missing) + "."
        )

    if not has_any(NO_UNRESOLVED_PATTERNS, body):
        messages.append("High-risk PR body must state that unresolved ultrareview findings are 0/none.")

    return not messages, messages, True, risk_reasons


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--event", help="GitHub event JSON path")
    parser.add_argument("--body-file", help="Local markdown file to validate")
    parser.add_argument("--changed-files", help="Newline-separated changed file list")
    parser.add_argument(
        "--emit-exception",
        metavar="REASON",
        help=(
            "Print a high-risk gate block that passes via the exception route "
            "(Claude Code #1 owner + visible reason), then exit. The honest "
            "route when /ultrareview was not run."
        ),
    )
    parser.add_argument(
        "--emit-evidence",
        action="store_true",
        help=(
            "Print a high-risk gate block that passes via the evidence route "
            "(covers all required perspectives), then exit. Use only after a "
            "real /ultrareview run."
        ),
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)

    if args.emit_exception is not None:
        print(passing_exception_block(args.emit_exception), end="")
        return 0
    if args.emit_evidence:
        print(passing_evidence_block(), end="")
        return 0

    payload = event_payload(args.event)
    body = pr_body(payload, args.body_file)
    title = pr_title(payload)
    changed_files = read_changed_files(args.changed_files)
    labels = pr_labels(payload)

    ok, messages, high_risk, risk_reasons = validate(body, changed_files, labels, title)
    print(f"High-risk ultrareview gate: {'PASS' if ok else 'FAIL'}")
    print(f"High-risk triggers detected: {'yes' if high_risk else 'no'}")
    if changed_files:
        print(f"Changed files inspected: {len(changed_files)}")
    for reason in risk_reasons:
        print(f"- trigger: {reason}")
    for message in messages:
        print(f"- {message}")
    if not ok:
        print()
        print(
            "Recommended fix — paste this exception block into the PR body "
            "(replace the reason), or re-run with "
            '--emit-exception "<reason>":'
        )
        print("---8<--- snippet start ---8<---")
        print(
            passing_exception_block(
                "<reason >= "
                f"{EXCEPTION_REASON_MIN_LENGTH} chars; e.g. prose-only trigger, "
                "no high-risk path touched>"
            ),
            end="",
        )
        print("---8<--- snippet end ---8<---")
        print(
            "If Claude Code #1 actually ran /ultrareview, use --emit-evidence "
            "instead to record the perspective coverage."
        )
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
