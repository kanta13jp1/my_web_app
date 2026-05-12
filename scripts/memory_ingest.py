#!/usr/bin/env python3
"""Create Obsidian-compatible memory notes from URLs, text, or GitHub items.

The script is intentionally dependency-free. It provides the first useful slice
of issue #974: an ingest pipeline that creates a Markdown note proposal,
suggests related notes, supports draft/save/discard modes, and writes an audit
log.
"""

from __future__ import annotations

import argparse
import html
import json
import re
import subprocess
import sys
import urllib.request
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

REPO_ROOT = Path(__file__).resolve().parent.parent
MEMORY_DIR = REPO_ROOT / "memory"
DEFAULT_DRAFT_DIR = MEMORY_DIR / "ingest_drafts"
DEFAULT_VAULT_DIR = MEMORY_DIR / "vault"
DEFAULT_LOG_PATH = MEMORY_DIR / "ingest_log.jsonl"
INVALID_FILENAME_CHARS = re.compile(r'[<>:"/\\|?*\x00-\x1f]')
TAG_RE = re.compile(r"[^A-Za-z0-9_\-/\u3040-\u30ff\u3400-\u9fff]+")
TOKEN_RE = re.compile(r"[A-Za-z][A-Za-z0-9_+\-]{2,}|[0-9]{2,}|[\u3040-\u30ff\u3400-\u9fff]{2,}")
HTML_SCRIPT_RE = re.compile(r"<(script|style).*?</\1>", re.IGNORECASE | re.DOTALL)
HTML_TAG_RE = re.compile(r"<[^>]+>")
MOJIBAKE_MARKERS = (
    "\u7e3a",
    "\u7e67",
    "\u8709",
    "\u8b41",
    "\u9695",
    "\u9015",
    "\u879f",
    "\u9b06",
    "\u90b1",
    "\u9711",
    "\u96a8",
    "\u83a0",
    "\u95bc",
    "\u7e5d",
    "\u8737",
    "\u60c4",
    "\u8373",
    "\u8b5b",
    "\u8763",
    "\u8811",
    "\u8b0c",
    "\u8cbf",
    "\ufffd",
)


@dataclass
class SourcePayload:
    source_type: str
    source_url: str
    title: str
    body: str
    metadata: dict[str, str]


@dataclass
class RelatedNote:
    title: str
    path: str
    score: int


def slugify(text: str, max_len: int = 56) -> str:
    slug = INVALID_FILENAME_CHARS.sub("", text.strip().lower())
    slug = re.sub(r"\s+", "-", slug)
    slug = re.sub(r"[^a-z0-9._\-\u3040-\u30ff\u3400-\u9fff]+", "-", slug)
    slug = re.sub(r"-+", "-", slug).strip("-._")
    return slug[:max_len] or "untitled"


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def yaml_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def yaml_list(values: Iterable[str]) -> str:
    return "[" + ", ".join(yaml_string(value) for value in values) + "]"


def mojibake_score(value: str) -> int:
    return sum(value.count(marker) for marker in MOJIBAKE_MARKERS) + value.count("\ufffd") * 8


def repair_mojibake(value: str) -> str:
    if not value or mojibake_score(value) == 0:
        return value
    candidates = [value]
    for source_encoding, target_encoding in (("cp932", "utf-8"), ("latin-1", "utf-8")):
        try:
            candidates.append(value.encode(source_encoding).decode(target_encoding))
        except UnicodeError:
            continue
    return min(candidates, key=mojibake_score)


def decode_bytes(raw: bytes) -> str:
    candidates: list[str] = []
    for encoding in ("utf-8-sig", "utf-8", "cp932", "shift_jis", "mbcs"):
        try:
            candidates.append(raw.decode(encoding))
        except (LookupError, UnicodeDecodeError):
            continue
    if not candidates:
        candidates.append(raw.decode("utf-8", errors="replace"))
    return repair_mojibake(min(candidates, key=mojibake_score))


def run_json(command: list[str]) -> dict[str, object] | None:
    try:
        result = subprocess.run(
            command,
            check=True,
            capture_output=True,
        )
        return repair_json_strings(json.loads(decode_bytes(result.stdout)))
    except (subprocess.CalledProcessError, FileNotFoundError, json.JSONDecodeError):
        return None


def repair_json_strings(value: object) -> object:
    if isinstance(value, str):
        return repair_mojibake(value)
    if isinstance(value, list):
        return [repair_json_strings(item) for item in value]
    if isinstance(value, dict):
        return {key: repair_json_strings(item) for key, item in value.items()}
    return value


