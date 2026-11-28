import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts.local_rag_runtime import enforce_memory_budget, run_rag


class LocalRagRuntimeTest(unittest.TestCase):
    def test_run_rag_returns_citations_without_network(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            model = root / "pleias-rag.gguf"
            docs = root / "lancedb"
            docs.mkdir()
            model.write_text("dummy local model marker", encoding="utf-8")
            (docs / "policy.md").write_text(
                "Offline secure mode answers from local documents only. "
                "External API calls are blocked.",
                encoding="utf-8",
            )

            result = run_rag(
                query="How does offline secure mode answer?",
                model_path=str(model),
                vector_db_path=str(docs),
                engine="pleias-rag",
                memory_limit_mb=8192,
                network_blocked=True,
            )

        self.assertTrue(result["success"])
        self.assertTrue(result["offline_only"])
        self.assertTrue(result["network_blocked"])
        self.assertLessEqual(result["memory_peak_mb"], 8192)
        self.assertEqual(result["citations"][0]["title"], "policy")
        self.assertIn("Sources:", result["text"])

    def test_run_rag_fails_safely_when_model_is_missing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            docs = root / "lancedb"
            docs.mkdir()
            (docs / "manual.md").write_text("local doc", encoding="utf-8")

            result = run_rag(
                query="hello",
                model_path=str(root / "missing.gguf"),
                vector_db_path=str(docs),
                engine="pleias-rag",
                memory_limit_mb=8192,
                network_blocked=True,
            )

        self.assertFalse(result["success"])
        self.assertEqual(result["status"], "missingModel")
        self.assertTrue(result["offline_only"])
        self.assertEqual(result["memory_limit_mb"], 8192)

    def test_enforce_memory_budget_caps_at_8gb_and_bounds_large_docs(self) -> None:
        effective, max_docs, max_chars = enforce_memory_budget(32768)
        self.assertEqual(effective, 8192)
        self.assertGreater(max_docs, 0)
        self.assertGreater(max_chars, 0)

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            model = root / "pleias-rag.gguf"
            docs = root / "lancedb"
            docs.mkdir()
            model.write_text("dummy local model marker", encoding="utf-8")
            (docs / "large.md").write_text(
                "secure offline data " * 5000,
                encoding="utf-8",
            )

            result = run_rag(
                query="secure offline data",
                model_path=str(model),
                vector_db_path=str(docs),
                engine="pleias-rag",
                memory_limit_mb=32768,
                network_blocked=True,
            )

        self.assertTrue(result["success"])
        self.assertEqual(result["memory_limit_mb"], 8192)
        self.assertTrue(result["memory_guard_passed"])
        self.assertGreaterEqual(result["truncated_docs"], 1)

    def test_run_rag_rejects_when_peak_exceeds_8gb_limit(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            model = root / "pleias-rag.gguf"
            docs = root / "lancedb"
            docs.mkdir()
            model.write_text("dummy local model marker", encoding="utf-8")
            (docs / "doc.md").write_text("local doc", encoding="utf-8")

            with patch(
                "scripts.local_rag_runtime.tracemalloc.get_traced_memory",
                return_value=(1024, 9000 * 1024 * 1024),
            ):
                result = run_rag(
                    query="local",
                    model_path=str(model),
                    vector_db_path=str(docs),
                    engine="pleias-rag",
                    memory_limit_mb=8192,
                    network_blocked=True,
                )

        self.assertFalse(result["success"])
        self.assertEqual(result["status"], "memoryLimitExceeded")
        self.assertEqual(result["memory_limit_mb"], 8192)
        self.assertFalse(result["memory_guard_passed"])


if __name__ == "__main__":
    unittest.main()
