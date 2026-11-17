"""Fail-closed environment boundary for disposable payroll HTTP tests."""
from uuid import UUID


def validate_environment(env, debug=__debug__):
    if not debug:
        raise RuntimeError('Optimized Python disables test assertions')
    required = {
        'GITHUB_ACTIONS': 'true',
        'PGHOST': '127.0.0.1',
        'PGPORT': '5432',
        'PGDATABASE': 'payroll_contract',
        'PGUSER': 'postgres',
        'PGPASSWORD': 'synthetic-contract-only',
    }
    for key, value in required.items():
        if env.get(key) != value:
            raise RuntimeError(f'Refusing unsafe test environment: {key}')
    for key in ('PGHOSTADDR', 'PGSERVICE', 'PGSERVICEFILE', 'PGOPTIONS',
                'PGPASSFILE'):
        if env.get(key):
            raise RuntimeError(f'Refusing overridden PostgreSQL setting: {key}')
    token = env.get('PAYROLL_TRANSPORT_FIXTURE_TOKEN', '')
    try:
        parsed = UUID(token)
    except (ValueError, AttributeError, TypeError):
        raise RuntimeError('Missing disposable per-run fixture marker') from None
    if parsed.version != 4 or str(parsed) != token:
        raise RuntimeError('Invalid disposable per-run fixture marker')
    return token


def validate_marker_count(count):
    if count != '1':
        raise RuntimeError('Disposable per-run fixture marker does not match')