def fetch_github_issue(repo: str, number: int) -> SourcePayload | None:
    data = run_json(
        [
            "gh",
            "issue",
            "view",
            str(number),
            "--repo",
            repo,
            "--json",
            "title,body,state,labels,createdAt,updatedAt,url",
        ]
    )
    if not data:
        return None
    labels = ", ".join(str(label.get("name", "")) for label in data.get("labels", []))
    return SourcePayload(
        source_type="github_issue",
        source_url=str(data.get("url") or ""),
        title=f"GitHub Issue #{number}: {data.get('title') or 'Untitled'}",
        body=str(data.get("body") or "(empty body)"),
        metadata={
            "gh_repo": repo,
            "gh_issue_number": str(number),
            "gh_state": str(data.get("state") or ""),
            "gh_labels": labels,
            "gh_created_at": str(data.get("createdAt") or ""),
            "gh_updated_at": str(data.get("updatedAt") or ""),
        },
    )


def fetch_github_pr(repo: str, number: int) -> SourcePayload | None:
    data = run_json(
        [
            "gh",
            "pr",
            "view",
            str(number),
            "--repo",
            repo,
            "--json",
            "title,body,state,labels,createdAt,updatedAt,url,headRefName,baseRefName",
        ]
    )
    if not data:
        return None
    labels = ", ".join(str(label.get("name", "")) for label in data.get("labels", []))
    return SourcePayload(
        source_type="github_pr",
        source_url=str(data.get("url") or ""),
        title=f"GitHub PR #{number}: {data.get('title') or 'Untitled'}",
        body=str(data.get("body") or "(empty body)"),
        metadata={
            "gh_repo": repo,
            "gh_pr_number": str(number),
            "gh_state": str(data.get("state") or ""),
            "gh_labels": labels,
            "gh_head": str(data.get("headRefName") or ""),
            "gh_base": str(data.get("baseRefName") or ""),
            "gh_created_at": str(data.get("createdAt") or ""),
            "gh_updated_at": str(data.get("updatedAt") or ""),
        },
    )


def fetch_url(url: str, limit: int) -> SourcePayload | None:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "jibun-memory-ingest/1.0 (+https://github.com/kanta13jp1/my_web_app)"},
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            raw = response.read(limit)
    except OSError:
        return None
    text = decode_bytes(raw)
    title_match = re.search(r"<title[^>]*>(.*?)</title>", text, re.IGNORECASE | re.DOTALL)
    title = html.unescape(title_match.group(1)).strip() if title_match else f"URL ingest: {url}"
    text = HTML_SCRIPT_RE.sub(" ", text)
    text = HTML_TAG_RE.sub(" ", text)
    text = html.unescape(text)
    text = re.sub(r"\s+", " ", text).strip()
    return SourcePayload(
        source_type="url",
        source_url=url,
        title=title or f"URL ingest: {url}",
        body=text[:limit],
        metadata={"url": url},
    )


def read_source(args: argparse.Namespace) -> SourcePayload:
    if args.gh_issue:
        payload = fetch_github_issue(args.repo, args.gh_issue)
        if not payload:
            raise RuntimeError(f"failed to fetch GitHub issue #{args.gh_issue}")
        return payload
    if args.gh_pr:
        payload = fetch_github_pr(args.repo, args.gh_pr)
        if not payload:
            raise RuntimeError(f"failed to fetch GitHub PR #{args.gh_pr}")
        return payload
    if args.url:
        payload = fetch_url(args.url, args.fetch_limit)
        if not payload:
            raise RuntimeError(f"failed to fetch URL: {args.url}")
        return payload
    if args.input_file:
        path = Path(args.input_file)
        body = decode_bytes(path.read_bytes())
        title = args.title or f"File ingest: {path.name}"
        return SourcePayload("file", str(path), title, body, {"input_file": str(path)})
    body = sys.stdin.read()
    if not body.strip():
        raise RuntimeError("no input; use --gh-issue, --gh-pr, --url, --input-file, or stdin")
    return SourcePayload("manual", "", args.title or "Manual ingest", body, {})


def tokenize(text: str) -> set[str]:
    return {token.lower() for token in TOKEN_RE.findall(text) if len(token.strip()) >= 2}


def extract_title(text: str, fallback: str) -> str:
    for line in text.splitlines():
        if line.startswith("# "):
            return line[2:].strip() or fallback
    return fallback


