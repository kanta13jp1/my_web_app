#!/usr/bin/env python3
"""Serve a Flutter Web build with an index.html fallback for path routes."""

from __future__ import annotations

import argparse
import os
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit


class FlutterSpaRequestHandler(SimpleHTTPRequestHandler):
    """Return index.html when a path URL does not name a built asset."""

    def send_head(self):  # type: ignore[no-untyped-def]
        requested_path = Path(self.translate_path(urlsplit(self.path).path))
        if not requested_path.exists():
            original_path = self.path
            self.path = "/index.html"
            try:
                return super().send_head()
            finally:
                self.path = original_path
        return super().send_head()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", required=True)
    parser.add_argument("--port", type=int, default=7357)
    args = parser.parse_args()

    build_directory = Path(args.directory).resolve(strict=True)
    if not (build_directory / "index.html").is_file():
        parser.error(f"index.html was not found in {build_directory}")

    handler = partial(FlutterSpaRequestHandler, directory=os.fspath(build_directory))
    with ThreadingHTTPServer(("127.0.0.1", args.port), handler) as server:
        server.serve_forever()


if __name__ == "__main__":
    main()
