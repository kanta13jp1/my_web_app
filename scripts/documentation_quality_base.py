"""Resolve the immutable base paired with a checked-out PR merge commit."""
import argparse
import re
import subprocess


def comparison_base(event_base, parents):
    if not re.fullmatch(r'[0-9a-f]{40}', event_base):
        raise ValueError('event base must be a 40-character commit SHA')
    # pull_request checkout is a synthetic merge. An event payload can retain
    # an older base after main advances; compare against this merge's first parent.
    if len(parents) != 2 or any(not re.fullmatch(r'[0-9a-f]{40}', p) for p in parents):
        raise ValueError('PR documentation check requires a two-parent merge checkout')
    return parents[0]


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--event-base', required=True)
    args = parser.parse_args()
    parents = subprocess.check_output(['git', 'show', '-s', '--format=%P', 'HEAD'], text=True).split()
    print(comparison_base(args.event_base, parents))
