"""Serve a built Flutter Web app with history-route fallback for E2E tests."""

from __future__ import annotations

import argparse
import http.server
import os
from pathlib import Path
from urllib.parse import urlparse


class SpaRequestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self) -> None:  # noqa: N802 - inherited HTTP method name.
        requested_path = urlparse(self.path).path
        if requested_path not in ('', '/') and not Path(
            requested_path.lstrip('/'),
        ).exists():
            self.path = '/index.html'
        super().do_GET()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('directory', type=Path)
    parser.add_argument('--port', type=int, default=7358)
    args = parser.parse_args()
    os.chdir(args.directory)
    server = http.server.ThreadingHTTPServer(
        ('127.0.0.1', args.port),
        SpaRequestHandler,
    )
    server.serve_forever()


if __name__ == '__main__':
    main()
