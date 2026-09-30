import {compare} from './model.mjs';
const form=document.querySelector('form'),alert=document.querySelector('[role=alert]'),result=document.querySelector('[role=status]');
function clear(){alert.textContent='';result.textContent='入力が変わりました。照合してください。';}
form.addEventListener('input',clear);
form.addEventListener('submit',e=>{e.preventDefault();alert.textContent='';result.textContent='照合結果はありません。';try{const count=document.querySelector('#calls').value;if(!count.trim())throw new Error('ツール呼出数を入力してください。');const v=compare(document.querySelector('#expected').value,document.querySelector('#response').value,Number(count));result.textContent=v.rows.map(r=>r.mark+'：'+(r.seen?'検出':'未検出')).join('\n')+'\n'+v.scope+'\n文字列の検出だけでは読み込み経路や安全性を証明できません。';}catch(err){alert.textContent=err.message;}});
document.querySelector('#example').addEventListener('click',()=>{document.querySelector('#expected').value='MARK_C MARK_A';document.querySelector('#response').value='MARK_C';document.querySelector('#calls').value='0';form.requestSubmit();});
