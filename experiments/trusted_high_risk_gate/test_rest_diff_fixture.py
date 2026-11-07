import io
import unittest
from copy import deepcopy

from policy import Binding
from rest_diff_fixture import LIMIT, read_capped, synthetic_digest


class ShortReads(io.BytesIO):
    def read(self, size=-1):
        return super().read(min(size, 3))


class PartialThenTimeout:
    def __init__(self):
        self.first = True

    def read(self, size):
        if self.first:
            self.first = False
            return b'partial'
        raise TimeoutError('synthetic read deadline')


class RestDiffFixtureTest(unittest.TestCase):
    def setUp(self):
        self.binding = Binding('example/app', 3, 'a' * 40, 'b' * 40)
        self.pr = {'base': self.binding.base, 'head': self.binding.head, 'changed_files': 1}
        self.files = [{'filename': 'example.txt', 'status': 'modified', 'additions': 1,
                       'deletions': 1, 'patch': '@@ -1,2 +1,2 @@\n same\n-old\n+new'}]

    def digest(self, files=None, after=None):
        return synthetic_digest(self.binding, self.pr, self.files if files is None else files,
                                self.pr if after is None else after)

    def test_stream_cap_and_short_reads(self):
        self.assertEqual(read_capped(ShortReads(b'abcde')), b'abcde')
        self.assertEqual(len(read_capped(io.BytesIO(b'x' * LIMIT))), LIMIT)
        with self.assertRaises(ValueError):
            read_capped(io.BytesIO(b'x' * (LIMIT + 1)))

    def test_domain_is_incompatible_with_existing_producer(self):
        self.assertTrue(self.digest().startswith('experimental-rest-files-v1:'))
        self.assertNotEqual(self.digest(), 'f' * 64)

    def test_partial_response_then_timeout_never_returns_partial_data(self):
        with self.assertRaises(TimeoutError):
            read_capped(PartialThenTimeout())

    def test_reject_changed_binding_missing_or_duplicate_files(self):
        for files, after in [([], self.pr), (self.files * 2, self.pr),
                             (self.files, {**self.pr, 'head': 'c' * 40})]:
            with self.assertRaises(ValueError):
                self.digest(files, after)

    def test_reject_rename_binary_missing_patch_and_truncation(self):
        for changes in [{'status': 'renamed'}, {'patch': None},
                        {'patch': '@@ -1,2 +1,2 @@\n same\n-old'},
                        {'patch': '@@ -1,2 +1,2 @@\n same\n\n-old\n+new'},
                        {'patch': 'Binary files differ'}, {'additions': 2}]:
            files = deepcopy(self.files)
            files[0].update(changes)
            with self.assertRaises(ValueError):
                self.digest(files)

    def test_conservative_file_cap(self):
        self.pr['changed_files'] = 100
        with self.assertRaises(ValueError):
            self.digest(self.files * 100)


if __name__ == '__main__':
    unittest.main()
