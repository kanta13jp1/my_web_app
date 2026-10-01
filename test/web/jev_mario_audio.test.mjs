import test from 'node:test';
import assert from 'node:assert/strict';
import { GameAudio, effects, musicStep, arrangements, MAX_VOICES, MAX_MUSIC_VOICES } from '../../web/labs/jev-mario/audio.mjs';
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
  for(let i=0;i<100;i++)a.effect('clear');assert.ok(a.nodes.size<=32);
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
 c.currentTime+=1;a.tick('castle');assert.equal(a.track,'castle');assert.ok(a.music.size>0);
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

test('lead and accompaniment cache distinct pulse duties and skid remains bounded',async()=>{
 const c=context();let waves=0;c.createPeriodicWave=()=>{waves++;return {};};const old=c.createOscillator.bind(c);c.createOscillator=()=>Object.assign(old(),{setPeriodicWave(){}});
 const a=new GameAudio(()=>c);await a.enable(true);a.tone(60,1,.1,'square',.02,true,0,.25);a.tone(67,1,.1,'square',.02,true,0,.5);a.tone(69,1,.1,'square',.02,true,0,.5);assert.equal(waves,2);a.effect('skid');a.stop();assert.equal(a.nodes.size,0);
});

test('effects duck music only and disabling audio restores its level',async()=>{
 const c=context(),a=new GameAudio(()=>c);await a.enable(true);const values=[];a.musicGain.gain.cancelScheduledValues=t=>values.push(['cancel',t]);a.musicGain.gain.setValueAtTime=(v,t)=>values.push(['set',v,t]);a.musicGain.gain.linearRampToValueAtTime=(v,t)=>values.push(['ramp',v,t]);
 a.effect('coin');assert.ok(values.some(v=>v[0]==='set'&&v[1]===.35));assert.ok(values.some(v=>v[0]==='ramp'&&v[1]===1));assert.equal(a.master.gain.value,1);a.effect('impact');await a.enable(false);assert.equal(a.musicGain.gain.value,1);assert.equal(a.nodes.size,0);
});

test('late animation frames resume music without replaying a burst of overdue beats',async()=>{
 const c=context(),a=new GameAudio(()=>c);await a.enable(true);a.tick();const beat=a.beat;
 c.currentTime=a.next+.20;a.tick();assert.equal(a.beat,beat+1);
 const fresh=c.oscillators.filter(o=>!o.stopped);assert.ok(fresh.every(o=>o.started<=a.next));
 a.stop();assert.equal(a.nodes.size,0);
});


test('fireworks synthesize a bounded burst and mute releases it',async()=>{
 const c=context(),a=new GameAudio(()=>c);await a.enable(true);let bursts=0;a.noise=(_t,duration)=>{bursts++;assert.equal(duration,.16);};a.effect('firework');assert.equal(bursts,1);assert.equal(c.oscillators.length,1);await a.enable(false);assert.equal(a.nodes.size,0);
});

test('every room has independent nine-part harmony, stable tempo and retained mute',async()=>{
 for(const track of Object.keys(arrangements)){
  const a=musicStep(track,0),b=musicStep(track,16);assert.ok(a.lead>0&&a.harmony>0&&a.bass>0&&a.counter>0&&a.pad>0&&a.fifth>0&&a.answer>0&&a.bell>0&&a.accent>0);assert.notEqual(a.bass,b.bass);assert.ok(musicStep(track,0,true).step<a.step);
  const c=context(),audio=new GameAudio(()=>c);await audio.enable(true);audio.tick(track,{star:track==='star'});assert.ok(c.oscillators.length>=6,track);audio.stop();assert.equal(audio.nodes.size,0);
 }
 assert.notDeepEqual(arrangements.castle.chords,arrangements.overworld.chords);
});

