#!/usr/bin/env python3
"""Render the public Supabase project URL into Flutter's built web shell."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
from urllib.parse import urlparse


PLACEHOLDER = "__SUPABASE_URL__"


def normalize_public_url(raw_url: str) -> str:
    value = raw_url.strip().rstrip("/")
    parsed = urlparse(value)
    is_loopback = parsed.hostname in {"localhost", "127.0.0.1", "::1"}
    if (
        not parsed.hostname
        or parsed.username
        or parsed.password
        or parsed.query
        or parsed.fragment
        or parsed.path not in {"", "/"}
        or (parsed.scheme != "https" and not (parsed.scheme == "http" and is_loopback))
    ):
        raise ValueError("SUPABASE_URL must be an HTTPS origin or a loopback HTTP origin.")
    return value


def render_web_shell(path: Path, raw_url: str) -> int:
    public_url = normalize_public_url(raw_url)
    source = path.read_text(encoding="utf-8")
    replacements = source.count(PLACEHOLDER)
    if replacements == 0:
        raise ValueError(f"{path} does not contain the Supabase URL placeholder.")
    rendered = source.replace(PLACEHOLDER, public_url)
    if PLACEHOLDER in rendered:
        raise ValueError(f"{path} still contains the Supabase URL placeholder.")
    path.write_text(rendered, encoding="utf-8")
    return replacements


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--input",
        type=Path,
        default=Path("build/web/index.html"),
        help="Built Flutter web shell to render.",
    )
    args = parser.parse_args()
    raw_url = os.environ.get("SUPABASE_URL", "")
    if not raw_url.strip():
        parser.error("SUPABASE_URL is required; its value is never printed.")
    replacements = render_web_shell(args.input, raw_url)
    print(f"Rendered public Supabase origin in {args.input} ({replacements} placeholders).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
