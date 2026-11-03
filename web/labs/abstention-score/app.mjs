import {score} from './model.mjs';
const labels=document.querySelector('#labels'),penalty=document.querySelector('#penalty'),result=document.querySelector('#result'),error=document.querySelector('#error');
const pct=v=>v===null?'計算不能':(v*100).toFixed(2)+'%';
function calculate(){try{if(!penalty.value.trim())throw new Error('減点を入力してください。');const r=score(labels.value,Number(penalty.value));result.textContent=`全${r.n}件：正答${r.c}・誤答${r.e}・保留${r.a}\n全問正答率 ${pct(r.accuracy)}\n全問誤答率 ${pct(r.error)}\n保留率 ${pct(r.abstention)}\n回答率 ${pct(r.coverage)}\n回答中の誤答率 ${pct(r.answeredError)}\n点数 ${r.score===null?'計算不能':r.score.toFixed(4)}`;error.textContent='';}catch(e){result.textContent='集計結果はありません。';error.textContent=e.message;}}
document.querySelector('form').addEventListener('submit',e=>{e.preventDefault();calculate();});
for(const el of [labels,penalty])el.addEventListener('input',()=>{result.textContent='入力が変わりました。集計してください。';error.textContent='';});
document.querySelectorAll('[data-example]').forEach(b=>b.addEventListener('click',()=>{const [c,e,a]=b.dataset.example==='a'?[24,75,1]:b.dataset.example==='b'?[22,26,52]:[0,0,10];labels.value=[...Array(c).fill('C'),...Array(e).fill('E'),...Array(a).fill('A')].join(' ');calculate();}));
