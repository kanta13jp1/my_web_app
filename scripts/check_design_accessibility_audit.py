#!/usr/bin/env python3
"""Require Design-plugin accessibility evidence for UI Pull Requests.

The gate verifies a review declaration, not WCAG conformance. A reviewer must
still inspect the linked plugin output and deterministic UI evidence.
"""

from __future__ import annotations

import argparse
from datetime import date, timedelta
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


UI_ROOTS = (
    "lib/ui/",
    "lib/widgets/",
    "lib/pages/",
    "lib/screens/",
    "lib/components/",
)

UI_FILE_SUFFIXES = (
    "_component.dart",
    "_dialog.dart",
    "_page.dart",
    "_screen.dart",
    "_sheet.dart",
    "_view.dart",
    "_widget.dart",
)

UI_SHELL_FILES = {
    "lib/app.dart",
    "lib/main.dart",
    "lib/router.dart",
    "lib/routes.dart",
}

UI_SHELL_ROOTS = (
    "lib/dev/",
    "lib/features/",
    "lib/navigation/",
    "lib/routes/",
)

NON_UI_SEGMENTS = {
    "controllers",
    "data",
    "domain",
    "model",
    "models",
    "providers",
    "repository",
    "repositories",
    "service",
    "services",
    "state",
    "view_model",
    "view_models",
}

MICROCOPY_PATH_MARKERS = (
    "checkout",
    "payment",
    "purchase",
    "billing",
    "form",
    "auth",
    "login",
    "signin",
    "signup",
    "register",
    "registration",
    "contact",
)

REQUIRED_FIELDS = (
    "Scope",
    "Surface-Type",
    "Design-Plugin-Status",
    "Design-Plugin-Reviewed-At",
    "Design-Plugin-Evidence",
    "WCAG-2.1-AA-Findings",
    "Remediation",
    "Deterministic-Evidence",
    "Error-Microcopy-Review",
)

PLACEHOLDER_PATTERNS = (
    r"^\s*$",
    r"<[^>]+>",
    r"\b(?:todo|tbd|placeholder|pending|later)\b",
    r"^\s*(?:n/?a|none|-+)\s*$",
    r"<!--.*?-->",
)


@dataclass(frozen=True)
class ChangedPath:
    status: str
    path: str


def normalize_path(path: str) -> str:
    normalized = path.replace("\ufeff", "").replace("\\", "/").strip()
    while normalized.startswith("./"):
        normalized = normalized[2:]
    return normalized


def parse_changed_paths(path: str | None) -> list[ChangedPath]:
    if not path:
        return []
    source = Path(path)
    if not source.exists():
        return []

    changes: list[ChangedPath] = []
    for raw_line in source.read_text(encoding="utf-8-sig").splitlines():
        if not raw_line.strip():
            continue
        parts = raw_line.split("\t")
        if len(parts) == 1:
            changes.append(ChangedPath("M", normalize_path(parts[0])))
            continue
        status = parts[0].strip().upper()
        changes.append(ChangedPath(status, normalize_path(parts[-1])))
    return changes


def is_ui_surface(path: str) -> bool:
    normalized = normalize_path(path).lower()
    if not normalized.endswith(".dart"):
        return False
    recognized = (
        normalized in UI_SHELL_FILES
        or normalized.startswith(UI_ROOTS)
        or normalized.startswith(UI_SHELL_ROOTS)
        or normalized.endswith(UI_FILE_SUFFIXES)
    )
    if not recognized:
        return False
    segments = set(normalized.split("/"))
    return not bool(segments & NON_UI_SEGMENTS)


def relevant_ui_changes(changes: list[ChangedPath]) -> list[ChangedPath]:
    return [change for change in changes if is_ui_surface(change.path)]


def is_new_component(change: ChangedPath) -> bool:
    return change.status.startswith(("A", "C")) and is_ui_surface(change.path)


def needs_microcopy_review(changes: list[ChangedPath]) -> bool:
    for change in changes:
        lowered = change.path.lower()
        tokens = set(re.split(r"[^a-z0-9]+", lowered))
        if tokens.intersection(MICROCOPY_PATH_MARKERS):
            return True
        if "sign_in" in lowered or "sign_up" in lowered:
            return True
    return False


def event_payload(path: str | None) -> dict[str, Any]:
    if not path:
        return {}
    source = Path(path)
    if not source.exists():
        return {}
    data = json.loads(source.read_text(encoding="utf-8"))
    return data if isinstance(data, dict) else {}


def pr_body(payload: dict[str, Any], body_file: str | None) -> str:
    if body_file:
        source = Path(body_file)
        return source.read_text(encoding="utf-8") if source.exists() else ""
    pull_request = payload.get("pull_request")
    if isinstance(pull_request, dict):
        body = pull_request.get("body")
        return body if isinstance(body, str) else ""
    return ""


