"""Resolve generated source links from the concept page directory."""
import re
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import wiki_compile


class ConceptSourceLinkTest(unittest.TestCase):
    def test_sources_resolve_from_concept_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            wiki = root / "docs" / "concepts"
            wiki.mkdir(parents=True)
            sources = [
                root / "docs" / "competitor-reports" / "example.md",
                root / "memory" / "project_example.md",
            ]
            for source in sources:
                source.parent.mkdir(parents=True, exist_ok=True)
                source.write_text("# Fixture", encoding="utf-8")
            with patch.object(wiki_compile, "REPO_ROOT", root), patch.object(
                wiki_compile, "WIKI_DIR", wiki
            ):
                rendered = wiki_compile.render_concept_page(
                    "Fixture", {"competitor": 1, "memory": 1}, sources
                )
            for source in sources:
                label = source.relative_to(root).as_posix()
                match = re.search(
                    r"\[" + re.escape(label) + r"\]\(([^)]+)\)", rendered
                )
                self.assertIsNotNone(match)
                self.assertEqual((wiki / match.group(1)).resolve(), source.resolve())


if __name__ == "__main__":
    unittest.main()
