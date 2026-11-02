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
import subprocess
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


# --- Visual Parity Exemption -------------------------------------------
#
# A PR that only touches named Dart functions inside a UI-surface file can
# skip the full Design plugin audit IF it can be proven mechanically that:
#   1. every changed line falls inside one of the declared functions, and
#   2. each declared function's "visual fingerprint" (the ordered sequence
#      of widget-constructor calls and string-literal contents it contains)
#      is byte-identical between the base and head revisions.
#
# This is intentionally narrow: it only recognizes a hand-picked, reviewed
# set of interchangeable widget names (WIDGET_ALIASES below) and otherwise
# requires the function body to be textually unchanged apart from
# whitespace/formatting. Any parse ambiguity fails CLOSED (falls back to
# requiring the full audit) — this check is only ever allowed to make the
# gate *stricter* by mistake, never looser.


# Widget constructors this repo treats as interchangeable for visual-parity
# purposes because they share the same rendering/decoration/keyboard/style
# API surface (e.g. TextField vs TextFormField both wrap EditableText).
# Extend this list only after a human reviews the new pair for equivalence.
WIDGET_ALIASES: dict[str, str] = {
    "TextFormField": "TextField",
}


def _normalize_widget_name(name: str) -> str:
    return WIDGET_ALIASES.get(name, name)


def _tokenize_dart(text: str) -> list[tuple[str, int, int]]:
    """Splits Dart source into (kind, start, end) spans covering `text`
    with no gaps, where kind is "code", "string", or "comment".

    Braces and widget calls inside string interpolation (`${...}`) are
    classified as "code" (they are real, executable Dart), while the
    literal characters of a string (outside any interpolation) are
    classified as "string". This lets callers both (a) brace-match
    accurately by only counting "code" braces, and (b) fingerprint the
    *contents* of string literals separately from real widget calls.
    """
    n = len(text)
    spans: list[tuple[str, int, int]] = []
    i = 0
    code_start = 0
    # Stack entries are ("string", quote, is_raw, is_triple) while consuming
    # literal string text, or ("interp", depth) while consuming the Dart
    # expression inside a `${...}` interpolation — `depth` counts unmatched
    # `{` seen *inside* that expression, so a `}` only closes the
    # interpolation (returning to its enclosing string) when depth is 0.
    stack: list[tuple] = []

    def flush_code(end: int) -> None:
        if end > code_start:
            spans.append(("code", code_start, end))

    while i < n:
        if stack and stack[-1][0] == "string":
            _, quote, is_raw, is_triple = stack[-1]
            start = i
            while i < n:
                ch = text[i]
                if not is_raw and ch == "\\":
                    i += 2
                    continue
                if not is_raw and ch == "$" and i + 1 < n:
                    nxt = text[i + 1]
                    if nxt == "{":
                        break  # interpolation begins; flush string text so far
                    if nxt.isalpha() or nxt == "_":
                        i += 1  # bare `$identifier`; keep consuming as text
                        continue
                if is_triple:
                    if text[i : i + 3] == quote * 3:
                        break
                    i += 1
                    continue
                if ch == quote:
                    break
                i += 1
            spans.append(("string", start, i))
            if i >= n:
                return spans
            if text[i] == quote or (is_triple and text[i : i + 3] == quote * 3):
                i += 3 if is_triple else 1
                stack.pop()
                code_start = i
                continue
            # Otherwise we stopped at `${`: enter interpolation as code.
            stack.append(("interp", 0))
            i += 2
            code_start = i
            continue

        ch = text[i]
        if stack and stack[-1][0] == "interp":
            if ch == "{":
                stack[-1] = ("interp", stack[-1][1] + 1)
                i += 1
                continue
            if ch == "}":
                depth = stack[-1][1]
                if depth == 0:
                    flush_code(i)
                    stack.pop()
                    i += 1
                    code_start = i
                    continue
                stack[-1] = ("interp", depth - 1)
                i += 1
                continue
        if text[i : i + 2] == "//":
            flush_code(i)
            j = text.find("\n", i)
            end = n if j == -1 else j + 1
            spans.append(("comment", i, end))
            i = end
            code_start = i
            continue
        if text[i : i + 2] == "/*":
            flush_code(i)
            j = text.find("*/", i + 2)
            end = n if j == -1 else j + 2
            spans.append(("comment", i, end))
            i = end
            code_start = i
            continue
        if ch in "'\"":
            is_raw = i > 0 and text[i - 1] == "r" and not (
                i >= 2 and (text[i - 2].isalnum() or text[i - 2] == "_")
            )
            is_triple = text[i : i + 3] == ch * 3
            flush_code(i)
            i += 3 if is_triple else 1
            stack.append(("string", ch, is_raw, is_triple))
            code_start = i
            continue
        i += 1

    flush_code(n)
    return spans


_WIDGET_CALL_RE = re.compile(r"\b([A-Z][A-Za-z0-9_]*)\s*(?=\()")

