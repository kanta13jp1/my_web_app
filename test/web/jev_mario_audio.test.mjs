import test from 'node:test';
import assert from 'node:assert/strict';
import { GameAudio, effects, musicStep, arrangements, MAX_VOICES, MAX_MUSIC_VOICES, scores, MOTIF, ostinatoStep, bassStep, leadLayers } from '../../web/labs/jev-mario/audio.mjs';
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
  for(let i=0;i<100;i++)a.effect('clear');assert.ok(a.nodes.size<=MAX_VOICES);
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


test('64 voice budget reserves sixteen effect voices and displaces music instead of dropping an effect',async()=>{const c=context(),a=new GameAudio(()=>c);await a.enable(true);for(let i=0;i<80;i++)a.tone(60,1,1,'triangle',.01,true);assert.equal(a.music.size,MAX_MUSIC_VOICES);for(let i=0;i<16;i++)a.tone(80,1,.1,'square',.03,false);assert.equal(a.nodes.size,MAX_VOICES);const music=[...a.music];a.tone(84,1,.1,'square',.03,false);assert.equal(a.nodes.size,64);assert.equal(a.music.size,47);assert.ok(music[0].stopped);await a.enable(false);assert.equal(a.nodes.size,0);assert.equal(a.music.size,0);});

test('fixed preamp raises the default output while slider mute still controls the master',async()=>{const c=context(),a=new GameAudio(()=>c);await a.enable(true);assert.equal(a.preamp.gain.value,1.8);assert.equal(a.master.gain.value,1);a.setVolume(0);assert.equal(a.master.gain.value,0);a.setVolume(.4);assert.equal(a.master.gain.value,.4);assert.equal(a.preamp.gain.value,1.8);await a.enable(false);assert.equal(a.nodes.size,0);});

test('four-note hook repeats at new register with alternating lead instruments',()=>{assert.deepEqual(MOTIF,[0,3,5,3]);for(const track of Object.keys(scores)){const first=scores[track].slice(0,4);assert.deepEqual(first.map(n=>n-first[0]),MOTIF);assert.deepEqual(scores[track].slice(8,12),first.map(n=>n+12));assert.deepEqual(scores[track].slice(16,20),first);assert.notEqual(musicStep(track,0).leadType,musicStep(track,16).leadType);assert.notDeepEqual(scores[track].slice(12,16),scores[track].slice(28,32));}});

test('ostinato repeats sixteenths below the melody and water uses eighths',()=>{
 const first=ostinatoStep('overworld',0),step=musicStep('overworld',0).step;
 assert.equal(first.length,2);assert.equal(first[1].offset,step/2);
 assert.deepEqual(Array.from({length:4},(_,i)=>ostinatoStep('overworld',i)).flat().map(n=>n.note),[60,67,64,67,60,64,67,64]);
 assert.deepEqual(ostinatoStep('overworld',4),first);
 assert.ok(ostinatoStep('overworld',0,true)[1].offset<first[1].offset);
 assert.equal(ostinatoStep('underwater',0).length,1);
});
test('water melody sustains above moving accompaniment; switching and mute release every voice',async()=>{
 const c=context(),a=new GameAudio(()=>c);await a.enable(true);a.tick('underwater');
 const calls=[];a.tone=(...args)=>calls.push(args);a.beat=2;a.next=c.currentTime;a.tick('underwater');
 const n=musicStep('underwater',2);assert.ok(calls.some(x=>x[0]===scores.underwater[1]&&x[2]>n.step));
 calls.length=0;a.beat=3;a.next=c.currentTime;a.tick('underwater');assert.ok(!calls.some(x=>x[0]===musicStep('underwater',3).lead&&x[4]===.052));
 await a.enable(false);assert.equal(a.nodes.size,0);
});

