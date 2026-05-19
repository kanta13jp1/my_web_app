import importlib.util
import tempfile
import unittest
from pathlib import Path


def load_module():
    root = Path(__file__).resolve().parents[2]
    script = root / "scripts" / "knowledge_vault_lint.py"
    spec = importlib.util.spec_from_file_location("knowledge_vault_lint", script)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class KnowledgeVaultLintTest(unittest.TestCase):
    def test_nested_docs_are_link_checked_but_not_orphan_scored(self):
        lint = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            docs = root / "docs"
            root_doc = docs / "ROOT_DOC.md"
            nested_doc = docs / "daily-reports" / "2026-05-18.md"
            nested_doc.parent.mkdir(parents=True)
            root_doc.write_text("# Root Doc\n", encoding="utf-8")
            nested_doc.write_text("# Daily Report\n[[MISSING_TARGET]]\n", encoding="utf-8")

            original_docs_dir = lint.DOCS_DIR
            lint.DOCS_DIR = docs
            try:
                self.assertEqual(lint.detect_orphans([root_doc, nested_doc]), [root_doc])
                self.assertEqual(lint.detect_broken_links([root_doc, nested_doc]), [(nested_doc, "MISSING_TARGET")])
            finally:
                lint.DOCS_DIR = original_docs_dir

    def test_collect_md_files_skips_ingest_drafts(self):
        lint = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            memory = Path(tmp) / "memory"
            draft = memory / "ingest_drafts" / "draft.md"
            curated = memory / "vault" / "curated.md"
            draft.parent.mkdir(parents=True)
            curated.parent.mkdir(parents=True)
            draft.write_text("# Draft\n", encoding="utf-8")
            curated.write_text("# Curated\n", encoding="utf-8")

            self.assertEqual(lint.collect_md_files([memory]), [curated])


if __name__ == "__main__":
    unittest.main()
