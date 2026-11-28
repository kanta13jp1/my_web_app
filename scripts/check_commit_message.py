#!/usr/bin/env python3
"""Validate local commit messages and evaluate safe CI skip directives."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path


GIT_SCISSOR_LINE = "# ------------------------ >8 ------------------------"

EXEMPT_SUBJECT_PATTERNS = (
    re.compile(r"^Merge\s+"),
    re.compile(r'^Revert\s+"'),
    re.compile(r"^(?:fixup|squash|amend)!\s+"),
)

TICKET_REFERENCE_PATTERNS = (
    re.compile(
        r"\b(?:refs?|closes?|closed?|fix(?:es|ed)?|resolves?|resolved?|related\s+to|see|issues?)\s*:?\s*(#[1-9]\d*)\b",
        re.IGNORECASE,
    ),
    re.compile(r"\(\s*(#[1-9]\d*)\s*\)"),
)

SKIP_CI_PATTERN = re.compile(r"\[(?:skip\s+ci|ci\s+skip)\]", re.IGNORECASE)


def clean_commit_message(raw_text: str) -> str:
    """Strip git comment lines and verbose diff scissors from a commit message."""
    normalized = raw_text.lstrip("\ufeff").replace("\r\n", "\n").replace("\r", "\n")
    kept_lines: list[str] = []
    for line in normalized.splitlines():
        if line == GIT_SCISSOR_LINE:
            break
        if line.startswith("#"):
            continue
        kept_lines.append(line)
    return "\n".join(kept_lines).strip()


def is_exempt_commit(cleaned_message: str) -> bool:
    """Return True for auto-generated merge, revert, or autosquash commits."""
    if not cleaned_message:
        return False
    subject = cleaned_message.splitlines()[0].strip()
    return any(pattern.match(subject) for pattern in EXEMPT_SUBJECT_PATTERNS)


def extract_ticket_references(cleaned_message: str) -> list[str]:
    """Extract deduplicated ticket references such as '#2727' from message text."""
    seen: set[str] = set()
    ordered: list[str] = []
    for pattern in TICKET_REFERENCE_PATTERNS:
        for match in pattern.finditer(cleaned_message):
            ticket = match.group(1)
            if ticket not in seen:
                seen.add(ticket)
                ordered.append(ticket)
    return ordered


def validate_commit_message(raw_text: str) -> tuple[bool, str]:
    """Validate that a commit message is non-empty and references a ticket or exemption."""
    cleaned = clean_commit_message(raw_text)
    if not cleaned:
        return (
            False,
            "Commit message is empty after stripping Git comments. "
            "Include a summary and ticket reference (e.g. 'feat: update ci (refs #2727)').",
        )

    if is_exempt_commit(cleaned):
        return True, "Exempted auto-generated commit prefix (Merge/Revert/fixup/squash/amend)."

    refs = extract_ticket_references(cleaned)
    if not refs:
        return (
            False,
            "Commit message must reference an issue/ticket number. "
            "Accepted formats: 'refs #1234', 'Closes #1234', 'Related to #1234', or 'feat: summary (#1234)'.",
        )

    return True, f"Accepted ticket reference(s): {', '.join(refs)}"


def detect_ci_skip(raw_text: str) -> bool:
    """Return True when non-comment commit text contains [skip ci] or [ci skip]."""
    cleaned = clean_commit_message(raw_text)
    if not cleaned:
        return False
    return SKIP_CI_PATTERN.search(cleaned) is not None


def _run_git(repo_root: Path, args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", "-C", str(repo_root), *args],
        text=True,
        encoding="utf-8",
        errors="replace",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def read_git_commit_messages(repo_root: Path, event_name: str) -> list[str]:
    """Read HEAD commit message and, on pull_request merges, HEAD^2 commit message safely."""
    refs = ["HEAD"]
    if event_name == "pull_request":
        head2_check = _run_git(repo_root, ["rev-parse", "--verify", "--quiet", "HEAD^2"])
        if head2_check.returncode == 0:
            refs.append("HEAD^2")

    messages: list[str] = []
    for ref in refs:
        proc = _run_git(repo_root, ["log", "-1", "--format=%B", ref])
        if proc.returncode == 0 and proc.stdout:
            messages.append(proc.stdout)
    return messages


def evaluate_ci_skip(
    repo_root: Path,
    *,
    event_name: str,
    message_text: str | None = None,
) -> dict[str, str]:
    """Determine GitHub Actions skip outputs without disabling required PR status gates."""
    messages = (
        [message_text]
        if message_text is not None
        else read_git_commit_messages(repo_root, event_name)
    )
    skip_requested = any(detect_ci_skip(message) for message in messages)
    skip_non_required_heavy = skip_requested and event_name != "workflow_dispatch"
    return {
        "skip_requested": "true" if skip_requested else "false",
        "skip_non_required_heavy": "true" if skip_non_required_heavy else "false",
    }


def write_github_outputs(output_path: Path, outputs: dict[str, str]) -> None:
    """Append key=value step outputs to GITHUB_OUTPUT."""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("a", encoding="utf-8", newline="\n") as handle:
        for key, value in outputs.items():
            handle.write(f"{key}={value}\n")


def run_self_test() -> int:
    """Run quick internal verification checks and return 0 on success."""
    valid_ok, _ = validate_commit_message("feat: add guard (refs #2727)")
    valid_paren, _ = validate_commit_message("fix: handle timeout (#2727)")
    exempt_merge, _ = validate_commit_message("Merge branch 'main' into feat/test")
    missing_ref, _ = validate_commit_message("chore: tidy scripts")
    skip_yes = detect_ci_skip("docs: typo fix [skip ci] (refs #2727)")
    skip_comment = detect_ci_skip("feat: test (refs #2727)\n# [skip ci]")

    checks = (
        valid_ok,
        valid_paren,
        exempt_merge,
        not missing_ref,
        skip_yes,
        not skip_comment,
    )
    if not all(checks):
        print("Self-test failed", file=sys.stderr)
        return 1

    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp) / "out.txt"
        write_github_outputs(tmp_path, {"skip_requested": "false"})
        if tmp_path.read_text(encoding="utf-8") != "skip_requested=false\n":
            print("Self-test output write failed", file=sys.stderr)
            return 1

    print("check_commit_message.py self-test passed")
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--message-file", type=Path, help="Commit message file to validate.")
    group.add_argument("--message", help="Commit message text to validate.")
    group.add_argument(
        "--check-ci-skip-git",
        action="store_true",
        help="Inspect git HEAD (and HEAD^2 for pull_request) for [skip ci]/[ci skip].",
    )
    group.add_argument(
        "--check-ci-skip-file",
        type=Path,
        help="Inspect a commit message file for [skip ci]/[ci skip].",
    )
    group.add_argument("--self-test", action="store_true", help="Run built-in verification checks.")
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path("."),
        help="Repository root for --check-ci-skip-git.",
    )
    parser.add_argument(
        "--event-name",
        default="",
        help="GitHub Actions event name (e.g., push, pull_request, workflow_dispatch).",
    )
    parser.add_argument(
        "--github-output",
        type=Path,
        help="Optional GITHUB_OUTPUT path for writing skip outputs.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)

    if args.self_test:
        return run_self_test()

    if args.check_ci_skip_git or args.check_ci_skip_file is not None:
        message_text: str | None = None
        if args.check_ci_skip_file is not None:
            message_text = args.check_ci_skip_file.read_text(encoding="utf-8", errors="replace")
        outputs = evaluate_ci_skip(
            args.repo_root,
            event_name=args.event_name,
            message_text=message_text,
        )
        if args.github_output is not None:
            write_github_outputs(args.github_output, outputs)
        print(json.dumps(outputs, ensure_ascii=False, sort_keys=True))
        return 0

    if args.message_file is not None:
        if not args.message_file.is_file():
            print(f"Commit message file not found: {args.message_file}", file=sys.stderr)
            return 1
        raw_text = args.message_file.read_text(encoding="utf-8", errors="replace")
    else:
        raw_text = args.message or ""

    ok, detail = validate_commit_message(raw_text)
    if ok:
        print(detail)
        return 0

    print(detail, file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
