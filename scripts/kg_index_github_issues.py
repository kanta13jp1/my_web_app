#!/usr/bin/env python3
"""Build Knowledge Graph records from GitHub Issues."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path
from typing import Any

from kg_index_common import SourceRecord, add_common_args, finish, now_iso


def run_gh(args: list[str]) -> Any:
    completed = subprocess.run(
        ["gh", *args],
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    return json.loads(completed.stdout or "[]")


def load_issue_list(repo: str, limit: int) -> list[dict[str, Any]]:
    return run_gh(
        [
            "issue",
            "list",
            "--repo",
            repo,
            "--state",
            "all",
            "--limit",
            str(limit),
            "--json",
            "number,title,body,url,labels,updatedAt",
        ]
    )


def with_comments(repo: str, issues: list[dict[str, Any]]) -> list[dict[str, Any]]:
    enriched: list[dict[str, Any]] = []
    for issue in issues:
        number = str(issue.get("number") or "")
        if not number:
            continue
        detail = run_gh(
            [
                "issue",
                "view",
                number,
                "--repo",
                repo,
                "--json",
                "comments",
            ]
        )
        issue = dict(issue)
        issue["comments"] = detail.get("comments") or []
        enriched.append(issue)
    return enriched


def issue_content(issue: dict[str, Any]) -> str:
    labels = [
        str(label.get("name"))
        for label in issue.get("labels") or []
        if isinstance(label, dict) and label.get("name")
    ]
    comments = []
    for comment in issue.get("comments") or []:
        if isinstance(comment, dict) and comment.get("body"):
            comments.append(str(comment["body"]))
    return "\n\n".join(
        part
        for part in [
            f"#{issue.get('number')} {issue.get('title')}",
            f"labels: {', '.join(labels)}" if labels else "",
            str(issue.get("body") or ""),
            "\n\n".join(comments),
        ]
        if part
    )


def build_records(
    issues: list[dict[str, Any]],
    *,
    repo: str,
) -> list[SourceRecord]:
    records: list[SourceRecord] = []
    for issue in issues:
        number = issue.get("number")
        if number is None:
            continue
        content = issue_content(issue)
        if not content.strip():
            continue
        labels = [
            str(label.get("name"))
            for label in issue.get("labels") or []
            if isinstance(label, dict) and label.get("name")
        ]
        records.append(
            SourceRecord(
                source_type="issue",
                source_id=str(number),
                title=str(issue.get("title") or f"Issue #{number}"),
                content=content,
                source_url=str(
                    issue.get("url") or f"https://github.com/{repo}/issues/{number}"
                ),
                metadata={
                    "repo": repo,
                    "number": number,
                    "labels": labels,
                    "updated_at": issue.get("updatedAt"),
                },
                last_synced_at=str(issue.get("updatedAt") or now_iso()),
            )
        )
    return records


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default="kanta13jp1/my_web_app")
    parser.add_argument("--issues-json")
    parser.add_argument("--include-comments", action="store_true")
    add_common_args(parser, default_output="github-issues.jsonl")
    args = parser.parse_args()

    if args.issues_json:
        issues = json.loads(Path(args.issues_json).read_text(encoding="utf-8"))
    else:
        issues = load_issue_list(args.repo, args.limit)
        if args.include_comments:
            issues = with_comments(args.repo, issues)
    finish(build_records(issues, repo=args.repo), args)


if __name__ == "__main__":
    main()
