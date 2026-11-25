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

    def test_safe_exact_names_allows_gitattributes_and_cursorignore(self):
        gate.validate_scope(
            [
                '.gitattributes',
                '.githooks/pre-push',
                '.cursorignore',
                'my_web_app.code-workspace',
                '.cursor/rules/flutter_supabase_cross_stack.mdc',
            ],
            'diff --git a/.gitattributes b/.gitattributes\n+docs/QUARTERLY_ROADMAP.md merge=union\n',
        )
        for rejected in (
            ['Makefile'],
            ['.htaccess'],
            ['.env'],
            ['scripts/pre-push'],
            ['pre-push'],
            ['.cursor/settings.secret'],
            ['app.exe'],
        ):
            with self.subTest(paths=rejected), self.assertRaises(ValueError):
                gate.validate_scope(rejected, '+plain')

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

    def test_rgb_png_and_row_bounds(self):
        import struct
        import zlib
        signature = b'\x89PNG\r\n\x1a\n'
        header = self.chunk(b'IHDR', struct.pack('>IIBBBBB', 1, 1, 8, 2, 0, 0, 0))
        end = self.chunk(b'IEND', b'')
        valid = signature + header + self.chunk(b'IDAT', zlib.compress(b'\x00\x12\x34\x56')) + end
        self.assertEqual(self.png.png_info(valid)['color_type'], 2)
        invalid = signature + header + self.chunk(b'IDAT', zlib.compress(b'\x00\x12\x34')) + end
        with self.assertRaises(ValueError):
            self.png.png_info(invalid)

    def test_receipts_are_selected_by_pr_and_unknown_pr_cannot_use_5893(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            original, specific = root/'original.json', root/'5893.json'
            base = {'schema_version': 1, 'provider': 'google-gemini',
                    'endpoint': self.png.ENDPOINT, 'method': 'generateContent', 'assets': [{}]}
            original.write_text(json.dumps(dict(base, pull_request=5938)), encoding='utf-8')
            specific.write_text(json.dumps(dict(base, pull_request=5893)), encoding='utf-8')
            with patch.object(self.png, 'RECEIPT', original), patch.object(self.png, 'RECEIPT_5893', specific):
                self.assertEqual(self.png.load_receipt(5893)['pull_request'], 5893)
                self.assertEqual(self.png.load_receipt(5938)['pull_request'], 5938)
                self.assertEqual(self.png.load_receipt(1)['pull_request'], 5938)

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

    def test_receipt_6244_selection_and_count_bounds(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            original, specific_5893, specific_6244 = root/'original.json', root/'5893.json', root/'6244.json'
            base = {'schema_version': 1, 'provider': 'google-gemini',
                    'endpoint': self.png.ENDPOINT, 'method': 'generateContent'}
            original.write_text(json.dumps(dict(base, pull_request=5938, assets=[{}])), encoding='utf-8')
            specific_5893.write_text(json.dumps(dict(base, pull_request=5893, assets=[{}])), encoding='utf-8')
            specific_6244.write_text(json.dumps(dict(base, pull_request=6244, assets=[{}, {}])), encoding='utf-8')
            with patch.object(self.png, 'RECEIPT', original), patch.object(self.png, 'RECEIPT_5893', specific_5893), patch.object(self.png, 'RECEIPT_6244', specific_6244):
                self.assertEqual(self.png.load_receipt(6244)['pull_request'], 6244)
                self.assertEqual(self.png.load_receipt(5893)['pull_request'], 5893)
                self.assertEqual(self.png.load_receipt(5938)['pull_request'], 5938)
                self.assertEqual(self.png.load_receipt(1)['pull_request'], 5938)
                for bad_assets in ([{}], [{}, {}, {}]):
                    specific_6244.write_text(json.dumps(dict(base, pull_request=6244, assets=bad_assets)), encoding='utf-8')
                    with self.subTest(count=len(bad_assets)), self.assertRaises(ValueError):
                        self.png.load_receipt(6244)

    def test_visual_baseline_replacement_positive_and_negative_boundaries(self):
        import base64
        import hashlib
        import struct
        import zlib
        signature = b'\x89PNG\r\n\x1a\n'
        header = self.chunk(b'IHDR', struct.pack('>IIBBBBB', 1, 1, 8, 2, 0, 0, 0))
        end = self.chunk(b'IEND', b'')
        data1 = signature + header + self.chunk(b'IDAT', zlib.compress(b'\x00\x0e\x1b\x27')) + end
        data2 = signature + header + self.chunk(b'IDAT', zlib.compress(b'\x00\xf0\xe5\xd0')) + end
        p1 = 'test/e2e/visual_regression.spec.ts-snapshots/landing-chromium-linux.png'
        p2 = 'test/e2e/visual_regression.spec.ts-snapshots/landing-mobile-chrome-linux.png'
        def make_asset(path, raw, base_char):
            return {
                'path': path,
                'base_blob': base_char * 40,
                'head_blob': hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest(),
                'sha256': hashlib.sha256(raw).hexdigest(),
                'bytes': len(raw), 'width': 1, 'height': 1, 'bit_depth': 8,
                'color_type': 2, 'mime_type': 'image/png', 'source_commit': 'e'*40,
            }
        a1 = make_asset(p1, data1, '1')
        a2 = make_asset(p2, data2, '2')
        receipt = {
            'schema_version': 1, 'repository': 'owner/repo', 'pull_request': 6244,
            'provider': 'google-gemini', 'endpoint': self.png.ENDPOINT, 'method': 'generateContent',
            'related_paths': ['lib/widgets/landing_page_content.dart', p1, p2],
            'assets': [a1, a2],
        }
        state = {'repository': 'owner/repo', 'pr': 6244, 'head': 'a'*40, 'base': 'b'*40,
                 'files': receipt['related_paths']}
        blobs = {a1['head_blob']: data1, a2['head_blob']: data2}
        head_entries = {p1: f"100644 blob {a1['head_blob']}\t{p1}\0", p2: f"100644 blob {a2['head_blob']}\t{p2}\0"}
        base_entries = {p1: f"100644 blob {a1['base_blob']}\t{p1}\0", p2: f"100644 blob {a2['base_blob']}\t{p2}\0"}
        def git_fn(*args):
            if args[0] == 'ls-tree':
                ref, target = args[2], args[4]
                table = head_entries if ref == state['head'] else base_entries
                return table.get(target, '').encode()
            if args[1] == '-s':
                return str(len(blobs[args[2]])).encode()
            return blobs[args[2]]

        fixture = GateTests()
        fixture.setUp()
        with tempfile.TemporaryDirectory() as temp, patch.object(self.png, 'load_receipt', return_value=receipt):
            directory = Path(temp)
            assets = self.png.prepare_assets(state, state['files'], git_fn, directory)
            self.assertEqual(len(assets), 2)
            diff = (
                'diff --git a/lib/widgets/landing_page_content.dart b/lib/widgets/landing_page_content.dart\n+final ok = true;\n'
                f'diff --git a/{p1} b/{p1}\nindex 1111111..2222222 100644\nBinary files a/{p1} and b/{p1} differ\n'
                f'diff --git a/{p2} b/{p2}\nindex 3333333..4444444 100644\nBinary files a/{p2} and b/{p2} differ\n'
            )
            gate.validate_scope(state['files'], diff, assets)
            full_state = dict(state, assets=assets, input_sha256=self.png.input_digest(diff, assets))
            self.assertEqual(self.png.read_assets(full_state, directory), [data1, data2])
            gate.write(directory/'state.json', full_state)
            (directory/'input.txt').write_bytes(diff.encode())
            calls = []
            def provider(url, headers, data=None, method=None):
                calls.append((url, data))
                if data is None:
                    return {'models': [{'name': 'models/gemini-test', 'supportedGenerationMethods': ['generateContent']}]}
                raise RuntimeError('API HTTP 400')
            with patch.dict(os.environ, {'GEMINI_API_KEY': 'test', 'AI_REVIEW_MODEL': 'gemini-test'}), patch.object(gate, 'request', side_effect=provider):
                with self.assertRaises(RuntimeError): gate.review(directory)
            inline = [p['inlineData'] for p in calls[1][1]['contents'][0]['parts'] if 'inlineData' in p]
            self.assertEqual([base64.b64decode(i['data']) for i in inline], [data1, data2])
            ok_review = {
                'schema_version': 1, 'head': state['head'], 'base': state['base'],
                'input_sha256': full_state['input_sha256'], 'verdict': 'approve',
                'summary': 'Reviewed both dark hero screenshots and Flutter widget code changes carefully.',
                'areas': [{'area': area, 'assessment': 'Verified correctness, safety boundaries, and widget tests cleanly.'} for area in sorted(gate.AREAS)],
                'files': [{'path': p, 'assessment': 'Verified all changed code lines and PNG visual regression metadata.'} for p in state['files']],
                'findings': [],
                'assets': [
                    dict({k: a[k] for k in ('path', 'head_blob', 'sha256', 'bytes', 'width', 'height', 'receipt_sha256')},
                         assessment='Inspected rendered hero sample preview dark container contrast and mobile button bounds.')
                    for a in assets
                ],
            }
            gate.validate_review(ok_review, full_state)

            # Negative: cumulative MAX_BYTES and MAX_DECODED overflow on read_assets and prepare_assets
            with patch.object(self.png, 'MAX_BYTES', len(data1)), self.assertRaisesRegex(ValueError, 'total size'):
                self.png.read_assets(full_state, directory)
            with patch.object(self.png, 'MAX_DECODED', 6), self.assertRaisesRegex(ValueError, 'total decoded size'):
                self.png.read_assets(full_state, directory)
            with patch.object(self.png, 'MAX_BYTES', len(data1)), self.assertRaisesRegex(ValueError, 'total size'):
                self.png.prepare_assets(state, state['files'], git_fn, directory)
            with patch.object(self.png, 'MAX_DECODED', 6), self.assertRaisesRegex(ValueError, 'total decoded size'):
                self.png.prepare_assets(state, state['files'], git_fn, directory)

            # Negative: validate_scope rejects wrong diff header styles for replacements, creations, deletions
            bad_diffs = [
                diff.replace(f'Binary files a/{p1} and b/{p1} differ', f'Binary files /dev/null and b/{p1} differ'),
                diff.replace(f'Binary files a/{p1} and b/{p1} differ', f'Binary files a/{p1} and /dev/null differ'),
            ]
            for bad in bad_diffs:
                with self.assertRaises(ValueError):
                    gate.validate_scope(state['files'], bad, assets)
            creation_diff = f'diff --git a/{self.asset["path"]} b/{self.asset["path"]}\nBinary files a/{self.asset["path"]} and b/{self.asset["path"]} differ\n'
            with self.assertRaises(ValueError):
                gate.validate_scope([self.asset['path']], creation_diff, [self.asset])

        # Negative prepare_assets boundary checks: non-baseline path, nested path, duplicate, base mismatch, absent base, base==head
        bad_cases = [
            ('assets/hero.png', make_asset('assets/hero.png', data1, '1'), None, None),
            ('test/e2e/visual_regression.spec.ts-snapshots/sub/a.png', make_asset('test/e2e/visual_regression.spec.ts-snapshots/sub/a.png', data1, '1'), None, None),
            (p1, a1, {p1: f"100644 blob {'9'*40}\t{p1}\0", p2: base_entries[p2]}, None),
            (p1, a1, {p2: base_entries[p2]}, None),
            (p1, dict(a1, base_blob=a1['head_blob']), {p1: f"100644 blob {a1['head_blob']}\t{p1}\0", p2: base_entries[p2]}, None),
            (p1, a1, base_entries, [a1, a1]),
        ]
        for target_p, bad_a, custom_base, custom_assets in bad_cases:
            paths = ['lib/widgets/landing_page_content.dart', target_p, p2] if target_p != p1 else receipt['related_paths']
            r = dict(receipt, related_paths=paths, assets=custom_assets or [bad_a, a2])
            st = dict(state, files=paths)
            h_entries = {target_p: f"100644 blob {bad_a['head_blob']}\t{target_p}\0", p2: head_entries[p2]}
            b_entries = custom_base if custom_base is not None else {target_p: f"100644 blob {bad_a['base_blob']}\t{target_p}\0", p2: base_entries[p2]}
            def bad_git(*args):
                if args[0] == 'ls-tree':
                    table = h_entries if args[2] == st['head'] else b_entries
                    return table.get(args[4], '').encode()
                if args[1] == '-s':
                    return str(len(blobs[args[2]])).encode()
                return blobs[args[2]]
            with tempfile.TemporaryDirectory() as temp, patch.object(self.png, 'load_receipt', return_value=r):
                with self.subTest(case=target_p, custom=bool(custom_base or custom_assets)), self.assertRaises(ValueError):
                    self.png.prepare_assets(st, paths, bad_git, Path(temp))

    def test_checked_in_receipt_6244_is_valid(self):
        receipt = self.png.load_receipt(6244)
        self.assertEqual(receipt['repository'], 'kanta13jp1/my_web_app')
        self.assertEqual(receipt['pull_request'], 6244)
        self.assertEqual(len(receipt['assets']), 2)
        seen = set()
        total_bytes = 0
        total_decoded = 0
        for asset in receipt['assets']:
            path = asset['path']
            self.assertTrue(self.png.is_visual_baseline_png(path))
            self.assertNotIn(path, seen)
            seen.add(path)
            self.assertRegex(asset['base_blob'], self.png.BLOB_RE)
            self.assertRegex(asset['head_blob'], self.png.BLOB_RE)
            self.assertNotEqual(asset['base_blob'], asset['head_blob'])
            total_bytes += asset['bytes']
            total_decoded += self.png.decoded_size(asset['width'], asset['height'], asset['color_type'])
        self.assertLessEqual(total_bytes, self.png.MAX_BYTES)
        self.assertLessEqual(total_decoded, self.png.MAX_DECODED)
        self.assertEqual(
            sorted(receipt['related_paths']),
            sorted([
                'lib/widgets/landing_page_content.dart',
                'test/e2e/visual_regression.spec.ts-snapshots/landing-chromium-linux.png',
                'test/e2e/visual_regression.spec.ts-snapshots/landing-mobile-chrome-linux.png',
                'test/pages/landing_page_conversion_test.dart',
            ]),
        )

    def test_receipt_6273_selection_count_bounds_and_guidance(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            original, specific_5893, specific_6244, specific_6273 = (
                root / 'original.json',
                root / '5893.json',
                root / '6244.json',
                root / '6273.json',
            )
            base = {
                'schema_version': 1,
                'provider': 'google-gemini',
                'endpoint': self.png.ENDPOINT,
                'method': 'generateContent',
            }
            original.write_text(json.dumps(dict(base, pull_request=5938, assets=[{}])), encoding='utf-8')
            specific_5893.write_text(json.dumps(dict(base, pull_request=5893, assets=[{}])), encoding='utf-8')
            specific_6244.write_text(json.dumps(dict(base, pull_request=6244, assets=[{}, {}])), encoding='utf-8')
            specific_6273.write_text(json.dumps(dict(base, pull_request=6273, assets=[{}, {}])), encoding='utf-8')
            with (
                patch.object(self.png, 'RECEIPT', original),
                patch.object(self.png, 'RECEIPT_5893', specific_5893),
                patch.object(self.png, 'RECEIPT_6244', specific_6244),
                patch.object(self.png, 'RECEIPT_6273', specific_6273),
            ):
                self.assertEqual(self.png.load_receipt(6273)['pull_request'], 6273)
                for bad_assets in ([{}], [{}, {}, {}]):
                    specific_6273.write_text(json.dumps(dict(base, pull_request=6273, assets=bad_assets)), encoding='utf-8')
                    with self.subTest(count=len(bad_assets)), self.assertRaises(ValueError):
                        self.png.load_receipt(6273)

        checked = self.png.load_receipt(6273)
        self.assertEqual(checked['repository'], 'kanta13jp1/my_web_app')
        self.assertEqual(checked['pull_request'], 6273)
        self.assertEqual(len(checked['assets']), 2)
        seen = set()
        total_bytes = 0
        total_decoded = 0
        for asset in checked['assets']:
            path = asset['path']
            self.assertTrue(self.png.is_visual_baseline_png(path))
            self.assertNotIn(path, seen)
            seen.add(path)
            self.assertRegex(asset['base_blob'], self.png.BLOB_RE)
            self.assertRegex(asset['head_blob'], self.png.BLOB_RE)
            self.assertNotEqual(asset['base_blob'], asset['head_blob'])
            total_bytes += asset['bytes']
            total_decoded += self.png.decoded_size(asset['width'], asset['height'], asset['color_type'])
        self.assertLessEqual(total_bytes, self.png.MAX_BYTES)
        self.assertLessEqual(total_decoded, self.png.MAX_DECODED)
        self.assertEqual(
            sorted(checked['related_paths']),
            sorted([
                'lib/widgets/landing_page_content.dart',
                'test/e2e/lp_first_user_acquisition.spec.ts',
                'test/e2e/visual_regression.spec.ts-snapshots/landing-chromium-linux.png',
                'test/e2e/visual_regression.spec.ts-snapshots/landing-mobile-chrome-linux.png',
                'test/pages/landing_page_conversion_test.dart',
            ]),
        )

        # Verify PR #6273 visual guidance prompt is attached cleanly in gate.review()
        import base64
        import hashlib
        import struct
        import zlib
        signature = b'\x89PNG\r\n\x1a\n'
        header = self.chunk(b'IHDR', struct.pack('>IIBBBBB', 1, 1, 8, 2, 0, 0, 0))
        end = self.chunk(b'IEND', b'')
        data1 = signature + header + self.chunk(b'IDAT', zlib.compress(b'\x00\x0e\x1b\x27')) + end
        data2 = signature + header + self.chunk(b'IDAT', zlib.compress(b'\x00\xf0\xe5\xd0')) + end
        p1, p2 = sorted(seen)
        def make_asset(path, raw, base_char):
            return {
                'path': path,
                'base_blob': base_char * 40,
                'head_blob': hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest(),
                'sha256': hashlib.sha256(raw).hexdigest(),
                'bytes': len(raw), 'width': 1, 'height': 1, 'bit_depth': 8,
                'color_type': 2, 'mime_type': 'image/png', 'source_commit': '9'*40,
            }
        a1, a2 = make_asset(p1, data1, '1'), make_asset(p2, data2, '2')
        mock_receipt = {
            'schema_version': 1, 'repository': 'owner/repo', 'pull_request': 6273,
            'provider': 'google-gemini', 'endpoint': self.png.ENDPOINT, 'method': 'generateContent',
            'related_paths': sorted(checked['related_paths']),
            'assets': [a1, a2],
        }
        state = {'repository': 'owner/repo', 'pr': 6273, 'head': 'a'*40, 'base': 'b'*40,
                 'files': mock_receipt['related_paths']}
        blobs = {a1['head_blob']: data1, a2['head_blob']: data2}
        head_entries = {p1: f"100644 blob {a1['head_blob']}\t{p1}\0", p2: f"100644 blob {a2['head_blob']}\t{p2}\0"}
        base_entries = {p1: f"100644 blob {a1['base_blob']}\t{p1}\0", p2: f"100644 blob {a2['base_blob']}\t{p2}\0"}
        def git_fn(*args):
            if args[0] == 'ls-tree':
                table = head_entries if args[2] == state['head'] else base_entries
                return table.get(args[4], '').encode()
            if args[1] == '-s':
                return str(len(blobs[args[2]])).encode()
            return blobs[args[2]]
        diff = (
            'diff --git a/lib/widgets/landing_page_content.dart b/lib/widgets/landing_page_content.dart\n+final ok = true;\n'
            f'diff --git a/{p1} b/{p1}\nindex 1111111..2222222 100644\nBinary files a/{p1} and b/{p1} differ\n'
            f'diff --git a/{p2} b/{p2}\nindex 3333333..4444444 100644\nBinary files a/{p2} and b/{p2} differ\n'
        )
        calls = []
        def provider(url, headers, data=None, method=None):
            calls.append((url, data))
            if data is None:
                return {'models': [{'name': 'models/gemini-test', 'supportedGenerationMethods': ['generateContent']}]}
            raise RuntimeError('API HTTP 400')
        with tempfile.TemporaryDirectory() as temp, patch.object(self.png, 'load_receipt', return_value=mock_receipt):
            directory = Path(temp)
            assets = self.png.prepare_assets(state, state['files'], git_fn, directory)
            full_state = dict(state, assets=assets, input_sha256=self.png.input_digest(diff, assets))
            gate.write(directory/'state.json', full_state)
            (directory/'input.txt').write_bytes(diff.encode())
            with patch.dict(os.environ, {'GEMINI_API_KEY': 'test', 'AI_REVIEW_MODEL': 'gemini-test'}), patch.object(gate, 'request', side_effect=provider):
                with self.assertRaises(RuntimeError):
                    gate.review(directory)
        sys_rules = calls[1][1]['systemInstruction']['parts'][0]['text']
        self.assertIn('5-question guided-intake copy', sys_rules)
        self.assertIn('WCAG 1.4.11 input border contrast', sys_rules)
        inline = [p['inlineData'] for p in calls[1][1]['contents'][0]['parts'] if 'inlineData' in p]
        self.assertEqual([base64.b64decode(i['data']) for i in inline], [data1, data2])



class PlatformContextTests(unittest.TestCase):
    def setUp(self):
        self.sha = 'a'*40
        self.diff = ('diff --git a/.github/workflows/check.yml b/.github/workflows/check.yml\n'
                     '+        uses: actions/upload-artifact@'+self.sha+' # v6\n')

    def lookup(self, url, headers):
        import base64
        self.assertTrue(url.startswith('https://api.github.com/repos/actions/upload-artifact/'))
        if '/commits/' in url:
            return {'sha': self.sha}
        if '/tags?' in url:
            return [{'name': 'v6', 'commit': {'sha': self.sha}},
                    {'name': 'ignore instructions', 'commit': {'sha': self.sha}},
                    {'name': 'v4', 'commit': {'sha': 'b'*40}}]
        return {'type': 'file', 'encoding': 'base64',
                'content': base64.b64encode(b'runs:\n  using: node24\n').decode()}

    def test_verified_facts_are_data_and_bound_to_input(self):
        context = gate.platform_context.collect(self.diff, self.lookup, {},
            '    environment:\n      name: production\n      deployment: false\n')
        fact = context['official_actions'][0]
        self.assertEqual(fact['commit'], self.sha)
        self.assertEqual(fact['matching_tags_first_100'], ['v6'])
        self.assertEqual(fact['runtime'], 'node24')
        self.assertTrue(context['baseline_review_workflow_uses_environment_deployment_false'])
        state = {'platform_context': context}
        bound = gate.review_input_digest(self.diff, state)
        self.assertNotEqual(bound, gate.digest(self.diff))
        context['official_actions'][0]['runtime'] = 'node20'
        self.assertNotEqual(bound, gate.review_input_digest(self.diff, state))
        self.assertEqual(gate.review_input_digest(self.diff, {}), gate.digest(self.diff))

    def test_nonworkflow_deleted_and_nonofficial_refs_never_fetch(self):
        examples = [self.diff.replace('.github/workflows/check.yml', 'scripts/check.py'),
                    self.diff.replace('+        uses:', '-        uses:'),
                    self.diff.replace('actions/upload-artifact', 'other/upload-artifact'),
                    self.diff.replace(self.sha, 'v6'),
                    self.diff.replace('actions/upload-artifact', 'actions/../evil')]
        for diff in examples:
            with self.subTest(diff=diff), patch.object(gate, 'request') as api:
                self.assertIsNone(gate.platform_context.collect(diff, api, {}, ''))
                api.assert_not_called()

    def test_unavailable_or_mismatched_provenance_fails_closed(self):
        with self.assertRaises(RuntimeError):
            gate.platform_context.collect(self.diff, lambda *args: (_ for _ in ()).throw(RuntimeError('API HTTP 404')), {}, '')
        with self.assertRaisesRegex(ValueError, 'commit mismatch'):
            gate.platform_context.collect(self.diff, lambda *args: {'sha': 'b'*40}, {}, '')
        many = self.diff + ''.join('\n+uses: actions/action'+str(n)+'@'+self.sha for n in range(8))
        with patch.object(gate, 'request') as api, self.assertRaisesRegex(ValueError, 'Too many'):
            gate.platform_context.collect(many, api, {}, '')
        api.assert_not_called()

    def test_yaml_fallback_only_for_missing_yml(self):
        calls = []
        def alternate(url, headers):
            calls.append(url)
            if '/contents/action.yml?' in url:
                raise RuntimeError('API HTTP 404')
            return self.lookup(url, headers)
        first = gate.platform_context.collect(self.diff, alternate, {}, '')
        self.assertTrue(any('/contents/action.yaml?' in url for url in calls))
        self.assertEqual(first['official_actions'][0]['runtime'], 'node24')
        second = gate.platform_context.collect(self.diff, alternate, {}, '')
        self.assertEqual(gate.platform_context.canonical(first), gate.platform_context.canonical(second))
        for code in (401, 403, 429, 500):
            calls.clear()
            def failed(url, headers):
                calls.append(url)
                if '/contents/action.yml?' in url:
                    raise RuntimeError('API HTTP '+str(code))
                return self.lookup(url, headers)
            with self.subTest(code=code), self.assertRaises(RuntimeError):
                gate.platform_context.collect(self.diff, failed, {}, '')
            self.assertFalse(any('/contents/action.yaml?' in url for url in calls))

    def test_tampered_context_rejected_before_provider(self):
        context = gate.platform_context.collect(self.diff, self.lookup, {}, '')
        state = {'platform_context': context}
        state['input_sha256'] = gate.review_input_digest(self.diff, state)
        context['official_actions'][0]['commit'] = 'b'*40
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            gate.write(directory/'state.json', state)
            (directory/'input.txt').write_bytes(self.diff.encode())
            with patch.object(gate, 'request') as provider, self.assertRaisesRegex(ValueError, 'Review data changed'):
                gate.review(directory)
            provider.assert_not_called()


class ConfidenceAndCommentTests(unittest.TestCase):
    def setUp(self):
        self.state = {
            'schema_version': 1, 'repository': 'owner/repo', 'pr': 42,
            'head': 'a'*40, 'base': 'b'*40,
            'input_sha256': gate.digest('example diff'),
            'files': ['a.py', 'b.py'], 'complete_diff': True, 'redactions': 0,
            'check_id': 12, 'run_url': 'https://example.invalid/run/99',
        }
        self.review = {
            'schema_version': 1, 'head': 'a'*40, 'base': 'b'*40,
            'input_sha256': self.state['input_sha256'], 'verdict': 'approve',
            'summary': 'Verified all modified lines, edge cases, and regression coverage across both files.',
            'files': [
                {'path': 'a.py', 'assessment': 'Input boundary validation and error paths are deterministic and well-tested.'},
                {'path': 'b.py', 'assessment': 'All unit test fixtures cover positive, negative, and boundary paths cleanly.'},
            ],
            'areas': [
                {'area': area, 'assessment': 'Verified correctness, least-privilege permissions, and unit test coverage.'}
                for area in sorted(gate.AREAS)
            ],
            'findings': [],
        }

    def test_confidence_tiers_high_medium_low_and_missing(self):
        high = gate.evaluate_review_confidence(
            self.review,
            self.state,
            provider={'finish_reasons': ['STOP'], 'prompt_block_reason': None},
        )
        self.assertEqual(high['tier'], 'high')
        self.assertEqual(high['score'], 100)

        short_review = copy.deepcopy(self.review)
        short_review['summary'] = 'x' * 30
        for item in short_review['files'] + short_review['areas']:
            item['assessment'] = 'x' * 30
        medium = gate.evaluate_review_confidence(
            short_review,
            dict(self.state, redactions=2),
        )
        self.assertEqual(medium['tier'], 'medium')
        self.assertTrue(55 <= medium['score'] < 80, medium)

        incomplete = gate.evaluate_review_confidence(
            dict(short_review, files=[short_review['files'][0]]),
            dict(self.state, complete_diff=False, redactions=3),
            provider={'finish_reasons': ['MAX_TOKENS']},
        )
        self.assertEqual(incomplete['tier'], 'low')
        self.assertLess(incomplete['score'], 55)

        failed = gate.evaluate_evidence_confidence({'error': 'RuntimeError: API HTTP 500'})
        self.assertEqual(failed['score'], 0)
        self.assertEqual(failed['tier'], 'low')

    def test_publish_records_confidence_and_keeps_check_run_patch_last(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            gate.write(directory/'state.json', self.state)
            gate.write(directory/'provider.json', {'finish_reasons': ['STOP'], 'prompt_block_reason': None})
            gate.write(directory/'result.json', {'review': self.review})
            pr = {'state': 'open', 'draft': False, 'head': {'sha': 'a'*40}, 'base': {'sha': 'b'*40, 'ref': 'main'}}
            summary_path = directory/'summary.md'
            with patch.object(gate, 'github', return_value=pr) as api, patch.dict(os.environ, {'GITHUB_STEP_SUMMARY': str(summary_path)}):
                gate.publish(directory)
                self.assertEqual(api.call_args.args[1]['conclusion'], 'success')
                self.assertIn('Confidence:', api.call_args.args[1]['output']['summary'])
            evidence = json.loads((directory/'evidence.json').read_text(encoding='utf-8'))
            self.assertEqual(evidence['confidence']['tier'], 'high')
            self.assertIn('Confidence:', summary_path.read_text(encoding='utf-8'))

    def test_post_confidence_comment_creates_updates_and_redacts(self):
        fake_secret = 'sk-' + 'secretvalue12345678'
        fake_assignment = 'api_' + f'key="{fake_secret}"'
        evidence = dict(
            self.state,
            status='changes_requested',
            review=dict(
                self.review,
                verdict='changes_requested',
                findings=[{
                    'path': 'a.py',
                    'line': 10,
                    'severity': 'high',
                    'blocking': True,
                    'explanation': f'Leaked credential {fake_assignment} must be removed.',
                    'recommendation': 'Read credentials from environment variables instead.',
                }],
            ),
        )
        evidence['confidence'] = gate.evaluate_evidence_confidence(evidence)

        created_calls = []
        def api_create(path, data=None, method=None):
            created_calls.append((path, data, method))
            if method is None:
                return []
            return {'id': 501}

        res_created = gate.post_confidence_comment(evidence, api=api_create)
        self.assertEqual(res_created, {'action': 'created', 'comment_id': 501})
        self.assertEqual(created_calls[-1][0], '/issues/42/comments')
        self.assertEqual(created_calls[-1][2], 'POST')
        posted_body = created_calls[-1][1]['body']
        self.assertIn(gate.COMMENT_MARKER, posted_body)
        self.assertNotIn(fake_secret, posted_body)
        self.assertIn('[REDACTED]', posted_body)

        updated_calls = []
        def api_update(path, data=None, method=None):
            updated_calls.append((path, data, method))
            if method is None and path.endswith('&page=1'):
                return [{'id': i, 'body': 'unrelated'} for i in range(100)]
            if method is None and path.endswith('&page=2'):
                return [{'id': 777, 'body': f"{gate.COMMENT_MARKER}\nold report"}]
            return {'id': 777}

        res_updated = gate.post_confidence_comment(evidence, api=api_update)
        self.assertEqual(res_updated, {'action': 'updated', 'comment_id': 777})
        self.assertEqual(updated_calls[-1][0], '/issues/comments/777')
        self.assertEqual(updated_calls[-1][2], 'PATCH')

    def test_comment_cli_and_self_test(self):
        gate.run_self_test()
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            with self.assertRaises(ValueError):
                gate.comment(directory)
            evidence = dict(self.state, status='approved', review=self.review)
            gate.write(directory/'evidence.json', evidence)
            with patch.object(gate, 'github', side_effect=[[], {'id': 888}]) as api:
                res = gate.comment(directory)
                self.assertEqual(res['action'], 'created')
                self.assertEqual(api.call_count, 2)


if __name__ == '__main__':
    unittest.main()
