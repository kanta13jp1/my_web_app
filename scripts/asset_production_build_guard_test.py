"""Standard-library offline fixtures; never runs Git/API/auth/SDK/build subprocesses."""
import contextlib
import hashlib
import io
import json
import os
from pathlib import Path
import re
import runpy
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / 'scripts/asset_production_build_guard.py'
WORKFLOW = ROOT / '.github/workflows/asset-production-config-build-only.yml'
ASSETS = ROOT / 'docs/asset-release-build-only/approved-assets'


@contextlib.contextmanager
def tiny_workspace():
    base = Path(tempfile.gettempdir()).resolve()
    temporary = tempfile.TemporaryDirectory(prefix='asset_build_guard_test_')
    root = Path(temporary.name).resolve()
    def checked():
        if root.parent != base or not root.name.startswith('asset_build_guard_test_'):
            raise RuntimeError('unsafe fixture cleanup target')
    checked()
    try:
        yield root
    finally:
        checked()  # Exact resolved parent/prefix verified before recursive cleanup.
        temporary.cleanup()


class BuildOnlyGuardTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.module = runpy.run_path(str(TARGET), run_name='offline_build_guard_tests')

    def values(self):
        return {'repo': 'kanta13jp1/my_web_app', 'event': 'workflow_dispatch', 'run_id': '123',
                'run_attempt': '1', 'workflow_sha': 'a' * 40, 'expected_controller_sha': 'a' * 40,
                'app_version': '1.0.2279', 'build_number': '5837'}

    def owner(self):
        return {'schema_version': 1, 'repo': self.module['REPO'], 'source': self.module['SOURCE'],
                'source_tree': self.module['TREE'], 'controller_commit': 'a' * 40,
                'ci_run': 43176832528, 'ci_attempt': 1, 'app_version': '1.0.2279',
                'build_number': '5837', 'approved_for_build': True, 'approved_for_publish': False}

    def validate_owner(self, owner):
        raw = json.dumps(owner, sort_keys=True, separators=(',', ':'))
        return self.module['validate_owner'](raw, hashlib.sha256(raw.encode()).hexdigest(), self.values())

    def bundle(self, parent):
        root = parent / 'web'
        root.mkdir()
        entries = {'index.html': b'<html>fixture</html>', 'main.dart.js': b'compiled fixture',
                   'flutter_bootstrap.js': b'bootstrap fixture',
                   'version.json': self.module['canonical']({'commit': self.module['SOURCE'],
                       'version': '1.0.2279', 'buildNumber': '5837'}),
                   '.well-known/security.txt': b'public fixture', '.meta': b'public hidden fixture'}
        for name, content in entries.items():
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
        return root, entries

    def test_valid_inputs_and_fixed_source(self):
        values = self.values()
        self.assertEqual(self.module['validate_inputs'](values), values)
        self.assertIsNot(self.module['validate_inputs'](values), values)
        self.assertEqual(self.module['SOURCE'], 'fa36e621ea0e445cdfb3b8d145c85184e874685a')
        self.assertEqual(self.module['TREE'], '81d247963dd8e1fd6df0543e3adc2e5acf0caca3')

    def test_bad_runtime_bindings(self):
        for key, value in [('repo', 'other/repo'), ('event', 'push'), ('run_attempt', '2'),
                           ('run_id', ''), ('run_id', '1;echo bad'), ('workflow_sha', 'b' * 40),
                           ('app_version', '1.0.2278'), ('app_version', '01.0.2279'),
                           ('app_version', '1.0.2279;echo bad'), ('build_number', '5836'),
                           ('build_number', str(2**31)), ('build_number', '05837')]:
            with self.subTest(key=key, value=value):
                values = self.values()
                values[key] = value
                with self.assertRaises((ValueError, TypeError)):
                    self.module['validate_inputs'](values)

    def test_owner_is_build_only(self):
        receipt = self.validate_owner(self.owner())
        self.assertTrue(receipt['approved_for_build'])
        self.assertFalse(receipt['approved_for_publish'])

    def test_owner_rejects_binding_or_extra_fields(self):
        for key, value in [('approved_for_build', False), ('approved_for_build', 1),
                           ('approved_for_publish', True), ('ci_run', 43163187295),
                           ('ci_attempt', True), ('controller_commit', 'b' * 40),
                           ('source', 'b' * 40), ('source_tree', 'c' * 40),
                           ('app_version', '2.0.0'), ('build_number', '5838'), ('extra', 'forbidden')]:
            with self.subTest(key=key):
                owner = self.owner()
                owner[key] = value
                with self.assertRaises((ValueError, TypeError)):
                    self.validate_owner(owner)

    def test_owner_hash_and_strict_json(self):
        raw = json.dumps(self.owner())
        with self.assertRaises(ValueError):
            self.module['validate_owner'](raw, '0' * 64, self.values())
        for raw in ('{"x":1,"x":2}', '{"x":NaN}', '{"x":Infinity}'):
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                self.module['strict_json'](raw)

    def test_hidden_inventory_and_configuration_not_emitted(self):
        with tiny_workspace() as parent:
            root, entries = self.bundle(parent)
            inventory = self.module['validate_bundle'](root, self.values())
            self.assertEqual(len(inventory), 6)
            self.assertIn('/.well-known/security.txt', inventory)
            self.assertIn('/.meta', inventory)
            sealed = self.module['seal'](root, self.values(), {'public_client': 'synthetic-do-not-emit'})
            self.assertNotIn('synthetic-do-not-emit', json.dumps(sealed))
            self.assertIn('build_configuration_sha256', sealed)
            self.assertNotIn('configuration_sha256', sealed)
            expected = hashlib.sha256(self.module['canonical']({
                '/' + name: hashlib.sha256(raw).hexdigest() for name, raw in entries.items()})).hexdigest()
            self.assertEqual(sealed['artifact_sha256'], expected)
            self.assertFalse(sealed['publication_allowed'])
            self.assertFalse(sealed['approved_for_publish'])

    def test_bad_manifest_empty_core_and_unsafe_path(self):
        with tiny_workspace() as parent:
            root, _ = self.bundle(parent)
            for name, replacement in [('version.json', b'{}'), ('main.dart.js', b'')]:
                with self.subTest(name=name):
                    path = root / name
                    original = path.read_bytes()
                    path.write_bytes(replacement)
                    with self.assertRaises(ValueError):
                        self.module['validate_bundle'](root, self.values())
                    path.write_bytes(original)
            bad = root / 'unsafe space.txt'
            bad.write_bytes(b'x')
            with self.assertRaises(ValueError):
                self.module['validate_bundle'](root, self.values())
            bad.unlink()
            link = root / 'linked.js'
            try:
                link.symlink_to(root / 'main.dart.js')
            except (OSError, NotImplementedError):
                return  # Other boundary assertions still ran on platforms without symlink rights.
            with self.assertRaises(ValueError):
                self.module['validate_bundle'](root, self.values())

    def test_exact_frozen_assets_and_preflight(self):
        values = self.module['_snapshots'](ASSETS)
        self.assertEqual(set(values), {'catalog.json', 'release-notes.json'})
        self.assertEqual(hashlib.sha256((ASSETS / 'ASSET_HOSTING_PREFLIGHT_V3.py').read_bytes()).hexdigest(),
                         self.module['PREFLIGHT_SHA256'])
        with tiny_workspace() as parent:
            for name, raw in values.items():
                (parent / name).write_bytes(raw)
            (parent / 'catalog.json').write_bytes(b'{}')
            with self.assertRaises(ValueError):
                self.module['_snapshots'](parent)

    def test_virtual_total_capacity_without_large_allocation(self):
        # Patch only this module's read/hash boundaries; no large files or subprocess.
        with tiny_workspace() as parent:
            root, _ = self.bundle(parent)
            virtual = set()
            for number in range(8):
                path = root / ('capacity_' + str(number) + '.bin')
                path.write_bytes(b'tiny fixture')
                virtual.add(path)
            original_lstat, original_read = Path.lstat, Path.read_bytes
            real_hash = hashlib.sha256
            sizes = {path: 25 * 1024 * 1024 for path in virtual}
            class VirtualBytes:
                def __init__(self, size):
                    self.size = size
                def __len__(self):
                    return self.size
            def lstat(path, *args, **kwargs):
                result = original_lstat(path, *args, **kwargs)
                return SimpleNamespace(st_mode=result.st_mode, st_nlink=result.st_nlink,
                                       st_size=sizes[path]) if path in sizes else result
            def read(path):
                return VirtualBytes(sizes[path]) if path in sizes else original_read(path)
            fake_hash = SimpleNamespace(sha256=lambda value: real_hash(b'virtual')
                                       if isinstance(value, VirtualBytes) else real_hash(value))
            globals_ = self.module['validate_bundle'].__globals__
            for path in sorted(virtual)[6:]:
                path.unlink()
                del sizes[path]
            with patch.object(Path, 'lstat', lstat), patch.object(Path, 'read_bytes', read), \
                    patch.dict(globals_, {'hashlib': fake_hash}):
                inventory = self.module['validate_bundle'](root, self.values())
                self.assertGreater(sum(x['bytes'] for x in inventory.values()), 128 * 1024 * 1024)
                self.assertLess(sum(x['bytes'] for x in inventory.values()), 192 * 1024 * 1024)
                one = next(iter(sizes))
                sizes[one] = 33 * 1024 * 1024
                with self.assertRaises(ValueError):
                    self.module['validate_bundle'](root, self.values())
                sizes[one] = 25 * 1024 * 1024
                for path in sorted(virtual)[6:]:
                    path.write_bytes(b'tiny fixture')
                    sizes[path] = 25 * 1024 * 1024
                with self.assertRaises(ValueError):
                    self.module['validate_bundle'](root, self.values())

    def test_cli_owner_failure_precedes_git_network_or_build(self):
        with tiny_workspace() as root:
            env = {'GITHUB_REPOSITORY': 'kanta13jp1/my_web_app', 'GITHUB_EVENT_NAME': 'workflow_dispatch',
                   'GITHUB_RUN_ID': '123', 'GITHUB_RUN_ATTEMPT': '1', 'CONTROLLER_WORKFLOW_SHA': 'a' * 40,
                   'EXPECTED_CONTROLLER_SHA': 'a' * 40, 'APP_VERSION': '1.0.2279', 'BUILD_NUMBER': '5837',
                   'OWNER_RECORD_JSON': 'synthetic-private-marker', 'OWNER_RECORD_SHA256': '0' * 64}
            def forbidden(*args, **kwargs):
                calls.append(True)
                raise AssertionError('Git/network/build boundary unexpectedly reached')
            calls = []
            globals_ = self.module['main'].__globals__
            output = io.StringIO()
            with patch.dict(os.environ, env, clear=True), \
                    patch.dict(globals_, {'verify': forbidden}), \
                    patch('subprocess.run', forbidden), \
                    patch.object(sys, 'argv', ['guard', 'verify', '--control', str(root), '--product', str(root)]), \
                    contextlib.redirect_stdout(output):
                self.assertEqual(self.module['main'](), 2)
            self.assertEqual(calls, [])  # Guard catches exceptions, so raising alone proves nothing.
            self.assertEqual(output.getvalue(), 'build_only_guard:verify:stopped\n')

    def test_cli_system_interrupts_propagate_without_output(self):
        globals_ = self.module['main'].__globals__
        for interrupt in (KeyboardInterrupt, SystemExit):
            with self.subTest(interrupt=interrupt.__name__):
                output = io.StringIO()
                with patch.dict(globals_, {'_runtime': lambda: (_ for _ in ()).throw(interrupt())}), \
                        patch.object(sys, 'argv', ['guard', 'verify', '--control', '.', '--product', '.']), \
                        contextlib.redirect_stdout(output), self.assertRaises(interrupt):
                    self.module['main']()
                self.assertEqual(output.getvalue(), '')

    def test_workflow_manual_readonly_gate_and_public_hidden_upload(self):
        text = WORKFLOW.read_text(encoding='utf-8')
        self.assertRegex(text, r'(?m)^on:\n  workflow_dispatch:\n')
        self.assertNotRegex(text, r'(?m)^  (?:push|pull_request|schedule):')
        self.assertIn('permissions: {}\n', text)
        self.assertIn('    permissions:\n      contents: read\n      actions: read\n', text)
        self.assertIn('cancel-in-progress: false', text)
        self.assertIn('timeout-minutes: 45', text)
        steps = re.split(r'(?m)^      - name: ', text)[1:]
        gate = next(i for i, step in enumerate(steps) if step.startswith('Verify owner'))
        self.assertTrue(all('secrets.' not in step for step in steps[:gate + 1]))
        for run in re.findall(r'(?m)^        run: \|\n((?:          .*\n|\n)*)', text):
            self.assertNotIn('${{ inputs.', run)
        self.assertEqual(text.count('control/scripts/asset_production_build_guard.py'), 3)
        self.assertIn('control/docs/asset-release-build-only/approved-assets/catalog.json', text)
        self.assertIn('uses: ./.github/actions/prepare-sea-shelter-arena', text)
        self.assertIn('include-hidden-files: true', steps[-1])
        self.assertIn('retention-days: 1', steps[-1])
        self.assertIn('            build/web\n', steps[-1])
        self.assertNotIn('FIREBASE_SERVICE_ACCOUNT', text)
        self.assertNotIn('SUPABASE_ACCESS_TOKEN', text)


if __name__ == '__main__':
    unittest.main()
