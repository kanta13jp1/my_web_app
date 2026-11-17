export const SIZE = 7;
// Abstract right-angle ray puzzle, not a physical optics simulator.
export const LEVELS = [
  { title:'最初の反射', brief:'鏡を1回押して、光を上の受光器へ。', mirrors:[[2,3]], initial:[1], sources:[[-1,3,1,0,'mint']], targets:[[2,0,'mint']] },
  { title:'折り返す光', brief:'3枚の鏡をつなぎ、右下の受光器を灯す。', mirrors:[[1,5],[1,2],[5,2]], initial:[1,1,0], sources:[[-1,5,1,0,'gold']], targets:[[5,6,'gold']] },
  { title:'三つの灯台', brief:'3色すべてを、それぞれの受光器へ導く。', mirrors:[[3,1],[1,3],[5,5]], initial:[0,1,1], sources:[[-1,1,1,0,'rose'],[-1,3,1,0,'mint'],[-1,5,1,0,'gold']], targets:[[3,6,'rose'],[1,0,'mint'],[5,0,'gold']] },
];
export function validate(level, state) {
  if (!Array.isArray(state) || state.length !== level.mirrors.length || state.some(v => v !== 0 && v !== 1)) throw new Error('鏡の設定が正しくありません。');
  return [...state];
}
export function trace(level, input) {
  const state = validate(level,input), lit = new Set(), paths = [];
  for (const source of level.sources) {
    let [x,y,dx,dy,color] = source;
    const points = [[x,y]], visited = new Set(); let reason='edge';
    for (let step=0;step<256;step++) {
      x+=dx;y+=dy;points.push([x,y]);
      if(x<0||y<0||x>=SIZE||y>=SIZE) break;
      const key = `${x},${y},${dx},${dy}`;
      if(visited.has(key)){reason='loop';break;}visited.add(key);
      const target=level.targets.findIndex(t=>t[0]===x&&t[1]===y);
      if(target!==-1){if(level.targets[target][2]===color)lit.add(target);reason='target';break;}
      const mirror=level.mirrors.findIndex(m=>m[0]===x&&m[1]===y);
      if(mirror!==-1) [dx,dy]=state[mirror]===0?[-dy,-dx]:[dy,dx];
    }
    paths.push({color,points,reason});
  }
  return {paths,lit:[...lit],solved:lit.size===level.targets.length};
}
export function hint(level,input) {
  const state=validate(level,input); if(trace(level,state).solved)return null;
  if(state.length>12)throw new Error('ヒント探索の上限を超えました。');
  let best=null, distance=Infinity;
  for(let mask=0;mask<2**state.length;mask++){
    const candidate=state.map((_,i)=>(mask>>i)&1),d=candidate.filter((v,i)=>v!==state[i]).length;
    if(d<distance&&trace(level,candidate).solved){best=candidate;distance=d;}
  }
  return best?best.findIndex((v,i)=>v!==state[i]):null;
}
