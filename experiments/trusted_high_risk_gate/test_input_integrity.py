import hashlib
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

from input_integrity import verify_local_text_diff
from policy import Binding


class InputIntegrityTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='synthetic-review-diff-')
        self.repo = Path(self.tmp.name)
        self.git('init', '-q')
        (self.repo / 'example.txt').write_text('fixture 1\n', encoding='utf-8')
        self.git('add', 'example.txt')
        self.commit('base')
        base = self.git('rev-parse', 'HEAD').decode().strip()
        (self.repo / 'example.txt').write_text('fixture 2\nFIXTURE_SECRET_X\n¥123\n', encoding='utf-8')
        self.git('add', 'example.txt')
        self.commit('head')
        self.binding = Binding('example/app', 123, base, self.git('rev-parse', 'HEAD').decode().strip())
        raw = self.git('diff', '--no-ext-diff', '--no-textconv', '--no-renames', '--unified=40', base + '...HEAD').decode()
        sanitized = re.sub(r'(?:[¥￥$€£]\s*[-+]?\d[\d,.]*|[-+]?\d[\d,.]*\s*円)', '[REDACTED_AMOUNT]', raw.replace('FIXTURE_SECRET_X', '[REDACTED]'))
        self.digest = hashlib.sha256(sanitized.encode()).hexdigest()

    def tearDown(self):
        resolved = self.repo.resolve()
        if resolved.parent != Path(tempfile.gettempdir()).resolve() or not resolved.name.startswith('synthetic-review-diff-'):
            raise RuntimeError('refusing cleanup outside the synthetic fixture directory')
        self.tmp.cleanup()

    def git(self, *args):
        return subprocess.run(['git', '-C', str(self.repo), *args], capture_output=True, check=True).stdout

    def commit(self, message):
        self.git('-c', 'user.name=Synthetic Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', message)

    @staticmethod
    def scope(paths, raw, assets):
        if paths != ['example.txt'] or assets or 'Binary files ' in raw:
            raise ValueError('synthetic scope invalid')

    @staticmethod
    def redact(raw):
        return raw.replace('FIXTURE_SECRET_X', '[REDACTED]'), 1

    def verify(self, paths=None, digest=None, assets=None, binding=None):
        return verify_local_text_diff(self.repo, binding or self.binding, ['example.txt'] if paths is None else paths,
                                      self.digest if digest is None else digest,
                                      [] if assets is None else assets, self.scope, self.redact)

    def test_exact_sanitized_diff_digest_matches(self):
        self.assertTrue(self.verify())
        self.assertFalse(self.verify(digest='0' * 64))

    def test_missing_object_or_incomplete_file_list_fails_closed(self):
        with self.assertRaises(ValueError):
            self.verify(paths=['other.txt'])
        with self.assertRaises(ValueError):
            self.verify(binding=Binding('example/app', 123, 'f' * 40, self.binding.head))

    def test_image_assets_rejected_until_supported(self):
        with self.assertRaises(ValueError):
            self.verify(assets=[{'path': 'image.png'}])


if __name__ == '__main__':
    unittest.main()
