// LightGBM multiclass trees exported as compact arrays. A node is
// [feature, threshold, left, right]; a negative child c is leaf ~c.
// Browser and Node share this file so their decisions cannot drift.
export function predict2(model,x){
 const k=model.classes.length,scores=new Array(k).fill(0);
 for(let t=0;t<model.trees.length;t++){
  const tree=model.trees[t];let n=tree.n.length?0:-1;
  while(n>=0){const node=tree.n[n];n=x[node[0]]<=node[1]?node[2]:node[3];}
  scores[t%k]+=tree.l[~n];
 }
 const top=Math.max(...scores),e=scores.map(v=>Math.exp(v-top)),sum=e.reduce((a,b)=>a+b,0),index=scores.indexOf(top);
 return {scores,probabilities:e.map(v=>v/sum),index,action:model.classes[index]};
}