def note_path_label(path: Path) -> str:
    try:
        rel = path.relative_to(REPO_ROOT)
    except ValueError:
        rel = path
    return rel.as_posix()


def collect_notes(roots: list[Path]) -> list[tuple[Path, str, set[str]]]:
    notes: list[tuple[Path, str, set[str]]] = []
    for root in roots:
        if not root.exists():
            continue
        for path in root.rglob("*.md"):
            if any(part in {".git", "node_modules", "build", "dist", "ingest_drafts"} for part in path.parts):
                continue
            try:
                text = path.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            notes.append((path, extract_title(text, path.stem), tokenize(text[:12000])))
    return notes


def rank_related(payload: SourcePayload, roots: list[Path], minimum: int, limit: int) -> list[RelatedNote]:
    source_tokens = tokenize(f"{payload.title}\n{payload.body[:24000]}")
    ranked: list[RelatedNote] = []
    for path, title, tokens in collect_notes(roots):
        score = len(source_tokens.intersection(tokens))
        if score <= 0:
            continue
        ranked.append(RelatedNote(title=title, path=note_path_label(path), score=score))
    ranked.sort(key=lambda item: (-item.score, item.path))
    selected = ranked[:limit]
    if len(selected) < minimum:
        memory_index = MEMORY_DIR / "MEMORY.md"
        if memory_index.exists() and all(item.path != note_path_label(memory_index) for item in selected):
            selected.append(RelatedNote("MEMORY Index", note_path_label(memory_index), 1))
    return selected[: max(limit, minimum)]


def summarize(text: str, max_chars: int = 560) -> str:
    compact = re.sub(r"\s+", " ", text).strip()
    if not compact:
        return "(empty)"
    if len(compact) <= max_chars:
        return compact
    end = compact.rfind("。", 0, max_chars)
    if end < 120:
        end = compact.rfind(".", 0, max_chars)
    if end < 120:
        end = max_chars
    return compact[:end].strip() + "..."


def extract_concepts(payload: SourcePayload, limit: int = 12) -> list[str]:
    counts: dict[str, int] = {}
    for token in tokenize(f"{payload.title}\n{payload.body[:20000]}"):
        if token.isdigit() or len(token) < 3:
            continue
        counts[token] = counts.get(token, 0) + 1
    ranked = sorted(counts, key=lambda item: (-counts[item], item))
    return ranked[:limit]


def normalize_tags(tags: Iterable[str], payload: SourcePayload) -> list[str]:
    result = ["ingest", payload.source_type.replace("_", "-")]
    for tag in tags:
        cleaned = TAG_RE.sub("-", tag.strip()).strip("-").lower()
        if cleaned:
            result.append(cleaned)
    seen: set[str] = set()
    output: list[str] = []
    for tag in result:
        if tag not in seen:
            seen.add(tag)
            output.append(tag)
    return output


def render_note(
    payload: SourcePayload,
    slug: str,
    related: list[RelatedNote],
    tags: list[str],
    status: str,
) -> str:
    now = utc_now()
    related_links = [f"[[{Path(item.path).stem}]]" for item in related]
    metadata_lines = [
        "---",
        f"title: {yaml_string(payload.title)}",
        "type: ingest",
        f"status: {status}",
        f"source_type: {payload.source_type}",
        f"source_url: {yaml_string(payload.source_url)}",
        f"slug: {yaml_string(slug)}",
        f"ingested_at: {now}",
        f"tags: {yaml_list(tags)}",
        f"related: {yaml_list(related_links)}",
    ]
    for key, value in sorted(payload.metadata.items()):
        safe_key = re.sub(r"[^A-Za-z0-9_]+", "_", key).strip("_") or "meta"
        metadata_lines.append(f"{safe_key}: {yaml_string(value)}")
    metadata_lines.append("---")

    concepts = extract_concepts(payload)
    lines = [
        *metadata_lines,
        "",
        f"# {payload.title}",
        "",
        "## Summary",
        "",
        summarize(payload.body),
        "",
        "## Concepts",
        "",
    ]
    lines.extend(f"- `{concept}`" for concept in concepts) if concepts else lines.append("- (none)")
    lines.extend(["", "## Related Notes", ""])
    if related:
        for item in related:
            lines.append(f"- [[{Path(item.path).stem}]] - {item.title} (score {item.score})")
    else:
        lines.append("- No related notes found yet.")
    lines.extend(
        [
            "",
            "## Source",
            "",
            f"- type: `{payload.source_type}`",
            f"- url/path: {payload.source_url or '(manual input)'}",
            "",
            "## Raw Content",
            "",
            payload.body.strip() or "(empty)",
            "",
        ]
    )
    return "\n".join(lines)


