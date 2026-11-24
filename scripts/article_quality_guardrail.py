#!/usr/bin/env python3
"""Article publish automated quality guardrail (#2648).

Dependency-free validator enforcing article structural completeness,
placeholder/stub rejection, near-duplicate topic overlap checks against
`docs/blog-drafts/` and `docs/blog/zenn/`, and git commit traceability with
fail-closed JSON and Markdown error audit logs.
"""

from __future__ import annotations

import argparse
from collections import Counter
from dataclasses import asdict, dataclass
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from typing import Any


DEFAULT_CORPUS_ROOTS = ("docs/blog-drafts", "docs/blog/zenn")
DEFAULT_MIN_CHARS = 600
DEFAULT_MIN_H2 = 2
DEFAULT_SIMILARITY_THRESHOLD = 0.55

PLACEHOLDER_PATTERNS: tuple[tuple[str, re.Pattern[str]], ...] = (
    ("todo_marker", re.compile(r"\b(?:TODO|TBD|FIXME)\b")),
    ("lorem_ipsum", re.compile(r"(?i)\blorem\s+ipsum\b")),
    ("coming_soon", re.compile(r"(?i)\bcoming\s+soon\b")),
    ("stub_bracket", re.compile(r"\[(?:placeholder|作成中|執筆予定)\]")),
)
CJK_RUN_RE = re.compile(r"[\u3040-\u30ff\u4e00-\u9fff]{2,}")
ASCII_WORD_RE = re.compile(r"[a-z0-9_]{2,}")
FENCE_RE = re.compile(r"```.*?```", flags=re.DOTALL)


@dataclass(frozen=True)
class SimilarArticleMatch:
    path: str
    title: str
    char_3gram_jaccard: float
    term_cosine: float
    similarity: float
    reason: str


@dataclass(frozen=True)
class CommitTrace:
    commit_sha: str
    commit_timestamp: str
    commit_subject: str
    content_sha256: str


@dataclass(frozen=True)
class ArticleEvaluationResult:
    path: str
    title: str
    passed: bool
    substantive_chars: int
    h1_present: bool
    h2_count: int
    failures: list[str]
    top_matches: list[dict[str, Any]]
    traceability: dict[str, str]


def strip_frontmatter(text: str) -> str:
    lines = text.splitlines()
    if lines and lines[0].strip() == "---":
        for idx, line in enumerate(lines[1:], start=1):
            if line.strip() == "---":
                return "\n".join(lines[idx + 1 :])
    return text


def extract_frontmatter(text: str) -> dict[str, str]:
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return {}
    data: dict[str, str] = {}
    for line in lines[1:]:
        if line.strip() == "---":
            break
        match = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line.strip())
        if match:
            data[match.group(1).lower()] = match.group(2).strip().strip('"').strip("'")
    return data


def visible_body_without_code(text: str) -> str:
    return FENCE_RE.sub("", strip_frontmatter(text))


def extract_title(text: str) -> tuple[str, bool]:
    fm = extract_frontmatter(text)
    h1_title = ""
    for line in strip_frontmatter(text).splitlines():
        if re.match(r"^#\s+\S", line):
            h1_title = line[2:].strip()
            break
    fm_title = fm.get("title", "").strip()
    if h1_title:
        return h1_title, True
    if fm_title:
        return fm_title, True
    return "", False


def extract_h2_headings(text: str) -> list[str]:
    headings: list[str] = []
    for line in visible_body_without_code(text).splitlines():
        if re.match(r"^##\s+\S", line):
            headings.append(line.strip())
    return headings


def substantive_char_count(text: str) -> int:
    stripped = visible_body_without_code(text)
    stripped = re.sub(r"^#{1,6}\s+.*$", "", stripped, flags=re.MULTILINE)
    return len(re.sub(r"\s+", "", stripped))


def detect_placeholders(text: str) -> list[str]:
    cleaned = visible_body_without_code(text)
    hits: list[str] = []
    for label, pattern in PLACEHOLDER_PATTERNS:
        if pattern.search(cleaned):
            hits.append(label)
    return hits


