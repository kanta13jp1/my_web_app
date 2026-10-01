import {World11} from '../../web/labs/jev-mario/world11.mjs';
import {LiveGuard} from '../../web/labs/jev-mario/live-guard.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
const rows=[];
for(const phase of [0,30,60,90]){
const g=new World11(32);g.power=1;Object.assign(g.p,{x:2173,y:180,h:28,vx:0,vy:0,grounded:true});g.camera=2077;g.frames=phase;g.contents.clear();g.items=[];g.cells.set('135,9','used');
const memory=[{stage:32,room:'castle',x:2189,y:153,count:12,kind:'stalled',failedActions:{jump:12,noop:4}}];const guard=new LiveGuard();let furthest=g.p.x,first=null;
for(let step=0;step<300&&g.phase==='playing';step++){const action=guard.decide(g,'jump',memory);first??=action;g.buttons(action);g.step();g.drainSounds();furthest=Math.max(furthest,g.p.x);}
rows.push({phase,first,furthest,x:g.p.x,y:g.p.y,alive:g.phase==='playing',deaths:g.deaths});}
mkdirSync('test-results',{recursive:true});writeFileSync('test-results/jev-course-audit-3.json',JSON.stringify({kind:'bounded recovery fixture, not full stage clearance',rows},null,2));console.log(JSON.stringify(rows));
