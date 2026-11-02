export const HISTORY_KEY='jev-mario-campaigns-v1';
export const RUN_REVISION='world8-1';
export const CONTROLLERS={manual:'手動',jev_only:'Jevのみ',jev_plus_local:'Jev＋ローカル補助',lightgbm_plus_search:'LightGBM＋探索'};
const integer=(v,min,max)=>Number.isInteger(v)&&v>=min&&v<=max;
export function validRun(r){return !!r&&typeof r.id==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(r.id)&&['world6-1','world7-1',RUN_REVISION].includes(r.revision)&&integer(r.course,1,32)&&integer(r.reached,r.course,32)&&integer(r.cleared,r.course-1,r.reached)&&Object.hasOwn(CONTROLLERS,r.controller)&&['won','dead','stopped'].includes(r.outcome)&&integer(r.score,0,10000000)&&integer(r.elapsed_ms,1,86400000)&&integer(r.power,0,2)&&typeof r.eligible==='boolean'&&typeof r.created_at==='string'&&Number.isFinite(Date.parse(r.created_at));}
export class Campaign{
 constructor(clock=()=>performance.now(),uuid=()=>crypto.randomUUID()){this.clock=clock;this.uuid=uuid;this.active=null;}
 begin(world,controller){if(this.active)return;this.started=this.clock();this.active={id:this.uuid(),revision:RUN_REVISION,course:world.stage,reached:world.stage,cleared:world.stage-1,controller,power:world.power,eligible:world.frames===0&&world.p.x===32,created_at:new Date().toISOString()};}
 observe(world){if(!this.active)return;this.active.reached=Math.max(this.active.reached,world.stage);if(world.phase==='won')this.active.cleared=Math.max(this.active.cleared,world.stage);}
 finish(world,outcome){if(!this.active)return null;this.observe(world);const row={...this.active,outcome,score:world.score,elapsed_ms:Math.max(1,Math.round(this.clock()-this.started))};this.active=null;return row;}
}
export class RunHistory{
 constructor(storage){this.storage=storage;this.rows=[];this.warning='';try{const raw=storage.getItem(HISTORY_KEY);if(raw){const data=JSON.parse(raw);if(!Array.isArray(data))throw Error();this.rows=data.filter(validRun).slice(0,100);}}catch{this.warning='保存履歴を読み込めません。この画面の記録はJSONで保存できます。';}}
 add(row){if(!validRun(row))return false;this.rows=[row,...this.rows.filter(r=>r.id!==row.id)].slice(0,100);try{this.storage.setItem(HISTORY_KEY,JSON.stringify(this.rows));}catch{this.warning='端末への保存に失敗しました。ページを閉じる前に履歴JSONを保存してください。';}return true;}
}
export function compareRuns(a,b){return b.reached-a.reached||b.cleared-a.cleared||b.score-a.score||a.elapsed_ms-b.elapsed_ms||a.created_at.localeCompare(b.created_at)||a.id.localeCompare(b.id);}
