// Original scores and synthesized effects; no sampled Nintendo soundtrack.
export const scores={
 overworld:[76,0,79,81,0,79,76,72,74,0,77,79,0,76,74,71,72,76,79,0,84,81,79,76,74,77,81,79,76,74,72,0,79,0,76,72,74,77,79,0,81,84,83,79,76,79,74,0,72,74,76,79,81,0,77,74,79,76,72,74,71,0,72,0],
 underground:[48,60,0,51,63,0,53,65,0,51,63,0,46,58,0,48,60,0,55,67,0,53,65,0,51,63,0,46,58,0,48,0],
 star:[84,79,88,84,91,88,86,83,89,86,93,89,88,84,91,88,86,81,89,86,88,83,91,88,84,79,88,84,83,79,86,83]
};
export const effects={jump:[48,60,72],coin:[88,95],bump:[38,32],break:[43,35,28],item:[60,64,67,72],stomp:[48,36],hurt:[65,53,41],pipe:[55,48,41],fire:[65,48],hurry:[79,84,88,84,79,84],death:[72,68,63,58,51,44],clear:[60,64,67,72,76,79,84]};
export class GameAudio{
 constructor(factory=()=>new(globalThis.AudioContext||globalThis.webkitAudioContext)()){
  this.factory=factory;this.enabled=false;this.volume=.25;this.nodes=new Set();this.music=new Set();this.beat=0;this.next=0;this.track='';this.musicUntil=0;
 }
 async enable(value){this.enabled=!!value;if(!value){this.stop();return true;}try{
  if(!this.context){this.context=this.factory();this.master=this.context.createGain();this.master.connect(this.context.destination);}
  this.master.gain.value=this.volume;await this.context.resume();return this.context.state==='running';
 }catch{this.enabled=false;this.stop();return false;}}
 setVolume(v){this.volume=Math.max(0,Math.min(1,Number(v)||0));if(this.master)this.master.gain.value=this.volume;}
 tone(note,time,duration,type='square',gain=.09,music=false,slide=0){
  if(!note||!this.enabled||this.context?.state!=='running'||this.nodes.size>=48)return;
  const osc=this.context.createOscillator(),env=this.context.createGain();osc.type=type;
  osc.frequency.value=440*2**((note-69)/12);
  if(slide&&osc.frequency.exponentialRampToValueAtTime){osc.frequency.setValueAtTime(osc.frequency.value,time);osc.frequency.exponentialRampToValueAtTime(440*2**((note+slide-69)/12),time+duration);}
  env.gain.setValueAtTime(0,time);env.gain.linearRampToValueAtTime(gain,time+.004);env.gain.exponentialRampToValueAtTime(.0001,time+duration);
  osc.connect(env);env.connect(this.master);this.nodes.add(osc);if(music)this.music.add(osc);
  osc.onended=()=>{osc.disconnect();env.disconnect();this.nodes.delete(osc);this.music.delete(osc);};osc.start(time);osc.stop(time+duration+.01);
 }
 stopMusic(){for(const o of this.music){try{o.stop();}catch{}o.disconnect();this.nodes.delete(o);}this.music.clear();}
 tick(room='overworld',{star=false,hurry=false}={}){
  if(!this.enabled||this.context?.state!=='running')return;
  const now=this.context.currentTime;if(now<this.musicUntil)return;
  const track=star?'star':room==='underground'?'underground':'overworld';
  if(track!==this.track){this.stopMusic();this.track=track;this.beat=0;this.next=now;}
  if(this.next<now-.25)this.next=now;
  const step=(track==='star'?.095:track==='underground'?.18:.145)*(hurry?.78:1),melody=scores[track];
  while(this.next<now+.08){const n=melody[this.beat%melody.length],root=[48,45,53,43][Math.floor(this.beat/16)%4];
   this.tone(n,this.next,step*.8,'square',.045,true);
   if(track==='overworld'&&this.beat%4===2)this.tone(n?n-12:0,this.next,step*.65,'square',.025,true);
   if(this.beat%2===0)this.tone(track==='underground'?36:root+(this.beat%4===2?7:0),this.next,step*1.6,'triangle',.10,true);
   // Short low pulse supplies a bounded percussion voice.
   if(this.beat%4===0)this.tone(32,this.next,.035,'triangle',.06,true,-12);
   this.next+=step;this.beat++;
  }
 }
 effect(name){if(!this.enabled||!this.context)return;const notes=effects[name];if(!notes)return;
  const terminal=name==='death'||name==='clear',step=terminal?.13:name==='pipe'?.075:.055;
  if(terminal||name==='hurry'){this.stopMusic();this.musicUntil=this.context.currentTime+notes.length*step+.08;}
  if(name==='jump'){this.tone(48,this.context.currentTime,.17,'square',.08,false,24);return;}
  if(name==='fire'){this.tone(70,this.context.currentTime,.09,'square',.06,false,-30);return;}
  notes.forEach((n,i)=>this.tone(n,this.context.currentTime+i*step,step*.95,name==='bump'||name==='stomp'?'triangle':'square',.09));
 }
 stop(){for(const o of this.nodes){try{o.stop();}catch{}o.disconnect();}this.nodes.clear();this.music.clear();this.beat=0;this.next=0;this.track='';this.musicUntil=0;}
}
