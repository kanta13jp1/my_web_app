from __future__ import annotations

import json
import os
from pathlib import Path
import tempfile
import threading
import unittest
from unittest.mock import patch

from serve_business_execution_fixture import (
    FixtureHandler, FixtureServer, verify_ready, write_ready,
)


class FixtureIdentityTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for name in ("index.html", "main.dart.js", "flutter_bootstrap.js"):
            (self.root / name).write_text("synthetic fixture", encoding="utf-8")
        self.sha = "a" * 40
        self.server = FixtureServer(self.root, self.sha)
        self.thread = threading.Thread(target=self.server.serve_forever)
        self.thread.start()
        self.addCleanup(self.stop_server)
        self.ready = self.root / "ready.json"
        write_ready(self.server, self.ready)

    def stop_server(self) -> None:
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=5)
        self.assertFalse(self.thread.is_alive())

    def test_os_allocated_port_and_exact_pid_nonce_head_are_verified(self) -> None:
        origin = verify_ready(self.ready, os.getpid(), self.sha)
        self.assertEqual(origin, f"http://127.0.0.1:{self.server.server_port}")
        self.assertNotEqual(self.server.server_port, 0)

    def test_responder_with_different_identity_is_rejected(self) -> None:
        identity = json.loads(self.ready.read_text(encoding="utf-8"))
        identity["token"] = "different_nonce_" * 3
        self.ready.write_text(json.dumps(identity), encoding="utf-8")
        with self.assertRaises(ValueError):
            verify_ready(self.ready, os.getpid(), self.sha)

    def test_stale_readiness_wrong_pid_or_head_is_rejected(self) -> None:
        with self.assertRaises(FileExistsError):
            write_ready(self.server, self.ready)
        with self.assertRaises(ValueError):
            verify_ready(self.ready, os.getpid() + 1, self.sha)
        with self.assertRaises(ValueError):
            verify_ready(self.ready, os.getpid(), "b" * 40)

    def test_identity_redirect_is_rejected_without_following_it(self) -> None:
        def redirect(handler: FixtureHandler) -> None:
            handler.send_response(302)
            handler.send_header("Location", "https://example.invalid/production")
            handler.end_headers()

        with patch.object(FixtureHandler, "do_GET", redirect):
            with self.assertRaisesRegex(RuntimeError, "must not redirect"):
                verify_ready(self.ready, os.getpid(), self.sha)

    def test_missing_fixture_cannot_create_a_ready_server(self) -> None:
        (self.root / "main.dart.js").unlink()
        with self.assertRaises(ValueError):
            FixtureServer(self.root, self.sha)


if __name__ == "__main__":
    unittest.main()