test('syncopation anticipates the next chord bass and phrase lead, without duplicate attacks',async()=>{
 const c=context(),a=new GameAudio(()=>c);await a.enable(true);a.tick('overworld');
 const calls=[];a.tone=(...args)=>calls.push(args);a.beat=15;a.next=c.currentTime;a.tick('overworld');
 const current=musicStep('overworld',15),next=musicStep('overworld',16);
 const bass=calls.find(x=>x[4]===.105),lead=calls.find(x=>x[4]===.052&&x[0]>0);
 assert.equal(bass[0],next.bass);assert.notEqual(bass[0],current.bass);
 assert.equal(lead[0],next.lead);assert.equal(lead[3],next.leadType);
 for(const n of [bass,lead]){assert.ok(n[1]>c.currentTime&&n[1]<c.currentTime+current.step);assert.ok(n[1]+n[2]>c.currentTime+current.step);}
 calls.length=0;a.beat=16;a.next=c.currentTime;a.tick('overworld');assert.ok(!calls.some(x=>x[4]===.105||x[4]===.052));
 await a.enable(false);assert.equal(a.nodes.size,0);
});
test('offbeat accompaniment accents repeat while water keeps its softer regular rhythm',()=>{
 const notes=ostinatoStep('overworld',0);assert.ok(notes[1].gain>notes[0].gain);assert.ok(notes[1].offset>0);
 assert.ok(ostinatoStep('overworld',1)[0].gain>notes[0].gain);
 assert.equal(ostinatoStep('underwater',0)[0].gain,ostinatoStep('underwater',1)[0].gain);
});


test('castle moves Em C D B major and resolves D sharp to E on the loop',()=>{
 assert.deepEqual(arrangements.castle.chords,[[40,43,47],[36,40,43],[38,42,45],[35,39,42]]);
 assert.deepEqual(scores.castle.slice(0,4),[64,67,69,67]);
 assert.deepEqual(scores.castle.slice(32,36),[62,66,69,66]);
 assert.deepEqual(scores.castle.slice(48,52),[59,63,66,63]);
 assert.equal(musicStep('castle',62).lead,63);
 assert.equal(musicStep('castle',64).lead,64);
 assert.deepEqual([0,16,32,48,64].map(b=>musicStep('castle',b).bass),[40,36,38,35,40]);
 assert.equal(ostinatoStep('castle',48)[0].note,47);
 assert.ok(Array.from({length:8},(_,i)=>ostinatoStep('castle',48+i)).flat().some(e=>e.note===51));
});


test('bass groove answers an octave up, rests, and approaches the next root',()=>{
 assert.equal(bassStep('castle',0)[0].note,40);
 assert.equal(bassStep('castle',2)[0].note,52);
 assert.ok(bassStep('castle',2)[0].duration<musicStep('castle',2).step);
 assert.deepEqual(bassStep('castle',6),[]);
 assert.equal(bassStep('castle',62)[0].note,39);
 assert.equal(bassStep('castle',63)[0].note,40);
 assert.ok(bassStep('castle',62)[0].offset<bassStep('castle',63)[0].offset);
 assert.ok(bassStep('overworld',3,true)[0].offset<bassStep('overworld',3)[0].offset);
 assert.equal(bassStep('underwater',2)[0].note,48);
 assert.ok(bassStep('underwater',2)[0].duration>musicStep('underwater',2).step);
 assert.deepEqual(bassStep('underwater',3),[]);
});


