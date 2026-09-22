"""Measure only committed synthetic fixtures against a loopback JevBERT server."""
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import statistics
import time
import urllib.error
import urllib.request

UPSTREAM = '5a5af4ebd99c8b7db9f227d4d46216d668c2cc8f'
MODEL = 'jevbert-poc-nli-ja-en-0.2.0'
FIXTURES = Path(__file__).with_name('fixtures.json')


def validate_answer(body, ids):
    if body.get('model') != MODEL:
        raise ValueError('unexpected_model')
    answer = body['answers']['classification']
    if answer.get('type') != 'choice' or answer.get('choice') not in ids:
        raise ValueError('unexpected_choice')
    scores = answer['probabilities']
    if set(scores) != set(ids):
        raise ValueError('incomplete_distribution')
    values = [*scores.values(), answer['confidence']]
    if any(type(v) not in (int, float) or not math.isfinite(v) or not 0 <= v <= 1 for v in values):
        raise ValueError('invalid_probability')
    if abs(sum(scores.values()) - 1) > 0.01:
        raise ValueError('unnormalized_distribution')
    return answer


def rule_choice(text, rules):
    for keyword, category in rules:
        if keyword.lower() in text.lower().strip():
            return category
    return 'other'


def main():
    data = json.loads(FIXTURES.read_text(encoding='utf-8'))
    assert data['synthetic'] is True
    assert len(data['samples']) == 14 and len(data['categories']) == 12
    key = os.environ['JEVBERT_API_KEYS']
    criteria = {k: v['label'] + ': ' + v['description'] for k, v in data['categories'].items()}
    rows = []
    for sample in data['samples']:
        payload = json.dumps({'model':'jev-latest','state':sample['text'], 'questions':{
            'classification':{'type':'choice','instructions':data['instructions'],'criteria':criteria}
        }}, ensure_ascii=False).encode()
        row = {**sample, 'rule':rule_choice(sample['text'], data['rules']), 'trials':[]}
        # Two recorded calls, no retry or omitted warmup; first call remains labelled.
        for repetition in range(2):
            request = urllib.request.Request('http://127.0.0.1:8765/v1/systemone', data=payload,
                headers={'Content-Type':'application/json','Authorization':'Bearer '+key})
            started = time.perf_counter()
            try:
                with urllib.request.urlopen(request, timeout=40) as response:
                    body = json.load(response)
                answer = validate_answer(body, criteria)
                trial = {'status':'ok','model':body['model'],'answer':answer}
            except urllib.error.HTTPError as error:
                trial = {'status':'error','error':'http_'+str(error.code)}
            except Exception as error:
                # Never serialize exception text, request headers or arbitrary upstream bodies.
                trial = {'status':'error','error':type(error).__name__}
            trial.update(repetition=repetition+1, http_ms=round((time.perf_counter()-started)*1000, 3))
            row['trials'].append(trial)
        rows.append(row)
    timings = [t['http_ms'] for row in rows for t in row['trials'] if t['status']=='ok']
    result = {
        'schema_version':1, 'synthetic':True, 'mode':'saved_real_model_measurement',
        'recorded_at':time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
        'app_revision':os.environ.get('GITHUB_SHA'), 'run_id':os.environ.get('GITHUB_RUN_ID'),
        'upstream_revision':UPSTREAM, 'model':MODEL,
        'model_revision':'9abf1c8aaeb82a2447809c20753ed0b106b76652',
        'fixtures_sha256':hashlib.sha256(FIXTURES.read_bytes()).hexdigest(),
        'benchmark_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'rule_source_revision':data['source_revision'],
        'environment':{'platform':platform.platform(),'cpu':platform.processor(),'cpu_count':os.cpu_count(),
                       'python':platform.python_version(),'device':'CPU','threads':2},
        'timing_scope':'Loopback HTTP JSON round trip, including serialization, queue and CPU inference; excludes server/model startup. First call retained, 2 calls/sample, no retry.',
        'confidence_note':'Uncalibrated distribution concentration; not correctness or probability of truth.',
        'categories':data['categories'], 'samples':rows,
        'summary':{'valid':len(timings),'total':28,'http_median_ms':statistics.median(timings) if timings else None},
        'unmeasured':{'jwenv':'12 choices not validated; prior Jwenv contract supports at most 8.',
                      'cloud_jev':'Not called in this experiment.'},
    }
    output = Path('out/expense-comparison')
    output.mkdir(parents=True, exist_ok=True)
    (output/'results.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result['summary']))
    if len(timings) != 28:
        raise SystemExit('At least one call failed; retained all outcomes for diagnosis.')


if __name__ == '__main__':
    main()
