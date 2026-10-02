"""Check CommonMark local file targets without making network requests."""
from pathlib import Path
from urllib.parse import unquote, urlsplit
from html.parser import HTMLParser
from functools import lru_cache
import unicodedata
from markdown_it import MarkdownIt


class ExplicitAnchors(HTMLParser):
    def __init__(self):
        super().__init__()
        self.anchors = set()

    def handle_starttag(self, tag, attrs):
        for key, value in attrs:
            if value and (key == 'id' or (tag == 'a' and key == 'name')):
                self.anchors.add(value)


@lru_cache(maxsize=128)
def anchors(path: Path) -> set[str]:
    tokens = MarkdownIt('commonmark').parse(path.read_text(encoding='utf-8-sig'))
    result = set()
    used = set()
    html = ExplicitAnchors()
    for index, token in enumerate(tokens):
        if token.type == 'html_block':
            html.feed(token.content)
        for child in token.children or []:
            if child.type == 'html_inline':
                html.feed(child.content)
        if token.type != 'heading_open':
            continue
        plain = ''.join(child.content for child in tokens[index + 1].children or [] if child.type in ('text', 'code_inline', 'image'))
        slug = ''.join(c for c in plain.lower() if c in '-_' or not unicodedata.category(c).startswith(('P', 'S'))).replace(' ', '-')
        base = slug
        suffix = 0
        while slug in used:
            suffix += 1
            slug = f'{base}-{suffix}'
        used.add(slug)
        result.add(slug)
    return result | html.anchors


def check_links(root: Path, source: Path) -> list[dict[str, object]]:
    root = root.resolve()
    source = source.resolve()
    if not source.is_relative_to(root):
        raise ValueError("source outside repository")
    text = source.read_text(encoding="utf-8-sig")
    findings = []
    for token in MarkdownIt("commonmark").parse(text):
        for child in token.children or []:
            target = child.attrGet("href") if child.type == "link_open" else child.attrGet("src") if child.type == "image" else None
            if not target:
                continue
            url = urlsplit(target)
            # External and custom-scheme URLs are not fetched.
            if url.scheme or url.netloc:
                continue
            decoded = unquote(url.path)
            # Root-relative extensionless targets are web application routes,
            # not repository files. Their availability belongs to browser CI.
            if decoded.startswith("/") and not Path(decoded).suffix:
                continue
            path = source if not decoded else (root / decoded.lstrip("/")) if decoded.startswith("/") else source.parent / decoded
            path = path.resolve()
            reason = "outside_repository" if not path.is_relative_to(root) else "missing_local_target" if not path.exists() else None
            if reason is None and url.fragment and path.is_file() and path.suffix.lower() == '.md':
                if unquote(url.fragment) not in anchors(path):
                    reason = 'missing_markdown_anchor'
            if reason:
                findings.append({"file": source.relative_to(root).as_posix(), "line": (token.map or [0])[0] + 1, "target": target, "reason": reason})
    return findings


if __name__ == "__main__":
    import argparse
    import json
    import subprocess
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("paths", nargs="*")
    args = parser.parse_args()
    paths = args.paths or [p.decode("utf-8") for p in subprocess.check_output(["git", "ls-files", "-z"], cwd=args.root).split(b"\0") if p.lower().endswith(b".md")]
    report = []
    for name in paths:
        report.extend(check_links(args.root, args.root / name))
    print(json.dumps({"checked_files": len(paths), "findings": report, "external_urls": "not_checked", "anchors": "CommonMark headings and explicit HTML IDs", "root_application_routes": "not_checked"}, ensure_ascii=False))
    raise SystemExit(1 if report else 0)
