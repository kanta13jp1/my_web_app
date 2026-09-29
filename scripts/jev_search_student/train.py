"""Fit a 7-way LightGBM student on search labels and export compact trees."""
import hashlib
import json
import sys
from pathlib import Path

import lightgbm as lgb
import numpy as np

ACTIONS = ['noop', 'right', 'right_jump', 'right_run', 'right_run_jump', 'jump', 'left']
width, out = int(sys.argv[1]), Path(sys.argv[2])
X = np.fromfile(out / 'X.f64', dtype=np.float64).reshape(-1, width)
y = np.array(json.loads((out / 'y.json').read_text()), dtype=int)
assert len(X) == len(y) and np.isfinite(X).all() and y.min() >= 0
params = {'objective': 'multiclass', 'num_class': 7, 'num_leaves': 31, 'learning_rate': 0.1,
          'min_data_in_leaf': 10, 'lambda_l2': 1.0, 'feature_fraction': 0.9, 'seed': 20260925,
          'deterministic': True, 'force_row_wise': True, 'num_threads': 4, 'verbosity': -1}
booster = lgb.train(params, lgb.Dataset(X, label=y), num_boost_round=250)


def export(tree):
    nodes, leaves = [], []

    def walk(n):
        if 'leaf_value' in n:
            leaves.append(n['leaf_value'])
            return ~(len(leaves) - 1)
        assert n['decision_type'] == '<=' and n.get('missing_type') != 'Zero'
        i = len(nodes)
        nodes.append(None)
        left, right = walk(n['left_child']), walk(n['right_child'])
        nodes[i] = [n['split_feature'], n['threshold'], left, right]
        return i
    walk(tree['tree_structure'])
    return {'n': nodes, 'l': leaves}


model = {'kind': 'lightgbm-multiclass-compact-v1', 'classes': ACTIONS, 'features': width,
         'lightgbm': lgb.__version__, 'rows': int(len(y)),
         'trees': [export(t) for t in booster.dump_model()['tree_info']]}
text = json.dumps(model, separators=(',', ':'))
(out / 'model.json').write_text(text)
sample = np.linspace(0, len(X) - 1, num=min(300, len(X))).astype(int)
(out / 'parity.json').write_text(json.dumps({'rows': X[sample].tolist(), 'scores': booster.predict(X[sample], raw_score=True).tolist()}))
pred = booster.predict(X).argmax(axis=1)
print(json.dumps({'rows': int(len(y)), 'labels': {a: int((y == i).sum()) for i, a in enumerate(ACTIONS)},
                  'in_sample_teacher_agreement': float((pred == y).mean()), 'trees': len(model['trees']),
                  'model_bytes': len(text), 'model_sha256': hashlib.sha256(text.encode()).hexdigest()}))
