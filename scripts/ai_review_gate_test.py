#!/usr/bin/env python3
"""Security boundaries and provider failures, without model/network calls."""
import copy
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import ai_review_gate as gate


class GateTests(unittest.TestCase):
    def setUp(self):
        self.state = {'schema_version': 1, 'head': 'a'*40, 'base': 'b'*40,
                      'input_sha256': gate.digest('example diff'), 'files': ['a.py'],
                      'pr': 1, 'check_id': 12, 'run_url': 'https://example.invalid/run'}
        self.review = {k: self.state[k] for k in ('schema_version', 'head', 'base', 'input_sha256')}
        self.review.update(verdict='approve', summary='Examined the actual implementation and the changed tests.',
            files=[{'path': 'a.py', 'assessment': 'The changed validation rejects absent and stale review evidence.'}],
            areas=[{'area': area, 'assessment': 'The diff preserves the existing validation and access controls.'} for area in sorted(gate.AREAS)], findings=[])
        self.pr = {'state': 'open', 'draft': False, 'head': {'sha': self.state['head']}, 'base': {'sha': self.state['base'], 'ref': 'main'}}

    def test_complete_review_accepts(self):
        gate.validate_review(self.review, self.state)
        gate.assert_current(self.state, self.pr)

    def test_head_and_base_changes_reject(self):
        for ref in ('head', 'base'):
            changed = copy.deepcopy(self.pr)
            changed[ref]['sha'] = 'c'*40
            with self.assertRaises(ValueError): gate.assert_current(self.state, changed)

    def test_closed_and_draft_reject(self):
        for changed in (dict(self.pr, state='closed'), dict(self.pr, draft=True)):
            with self.assertRaises(ValueError): gate.assert_current(self.state, changed)

    def test_incomplete_or_malformed_review_rejects(self):
        for field, value in [('head', 'c'*40), ('base', 'c'*40), ('input_sha256', 'wrong'),
                             ('files', []), ('areas', []), ('summary', 'LGTM'),
                             ('verdict', 'LGTM'), ('schema_version', True), ('findings', {})]:
            malformed = dict(self.review, **{field: value})
            with self.subTest(field=field), self.assertRaises(ValueError):
                gate.validate_review(malformed, self.state)

    def test_duplicate_coverage_rejects(self):
        malformed = dict(self.review, files=self.review['files']*2)
        with self.assertRaises(ValueError): gate.validate_review(malformed, self.state)

    def test_material_finding_cannot_approve(self):
        finding = {'path': 'a.py', 'line': 1, 'severity': 'high', 'blocking': True,
                   'explanation': 'A missing ownership check exposes other users records.',
                   'recommendation': 'Verify the caller owns each selected record before returning it.'}
        with self.assertRaises(ValueError):
            gate.validate_review(dict(self.review, findings=[finding]), self.state)
        finding['blocking'] = False
        with self.assertRaises(ValueError):
            gate.validate_review(dict(self.review, findings=[finding]), self.state)

    def test_private_binary_oversized_or_unknown_input_rejects(self):
        cases = [(['Attachments/receipt.pdf'], 'private'), (['a.py'], 'Binary files a and b differ'),
                 (['a.py'], 'x'*(gate.MAX_DIFF+1)), (['a.xyz'], 'unknown'),
                 (['a.py'], 'new file mode 120000'), (['a.py']*41, 'too many')]
        cases.append((['a.py'], 'index abc..def 120000'))
        for paths, diff in cases:
            with self.subTest(paths=paths), self.assertRaises(ValueError): gate.validate_scope(paths, diff)

    def test_binary_header_mentioned_in_source_is_not_a_binary_change(self):
        gate.validate_scope(['a.py'], '+message = "Binary files are unsupported"')

    def test_provider_failure_missing_evidence_and_moved_base_publish_failure(self):
        for result_kind in ('missing', 'malformed', 'moved_base', 'changes'):
            with self.subTest(kind=result_kind), tempfile.TemporaryDirectory() as temp:
                directory = Path(temp)
                gate.write(directory/'state.json', self.state)
                current = copy.deepcopy(self.pr)
                if result_kind == 'moved_base': current['base']['sha'] = 'c'*40
                if result_kind != 'missing':
                    review = copy.deepcopy(self.review)
                    if result_kind == 'malformed': review['verdict'] = 'LGTM'
                    if result_kind == 'changes': review['verdict'] = 'changes_requested'
                    gate.write(directory/'result.json', {'review': review})
                with patch.object(gate, 'github', return_value=current) as api, patch.dict(os.environ, {'GITHUB_STEP_SUMMARY': str(directory/'summary')}):
                    with self.assertRaises(ValueError): gate.publish(directory)
                    self.assertEqual(api.call_args.args[1]['conclusion'], 'failure')
                    self.assertNotEqual(json.loads((directory/'evidence.json').read_text())['status'], 'approved')

    def test_provider_http_error_never_creates_result(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            gate.write(directory/'state.json', self.state)
            (directory/'input.txt').write_text('example diff')
            with patch.dict(os.environ, {'GEMINI_API_KEY': 'fake-test-value'}), patch.object(gate, 'request', side_effect=RuntimeError('API HTTP 429')):
                with self.assertRaises(RuntimeError): gate.review(directory)
            self.assertFalse((directory/'result.json').exists())

    def test_incomplete_provider_response_preserves_reason_but_no_verdict(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            gate.write(directory/'state.json', self.state)
            (directory/'input.txt').write_text('example diff')
            models = {'models': [{'name': 'models/gemini-3.8-flash', 'supportedGenerationMethods': ['generateContent']}]}
            response = {'modelVersion': 'verified-model', 'responseId': 'test-response',
                        'candidates': [{'finishReason': 'MAX_TOKENS'}], 'usageMetadata': {'totalTokenCount': 16000}}
            with patch.dict(os.environ, {'GEMINI_API_KEY': 'fake-test-value', 'AI_REVIEW_MODEL': 'gemini-3.8-flash'}), patch.object(gate, 'request', side_effect=[models, response]):
                with self.assertRaisesRegex(ValueError, 'MAX_TOKENS'): gate.review(directory)
            self.assertFalse((directory/'result.json').exists())
            self.assertEqual(json.loads((directory/'provider.json').read_text())['finish_reasons'], ['MAX_TOKENS'])

    def test_redaction_keeps_credentials_out_of_prompt(self):
        text, count = gate.redact_secrets_with_count('api_key="sk-abcdefghijklmnopqrstuvwx"')
        self.assertNotIn('abcdefghijklmnopqrstuvwx', text)
        self.assertGreater(count, 0)


if __name__ == '__main__':
    unittest.main()