def normalize_text(text: str) -> str:
    body = visible_body_without_code(text).lower()
    body = re.sub(r"https?://\S+", " ", body)
    body = re.sub(r"[\W_]+", " ", body, flags=re.UNICODE)
    return re.sub(r"\s+", " ", body).strip()


def normalize_title(title: str) -> str:
    return re.sub(r"[\W_]+", "", title.lower(), flags=re.UNICODE)


def char_ngrams(text: str, size: int = 3) -> set[str]:
    compact = text.replace(" ", "")
    if not compact:
        return set()
    if len(compact) < size:
        return {compact}
    return {compact[i : i + size] for i in range(0, len(compact) - size + 1)}


def jaccard_similarity(left: set[str], right: set[str]) -> float:
    if not left or not right:
        return 0.0
    return len(left & right) / len(left | right)


def extract_term_counts(text: str) -> Counter[str]:
    term_counts: Counter[str] = Counter()
    for word in ASCII_WORD_RE.findall(text):
        term_counts[word] += 1
    for run in CJK_RUN_RE.findall(text):
        for i in range(len(run) - 1):
            term_counts[run[i : i + 2]] += 1
    return term_counts


def cosine_similarity(left: Counter[str], right: Counter[str]) -> float:
    if not left or not right:
        return 0.0
    common = set(left.keys()) & set(right.keys())
    dot = sum(left[k] * right[k] for k in common)
    if dot == 0:
        return 0.0
    norm_l = math.sqrt(sum(v * v for v in left.values()))
    norm_r = math.sqrt(sum(v * v for v in right.values()))
    if norm_l == 0.0 or norm_r == 0.0:
        return 0.0
    return dot / (norm_l * norm_r)


def find_similar_articles(
    target_path: Path,
    target_text: str,
    corpus_roots: list[Path],
    *,
    top_k: int = 3,
) -> list[SimilarArticleMatch]:
    target_resolved = target_path.resolve()
    target_title, _ = extract_title(target_text)
    norm_target_title = normalize_title(target_title)
    norm_target_body = normalize_text(target_text)
    target_3grams = char_ngrams(norm_target_body, size=3)
    target_terms = extract_term_counts(norm_target_body)

    seen_paths: set[Path] = set()
    matches: list[SimilarArticleMatch] = []

    for root in corpus_roots:
        if not root.exists():
            continue
        for candidate in sorted(root.rglob("*.md")):
            cand_resolved = candidate.resolve()
            if cand_resolved == target_resolved or cand_resolved in seen_paths:
                continue
            seen_paths.add(cand_resolved)
            cand_text = candidate.read_text(encoding="utf-8", errors="replace")
            if substantive_char_count(cand_text) < 80:
                continue
            cand_title, _ = extract_title(cand_text)
            norm_cand_title = normalize_title(cand_title)
            norm_cand_body = normalize_text(cand_text)

            jacc = jaccard_similarity(target_3grams, char_ngrams(norm_cand_body, size=3))
            cos = cosine_similarity(target_terms, extract_term_counts(norm_cand_body))
            if norm_target_title and norm_cand_title and norm_target_title == norm_cand_title:
                sim = 1.0
                reason = "duplicate_title"
            else:
                sim = max(jacc, cos)
                reason = "topic_overlap"

            matches.append(
                SimilarArticleMatch(
                    path=candidate.as_posix(),
                    title=cand_title or candidate.name,
                    char_3gram_jaccard=round(jacc, 4),
                    term_cosine=round(cos, 4),
                    similarity=round(sim, 4),
                    reason=reason,
                )
            )

    matches.sort(key=lambda item: (-item.similarity, item.path))
    return matches[:top_k]


