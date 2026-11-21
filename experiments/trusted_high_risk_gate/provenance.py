"""Prototype provenance checks; all metadata/bytes must come from GitHub API.

No network adapter or CI integration exists yet. Never accept a PR-supplied
metadata object or artifact bytes as an alternative to authenticated API reads.
"""
import hashlib
import io
import json
import re
import zipfile

TRUSTED_PATH = '.github/workflows/claude-agent-review.yml'
TRUSTED_APP = 15368
MAX_ARCHIVE = 512 * 1024
MAX_EVIDENCE = 256 * 1024


def attest(binding, run, check, artifact, archive, expected_workflow_id, expected_files):
    """Validate trusted-run metadata and extract one bound review artifact.

    The caller MUST independently retrieve run/check/artifact metadata and
    archive from authenticated api.github.com endpoints under binding.repository.
    """
    def require(value, reason):
        if not value:
            raise ValueError(reason)

    require(type(run.get('id')) is int and run['id'] > 0, 'invalid run')
    rid = run['id']
    attempt = run.get('run_attempt')
    require(type(attempt) is int and attempt > 0, 'invalid run attempt')
    require(run.get('event') == 'pull_request_target' and run.get('status') == 'completed'
            and run.get('conclusion') == 'success', 'untrusted or unsuccessful run')
    require(run.get('workflow_id') == expected_workflow_id and run.get('path') == TRUSTED_PATH,
            'unexpected workflow')
    require((run.get('repository') or {}).get('full_name') == binding.repository
            and run.get('head_sha') == binding.head, 'run binding mismatch')
    require(check.get('name') == 'AI Review Gate' and check.get('status') == 'completed'
            and check.get('conclusion') == 'success' and (check.get('app') or {}).get('id') == TRUSTED_APP,
            'untrusted or unsuccessful check')
    require(check.get('head_sha') == binding.head and check.get('external_id') ==
            f'ai-review:{binding.pr}:{binding.base}:{binding.head}', 'check binding mismatch')
    require(artifact.get('name') == f'ai-review-{rid}-{attempt}' and not artifact.get('expired')
            and (artifact.get('workflow_run') or {}).get('id') == rid
            and (artifact.get('workflow_run') or {}).get('head_sha') == binding.head,
            'artifact binding mismatch')
    require(isinstance(archive, bytes) and 0 < len(archive) <= MAX_ARCHIVE, 'invalid archive size')
    digest = artifact.get('digest')
    require(isinstance(digest, str) and re.fullmatch(r'sha256:[0-9a-f]{64}', digest)
            and digest == 'sha256:' + hashlib.sha256(archive).hexdigest(), 'artifact digest mismatch')
    try:
        with zipfile.ZipFile(io.BytesIO(archive)) as z:
            entries = z.infolist()
            require(len(entries) == 1 and entries[0].filename == 'evidence.json'
                    and entries[0].file_size <= MAX_EVIDENCE, 'unexpected artifact contents')
            evidence = json.loads(z.read(entries[0]).decode('utf-8'))
    except (zipfile.BadZipFile, UnicodeError, json.JSONDecodeError, RuntimeError) as exc:
        raise ValueError('invalid evidence archive') from exc
    require(isinstance(evidence, dict), 'invalid evidence')
    require(type(evidence.get('schema_version')) is int and evidence['schema_version'] == 1,
            'unexpected evidence schema')
    require(evidence.get('repository') == binding.repository and evidence.get('pr') == binding.pr
            and evidence.get('base') == binding.base and evidence.get('head') == binding.head
            and evidence.get('workflow_sha') == binding.base, 'evidence binding mismatch')
    require(str(evidence.get('run_id')) == str(rid) and str(evidence.get('run_attempt')) == str(attempt)
            and evidence.get('check_id') == check.get('id'), 'evidence provenance mismatch')
    review = evidence.get('review')
    require(evidence.get('status') == 'approved' and evidence.get('complete_diff') is True
            and isinstance(review, dict) and review.get('verdict') == 'approve', 'incomplete review')
    require(isinstance(evidence.get('response_id'), str) and evidence['response_id'].strip(),
            'missing actual provider response')
    require(type(review.get('schema_version')) is int and review['schema_version'] == 1,
            'unexpected review schema')
    require(review.get('head') == binding.head and review.get('base') == binding.base
            and isinstance(evidence.get('input_sha256'), str)
            and re.fullmatch(r'[0-9a-f]{64}', evidence['input_sha256'])
            and review.get('input_sha256') == evidence['input_sha256'], 'review binding mismatch')
    require(isinstance(expected_files, list) and expected_files
            and all(isinstance(x, str) and x for x in expected_files)
            and len(set(expected_files)) == len(expected_files), 'invalid current changed files')
    evidence_files = evidence.get('files')
    review_files = review.get('files')
    require(isinstance(evidence_files, list) and len(evidence_files) == len(expected_files)
            and all(isinstance(x, str) for x in evidence_files)
            and set(evidence_files) == set(expected_files), 'incomplete reviewed input')
    require(isinstance(review_files, list) and len(review_files) == len(expected_files)
            and all(isinstance(x, dict) and isinstance(x.get('path'), str)
                    and isinstance(x.get('assessment'), str) and len(x['assessment'].strip()) >= 30
                    for x in review_files)
            and len(set(x['path'] for x in review_files)) == len(expected_files)
            and set(x['path'] for x in review_files) == set(expected_files), 'incomplete per-file review')
    findings = review.get('findings')
    require(isinstance(findings, list) and all(isinstance(x, dict) and x.get('blocking') is False
            and x.get('severity') == 'low' for x in findings),
            'missing findings or blocking findings')
    areas = review.get('areas')
    require(isinstance(areas, list) and all(isinstance(x, dict) for x in areas), 'invalid areas')
    area_names = [x.get('area') for x in areas]
    require(all(isinstance(x, str) for x in area_names) and len(set(area_names)) == len(area_names),
            'duplicate or invalid areas')
    return {'repository': binding.repository, 'pr': binding.pr, 'base': binding.base, 'head': binding.head,
            'verdict': 'approve', 'unresolved': 0, 'areas': {x['area']: x.get('assessment') for x in areas}}
