#!/usr/bin/env python3
"""Extract NotebookLM-derived additional requests and open GitHub Issues.

The script is intentionally stdlib-only. It uses the local NotebookLM CLI for
source-grounded extraction and the GitHub CLI for issue creation.
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
import tempfile
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


UTC = dt.timezone.utc
REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUTPUT_DIR = Path("docs/notebooklm-requirements")
DEFAULT_LABELS = ["enhancement", "追加要望", "notebooklm", "automation", "wbs"]
DEFAULT_MAX_CREATED_ISSUES = 9
PRIORITY_LABELS = {
    "P0": "priority:critical",
    "P1": "priority:high",
    "P2": "priority:medium",
    "P3": "priority:medium",
}
MARKER_PREFIX = "notebooklm-requirement"
MARKER_RE = re.compile(
    r"notebooklm-requirement:([0-9a-fA-F-]{8,36}):([0-9]+)"
)


@dataclass(frozen=True)
class CommandResult:
    code: int
    stdout: str
    stderr: str


@dataclass
class Requirement:
    notebook_id: str
    notebook_short_id: str
    notebook_title: str
    notebook_created_at: str | None
    notebook_is_owner: bool
    slot: int
    title: str
    rationale: str
    acceptance_criteria: list[str] = field(default_factory=list)
    implementation_notes: str = ""
    priority: str = "P2"
    requires_verification: bool = True
    marker: str = ""
    issue_title: str = ""
    issue_url: str = ""
    issue_number: int | None = None
    status: str = "extracted"
    error: str = ""

    def to_dict(self) -> dict[str, Any]:
        return {
            "notebook_id": self.notebook_id,
            "notebook_short_id": self.notebook_short_id,
            "notebook_title": self.notebook_title,
            "notebook_created_at": self.notebook_created_at,
            "notebook_is_owner": self.notebook_is_owner,
            "slot": self.slot,
            "title": self.title,
            "rationale": self.rationale,
            "acceptance_criteria": self.acceptance_criteria,
            "implementation_notes": self.implementation_notes,
            "priority": self.priority,
            "requires_verification": self.requires_verification,
            "marker": self.marker,
            "issue_title": self.issue_title,
            "issue_url": self.issue_url,
            "issue_number": self.issue_number,
            "status": self.status,
            "error": self.error,
        }


class DedupFetchError(RuntimeError):
    """Raised when Issue creation would run without reliable dedup evidence."""


def now_iso() -> str:
    return (
        dt.datetime.now(UTC)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )


def run_command(
    args: list[str],
    cwd: Path,
    timeout: int,
    *,
    capture: bool = True,
) -> CommandResult:
    env = {**os.environ, "PYTHONUTF8": "1"}
    try:
        proc = subprocess.run(
            args,
            cwd=str(cwd),
            env=env,
            text=True,
            encoding="utf-8",
            errors="replace",
            stdout=subprocess.PIPE if capture else None,
            stderr=subprocess.PIPE if capture else None,
            check=False,
            timeout=timeout,
        )
    except FileNotFoundError as exc:
        return CommandResult(127, "", str(exc))
    except subprocess.TimeoutExpired as exc:
        return CommandResult(124, exc.stdout or "", exc.stderr or "timeout")
    except OSError as exc:
        return CommandResult(126, "", str(exc))
    return CommandResult(proc.returncode, proc.stdout or "", proc.stderr or "")


def parse_json_maybe_prefixed(raw: str) -> Any:
    raw = raw.strip()
    if not raw:
        raise ValueError("empty JSON input")
    starts = [idx for idx in (raw.find("{"), raw.find("[")) if idx >= 0]
    if starts:
        raw = raw[min(starts) :]
    return json.loads(raw)


def load_json(path: Path, default: Any) -> Any:
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8-sig"))


def save_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


def short_id(notebook_id: str) -> str:
    return notebook_id.split("-", 1)[0]


def one_line(text: Any, fallback: str = "") -> str:
    cleaned = re.sub(r"\s+", " ", str(text or "")).strip()
    cleaned = cleaned.strip("`*_#- ")
    return cleaned or fallback


def truncate(text: str, limit: int) -> str:
    text = one_line(text)
    if len(text) <= limit:
        return text
    return text[: limit - 1].rstrip() + "…"


def normalize_priority(value: Any) -> str:
    text = one_line(value, "P2").upper()
    match = re.search(r"P[0-3]", text)
    return match.group(0) if match else "P2"


def priority_label_for(priority: str) -> str:
    return PRIORITY_LABELS.get(normalize_priority(priority), "priority:medium")


def labels_for_requirement(base_labels: list[str], req: Requirement) -> list[str]:
    labels = [*base_labels, priority_label_for(req.priority)]
    return list(dict.fromkeys(label for label in labels if label))


def marker_for(notebook_id: str, slot: int) -> str:
    return f"{MARKER_PREFIX}:{notebook_id.lower()}:{slot}"


def requirement_hash(req: Requirement) -> str:
    payload = "\n".join(
        [
            req.notebook_id,
            str(req.slot),
            req.title,
            req.rationale,
            "\n".join(req.acceptance_criteria),
        ]
    )
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:16]


def normalize_notebook(item: dict[str, Any], index: int) -> dict[str, Any]:
    notebook_id = str(item.get("id", "")).strip()
    return {
        "index": int(item.get("index") or index),
        "id": notebook_id,
        "short_id": short_id(notebook_id),
        "title": str(item.get("title", "")).strip(),
        "is_owner": bool(item.get("is_owner", False)),
        "created_at": item.get("created_at"),
        "updated_at": item.get("updated_at"),
    }


def read_notebooks(args: argparse.Namespace, root: Path) -> list[dict[str, Any]]:
    if args.input_json:
        data = load_json(Path(args.input_json), {})
    else:
        result = run_command(["notebooklm", "list", "--json"], root, args.timeout)
        if result.code != 0:
            raise RuntimeError(result.stderr.strip() or result.stdout.strip())
        data = parse_json_maybe_prefixed(result.stdout)

    notebooks = data.get("notebooks", data if isinstance(data, list) else [])
    if not isinstance(notebooks, list):
        raise ValueError("NotebookLM payload does not contain a notebook list")
    return [
        normalize_notebook(item, index + 1)
        for index, item in enumerate(notebooks)
        if isinstance(item, dict) and item.get("id")
    ]


def infer_repo(root: Path) -> str:
    result = run_command(
        ["gh", "repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner"],
        root,
        30,
    )
    if result.code == 0 and result.stdout.strip():
        return result.stdout.strip()

    result = run_command(["git", "remote", "get-url", "origin"], root, 30)
    remote = result.stdout.strip()
    match = re.search(r"github\.com[:/](.+?)(?:\.git)?$", remote)
    if match:
        return match.group(1)
    raise RuntimeError("Could not infer GitHub repo; pass --repo")


def ensure_labels(repo: str, labels: list[str], root: Path, timeout: int) -> None:
    result = run_command(
        ["gh", "label", "list", "--repo", repo, "--limit", "500", "--json", "name"],
        root,
        timeout,
    )
    if result.code != 0:
        print(f"[warn] label list failed: {result.stderr.strip()}", file=sys.stderr)
        return
    try:
        existing = {str(row.get("name", "")) for row in json.loads(result.stdout)}
    except json.JSONDecodeError:
        existing = set()
    colors = {
        "notebooklm": "6f42c1",
        "automation": "0E8A16",
        "wbs": "ededed",
        "追加要望": "ededed",
        "priority:critical": "b60205",
        "priority:high": "d93f0b",
        "priority:medium": "fbca04",
    }
    for label in labels:
        if label in existing:
            continue
        create = run_command(
            [
                "gh",
                "label",
                "create",
                label,
                "--repo",
                repo,
                "--color",
                colors.get(label, "ededed"),
                "--description",
                "NotebookLM-derived additional request",
            ],
            root,
            timeout,
        )
        if create.code != 0:
            print(f"[warn] label create failed for {label}", file=sys.stderr)


def existing_requirement_issues(
    repo: str,
    root: Path,
    timeout: int,
    *,
    required: bool = False,
) -> dict[str, dict[str, Any]]:
    result = run_command(
        [
            "gh",
            "issue",
            "list",
            "--repo",
            repo,
            "--state",
            "all",
            "--label",
            "notebooklm",
            "--limit",
            "5000",
            "--json",
            "number,title,body,url,state",
        ],
        root,
        timeout,
    )
    if result.code != 0:
        message = result.stderr.strip() or result.stdout.strip() or "unknown gh issue list failure"
        if required:
            raise DedupFetchError(f"issue dedup fetch failed: {message}")
        print(f"[warn] issue dedup fetch failed: {message}", file=sys.stderr)
        return {}
    try:
        issues = json.loads(result.stdout or "[]")
    except json.JSONDecodeError:
        return {}
    existing: dict[str, dict[str, Any]] = {}
    for issue in issues:
        body = str(issue.get("body", ""))
        for match in MARKER_RE.finditer(body):
            key = f"{MARKER_PREFIX}:{match.group(1).lower()}:{match.group(2)}"
            existing[key] = issue
    return existing


def extraction_prompt(count: int) -> str:
    return f"""
