// Lossless terrain packing; no planner output or future state is added.
export function compactRequest(state){
 if(!Array.isArray(state.tiles)||state.tiles.length!==117||state.tiles.some(t=>t!==0&&t!==84))throw Error('unsupported terrain');
 const rows=Array.from({length:13},(_,r)=>state.tiles.slice(r*9,r*9+9).map(t=>t?1:0).join(''));
 return {state:{player:state.player,enemies:state.enemies,map:rows},questions:{controller:{type:'choice',
 instructions:'Reach the flag on the right. Avoid enemies and pits; jump over obstacles. Map: 1=solid, rows world tile y=2..14, columns player tile x-2..x+6. Enemy dx is relative to player. Choose held buttons for the next 500ms. Jump starts only on a new press.',
 criteria:{noop:'Release all buttons',right:'Right',right_run:'Right + run',left:'Left',jump:'Jump',right_jump:'Right + jump',right_run_jump:'Right + run + jump'}}}};
}
