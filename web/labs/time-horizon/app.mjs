import { horizon } from './model.mjs';
const input=document.querySelector('#percent'), result=document.querySelector('#result'), error=document.querySelector('#error');
function clear(){result.textContent='入力を変更しました。計算してください。';error.textContent='';}
function calculate(){
  try {
    const text=input.value.trim();
    if(!text) throw new Error('成功率を入力してください。');
    const p=Number(text), minutes=horizon(p);
    result.textContent=`合成例：成功率${p}%では人間基準 ${minutes.toFixed(2)} 分`;
    error.textContent='';
  } catch(e){result.textContent='計算結果はありません。';error.textContent=e.message;}
}
input.addEventListener('input',clear);
document.querySelector('form').addEventListener('submit',event=>{event.preventDefault();calculate();});
document.querySelectorAll('[data-p]').forEach(button=>button.addEventListener('click',()=>{input.value=button.dataset.p;calculate();}));
