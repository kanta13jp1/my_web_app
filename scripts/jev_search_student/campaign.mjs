// Fixed 60 Hz campaign frames for experiments, mirroring the lab: a cleared
// course plays its 180-frame presentation, then advanceStage() keeps score,
// coins, lives and power. Controls are ignored during the presentation.
export function tick(g,action,lastCourse=2){
 g.clock=(g.clock??0)+1;
 if(g.phase==='playing'){
  g.buttons(action);g.step();
  if(g.phase!=='playing')(g.stageResults??=[]).push({course:g.stage,phase:g.phase,frames:g.frames,clock:g.clock,x:+g.p.x.toFixed(2)});
  return;
 }
 if(g.phase==='won'&&g.stage<lastCourse){
  g.presentationStep();
  if(g.presentation>=180){const keep={clock:g.clock,stageResults:g.stageResults};g.advanceStage();Object.assign(g,keep);}
 }
}
export const finished=(g,lastCourse=2)=>g.phase==='dead'||(g.phase==='won'&&g.stage>=lastCourse);
export const cleared=(g,lastCourse=2)=>g.phase==='won'&&g.stage>=lastCourse;
