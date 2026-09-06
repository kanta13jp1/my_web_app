import { BASE, CROSSINGS, LIMIT, create, step, metrics, signal, validate, position } from './model.mjs';
const $ = id => document.getElementById(id);
let settings = { ...BASE }, a, b, running = false, previous = 0, accumulator = 0;
const canvases = [$('cityA'), $('cityB')];
const contexts = canvases.map(canvas => canvas.getContext('2d'));
function announce(text) { $('status').textContent = text; }
function reset(message = '条件をそろえてリセットしました。') {
  a = create({ ...BASE, demand: settings.demand, seed: settings.seed }); b = create(settings);
  running = false; accumulator = 0; $('play').textContent = '比較を開始';
  for (const key of ['green', 'offset', 'demand', 'seed']) $(key).value = settings[key];
  $('greenValue').textContent = `${settings.green} / 40 tick`;
  $('offsetValue').textContent = `${settings.offset} tick`; $('demandValue').textContent = `${settings.demand}%`;
  announce(message); update();
}
function update() {
  for (const [world, id] of [[a, 'metricsA'], [b, 'metricsB']]) {
    const m = metrics(world), container = $(id); container.replaceChildren();
    for (const [label, value] of [['到着 / 台', m.arrived], ['累積待機 / 台·tick', m.waiting], ['未到着 / 台', m.onRoad + m.outside]]) {
      const item = document.createElement('div'); item.className = 'metric';
      const caption = document.createElement('span'); caption.textContent = label;
      const number = document.createElement('b'); number.textContent = value.toLocaleString(); item.append(caption, number); container.append(item);
    }
  }
  $('clock').textContent = `${a.tick} / ${LIMIT} tick`;
  const diff = b.arrived - a.arrived, wait = b.waiting - a.waiting;
  $('difference').textContent = a.tick === 0 ? '比較を開始すると結果が出ます' : `B − A：到着 ${diff > 0 ? '+' : ''}${diff}台 / 待機 ${wait > 0 ? '+' : ''}${wait.toLocaleString()}台·tick`;
}
function draw(canvas, ctx, world) {
  if (!ctx) return;
  const w = canvas.clientWidth, h = canvas.clientHeight, dpr = Math.min(devicePixelRatio || 1, 2);
  if (canvas.width !== Math.round(w*dpr) || canvas.height !== Math.round(h*dpr)) { canvas.width = Math.round(w*dpr); canvas.height = Math.round(h*dpr); }
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0); ctx.clearRect(0, 0, w, h);
  const scale = Math.min(w / 72, h / 44);
  const p = (x, y, z = 0) => [w / 2 + (x - y) * scale, h * .18 + (x + y) * scale * .48 - z * scale];
  function poly(points, fill, stroke) {
    ctx.beginPath(); points.forEach((q, i) => { const [x,y] = p(...q); i ? ctx.lineTo(x,y) : ctx.moveTo(x,y); }); ctx.closePath();
    ctx.fillStyle = fill; ctx.fill(); if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = .5; ctx.stroke(); }
  }
  poly([[-2,-2],[34,-2],[34,34],[-2,34]], '#1b323d', '#395663');
  poly([[-2,34],[34,34],[34,34,-1],[-2,34,-1]], '#091720');
  poly([[34,-2],[34,34],[34,34,-1],[34,-2,-1]], '#10232f');
  for (const lane of CROSSINGS) {
    poly([[0,lane-.9],[32,lane-.9],[32,lane+.9],[0,lane+.9]], '#09161f');
    poly([[lane-.9,0],[lane+.9,0],[lane+.9,32],[lane-.9,32]], '#09161f');
    for (let n = 0; n < 32; n += 2) {
      poly([[n,lane-.05],[n+.8,lane-.05],[n+.8,lane+.05],[n,lane+.05]], '#47616b');
      poly([[lane-.05,n],[lane+.05,n],[lane+.05,n+.8],[lane-.05,n+.8]], '#47616b');
    }
  }
  const objects = [];
  for (let row=0; row<4; row++) for (let col=0; col<4; col++) {
    const x=col*8+2, y=row*8+2, z=1.8+((row*7+col*3)%6)*.75;
    objects.push({ depth:x+y+6, paint:()=>{
      poly([[x,y],[x+4,y],[x+4,y+4],[x,y+4]], '#24404c');
      poly([[x,y+4],[x+4,y+4],[x+4,y+4,z],[x,y+4,z]], '#254556', '#446374');
      poly([[x+4,y],[x+4,y+4],[x+4,y+4,z],[x+4,y,z]], '#183746', '#365567');
      poly([[x,y,z],[x+4,y,z],[x+4,y+4,z],[x,y+4,z]], '#486878', '#648694');
      for(let level=.6;level<z-.3;level+=.85) for(let n=.5;n<3.8;n+=.85) {
        poly([[x+n,y+4+.01,level],[x+n+.35,y+4+.01,level],[x+n+.35,y+4+.01,level+.35],[x+n,y+4+.01,level+.35]], (row+col)%3===0?'#d9b481':'#71adbb');
      }
      const [px,py]=p(x+2,y+2,z+.1);ctx.fillStyle='#718f9b';ctx.fillRect(px-3,py-2,6,3);
    }});
  }
  for(const car of world.cars) {
    const [x,y]=position(car), color=car.stopped?'#ff7b79':car.axis==='E'?'#92e9da':'#ffd094';
    objects.push({depth:x+y,paint:()=>{
      const [px,py]=p(x,y,.35);ctx.shadowColor=color;ctx.shadowBlur=car.stopped?4:7;
      poly([[x-.3,y-.22,.2],[x+.3,y-.22,.2],[x+.3,y+.22,.2],[x-.3,y+.22,.2]],color);
      ctx.shadowBlur=0;ctx.fillStyle='#eafff8';ctx.fillRect(px,py,1.2,1.2);
    }});
  }
  objects.sort((left,right)=>left.depth-right.depth).forEach(object=>object.paint());
  for(const x of CROSSINGS) for(const y of CROSSINGS) {
    const phase=signal(world.config,world.tick,x,y),[px,py]=p(x,y,.5);
    ctx.strokeStyle=phase==='E'?'#90dcc9':phase==='S'?'#f3bd80':'#ff7b79';ctx.lineWidth=1.5;
    ctx.beginPath();ctx.arc(px,py,3,0,Math.PI*2);ctx.stroke();
  }
  ctx.fillStyle='#95adba';ctx.font='10px system-ui';ctx.fillText(`SEED ${world.config.seed} · 出発予定 ${world.events.length}台`,16,h-14);
}
function frame(timestamp) {
  const delta=previous ? Math.min((timestamp-previous)/1000,.1) : 0; previous=timestamp;
  if(running) {
    accumulator+=delta*Number($('speed').value);
    while(accumulator>=1 && a.tick<LIMIT){step(a);step(b);accumulator--;}
    update();
    if(a.tick===LIMIT){running=false;accumulator=0;$('play').textContent='もう一度比較';announce('720 tickの観測が終了しました。未到着車も含めて比較してください。');}
  }
  draw(canvases[0],contexts[0],a);draw(canvases[1],contexts[1],b);
  requestAnimationFrame(frame);
}
$('play').onclick=()=>{
  if(a.tick===LIMIT) reset(); running=!running; $('play').textContent=running?'一時停止':'再開';
  announce(running?'同じ需要で比較中です。':'一時停止中です。');
};
$('reset').onclick=()=>reset();
$('wave').onclick=()=>{settings={...settings,green:26,offset:8};reset('東行優先の候補を設定しました。南行への影響も比較してください。');};
for(const key of ['green','offset','demand','seed']) $(key).addEventListener('change',()=>{
  try{settings=validate({...settings,[key]:Number($(key).value)});reset();}catch(error){announce(error.message);$(key).value=settings[key];}
});
$('save').onclick=()=>{try{localStorage.setItem('flow-city-v1',JSON.stringify({version:1,settings}));announce('このブラウザに設定を保存しました。');}catch{announce('保存できませんでした。ブラウザの保存設定を確認してください。');}};
$('restore').onclick=()=>{try{const text=localStorage.getItem('flow-city-v1');if(!text)throw new Error('保存された設定がありません。');const data=JSON.parse(text);if(data.version!==1)throw new Error('対応していない保存形式です。');settings=validate(data.settings);reset('保存した設定を復元しました。');}catch(error){announce(`復元できません: ${error.message}`);}};
document.addEventListener('visibilitychange',()=>{if(document.hidden){running=false;accumulator=0;previous=0;$('play').textContent='再開';}});
reset('準備完了。まずは同じ設定で再現性を確認できます。');
if(contexts.some(ctx=>!ctx)){announce('描画機能を利用できません。対応ブラウザで開いてください。');$('play').disabled=true;}
else requestAnimationFrame(frame);
