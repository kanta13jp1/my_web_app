#!/usr/bin/env python3
"""Offline, deterministic tests of the read-only review evidence bridge."""
import copy
import io
import json
import unittest
import zipfile

import ai_review_merge_gate as gate


class ReviewMergeGateTest(unittest.TestCase):
    def setUp(self):
        self.expected = dict(repository='owner/repo', pr=42, head='a'*40, base='b'*40)
        self.root = 'repos/owner/repo'
        self.check = dict(id=7, name=gate.CHECK, external_id='ai-review:42:'+'b'*40+':'+'a'*40,
                          head_sha='a'*40, app={'id': 15368}, status='completed', conclusion='success',
                          output={'summary': '[Machine evidence and run](https://github.com/owner/repo/actions/runs/9)'})
        self.run = dict(id=9, run_attempt=1, workflow_id=12, path=gate.WORKFLOW,
                        repository={'full_name': 'owner/repo'}, event='workflow_dispatch',
                        status='completed', conclusion='success')
        self.evidence = dict(self.expected, workflow_sha='b'*40, run_id='9', run_attempt='1',
                             check_id=7, status='approved', complete_diff=True,
                             response_id='real-provider-response', input_sha256='c'*64,
                             review=dict(verdict='approve', head='a'*40, base='b'*40,
                                         input_sha256='c'*64, findings=[]))
        self.artifact = dict(id=10, name='ai-review-9-1', expired=False, size_in_bytes=1000)
        self.data = {
            self.root+'/pulls/42': dict(state='open', draft=False,
                                       head={'sha': 'a'*40}, base={'ref': 'main', 'sha': 'b'*40}),
            self.root+'/commits/'+'a'*40+'/check-runs?per_page=100&page=1': {'check_runs': [self.check]},
            self.root+'/actions/runs/9': self.run,
            self.root+'/actions/workflows/claude-agent-review.yml': {'id': 12},
            self.root+'/actions/runs/9/artifacts?per_page=100': {'artifacts': [self.artifact]},
        }

    def archive(self, evidence=None, filename='evidence.json'):
        result = io.BytesIO()
        with zipfile.ZipFile(result, 'w', zipfile.ZIP_DEFLATED) as archive:
            archive.writestr(filename, json.dumps(self.evidence if evidence is None else evidence))
        return result.getvalue()

    def observe(self):
        return gate.observe(self.expected, lambda path: copy.deepcopy(self.data[path]),
                            lambda path: self.archive())

    def test_complete_actual_trusted_approval(self):
        self.assertEqual(self.observe(), '9')

    def test_stale_or_unready_pr_is_not_approved(self):
        pr = self.data[self.root+'/pulls/42']
        for key, value in [('state', 'closed'), ('draft', True), ('head', {'sha': 'd'*40}),
                           ('base', {'ref': 'main', 'sha': 'd'*40})]:
            original = copy.deepcopy(pr)
            with self.subTest(key=key), self.assertRaises(ValueError):
                pr[key] = value
                self.observe()
            pr.clear()
            pr.update(original)

    def test_wrong_app_binding_or_own_workflow_check_cannot_approve(self):
        for key, value in [('app', {'id': 1}), ('external_id', None), ('head_sha', 'd'*40)]:
            with self.subTest(key=key):
                original = self.check[key]
                self.check[key] = value
                with self.assertRaises(gate.PendingReview):
                    self.observe()
                self.check[key] = original

    def test_pending_is_distinct_from_rejection(self):
        self.check['status'] = 'in_progress'
        with self.assertRaises(gate.PendingReview):
            self.observe()
        self.check.update(status='completed', conclusion='failure')
        with self.assertRaises(ValueError):
            self.observe()

    def test_newest_bound_review_wins(self):
        earlier = copy.deepcopy(self.check)
        earlier['id'] = 6
        self.check['conclusion'] = 'failure'
        self.data[self.root+'/commits/'+'a'*40+'/check-runs?per_page=100&page=1']['check_runs'].append(earlier)
        with self.assertRaises(ValueError):
            self.observe()

    def test_untrusted_or_failed_workflow_cannot_approve(self):
        for key, value in [('workflow_id', 99), ('path', 'other.yml'), ('event', 'pull_request'),
                           ('repository', {'full_name': 'attacker/repo'}), ('conclusion', 'failure')]:
            with self.subTest(key=key):
                original = self.run[key]
                self.run[key] = value
                with self.assertRaises(ValueError):
                    self.observe()
                self.run[key] = original

    def test_running_workflow_waits_for_artifact(self):
        self.run['status'] = 'in_progress'
        with self.assertRaises(gate.PendingReview):
            self.observe()

    def test_missing_duplicate_expired_wrong_attempt_or_oversized_artifact(self):
        key = self.root+'/actions/runs/9/artifacts?per_page=100'
        for artifacts in [[], [self.artifact, self.artifact], [dict(self.artifact, expired=True)],
                          [dict(self.artifact, name='ai-review-9-2')],
                          [dict(self.artifact, size_in_bytes=gate.LIMIT+1)]]:
            with self.subTest(artifacts=artifacts), self.assertRaises(ValueError):
                self.data[key]['artifacts'] = artifacts
                self.observe()

    def test_evidence_bindings_are_all_required(self):
        for key, value in [('repository', 'other/repo'), ('pr', 43), ('head', 'd'*40),
                           ('base', 'd'*40), ('workflow_sha', 'd'*40), ('run_id', '8'),
                           ('run_attempt', '2'), ('check_id', 8), ('status', 'failed'),
                           ('complete_diff', False), ('response_id', ''), ('input_sha256', '')]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                evidence = copy.deepcopy(self.evidence)
                evidence[key] = value
                gate.verify_evidence(evidence, self.expected, self.check, self.run)

    def test_provider_rejection_mismatch_and_blocking_findings_fail(self):
        for key, value in [('verdict', 'changes_requested'), ('head', 'd'*40),
                           ('base', 'd'*40), ('input_sha256', 'd'*64),
                           ('findings', [{'blocking': True}])]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                evidence = copy.deepcopy(self.evidence)
                evidence['review'][key] = value
                gate.verify_evidence(evidence, self.expected, self.check, self.run)

    def test_archive_paths_and_zip_bombs_are_rejected_without_extraction(self):
        with self.assertRaises(ValueError):
            gate.evidence_from_zip(self.archive(filename='../evidence.json'))
        with self.assertRaises(ValueError):
            gate.evidence_from_zip(self.archive({'padding': 'x'*(gate.LIMIT+1)}))
        with self.assertRaises(ValueError):
            gate.evidence_from_zip(b'x'*(gate.LIMIT+1))

    def test_real_evidence_round_trip(self):
        self.assertEqual(gate.evidence_from_zip(self.archive()), self.evidence)


if __name__ == '__main__':
    unittest.main()
