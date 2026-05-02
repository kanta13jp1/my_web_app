#!/usr/bin/env python3
"""Route GitHub PR review feedback into repair or handoff queues."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


CATEGORIES = (
    "local_patch",
    "design_decision",
    "needs_claude_code",
    "needs_user_product_judgment",
    "stale_superseded",
)

LOCAL_PATCH_PATTERNS = (
    r"\btypo\b",
    r"\bnull\b",
    r"\bunused\b",
    r"\bimport\b",
    r"\blint\b",
    r"\bformat\b",
    r"\btest\b",
    r"\brename\b",
    r"\bfix\b",
    r"\bchange\b",
    r"\bshould\b",
    r"\bmissing\b",
    r"\berror\b",
    r"\bbug\b",
    r"\bexception\b",
)

DESIGN_PATTERNS = (
    r"\bintentional\b",
    r"\btrade[- ]?off\b",
    r"\bwhy\b",
    r"\bconsider\b",
    r"\bdocument\b",
    r"\badr\b",
    r"\bdesign decision\b",
)

CLAUDE_PATTERNS = (
    r"\barchitecture\b",
    r"\barchitectural\b",
    r"\bschema\b",
    r"\bmigration strategy\b",
    r"\bsecurity model\b",
    r"\breview gate\b",
    r"\bpolicy\b",
    r"\bquality gate\b",
    r"\bclaude\b",
    r"\bultrareview\b",
)

USER_PATTERNS = (
    r"\bproduct\b",
    r"\buser judgment\b",
    r"\bmanual decision\b",
    r"\bbusiness\b",
    r"\bpricing\b",
    r"\blegal\b",
    r"\bconfirm\b",
    r"\bask the user\b",
    r"\bowner decision\b",
)

STALE_PATTERNS = (
    r"\balready fixed\b",
    r"\bresolved\b",
    r"\bsuperseded\b",
    r"\boutdated\b",
    r"\bno longer applies\b",
)


@dataclass(frozen=True)
class ReviewItem:
    kind: str
    body: str
    author: str = ""
    url: str = ""
    path: str = ""
    line: int | None = None
    state: str = ""
    resolved: bool = False
    outdated: bool = False
    created_at: str = ""

    @property
    def has_location(self) -> bool:
        return bool(self.path)


def run_gh_json(args: list[str]) -> Any:
    result = subprocess.run(
        ["gh", *args],
        check=False,
        encoding="utf-8",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        raise RuntimeError(
            "gh command failed: "
            + " ".join(["gh", *args])
            + "\n"
            + result.stderr.strip()
        )
    text = result.stdout.strip()
    return json.loads(text) if text else {}


def split_repo(repo: str) -> tuple[str, str]:
    if "/" not in repo:
        raise ValueError("repo must be owner/name")
    owner, name = repo.split("/", 1)
    if not owner or not name:
        raise ValueError("repo must be owner/name")
    return owner, name


def fetch_pr_data(repo: str, pr_number: int) -> dict[str, Any]:
    owner, name = split_repo(repo)
    comments = run_gh_json([
        "api",
        f"repos/{repo}/pulls/{pr_number}/comments?per_page=100",
    ])
    reviews = run_gh_json([
        "api",
        f"repos/{repo}/pulls/{pr_number}/reviews?per_page=100",
    ])
    query = """
    query($owner: String!, $name: String!, $number: Int!) {
      repository(owner: $owner, name: $name) {
        pullRequest(number: $number) {
          title
          url
          reviewThreads(first: 100) {
            nodes {
              isResolved
              isOutdated
              path
              line
              startLine
              comments(first: 20) {
                nodes {
                  author { login }
                  body
                  url
                  createdAt
                }
              }
            }
          }
        }
      }
    }
    """
    threads = run_gh_json([
        "api",
        "graphql",
        "-F",
        f"owner={owner}",
        "-F",
        f"name={name}",
        "-F",
        f"number={pr_number}",
        "-f",
        f"query={query}",
    ])
    return {"comments": comments, "reviews": reviews, "threads": threads}


def read_json(path: str | None, default: Any) -> Any:
    if not path:
        return default
    source = Path(path)
    if not source.exists():
        return default
    return json.loads(source.read_text(encoding="utf-8"))


def normalize_rest_comment(raw: dict[str, Any]) -> ReviewItem:
    user = raw.get("user") if isinstance(raw.get("user"), dict) else {}
    return ReviewItem(
        kind="review_comment",
        body=str(raw.get("body") or ""),
        author=str(user.get("login") or ""),
        url=str(raw.get("html_url") or raw.get("url") or ""),
        path=str(raw.get("path") or ""),
        line=int(raw["line"]) if raw.get("line") is not None else None,
        created_at=str(raw.get("created_at") or ""),
    )


def normalize_review(raw: dict[str, Any]) -> ReviewItem:
    user = raw.get("user") if isinstance(raw.get("user"), dict) else {}
    return ReviewItem(
        kind="pull_request_review",
        body=str(raw.get("body") or ""),
        author=str(user.get("login") or ""),
        url=str(raw.get("html_url") or ""),
        state=str(raw.get("state") or ""),
        created_at=str(raw.get("submitted_at") or ""),
    )


def graphql_threads(data: dict[str, Any]) -> list[dict[str, Any]]:
    repo = (data.get("data") or {}).get("repository") or {}
    pr = repo.get("pullRequest") or {}
    review_threads = pr.get("reviewThreads") or {}
    nodes = review_threads.get("nodes") or []
    return [node for node in nodes if isinstance(node, dict)]


def normalize_thread_comments(data: dict[str, Any]) -> list[ReviewItem]:
    items: list[ReviewItem] = []
    for thread in graphql_threads(data):
        comments = ((thread.get("comments") or {}).get("nodes") or [])
        for comment in comments:
            if not isinstance(comment, dict):
                continue
            author = comment.get("author") if isinstance(comment.get("author"), dict) else {}
            line = thread.get("line") if thread.get("line") is not None else thread.get("startLine")
            items.append(
                ReviewItem(
                    kind="review_thread_comment",
                    body=str(comment.get("body") or ""),
                    author=str(author.get("login") or ""),
                    url=str(comment.get("url") or ""),
                    path=str(thread.get("path") or ""),
                    line=int(line) if line is not None else None,
                    resolved=bool(thread.get("isResolved")),
                    outdated=bool(thread.get("isOutdated")),
                    created_at=str(comment.get("createdAt") or ""),
                )
            )
    return items


def collect_items(data: dict[str, Any]) -> list[ReviewItem]:
    items: list[ReviewItem] = []
    comments = data.get("comments") or []
    reviews = data.get("reviews") or []
    if isinstance(comments, list):
        items.extend(normalize_rest_comment(item) for item in comments if isinstance(item, dict))
    if isinstance(reviews, list):
        items.extend(
            normalize_review(item)
            for item in reviews
            if isinstance(item, dict) and str(item.get("body") or "").strip()
        )
    if isinstance(data.get("threads"), dict):
        items.extend(normalize_thread_comments(data["threads"]))

    deduped: list[ReviewItem] = []
    seen: set[str] = set()
    for item in items:
        key = item.url or f"{item.kind}:{item.path}:{item.line}:{item.body[:160]}"
        if key in seen:
            continue
        seen.add(key)
        deduped.append(item)
    return deduped


def has_any(patterns: tuple[str, ...], text: str) -> bool:
    return any(re.search(pattern, text, flags=re.IGNORECASE) for pattern in patterns)


def classify_item(item: ReviewItem) -> tuple[str, str]:
    body = item.body.strip()
    body_lower = body.lower()
    if item.resolved or item.outdated:
        return "stale_superseded", "Review thread is resolved or outdated."
    if not body:
        return "stale_superseded", "Empty review body."
    if has_any(STALE_PATTERNS, body_lower):
        return "stale_superseded", "Comment states the point is resolved, outdated, or superseded."
    if has_any(USER_PATTERNS, body_lower):
        return "needs_user_product_judgment", "Comment asks for product, business, legal, or owner judgment."
    if has_any(CLAUDE_PATTERNS, body_lower):
        return "needs_claude_code", "Comment touches architecture, schema, security model, or review policy."
    if has_any(DESIGN_PATTERNS, body_lower):
        return "design_decision", "Comment asks for rationale or trade-off documentation."
    if item.state.upper() == "CHANGES_REQUESTED" and not item.has_location:
        return "needs_claude_code", "Top-level requested changes need owner routing before patching."
    if item.has_location:
        if has_any(LOCAL_PATCH_PATTERNS, body_lower):
            return "local_patch", "Located, concrete code feedback."
        return "local_patch", "Located review comment can be handled as a bounded patch."
    return "design_decision", "General feedback without a file location."


def route_items(items: list[ReviewItem]) -> dict[str, Any]:
    groups: dict[str, list[dict[str, Any]]] = {category: [] for category in CATEGORIES}
    for item in items:
        category, reason = classify_item(item)
        groups[category].append(
            {
                "kind": item.kind,
                "body": item.body.strip(),
                "author": item.author,
                "url": item.url,
                "path": item.path,
                "line": item.line,
                "state": item.state,
                "created_at": item.created_at,
                "reason": reason,
            }
        )
    return {
        "counts": {category: len(groups[category]) for category in CATEGORIES},
        "groups": groups,
        "local_patch_paths": sorted(
            {
                item["path"]
                for item in groups["local_patch"]
                if item.get("path")
            }
        ),
    }


def markdown_link(item: dict[str, Any]) -> str:
    label_parts = []
    if item.get("path"):
        label_parts.append(str(item["path"]))
        if item.get("line"):
            label_parts[-1] += f":{item['line']}"
    if item.get("author"):
        label_parts.append(f"by @{item['author']}")
    label = " / ".join(label_parts) or item.get("kind") or "review item"
    url = str(item.get("url") or "")
    return f"[{label}]({url})" if url else label


def one_line(text: str, limit: int = 220) -> str:
    clean = re.sub(r"\s+", " ", text).strip()
    return clean if len(clean) <= limit else clean[: limit - 1].rstrip() + "..."


def render_markdown(
    repo: str,
    pr_number: int,
    routed: dict[str, Any],
    validation_summary: str = "",
) -> str:
    generated_at = dt.datetime.now(dt.timezone.utc).isoformat()
    run_id = os.environ.get("GITHUB_RUN_ID", "")
    run_url = (
        f"https://github.com/{repo}/actions/runs/{run_id}"
        if run_id else ""
    )
    lines = [
        "# PR Review Routing Report",
        "",
        f"- Repository: `{repo}`",
        f"- PR: `#{pr_number}`",
        f"- Generated: `{generated_at}`",
    ]
    if run_url:
        lines.append(f"- Actions run: {run_url}")
    if validation_summary:
        lines.append(f"- Validation summary: {validation_summary}")
    lines.extend(["", "## Counts", ""])
    for category in CATEGORIES:
        lines.append(f"- `{category}`: {routed['counts'].get(category, 0)}")

    local_paths = routed.get("local_patch_paths") or []
    lines.extend(["", "## Local Patch Scope", ""])
    if local_paths:
        for path in local_paths:
            lines.append(f"- `{path}`")
    else:
        lines.append("- No bounded local patch path detected.")

    section_titles = {
        "local_patch": "Local Patch Candidates",
        "design_decision": "Design Decisions",
        "needs_claude_code": "Claude Code Handoff",
        "needs_user_product_judgment": "User/Product Judgment Handoff",
        "stale_superseded": "Stale Or Superseded",
    }
    for category in CATEGORIES:
        lines.extend(["", f"## {section_titles[category]}", ""])
        items = routed["groups"].get(category, [])
        if not items:
            lines.append("- None.")
            continue
        for item in items:
            lines.append(f"- {markdown_link(item)}")
            lines.append(f"  - Reason: {item['reason']}")
            lines.append(f"  - Comment: {one_line(item.get('body', ''))}")

    lines.extend(
        [
            "",
            "## Routing Rules",
            "",
            "- `local_patch`: bounded file-level feedback; patch only the listed files or open a small fix PR.",
            "- `design_decision`: answer or document the trade-off before changing code.",
            "- `needs_claude_code`: route to Claude Code for architecture, schema, security model, or gate design.",
            "- `needs_user_product_judgment`: create an Issue comment or WBS user task before implementation.",
            "- `stale_superseded`: do not patch unless a reviewer reopens the point.",
            "",
            "## Responsibility Boundaries",
            "",
            "- #1557 clusters CI failures and duplicate workflow-failure Issues.",
            "- #1637 evaluates issue digests and backlog shape.",
            "- #1559 routes Claude Code/Codex changelog changes into automation.",
            "- This report only routes PR review comments and requested changes into repair or handoff queues.",
        ]
    )
    return "\n".join(lines) + "\n"


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True, help="GitHub repo as owner/name")
    parser.add_argument("--pr-number", type=int, required=True)
    parser.add_argument("--comments-json", help="Optional REST review comments JSON")
    parser.add_argument("--reviews-json", help="Optional REST reviews JSON")
    parser.add_argument("--threads-json", help="Optional GraphQL reviewThreads JSON")
    parser.add_argument("--output-md", default="/tmp/pr-review-routing.md")
    parser.add_argument("--output-json", default="/tmp/pr-review-routing.json")
    parser.add_argument("--validation-summary", default="")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    if args.comments_json or args.reviews_json or args.threads_json:
        data = {
            "comments": read_json(args.comments_json, []),
            "reviews": read_json(args.reviews_json, []),
            "threads": read_json(args.threads_json, {}),
        }
    else:
        data = fetch_pr_data(args.repo, args.pr_number)

    items = collect_items(data)
    routed = route_items(items)
    routed["repo"] = args.repo
    routed["pr_number"] = args.pr_number
    routed["item_count"] = len(items)
    Path(args.output_json).write_text(
        json.dumps(routed, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    Path(args.output_md).write_text(
        render_markdown(args.repo, args.pr_number, routed, args.validation_summary),
        encoding="utf-8",
    )
    print(f"Routed {len(items)} review item(s) for {args.repo}#{args.pr_number}")
    print(json.dumps(routed["counts"], ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
