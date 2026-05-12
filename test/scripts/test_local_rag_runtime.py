import tempfile
import unittest
from pathlib import Path

from scripts.local_rag_runtime import run_rag


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


if __name__ == "__main__":
    unittest.main()
