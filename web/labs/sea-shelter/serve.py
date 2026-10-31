"""Serve the prototype locally with consistent ES module MIME types on Windows."""

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class Handler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, ".mjs": "text/javascript"}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--directory", type=Path, help="Optional generated web root")
    args = parser.parse_args()
    root = (args.directory or Path(__file__).resolve().parents[2]).resolve()
    if not (root / "labs/sea-shelter/index.html").is_file():
        parser.error("directory must contain labs/sea-shelter/index.html")
    handler = partial(Handler, directory=str(root))
    print(f"Open http://127.0.0.1:{args.port}/labs/sea-shelter/index.html", flush=True)
    with ThreadingHTTPServer(("127.0.0.1", args.port), handler) as server:
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass
