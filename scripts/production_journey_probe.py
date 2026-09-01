#!/usr/bin/env python3
"""Verify route-specific initial HTML for the public conversion journey.

The same contract runs against ``build/web`` before deployment and against the
live Firebase origin after deployment. It intentionally inspects the HTTP/file
response before Flutter boots: title, description, canonical URL, Open Graph
URL, approved content markers, and byte-level uniqueness.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
import urllib.request
from dataclasses import dataclass
from html.parser import HTMLParser
from pathlib import Path


if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")


DEFAULT_BASE_URL = "https://my-web-app-b67f4.web.app"
JOURNEY_PATHS = (
    "/",
    "/subscription-billing",
    "/privacy",
    "/terms",
    "/tokusho",
)
ROOT_EXPECTATION = {
    "title": "自分株式会社とは？ | 人生を経営するAIライフマネジメントアプリ",
    "description": (
        "自分株式会社は、自分自身を一つの会社に見立て、仕事・学習・お金・健康を"
        "整理するライフマネジメントアプリです。登録前にAIの提案を1件試せます。"
    ),
    "contract_markers": ["登録前にAI提案を1件体験"],
}


class ContractError(RuntimeError):
    pass


class MetadataParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.in_title = False
        self.title_parts: list[str] = []
        self.description: str | None = None
        self.canonical: str | None = None
        self.og_url: str | None = None

    @property
    def title(self) -> str:
        return "".join(self.title_parts).strip()

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = {key.lower(): value or "" for key, value in attrs}
        if tag.lower() == "title":
            self.in_title = True
        elif tag.lower() == "meta":
            if values.get("name", "").lower() == "description":
                self.description = values.get("content")
            if values.get("property", "").lower() == "og:url":
                self.og_url = values.get("content")
        elif tag.lower() == "link":
            rels = values.get("rel", "").lower().split()
            if "canonical" in rels:
                self.canonical = values.get("href")

    def handle_endtag(self, tag: str) -> None:
        if tag.lower() == "title":
            self.in_title = False

    def handle_data(self, data: str) -> None:
        if self.in_title:
            self.title_parts.append(data)


@dataclass(frozen=True)
class Response:
    path: str
    status: int
    body: bytes


def load_expectations(config_path: Path) -> dict[str, dict]:
    config = json.loads(config_path.read_text(encoding="utf-8"))
    expectations = {"/": dict(ROOT_EXPECTATION)}
    for route in config["routes"]:
        if route.get("path") in JOURNEY_PATHS:
            expectations[route["path"]] = route
    missing = [path for path in JOURNEY_PATHS if path not in expectations]
    if missing:
        raise ContractError(f"route config is missing: {', '.join(missing)}")
    return expectations


def read_build_response(root_dir: Path, path: str) -> Response:
    file_path = (
        root_dir / "index.html"
        if path == "/"
        else root_dir / path.strip("/") / "index.html"
    )
    if not file_path.is_file():
        raise ContractError(f"{path}: initial HTML not found at {file_path}")
    return Response(path=path, status=200, body=file_path.read_bytes())


def read_http_response(base_url: str, path: str, timeout: float) -> Response:
    url = f"{base_url.rstrip('/')}{path}"
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "text/html",
            "Cache-Control": "no-cache",
            "User-Agent": "my-web-app-static-route-contract/1.0",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return Response(
                path=path,
                status=response.status,
                body=response.read(),
            )
    except Exception as error:
        raise ContractError(f"{path}: HTTP probe failed: {error}") from error


def validate_response(response: Response, expected: dict, base_url: str) -> dict:
    if not 200 <= response.status < 300:
        raise ContractError(
            f"{response.path}: expected HTTP success, got {response.status}"
        )
    try:
        html_text = response.body.decode("utf-8")
    except UnicodeDecodeError as error:
        raise ContractError(f"{response.path}: response is not UTF-8 HTML") from error

    parser = MetadataParser()
    parser.feed(html_text)
    expected_url = f"{base_url.rstrip('/')}{response.path}"
    fields = {
        "title": (parser.title, expected["title"]),
        "description": (parser.description, expected["description"]),
        "canonical": (parser.canonical, expected_url),
        "og:url": (parser.og_url, expected_url),
    }
    for name, (actual, wanted) in fields.items():
        if actual != wanted:
            raise ContractError(
                f"{response.path}: {name} mismatch: expected {wanted!r}, got {actual!r}"
            )
    for marker in expected.get("contract_markers", []):
        if marker not in html_text:
            raise ContractError(
                f"{response.path}: approved content marker missing: {marker!r}"
            )

    return {
        "path": response.path,
        "status": response.status,
        "title": parser.title,
        "description": parser.description,
        "canonical": parser.canonical,
        "og_url": parser.og_url,
        "sha256": hashlib.sha256(response.body).hexdigest(),
        "bytes": len(response.body),
    }


def run_probe(
    *,
    config_path: Path,
    base_url: str = DEFAULT_BASE_URL,
    root_dir: Path | None = None,
    timeout: float = 20,
) -> list[dict]:
    expectations = load_expectations(config_path)
    results = []
    for path in JOURNEY_PATHS:
        response = (
            read_build_response(root_dir, path)
            if root_dir is not None
            else read_http_response(base_url, path, timeout)
        )
        results.append(validate_response(response, expectations[path], base_url))

    for field in ("title", "description", "canonical", "og_url", "sha256"):
        values = [result[field] for result in results]
        if len(set(values)) != len(values):
            raise ContractError(f"journey responses do not have unique {field}: {values}")
    return results


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group()
    source.add_argument(
        "--root-dir",
        type=Path,
        help="built web root for pre-deploy verification",
    )
    source.add_argument("--base-url", default=DEFAULT_BASE_URL, help="live origin to probe")
    parser.add_argument(
        "--public-routes",
        type=Path,
        default=Path("web/seo/public-routes.json"),
    )
    parser.add_argument("--timeout", type=float, default=20)
    args = parser.parse_args(argv)

    try:
        results = run_probe(
            config_path=args.public_routes,
            base_url=args.base_url,
            root_dir=args.root_dir,
            timeout=args.timeout,
        )
    except ContractError as error:
        print(f"static route contract failed: {error}", file=sys.stderr)
        return 1
    print(json.dumps({"ok": True, "routes": results}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