def audit_section(body: str) -> str:
    match = re.search(
        r"(?ims)^##\s+Design Accessibility Audit\s*$\s*(.*?)(?=^##\s+|\Z)",
        body,
    )
    return match.group(1).strip() if match else ""


def field_value(section: str, field: str) -> str:
    match = re.search(
        rf"(?im)^\s*[-*]\s*(?:\[[ xX]\]\s*)?{re.escape(field)}\s*:\s*(.*?)\s*$",
        section,
    )
    return match.group(1).strip() if match else ""


def is_placeholder(value: str) -> bool:
    return any(
        re.search(pattern, value, flags=re.IGNORECASE | re.DOTALL)
        for pattern in PLACEHOLDER_PATTERNS
    )


def has_meaningful_value(value: str, minimum: int = 8) -> bool:
    return len(value.strip()) >= minimum and not is_placeholder(value)


def has_evidence_reference(value: str) -> bool:
    if not has_meaningful_value(value, 12):
        return False
    patterns = (
        r"https://(?!example\.com\b)\S+",
        r"\bpr[- ]comment\s*#\d+\b",
        r"\bartifact\s*:\s*\S+",
        r"\b(?:docs|artifacts|evidence)/\S+\.(?:md|json|png|jpe?g|webp|pdf)\b",
    )
    return any(re.search(pattern, value, flags=re.IGNORECASE) for pattern in patterns)


def valid_review_date(value: str) -> bool:
    try:
        reviewed = date.fromisoformat(value.strip())
    except ValueError:
        return False
    # CI usually runs in UTC while the project operates in JST.
    return reviewed <= date.today() + timedelta(days=1)


def validate(
    body: str,
    changes: list[ChangedPath],
) -> tuple[bool, list[str], bool, bool, bool, list[str]]:
    ui_changes = relevant_ui_changes(changes)
    audit_required = bool(ui_changes)
    new_component = any(is_new_component(change) for change in ui_changes)
    microcopy_required = needs_microcopy_review(ui_changes)
    ui_paths = [change.path for change in ui_changes]

    if not audit_required:
        return (
            True,
            ["No user-visible Flutter UI change detected; audit declaration is not required."],
            False,
            False,
            False,
            [],
        )

    section = audit_section(body)
    if not section:
        return (
            False,
            ["Missing `## Design Accessibility Audit` section in the PR body."],
            True,
            new_component,
            microcopy_required,
            ui_paths,
        )

    messages: list[str] = []
    values = {field: field_value(section, field) for field in REQUIRED_FIELDS}
    for field, value in values.items():
        if not value:
            messages.append(f"Missing `{field}` field in the audit section.")

    status = values["Design-Plugin-Status"].strip().lower()
    if status and status != "pass":
        messages.append(
            "`Design-Plugin-Status` must be exactly `pass` after remediation and re-review."
        )

    review_date = values["Design-Plugin-Reviewed-At"]
    if review_date and not valid_review_date(review_date):
        messages.append(
            "`Design-Plugin-Reviewed-At` must be a valid, non-future ISO date (YYYY-MM-DD)."
        )

    scope = values["Scope"]
    if scope and not all(token in scope.lower() for token in ("states=", "viewports=")):
        messages.append("`Scope` must include structured `states=` and `viewports=` evidence.")

    surface_type = values["Surface-Type"].strip().lower()
    declared_checkout = surface_type.startswith("checkout-form")
    declared_other = surface_type.startswith("other")
    scope_requires_microcopy = needs_microcopy_review(
        [ChangedPath("M", scope)] if scope else []
    )
    microcopy_required = microcopy_required or declared_checkout or scope_requires_microcopy
    if surface_type and not (declared_checkout or declared_other):
        messages.append(
            "`Surface-Type` must start with `checkout-form` or `other` and include a reason."
        )
    elif surface_type and not has_meaningful_value(surface_type, 18):
        messages.append("`Surface-Type` must include a specific classification reason.")
    if microcopy_required and declared_other:
        messages.append(
            "Checkout/form path or scope cannot declare `Surface-Type: other`; use `checkout-form`."
        )

    for field, minimum in (
        ("Scope", 24),
        ("WCAG-2.1-AA-Findings", 8),
        ("Remediation", 8),
        ("Deterministic-Evidence", 12),
    ):
        value = values[field]
        if value and not has_meaningful_value(value, minimum):
            messages.append(f"`{field}` must contain specific, non-placeholder evidence.")

    evidence = values["Design-Plugin-Evidence"]
    if evidence and not has_evidence_reference(evidence):
        messages.append(
            "`Design-Plugin-Evidence` must contain an HTTPS URL, PR comment number, "
            "artifact reference, or repository evidence file path."
        )

    findings = values["WCAG-2.1-AA-Findings"].lower()
    if findings and not all(
        token in findings for token in ("result=pass", "unresolved-high=0")
    ):
        messages.append(
            "`WCAG-2.1-AA-Findings` must include `result=pass` and `unresolved-high=0`."
        )

    remediation = values["Remediation"].lower()
    if remediation and not re.search(r"\bresolved=\d+\b", remediation):
        messages.append("`Remediation` must include a numeric `resolved=<count>` field.")

    deterministic = values["Deterministic-Evidence"].lower()
    if deterministic and not all(
        re.search(rf"\b{field}\s*=", deterministic)
        for field in ("tests", "keyboard-contrast", "at")
    ):
        messages.append(
            "`Deterministic-Evidence` must include `tests=`, `keyboard-contrast=`, and `AT=`."
        )

    microcopy = values["Error-Microcopy-Review"].strip()
    lowered_microcopy = microcopy.lower()
    if microcopy_required:
        if not lowered_microcopy.startswith("reviewed") or not has_meaningful_value(
            microcopy, 18
        ):
            messages.append(
                "Checkout/form-related UI requires "
                "`Error-Microcopy-Review: reviewed — <specific result>`."
            )
    elif microcopy:
        reviewed = lowered_microcopy.startswith("reviewed") and has_meaningful_value(
            microcopy, 18
        )
        not_applicable = lowered_microcopy.startswith(
            "not-applicable"
        ) and has_meaningful_value(microcopy, 28)
        if not (reviewed or not_applicable):
            messages.append(
                "`Error-Microcopy-Review` must be `reviewed — <result>` or "
                "`not-applicable — <specific reason>`."
            )

    return (
        not messages,
        messages or ["Design accessibility audit evidence contract is complete."],
        True,
        new_component,
        microcopy_required,
        ui_paths,
    )


