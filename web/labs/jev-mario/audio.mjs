// Original scores and synthesized effects; no sampled Nintendo soundtrack.
export const scores={
 underwater:[72,76,79,84,79,76,74,77,81,86,81,77,71,74,79,83,79,74,72,76,79,84,0,79],
 overworld:[76,0,79,81,0,79,76,72,74,0,77,79,0,76,74,71,72,76,79,0,84,81,79,76,74,77,81,79,76,74,72,0,79,0,76,72,74,77,79,0,81,84,83,79,76,79,74,0,72,74,76,79,81,0,77,74,79,76,72,74,71,0,72,0],
 castle:[48,55,60,63,59,55,47,54,59,62,58,54,46,53,58,61,57,53,43,50,55,58,54,50,48,55,60,63,59,55,48,0],
 underground:[48,60,0,51,63,0,53,65,0,51,63,0,46,58,0,48,60,0,55,67,0,53,65,0,51,63,0,46,58,0,48,0],
 star:[84,79,88,84,91,88,86,83,89,86,93,89,88,84,91,88,86,81,89,86,88,83,91,88,84,79,88,84,83,79,86,83]
};
// Ten arranged pitched parts (not ten notes on every beat): pulse lead, chord arpeggio, soft counterline, high pad, soft chord fifth, syncopated answer, high bell, short chord accent, triangle bass; noise is percussion.
// Each room has its own harmonic progression rather than a shared major-key backing.
export const arrangements={
 overworld:{step:.145,chords:[[48,52,55],[45,48,52],[53,57,60],[43,47,50]],duty:.25},
 underground:{step:.18,chords:[[36,39,43],[34,38,41],[32,36,39],[31,35,38]],duty:.125},
 castle:{step:.13,chords:[[36,39,43],[35,38,42],[34,37,41],[31,34,38]],duty:.125},
 underwater:{step:.22,chords:[[48,52,55],[50,53,57],[43,47,50],[48,52,55]],duty:.5},
 star:{step:.095,chords:[[60,64,67],[62,65,69],[64,67,71],[59,63,66]],duty:.25}
};
export function musicStep(track,beat,hurry=false){
 const a=arrangements[track]??arrangements.overworld,chord=a.chords[Math.floor(beat/16)%a.chords.length],step=a.step*(hurry?.78:1);
 return {step,lead:scores[track]?.[beat%scores[track].length]??0,harmony:chord[[0,2,1,2][beat%4]]+12,bass:chord[beat%4===2?2:0]-(track==='star'?12:0),counter:chord[beat%8<4?1:2]+(track==='castle'?0:12),pad:chord[0]+(track==='castle'||track==='underground'?19:24),fifth:chord[2]+12,answer:chord[(Math.floor(beat/2)+1)%3]+24,bell:chord[(Math.floor(beat/4)+2)%3]+36,accent:chord[1]+24,echo:chord[2]+19,duty:a.duty};
}
export const effects={firework:[48,36],swim:[60,67],bridge:[43,38,31,24],impact:[42,30],skid:[79,67,79],flag:[84,81,79,76,72,67],tally:[84],kick:[43,31],appear:[48,53,57,60,65],life:[72,79,76,84,81,88],jump:[48,60,72],coin:[88,95],bump:[38,32],break:[43,35,28],item:[60,64,67,72],stomp:[48,36],hurt:[65,53,41],pipe:[55,48,41],fire:[65,48],hurry:[79,84,88,84,79,84],death:[72,68,63,58,51,44],clear:[60,64,67,72,76,79,84]};
export class GameAudio{
 constructor(factory=()=>new(globalThis.AudioContext||globalThis.webkitAudioContext)()){
  this.factory=factory;this.enabled=false;this.volume=.65;this.nodes=new Set();this.music=new Set();this.beat=0;this.next=0;this.track='';this.musicUntil=0;
 }
 async enable(value){this.enabled=!!value;if(!value){this.stop();return true;}try{
  if(!this.context){this.context=this.factory();this.master=this.context.createGain();if(this.context.createDynamicsCompressor){this.limiter=this.context.createDynamicsCompressor();this.limiter.threshold.value=-10;this.limiter.knee.value=8;this.limiter.ratio.value=12;this.master.connect(this.limiter);this.limiter.connect(this.context.destination);}else this.master.connect(this.context.destination);this.musicGain=this.context.createGain();this.musicGain.gain.value=1;this.musicGain.connect(this.master);}
  this.master.gain.value=this.volume;await this.context.resume();return this.context.state==='running';
 }catch{this.enabled=false;this.stop();return false;}}
 captureOutput(){
  if(!this.enabled||!this.context||!this.master)return null;
  const destination=this.context.createMediaStreamDestination();(this.limiter||this.master).connect(destination);
  return {stream:destination.stream,release:()=>{(this.limiter||this.master).disconnect(destination);destination.stream.getTracks().forEach(t=>t.stop());}};
 }
 setVolume(v){this.volume=Math.max(0,Math.min(1,Number(v)||0));if(this.master)this.master.gain.value=this.volume;}
 tone(note,time,duration,type='square',gain=.09,music=false,slide=0,duty=.25){
  if(!note||!this.enabled||this.context?.state!=='running'||this.nodes.size>=48)return;
  const osc=this.context.createOscillator(),env=this.context.createGain();osc.type=type;
  // Band-limited 25% pulse gives a second NES-like voice, with square fallback.
  if(type==='square'&&this.context.createPeriodicWave&&osc.setPeriodicWave){
    this.pulses??=new Map();if(!this.pulses.has(duty)){const real=new Float32Array(33),imag=new Float32Array(33);for(let n=1;n<33;n++){real[n]=2*Math.sin(2*Math.PI*n*duty)/(Math.PI*n);imag[n]=2*(1-Math.cos(2*Math.PI*n*duty))/(Math.PI*n);}this.pulses.set(duty,this.context.createPeriodicWave(real,imag));}
    osc.setPeriodicWave(this.pulses.get(duty));
  }
  osc.frequency.value=440*2**((note-69)/12);
  if(slide&&osc.frequency.exponentialRampToValueAtTime){osc.frequency.setValueAtTime(osc.frequency.value,time);osc.frequency.exponentialRampToValueAtTime(440*2**((note+slide-69)/12),time+duration);}
  env.gain.setValueAtTime(0,time);env.gain.linearRampToValueAtTime(gain,time+.004);env.gain.exponentialRampToValueAtTime(.0001,time+duration);
  osc.connect(env);env.connect(music?this.musicGain:this.master);this.nodes.add(osc);if(music)this.music.add(osc);
  osc.onended=()=>{osc.disconnect();env.disconnect();this.nodes.delete(osc);this.music.delete(osc);};osc.start(time);osc.stop(time+duration+.01);
 }
 noise(time,duration=.04,gain=.025,music=false){
  if(!this.enabled||this.context?.state!=='running'||!this.context.createBuffer||!this.context.createBufferSource||this.nodes.size>=48)return;
  if(!this.noiseBuffer){const n=Math.ceil(this.context.sampleRate*.08);this.noiseBuffer=this.context.createBuffer(1,n,this.context.sampleRate);const data=this.noiseBuffer.getChannelData(0);let state=1;for(let i=0;i<n;i++){state=(state>>1)|(((state^(state>>1))&1)<<14);data[i]=(state&1)?1:-1;}}
  const source=this.context.createBufferSource(),env=this.context.createGain();source.buffer=this.noiseBuffer;source.loop=true;
  env.gain.setValueAtTime(gain,time);env.gain.exponentialRampToValueAtTime(.0001,time+duration);source.connect(env);env.connect(music?this.musicGain:this.master);
  this.nodes.add(source);if(music)this.music.add(source);source.onended=()=>{source.disconnect();env.disconnect();this.nodes.delete(source);this.music.delete(source);};source.start(time);source.stop(time+duration);
 }
 stopMusic(){for(const o of this.music){try{o.stop();}catch{}o.disconnect();this.nodes.delete(o);}this.music.clear();}
 tick(room='overworld',{star=false,hurry=false}={}){
  if(!this.enabled||this.context?.state!=='running')return;
  const now=this.context.currentTime;if(now<this.musicUntil)return;
  const track=star?'star':room==='underwater'?'underwater':room==='castle'?'castle':(room==='underground'||room==='stage-underground')?'underground':'overworld';
  if(track!==this.track){this.stopMusic();this.track=track;this.beat=0;this.next=now;}
  // Do not bunch late beats together after a stalled browser frame.
  if(this.next<now)this.next=now;
  while(this.next<now+.08){
   const {step,lead,harmony,bass,counter,pad,fifth,answer,bell,accent,echo,duty}=musicStep(track,this.beat,hurry),t=this.next;
   this.tone(lead,t,step*(this.beat%4===3?.55:.82),'square',.040,true,0,duty);
   // Offbeat comping and broken triads keep the lead audible without dense chords.
   if(this.beat%2===0||track==='star')this.tone(harmony,t+step*.08,step*.65,'square',track==='underwater'?.013:.018,true,0,.5);
   if(this.beat%16===11)this.tone(echo,t+step*.6,step*.7,'triangle',.008,true);
   if(this.beat%8===3)this.tone(accent,t+step*.35,step*.5,'square',track==='castle'?.006:.010,true,0,.125);
   if(this.beat%8===6)this.tone(bell,t+step*.60,step*1.2,'sine',track==='underwater'?.014:.009,true);
   if(this.beat%4===2)this.tone(answer,t+step*.45,step*.40,'triangle',track==='castle'?.009:.014,true);
   if(this.beat%8===0)this.tone(fifth,t+step*.3,step*5.5,'sine',.012,true);
   if(this.beat%8===0)this.tone(pad,t+step*.20,step*6.5,'triangle',track==='castle'?.009:.012,true);
   if(this.beat%4===0)this.tone(counter,t+step*.16,step*3.2,'triangle',track==='underwater'?.023:.017,true);
   if(this.beat%2===0)this.tone(bass,t,step*1.55,'triangle',.085,true);
   if(track==='overworld'||track==='star'){
    if(this.beat%4===0)this.tone(32,t,.035,'triangle',.055,true,-12);
    if(this.beat%2===1)this.noise(t,this.beat%4===3?.045:.018,this.beat%4===3?.018:.009,true);
   }else if(track==='castle'&&this.beat%4===2)this.noise(t,.055,.016,true);
   else if(track==='underground'&&this.beat%8===6)this.noise(t,.022,.009,true);
   this.next+=step;this.beat++;
  }

 }
 effect(name){if(!this.enabled||!this.context)return;const notes=effects[name];if(!notes)return;
  // Briefly duck only music; effects and captured master output remain audible.
  const now=this.context.currentTime,param=this.musicGain?.gain;
  if(param?.cancelScheduledValues){param.cancelScheduledValues(now);param.setValueAtTime(.35,now);param.linearRampToValueAtTime(1,now+.18);}
  if(name==='firework'){this.noise(now,.16,.09);this.tone(48,now,.18,'triangle',.09,false,-24);return;}
  if(name==='impact'){this.noise(now,.055,.04);this.tone(42,now,.07,'triangle',.08,false,-12);return;}
  if(name==='skid'){this.noise(this.context.currentTime,.055,.035);this.tone(79,this.context.currentTime,.075,'square',.035,false,-12);return;}
  if(name==='break'){this.noise(this.context.currentTime,.075,.065);}
  const terminal=name==='death'||name==='clear'||name==='flag',step=terminal?.13:name==='life'?.10:name==='appear'?.045:name==='pipe'?.075:.055;
  if(terminal||name==='hurry'){this.stopMusic();this.musicUntil=this.context.currentTime+notes.length*step+.08;}
  if(name==='tally'){this.tone(84,this.context.currentTime,.025,'square',.035);return;}
  if(name==='kick'){this.tone(43,this.context.currentTime,.09,'triangle',.10,false,-18);return;}
  if(name==='jump'){this.tone(48,this.context.currentTime,.17,'square',.08,false,24);return;}
  if(name==='coin'){this.tone(96,now+.04,.10,'sine',.022);}
  if(name==='stomp'){this.tone(36,now,.055,'triangle',.05,false,-12);}
  if(name==='fire'){this.noise(now,.018,.016);this.tone(70,this.context.currentTime,.09,'square',.06,false,-30);return;}
  notes.forEach((n,i)=>this.tone(n,this.context.currentTime+i*step,step*.95,name==='bump'||name==='stomp'?'triangle':'square',.075));
  if(['clear','life','item'].includes(name)){
   const end=now+(notes.length-1)*step,n=notes.at(-1);
   this.tone(n-12,end,step*2.3,'triangle',.08);
   this.tone(n-5,end,step*1.8,'square',.022);
   this.tone(n-8,end,step*1.6,'triangle',.022);
   this.tone(n+7,end+step*.08,step*2.1,'triangle',.012);
  }
 }
 stop(){for(const o of this.nodes){try{o.stop();}catch{}o.disconnect();}this.nodes.clear();this.music.clear();this.beat=0;this.next=0;this.track='';this.musicUntil=0;if(this.musicGain){this.musicGain.gain.cancelScheduledValues?.(this.context.currentTime);this.musicGain.gain.value=1;}}
}
