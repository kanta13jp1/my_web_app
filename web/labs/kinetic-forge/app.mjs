import {W,H,R,DT,MAX_LINES,LEVELS,create,step} from './model.mjs';
const $=id=>document.getElementById(id),canvas=$('board'),ctx=canvas.getContext('2d');
let level=0,lines=[],sim=create(0),mode='design',drag=null,raf=0,last=0,acc=0;
const ready=()=>mode==='design';
function sync(message){
  const l=LEVELS[level];$('title').textContent=l.name;$('brief').textContent=l.brief;$('chapter').textContent=`ROOM 0${level+1} / 03`;
  $('phase').textContent=mode==='design'?'DESIGN MODE':mode==='running'?'LIVE':mode==='paused'?'PAUSED':sim.status==='won'?'ARRIVED':'TRY AGAIN';
  $('play').textContent=mode==='running'?'一時停止':mode==='paused'?'続ける':'球を放つ';$('play').disabled=mode==='done';
  $('undo').disabled=!ready()||lines.length===0;$('clear').disabled=!ready()||lines.length===0;$('sample').disabled=!ready();
  $('add-line').disabled=!ready();
  $('line-count').textContent=`${lines.length} / ${MAX_LINES} LINES`;$('clock').textContent=`${(sim.tick*DT).toFixed(2)} s`;
  if(message)$('status').textContent=message;
}
function reset(message='コースはそのまま。もう一度試せます。'){mode='design';drag=null;sim=create(level,lines);last=0;acc=0;sync(message);draw();}
function load(i){level=i;lines=[];$('level').value=i;reset('線を描いて、球をリングへ導こう。');}
function draw(){
  ctx.clearRect(0,0,W,H);ctx.strokeStyle='#243245';ctx.lineWidth=1;
  for(let x=0;x<=W;x+=45){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,H);ctx.stroke();}for(let y=0;y<=H;y+=45){ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(W,y);ctx.stroke();}
  const [gx,gy,gr]=LEVELS[level].goal;ctx.save();ctx.shadowColor='#a2f8da';ctx.shadowBlur=18;ctx.strokeStyle='#a2f8da';ctx.lineWidth=3;ctx.beginPath();ctx.arc(gx,gy,gr,0,Math.PI*2);ctx.stroke();ctx.restore();ctx.fillStyle='#a2f8da';ctx.font='bold 13px monospace';ctx.textAlign='center';ctx.fillText('GOAL',gx,gy+5);
  const all=[...lines];if(drag)all.push(drag);
  ctx.lineCap='round';for(const [x,y,bx,by] of all){ctx.strokeStyle='#ffc68e';ctx.lineWidth=5;ctx.beginPath();ctx.moveTo(x,y);ctx.lineTo(bx,by);ctx.stroke();ctx.fillStyle='#ffddba';for(const [px,py] of [[x,y],[bx,by]]){ctx.beginPath();ctx.arc(px,py,4,0,Math.PI*2);ctx.fill();}}
  if(sim.path.length){ctx.strokeStyle='#edac6955';ctx.lineWidth=2;ctx.beginPath();sim.path.forEach(([x,y],i)=>i?ctx.lineTo(x,y):ctx.moveTo(x,y));ctx.stroke();}
  ctx.save();ctx.shadowColor=sim.status==='won'?'#a2f8da':'#ffb566';ctx.shadowBlur=20;ctx.fillStyle=sim.status==='won'?'#a2f8da':'#fff0dc';ctx.beginPath();ctx.arc(sim.x,sim.y,R,0,Math.PI*2);ctx.fill();ctx.restore();
  ctx.fillStyle='#a5b9cc';ctx.font='11px monospace';ctx.textAlign='left';const [sx,sy]=LEVELS[level].spawn;ctx.fillText('START',sx+18,sy+4);
}
function frame(time){
  if(mode==='running'){
    if(last)acc+=Math.min((time-last)/1000,.1);last=time;let count=0;
    while(acc>=DT&&count++<12){sim=step(sim);acc-=DT;if(sim.status!=='running'){mode='done';sync(sim.status==='won'?'到達！ あなたの一筆が、球の道になりました。':'届きませんでした。「もう一度」で線を直して試そう。');break;}}
    $('clock').textContent=`${(sim.tick*DT).toFixed(2)} s`;draw();
  }else last=0;
  raf=requestAnimationFrame(frame);
}
const point=e=>{const b=canvas.getBoundingClientRect();return [Math.max(0,Math.min(W,(e.clientX-b.left)/b.width*W)),Math.max(0,Math.min(H,(e.clientY-b.top)/b.height*H))];};
canvas.addEventListener('pointerdown',e=>{if(!ready())return;if(lines.length>=MAX_LINES){sync('40本に達しました。一筆戻すか線を消してください。');return;}const [x,y]=point(e);drag=[x,y,x,y];canvas.setPointerCapture(e.pointerId);draw();});
canvas.addEventListener('pointermove',e=>{if(!drag)return;const [x,y]=point(e);drag[2]=x;drag[3]=y;draw();});
canvas.addEventListener('pointerup',()=>{if(!drag)return;if(Math.hypot(drag[2]-drag[0],drag[3]-drag[1])>=4)lines.push([...drag]);drag=null;sim=create(level,lines);sync('線を追加しました。「球を放つ」で実験。');draw();});
canvas.addEventListener('pointercancel',()=>{drag=null;draw();});
$('play').onclick=()=>{if(mode==='running'){mode='paused';sync('一時停止。同じ位置から続けられます。');}else{if(mode==='design')sim=create(level,lines);mode='running';last=0;acc=0;sync('球の行き先を観察しよう。');}};
$('retry').onclick=()=>reset();$('undo').onclick=()=>{if(ready()){lines.pop();reset('最後の一筆を戻しました。');}};
$('clear').onclick=()=>{if(ready()){lines=[];reset('線を消しました。新しい道を描こう。');}};
$('sample').onclick=()=>{if(ready()){lines=LEVELS[level].sample.map(l=>[...l]);reset('見本のコースを置きました。消して描き直すこともできます。');}};
$('level').onchange=()=>load(Number($('level').value));
$('add-line').onclick=()=>{
  if(!ready())return;
  if(lines.length>=MAX_LINES){sync('40本に達しました。一筆戻すか線を消してください。');return;}
  const values=['x1','y1','x2','y2'].map(id=>$(id).valueAsNumber);
  if(values.some((v,i)=>!Number.isFinite(v)||v<0||v>(i%2?H:W))){sync('横は0〜900、縦は0〜540の数値で入力してください。');return;}
  if(Math.hypot(values[2]-values[0],values[3]-values[1])<4){sync('始点と終点を4以上離してください。');return;}
  lines.push(values);reset('座標で線を追加しました。「球を放つ」で実験。');
};
document.addEventListener('visibilitychange',()=>{if(document.hidden&&mode==='running'){mode='paused';sync('画面が隠れたため一時停止しました。');}});
window.addEventListener('pagehide',()=>cancelAnimationFrame(raf));
load(0);raf=requestAnimationFrame(frame);