def passing_snippet(*, microcopy_required: bool = False) -> str:
    microcopy = (
        "reviewed — <before/after copy and recovery behavior>"
        if microcopy_required
        else "not-applicable — <specific reason this UI has no checkout/form error state>"
    )
    return (
        "## Design Accessibility Audit\n\n"
        "- Scope: routes=<routes>; components=<components>; states=<states>; viewports=<viewports>\n"
        "- Surface-Type: <checkout-form — reason | other — reason>\n"
        "- Design-Plugin-Status: pass\n"
        "- Design-Plugin-Reviewed-At: <YYYY-MM-DD>\n"
        "- Design-Plugin-Evidence: <HTTPS URL, PR comment #, artifact:name, or evidence file>\n"
        "- WCAG-2.1-AA-Findings: result=pass; unresolved-high=0; <summary/remaining risks>\n"
        "- Remediation: resolved=<count>; <changes after review or why none was required>\n"
        "- Deterministic-Evidence: tests=<result>; keyboard-contrast=<result>; AT=<result or not-run owner/follow-up>\n"
        f"- Error-Microcopy-Review: {microcopy}\n"
    )


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--event", help="GitHub pull_request event JSON path")
    parser.add_argument("--body-file", help="Local PR body markdown to validate")
    parser.add_argument(
        "--changed-files-status",
        help="git diff --name-status output for the PR",
    )
    parser.add_argument("--emit-snippet", action="store_true")
    parser.add_argument("--microcopy-required", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    if args.emit_snippet:
        print(passing_snippet(microcopy_required=args.microcopy_required), end="")
        return 0

    if not args.changed_files_status:
        print("Design accessibility audit gate: FAIL")
        print("- `--changed-files-status` is required; refusing to skip UI detection.")
        return 2
    changed_source = Path(args.changed_files_status)
    if not changed_source.exists() or not changed_source.read_text(
        encoding="utf-8-sig"
    ).strip():
        print("Design accessibility audit gate: FAIL")
        print("- Changed-file status input is missing or empty; refusing to fail open.")
        return 2

    payload = event_payload(args.event)
    body = pr_body(payload, args.body_file)
    changes = parse_changed_paths(args.changed_files_status)
    ok, messages, required, new_component, microcopy_required, paths = validate(
        body, changes
    )

    print(f"Design accessibility audit gate: {'PASS' if ok else 'FAIL'}")
    print(f"UI audit required: {'yes' if required else 'no'}")
    print(f"New UI component detected: {'yes' if new_component else 'no'}")
    print(f"Error microcopy review required: {'yes' if microcopy_required else 'no'}")
    for path in paths:
        print(f"- UI change: {path}")
    for message in messages:
        print(f"- {message}")

    if not ok:
        print()
        print("Paste this block into the PR body and replace every placeholder:")
        print("---8<--- snippet start ---8<---")
        print(passing_snippet(microcopy_required=microcopy_required), end="")
        print("---8<--- snippet end ---8<---")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
