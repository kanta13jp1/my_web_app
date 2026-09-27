// Device-local assistance experience, never model training or shared score data.
export const MEMORY_KEY='jev-mario-retry-world8-v1';
const valid=r=>r&&Number.isInteger(r.stage)&&r.stage>=1&&r.stage<=32&&['overworld','stage-underground','underground','underwater','castle'].includes(r.room)&&Number.isFinite(r.x)&&r.x>=0&&r.x<10000&&Number.isFinite(r.y)&&Math.abs(r.y)<1000&&Number.isInteger(r.count)&&r.count>0&&r.count<=12;
export function retryLevel(world,records=[]){return Math.min(3,records.reduce((level,r)=>r.stage===world.stage&&r.room===world.room&&world.p.x>=r.x-192&&world.p.x<=r.x+24?Math.max(level,r.count??1):level,0));}
export class RetryMemory{
 constructor(storage){this.records=[];this.saved=false;try{this.storage=storage===undefined?globalThis.localStorage:storage;const raw=this.storage?.getItem(MEMORY_KEY);if(raw&&raw.length<20000){const data=JSON.parse(raw);if(Array.isArray(data))this.records=data.filter(valid).slice(-64).map(({stage,room,x,y,count})=>({stage,room,x,y,count}));}}catch{this.storage=null;}}
 record(world){if(world.phase!=='dead')return;const r={stage:world.stage,room:world.room,x:world.p.x,y:world.p.y,count:1};if(!valid(r))return;const old=this.records.find(f=>f.stage===r.stage&&f.room===r.room&&Math.abs(f.x-r.x)<48);if(old){old.count=Math.min(12,old.count+1);this.records=this.records.filter(f=>f!==old);this.records.push(old);}else this.records.push(r);this.records=this.records.slice(-64);this.persist();}
 persist(){try{this.storage?.setItem(MEMORY_KEY,JSON.stringify(this.records));this.saved=!!this.storage;}catch{this.saved=false;}}
 clear(){this.records=[];try{this.storage?.removeItem(MEMORY_KEY);}catch{}this.saved=false;}
}
