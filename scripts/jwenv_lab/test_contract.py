"""Static checks for the Jwenv lab: vendored engine integrity, pinned model, and no external calls."""
import hashlib
import json
import re
import unittest

from common import FIXTURES, LAB, VENDOR, core_constant, manifest


class VendoredEngine(unittest.TestCase):
    def test_every_vendored_file_matches_the_pinned_upstream(self):
        m = manifest()
        self.assertEqual(m['revision'], core_constant('ENGINE')['revision'])
        self.assertFalse(m['modified'])
        listed = set(m['files'])
        present = {p.relative_to(VENDOR).as_posix() for p in VENDOR.rglob('*') if p.is_file()}
        self.assertEqual(present - {'manifest.json', 'NOTICE.md'}, listed)
        for rel, info in m['files'].items():
            with self.subTest(rel):
                # Git stores LF; a Windows checkout with core.autocrlf=true writes CRLF.
                data = (VENDOR / rel).read_bytes().replace(b'\r\n', b'\n')
                self.assertEqual(hashlib.sha256(data).hexdigest(), info['sha256'])

    def test_notice_keeps_the_mit_permission_notice(self):
        notice = (VENDOR / 'NOTICE.md').read_text(encoding='utf-8')
        self.assertIn('Permission is hereby granted, free of charge', notice)
        self.assertIn(manifest()['revision'], notice)


class PinnedInputs(unittest.TestCase):
    def test_model_is_pinned_by_revision_size_and_sha256(self):
        model = core_constant('MODEL')
        self.assertRegex(model['revision'], r'^[0-9a-f]{40}$')
        self.assertRegex(model['sha256'], r'^[0-9a-f]{64}$')
        self.assertEqual(model['file'], 'jwenv-0.6b-poc-q8_0.gguf')
        self.assertGreater(model['bytes'], 500_000_000)

    def test_expense_domain_matches_the_bert_fixture(self):
        fixtures = json.loads(FIXTURES.read_text(encoding='utf-8'))
        self.assertEqual(core_constant('EXPENSE_DOMAIN'), fixtures['instructions'])


class NoExternalCalls(unittest.TestCase):
    def test_page_loads_only_same_origin_code_and_data(self):
        html = (LAB / 'index.html').read_text(encoding='utf-8')
        for src in re.findall(r'(?:src|href)="([^"]+)"', html):
            self.assertFalse(src.startswith(('http:', 'https:', '//')), f'external resource in page: {src}')
        app = (LAB / 'app.mjs').read_text(encoding='utf-8')
        for arg in re.findall(r'fetch\(([^,)]+)', app):
            self.assertNotRegex(arg.strip(), r"^['\"`]https?:", f'fetch to external URL: {arg}')
        for imp in re.findall(r"from '([^']+)'", app):
            self.assertTrue(imp.startswith('./'), imp)


if __name__ == '__main__':
    unittest.main()
