import unittest
from copy import deepcopy

from github_observer import Pending, observe, pages
import test_provenance as fixtures


class ObserverTest(unittest.TestCase):
    def setUp(self):
        self.fixture = fixtures.ProvenanceTest()
        self.fixture.setUp()
        f = self.fixture
        self.pr = {'state': 'open', 'draft': False, 'head': {'sha': f.b.head},
                   'base': {'sha': f.b.base, 'ref': 'main'}, 'changed_files': 1,
                   'title': 'review', 'body': '', 'labels': []}
        f.check['output'] = {'summary': f'[Machine evidence](https://github.com/{f.b.repository}/actions/runs/44)'}
        self.artifact, self.archive = f.archive()
        self.artifact['id'] = 77
        self.pr_reads = 0

    def get(self, path):
        f = self.fixture
        if path.endswith('/pulls/123'):
            self.pr_reads += 1
            return deepcopy(self.pr)
        if '/pulls/123/files?' in path:
            return [{'filename': f.files[0]}]
        if '/check-runs?' in path:
            return {'check_runs': [deepcopy(f.check)]}
        if path.endswith('/actions/runs/44'):
            return deepcopy(f.run)
        if path.endswith('/actions/workflows/claude-agent-review.yml'):
            return {'id': 7}
        if '/actions/runs/44/artifacts?' in path:
            return {'artifacts': [deepcopy(self.artifact)]}
        raise AssertionError('unexpected read: ' + path)

    def download(self, path):
        self.assertTrue(path.endswith('/actions/artifacts/77/zip'))
        return self.archive

    def test_full_provenance_path_accepts_only_bound_evidence(self):
        self.assertTrue(observe(self.fixture.b, self.get, self.download)[0])
        self.assertEqual(self.pr_reads, 2)

    def test_changed_pr_after_fetch_fails(self):
        def changed(path):
            result = self.get(path)
            if path.endswith('/pulls/123') and self.pr_reads == 2:
                result['head']['sha'] = 'c' * 40
            return result
        with self.assertRaises(ValueError):
            observe(self.fixture.b, changed, self.download)

    def test_missing_check_is_pending(self):
        def missing(path):
            return {'check_runs': []} if '/check-runs?' in path else self.get(path)
        with self.assertRaises(Pending):
            observe(self.fixture.b, missing, self.download)

    def test_incomplete_file_page_is_fail_closed(self):
        self.pr['changed_files'] = 2
        with self.assertRaises(ValueError):
            observe(self.fixture.b, self.get, self.download)

    def test_pagination_reads_all_pages_and_fails_at_cap(self):
        def get_page(path):
            return {'items': list(range(100)) if path.endswith('page=1') else [100]}
        self.assertEqual(len(pages('repos/example/app/items', 'items', get_page)), 101)
        with self.assertRaises(ValueError):
            pages('repos/example/app/items', 'items', lambda _: {'items': list(range(100))}, 2)


if __name__ == '__main__':
    unittest.main()