test('contrasting bass and pluck cache distinct spectra and release within the voice budget',async()=>{
 const c=context(),spectra=[];c.createPeriodicWave=(r,i)=>{spectra.push([...i]);return {id:spectra.length};};
 const old=c.createOscillator.bind(c);c.createOscillator=()=>Object.assign(old(),{setPeriodicWave(w){this.wave=w;}});
 const a=new GameAudio(()=>c);await a.enable(true);
 for(let i=0;i<80;i++)a.tone(48,1,.3,i%2?'bass':'pluck',.01,true);
 assert.equal(spectra.length,2);assert.notDeepEqual(spectra[0],spectra[1]);assert.equal(a.music.size,MAX_MUSIC_VOICES);
 a.effect('coin');assert.ok(a.nodes.size<=MAX_VOICES);await a.enable(false);assert.equal(a.nodes.size,0);
});
test('the pulse lead remains the principal voice while backing uses contrasting timbres',async()=>{
 const c=context(),a=new GameAudio(()=>c);await a.enable(true);a.track='overworld';a.next=c.currentTime;const calls=[];a.tone=(...args)=>calls.push(args);a.tick();
 assert.ok(calls.some(x=>x[3]==='square'&&x[4]===.052));assert.ok(calls.some(x=>x[3]==='bass'&&x[4]===.105));assert.ok(calls.some(x=>x[3]==='pluck'&&x[4]<.052));
});


test('octave layers are reserved for the phrase climax and nearby castle boss',()=>{
 assert.deepEqual(leadLayers('overworld',0),[]);assert.deepEqual(leadLayers('overworld',48).map(x=>x.interval),[12]);assert.deepEqual(leadLayers('overworld',64),[]);
 assert.deepEqual(leadLayers('castle',0,true).map(x=>x.interval),[12,-12]);assert.deepEqual(leadLayers('castle',0,false),[]);assert.deepEqual(leadLayers('underwater',48,true),[]);
});
test('octave layers share anticipated lead timing and silence its duplicate grid attack',async()=>{
 const c=context(),a=new GameAudio(()=>c);await a.enable(true);a.track='castle';a.beat=47;a.next=c.currentTime;const calls=[];a.tone=(...args)=>calls.push(args);a.tick('castle',{boss:true});
 const lead=calls.find(x=>x[4]===.052&&x[0]>0);assert.ok(lead);for(const [offset,gain]of [[12,.018],[-12,.012]]){const layer=calls.find(x=>x[4]===gain&&x[0]===lead[0]+offset&&x[1]===lead[1]);assert.ok(layer);assert.equal(layer[2],lead[2]);}
 calls.length=0;a.beat=48;a.next=c.currentTime;a.tick('castle',{boss:true});assert.ok(!calls.some(x=>[.052,.018,.012].includes(x[4])&&x[1]===c.currentTime));
});

test('climax breath removes bass and percussion for one beat but preserves lead and return',async()=>{
 const c=context(),a=new GameAudio(()=>c);await a.enable(true);a.track='overworld';const tones=[],drums=[];a.tone=(...x)=>tones.push(x);a.noise=(...x)=>drums.push(x);
 for(const beat of [46,47]){tones.length=0;drums.length=0;a.beat=beat;a.next=c.currentTime;a.tick();assert.ok(!tones.some(x=>x[3]==='bass'||x[4]===.055));assert.equal(drums.length,0);assert.ok(tones.length>0);}
 tones.length=0;a.beat=48;a.next=c.currentTime;a.tick();assert.ok(tones.some(x=>x[4]===.055));assert.ok(tones.some(x=>x[3]==='pluck'));
 tones.length=0;a.effect('coin');assert.ok(tones.some(x=>x[5]!==true));
});

import {bossAccent} from '../../web/labs/jev-mario/audio.mjs';
test('boss accents group eight eighths as three plus three plus two',()=>{
 const hits=Array.from({length:17},(_,i)=>i).filter(bossAccent);assert.deepEqual(hits,[0,3,6,8,11,14,16]);assert.deepEqual(hits.slice(1).map((x,i)=>x-hits[i]),[3,3,2,3,3,2]);
});
test('grouped accents sound only near a boss and respect the phrase breath',async()=>{
 const c=context(),a=new GameAudio(()=>c);await a.enable(true);a.track='castle';const notes=[];a.tone=(...x)=>notes.push(x);
 for(const boss of [false,true])for(const beat of [0,1,3,6,46,47]){notes.length=0;a.beat=beat;a.next=c.currentTime;a.tick('castle',{boss});assert.equal(notes.some(x=>x[4]===.020),boss&&[0,3,6].includes(beat));}
});