def collect_git_traceability(
    file_path: Path,
    content: str,
    *,
    repo_root: Path | None = None,
) -> CommitTrace:
    content_sha = hashlib.sha256(content.encode("utf-8", errors="replace")).hexdigest()
    cwd = str(repo_root) if repo_root else None
    rel_target = str(file_path)

    for cmd in (
        ["git", "log", "-n", "1", "--format=%H\x1f%cI\x1f%s", "--", rel_target],
        ["git", "log", "-n", "1", "--format=%H\x1f%cI\x1f%s", "HEAD"],
    ):
        try:
            proc = subprocess.run(
                cmd,
                cwd=cwd,
                check=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                encoding="utf-8",
                errors="replace",
            )
        except OSError:
            continue
        output = proc.stdout.strip()
        if proc.returncode == 0 and "\x1f" in output:
            parts = output.split("\x1f", 2)
            if len(parts) == 3 and parts[0].strip():
                return CommitTrace(
                    commit_sha=parts[0].strip(),
                    commit_timestamp=parts[1].strip(),
                    commit_subject=parts[2].strip(),
                    content_sha256=content_sha,
                )

    return CommitTrace(
        commit_sha="untracked-local",
        commit_timestamp="",
        commit_subject="not yet committed",
        content_sha256=content_sha,
    )


def evaluate_article(
    article_path: Path,
    *,
    corpus_roots: list[Path],
    min_chars: int = DEFAULT_MIN_CHARS,
    min_h2: int = DEFAULT_MIN_H2,
    similarity_threshold: float = DEFAULT_SIMILARITY_THRESHOLD,
    repo_root: Path | None = None,
) -> ArticleEvaluationResult:
    if not article_path.exists():
        return ArticleEvaluationResult(
            path=article_path.as_posix(),
            title="",
            passed=False,
            substantive_chars=0,
            h1_present=False,
            h2_count=0,
            failures=[f"missing_file: {article_path.as_posix()}"],
            top_matches=[],
            traceability=asdict(
                CommitTrace(
                    commit_sha="missing",
                    commit_timestamp="",
                    commit_subject="",
                    content_sha256="",
                )
            ),
        )

    text = article_path.read_text(encoding="utf-8", errors="replace")
    title, h1_present = extract_title(text)
    chars = substantive_char_count(text)
    h2s = extract_h2_headings(text)
    placeholders = detect_placeholders(text)
    top_matches = find_similar_articles(article_path, text, corpus_roots, top_k=3)
    trace = collect_git_traceability(article_path, text, repo_root=repo_root)

    failures: list[str] = []
    if not title or not h1_present:
        failures.append("missing_title_or_h1: Frontmatter title または # 見出しが不足しています")
    if chars < min_chars:
        failures.append(f"insufficient_length: 本文文字数 {chars} < 最小基準 {min_chars}")
    if len(h2s) < min_h2:
        failures.append(f"missing_h2_sections: H2 見出し数 {len(h2s)} < 最小基準 {min_h2}")
    for marker in placeholders:
        failures.append(f"placeholder_detected: {marker}")

    for match in top_matches:
        if match.similarity >= similarity_threshold:
            failures.append(
                f"topic_overlap ({match.reason}): {match.path} との類似度 {match.similarity:.4f} >= {similarity_threshold:.2f}"
            )

    return ArticleEvaluationResult(
        path=article_path.as_posix(),
        title=title,
        passed=len(failures) == 0,
        substantive_chars=chars,
        h1_present=h1_present,
        h2_count=len(h2s),
        failures=failures,
        top_matches=[asdict(m) for m in top_matches],
        traceability=asdict(trace),
    )


