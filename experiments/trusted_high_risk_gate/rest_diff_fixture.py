"""Synthetic REST patch evidence experiment; not connected to observer or CI.

The caller must supply authenticated, bounded, fresh, trusted GitHub responses.
This module provides neither authentication nor a proof of API patch completeness.
Its domain is deliberately incompatible with the existing Git-based producer.
"""
import hashlib
import json
import re

DOMAIN = 'experimental-rest-files-v1'
LIMIT = 240_000
HUNK = re.compile(r'^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@(?: .*)?$')


def read_capped(stream):
    """Fixture reader, not a deadline: callers must enforce read and total deadlines.

    A timeout/connection failure propagates; partial data is never returned.
    An arbitrary blocking stream can still hang here, so real HTTP is prohibited
    until an independently verified transport supplies cancellation and deadlines.
    """
    out = bytearray()
    while len(out) <= LIMIT:
        size = min(8192, LIMIT + 1 - len(out))
        chunk = stream.read(size)
        if not isinstance(chunk, bytes) or len(chunk) > size:
            raise ValueError('invalid stream')
        if not chunk:
            break
        out.extend(chunk)
    if len(out) > LIMIT:
        raise ValueError('response exceeds limit')
    return bytes(out)


def patch_counts(patch):
    if not isinstance(patch, str) or not patch or '\r' in patch or '\x00' in patch:
        raise ValueError('missing or unsupported patch')
    add = delete = 0
    old_remaining = new_remaining = None
    hunks = 0
    lines = patch.split('\n')
    for index, line in enumerate(lines):
        if not line:
            if index != len(lines) - 1:
                raise ValueError('unprefixed empty patch line')
            continue
        if line.startswith('@@ '):
            if old_remaining is not None and (old_remaining != 0 or new_remaining != 0):
                raise ValueError('truncated hunk')
            match = HUNK.fullmatch(line)
            if not match:
                raise ValueError('invalid hunk header')
            old_remaining = int(match.group(2) or '1')
            new_remaining = int(match.group(4) or '1')
            hunks += 1
        elif line and old_remaining is not None:
            if line[0] == ' ':
                old_remaining -= 1
                new_remaining -= 1
            elif line[0] == '+':
                new_remaining -= 1
                add += 1
            elif line[0] == '-':
                old_remaining -= 1
                delete += 1
            else:
                raise ValueError('unsupported patch line')
            if old_remaining < 0 or new_remaining < 0:
                raise ValueError('invalid hunk size')
        elif line:
            raise ValueError('missing hunk header')
    if not hunks or old_remaining != 0 or new_remaining != 0:
        raise ValueError('missing or truncated hunk')
    return add, delete


def synthetic_digest(binding, before, files, after):
    """Domain-separated test digest; does not establish independent coverage."""
    def current(pr):
        return (isinstance(pr, dict) and pr.get('head') == binding.head
                and pr.get('base') == binding.base and type(pr.get('changed_files')) is int)
    if not current(before) or not current(after) or before != after:
        raise ValueError('PR binding changed')
    count = before['changed_files']
    if not isinstance(files, list) or not 0 < count < 100 or len(files) != count:
        raise ValueError('file list incomplete or exceeds conservative cap')
    normalized = []
    seen = set()
    for item in files:
        if not isinstance(item, dict) or item.get('status') not in ('added', 'removed', 'modified'):
            raise ValueError('rename, binary or unsupported status')
        path = item.get('filename')
        if not isinstance(path, str) or not path or path in seen or '\x00' in path:
            raise ValueError('invalid or duplicate filename')
        seen.add(path)
        additions, deletions = patch_counts(item.get('patch'))
        if type(item.get('additions')) is not int or type(item.get('deletions')) is not int:
            raise ValueError('invalid stats')
        if (additions, deletions) != (item['additions'], item['deletions']) or additions + deletions == 0:
            raise ValueError('patch stats incomplete')
        normalized.append({'path': path, 'status': item['status'], 'patch': item['patch']})
    normalized.sort(key=lambda item: item['path'])
    content = {'domain': DOMAIN, 'repository': binding.repository, 'pr': binding.pr,
               'base': binding.base, 'head': binding.head, 'files': normalized}
    data = json.dumps(content, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode('utf-8')
    if len(data) > LIMIT:
        raise ValueError('canonical input exceeds limit')
    return DOMAIN + ':' + hashlib.sha256(data).hexdigest()
