"""Fail-closed guards for the opt-in, GitHub-hosted real Auth test lane."""
from pathlib import Path
import os
import re
from urllib.parse import urlsplit

API = 'http://127.0.0.1:54321'
APP = 'http://127.0.0.1:7357'


def local_url(value, *, port, database=False):
    parsed = urlsplit(value)
    expected = 'postgresql' if database else 'http'
    if (parsed.scheme != expected or parsed.hostname != '127.0.0.1'
            or parsed.port != port or parsed.query or parsed.fragment):
        raise ValueError('Only the exact isolated loopback endpoint is allowed')
    if database:
        if parsed.path != '/postgres' or parsed.username != 'postgres':
            raise ValueError('Unexpected isolated database')
    elif parsed.username or parsed.password or parsed.path not in ('', '/'):
        raise ValueError('Origin only required')
    return parsed


def runtime(env=None):
    env = os.environ if env is None else env
    if env.get('GITHUB_ACTIONS') != 'true' or env.get('RUNNER_ENVIRONMENT') != 'github-hosted':
        raise ValueError('Only an ephemeral GitHub-hosted runner may execute this suite')
    run, attempt = env.get('GITHUB_RUN_ID', ''), env.get('GITHUB_RUN_ATTEMPT', '')
    if not re.fullmatch(r'[1-9][0-9]*', run) or not re.fullmatch(r'[1-9][0-9]*', attempt):
        raise ValueError('A real run identity is required')
    for key in ('SUPABASE_ACCESS_TOKEN', 'SUPABASE_DB_PASSWORD',
                'SUPABASE_SERVICE_ROLE_KEY', 'STRIPE_SECRET_KEY', 'DATABASE_URL'):
        if env.get(key):
            raise ValueError('Do not provide hosted credentials to this lane')
    if env.get('SUPABASE_URL', API) != API or env.get('E2E_BASE_URL', APP) != APP:
        raise ValueError('Hosted/custom endpoints are forbidden')
    raw_temp = Path(env.get('RUNNER_TEMP', ''))
    temp = raw_temp.resolve()
    if not raw_temp.is_absolute() or not env.get('RUNNER_TEMP') or temp == Path(temp.anchor):
        raise ValueError('Bounded runner temporary directory required')
    project = f'hexciv-auth-{run}-{attempt}'
    work = temp / project
    if work.parent != temp:
        raise ValueError('Unsafe temporary path')
    return project, work
