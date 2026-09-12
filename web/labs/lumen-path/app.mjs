import {LEVELS,trace,hint} from './model.mjs';
const $=id=>document.getElementById(id),NS='http://www.w3.org/2000/svg';
const COLORS={mint:'#7df8d7',gold:'#ffd27e',rose:'#ff8db7'},SYMBOLS={mint:'◆',gold:'●',rose:'▲'};
let selected=0,state=[],history=[],highlight=null;
function load(index){selected=index;state=[...LEVELS[index].initial];history=[];highlight=null;$('level').value=index;render('鏡を押して、光の行き先を変えてみましょう。');}
function svg(tag,attrs){const e=document.createElementNS(NS,tag);for(const [k,v] of Object.entries(attrs))e.setAttribute(k,v);return e;}
function piece(x,y,classes,color,text,label,action){
  const e=document.createElement(action?'button':'span');e.className=`piece ${classes}`;
  // SVG uses preserveAspectRatio="none" so cells and HTML controls align at all sizes.
  e.style.left=`${(x+1)/9*100}%`;e.style.top=`${(y+1)/9*100}%`;e.style.setProperty('--color',COLORS[color]||'#fff');e.textContent=text;
  e.setAttribute('aria-label',label);if(action)e.onclick=action;$('pieces').append(e);
}
function rotate(i){history.push([...state]);state[i]^=1;highlight=null;render();$('pieces').querySelectorAll('button')[i].focus({preventScroll:true});}
function render(message){
  const level=LEVELS[selected],result=trace(level,state);$('pieces').replaceChildren();$('rays').replaceChildren();$('rays').setAttribute('preserveAspectRatio','none');
  $('chapter').textContent=`ROOM 0${selected+1} / 03`;$('title').textContent=level.title;$('brief').textContent=level.brief;
  $('lit').textContent=`${result.lit.length} / ${level.targets.length} LIGHTS`;$('moves').textContent=history.length;
  $('undo').disabled=history.length===0;$('next').disabled=!result.solved||selected===LEVELS.length-1;$('hint').disabled=result.solved;
  $('status').textContent=message||(result.solved?(selected===2?'3色すべて点灯。光の道がつながりました。':'点灯しました！ 次の部屋へ進めます。'):'まだ届いていない光があります。道筋をたどってみましょう。');
  for(const path of result.paths){const d=path.points.map(([x,y],i)=>`${i?'L':'M'}${x},${y}`).join(' ');for(const kind of ['halo','core','flow']){const line=svg('path',{d,class:`beam ${kind}`});line.style.setProperty('--color',COLORS[path.color]);$('rays').append(line);}}
  level.sources.forEach(([x,y,,,color])=>piece(x,y,'source',color,SYMBOLS[color],`${color} 光源`));
  level.targets.forEach(([x,y,color],i)=>piece(x,y,`target ${result.lit.includes(i)?'on':''}`,color,SYMBOLS[color],`${color} 受光器 ${result.lit.includes(i)?'点灯':'消灯'}`));
  level.mirrors.forEach(([x,y],i)=>piece(x,y,`mirror ${highlight===i?'hinted':''}`,null,state[i]?'╲':'╱',`鏡 ${i+1}、${state[i]?'右下向き':'右上向き'}、押して回転`,()=>rotate(i)));
}
$('undo').onclick=()=>{if(history.length){state=history.pop();highlight=null;render('一手戻しました。');}};
$('reset').onclick=()=>load(selected);
$('level').onchange=()=>load(Number($('level').value));
$('next').onclick=()=>{if(trace(LEVELS[selected],state).solved&&selected<2)load(selected+1);};
$('hint').onclick=()=>{highlight=hint(LEVELS[selected],state);render(highlight===null?'この配置ではヒントが見つかりません。':`白枠の鏡 ${highlight+1} を回してみましょう。`);};
load(0);
