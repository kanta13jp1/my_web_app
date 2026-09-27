import test from 'node:test';
import assert from 'node:assert/strict';
import { parseRows, compare, calendarDate, reconcile, signTest } from '../../web/labs/acquisition-check/model.mjs';
const periods={beforeStart:'2026-09-13',beforeEnd:'2026-09-19',afterStart:'2026-09-20',afterEnd:'2026-09-26'};
const counts=[7,10,7,2,7,3,3,8,28,17,2,8,5,5];
const csv='date,count\n'+counts.map((n,i)=>`2026-09-${13+i},${n}`).join('\n');
test('production observations reproduce daily ratios and conditional sign sensitivity',()=>{
  const r=compare(parseRows(csv),periods);
  assert.equal(r.before.count,39);assert.equal(r.after.count,73);assert.equal(r.ratio,73/39);
  assert.equal(r.sign.p,.03125);assert.deepEqual(r.sign.leaveOneOut,[.03125,.0625]);assert.equal(r.causalEffect,null);
});
test('invalid counts and dates are rejected without accepting partial numbers',()=>{
  for(const value of ['-1','hello','1.2','true','','NaN','Infinity','1e3','9007199254740992']) assert.throws(()=>parseRows(`date,count\n2026-09-13,${value}`));
  assert.throws(()=>parseRows('date,count\n2026-02-30,1'));
  assert.throws(()=>parseRows('date,count\n2026-09-13,1\n2026-09-13,2'));
  assert.equal(parseRows('date,count\n2026-09-13,0')[0].count,0);
});
test('missing dates hold comparison and zero baseline is undefined',()=>{
  const rows=parseRows(csv);rows.splice(1,1);assert.deepEqual(compare(rows,periods).missing,['2026-09-14']);
  assert.equal(compare(parseRows(csv).map(r=>({...r,count:0})),periods).ratio,null);
  assert.throws(()=>compare(parseRows(csv),{...periods,afterStart:'2026-09-19'}));
});
test('different period lengths use per-day rates; control and search are separate',()=>{
  const input='date,count,control,impressions\n2026-09-01,10,10,100\n2026-09-02,15,20,120\n2026-09-03,15,20,120';
  const r=compare(parseRows(input),{beforeStart:'2026-09-01',beforeEnd:'2026-09-01',afterStart:'2026-09-02',afterEnd:'2026-09-03'});
  assert.equal(r.ratio,1.5);assert.equal(r.controlRatio,2);assert.equal(r.relativeRatio,.75);assert.equal(r.searchRatio,1.2);assert.equal(r.sign,null);
});
test('timezone boundary and repeated daylight-saving hour preserve explicit offsets',()=>{
  assert.equal(calendarDate('2026-09-20T15:30:00Z','Asia/Tokyo'),'2026-09-21');
  assert.equal(calendarDate('2026-09-20T15:30:00Z','UTC'),'2026-09-20');
  for(const offset of ['-07:00','-08:00']) assert.equal(calendarDate(`2026-11-01T01:30:00${offset}`,'America/Los_Angeles'),'2026-11-01');
  assert.throws(()=>calendarDate('2026-11-01T01:30:00','America/Los_Angeles'));
});
test('stage records expose unattempted, unknown and unsaved actions, without double-counting retries',()=>{
  const text='id,stage\na,occurred\nb,occurred\nb,attempted\nb,attempted\nc,occurred\nc,attempted\nc,accepted\nd,occurred\nd,attempted\nd,accepted\nd,saved\ne,occurred\ne,attempted\ne,duplicate';
  assert.deepEqual(reconcile(text),{occurred:5,unattempted:1,unacknowledged:1,unsaved:1,saved:1,duplicates:1});
  assert.throws(()=>reconcile('id,stage\na,saved'));
  assert.throws(()=>reconcile('id,stage\na,occurred\na,attempted\na,accepted\na,duplicate'));
});
test('sign probability agrees with independently enumerated coin outcomes',()=>{
  for(let n=1;n<=8;n++)for(let positives=0;positives<=n;positives++){
    const tail=Math.min(positives,n-positives);let favorable=0;
    for(let bits=0;bits<2**n;bits++){const k=bits.toString(2).replaceAll('0','').length;if(k<=tail||k>=n-tail)favorable++;}
    assert.equal(signTest(Array.from({length:n},(_,i)=>i<positives?1:-1)).p,favorable/2**n);
  }
});