def discover_changed_articles(base_ref: str, *, repo_root: Path | None = None) -> list[Path]:
    cwd = str(repo_root) if repo_root else None
    proc = subprocess.run(
        ["git", "diff", "--name-only", "--diff-filter=AMR", f"{base_ref}..HEAD"],
        cwd=cwd,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if proc.returncode != 0:
        raise RuntimeError(f"git diff failed for {base_ref}..HEAD: {proc.stderr.strip()}")
    targets: list[Path] = []
    for raw_line in proc.stdout.splitlines():
        rel = raw_line.strip().replace("\\", "/")
        if not rel.endswith(".md"):
            continue
        if rel.startswith("docs/blog-drafts/") or rel.startswith("docs/blog/zenn/"):
            candidate = (repo_root / rel) if repo_root else Path(rel)
            if candidate.exists():
                targets.append(candidate)
    return sorted(targets)


def render_markdown_report(report: dict[str, Any]) -> str:
    lines = [
        f"# Article Quality Guardrail Report ({report['status'].upper()})",
        "",
        f"- Checked articles: `{report['checked_count']}`",
        f"- Failed articles: `{report['failed_count']}`",
        f"- Policy thresholds: min_chars=`{report['thresholds']['min_chars']}`, "
        f"min_h2=`{report['thresholds']['min_h2']}`, "
        f"similarity_threshold=`{report['thresholds']['similarity_threshold']}`",
        "",
    ]
    if report["status"] == "skipped":
        lines.append("- Target changes in `docs/blog-drafts/` or `docs/blog/zenn/`: none (graceful pass).")
        return "\n".join(lines) + "\n"

    for item in report["articles"]:
        badge = "PASS" if item["passed"] else "FAIL"
        trace = item["traceability"]
        lines.extend(
            [
                f"## [{badge}] `{item['path']}`",
                f"- Title: {item['title'] or '(none)'}",
                f"- Metrics: chars=`{item['substantive_chars']}`, h2=`{item['h2_count']}`",
                f"- Commit Traceability: sha=`{trace['commit_sha']}`, "
                f"timestamp=`{trace['commit_timestamp']}`, sha256=`{trace['content_sha256'][:16]}...`",
            ]
        )
        if item["failures"]:
            lines.append("- Failures:")
            for reason in item["failures"]:
                lines.append(f"  - {reason}")
        if item["top_matches"]:
            lines.append("- Closest existing corpus matches (top 3):")
            for match in item["top_matches"]:
                lines.append(
                    f"  - `{match['path']}` (similarity={match['similarity']:.4f}, "
                    f"3gram={match['char_3gram_jaccard']:.4f}, cosine={match['term_cosine']:.4f})"
                )
        lines.append("")
    return "\n".join(lines)


def write_outputs(
    report: dict[str, Any],
    *,
    json_out: str = "",
    markdown_out: str = "",
    github_output: str = "",
) -> None:
    md_text = render_markdown_report(report)
    if json_out:
        out_path = Path(json_out)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
            newline="\n",
        )
    if markdown_out:
        md_path = Path(markdown_out)
        md_path.parent.mkdir(parents=True, exist_ok=True)
        md_path.write_text(md_text, encoding="utf-8", newline="\n")
    if github_output:
        with Path(github_output).open("a", encoding="utf-8", newline="\n") as gh:
            gh.write(f"guardrail_status={report['status']}\n")
            gh.write(f"checked_count={report['checked_count']}\n")
            gh.write(f"failed_count={report['failed_count']}\n")


