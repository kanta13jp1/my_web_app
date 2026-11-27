import { test } from 'node:test';
import assert from 'node:assert/strict';
import { horizon } from '../../web/labs/time-horizon/model.mjs';
test('known analytic intersections',()=>{for(const [p,t] of [[50,120],[80,60],[90,40]])assert.ok(Math.abs(horizon(p)-t)<1e-6);});
test('invalid and non-number inputs are rejected',()=>{for(const p of [0,100,-1,101,NaN,Infinity,'80',null])assert.throws(()=>horizon(p));});
test('higher reliability always shortens synthetic horizon',()=>{let previous=Infinity;for(let p=1;p<100;p++){const t=horizon(p);assert.ok(t>0&&t<previous);previous=t;}});
