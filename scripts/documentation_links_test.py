import tempfile
import unittest
from pathlib import Path
from documentation_links import check_links


class LinksTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.source = self.root / "guide.md"
        (self.root / "exists.md").write_text("# Heading", encoding="utf-8")

    def check(self, text):
        self.source.write_text(text, encoding="utf-8")
        return check_links(self.root, self.source)

    def test_existing_and_root_relative_targets(self):
        self.assertEqual(self.check("[ok](exists.md) [root](/exists.md#heading)"), [])

    def test_missing_inline_reference_and_image(self):
        result = self.check("[bad](missing.md) ![img](missing.png) [ref][r]\n\n[r]: absent.md")
        self.assertEqual(len(result), 3)
        self.assertEqual({r["reason"] for r in result}, {"missing_local_target"})

    def test_code_examples_not_links(self):
        self.assertEqual(self.check("`[fake](missing.md)`\n\n```md\n[fake](missing.md)\n```"), [])

    def test_encoded_spaces_and_parent_paths(self):
        (self.root / "space file.md").write_text("text", encoding="utf-8")
        self.assertEqual(self.check("[ok](space%20file.md)"), [])
        self.assertEqual(self.check("[bad](../outside.md)")[0]["reason"], "outside_repository")

    def test_external_private_urls_are_never_fetched(self):
        self.assertEqual(self.check("# Heading\n[external](https://127.0.0.1/private) [mail](mailto:x@example.invalid) [anchor](#heading)"), [])

    def test_missing_anchor_and_repeated_heading(self):
        self.assertEqual(self.check('# Intro\n# Intro\n[ok](#intro-1)'), [])
        self.assertEqual(self.check('[bad](exists.md#absent)')[0]['reason'], 'missing_markdown_anchor')

    def test_unicode_formatted_and_explicit_anchors(self):
        self.assertEqual(self.check('# **日本語** `見出し`!\n[ok](#日本語-見出し)\n<a id="custom"></a>\n[explicit](#custom)'), [])

    def test_code_block_heading_is_not_anchor(self):
        self.assertEqual(self.check('```md\n# Fake\n```\n[bad](#fake)')[0]['reason'], 'missing_markdown_anchor')

    def test_application_routes_are_not_file_links(self):
        self.assertEqual(self.check("[privacy](/privacy) [legal](/tokusho?lang=ja)"), [])
        self.assertEqual(len(self.check("[file](/missing.md)")), 1)

    def test_nested_source_and_source_escape(self):
        folder = self.root / "nested"
        folder.mkdir()
        self.source = folder / "guide.md"
        self.assertEqual(self.check("[ok](../exists.md)"), [])
        with self.assertRaises(ValueError):
            check_links(folder, self.root / "exists.md")


if __name__ == "__main__":
    unittest.main()
