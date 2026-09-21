import test from 'node:test';
import assert from 'node:assert/strict';
import { GameAudio, effects } from '../../web/labs/jev-mario/audio.mjs';
import { World11 } from '../../web/labs/jev-mario/world11.mjs';
test('noise percussion reuses one buffer and stops with music or mute',async()=>{
 const c=context();let buffers=0;const sources=[];c.sampleRate=48000;
 c.createBuffer=(_,n)=>{buffers++;return {getChannelData:()=>new Float32Array(n)};};
 c.createBufferSource=()=>{const o={connect(){},disconnect(){},start(){},stop(){this.stopped=true;}};sources.push(o);return o;};
 const a=new GameAudio(()=>c);await a.enable(true);a.noise(1,.035,.01,true);a.noise(1,.075,.03,false);
 assert.equal(buffers,1);assert.equal(a.nodes.size,2);a.stopMusic();assert.equal(a.nodes.size,1);assert.ok(sources[0].stopped);
 await a.enable(false);assert.equal(a.nodes.size,0);assert.ok(sources.every(s=>s.stopped));
});
function context(){
  const oscillators=[];
  return {state:'running',currentTime:1,destination:{},oscillators,resume:async()=>{},
    createGain:()=>({gain:{value:0,setValueAtTime(){},linearRampToValueAtTime(){},exponentialRampToValueAtTime(){}},connect(){},disconnect(){}}),
    createOscillator(){const o={frequency:{value:0},connect(){},disconnect(){},start(t){this.started=t;},stop(){this.stopped=true;}};oscillators.push(o);return o;}};
}
test('audio is opt-in, bounded, muted and reusable after stop',async()=>{
  const ctx=context();let created=0;const a=new GameAudio(()=>{created++;return ctx;});
  a.tick();a.effect('jump');assert.equal(created,0);
  await a.enable(true);a.tick();a.effect('coin');assert.ok(ctx.oscillators.length>=4);
  a.setVolume(999);assert.equal(a.master.gain.value,1);a.setVolume(0);assert.equal(a.master.gain.value,0);
  for(let i=0;i<100;i++)a.effect('clear');assert.ok(a.nodes.size<=48);
  await a.enable(false);assert.equal(a.nodes.size,0);assert.ok(ctx.oscillators.every(o=>o.stopped));
  const count=ctx.oscillators.length;a.tick();a.effect('jump');assert.equal(ctx.oscillators.length,count);
  await a.enable(true);a.tick();assert.equal(created,1);assert.ok(a.nodes.size>0);
});
test('unsupported audio fails without affecting game',async()=>{
  const a=new GameAudio(()=>{throw new Error('unavailable');});assert.equal(await a.enable(true),false);a.tick();a.stop();
});
test('world emits one jump per liftoff, coin once, and terminal events once',()=>{
  const w=new World11();w.input.jump=true;w.step();assert.deepEqual(w.drainSounds(),['jump']);
  w.step();assert.deepEqual(w.drainSounds(),[]);
  w.hitBlock(16,9);assert.ok(w.drainSounds().includes('coin'));w.hitBlock(16,9);assert.deepEqual(w.drainSounds(),[]);
  w.die();w.die();assert.deepEqual(w.drainSounds(),['death']);w.reset();assert.deepEqual(w.drainSounds(),[]);
  w.p.x=198*16;w.step();assert.ok(w.drainSounds().includes('flag'));
  for(const name of ['jump','coin','bump','break','item','stomp','hurt','pipe','death','clear'])assert.ok(effects[name].length);
});

test('room/star themes switch, hurry speeds sequence, terminal stingers stop music',async()=>{
 const c=context(),a=new GameAudio(()=>c);await a.enable(true);a.tick();assert.equal(a.track,'overworld');
 c.currentTime+=1;a.tick('underground');assert.equal(a.track,'underground');
 c.currentTime+=1;a.tick('overworld',{star:true});assert.equal(a.track,'star');
 const old=[...a.music];a.effect('death');assert.equal(a.music.size,0);assert.ok(old.every(o=>o.stopped));
 const count=c.oscillators.length;a.tick();assert.equal(c.oscillators.length,count);
 a.stop();a.tick('overworld',{hurry:true});assert.ok(a.next-c.currentTime<.145);
});


test('pulse voice is cached and new item/life sounds release bounded nodes',async()=>{
 const c=context();let waves=0,applied=0;c.createPeriodicWave=(real,imag)=>{waves++;assert.equal(real.length,33);assert.equal(imag.length,33);return {};};
 const factory=c.createOscillator.bind(c);c.createOscillator=()=>{const o=factory();o.setPeriodicWave=()=>applied++;return o;};
 const a=new GameAudio(()=>c);await a.enable(true);a.effect('appear');a.effect('life');assert.equal(waves,1);assert.ok(applied>=10);
 a.stop();assert.equal(a.nodes.size,0);assert.ok(c.oscillators.every(o=>o.stopped));
});
