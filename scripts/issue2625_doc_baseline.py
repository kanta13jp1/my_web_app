import json, pathlib, subprocess
out = pathlib.Path('doc-quality-evidence'); out.mkdir()
fixture = out / 'positive-negative.md'
fixture.write_text('This documentation is correct.\n', encoding='utf-8')
assert subprocess.run(['codespell', '--', str(fixture)], capture_output=True).returncode == 0
fixture.write_text('This is teh documentation.\n', encoding='utf-8')
assert subprocess.run(['codespell', '--', str(fixture)], capture_output=True).returncode != 0
files = [p.decode('utf-8') for p in subprocess.check_output(['git','ls-files','-z']).split(b'\0') if p and p.lower().endswith(b'.md')]
statuses = []; findings = []
for i in range(0, len(files), 100):
    result = subprocess.run(['codespell','--',*files[i:i+100]], capture_output=True, text=True, timeout=120)
    statuses.append(result.returncode)
    findings.extend(result.stdout.splitlines())
    if result.stderr: findings.extend(result.stderr.splitlines())
(out/'spell-findings.txt').write_text('\n'.join(findings), encoding='utf-8')
summary = {'head':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(), 'tracked_markdown_files':len(files), 'finding_lines':len(findings), 'batch_exit_codes':statuses, 'positive_negative_detector_tests':'passed', 'scope':'English common misspellings; not Japanese grammar or link validation; diagnostic only'}
(out/'summary.json').write_text(json.dumps(summary,indent=2), encoding='utf-8')
print(json.dumps(summary))
assert all(code in (0,65) for code in statuses), 'unexpected checker failure'