You are reviewing one NotebookLM notebook for the repository `my_web_app`.

System context:
- Flutter Web application backed by Supabase.
- Work is tracked through GitHub Issues/WBS, GitHub Actions, NotebookLM intake,
  AI tool monitoring, and deterministic validation.

Task:
Extract exactly {count} additional requests that should be added to this system.
Turn the notebook's ideas into actionable product, operations, automation,
security, research, or workflow improvements for `my_web_app`.

Rules:
- Return only a JSON array. No markdown, no code fence, no preface.
- Use Japanese for all values.
- Each object must include these keys:
  "title", "rationale", "acceptance_criteria", "implementation_notes",
  "priority", "requires_verification".
- "acceptance_criteria" must be an array of 2 to 4 concrete testable strings.
- If the notebook is not directly technical, translate it into neutral
  knowledge-management, intake, risk-control, or product-research requirements.
- For political, personal, financial, legal, or third-party claims, stay neutral
  and set "requires_verification" to true.
""".strip()


def parse_answer_array(answer: str) -> list[Any]:
    text = answer.strip()
    text = re.sub(r"^```(?:json)?", "", text, flags=re.IGNORECASE).strip()
    text = re.sub(r"```$", "", text).strip()
    start = text.find("[")
    end = text.rfind("]")
    if start < 0 or end < start:
        raise ValueError("answer did not contain a JSON array")
    return json.loads(text[start : end + 1])


def answer_text_from_stdout(stdout: str) -> str:
    try:
        payload = parse_json_maybe_prefixed(stdout)
    except (ValueError, json.JSONDecodeError):
        payload = None
    if isinstance(payload, dict) and "answer" in payload:
        return str(payload.get("answer") or "")
    if isinstance(payload, list):
        return json.dumps(payload, ensure_ascii=False)

    lines = stdout.splitlines()
    answer_lines: list[str] = []
    collecting = False
    for line in lines:
        stripped = line.strip()
        if stripped == "Answer:":
            collecting = True
            continue
        if stripped.startswith("Resumed conversation:"):
            break
        if stripped.startswith("Matched:") or stripped.startswith("Continuing conversation"):
            continue
        if collecting or stripped:
            answer_lines.append(line)
    return "\n".join(answer_lines).strip()


def first_value(item: dict[str, Any], keys: list[str], fallback: str = "") -> Any:
    for key in keys:
        if key in item and item[key] not in (None, ""):
            return item[key]
    return fallback


def normalize_criteria(raw: Any) -> list[str]:
    if isinstance(raw, list):
        criteria = [one_line(value) for value in raw]
    else:
        criteria = [
            one_line(value)
            for value in re.split(r"(?:\n|;|；)", str(raw or ""))
        ]
    return [value for value in criteria if value][:4]


def normalize_requirement(
    notebook: dict[str, Any],
    slot: int,
    item: Any,
) -> Requirement:
    if not isinstance(item, dict):
        item = {"title": str(item)}
    title = one_line(
        first_value(item, ["title", "short_title", "短いタイトル", "name"]),
        fallback=f"{notebook['title']} requirement {slot}",
    )
    rationale = one_line(
        first_value(item, ["rationale", "reason", "理由", "background"]),
        fallback="NotebookLM source indicates this should be reviewed as an additional request.",
    )
    criteria = normalize_criteria(
        first_value(
            item,
            ["acceptance_criteria", "acceptanceCriteria", "受け入れ条件", "criteria"],
            [],
        )
    )
    if not criteria:
        criteria = [
            "要求内容が既存 Issue/WBS と重複しないことを確認する",
            "実装または運用変更を検証するチェック手順が記録されている",
        ]
    notes = one_line(
        first_value(item, ["implementation_notes", "implementationNotes", "実装メモ", "notes"]),
        fallback="NotebookLM 由来の追加要望として一次情報確認後に WBS へ連携する。",
    )
    priority = normalize_priority(first_value(item, ["priority", "優先度"], "P2"))
    requires_raw = first_value(
        item,
        ["requires_verification", "requiresVerification", "要検証"],
        True,
    )
    requires_verification = bool(requires_raw)
    if isinstance(requires_raw, str):
        requires_verification = requires_raw.strip().lower() not in {
            "false",
            "no",
            "0",
            "不要",
        }

    notebook_id = notebook["id"]
    req = Requirement(
        notebook_id=notebook_id,
        notebook_short_id=notebook["short_id"],
        notebook_title=notebook["title"],
        notebook_created_at=notebook.get("created_at"),
        notebook_is_owner=bool(notebook.get("is_owner")),
        slot=slot,
        title=title,
        rationale=rationale,
        acceptance_criteria=criteria,
        implementation_notes=notes,
        priority=priority,
        requires_verification=requires_verification,
    )
    req.marker = marker_for(notebook_id, slot)
    req.issue_title = truncate(
        f"[追加要望][{priority}][NotebookLM] {req.notebook_short_id}:{slot} {title}",
        180,
    )
    return req


def ask_notebook_for_requirements(
    notebook: dict[str, Any],
    args: argparse.Namespace,
    root: Path,
) -> list[Requirement]:
    prompt = extraction_prompt(args.requirements_per_notebook)
    cmd = ["notebooklm", "ask", "--notebook", notebook["id"]]
    if args.notebooklm_json:
        cmd.append("--json")
    cmd.append(prompt)
    result = run_command(cmd, root, args.timeout)
    if result.code != 0:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip())
    rows = parse_answer_array(answer_text_from_stdout(result.stdout))
    reqs = [
        normalize_requirement(notebook, index + 1, item)
        for index, item in enumerate(rows[: args.requirements_per_notebook])
    ]
    if len(reqs) != args.requirements_per_notebook:
        raise ValueError(
            f"expected {args.requirements_per_notebook} requirements, got {len(reqs)}"
        )
    return reqs


def issue_body(req: Requirement, extracted_at: str) -> str:
    criteria = "\n".join(f"- [ ] {item}" for item in req.acceptance_criteria)
    owner = "Owner" if req.notebook_is_owner else "Shared"
    verification = (
        "- [ ] NotebookLM 由来の外部事実は、実装前に公式または一次情報で確認する"
        if req.requires_verification
        else "- [ ] NotebookLM 抽出結果と既存 repo 文脈の整合性を確認する"
    )
    return f"""<!-- {req.marker} -->
