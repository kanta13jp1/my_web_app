import unittest
from copy import deepcopy
from policy import Binding, REQUIRED_AREAS, evaluate


class TrustedRiskPolicyTest(unittest.TestCase):
    def setUp(self):
        self.b = Binding('example/app', 123, 'a' * 40, 'b' * 40)
        self.paths = ['lib/services/asset_payroll_snapshot_store.dart']
        self.review = {'repository': self.b.repository, 'pr': self.b.pr, 'base': self.b.base, 'head': self.b.head,
                       'verdict': 'approve', 'unresolved': 0,
                       'areas': {a: 'Concrete reviewed behavior and verification evidence.' for a in REQUIRED_AREAS}}

    def decision(self, evidence=None, *, paths=None, body=''):
        return evaluate(self.b, self.paths if paths is None else paths, 'change', body, [], evidence)[0]

    def test_missing_review_and_unsigned_body_exception_are_rejected(self):
        self.assertFalse(self.decision(None, body='Reviewer: Claude Code #1\nHigh-Risk-Ultrareview-Exception: this is a sufficient reason'))

    def test_review_must_match_immutable_head_base_repository_and_pr(self):
        self.assertTrue(self.decision(self.review))
        for field in ('repository', 'pr', 'base', 'head'):
            wrong = deepcopy(self.review)
            wrong[field] = 'other'
            self.assertFalse(self.decision(wrong), field)

    def test_incomplete_perspective_or_unresolved_finding_is_rejected(self):
        for area in REQUIRED_AREAS:
            wrong = deepcopy(self.review)
            del wrong['areas'][area]
            self.assertFalse(self.decision(wrong), area)
        for unresolved in (1, None, False):
            wrong = deepcopy(self.review)
            wrong['unresolved'] = unresolved
            self.assertFalse(self.decision(wrong), unresolved)

    def test_missing_file_data_fails_closed_but_low_risk_can_pass(self):
        self.assertFalse(self.decision(paths=[]))
        self.assertTrue(self.decision(paths=['lib/widgets/simple_text.dart']))

    def test_payroll_risk_cannot_be_removed_by_editing_pr_body(self):
        self.assertFalse(self.decision(None, body=''))

    def test_review_gate_implementation_and_reusable_actions_are_high_risk(self):
        for path in ('scripts/ai_review_gate.py', 'scripts/check_high_risk_ultrareview_gate.py',
                     '.github/actions/paid-ai-policy/action.yml', '.github/workflows/ci.yml',
                     '.github/workflows/ordinary.yaml', 'lib/services/supabase_client_provider.dart',
                     'lib/services/supabase_runtime_config.dart'):
            self.assertFalse(self.decision(None, paths=[path]), path)


if __name__ == '__main__':
    unittest.main()
