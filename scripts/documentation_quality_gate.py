"""Report all Markdown findings; block new findings relative to a PR base."""
import argparse
from collections import Counter
import json
from pathlib import Path
import re
import subprocess
import tempfile
from documentation_links import check_links


def new_findings(current, previous):
    remaining = Counter(json.dumps(item, sort_keys=True) for item in previous)
    added = []
    for item in current:
        key = json.dumps(item, sort_keys=True)
        if remaining[key]:
            remaining[key] -= 1
        else:
            added.append(item)
    return added


def collect(root, paths):
    findings = []
    for name in paths:
        file = root / name
        if not file.is_file():
            continue
        for item in check_links(root, file):
            item.pop('line')  # Line movement is not a new broken target.
            findings.append({'kind': 'local_link', **item})
    for offset in range(0, len(paths), 100):
        result = subprocess.run(['codespell', '--', *paths[offset:offset+100]], cwd=root, text=True, capture_output=True, timeout=120)
        if result.returncode not in (0, 65):
            raise RuntimeError('codespell infrastructure failure')
        for line in result.stdout.splitlines():
            match = re.match(r'^(.*?):\d+: (.*)$', line)
            if not match:
                raise RuntimeError('unrecognized codespell result')
            findings.append({'kind': 'spelling', 'file': match[1], 'detail': match[2]})
    return findings


def tracked(root):
    return [p.decode('utf-8') for p in subprocess.check_output(['git', 'ls-files', '-z'], cwd=root).split(b'\0') if p.lower().endswith(b'.md')]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base')
    parser.add_argument('--output', type=Path, default=Path('doc-quality-evidence'))
    args = parser.parse_args()
    root = Path.cwd()
    current = collect(root, tracked(root))
    previous = []
    if args.base:
        # Exact immutable PR base only; the workflow supplies a SHA, not a name.
        if not re.fullmatch(r'[0-9a-f]{40}', args.base):
            raise ValueError('base must be a 40-character commit SHA')
        with tempfile.TemporaryDirectory(prefix='doc-base-') as directory:
            base_root = Path(directory)
            subprocess.run(['git', 'worktree', 'add', '--detach', directory, args.base], check=True, capture_output=True)
            try:
                previous = collect(base_root, tracked(base_root))
            finally:
                subprocess.run(['git', 'worktree', 'remove', directory], check=True, capture_output=True)
    added = new_findings(current, previous)
    args.output.mkdir(parents=True, exist_ok=True)
    report = {'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(), 'base': args.base, 'all_findings': current, 'new_findings': added, 'external_urls': 'not_checked', 'anchors': 'not_checked', 'app_routes': 'not_checked'}
    (args.output / 'findings.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    lines = ['# 文書品質検査', '', f'既存を含む指摘: {len(current)}', f'新規指摘: {len(added)}', '', '内部ファイル参照と英語の既知スペル誤りを検査。外部URL・アンカー・アプリURL・日本語文法は対象外。', '', '修正: 対象パスを確認しリンク先を復旧、または誤記を修正してください。誤検出は根拠と狭い例外をレビューします。', '', '全指摘はfindings.jsonに保存しています。']
    lines.extend(f'- {item}' for item in added[:50])
    (args.output / 'summary.md').write_text('\n'.join(lines), encoding='utf-8')
    print(json.dumps({'all_findings': len(current), 'new_findings': len(added)}))
    return 1 if added else 0


if __name__ == '__main__':
    raise SystemExit(main())
