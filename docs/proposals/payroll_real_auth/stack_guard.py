"""Pure fail-closed checks for the synthetic GitHub Actions fixture."""
import re

POSTGRES = 'postgres@sha256:e4cb93687b062cd25a0e8f672d85a7708235009d70d31f8a7698d9370092a9c4'
IMAGES = {
    'auth': 'supabase/gotrue@sha256:839f529492d116b4e8b7777c953a27c381d34c15a744b1bcefde5eefaa1f9f9f',
    'rest': 'postgrest/postgrest@sha256:c847127074bd26e1b8d3f7c0e6e01e5346f4b85dd34f5d699fd230af960827c0',
    'gateway': 'envoyproxy/envoy@sha256:be87c8b52663c1164a5bdf3c5419017a269cb3d8c74be1ec93638a71f1ffbd4b',
    'client': 'python@sha256:7712cfd23e0501f5cb58faa5e6e0d515c9939bdbce866921799b31e696a1d13c',
}


def job_identity(env):
    run, attempt = env.get('GITHUB_RUN_ID', ''), env.get('GITHUB_RUN_ATTEMPT', '')
    if (env.get('GITHUB_ACTIONS') != 'true' or not __debug__
        or env.get('RUNNER_ENVIRONMENT') != 'github-hosted'
        or env.get('GITHUB_REPOSITORY') != 'kanta13jp1/my_web_app'
        or env.get('GITHUB_JOB') != 'synthetic-auth-envoy'
        or env.get('GITHUB_EVENT_NAME') not in ('pull_request', 'workflow_dispatch')
        or not re.fullmatch(r'[0-9]+', run) or not re.fullmatch(r'[0-9]+', attempt)):
        raise RuntimeError('Expected the synthetic GitHub-hosted job')
    cid = env.get('FIXTURE_DB_CONTAINER_ID', '')
    if not re.fullmatch(r'[0-9a-f]{64}', cid):
        raise RuntimeError('Missing job-managed database container ID')
    return cid, run + '-' + attempt


def container_ok(info, cid, image_id, image, run_label, *, db=False, require_running=True):
    config, host = info.get('Config') or {}, info.get('HostConfig') or {}
    labels = config.get('Labels') or {}
    if (info.get('Id') != cid or info.get('Image') != image_id
        or (require_running and info.get('State', {}).get('Running') is not True) or config.get('Image') != image
        or labels.get('payroll.auth.run') != run_label or host.get('Privileged')
        or host.get('Binds') or host.get('PortBindings') or host.get('NetworkMode') == 'host'):
        return False
    if db:
        if not {'POSTGRES_DB=payroll_auth_fixture', 'POSTGRES_PASSWORD=synthetic-only'}.issubset(set(config.get('Env') or [])):
            return False
        if set((host.get('Tmpfs') or {}).keys()) != {'/var/lib/postgresql/data'}:
            return False
        return all(m.get('Type') == 'tmpfs' and m.get('Destination') == '/var/lib/postgresql/data'
                   for m in (info.get('Mounts') or []))
    return not (info.get('Mounts') or [])


def network_ok(info, network_id, run_label):
    return (info.get('Id') == network_id and info.get('Internal') is True
            and (info.get('Labels') or {}).get('payroll.auth.run') == run_label)


def member_of_only(info, network_name, network_id):
    networks = (info.get('NetworkSettings') or {}).get('Networks') or {}
    return (set(networks) == {network_name}
            and networks[network_name].get('NetworkID') == network_id)