def run_self_test() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        corpus_dir = root / "docs" / "blog-drafts"
        corpus_dir.mkdir(parents=True, exist_ok=True)

        existing = corpus_dir / "existing-cicd.md"
        existing.write_text(
            "---\n"
            "title: Automated Release Pipelines with GitHub Actions\n"
            "---\n\n"
            "# Automated Release Pipelines with GitHub Actions\n\n"
            "## Background\n\n"
            + ("Deterministic deployment checks prevent broken builds in production pipelines. " * 14)
            + "\n\n## Implementation\n\n"
            + ("Signed release tags and least-privilege workflows preserve auditability across teams. " * 14)
            + "\n",
            encoding="utf-8",
        )

        valid_distinct = corpus_dir / "fresh-accessibility.md"
        valid_distinct.write_text(
            "# Designing High-Contrast Flutter Widgets for Mobile Readers\n\n"
            "## Accessibility Contrast\n\n"
            + ("Color luminance ratios above seven to one keep typography legible outdoors. " * 14)
            + "\n\n## Tap Target Guidelines\n\n"
            + ("Minimum forty-eight logical pixel containers avoid accidental misses on touch screens. " * 14)
            + "\n",
            encoding="utf-8",
        )

        hollow_short = corpus_dir / "hollow.md"
        hollow_short.write_text("# Incomplete Idea\n\nTODO finish later.\n", encoding="utf-8")

        pass_res = evaluate_article(valid_distinct, corpus_roots=[corpus_dir])
        fail_res = evaluate_article(hollow_short, corpus_roots=[corpus_dir])
        dup_res = evaluate_article(
            existing,
            corpus_roots=[corpus_dir],
        )
        # Re-check with distinct file duplicating existing content
        dup_copy = corpus_dir / "copy-cicd.md"
        dup_copy.write_text(existing.read_text(encoding="utf-8"), encoding="utf-8")
        dup_copy_res = evaluate_article(dup_copy, corpus_roots=[corpus_dir])

        assert pass_res.passed, f"Expected valid self-test draft to pass: {pass_res.failures}"
        assert not fail_res.passed, "Expected hollow draft to fail"
        assert dup_res.passed, "Self-path exclusion should prevent self-duplicate failure"
        assert not dup_copy_res.passed, "Expected near-duplicate copy to fail"
        print(
            json.dumps(
                {
                    "self_test": "passed",
                    "valid_chars": pass_res.substantive_chars,
                    "hollow_failures": fail_res.failures,
                    "duplicate_failures": dup_copy_res.failures,
                },
                ensure_ascii=False,
            )
        )
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate blog/article quality before publishing.")
    parser.add_argument("--files", nargs="*", default=[], help="Explicit article paths to validate")
    parser.add_argument("--changed-since", default="", help="Git base ref/SHA for PR diff discovery")
    parser.add_argument("--corpus-root", action="append", default=[], help="Corpus root directory")
    parser.add_argument("--min-chars", type=int, default=DEFAULT_MIN_CHARS)
    parser.add_argument("--min-h2", type=int, default=DEFAULT_MIN_H2)
    parser.add_argument("--similarity-threshold", type=float, default=DEFAULT_SIMILARITY_THRESHOLD)
    parser.add_argument("--json-out", default="", help="Path for JSON audit log output")
    parser.add_argument("--markdown-out", default="", help="Path for Markdown audit log output")
    parser.add_argument("--github-output", default="", help="Path to GITHUB_OUTPUT")
    parser.add_argument("--self-test", action="store_true", help="Run built-in deterministic fixture checks")
    args = parser.parse_args(argv)

    if args.self_test:
        return run_self_test()

    corpus_roots = [Path(p) for p in (args.corpus_root or DEFAULT_CORPUS_ROOTS)]
    targets: list[Path] = [Path(p) for p in args.files]
    if args.changed_since:
        targets.extend(discover_changed_articles(args.changed_since))

    unique_targets: list[Path] = []
    seen: set[Path] = set()
    for t in targets:
        resolved = t.resolve()
        if resolved not in seen:
            seen.add(resolved)
            unique_targets.append(t)

    if not unique_targets:
        report = {
            "status": "skipped",
            "checked_count": 0,
            "failed_count": 0,
            "thresholds": {
                "min_chars": args.min_chars,
                "min_h2": args.min_h2,
                "similarity_threshold": args.similarity_threshold,
            },
            "articles": [],
        }
        write_outputs(
            report,
            json_out=args.json_out,
            markdown_out=args.markdown_out,
            github_output=args.github_output,
        )
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return 0

    evaluations = [
        evaluate_article(
            target,
            corpus_roots=corpus_roots,
            min_chars=args.min_chars,
            min_h2=args.min_h2,
            similarity_threshold=args.similarity_threshold,
        )
        for target in unique_targets
    ]
    failed_count = sum(1 for item in evaluations if not item.passed)
    status = "pass" if failed_count == 0 else "fail"
    report = {
        "status": status,
        "checked_count": len(evaluations),
        "failed_count": failed_count,
        "thresholds": {
            "min_chars": args.min_chars,
            "min_h2": args.min_h2,
            "similarity_threshold": args.similarity_threshold,
        },
        "articles": [asdict(item) for item in evaluations],
    }
    write_outputs(
        report,
        json_out=args.json_out,
        markdown_out=args.markdown_out,
        github_output=args.github_output,
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if failed_count == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
