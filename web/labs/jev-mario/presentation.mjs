import {courseInfo} from './world11.mjs?v=student-1';
// A live composition of the game and measured controller output, never a replay.
export const ACTIONS=['noop','right','right_jump','right_run','right_run_jump','jump','left'];
export function decisionView(value={}){
 const p=value.probabilities;
 const valid=p&&ACTIONS.every((a,i)=>Number.isFinite(Array.isArray(p)?p[i]:p[a])&&(Array.isArray(p)?p[i]:p[a])>=0&&(Array.isArray(p)?p[i]:p[a])<=1);
 const probabilities=valid?ACTIONS.map((a,i)=>Array.isArray(p)?p[i]:p[a]):null;
 return {...value,probabilities,latency:Number.isFinite(value.latency)&&value.latency>=0?value.latency:null};
}
export function drawPresentation(ctx,screen,{world,decision={},running=false,recording=false,fixture=false}){
 const d=decisionView(decision),w=1280,h=720;
 ctx.imageSmoothingEnabled=false;ctx.fillStyle='#0c1114';ctx.fillRect(0,0,w,h);
 const text=(s,x,y,size=14,color='#9da8af',font='system-ui')=>{ctx.fillStyle=color;ctx.font=`${size}px ${font}`;ctx.fillText(String(s),x,y);};
 const line=y=>{ctx.fillStyle='#263038';ctx.fillRect(866,y,392,1);};
 text(d.source||'Mario Decision Lab',20,29,22,'#edf2f5');
 const phase=fixture?'FIXED STATE':world.phase==='won'?'WORLD CLEAR':world.phase==='dead'?'TRY AGAIN':running?'LIVE GAMEPLAY':'PAUSED';
 text((recording?'● RECORDING · ':'')+phase,740,28,12,world.phase==='won'?'#a4e5bc':'#b4c5c9');
 ctx.fillStyle='#263038';ctx.fillRect(16,45,1248,1);
 ctx.fillStyle='#121a1e';ctx.fillRect(16,57,830,648);
 if(!fixture)ctx.drawImage(screen,0,0,screen.width,screen.height,88,61,682,639);
 else text('固定状態の計測 — ゲームプレイではありません',95,350,22);
 text(`World ${courseInfo(world.stage).label} · Decision ${String(d.count??0).padStart(4,'0')}`,868,76,13);
 text((d.action||'noop').replaceAll('_',' '),868,112,30,'#f0f4f6');
 text(`Model proposal: ${(d.proposal||'—').replaceAll('_',' ')}`,868,143,14);
 line(160);
 text('MODEL SCORE',868,183,11);text('LATENCY',1056,183,11);
 const index=ACTIONS.indexOf(d.proposal);
 text(d.probabilities&&index>=0?(100*d.probabilities[index]).toFixed(1)+'%':'—',868,211,23,'#edf2f5');
 text(d.latency===null?'—':d.latency.toFixed(3)+' ms',1056,211,23,'#edf2f5');
 text(d.latencyKind||'No measured inference yet',868,236,12);
 text('Model scores are not calibrated accuracy',868,254,12);
 line(267);text('Controller probabilities',868,290,14,'#edf2f5');
 ACTIONS.forEach((a,i)=>{const y=314+i*29,v=d.probabilities?.[i];text(a.replaceAll('_',' '),868,y,12);text(v===undefined?'—':(v*100).toFixed(1)+'%',1210,y,12);ctx.fillStyle='#1d282e';ctx.fillRect(868,y+5,386,5);if(v!==undefined){ctx.fillStyle=a===d.proposal?'#91d4e8':'#51636e';ctx.fillRect(868,y+5,386*v,5);}});
 line(516);text('Situation',868,540,14,'#edf2f5');
 const p=world.p;const pose=p.crouching?'crouching':p.grounded?(Math.abs(p.vx)>.1?'moving':'standing'):p.vy<0?'jumping':'falling';
 text(`Position  ${Math.round(p.x)}, ${Math.round(p.y)}`,868,566,14,'#b2bdc4','monospace');
 text(`Motion    ${pose} ${(p.facing??1)<0?'left':'right'}`,868,589,14,'#b2bdc4','monospace');
 text(`Time      ${world.time}    Score ${world.score}`,868,612,14,'#b2bdc4','monospace');
 text(`Model accepted ${d.accepted??0} / Search changed ${d.overrides??0}`,868,642,13);
 text('Independent recreation · real measurements',868,676,12);
 text(d.note||'No DeepSeek-trained weights loaded',868,696,12);
}
