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

    def test_short_assessments_reject_with_target_and_length(self):
        for collection, label in (('files', 'path'), ('areas', 'area')):
            malformed = copy.deepcopy(self.review)
            item = malformed[collection][0]
            item['assessment'] = ' ' + 'x'*29 + ' '
            with self.subTest(collection=collection), self.assertRaises(ValueError) as raised:
                gate.validate_review(malformed, self.state)
            self.assertIn(collection, str(raised.exception))
            self.assertIn(item[label], str(raised.exception))
            self.assertIn('29 trimmed characters; minimum 30', str(raised.exception))

    def test_thirty_character_assessments_preserve_boundary(self):
        review = copy.deepcopy(self.review)
        for item in review['files'] + review['areas']:
            item['assessment'] = ' ' + 'x'*30 + ' '
        gate.validate_review(review, self.state)

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



    def test_prepare_review_preserves_newlines_and_utf8(self):
        for ending in ('\n', '\r\n', '\r', '\r\n+mixed\n', ''):
            raw = 'diff --git a/a.py b/a.py\n+説明' + ending
            with self.subTest(ending=repr(ending)), tempfile.TemporaryDirectory() as temp:
                directory = Path(temp)
                env = {'PR_NUMBER': '1', 'GITHUB_REPOSITORY': 'example/repo',
                       'GITHUB_SHA': 'd'*40, 'GITHUB_RUN_ID': '1',
                       'GITHUB_RUN_ATTEMPT': '1', 'GITHUB_EVENT_NAME': 'workflow_dispatch',
                       'GEMINI_API_KEY': 'fake-test-value'}
                def git_result(*args):
                    if args[:2] == ('rev-parse', 'HEAD'): return b'd'*40
                    if args[0] == 'rev-parse': return b'a'*40
                    if '--name-only' in args: return b'a.py\0'
                    if args[0] == 'diff': return raw.encode('utf-8')
                    return b''
                with patch.dict(os.environ, env), patch.object(gate, 'github', side_effect=[self.pr, {'id': 12}]), patch.object(gate, 'git', side_effect=git_result):
                    gate.prepare(directory)
                self.assertEqual((directory/'input.txt').read_bytes(), raw.encode('utf-8'))
                state = json.loads((directory/'state.json').read_text(encoding='utf-8'))
                self.assertEqual(state['input_bytes'], len(raw.encode('utf-8')))
                self.assertEqual(state['input_sha256'], gate.digest(raw))
                with patch.dict(os.environ, env), patch.object(gate, 'request', side_effect=RuntimeError('provider reached')) as provider:
                    with self.assertRaisesRegex(RuntimeError, 'provider reached'):
                        gate.review(directory)
                    provider.assert_called_once()

    def test_changed_input_rejects_before_provider_call(self):
        original = 'diff\r\n+説明\r\n'
        for changed in (original.replace('\r\n', '\n'), original + 'x', original[:-1]):
            with self.subTest(changed=repr(changed)), tempfile.TemporaryDirectory() as temp:
                directory = Path(temp)
                gate.write(directory/'state.json', dict(self.state, input_sha256=gate.digest(original)))
                (directory/'input.txt').write_bytes(changed.encode('utf-8'))
                with patch.object(gate, 'request') as provider:
                    with self.assertRaisesRegex(ValueError, 'Review data changed'):
                        gate.review(directory)
                    provider.assert_not_called()
                self.assertFalse((directory/'result.json').exists())


