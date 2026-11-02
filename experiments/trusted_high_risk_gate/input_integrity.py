"""Fixture-stage local reconstruction, not yet connected to the CI gate.

Callbacks must be imported from the independently verified protected base; PR
code, PR-supplied callbacks or artifacts containing review text are untrusted.
Never print/upload the raw or sanitized diff. Image assets are not supported.
"""
import hashlib
import os
import re
import subprocess
import threading


def verify_local_text_diff(repo, binding, expected_paths, expected_digest, assets, validate_scope, redact):
    """Reconstruct producer inputs from immutable local Git objects; return bool.

    Only the digest and status leave this process. Missing Git objects, input
    over 240 KB, binary/private content, renames, or untrusted callbacks must
    fail closed. Caller supplies exactly the protected-base producer callbacks.
    """
    if not re.fullmatch(r'[0-9a-f]{40}', binding.base) or not re.fullmatch(r'[0-9a-f]{40}', binding.head):
        raise ValueError('invalid immutable Git binding')
    if not isinstance(expected_paths, list) or not expected_paths:
        raise ValueError('missing changed-file paths')
    if not isinstance(expected_digest, str) or not re.fullmatch(r'[0-9a-f]{64}', expected_digest):
        raise ValueError('invalid expected digest')
    if not isinstance(assets, list) or assets:
        raise ValueError('image assets unsupported by local reconstruction')
    env = dict(os.environ, GIT_CONFIG_NOSYSTEM='1', GIT_OPTIONAL_LOCKS='0', GIT_TERMINAL_PROMPT='0')
    comparison = binding.base + '...' + binding.head
    def git(*args):
        limit = 240_000
        process = subprocess.Popen(['git', '-C', str(repo), *args], stdout=subprocess.PIPE,
                                   stderr=subprocess.DEVNULL, env=env)
        output = []
        def read_limited():
            output.append(process.stdout.read(limit + 1))
        worker = threading.Thread(target=read_limited, daemon=True)
        worker.start()
        try:
            worker.join(30)
            if worker.is_alive():
                raise ValueError('local immutable diff timed out')
            if not output or len(output[0]) > limit:
                raise ValueError('local immutable diff exceeds output limit')
            if process.wait(timeout=5):
                raise ValueError('local immutable diff unavailable')
            return output[0]
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
            worker.join(5)
            process.stdout.close()
    names = git('diff', '--no-ext-diff', '--no-renames', '--name-only', '-z', comparison)
    paths = names.decode('utf-8').rstrip('\0').split('\0')
    if len(paths) != len(expected_paths) or set(paths) != set(expected_paths):
        raise ValueError('changed files mismatch; rename or incomplete input')
    raw_bytes = git('diff', '--no-ext-diff', '--no-textconv', '--no-renames', '--unified=40', comparison)
    if not 0 < len(raw_bytes) <= 240_000:
        raise ValueError('diff empty or exceeds producer limit')
    raw = raw_bytes.decode('utf-8')
    validate_scope(paths, raw, ())
    sanitized, _ = redact(raw)
    if not isinstance(sanitized, str):
        raise ValueError('invalid redaction output')
    sanitized = re.sub(r'(?:[¥￥$€£]\s*[-+]?\d[\d,.]*|[-+]?\d[\d,.]*\s*円)', '[REDACTED_AMOUNT]', sanitized)
    return hashlib.sha256(sanitized.encode('utf-8')).hexdigest() == expected_digest
