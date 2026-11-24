import io
import json
import os
import socket
import tempfile
import unittest
import urllib.error
import urllib.request
from pathlib import Path
from unittest.mock import patch

sys_path_target = str(Path(__file__).resolve().parent)
import sys

if sys_path_target not in sys.path:
    sys.path.insert(0, sys_path_target)

from extract_url_markdown import (  # noqa: E402
    MAX_BODY_BYTES,
    extract_url_to_markdown,
    html_to_markdown_and_payload,
    main,
    sanitize_embedded_link,
    sanitize_url_for_log,
    validate_https_url,
)


class _FakeHttpResponse:
    def __init__(
        self,
        body: bytes,
        *,
        status: int = 200,
        url: str = "https://docs.example.com/guide",
    ) -> None:
        self._body = body
        self.status = status
        self.url = url

    def read(self, n: int = -1) -> bytes:
        if n < 0:
            return self._body
        return self._body[:n]

    def __enter__(self) -> "_FakeHttpResponse":
        return self

    def __exit__(self, *args: object) -> bool:
        return False


def _public_addrinfo(*_args: object, **_kwargs: object) -> list[tuple[object, ...]]:
    return [
        (socket.AF_INET, socket.SOCK_STREAM, 6, "", ("93.184.216.34", 443)),
    ]


