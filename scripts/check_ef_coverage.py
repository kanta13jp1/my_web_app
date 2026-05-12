"""Check which deployed EFs are actually called from Flutter vs orphaned."""
import re
import glob
import os
import sys

def main():
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    lib_files = glob.glob(os.path.join(repo_root, 'lib/**/*.dart'), recursive=True)

    # Read deployed EFs from deploy-prod.yml
    deploy_yml = os.path.join(repo_root, '.github/workflows/deploy-prod.yml')
    deploy_line = re.compile(
        r'^\s*(?:supabase\s+functions\s+deploy|deploy_function)\s+([A-Za-z0-9_-]+)\b'
    )
    deployed = []
    with open(deploy_yml, encoding='utf-8') as f:
        for line in f:
            m = deploy_line.search(line)
            if m:
                deployed.append(m.group(1).rstrip())

    all_dart = ''
    for f in lib_files:
        with open(f, encoding='utf-8', errors='ignore') as fp:
            all_dart += fp.read()

    # Match real Supabase function invocations such as
    # `client.functions.invoke('schedule-hub')` without counting local helper
    # methods like `BlogService._invoke('blog.update_post')`.
    pattern = re.compile(r"(?<![A-Za-z0-9_])invoke\(\s*'([^']+)'", re.DOTALL)
    called = set(pattern.findall(all_dart))

    print(f'Deployed EFs: {len(deployed)}')
    print('Coverage:')
    not_called = []
    for ef in sorted(deployed):
        mark = 'OK  ' if ef in called else 'MISS'
        print(f'  {mark}: {ef}')
        if ef not in called:
            not_called.append(ef)

    phantom = sorted(called - set(deployed))
    if phantom:
        print(f'\nPHANTOM calls (invoked from Flutter but NOT deployed):')
        for ef in phantom:
            print(f'  WARN: {ef}')
        sys.exit(1)

    if not_called:
        print(f'\nNot called from Flutter (may be GHA/scheduled only): {not_called}')

    print(f'\nCoverage: {len(deployed) - len(not_called)}/{len(deployed)} deployed EFs called from Flutter')

if __name__ == '__main__':
    main()
