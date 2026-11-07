from pathlib import Path
import json,hashlib
r=Path(__file__).parent
assert hashlib.sha256((r/'protocol.json').read_bytes()).hexdigest()==(r/'protocol.sha256.txt').read_text().strip()
p=json.loads((r/'protocol.json').read_text(encoding='utf-8'));a=json.loads((r/'responses.json').read_text(encoding='utf-8'));saved=json.loads((r/'scores.json').read_text(encoding='utf-8'))
assert len(a)==5
for n in ['full','shard3','reset']:
 try:value=json.loads(a[n]['result']);passed=value==p['expected']
 except json.JSONDecodeError:value=a[n]['result'];passed=False
 assert {'actual':value,'passed':passed}==saved[n]
for o in a.values():assert not o['is_error'] and o['models']==[p['model']]
print('Saved evidence verified; strict JSON 1/3. No live model calls.')
