import unittest
import tempfile
from pathlib import Path
from documentation_quality_gate import collect, new_findings


class DeltaTest(unittest.TestCase):
    def test_old_findings_remain_reported_but_are_not_new(self):
        old = [{'file': 'a.md', 'detail': 'teh ==> the'}]
        self.assertEqual(new_findings(old, old), [])

    def test_new_or_duplicate_occurrences_block(self):
        old = [{'file': 'a.md', 'detail': 'teh ==> the'}]
        self.assertEqual(len(new_findings(old * 2, old)), 1)
        self.assertEqual(len(new_findings([{'file': 'b.md', 'detail': 'teh ==> the'}], old)), 1)

    def test_fixed_findings_do_not_block(self):
        self.assertEqual(new_findings([], [{'reason': 'missing_local_target'}]), [])

    def test_competitor_brand_rows_are_narrowly_excluded(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            file = root / 'docs/competitor-reports/2026-10-27.md'
            file.parent.mkdir(parents=True)
            file.write_text(
                '| Progate | https://prog-8.com | HTTP 200 |\n'
                '| freee 人事労務 | https://www.freee.co.jp/hr/ | HTTP 200 |\n'
                '| Ameba (サイバーエージェント) | https://ameba.jp | HTTP 200 |\n'
                'This is teh documentation.\n', encoding='utf-8')
            findings = collect(root, [file.relative_to(root).as_posix()])
            spelling = [item['detail'] for item in findings if item['kind'] == 'spelling']
            self.assertEqual(spelling, ['teh ==> the'])

    def test_brand_word_in_prose_or_wrong_domain_is_still_reported(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            file = root / 'docs/competitor-reports/2026-10-27.md'
            file.parent.mkdir(parents=True)
            file.write_text('Progate is in prose.\n| freee 人事労務 | https://example.com/hr/ |\n', encoding='utf-8')
            findings = collect(root, [file.relative_to(root).as_posix()])
            spelling = [item['detail'] for item in findings if item['kind'] == 'spelling']
            self.assertIn('Progate ==> Propagate', spelling)
            self.assertIn('freee ==> free', spelling)

    def test_actual_spelling_and_link_detectors(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            file = root / 'fixture.md'
            file.write_text('This documentation is correct.\n', encoding='utf-8')
            self.assertEqual(collect(root, ['fixture.md']), [])
            file.write_text('This is teh documentation. [missing](missing.md)\n', encoding='utf-8')
            self.assertEqual({item['kind'] for item in collect(root, ['fixture.md'])}, {'spelling', 'local_link'})


if __name__ == '__main__':
    unittest.main()