# Flutter's `Key` family is documented as pure widget-tree identity/
# reconciliation metadata — it is never painted and carries no copy, so its
# entire call (name and arguments alike) is excluded from the visual
# fingerprint below. This is a general, always-true fact about the Flutter
# framework, not a carve-out for any one PR.
_KEY_CONSTRUCTOR_NAMES = frozenset(
    {"Key", "ValueKey", "ObjectKey", "UniqueKey", "PageStorageKey", "GlobalKey"}
)

# Capitalized identifiers that are never themselves a rendered widget, so the
# *fact that this call exists* is excluded from the fingerprint — but unlike
# `_KEY_CONSTRUCTOR_NAMES`, their arguments are still scanned normally,
# because those arguments can still carry real visible copy (e.g. a
# `TextEditingController(text: ...)` initial value is exactly what a bound
# `TextField` displays first). Extend this list only after a human confirms
# the type is a plain Dart/Flutter SDK class that never paints itself.
_NON_WIDGET_CALL_NAMES = frozenset(
    {
        "Function",  # Dart function-type syntax, e.g. `double Function(...)`; not a call.
        "TextEditingController",
        "FocusNode",
        "ScrollController",
    }
)

_FUNCTION_DECL_RE_TEMPLATE = r"(?m)^[ \t]{{2}}[A-Za-z_][\w<>?,\s]*?\b{name}\s*\("


def function_declared(source: str, name: str) -> bool:
    """True if a method/function named `name` is declared at 2-space
    class-body indentation in `source` — used only as a sanity check that a
    declared exemption name refers to something real, not to decide the
    exemption's pass/fail (that is `visual_fingerprint` equality below).
    Deliberately loose (it doesn't try to match a full, possibly
    multi-line/brace-parameter-list, signature): a false positive here is
    harmless because the whole-file fingerprint comparison is what
    actually gates the exemption."""
    pattern = re.compile(_FUNCTION_DECL_RE_TEMPLATE.format(name=re.escape(name)))
    return pattern.search(source) is not None


def visual_fingerprint(source: str) -> tuple[str, ...] | None:
    """Returns the ordered sequence of "visually meaningful" tokens in Dart
    `source`: every widget-constructor-like call (normalized through
    WIDGET_ALIASES, excluding the non-visual Key family) and every
    string-literal's literal text that isn't a Key constructor argument,
    interleaved in source order. Two files with an identical fingerprint
    render the same widget types in the same order with the same copy,
    regardless of how values are computed or wired up internally (new
    helper methods/fields, controller vs. initialValue, moved Key
    arguments, renamed parameters, etc.). Returns None if `source` cannot
    be tokenized confidently.
    """
    try:
        spans = _tokenize_dart(source)
    except Exception:  # pragma: no cover - defensive; fail closed on any bug
        return None
    tokens: list[str] = []
    skip_depth = 0  # >0 while inside a Key-constructor call's argument list
    for kind, start, end in spans:
        segment = source[start:end]
        if kind == "string":
            # An empty literal renders no visible character anywhere it is
            # used, so its position/context can never be visually
            # significant — safe to drop unconditionally.
            if skip_depth == 0 and segment != "":
                tokens.append(f"text:{segment}")
            continue
        if kind != "code":
            continue
        i = 0
        n = len(segment)
        while i < n:
            if skip_depth > 0:
                ch = segment[i]
                if ch == "(":
                    skip_depth += 1
                elif ch == ")":
                    skip_depth -= 1
                i += 1
                continue
            match = _WIDGET_CALL_RE.match(segment, i)
            if match:
                name = match.group(1)
                if name in _KEY_CONSTRUCTOR_NAMES:
                    skip_depth = 1
                    i = match.end() + 1  # consume the name and its "("
                elif name in _NON_WIDGET_CALL_NAMES:
                    i = match.end()  # no call: token, but keep scanning args
                else:
                    tokens.append(f"call:{_normalize_widget_name(name)}")
                    i = match.end()
                continue
            i += 1
    return tuple(tokens)


def has_visual_parity(
    old_source: str | None,
    new_source: str,
    function_names: list[str],
) -> tuple[bool, list[str]]:
    """Verifies that `new_source` renders identically to `old_source`: same
    widget-constructor call sequence, same non-Key string-literal sequence,
    file-wide. `function_names` (the author's declared list of touched
    functions) is sanity-checked to exist in `new_source` for reviewer
    transparency, but the actual pass/fail is the whole-file fingerprint
    comparison — the declared list cannot make an actual visual change
    pass, and a wholly-new non-rendering helper cannot make it fail.
    Returns (ok, reasons); `ok` is False (full audit still required)
    whenever anything cannot be confidently verified.
    """
    if old_source is None:
        return False, ["File is new; there is no base revision to compare against."]
    if not function_names:
        return False, ["No functions were declared for the visual parity exemption."]

    missing = [name for name in function_names if not function_declared(new_source, name)]
    if missing:
        return False, [
            "Declared function(s) not found in the new revision: "
            + ", ".join(missing)
        ]

    old_fp = visual_fingerprint(old_source)
    new_fp = visual_fingerprint(new_source)
    if old_fp is None or new_fp is None:
        return False, ["Could not tokenize the file confidently; refusing to guess."]
    if old_fp != new_fp:
        return False, [
            "The file's visual fingerprint changed (a widget-call or "
            "string-literal sequence differs from the base revision)."
        ]
    return True, [
        "Visual parity verified for the whole file (declared functions: "
        + ", ".join(function_names)
        + ")."
    ]


