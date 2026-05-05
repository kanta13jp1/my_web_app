#!/usr/bin/env python3
"""Quality gate for generated blog drafts before publish.

The gate is intentionally dependency-free so it can run in GitHub Actions
before any Supabase or external publishing call.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


DEFAULT_CORPUS_ROOTS = ["docs/blog-drafts", "docs/blog"]


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def strip_frontmatter(text: str) -> str:
    lines = text.splitlines()
    if lines and lines[0].strip() == "---":
        for idx, line in enumerate(lines[1:], start=1):
            if line.strip() == "---":
                return "\n".join(lines[idx + 1 :])
    return text


def strip_code_fences(text: str) -> str:
    return re.sub(r"```.*?```", "", text, flags=re.DOTALL)


def extract_frontmatter(text: str) -> dict[str, str]:
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return {}
    data: dict[str, str] = {}
    for line in lines[1:]:
        if line.strip() == "---":
            break
        match = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line.strip())
        if not match:
            continue
        value = match.group(2).strip().strip('"').strip("'")
        data[match.group(1).lower()] = value
    return data


def extract_title(text: str) -> str:
    frontmatter = extract_frontmatter(text)
    if frontmatter.get("title"):
        return frontmatter["title"]
    for line in strip_frontmatter(text).splitlines():
        if line.startswith("# "):
            return line[2:].strip()
    return ""


def visible_text(text: str) -> str:
    return strip_code_fences(strip_frontmatter(text))


def compact_char_count(text: str) -> int:
    return len(re.sub(r"\s+", "", visible_text(text)))


def h2_headings(text: str) -> list[str]:
    headings: list[str] = []
    for line in visible_text(text).splitlines():
        if re.match(r"^##\s+\S", line):
            headings.append(line.strip())
    return headings


def normalize_for_similarity(text: str) -> str:
    text = visible_text(text).lower()
    text = re.sub(r"https?://\S+", " ", text)
    text = re.sub(r"[\W_]+", " ", text, flags=re.UNICODE)
    return re.sub(r"\s+", "", text)


def normalize_title(title: str) -> str:
    return re.sub(r"[\W_]+", "", title.lower(), flags=re.UNICODE)


def char_ngrams(text: str, size: int = 5) -> set[str]:
    if len(text) < size:
        return {text} if text else set()
    return {text[i : i + size] for i in range(0, len(text) - size + 1)}


def jaccard(left: set[str], right: set[str]) -> float:
    if not left or not right:
        return 0.0
    return len(left & right) / len(left | right)


def same_language_candidate(candidate: Path, language: str) -> bool:
    is_en = candidate.stem.endswith("-en")
    if language == "ja":
        return not is_en
    if language == "en":
        return is_en
    return True


def find_duplicates(
    draft_path: Path,
    draft_text: str,
    corpus_roots: list[Path],
    language: str,
    threshold: float,
) -> list[dict[str, Any]]:
    title = normalize_title(extract_title(draft_text))
    draft_ngrams = char_ngrams(normalize_for_similarity(draft_text))
    duplicates: list[dict[str, Any]] = []

    for root in corpus_roots:
        if not root.exists():
            continue
        for candidate in sorted(root.rglob("*.md")):
            if candidate.resolve() == draft_path.resolve():
                continue
            if not same_language_candidate(candidate, language):
                continue
            candidate_text = read_text(candidate)
            candidate_title = normalize_title(extract_title(candidate_text))
            if title and candidate_title and title == candidate_title:
                duplicates.append(
                    {
                        "path": str(candidate),
                        "reason": "duplicate_title",
                        "similarity": 1.0,
                    }
                )
                continue

            similarity = jaccard(draft_ngrams, char_ngrams(normalize_for_similarity(candidate_text)))
            if similarity >= threshold:
                duplicates.append(
                    {
                        "path": str(candidate),
                        "reason": "body_similarity",
                        "similarity": round(similarity, 4),
                    }
                )
    return duplicates


def collect_source_commits(source_ref: str) -> list[dict[str, str]]:
    if not source_ref:
        return []
    try:
        proc = subprocess.run(
            ["git", "log", "--no-merges", "-5", "--format=%H%x09%s", source_ref],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
    except OSError:
        return []
    commits: list[dict[str, str]] = []
    for line in proc.stdout.splitlines():
        if "\t" not in line:
            continue
        sha, subject = line.split("\t", 1)
        commits.append({"sha": sha, "subject": subject})
    return commits


def append_step_summary(report: dict[str, Any], summary_path: str | None) -> None:
    if not summary_path:
        return
    path = Path(summary_path)
    status = "PASS" if report["status"] == "pass" else "FAIL"
    lines = [
        f"## Blog Draft Quality Gate: {status}",
        "",
        f"- Draft: `{report['draft']}`",
        f"- Trace: `{report['trace_id']}`",
        f"- Source ref: `{report['source_ref']}`",
        f"- Characters: {report['metrics']['chars']}",
        f"- H2 headings: {report['metrics']['h2_headings']}",
        f"- Duplicates: {len(report['duplicates'])}",
    ]
    if report["errors"]:
        lines.append("")
        lines.append("### Errors")
        lines.extend(f"- `{err['code']}`: {err['message']}" for err in report["errors"])
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n\n")


def build_report(args: argparse.Namespace) -> dict[str, Any]:
    draft_path = Path(args.draft)
    errors: list[dict[str, str]] = []
    warnings: list[dict[str, str]] = []

    if not draft_path.exists():
        errors.append({"code": "missing_draft", "message": f"Draft not found: {draft_path}"})
        draft_text = ""
    else:
        draft_text = read_text(draft_path)

    title = extract_title(draft_text) if draft_text else ""
    chars = compact_char_count(draft_text) if draft_text else 0
    headings = h2_headings(draft_text) if draft_text else []
    sha256 = hashlib.sha256(draft_text.encode("utf-8", errors="replace")).hexdigest()

    if not title:
        errors.append({"code": "missing_title", "message": "Draft needs a frontmatter title or # heading."})
    if chars < args.min_chars:
        errors.append(
            {
                "code": "too_short",
                "message": f"Draft has {chars} compact chars; minimum is {args.min_chars}.",
            }
        )
    if len(headings) < args.min_headings:
        errors.append(
            {
                "code": "missing_headings",
                "message": f"Draft has {len(headings)} H2 headings; minimum is {args.min_headings}.",
            }
        )

    for required in args.required_heading:
        if not any(line.startswith(required) for line in headings):
            errors.append(
                {
                    "code": "missing_required_heading",
                    "message": f"No H2 heading starts with {required!r}.",
                }
            )

    if not args.trace_id:
        errors.append({"code": "missing_trace_id", "message": "--trace-id is required for publish traceability."})
    if not args.source_ref:
        errors.append({"code": "missing_source_ref", "message": "--source-ref is required for commit traceability."})

    duplicates = []
    if draft_text:
        duplicates = find_duplicates(
            draft_path=draft_path,
            draft_text=draft_text,
            corpus_roots=[Path(root) for root in args.corpus_root],
            language=args.language,
            threshold=args.duplicate_threshold,
        )
        if duplicates:
            first = duplicates[0]
            errors.append(
                {
                    "code": "duplicate_topic",
                    "message": f"Potential duplicate {first['reason']} at {first['path']} ({first['similarity']}).",
                }
            )

    source_commits = collect_source_commits(args.source_ref)
    if args.source_ref and not source_commits:
        warnings.append(
            {
                "code": "source_log_unavailable",
                "message": "Could not resolve git log for source ref; report still records source_ref and draft hash.",
            }
        )

    return {
        "status": "fail" if errors else "pass",
        "created_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "draft": str(draft_path),
        "title": title,
        "language": args.language,
        "trace_id": args.trace_id,
        "source_ref": args.source_ref,
        "source_commits": source_commits,
        "draft_sha256": sha256,
        "metrics": {
            "chars": chars,
            "h2_headings": len(headings),
            "headings": headings,
            "min_chars": args.min_chars,
            "min_headings": args.min_headings,
            "duplicate_threshold": args.duplicate_threshold,
        },
        "duplicates": duplicates,
        "warnings": warnings,
        "errors": errors,
    }


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate a blog draft before publish.")
    parser.add_argument("--draft", required=True, help="Markdown draft path.")
    parser.add_argument("--language", choices=["ja", "en", "any"], default="ja")
    parser.add_argument("--min-chars", type=int, default=800)
    parser.add_argument("--min-headings", type=int, default=2)
    parser.add_argument("--required-heading", action="append", default=[])
    parser.add_argument("--duplicate-threshold", type=float, default=0.82)
    parser.add_argument("--corpus-root", action="append", default=DEFAULT_CORPUS_ROOTS)
    parser.add_argument("--trace-id", default=os.environ.get("TRACE_ID", ""))
    parser.add_argument("--source-ref", default=os.environ.get("GITHUB_SHA", ""))
    parser.add_argument("--report", required=True, help="JSON report path.")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    report = build_report(args)
    report_path = Path(args.report)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    append_step_summary(report, os.environ.get("GITHUB_STEP_SUMMARY"))

    for warning in report["warnings"]:
        print(f"::warning::{warning['code']}: {warning['message']}")
    for error in report["errors"]:
        print(f"::error::{error['code']}: {error['message']}")

    print(json.dumps({"status": report["status"], "report": str(report_path)}, ensure_ascii=False))
    return 1 if report["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
