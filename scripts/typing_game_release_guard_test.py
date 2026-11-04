import copy
import unittest

import typing_game_release_guard as guard


class GuardTest(unittest.TestCase):
    def setUp(self):
        self.head = 'a' * 40
        self.base = 'b' * 40
        self.pr = {'state': 'closed', 'merged': True, 'merge_commit_sha': 'c' * 40,
                   'base': {'ref': 'main', 'sha': self.base},
                   'head': {'sha': self.head, 'repo': {'full_name': guard.REPO}}}
        self.checks = [{'name': name, 'app': {'id': 15368}, 'conclusion': 'success',
                        'output': {'summary': self.head + self.base + 'Result: **approved**.'}}
                       for name in guard.REQUIRED]
        self.checks.append({'name': 'Public E2E stability smoke', 'app': {'id': 15368},
                            'conclusion': 'skipped', 'output': {'summary': ''}})

    def test_real_merged_head_bound_review(self):
        guard.reviewed(self.pr, self.checks, self.head, self.base)

    def test_open_or_moved_source_rejected(self):
        for key, value in [('merged', False), ('state', 'open')]:
            pr = copy.deepcopy(self.pr)
            pr[key] = value
            with self.assertRaises(ValueError):
                guard.reviewed(pr, self.checks, self.head, self.base)
        with self.assertRaises(ValueError):
            guard.reviewed(self.pr, self.checks, 'd' * 40, self.base)

    def test_forged_incomplete_or_wrong_base_review_rejected(self):
        for mutation in ['app', 'result', 'base']:
            checks = copy.deepcopy(self.checks)
            for check in checks:
                if mutation == 'app':
                    check['app']['id'] = 1
                elif mutation == 'result':
                    check['conclusion'] = 'skipped'
                else:
                    check['output']['summary'] = self.head + 'Result: **approved**.'
            with self.assertRaises(ValueError):
                guard.reviewed(self.pr, checks, self.head, self.base)

    def test_latest_failed_check_cannot_reuse_old_success(self):
        checks = copy.deepcopy(self.checks)
        for check in checks:
            check['id'] = 1
        checks.append({'id': 2, 'name': 'Security Check', 'app': {'id': 15368},
                       'conclusion': 'failure', 'output': {'summary': ''}})
        with self.assertRaises(ValueError):
            guard.reviewed(self.pr, checks, self.head, self.base)

    def test_changed_pr_base_rejected(self):
        pr = copy.deepcopy(self.pr)
        pr['base']['sha'] = 'e' * 40
        with self.assertRaises(ValueError):
            guard.reviewed(pr, self.checks, self.head, self.base)

    def test_missing_public_smoke_context_rejected(self):
        checks = [c for c in self.checks if c['name'] != 'Public E2E stability smoke']
        with self.assertRaises(ValueError):
            guard.reviewed(self.pr, checks, self.head, self.base)

    def test_exact_selection_passes(self):
        all_blobs = {p: 'blob' for p in guard.GAME | guard.SUPPORT}
        guard.selection(all_blobs, all_blobs, all_blobs, all_blobs)

    def test_unrelated_file_or_changed_reviewed_blob_rejected(self):
        all_blobs = {p: 'blob' for p in guard.GAME | guard.SUPPORT}
        for paths in [set(all_blobs) | {'pubspec.yaml'}, set(all_blobs) - {'lib/main.dart'}]:
            with self.assertRaises(ValueError):
                guard.selection(paths, all_blobs, all_blobs, all_blobs)
        changed = dict(all_blobs, **{'lib/main.dart': 'other'})
        with self.assertRaises(ValueError):
            guard.selection(all_blobs, changed, all_blobs, all_blobs)

    def test_immutable_sha_validation(self):
        guard.sha(self.head)
        for value in ['main', 'a' * 39, 'A' * 40, 'a' * 40 + '\n']:
            with self.assertRaises(ValueError):
                guard.sha(value)


if __name__ == '__main__':
    unittest.main()
