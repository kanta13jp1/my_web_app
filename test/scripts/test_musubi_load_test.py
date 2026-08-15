import importlib.util
import json
import sys
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


SCRIPT = Path(__file__).parents[2] / "scripts" / "musubi_load_test.py"
SPEC = importlib.util.spec_from_file_location("musubi_load_test", SCRIPT)
assert SPEC and SPEC.loader
musubi = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = musubi
SPEC.loader.exec_module(musubi)


class _Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b"[]")

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        if length:
            json.loads(self.rfile.read(length))
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b"[]")

    def log_message(self, *_args):
        return


class MusubiLoadTest(unittest.TestCase):
    def test_mixed_plan_is_bounded_and_repeatable(self):
        plan = musubi.build_plan("mixed", 12, "地域")
        self.assertEqual(len(plan), 12)
        self.assertEqual(plan[0].name, "timeline")
        self.assertEqual(plan[1].name, "search")
        with self.assertRaises(ValueError):
            musubi.build_plan("mixed", 10_001, "地域")

    def test_percentile_uses_nearest_rank(self):
        self.assertEqual(musubi.percentile([10, 20, 30, 40], 0.95), 40)
        self.assertEqual(musubi.percentile([], 0.95), 0)

    def test_executes_parallel_requests_against_local_stub(self):
        server = ThreadingHTTPServer(("127.0.0.1", 0), _Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)

        plan = musubi.build_plan("mixed", 10, "地域")
        results = musubi.run_load(
            f"http://127.0.0.1:{server.server_port}",
            plan,
            concurrency=4,
            api_key="local-test-key",
            auth_token="local-test-token",
            timeout_seconds=2,
        )
        report = musubi.summarize(results)

        self.assertEqual(report["requests"], 10)
        self.assertEqual(report["failures"], 0)
        self.assertEqual(report["error_rate"], 0)
        self.assertGreaterEqual(report["p95_ms"], 0)


if __name__ == "__main__":
    unittest.main()