class ExtractUrlMarkdownTest(unittest.TestCase):
    def test_rejects_ssrf_non_https_userinfo_and_private_or_cgnat_ips(self) -> None:
        for bad_url in (
            "http://example.com/docs",
            "javascript:alert(1)",
            "file:///etc/passwd",
            "https://user:pass@example.com/secret",
            "https://localhost/admin",
            "https://service.internal/metrics",
            "https://127.0.0.1/health",
            "https://169.254.169.254/latest/meta-data",
            "https://100.64.0.10/internal",
            "https://[::1]/loopback",
        ):
            with self.subTest(bad_url=bad_url):
                with self.assertRaises(ValueError):
                    validate_https_url(bad_url)

        def fake_private_dns(*_args: object, **_kwargs: object) -> list[tuple[object, ...]]:
            return [
                (socket.AF_INET6, socket.SOCK_STREAM, 6, "", ("::ffff:10.0.0.5", 443, 0, 0)),
            ]

        with patch("socket.getaddrinfo", side_effect=fake_private_dns):
            with self.assertRaises(ValueError):
                validate_https_url("https://rebind.example.com/path")

    def test_sanitize_url_for_log_strips_query_fragment_and_userinfo(self) -> None:
        sanitized = sanitize_url_for_log(
            "https://alice:secret@docs.example.com:8443/v1/export?auth=opaque#top"
        )
        self.assertEqual(sanitized, "https://docs.example.com:8443/v1/export")
        self.assertNotIn("auth=opaque", sanitized)
        self.assertNotIn("alice", sanitized)
        self.assertNotIn("#top", sanitized)

    def test_strips_dangerous_uris_and_converts_html_to_markdown_and_json(self) -> None:
        html = """
        <html>
          <head>
            <title>External Guide</title>
            <meta name="description" content="Concise summary for JSON pipeline." />
            <script>alert("xss")</script>
          </head>
          <body>
            <h1>External Guide</h1>
            <p>See <a href="/docs/api">API Docs</a> or <a href="javascript:alert(1)">Unsafe</a>.</p>
            <h2>Key Highlights</h2>
            <ul>
              <li>First deterministic bullet</li>
              <li>Second insight with <a href="data:text/html,evil">Data URI</a></li>
            </ul>
            <blockquote>Important quote</blockquote>
            <pre>SELECT 1;</pre>
          </body>
        </html>
        """
        self.assertEqual(sanitize_embedded_link("javascript:alert(1)", "https://example.com"), "")
        self.assertEqual(sanitize_embedded_link("data:text/plain,hi", "https://example.com"), "")
        self.assertEqual(
            sanitize_embedded_link("/docs/api", "https://example.com/start"),
            "https://example.com/docs/api",
        )

        payload = html_to_markdown_and_payload(
            html,
            source_url="https://example.com/guide?ref=1",
        )
        self.assertEqual(payload["source_url"], "https://example.com/guide")
        self.assertEqual(payload["title"], "External Guide")
        self.assertEqual(payload["description"], "Concise summary for JSON pipeline.")
        self.assertEqual(payload["extractor_mode"], "stdlib_html")
        self.assertNotIn("javascript:", str(payload["markdown"]))
        self.assertNotIn("data:text/html", str(payload["markdown"]))
        self.assertNotIn("alert(", str(payload["markdown"]))
        self.assertEqual(
            payload["links"],
            [{"text": "API Docs", "url": "https://example.com/docs/api"}],
        )
        self.assertIn("First deterministic bullet", payload["key_points"])
        self.assertGreater(int(payload["word_count"]), 5)

    def test_rejects_oversized_2mib_body_and_blocks_unsafe_redirect(self) -> None:
        oversized = b"x" * (MAX_BODY_BYTES + 1)

        class _FakeOpener:
            def open(self, req: urllib.request.Request, timeout: int = 10) -> _FakeHttpResponse:
                return _FakeHttpResponse(oversized, url=req.full_url)

        with (
            patch("socket.getaddrinfo", side_effect=_public_addrinfo),
            patch("urllib.request.build_opener", return_value=_FakeOpener()),
        ):
            with self.assertRaises(RuntimeError) as ctx:
                extract_url_to_markdown("https://docs.example.com/large?secret=123")
        self.assertIn("exceeded", str(ctx.exception))
        self.assertNotIn("secret=123", str(ctx.exception))

        from extract_url_markdown import _SafeHttpsRedirectHandler

        handler = _SafeHttpsRedirectHandler(max_redirects=2)
        req = urllib.request.Request("https://docs.example.com/start", method="GET")
        with self.assertRaises(ValueError):
            handler.redirect_request(
                req,
                None,
                302,
                "Found",
                {},
                "http://127.0.0.1/admin",
            )

    def test_http_error_raises_runtime_error_with_sanitized_url_and_cli_exits_1(self) -> None:
        err = urllib.error.HTTPError(
            "https://docs.example.com/private?sig=abc",
            403,
            "Forbidden",
            hdrs=None,  # type: ignore[arg-type]
            fp=io.BytesIO(b"Access denied"),
        )

        class _FailOpener:
            def open(self, req: urllib.request.Request, timeout: int = 10) -> object:
                raise err

        stderr_buf = io.StringIO()
        with (
            patch("socket.getaddrinfo", side_effect=_public_addrinfo),
            patch("urllib.request.build_opener", return_value=_FailOpener()),
            patch("sys.stderr", stderr_buf),
        ):
            rc = main(["--url", "https://docs.example.com/private?sig=abc", "--mode", "stdlib_html"])
        self.assertEqual(rc, 1)
        self.assertIn("HTTP 403", stderr_buf.getvalue())
        self.assertIn("https://docs.example.com/private", stderr_buf.getvalue())
        self.assertNotIn("sig=abc", stderr_buf.getvalue())

    def test_env_gated_firecrawl_fallback_extracts_structured_json(self) -> None:
        firecrawl_resp = json.dumps(
            {
                "success": True,
                "data": {
                    "markdown": "# Firecrawl Title\n\n- Alpha point\n\n[Spec](https://spec.example.com/v1)",
                    "metadata": {
                        "title": "Firecrawl Title",
                        "description": "Structured firecrawl output",
                    },
                },
            }
        ).encode("utf-8")

        class _FirecrawlOpener:
            def open(self, req: urllib.request.Request, timeout: int = 10) -> _FakeHttpResponse:
                return _FakeHttpResponse(firecrawl_resp, url=req.full_url)

        with tempfile.TemporaryDirectory() as tmpdir:
            out_file = Path(tmpdir) / "out.json"
            with (
                patch.dict(os.environ, {"FIRECRAWL_API_KEY": "env-placeholder"}, clear=False),
                patch("socket.getaddrinfo", side_effect=_public_addrinfo),
                patch("urllib.request.build_opener", return_value=_FirecrawlOpener()),
            ):
                rc = main(["--url", "https://docs.example.com/spec", "--json-out", str(out_file)])
            self.assertEqual(rc, 0)
            written = json.loads(out_file.read_text(encoding="utf-8"))
            self.assertEqual(written["extractor_mode"], "firecrawl_v1")
            self.assertEqual(written["title"], "Firecrawl Title")
            self.assertEqual(written["key_points"], ["Firecrawl Title", "Alpha point"])
            self.assertEqual(
                written["links"],
                [{"text": "Spec", "url": "https://spec.example.com/v1"}],
            )


if __name__ == "__main__":
    unittest.main()
