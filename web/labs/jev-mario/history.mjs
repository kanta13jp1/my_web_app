export const HISTORY_KEY='jev-mario-runs-v1';
export const RUN_REVISION='world5-1';
export const CONTROLLERS={manual:'手動',jev_only:'Jevのみ',jev_plus_local:'Jev＋ローカル補助',lightgbm_plus_search:'LightGBM＋探索'};
export function validRun(r){return !!r&&typeof r.id==='string'&&/^[0-9a-f-]{36}$/i.test(r.id)&&r.revision===RUN_REVISION&&Number.isInteger(r.course)&&r.course>=1&&r.course<=20&&Object.hasOwn(CONTROLLERS,r.controller)&&['won','dead','stopped'].includes(r.outcome)&&Number.isInteger(r.score)&&r.score>=0&&r.score<=1000000&&Number.isInteger(r.frames)&&r.frames>0&&r.frames<=216000&&Number.isInteger(r.power)&&r.power>=0&&r.power<=2&&typeof r.eligible==='boolean'&&typeof r.created_at==='string'&&Number.isFinite(Date.parse(r.created_at));}
export class RunHistory{
 constructor(storage){this.storage=storage;this.rows=[];this.warning='';try{const raw=storage.getItem(HISTORY_KEY);if(raw){const data=JSON.parse(raw);if(!Array.isArray(data))throw Error();this.rows=data.filter(validRun).slice(0,100);}}catch{this.warning='保存履歴を読み込めません。この画面の記録はJSONで保存できます。';}}
 add(row){if(!validRun(row))return false;this.rows=[row,...this.rows.filter(r=>r.id!==row.id)].slice(0,100);try{this.storage.setItem(HISTORY_KEY,JSON.stringify(this.rows));}catch{this.warning='端末への保存に失敗しました。ページを閉じる前に履歴JSONを保存してください。';}return true;}
}
export function compareRuns(a,b){return Number(b.outcome==='won')-Number(a.outcome==='won')||b.score-a.score||a.frames-b.frames||a.created_at.localeCompare(b.created_at)||a.id.localeCompare(b.id);}
