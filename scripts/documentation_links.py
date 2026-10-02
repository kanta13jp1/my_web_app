"""Check CommonMark local file targets without making network requests."""
from pathlib import Path
from urllib.parse import unquote, urlsplit
from markdown_it import MarkdownIt


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
            # External, custom-scheme and pure fragment URLs are not fetched.
            if url.scheme or url.netloc or not url.path:
                continue
            decoded = unquote(url.path)
            # Root-relative extensionless targets are web application routes,
            # not repository files. Their availability belongs to browser CI.
            if decoded.startswith("/") and not Path(decoded).suffix:
                continue
            path = (root / decoded.lstrip("/")) if decoded.startswith("/") else source.parent / decoded
            path = path.resolve()
            reason = "outside_repository" if not path.is_relative_to(root) else "missing_local_target" if not path.exists() else None
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
    print(json.dumps({"checked_files": len(paths), "findings": report, "external_urls": "not_checked", "anchors": "not_checked", "root_application_routes": "not_checked"}, ensure_ascii=False))
    raise SystemExit(1 if report else 0)
