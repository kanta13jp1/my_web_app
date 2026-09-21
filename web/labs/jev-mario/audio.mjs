// Original procedural chiptune: no downloaded audio or game soundtrack.
const melody = [72,76,79,83,79,76,74,0,71,74,77,81,77,74,72,0,
  69,72,76,79,76,72,74,77,71,74,79,77,74,71,72,0];
export const effects = {
  jump:[48,60,72], coin:[88,95], bump:[38,32], break:[43,35,28],
  item:[60,64,67,72], stomp:[48,36], hurt:[65,53,41], pipe:[55,48,41],
  fire:[65,48], death:[72,68,63,58,51,44], clear:[60,64,67,72,76,79,84],
};
export class GameAudio {
  constructor(factory = () => new (globalThis.AudioContext || globalThis.webkitAudioContext)()) {
    this.factory=factory; this.enabled=false; this.volume=.25; this.nodes=new Set(); this.beat=0; this.next=0;
  }
  async enable(value) {
    this.enabled=!!value;
    if (!value) { this.stop(); return true; }
    try {
      if (!this.context) { this.context=this.factory(); this.master=this.context.createGain(); this.master.connect(this.context.destination); }
      this.master.gain.value=this.volume;
      await this.context.resume();
      return this.context.state==='running';
    } catch { this.enabled=false; this.stop(); return false; }
  }
  setVolume(value) { this.volume=Math.max(0,Math.min(1,Number(value)||0)); if(this.master)this.master.gain.value=this.volume; }
  tone(note, time, duration, type='square', gain=.09) {
    if(!note || !this.enabled || !this.context || this.context.state!=='running' || this.nodes.size>=48)return;
    const osc=this.context.createOscillator(), env=this.context.createGain();
    osc.type=type; osc.frequency.value=440*2**((note-69)/12);
    env.gain.setValueAtTime(0,time);env.gain.linearRampToValueAtTime(gain,time+.006);
    env.gain.exponentialRampToValueAtTime(.0001,time+duration);
    osc.connect(env);env.connect(this.master);this.nodes.add(osc);
    osc.onended=()=>{osc.disconnect();env.disconnect();this.nodes.delete(osc);};
    osc.start(time);osc.stop(time+duration+.01);
  }
  // Called from the existing animation loop; no independent background timer.
  tick(room='overworld') {
    if(!this.enabled || this.context?.state!=='running')return;
    const now=this.context.currentTime;
    if(this.next<now-.25)this.next=now;
    while(this.next<now+.08){
      const n=melody[this.beat%melody.length];
      this.tone(n ? n-(room==='underground'?12:0):0,this.next,.12,'square',.055);
      if(this.beat%2===0)this.tone([48,47,45,43][Math.floor(this.beat/8)%4],this.next,.22,'triangle',.13);
      this.next+=.16;this.beat++;
    }
  }
  effect(name) {
    if(!this.enabled || !this.context)return;
    const notes=effects[name];if(!notes)return;
    const step=name==='death'||name==='clear'?.13:.055;
    notes.forEach((n,i)=>this.tone(n,this.context.currentTime+i*step,step*.95,'square',.1));
  }
  stop() {
    for(const osc of this.nodes){try{osc.stop();}catch{} osc.disconnect();}
    this.nodes.clear();this.beat=0;this.next=0;
  }
}