test('seventh answer part enters on the offbeat and releases on mute',async()=>{const c=context(),a=new GameAudio(()=>c);await a.enable(true);a.tick('overworld');const scheduled=[];a.tone=(...args)=>scheduled.push(args);a.beat=2;a.next=c.currentTime;a.tick('overworld');const note=musicStep('overworld',2);assert.ok(scheduled.some(x=>x[0]===note.answer&&x[1]>c.currentTime&&x[3]==='triangle'));await a.enable(false);assert.equal(a.nodes.size,0);});

test('eighth bell answers the phrase with a quiet bounded voice',async()=>{const c=context(),a=new GameAudio(()=>c);await a.enable(true);a.tick('underwater');const scheduled=[];a.tone=(...args)=>scheduled.push(args);a.beat=6;a.next=c.currentTime;a.tick('underwater');const n=musicStep('underwater',6);assert.ok(scheduled.some(x=>x[0]===n.bell&&x[3]==='sine'&&x[4]<=.014));await a.enable(false);assert.equal(a.nodes.size,0);});

test('ninth chord accent is short, restrained and default volume is one hundred percent',async()=>{const c=context(),a=new GameAudio(()=>c);assert.equal(a.volume,1);await a.enable(true);a.tick();const scheduled=[];a.tone=(...args)=>scheduled.push(args);a.beat=3;a.next=c.currentTime;a.tick();const n=musicStep('overworld',3);assert.ok(scheduled.some(x=>x[0]===n.accent&&x[3]==='square'&&x[4]<=.010&&x[2]<n.step));await a.enable(false);assert.equal(a.nodes.size,0);});

test('eleventh transition voice stays short and bounded',async()=>{const c=context(),a=new GameAudio(()=>c);await a.enable(true);a.tick();const scheduled=[];a.tone=(...args)=>scheduled.push(args);a.beat=15;a.next=c.currentTime;a.tick();const n=musicStep('overworld',15);assert.ok(n.echo>0&&n.turn>0);assert.ok(scheduled.some(x=>x[0]===n.turn&&x[3]==='triangle'&&x[4]<=.007&&x[2]<n.step));await a.enable(false);assert.equal(a.nodes.size,0);});

test('twelfth pickup voice is quiet and short',async()=>{const c=context(),a=new GameAudio(()=>c);await a.enable(true);a.tick();const scheduled=[];a.tone=(...args)=>scheduled.push(args);a.beat=13;a.next=c.currentTime;a.tick();const n=musicStep('overworld',13);assert.ok(scheduled.some(x=>x[0]===n.pickup&&x[3]==='sine'&&x[4]<=.006&&x[2]<n.step));});


test('sixteen-part arrangement staggers the four new voices and mute releases them',async()=>{for(const [key,beat,type,gain]of [['reply',9,'triangle',.006],['lowAnswer',5,'triangle',.010],['spark',21,'sine',.004],['cadence',29,'sine',.006]]){const c=context(),a=new GameAudio(()=>c);await a.enable(true);a.tick();const calls=[];a.tone=(...args)=>calls.push(args);a.beat=beat;a.next=c.currentTime;a.tick();const n=musicStep('overworld',beat);assert.ok(calls.some(x=>x[0]===n[key]&&x[3]===type&&x[4]===gain&&x[1]>c.currentTime&&x[2]<n.step));await a.enable(false);assert.equal(a.nodes.size,0);}});


test('32 voice budget reserves eight effect voices and displaces music instead of dropping an effect',async()=>{const c=context(),a=new GameAudio(()=>c);await a.enable(true);for(let i=0;i<40;i++)a.tone(60,1,1,'triangle',.01,true);assert.equal(a.music.size,MAX_MUSIC_VOICES);for(let i=0;i<8;i++)a.tone(80,1,.1,'square',.03,false);assert.equal(a.nodes.size,MAX_VOICES);const music=[...a.music];a.tone(84,1,.1,'square',.03,false);assert.equal(a.nodes.size,32);assert.equal(a.music.size,23);assert.ok(music[0].stopped);await a.enable(false);assert.equal(a.nodes.size,0);assert.equal(a.music.size,0);});