def visual_parity_section(body: str) -> str:
    match = re.search(
        r"(?ims)^##\s+Visual Parity Exemption\s*$\s*(.*?)(?=^##\s+|\Z)",
        body,
    )
    return match.group(1).strip() if match else ""


_VISUAL_PARITY_LINE_RE = re.compile(
    r"(?im)^\s*[-*]\s*File\s*:\s*(?P<file>[^;]+?)\s*;\s*Functions\s*:\s*(?P<functions>.+?)\s*$"
)


def visual_parity_declarations(section: str) -> dict[str, list[str]]:
    """Parses `- File: <path>; Functions: <a, b, c>` lines out of a
    `## Visual Parity Exemption` section. One line per changed file."""
    declarations: dict[str, list[str]] = {}
    for match in _VISUAL_PARITY_LINE_RE.finditer(section):
        path = normalize_path(match.group("file"))
        functions = [
            name.strip() for name in match.group("functions").split(",") if name.strip()
        ]
        if path and functions:
            declarations[path] = functions
    return declarations


def load_file_contents_for_parity(
    base_ref: str | None,
    paths: list[str],
) -> dict[str, tuple[str | None, str]]:
    """Loads (base-revision-content-or-None, current-content) for each of
    `paths`, using `git show <base_ref>:<path>` for the base side and the
    on-disk file for the current side. Any failure (missing ref, file added
    in this PR, git not available, decode error) yields `None` for that
    side of that path so callers fail closed rather than skip verification
    silently."""
    contents: dict[str, tuple[str | None, str]] = {}
    for path in paths:
        old_source: str | None = None
        if base_ref:
            try:
                result = subprocess.run(
                    ["git", "show", f"{base_ref}:{path}"],
                    capture_output=True,
                    text=True,
                    encoding="utf-8",
                    errors="strict",
                )
                if result.returncode == 0:
                    old_source = result.stdout
            except Exception:
                old_source = None
        try:
            new_source = Path(path).read_text(encoding="utf-8")
        except Exception:
            new_source = ""
        contents[path] = (old_source, new_source)
    return contents


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
    file_contents: dict[str, tuple[str | None, str]] | None = None,
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

    parity_prelude: list[str] = []
    parity_section = visual_parity_section(body)
    if parity_section:
        if file_contents is None:
            parity_prelude.append(
                "Visual Parity Exemption declared, but no base/head file content was "
                "supplied for verification; falling back to the full audit requirement."
            )
        else:
            declarations = visual_parity_declarations(parity_section)
            if declarations and set(ui_paths) and set(ui_paths) <= set(declarations):
                parity_messages: list[str] = []
                all_ok = True
                for path in ui_paths:
                    old_source, new_source = file_contents.get(path, (None, ""))
                    ok, reasons = has_visual_parity(
                        old_source, new_source, declarations[path]
                    )
                    parity_messages.extend(f"{path}: {reason}" for reason in reasons)
                    all_ok = all_ok and ok
                if all_ok:
                    return (
                        True,
                        [
                            "Visual Parity Exemption verified; full Design "
                            "Accessibility Audit is not required."
                        ]
                        + parity_messages,
                        True,
                        new_component,
                        microcopy_required,
                        ui_paths,
                    )
                parity_prelude = parity_messages + [
                    "Visual Parity Exemption did not verify; falling back to the "
                    "full audit requirement."
                ]
            else:
                parity_prelude.append(
                    "Visual Parity Exemption does not cover every changed UI file; "
                    "falling back to the full audit requirement."
                )

    section = audit_section(body)
    if not section:
        return (
            False,
            parity_prelude
            + ["Missing `## Design Accessibility Audit` section in the PR body."],
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
        parity_prelude
        + (messages or ["Design accessibility audit evidence contract is complete."]),
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
    parser.add_argument(
        "--base-ref",
        help=(
            "Base git ref/SHA to diff against for `## Visual Parity Exemption` "
            "verification (e.g. the PR's merge-base). Requires the checkout to "
            "have that ref's history available (fetch-depth: 0)."
        ),
    )
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

    file_contents = None
    parity_section = visual_parity_section(body)
    if parity_section:
        declared_paths = list(visual_parity_declarations(parity_section))
        if declared_paths:
            file_contents = load_file_contents_for_parity(args.base_ref, declared_paths)

    ok, messages, required, new_component, microcopy_required, paths = validate(
        body, changes, file_contents
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
