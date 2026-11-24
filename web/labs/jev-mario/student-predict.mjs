// Numeric regression trees exported by LightGBM. Browser/Node share this code.
function tree(node,x){if('leaf_value'in node)return node.leaf_value;return tree(x[node.split_feature]<=node.threshold?node.left_child:node.right_child,x);}
export function predict(model,x){
 const raw=model.map(m=>m.tree_info.reduce((sum,t)=>sum+tree(t.tree_structure,x),0));
 const clipped=raw.map(v=>Math.max(0,v)),sum=clipped.reduce((a,b)=>a+b,0);
 return {raw,probabilities:sum?clipped.map(v=>v/sum):model.map(()=>1/model.length),index:raw.indexOf(Math.max(...raw))};
}
