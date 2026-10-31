#!/usr/bin/env python3
"""Run the same Echo Pump checks with fewer tool startups; cloud execution first."""
import argparse
import json
import os
from pathlib import Path
import shlex
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
PREFIXES = (('dart', 'format', '--output=none', '--set-exit-if-changed'),
            ('dart', 'analyze'), ('flutter', 'test'))
AUDIO = ['python3', 'scripts/generate_echo_pump_audio.py', '--check']


def load_commands():
    return json.loads((ROOT / 'scripts/echo_pump_dev_commands.json').read_text(encoding='utf-8'))


def grouped_commands(commands):
    targets = {prefix: set() for prefix in PREFIXES}
    audio = 0
    for command in commands:
        if command == AUDIO:
            audio += 1
            continue
        prefix = next((p for p in PREFIXES if command[:len(p)] == list(p)), None)
        if prefix is None:
            raise ValueError(f'Unrecognized check: {command}')
        paths = command[len(prefix):]
        if not paths or any(not p.endswith('.dart') or not p.startswith(('lib/', 'test/'))
                            or '..' in Path(p).parts for p in paths):
            raise ValueError(f'Invalid check targets: {paths}')
        targets[prefix].update(paths)
    if audio != 1 or any(not paths for paths in targets.values()):
        raise ValueError('All format, analyze, test and audio checks are required')
    result = [list(p) + sorted(targets[p]) for p in PREFIXES]
    # Preserve the audio provenance gate; no commands are optional in quick mode.
    return result[:2] + [AUDIO] + result[2:]


def run_checks(mode, root=ROOT, report_path=None):
    baseline = load_commands()
    grouped = grouped_commands(baseline)  # Validate even when benchmarking baseline.
    commands = baseline if mode == 'baseline' else grouped
    report_path = report_path or root / '.ci-logs/echo-pump-dev-checks.json'
    report = {'schema': 1, 'mode': mode, 'head_sha': os.environ.get('GITHUB_SHA', ''),
              'result': 'failure', 'commands': []}
    started = time.perf_counter()
    status = 0
    for command in commands:
        print('+ ' + shlex.join(command), flush=True)
        step_start = time.perf_counter()
        try:
            status = subprocess.run(command, cwd=root, check=False).returncode
        except OSError as error:
            print(str(error), flush=True)
            status = 127
        report['commands'].append({'argv': command, 'returncode': status,
                                   'seconds': round(time.perf_counter() - step_start, 3)})
        if status:
            break
    report['seconds'] = round(time.perf_counter() - started, 3)
    report['result'] = 'success' if status == 0 else 'failure'
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(f"{mode}: {report['result']} in {report['seconds']}s", flush=True)
    return status


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=('baseline', 'grouped'), default='grouped')
    return run_checks(parser.parse_args(argv).mode)


if __name__ == '__main__':
    raise SystemExit(main())
