"""Hosted execution entry: unreviewed, do not invoke before independent review."""
import json
import sys
from pathlib import Path
import protocol
from hosted_adapter import HostedAdapter

SAFE_FAILURES = frozenset(('migration_digest', 'container_identity', 'baseline', 'session_identity',
    'backend_separation', 'holder_lock', 'guard_confirmation', 'history_submission',
    'history_barrier', 'grant_commit', 'grant_before_release', 'barrier_release',
    'candidate_commit', 'final_observation', 'direct_revoke_unproven', 'cleanup_unproven'))

def failure_label(error):
    # Only protocol's fixed labels may be shown. Never print server data or OS errors.
    current=error
    while current is not None:
        if isinstance(current, protocol.Unknown) and len(current.args)==1 and current.args[0] in SAFE_FAILURES:
            return current.args[0]
        current=current.__cause__
    return 'adapter_or_unclassified'


def main(argv):
    if argv != ['--hosted-execute']:
        print('STOP: explicit hosted execution is required')
        return 73
    try:
        raw=(Path(__file__).resolve().parent / 'fixed-migration-DO-NOT-EXECUTE.bin').read_bytes()
        adapter=HostedAdapter()
        result=protocol.execute(adapter,raw)
        result['pg_server_version_num']=adapter.server_version_num
        print(json.dumps(result,sort_keys=True))
        return 1 if result['outcome']=='race_observed' else 0
    except Exception as error:
        # Do not print command lines, credentials, or raw server output.
        print('UNKNOWN: observation, isolation or cleanup evidence incomplete; stage=' + failure_label(error))
        return 1


if __name__ == '__main__':
    raise SystemExit(main(sys.argv[1:]))
