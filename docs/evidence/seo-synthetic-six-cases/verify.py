from pathlib import Path
import json
from datetime import date,timedelta,datetime
ROOT=Path(__file__).parent

def compare(before,after):
    averages=[]
    for period in (before,after):
        days=[r['date'] for r in period['rows']]
        if len(set(days))!=len(days):return {'status':'duplicate_day'}
        expected={str(date.fromisoformat(period['start'])+timedelta(days=i)) for i in range(period['days'])}
        if set(days)!=expected:return {'status':'missing_days'}
        averages.append({k:sum(r[k] for r in period['rows'])/period['days'] for k in ('clicks','conversions')})
    if any(averages[0][k]==0 for k in ('clicks','conversions')):return {'status':'undefined_baseline'}
    return {'status':'ok','click_ratio':averages[1]['clicks']/averages[0]['clicks'],'conversion_ratio':averages[1]['conversions']/averages[0]['conversions']}

if __name__=='__main__':
    results=[]
    for case in json.loads((ROOT/'cases.json').read_text(encoding='utf-8')):
        actual=compare(case['before'],case['after'])
        results.append({'id':case['id'],'expected':case['expected'],'actual':actual,'pass':actual==case['expected']})
    (ROOT/'results.json').write_text(json.dumps({'ran_at':datetime.now().astimezone().isoformat(),'results':results},indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'passed':sum(r['pass'] for r in results),'total':len(results)}))