def write_unique(directory: Path, slug: str, content: str) -> Path:
    directory.mkdir(parents=True, exist_ok=True)
    date = datetime.now().strftime("%Y%m%d")
    path = directory / f"ingest_{date}_{slug}.md"
    counter = 1
    while path.exists():
        path = directory / f"ingest_{date}_{slug}_{counter}.md"
        counter += 1
    path.write_text(content, encoding="utf-8")
    return path


def append_log(log_path: Path, payload: SourcePayload, slug: str, mode: str, note_path: Path | None, related: list[RelatedNote]) -> None:
    log_path.parent.mkdir(parents=True, exist_ok=True)
    record = {
        "ingested_at": utc_now(),
        "mode": mode,
        "slug": slug,
        "source_type": payload.source_type,
        "source_url": payload.source_url,
        "title": payload.title,
        "note_path": str(note_path) if note_path else "",
        "related": [asdict(item) for item in related],
    }
    with log_path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, ensure_ascii=False) + "\n")


def parse_roots(values: list[str]) -> list[Path]:
    roots = [MEMORY_DIR, REPO_ROOT / "docs"]
    for value in values:
        path = Path(value)
        roots.append(path if path.is_absolute() else REPO_ROOT / path)
    return roots


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gh-issue", type=int, help="GitHub issue number to ingest")
    parser.add_argument("--gh-pr", type=int, help="GitHub pull request number to ingest")
    parser.add_argument("--repo", default="kanta13jp1/my_web_app")
    parser.add_argument("--url", help="URL to fetch and ingest")
    parser.add_argument("--input-file", help="Local text/Markdown file to ingest")
    parser.add_argument("--title", default="", help="Title override for manual/file input")
    parser.add_argument("--slug", default="", help="Slug override")
    parser.add_argument("--mode", choices=["draft", "save", "discard"], default="draft")
    parser.add_argument("--target-dir", default="", help="Directory for --mode save")
    parser.add_argument("--draft-dir", default="", help="Directory for --mode draft")
    parser.add_argument("--export-dir", default="", help="Optional extra Obsidian vault export directory")
    parser.add_argument("--log", default="", help="Audit log JSONL path")
    parser.add_argument("--related-root", action="append", default=[], help="Extra Markdown root for related-note ranking")
    parser.add_argument("--min-related", type=int, default=1)
    parser.add_argument("--max-related", type=int, default=8)
    parser.add_argument("--tag", action="append", default=[])
    parser.add_argument("--fetch-limit", type=int, default=80000)
    parser.add_argument("--print", action="store_true", help="Print the generated note to stdout")
    args = parser.parse_args()

    try:
        payload = read_source(args)
    except RuntimeError as exc:
        print(f"ERR: {exc}", file=sys.stderr)
        return 1

    slug = args.slug or slugify(payload.title)
    roots = parse_roots(args.related_root)
    related = rank_related(payload, roots, args.min_related, args.max_related)
    tags = normalize_tags(args.tag, payload)
    note_status = "draft" if args.mode == "draft" else "accepted" if args.mode == "save" else "discarded"
    note = render_note(payload, slug, related, tags, note_status)

    note_path: Path | None = None
    if args.mode == "draft":
        draft_dir = Path(args.draft_dir) if args.draft_dir else DEFAULT_DRAFT_DIR
        note_path = write_unique(draft_dir, slug, note)
    elif args.mode == "save":
        target_dir = Path(args.target_dir) if args.target_dir else DEFAULT_VAULT_DIR
        note_path = write_unique(target_dir, slug, note)
    elif args.mode == "discard":
        note_path = None

    if args.export_dir and args.mode != "discard":
        export_dir = Path(args.export_dir)
        exported = write_unique(export_dir, slug, note)
        print(f"exported {exported}")

    log_path = Path(args.log) if args.log else DEFAULT_LOG_PATH
    append_log(log_path, payload, slug, args.mode, note_path, related)

    if args.print:
        print(note)
    if note_path:
        print(f"wrote {note_path}")
    else:
        print("discarded ingest proposal")
    print(f"logged {log_path}")
    if related:
        print("related:")
        for item in related:
            print(f"  - {item.path} (score {item.score})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
