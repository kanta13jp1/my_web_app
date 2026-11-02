#!/usr/bin/env python3
"""Partition test files before Flutter startup, keeping coverage and VM limits."""
import argparse
import json
from pathlib import Path
import subprocess


def select_files(root, index, total):
    if total < 1 or not 0 <= index < total:
        raise ValueError('Require total >= 1 and 0 <= index < total')
    files = sorted(path.relative_to(root).as_posix()
                   for path in (root / 'test').rglob('*_test.dart') if path.is_file())
    selected = files[index::total]
    if not selected:
        raise ValueError('VM shard must not silently pass with no test files')
    return selected


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--shard-index', type=int, required=True)
    parser.add_argument('--total-shards', type=int, required=True)
    args = parser.parse_args(argv)
    root = Path(__file__).resolve().parents[1]
    files = select_files(root, args.shard_index, args.total_shards)
    manifest = root / '.ci-logs' / 'vm-shard.json'
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text(json.dumps({'index': args.shard_index, 'total': args.total_shards,
                                   'files': files}, indent=2), encoding='utf-8')
    print(f'VM shard {args.shard_index}/{args.total_shards}: {len(files)} test files', flush=True)
    return subprocess.run(['flutter', 'test', '--coverage', '--concurrency=2',
                           '--file-reporter=json:.ci-logs/vm-events.jsonl', *files],
                          cwd=root, check=False).returncode


if __name__ == '__main__':
    raise SystemExit(main())
