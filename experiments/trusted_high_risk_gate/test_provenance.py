import hashlib
import io
import json
import unittest
import zipfile
from copy import deepcopy

from policy import Binding, REQUIRED_AREAS, evaluate
from provenance import attest


class ProvenanceTest(unittest.TestCase):
    def setUp(self):
        self.b = Binding('example/app', 123, 'a' * 40, 'b' * 40)
        self.run = {'id': 44, 'run_attempt': 1, 'event': 'pull_request_target', 'status': 'completed',
                    'conclusion': 'success', 'workflow_id': 7, 'path': '.github/workflows/claude-agent-review.yml',
                    'repository': {'full_name': self.b.repository}, 'head_sha': self.b.head}
        self.check = {'id': 555, 'name': 'AI Review Gate', 'status': 'completed', 'conclusion': 'success',
                      'app': {'id': 15368}, 'head_sha': self.b.head,
                      'external_id': f'ai-review:{self.b.pr}:{self.b.base}:{self.b.head}'}
        self.files = ['supabase/migrations/example.sql']
        self.evidence = {'schema_version': 1, 'repository': self.b.repository, 'pr': self.b.pr, 'base': self.b.base, 'head': self.b.head,
                         'workflow_sha': self.b.base, 'run_id': '44', 'run_attempt': '1', 'check_id': 555,
                         'status': 'approved', 'complete_diff': True, 'input_sha256': 'f' * 64, 'files': self.files,
                         'response_id': 'provider-response-123',
                         'review': {'schema_version': 1, 'head': self.b.head, 'base': self.b.base, 'input_sha256': 'f' * 64,
                                    'files': [{'path': self.files[0], 'assessment': 'Concrete reviewed behavior and verification evidence.'}],
                                    'verdict': 'approve', 'findings': [], 'areas': [
                                        {'area': a, 'assessment': 'Concrete review evidence and implications.'}
                                        for a in REQUIRED_AREAS]}}

    def archive(self, evidence=None):
        buf = io.BytesIO()
        with zipfile.ZipFile(buf, 'w') as z:
            z.writestr('evidence.json', json.dumps(self.evidence if evidence is None else evidence))
        data = buf.getvalue()
        meta = {'name': 'ai-review-44-1', 'expired': False,
                'digest': 'sha256:' + hashlib.sha256(data).hexdigest(),
                'workflow_run': {'id': 44, 'head_sha': self.b.head}}
        return meta, data

    def test_authenticated_review_with_exact_binding_is_accepted(self):
        meta, data = self.archive()
        review = attest(self.b, self.run, self.check, meta, data, 7, self.files)
        self.assertTrue(evaluate(self.b, ['supabase/migrations/example.sql'], '', '', [], review)[0])

    def test_wrong_run_source_or_forged_check_is_rejected(self):
        meta, data = self.archive()
        for field, val in [('event', 'pull_request'), ('workflow_id', 99), ('head_sha', 'c'*40)]:
            bad = deepcopy(self.run)
            bad[field] = val
            with self.assertRaises(ValueError, msg=field):
                attest(self.b, bad, self.check, meta, data, 7, self.files)
        bad = deepcopy(self.check)
        bad['app']['id'] = 999
        with self.assertRaises(ValueError):
            attest(self.b, self.run, bad, meta, data, 7, self.files)

    def test_digest_tampering_wrong_run_and_stale_base_are_rejected(self):
        meta, data = self.archive()
        with self.assertRaises(ValueError):
            attest(self.b, self.run, self.check, meta, data + b'x', 7, self.files)
        bad = deepcopy(meta)
        bad['workflow_run']['id'] = 99
        with self.assertRaises(ValueError):
            attest(self.b, self.run, self.check, bad, data, 7, self.files)
        stale = deepcopy(self.evidence)
        stale['workflow_sha'] = 'c' * 40
        meta, data = self.archive(stale)
        with self.assertRaises(ValueError):
            attest(self.b, self.run, self.check, meta, data, 7, self.files)

    def test_successful_generic_review_is_not_high_risk_review(self):
        generic = deepcopy(self.evidence)
        generic['review']['areas'] = [{'area': a, 'assessment': 'Concrete review evidence and implications.'}
                                      for a in ['correctness', 'security', 'tests']]
        meta, data = self.archive(generic)
        review = attest(self.b, self.run, self.check, meta, data, 7, self.files)
        self.assertFalse(evaluate(self.b, ['lib/services/asset_payroll_snapshot_store.dart'], '', '', [], review)[0])

    def test_missing_per_file_review_and_medium_advice_are_rejected(self):
        for change in ('missing_file', 'nonblocking_medium'):
            bad = deepcopy(self.evidence)
            if change == 'missing_file':
                bad['review']['files'] = []
            else:
                bad['review']['findings'] = [{'blocking': False, 'severity': 'medium'}]
            meta, data = self.archive(bad)
            with self.assertRaises(ValueError, msg=change):
                attest(self.b, self.run, self.check, meta, data, 7, self.files)


if __name__ == '__main__':
    unittest.main()
