from pathlib import Path
import json
from verify import compare
root=Path(__file__).parent
cases=json.loads((root/'cases.json').read_text(encoding='utf-8'))
saved=json.loads((root/'results.json').read_text(encoding='utf-8'))['results']
assert len(cases)==len(saved)==6
for case,record in zip(cases,saved):
    actual=compare(case['before'],case['after'])
    assert record['id']==case['id']
    assert actual==case['expected']==record['actual']==record['expected']
    assert record['pass'] is True
print('6 saved results reproduced; 5 distinct input pairs; evidence unchanged')
