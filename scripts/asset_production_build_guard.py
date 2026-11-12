"""Unapproved BUILD ONLY guard recipe. No Hosting/nonce/publish operations.
Authoring did not import or execute this file. CLI is for a future approved workflow.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import runpy
import stat
import subprocess
import sys

SOURCE = 'fa36e621ea0e445cdfb3b8d145c85184e874685a'
TREE = '81d247963dd8e1fd6df0543e3adc2e5acf0caca3'
PUBLIC = '399586d0eeda65f157819e21a5b2e47409b7e2ba'
REPO = 'kanta13jp1/my_web_app'
CI = 43176832528
PREFLIGHT_SHA256 = '48ffae2687b5f65b8df914cb645a45c326f5d019f4db8e8c7b3c2da926a49055'
SNAPSHOTS = {'catalog.json': '4a352a1063e70ec2f40f1bd5ee80a87b7b22d940100cb1549b4f73dee0ed5a55',
             'release-notes.json': 'daf91e6af1d57e8fc36f572cda520951b26437ab562c5a6f4a523f74e8e4f9d1'}
HELPERS = {'.github/actions/setup-flutter-sdk/action.yml': '9abb622a19138e9e98f8e12cd573116107d18982',
           '.github/actions/prepare-sea-shelter-arena/action.yml': 'dd537a932cf7a913d933576c291b63ccf48aa1e4',
           'scripts/ai_university_provider_catalog.py': '0abb16a347407691f3fc03a249edccd3af00b682',
           'scripts/render_web_supabase_config.py': '7a37385bb84a9013ff1af040d0e2e9127cc190a4'}
OWNER_KEYS = {'schema_version', 'repo', 'source', 'source_tree', 'controller_commit', 'ci_run',
              'ci_attempt', 'app_version', 'build_number', 'approved_for_build', 'approved_for_publish'}


def require(value):
    if not value:
        raise ValueError('guard_failed')


def canonical(value):
    return json.dumps(value, sort_keys=True, ensure_ascii=True, separators=(',', ':'),
                      allow_nan=False).encode('ascii')


def strict_json(raw):
    def pairs(items):
        out = {}
        for key, value in items:
            require(key not in out)
            out[key] = value
        return out
    def nonfinite(value):
        raise ValueError('nonfinite')
    return json.loads(raw, object_pairs_hook=pairs, parse_constant=nonfinite)


def validate_inputs(values):
    keys = {'repo', 'event', 'run_id', 'run_attempt', 'workflow_sha', 'expected_controller_sha',
            'app_version', 'build_number'}
    require(type(values) is dict and set(values) == keys and all(type(x) is str for x in values.values()))
    require(values['repo'] == REPO and values['event'] == 'workflow_dispatch' and values['run_attempt'] == '1')
    require(re.fullmatch('[1-9][0-9]{0,19}', values['run_id']) is not None)
    require(re.fullmatch('[0-9a-f]{40}', values['workflow_sha']) is not None and
            values['expected_controller_sha'] == values['workflow_sha'])
    version = values['app_version']
    require(len(version) <= 64 and re.fullmatch(
        r'(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)', version) is not None)
    require(tuple(map(int, version.split('.'))) > (1, 0, 2278))
    require(re.fullmatch('[1-9][0-9]{0,9}', values['build_number']) is not None and
            5836 < int(values['build_number']) < 2**31)
    return values.copy()


def validate_owner(raw_json, expected_sha256, inputs):
    inputs = validate_inputs(inputs)
    require(type(raw_json) is str and 0 < len(raw_json.encode('utf-8')) <= 65536 and
            type(expected_sha256) is str and re.fullmatch('[0-9a-f]{64}', expected_sha256) is not None)
    require(hashlib.sha256(raw_json.encode('utf-8')).hexdigest() == expected_sha256)
    owner = strict_json(raw_json)
    require(type(owner) is dict and set(owner) == OWNER_KEYS)
    expected = {'schema_version': 1, 'repo': REPO, 'source': SOURCE, 'source_tree': TREE,
                'controller_commit': inputs['workflow_sha'], 'ci_run': CI, 'ci_attempt': 1,
                'app_version': inputs['app_version'], 'build_number': inputs['build_number'],
                'approved_for_build': True, 'approved_for_publish': False}
    require(all(type(owner[key]) is type(value) and owner[key] == value for key, value in expected.items()))
    return {'owner_record_sha256': expected_sha256, 'approved_for_build': True,
            'approved_for_publish': False}


def _git(product, expression):
    result = subprocess.run(['git', '-C', str(product), 'rev-parse', expression],
                            capture_output=True, timeout=20, check=True)
    require(len(result.stdout) <= 100 and len(result.stderr) <= 65536)
    return result.stdout.decode('ascii').strip()


def _snapshots(assets):
    result = {}
    for name, digest in SNAPSHOTS.items():
        path = assets / name
        require(path.is_file() and not path.is_symlink())
        raw = path.read_bytes()
        require(len(raw) <= 65536 and hashlib.sha256(raw).hexdigest() == digest)
        strict_json(raw.decode('utf-8'))
        result[name] = raw
    return result


def verify(control, product, inputs, owner_receipt):
    require(_git(control, 'HEAD') == inputs['workflow_sha'])
    require(_git(product, 'HEAD') == SOURCE and _git(product, 'HEAD^{tree}') == TREE)
    for path, expected in HELPERS.items():
        raw = (product / path).read_bytes()
        require(hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest() == expected)
    assets = control / 'docs/asset-release-build-only/approved-assets'
    _snapshots(assets)
    preflight = assets / 'ASSET_HOSTING_PREFLIGHT_V3.py'
    require(not preflight.is_symlink() and preflight.is_file())
    require(hashlib.sha256(preflight.read_bytes()).hexdigest() == PREFLIGHT_SHA256)
    sys.dont_write_bytecode = True
    module = runpy.run_path(str(preflight), run_name='approved_build_only_preflight')
    require(module['SOURCE'] == SOURCE and module['RUN'] == CI and module['TREES'][SOURCE] == TREE)
    reader = module['Reader']()
    commit, _ = module['leaves'](reader, SOURCE, TREE)
    require([x['sha'] for x in commit['parents']] == [PUBLIC])
    module['full_run'](reader)
    require(module['manifest']() == {'commit': PUBLIC, 'version': '1.0.2278', 'buildNumber': '5836'})
    return {'source': SOURCE, 'source_tree': TREE, 'controller_commit': inputs['workflow_sha'],
            'ci_run': CI, 'ci_attempt': 1, 'run_id': inputs['run_id'], 'run_attempt': 1,
            **owner_receipt, 'publication_allowed': False}


def validate_bundle(root, inputs):
    inputs = validate_inputs(inputs)
    root = Path(root)
    require(root.is_dir() and not root.is_symlink())
    inventory, total = {}, 0
    for directory, dirs, files in os.walk(root, followlinks=False):
        for name in dirs:
            require(not (Path(directory) / name).is_symlink())
        for name in files:
            path = Path(directory) / name
            info = path.lstat()
            require(stat.S_ISREG(info.st_mode) and info.st_nlink == 1)
            relative = '/' + path.relative_to(root).as_posix()
            require(len(relative) <= 2048 and all(part not in ('', '.', '..') and
                re.fullmatch(r'[A-Za-z0-9._~!$&\x27()+,;=@-]+', part) is not None
                for part in relative[1:].split('/')))
            require(info.st_size <= 32 * 1024 * 1024)
            raw = path.read_bytes()
            require(len(raw) == info.st_size)
            total += len(raw)
            require(total <= 192 * 1024 * 1024 and len(inventory) < 2000)
            inventory[relative] = {'sha256': hashlib.sha256(raw).hexdigest(), 'bytes': len(raw)}
    for path in ('/index.html', '/main.dart.js', '/flutter_bootstrap.js', '/version.json'):
        require(path in inventory and inventory[path]['bytes'] > 0)
    version = strict_json((root / 'version.json').read_text(encoding='utf-8'))
    require(version == {'commit': SOURCE, 'version': inputs['app_version'], 'buildNumber': inputs['build_number']})
    return inventory


def seal(root, inputs, configuration):
    inputs = validate_inputs(inputs)
    require(type(configuration) is dict and all(type(k) is str and type(v) is str for k, v in configuration.items()))
    inventory = validate_bundle(root, inputs)
    artifact = hashlib.sha256(canonical({p: x['sha256'] for p, x in inventory.items()})).hexdigest()
    return {'schema_version': 1, 'source': SOURCE, 'source_tree': TREE,
            'controller_commit': inputs['workflow_sha'], 'ci_run': CI, 'ci_attempt': 1,
            'run_id': inputs['run_id'], 'run_attempt': 1, 'app_version': inputs['app_version'],
            'build_number': inputs['build_number'], 'artifact_sha256': artifact,
            'build_configuration_sha256': hashlib.sha256(canonical(configuration)).hexdigest(),
            'inventory': inventory, 'file_count': len(inventory),
            'publication_allowed': False, 'approved_for_publish': False,
            'production_build_only': True, 'hosting_config_attested': False,
            'live_preservation_pending': True, 'verification_pending': True}


def _runtime():
    names = {'repo': 'GITHUB_REPOSITORY', 'event': 'GITHUB_EVENT_NAME', 'run_id': 'GITHUB_RUN_ID',
             'run_attempt': 'GITHUB_RUN_ATTEMPT', 'workflow_sha': 'CONTROLLER_WORKFLOW_SHA',
             'expected_controller_sha': 'EXPECTED_CONTROLLER_SHA', 'app_version': 'APP_VERSION',
             'build_number': 'BUILD_NUMBER'}
    return validate_inputs({key: os.environ.get(name, '') for key, name in names.items()})


def _configuration(inputs):
    result = {key: os.environ.get(key, '') for key in
              ('SUPABASE_URL', 'SUPABASE_PUBLISHABLE_KEY', 'POSTHOG_PROJECT_TOKEN', 'POSTHOG_HOST')}
    require(all(result.values()))
    result.update({'ENVIRONMENT': 'production', 'APP_VERSION': inputs['app_version'],
                   'BUILD_NUMBER': inputs['build_number'], 'AI_UNIVERSITY_PROVIDER_COUNT': '368',
                   'LANDING_GOOGLE_LOGIN_ENABLED': 'true',
                   'ASSET_LIABILITY_SUPABASE_SYNC_ENABLED': 'true',
                   'ASSET_LIABILITY_SUPABASE_PRODUCTION_WRITES_ENABLED': 'true',
                   'ASSET_MANAGEMENT_AI_SUMMARY_ENABLED': 'true',
                   'ASSET_MANAGEMENT_AI_PROVIDER_ROUTING_ENABLED': 'true'})
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=('verify', 'prepare', 'seal'))
    parser.add_argument('--control', required=True)
    parser.add_argument('--product', required=True)
    args = parser.parse_args()
    phase = args.phase
    try:
        control, product = Path(args.control).resolve(), Path(args.product).resolve()
        inputs = _runtime()
        owner = validate_owner(os.environ.get('OWNER_RECORD_JSON', ''),
                               os.environ.get('OWNER_RECORD_SHA256', ''), inputs)
        if phase == 'verify':
            receipt = verify(control, product, inputs, owner)
            (product / 'BUILD_ONLY_VERIFIED.json').write_bytes(canonical(receipt))
        elif phase == 'prepare':
            values = _snapshots(control / 'docs/asset-release-build-only/approved-assets')
            root = product / 'build/web'
            require(root.is_dir() and not root.is_symlink())
            (root / 'version.json').write_bytes(canonical({'commit': SOURCE,
                'version': inputs['app_version'], 'buildNumber': inputs['build_number']}))
            (root / 'ai-university-catalog.json').write_bytes(values['catalog.json'])
            (root / 'release-notes.json').write_bytes(values['release-notes.json'])
            index = root / 'index.html'
            text = index.read_text(encoding='utf-8')
            index.write_text(text.replace('/ogp.png"', '/ogp.png?v=' + inputs['app_version'] + '"'), encoding='utf-8')
        else:
            receipt = seal(product / 'build/web', inputs, _configuration(inputs))
            receipt.update(owner)
            (product / 'build/asset-build-evidence.json').write_bytes(canonical(receipt))
        print('build_only_guard:' + phase + ':passed_not_publish_approved')
        return 0
    except Exception:
        print('build_only_guard:' + phase + ':stopped')
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
