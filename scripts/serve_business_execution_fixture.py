"""Serve/verify one loopback-only business execution fixture on an OS port."""

from __future__ import annotations

import argparse
from functools import partial
import http.server
import json
import os
from pathlib import Path
import re
import secrets
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler, ProxyHandler, build_opener

IDENTITY_PATH = "/__business_execution_identity"


class FixtureHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        self.send_header("X-Business-Execution-Fixture", self.server.identity["token"])
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_GET(self) -> None:  # noqa: N802 - HTTP handler API
        if urlsplit(self.path).path == IDENTITY_PATH:
            body = json.dumps(self.server.identity).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        requested = Path(self.translate_path(urlsplit(self.path).path))
        if not requested.exists():
            self.path = "/index.html"
        super().do_GET()


class FixtureServer(http.server.ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, directory: Path, source_sha: str) -> None:
        root = directory.resolve(strict=True)
        if not re.fullmatch(r"[0-9a-f]{40}", source_sha):
            raise ValueError("source_sha must identify the checked-out commit")
        for name in ("index.html", "main.dart.js", "flutter_bootstrap.js"):
            if not (root / name).is_file():
                raise ValueError(f"Missing Flutter fixture artifact: {name}")
        handler = partial(FixtureHandler, directory=str(root))
        # Port 0 is allocated and held by this actual server, with no
        # check-then-release free-port race.
        super().__init__(("127.0.0.1", 0), handler)
        self.identity = {
            "pid": os.getpid(),
            "port": self.server_port,
            "token": secrets.token_urlsafe(32),
            "source_sha": source_sha,
        }


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise RuntimeError("Fixture identity endpoint must not redirect")


def write_ready(server: FixtureServer, path: Path) -> None:
    # Never accept a stale readiness document from an earlier server.
    with path.open("x", encoding="utf-8") as stream:
        json.dump(server.identity, stream)
        stream.write("\n")


def verify_ready(path: Path, expected_pid: int, source_sha: str) -> str:
    identity = json.loads(path.read_text(encoding="utf-8"))
    port = identity.get("port")
    if (
        identity.get("pid") != expected_pid
        or expected_pid <= 0
        or not isinstance(port, int)
        or not 1 <= port <= 65535
        or identity.get("source_sha") != source_sha
        or not re.fullmatch(r"[0-9a-f]{40}", source_sha)
        or not re.fullmatch(r"[A-Za-z0-9_-]{40,64}", identity.get("token", ""))
    ):
        raise ValueError("Invalid fixture readiness identity")
    os.kill(expected_pid, 0)
    # Construct the URL ourselves; no hostname from a file can select production.
    origin = f"http://127.0.0.1:{port}"
    with build_opener(ProxyHandler({}), NoRedirect()).open(
        origin + IDENTITY_PATH, timeout=5,
    ) as response:
        observed = json.load(response)
    if observed != identity:
        raise ValueError("Responding server does not match the started fixture")
    os.kill(expected_pid, 0)
    return origin


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_subparsers(dest="mode", required=True)
    serve = modes.add_parser("serve")
    serve.add_argument("directory", type=Path)
    serve.add_argument("--ready-file", required=True, type=Path)
    serve.add_argument("--source-sha", required=True)
    verify = modes.add_parser("verify")
    verify.add_argument("--ready-file", required=True, type=Path)
    verify.add_argument("--pid", required=True, type=int)
    verify.add_argument("--source-sha", required=True)
    args = parser.parse_args()
    if args.mode == "verify":
        print(verify_ready(args.ready_file, args.pid, args.source_sha))
        return
    server = FixtureServer(args.directory, args.source_sha)
    try:
        write_ready(server, args.ready_file)
        server.serve_forever()
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
