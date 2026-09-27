import { parseRows, compare, calendarDate, reconcile } from './model.mjs';
const $ = id => document.getElementById(id);
let saved = null;
const sample = 'date,count\n2026-09-13,7\n2026-09-14,10\n2026-09-15,7\n2026-09-16,2\n2026-09-17,7\n2026-09-18,3\n2026-09-19,3\n2026-09-20,8\n2026-09-21,28\n2026-09-22,17\n2026-09-23,2\n2026-09-24,8\n2026-09-25,5\n2026-09-26,5';
function invalidate() { saved = null; $('result').hidden = true; $('error').textContent = ''; }
document.querySelectorAll('#data,.fields input,#zone').forEach(el => el.addEventListener('input', () => {
  invalidate(); $('provenance').textContent = '入力されたデータです。計測方法と日付の区切りを確認してください。';
}));
$('sample').addEventListener('click', () => {
  $('data').value = sample; $('zone').value = 'Asia/Tokyo';
  for (const [key, value] of Object.entries({beforeStart:'2026-09-13',beforeEnd:'2026-09-19',afterStart:'2026-09-20',afterEnd:'2026-09-26'})) $(key).value=value;
  invalidate(); $('provenance').textContent = 'my_web_appの2026年9月13〜26日の本番受付記録。日本時間。同じ対象・流入元・日付の重複を除いたページ接触39→73件です。人数・クリック・登録完了とは異なり、管理者や試験操作を除外した値でもありません。取得日: 2026-09-27。';
});
const format = n => n === null || n === undefined ? '算出できません' : Number(n.toFixed(5)).toLocaleString('ja-JP');
function paragraph(text, className='') { const p=document.createElement('p');p.textContent=text;p.className=className;$('result-content').append(p); }
$('compare').addEventListener('click', () => {
  invalidate();
  try {
    const rows=parseRows($('data').value), periods=Object.fromEntries(['beforeStart','beforeEnd','afterStart','afterEnd'].map(k=>[k,$(k).value]));
    const result=compare(rows,periods); saved={version:1,createdAt:new Date().toISOString(),timezone:$('zone').value,provenance:$('provenance').textContent,periods,rows,result};
    $('result-content').replaceChildren(); $('result').hidden=false;
    if (!result.ready) { paragraph(result.explanation,'warning');paragraph(`記録のない日: ${result.missing.join('、')}`);return; }
    const cards=document.createElement('div');cards.className='metrics';
    for (const [label,value] of [['変更前 / 1日',format(result.before.countPerDay)],['変更後 / 1日',format(result.after.countPerDay)],['1日あたりの倍率',result.ratio===null?'基準が0件':`${format(result.ratio)}倍`]]) { const card=document.createElement('div');card.className='metric';card.textContent=label;const strong=document.createElement('strong');strong.textContent=value;card.append(strong);cards.append(card); }
    $('result-content').append(cards);
    paragraph(`合計 ${result.before.count}件（${result.before.days}日） → ${result.after.count}件（${result.after.days}日）。日付の区切り: ${$('zone').selectedOptions[0].textContent}。`);
    if(result.sign) paragraph(`同じ曜日の組で増加${result.sign.plus}・減少${result.sign.minus}・同数${result.sign.ties}。符号検定（増減の偏りを見る計算）のp値は${format(result.sign.p)}。1組ずつ外すと${result.sign.leaveOneOut.map(format).join('〜')}。組が独立で増減が半々という仮定のもとで、同程度以上の偏りが出る確率です。原因の証明や「偶然の確率」ではありません。`);
    else paragraph('日数と曜日の対応が揃わないため、増減の偏りの検定は行いません。');
    if(result.before.control!==undefined) paragraph(`変更していない比較ページの1日あたり倍率: ${format(result.controlRatio)}。対象ページの倍率を比較ページの倍率で割った値: ${format(result.relativeRatio)}。流入や変更前の傾向が違えば、この値から施策効果は判断できません。`);
    if(result.before.impressions!==undefined) paragraph(`検索表示回数の1日あたり倍率: ${format(result.searchRatio)}。順位や掲載ページ数の変化も含むため、検索需要そのものとは区別してください。`);
    paragraph('この結果だけでは、サイトの変更が増加の原因だとは判断できません。記録の取りこぼし、季節、検索需要、比較ページの条件を別に確認してください。','warning');
  } catch(error) { $('error').textContent=error.message; }
});
$('download').addEventListener('click',()=>{if(!saved)return;const url=URL.createObjectURL(new Blob([JSON.stringify(saved,null,2)],{type:'application/json'}));const a=document.createElement('a');a.href=url;a.download='access-comparison.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);});
$('date-check').addEventListener('click',()=>{try{$('date-result').textContent=[['日本時間','Asia/Tokyo'],['米国太平洋時間','America/Los_Angeles'],['UTC','UTC']].map(([name,zone])=>`${name}: ${calendarDate($('instant').value,zone)}`).join('\n');}catch(e){$('date-result').textContent=e.message;}});
$('reconcile').addEventListener('click',()=>{try{const r=reconcile($('delivery').value);$('delivery-result').textContent=`操作発生 ${r.occurred}件 / 送信試行なし ${r.unattempted}件 / 受付結果未確認 ${r.unacknowledged}件 / 保存未確認 ${r.unsaved}件 / 保存確認 ${r.saved}件 / 重複処理 ${r.duplicates}件\n「未確認」は必ず失われたという意味ではありません。ログ自体の欠落や遅れも確認してください。`;}catch(e){$('delivery-result').textContent=e.message;}});