class PublicPngTests(unittest.TestCase):
    def setUp(self):
        import hashlib
        import struct
        import zlib
        self.png = gate.public_png
        self.chunk = lambda kind, body: struct.pack('>I', len(body))+kind+body+struct.pack('>I', zlib.crc32(kind+body) & 0xffffffff)
        self.header = self.chunk(b'IHDR', struct.pack('>IIBBBBB', 1, 1, 8, 6, 0, 0, 0))
        self.data = b'\x89PNG\r\n\x1a\n'+self.header+self.chunk(b'IDAT', zlib.compress(b'\0\xff\0\0\xff'))+self.chunk(b'IEND', b'')
        self.asset = {'path': 'web/labs/sea-shelter/assets/residents-original-v2.png',
            'head_blob': hashlib.sha1(b'blob '+str(len(self.data)).encode()+b'\0'+self.data).hexdigest(),
            'sha256': hashlib.sha256(self.data).hexdigest(), 'bytes': len(self.data),
            'width': 1, 'height': 1, 'bit_depth': 8, 'color_type': 6, 'mime_type': 'image/png',
            'source_commit': 'c'*40}
        self.receipt = {'schema_version': 1, 'repository': 'owner/repo', 'pull_request': 5938,
            'provider': 'google-gemini', 'endpoint': self.png.ENDPOINT, 'method': 'generateContent',
            'related_paths': [self.asset['path'], 'a.py'], 'assets': [self.asset]}
        self.state = {'repository': 'owner/repo', 'pr': 5938, 'head': 'a'*40, 'base': 'b'*40,
            'files': self.receipt['related_paths']}

    def git(self, *args):
        if args[0] == 'ls-tree':
            return (('100644 blob '+self.asset['head_blob']+'\t'+self.asset['path']+'\0').encode()
                    if args[2] == self.state['head'] else b'')
        return str(len(self.data)).encode() if args[1] == '-s' else self.data

    def intake(self, directory):
        return self.png.prepare_assets(self.state, self.state['files'], self.git, directory)

    def test_pinned_pixels_and_receipt_are_bound(self):
        with tempfile.TemporaryDirectory() as temp, patch.object(self.png, 'load_receipt', return_value=self.receipt):
            directory = Path(temp)
            assets = self.intake(directory)
            state = dict(self.state, assets=assets)
            self.assertEqual(self.png.read_assets(state, directory), [self.data])
            self.assertNotEqual(self.png.input_digest('diff', assets), gate.digest('diff'))
            self.assertEqual(self.png.input_digest('diff', []), gate.digest('diff'))
            (directory/'assets'/(assets[0]['sha256']+'.png')).write_bytes(self.data+b'x')
            with self.assertRaises(ValueError): self.png.read_assets(state, directory)

    def test_unknown_scope_and_nonregular_git_modes_fail(self):
        with tempfile.TemporaryDirectory() as temp, patch.object(self.png, 'load_receipt', return_value=self.receipt):
            directory = Path(temp)
            for key, value in [('repository', 'other/repo'), ('pr', 1), ('files', self.state['files']+['secret.py'])]:
                original = self.state[key]
                self.state[key] = value
                with self.assertRaises(ValueError): self.intake(directory)
                self.state[key] = original
            for mode in ('120000', '160000'):
                original = self.git
                def changed(*args):
                    return original(*args).replace(b'100644', mode.encode()) if args[0] == 'ls-tree' else original(*args)
                with self.assertRaises(ValueError):
                    self.png.prepare_assets(self.state, self.state['files'], changed, directory)
            with self.assertRaises(ValueError):
                self.png.prepare_assets(self.state, self.state['files'], lambda *args: b'present', directory)

    def test_corrupt_crc_trailing_data_zip_bomb_and_unknown_chunks_fail(self):
        import struct
        import zlib
        bad_crc = bytearray(self.data)
        bad_crc[30] ^= 1
        oversized = self.chunk(b'IHDR', struct.pack('>IIBBBBB', 100000, 100000, 8, 6, 0, 0, 0))
        cases = [bytes(bad_crc), self.data+b'x', self.data[:-2], b'not PNG',
            self.data[:8]+oversized+self.data[33:],
            self.data[:33]+self.chunk(b'acTL', b'12345678')+self.data[33:],
            self.data[:33]+self.chunk(b'IDAT', zlib.compress(b'\0'*1000))+self.chunk(b'IEND', b''),
            self.data[:33]+self.chunk(b'IDAT', zlib.compress(b'\x05\0\0\0\0'))+self.chunk(b'IEND', b'')]
        for data in cases:
            with self.subTest(size=len(data)), self.assertRaises((ValueError, zlib.error)):
                self.png.png_info(data)
        for key, value in [('sha256', '0'*64), ('head_blob', '0'*40), ('bytes', 1), ('width', 2)]:
            with self.subTest(field=key), self.assertRaises(ValueError):
                self.png.verify_bytes(self.data, dict(self.asset, **{key: value}))

    def test_binary_summary_is_kept_and_only_exact_approved_section_passes(self):
        path = self.asset['path']
        diff = f'diff --git a/{path} b/{path}\nnew file mode 100644\nBinary files /dev/null and b/{path} differ\n'
        gate.validate_scope([path], diff, [self.asset])
        for changed in [diff.replace(path, 'other.png'), diff+'GIT binary patch\n', diff+f'Binary files /dev/null and b/{path} differ\n', diff.replace('Binary files ', '+Binary files ')]:
            with self.assertRaises(ValueError): gate.validate_scope([path], changed, [self.asset])
        with self.assertRaises(ValueError): gate.validate_scope([path], diff)

    def test_missing_or_mismatched_image_assessment_fails(self):
        fixture = GateTests()
        fixture.setUp()
        asset = dict(self.asset, receipt_sha256='d'*64)
        state = dict(fixture.state, assets=[asset])
        result = copy.deepcopy(fixture.review)
        with self.assertRaises(ValueError): gate.validate_review(result, state)
        result['assets'] = [{k: asset[k] for k in ('path', 'head_blob', 'sha256', 'bytes', 'width', 'height', 'receipt_sha256')}]
        result['assets'][0]['assessment'] = 'Inspected the actual RGBA pixels and checked the sprite-cell integration.'
        gate.validate_review(result, state)
        for key, value in [('sha256', 'wrong'), ('bytes', True), ('assessment', 'LGTM')]:
            changed = copy.deepcopy(result)
            changed['assets'][0][key] = value
            with self.assertRaises(ValueError): gate.validate_review(changed, state)

    def test_actual_inline_pixels_sent_and_provider_failure_stays_closed(self):
        fixture = GateTests()
        fixture.setUp()
        with tempfile.TemporaryDirectory() as temp, patch.object(self.png, 'load_receipt', return_value=self.receipt):
            directory = Path(temp)
            assets = self.intake(directory)
            state = dict(self.state, assets=assets, input_sha256=self.png.input_digest('diff', assets))
            gate.write(directory/'state.json', state)
            (directory/'input.txt').write_bytes(b'diff')
            calls = []
            def provider(url, headers, data=None, method=None):
                calls.append((url, data))
                if data is None:
                    return {'models': [{'name': 'models/gemini-test', 'supportedGenerationMethods': ['generateContent']}]}
                raise RuntimeError('API HTTP 400')
            with patch.dict(os.environ, {'GEMINI_API_KEY': 'test', 'AI_REVIEW_MODEL': 'gemini-test'}), patch.object(gate, 'request', side_effect=provider):
                with self.assertRaises(RuntimeError): gate.review(directory)
            import base64
            payload = calls[1][1]
            image = payload['contents'][0]['parts'][-1]['inlineData']
            self.assertEqual(base64.b64decode(image['data']), self.data)
            self.assertEqual(image['mimeType'], 'image/png')
            self.assertEqual(calls[1][0], self.png.ENDPOINT+'models/gemini-test:generateContent')
            self.assertIn('assets', payload['generationConfig']['responseJsonSchema']['required'])
            self.assertFalse((directory/'result.json').exists())


if __name__ == '__main__':
    unittest.main()