<!-- notebooklm-requirement-hash:{requirement_hash(req)} -->

## Source Notebook

- Notebook ID: `{req.notebook_id}`
- Notebook title: {req.notebook_title}
- Ownership: {owner}
- Created: `{req.notebook_created_at or "unknown"}`
- Requirement slot: `{req.slot}/3`
- Suggested priority: `{req.priority}`
- Extracted at: `{extracted_at}`

## Additional Request

{req.title}

## Rationale

{req.rationale}

## Acceptance Criteria

{criteria}

## Implementation Notes

{req.implementation_notes}

## Verification / Routing

{verification}
- [ ] 既存 GitHub Issues / WBS と重複しないことを確認する
- [ ] Claude Code #1 + Codex #1 の top-level 2インスタンス制に沿って担当を決める
- [ ] 完了時は GitHub Issues WBS Sync または `wbs-progress-update.yml` で進捗を同期する

---

Generated by `scripts/notebooklm_requirements_to_issues.py`.
"""


def create_issue(
    repo: str,
    req: Requirement,
    labels: list[str],
    root: Path,
    timeout: int,
    extracted_at: str,
) -> Requirement:
    with tempfile.NamedTemporaryFile(
        "w",
        encoding="utf-8",
        newline="\n",
        suffix=".md",
        delete=False,
    ) as body_file:
        body_file.write(issue_body(req, extracted_at))
        body_path = body_file.name
    try:
        cmd = [
            "gh",
            "issue",
            "create",
            "--repo",
            repo,
            "--title",
            req.issue_title,
            "--body-file",
            body_path,
        ]
        for label in labels:
            cmd.extend(["--label", label])
        result = run_command(cmd, root, timeout)
    finally:
        try:
            Path(body_path).unlink()
        except OSError:
            pass

    if result.code != 0:
        req.status = "issue_create_failed"
        req.error = result.stderr.strip() or result.stdout.strip()
        return req
    req.issue_url = result.stdout.strip()
    number_match = re.search(r"/issues/(\d+)", req.issue_url)
    if number_match:
        req.issue_number = int(number_match.group(1))
    req.status = "created"
    return req


def render_report(
    checked_at: str,
    notebooks: list[dict[str, Any]],
    requirements: list[Requirement],
    errors: list[dict[str, str]],
    repo: str,
    create_issues: bool,
    max_created_issues: int,
) -> str:
    created = [req for req in requirements if req.status == "created"]
    skipped = [req for req in requirements if req.status == "skipped_existing"]
    capped = [req for req in requirements if req.status == "create_cap_reached"]
    failed = [req for req in requirements if req.status.endswith("failed")]
    lines = [
        "# NotebookLM Requirements to GitHub Issues",
        "",
        f"- Checked at: `{checked_at}`",
        f"- Repository: `{repo}`",
        f"- Notebook count in scope: `{len(notebooks)}`",
        f"- Requirements extracted: `{len(requirements)}`",
        f"- Issue creation enabled: `{str(create_issues).lower()}`",
        f"- Issue creation cap: `{max_created_issues if max_created_issues else 'none'}`",
        f"- Issues created: `{len(created)}`",
        f"- Existing requirement Issues skipped: `{len(skipped)}`",
        f"- Requirements held by creation cap: `{len(capped)}`",
        f"- Failed requirements: `{len(failed)}`",
        f"- Notebook extraction errors: `{len(errors)}`",
        "",
    ]
    if created:
        lines.extend(["## Created Issues", ""])
        for req in created:
            lines.append(
                f"- #{req.issue_number}: `{req.notebook_short_id}` slot {req.slot} - {req.title} ({req.issue_url})"
            )
        lines.append("")
    if skipped:
        lines.extend(["## Skipped Existing", ""])
        for req in skipped[:100]:
            lines.append(
                f"- `{req.notebook_short_id}` slot {req.slot}: {req.title} ({req.issue_url or 'existing marker'})"
            )
        if len(skipped) > 100:
            lines.append(f"- ... {len(skipped) - 100} more")
        lines.append("")
    if capped:
        lines.extend(["## Held by Creation Cap", ""])
        for req in capped[:100]:
            lines.append(f"- `{req.notebook_short_id}` slot {req.slot}: {req.title}")
        if len(capped) > 100:
            lines.append(f"- ... {len(capped) - 100} more")
        lines.append("")
    if errors or failed:
        lines.extend(["## Errors", ""])
        for item in errors:
            lines.append(f"- `{item['short_id']}` {item['title']}: {item['error']}")
        for req in failed:
            lines.append(f"- `{req.notebook_short_id}` slot {req.slot}: {req.error}")
        lines.append("")
    lines.append("<!-- generated-by: scripts/notebooklm_requirements_to_issues.py -->")
    lines.append("")
    return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-json", default="", help="NotebookLM list JSON path")
    parser.add_argument("--repo", default="", help="GitHub repo, e.g. owner/name")
    parser.add_argument("--limit", type=int, default=0, help="Max notebooks; 0 means all")
    parser.add_argument("--start-index", type=int, default=1, help="1-based list index")
    parser.add_argument("--requirements-per-notebook", type=int, default=3)
    parser.add_argument("--timeout", type=int, default=180)
    parser.add_argument("--notebooklm-json", action="store_true")
    parser.add_argument("--sleep-seconds", type=float, default=0.0)
    parser.add_argument("--create-issues", action="store_true")
    parser.add_argument(
        "--max-created-issues",
        type=int,
        default=DEFAULT_MAX_CREATED_ISSUES,
        help="Safety cap for newly created Issues; 0 means no cap",
    )
    parser.add_argument("--no-skip-existing-before-ask", action="store_true")
    parser.add_argument(
        "--label",
        action="append",
        default=None,
        help="GitHub issue label; repeatable. Defaults to repo NotebookLM labels.",
    )
    parser.add_argument(
        "--output-dir",
        default=str(DEFAULT_OUTPUT_DIR),
        help="Directory for default report/state outputs",
    )
    parser.add_argument("--json-out", default="")
    parser.add_argument("--report", default="")
    parser.add_argument("--state", default="")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = REPO_ROOT
    checked_at = now_iso()
    output_dir = Path(args.output_dir)
    json_out = Path(args.json_out) if args.json_out else output_dir / "latest-requirements.json"
    report_path = Path(args.report) if args.report else output_dir / "latest-report.md"
    state_path = Path(args.state) if args.state else output_dir / "state.json"
    labels = args.label if args.label is not None else DEFAULT_LABELS
    repo = args.repo or infer_repo(root)

    notebooks = read_notebooks(args, root)
    start = max(1, args.start_index)
    scoped = [item for item in notebooks if int(item["index"]) >= start]
    if args.limit:
        scoped = scoped[: args.limit]

    existing = existing_requirement_issues(
        repo,
        root,
        args.timeout,
        required=args.create_issues,
    )
    if args.create_issues:
        ensure_labels(
            repo,
            list(dict.fromkeys([*labels, *PRIORITY_LABELS.values()])),
            root,
            args.timeout,
        )

    print(f"[scan] notebooks={len(scoped)} repo={repo}", file=sys.stderr, flush=True)
    requirements: list[Requirement] = []
    errors: list[dict[str, str]] = []
    created_count = 0
    skip_before_ask = not args.no_skip_existing_before_ask

    for notebook in scoped:
        slots = range(1, args.requirements_per_notebook + 1)
        existing_for_notebook = {
            slot: existing.get(marker_for(notebook["id"], slot))
            for slot in slots
        }
        if skip_before_ask and all(existing_for_notebook.values()):
            for slot, issue in existing_for_notebook.items():
                req = normalize_requirement(
                    notebook,
                    slot,
                    {"title": issue.get("title", "existing requirement")},
                )
                req.status = "skipped_existing"
                req.issue_url = str(issue.get("url", ""))
                req.issue_number = int(issue["number"]) if issue.get("number") else None
                requirements.append(req)
            print(
                f"[skip] {notebook['short_id']} already has 3 markers",
                file=sys.stderr,
                flush=True,
            )
            continue

        try:
            print(
                f"[ask] index={notebook['index']} {notebook['short_id']} {notebook['title']}",
                file=sys.stderr,
                flush=True,
            )
            extracted = ask_notebook_for_requirements(notebook, args, root)
        except Exception as exc:  # noqa: BLE001 - keep batch moving
            errors.append(
                {
                    "id": notebook["id"],
                    "short_id": notebook["short_id"],
                    "title": notebook["title"],
                    "error": str(exc),
                }
            )
            print(f"[error] {notebook['short_id']} {exc}", file=sys.stderr, flush=True)
            continue

        for req in extracted:
            issue = existing.get(req.marker)
            if issue:
                req.status = "skipped_existing"
                req.issue_url = str(issue.get("url", ""))
                req.issue_number = int(issue["number"]) if issue.get("number") else None
                requirements.append(req)
                continue
            if not args.create_issues:
                req.status = "dry_run"
                requirements.append(req)
                continue
            if args.max_created_issues and created_count >= args.max_created_issues:
                req.status = "create_cap_reached"
                requirements.append(req)
                continue
            req = create_issue(
                repo,
                req,
                labels_for_requirement(labels, req),
                root,
                args.timeout,
                checked_at,
            )
            if req.status == "created":
                created_count += 1
                existing[req.marker] = {
                    "number": req.issue_number,
                    "title": req.issue_title,
                    "url": req.issue_url,
                    "state": "OPEN",
                    "body": req.marker,
                }
                print(f"[created] {req.issue_url}", file=sys.stderr, flush=True)
            else:
                print(
                    f"[warn] create failed {req.notebook_short_id}:{req.slot}",
                    file=sys.stderr,
                    flush=True,
                )
            requirements.append(req)
            if args.sleep_seconds > 0:
                time.sleep(args.sleep_seconds)

    state = load_json(state_path, {})
    state_requirements = state.get("requirements", {}) if isinstance(state, dict) else {}
    for req in requirements:
        state_requirements[req.marker] = {
            "last_seen_at": checked_at,
            "status": req.status,
            "issue_number": req.issue_number,
            "issue_url": req.issue_url,
            "title": req.title,
            "hash": requirement_hash(req),
        }
    save_json(
        state_path,
        {
            "checked_at": checked_at,
            "repo": repo,
            "requirements": state_requirements,
        },
    )
    save_json(
        json_out,
        {
            "checked_at": checked_at,
            "repo": repo,
            "notebook_count": len(scoped),
            "create_issues": args.create_issues,
            "requirements": [req.to_dict() for req in requirements],
            "errors": errors,
        },
    )
    write_text(
        report_path,
        render_report(
            checked_at,
            scoped,
            requirements,
            errors,
            repo,
            args.create_issues,
            args.max_created_issues,
        ),
    )
    print(str(report_path), file=sys.stderr, flush=True)
    return 1 if errors or any(req.status.endswith("failed") for req in requirements) else 0


if __name__ == "__main__":
    sys.exit(main())
