"""Fit probability regressors separately for Jev and synthetic rule teachers."""
import json, hashlib, platform
from pathlib import Path
import numpy as np
import lightgbm as lgb

OUT=Path('out/lightgbm'); DATA=Path('scripts/jev_distillation/teacher.json')
ACTIONS=['noop','right','right_jump','right_run','right_run_jump','jump','left']
data=json.loads(DATA.read_text());rows=[r for r in data['rows'] if r.get('teacher',{}).get('ok')]
assert data['source']=='d224c892c1f16895f24978358717717f96bad657' and data['feature_version']==1
candidates=json.loads((OUT/'candidates.json').read_text())
assert [{k:r[k] for k in ['id','features','state','split','group','rule_action']} for r in data['rows']]==[{k:r[k] for k in ['id','features','state','split','group','rule_action']} for r in candidates['rows']]
assert len({tuple(r['features']) for r in rows})==len(rows)
assert rows and len({r['id'] for r in rows})==len(rows)
groups={s:{r['group'] for r in rows if r['split']==s} for s in ['train','validation','test']}
assert not (groups['train']&groups['validation'] or groups['train']&groups['test'] or groups['validation']&groups['test'])
report={'source':data['source'],'dataset_sha256':hashlib.sha256(DATA.read_bytes()).hexdigest(),'lightgbm':lgb.__version__,'python':platform.python_version(),'rows':len(rows),'excluded_failed':len(data['rows'])-len(rows),'groups':{s:sorted(g) for s,g in groups.items()},'models':{}}
X=np.array([r['features'] for r in rows],dtype=float)
assert np.isfinite(X).all()
assert X.shape[1]==145
train=np.array([r['split']=='train' for r in rows]);valid=np.array([r['split']=='validation' for r in rows]);test=np.array([r['split']=='test' for r in rows])
assert min(sum(train),sum(valid),sum(test))>0
for kind in ['jev','rule']:
 Y=np.array([[r['teacher']['probabilities'][a] if kind=='jev' else float(r['rule_action']==a) for a in ACTIONS] for r in rows])
 assert np.allclose(Y.sum(axis=1),1,atol=.02)
 Y=Y/Y.sum(axis=1,keepdims=True)
 models=[]; preds=[]; rounds=[]
 for c in range(len(ACTIONS)):
  model=lgb.train({'objective':'regression','metric':'l2','verbosity':-1,'num_threads':2,'seed':20260922,'deterministic':True,'force_col_wise':True,'num_leaves':7,'min_data_in_leaf':5,'learning_rate':.05},lgb.Dataset(X[train],label=Y[train,c]),num_boost_round=150,valid_sets=[lgb.Dataset(X[valid],label=Y[valid,c])],callbacks=[lgb.early_stopping(15,verbose=False)])
  models.append(model.dump_model());preds.append(model.predict(X,num_threads=2));rounds.append(model.best_iteration)
 raw=np.array(preds).T;prob=np.maximum(raw,0);prob/=np.maximum(prob.sum(axis=1,keepdims=True),1e-12)
 truth=Y.argmax(axis=1);choices=raw.argmax(axis=1)
 metrics={}
 for name,mask in [('validation',valid),('test',test)]:
  matrix=np.zeros((7,7),dtype=int)
  for t,p in zip(truth[mask],choices[mask]):matrix[t,p]+=1
  per={a:{'support':int(matrix[i].sum()),'recall':float(matrix[i,i]/matrix[i].sum()) if matrix[i].sum() else None} for i,a in enumerate(ACTIONS)}
  metrics[name]={'n':int(sum(mask)),'teacher_distribution_argmax_agreement':float(np.mean(truth[mask]==choices[mask])),'majority_train_baseline':float(np.mean(truth[mask]==np.bincount(truth[train],minlength=7).argmax())),'probability_mae':float(np.mean(np.abs(Y[mask]-prob[mask]))),'confusion_matrix':matrix.tolist(),'per_action':per}
  if kind=='jev':metrics[name]['provider_choice_agreement']=float(np.mean(np.array([ACTIONS.index(r['teacher']['choice']) for r in rows])[mask]==choices[mask]))
 report['models'][kind]={'rounds':rounds,'metrics':metrics,'labels':{a:int(sum(truth==i)) for i,a in enumerate(ACTIONS)}}
 (OUT/(kind+'-model.json')).write_text(json.dumps(models))
 (OUT/(kind+'-parity.json')).write_text(json.dumps([{'features':x.tolist(),'raw':p.tolist()} for x,p in zip(X,raw)]))
(OUT/'training.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
