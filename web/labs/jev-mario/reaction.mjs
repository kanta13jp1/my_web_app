// Optional local rules, not Jev inference. Times are predictions at 60 simulation Hz.
export function hazards(world) {
  const p=world.p,forward=Math.max(0,p.vx),feet=p.y+p.h;
  const enemy=world.enemies.filter(e=>!e.dead&&e.x>=p.x&&Math.abs(e.y+e.h-feet)<24)
    .map(e=>({gap:e.x-p.x-p.w,closing:forward-e.vx})).filter(e=>e.closing>0)
    .sort((a,b)=>a.gap-b.gap)[0];
  const contact=enemy?Math.max(0,enemy.gap)/enemy.closing*1000/60:null;
  const reach=Math.max(12,forward*12),col=Math.floor((p.x+p.w+reach)/16),row=Math.floor((feet+1)/16);
  return {enemy_gap:enemy?.gap??null,contact_ms:contact,
    gap_ahead:p.grounded&&!world.solid(col,row)&&!world.solid(col,row+1),
    wall_ahead:p.grounded&&world.solid(Math.floor((p.x+p.w+4)/16),Math.floor((feet-4)/16))};
}
export class ReactionAssist {
  reset(){this.jumping=false;}
  decide(world,proposed){
    const hazard=hazards(world);
    if(world.phase!=='playing'||!proposed.startsWith('right')){this.reset();return {action:proposed,reason:null,hazard};}
    const jump=proposed.includes('run')?'right_run_jump':'right_jump';
    const released=proposed.includes('run')?'right_run':'right';
    if(this.jumping){
      if(!world.p.grounded)return {action:jump,reason:'local_jump_hold',hazard};
      this.jumping=false;
      // Release A once after landing so the next jump can have a rising edge.
      return {action:released,reason:'local_jump_release',hazard};
    }
    const reason=hazard.contact_ms!==null&&hazard.contact_ms<260?'enemy':hazard.gap_ahead?'gap':hazard.wall_ahead?'wall':null;
    if(world.p.grounded&&reason){this.jumping=true;return {action:jump,reason:'local_'+reason,hazard};}
    return {action:proposed,reason:null,hazard};
  }
}

// Linear estimate only: no terrain/enemy activation/acceleration simulation.
export function prediction(world,previous=0){
 const p=world.p,horizon=Math.max(0,Math.min(3000,previous||1000)),h=hazards(world);
 const e=world.enemies.filter(e=>!e.dead&&e.x>=p.x&&e.x-p.x<256&&Math.abs(e.y+e.h-p.y-p.h)<24).sort((a,b)=>a.x-b.x)[0];
 const gap=e?e.x-p.x-p.w:null,closing=e?Math.max(0,p.vx)-e.vx:0;
 const contact=speed=>e&&speed>0?Math.min(10000,Math.max(0,gap)/speed*1000/60):null;
 return {horizon_ms:horizon,jump_pressed:!!world.input.jump,run_pressed:!!world.input.run,
  gap_ahead:h.gap_ahead,wall_ahead:h.wall_ahead,enemy_gap:gap,enemy_vx:e?.vx??null,
  contact_ms:contact(closing),run_contact_ms:contact(e?2.6-e.vx:0),
  projected_gap:e?Math.max(-65535,Math.min(65535,gap-closing*horizon*60/1000)):null};
}
