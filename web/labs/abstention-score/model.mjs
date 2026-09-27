export function score(text, penalty) {
 if(typeof penalty!=='number'||!Number.isFinite(penalty)||penalty<0) throw new Error('減点は0以上の有限の数値にしてください。');
 const labels=text.trim()?text.trim().split(/[\s,]+/):[];
 if(labels.some(x=>!['C','E','A'].includes(x))) throw new Error('ラベルはC（正答）、E（誤答）、A（保留）だけを入力してください。');
 const c=labels.filter(x=>x==='C').length,e=labels.filter(x=>x==='E').length,a=labels.filter(x=>x==='A').length,n=labels.length;
 return {n,c,e,a,accuracy:n?c/n:null,error:n?e/n:null,abstention:n?a/n:null,coverage:n?(c+e)/n:null,answeredError:c+e?e/(c+e):null,score:n?(c-penalty*e)/n:null};
}
