import test from 'node:test';
import assert from 'node:assert/strict';
import { GameRecording } from '../../web/labs/jev-mario/recording.mjs';

function setup(options={}) {
  const tracks=[{stopped:false,stop(){this.stopped=true;}}];
  const stream={getTracks:()=>tracks,addTrack:t=>tracks.push(t)};
  let timer, result, failure;
  class Recorder {
    static isTypeSupported(t){return t.startsWith('video/webm');}
    constructor(_,opts){this.mimeType=opts.mimeType;this.state='inactive';}
    start(){this.state='recording';}
    stop(){this.state='inactive';this.ondataavailable({data:new Blob(['encoded-video'])});this.onstop();}
  }
  const recording=new GameRecording({canvas:{captureStream:()=>stream},Recorder,
    schedule:f=>{timer=f;return 1;},cancel:()=>{},ready:(...r)=>result=r,failed:e=>failure=e,...options});
  return {recording,tracks,expire:()=>timer(),result:()=>result,failure:()=>failure};
}
test('time limit finalizes once and releases capture and audio',()=>{
  const t=setup();let released=0;
  const sound={stop(){this.stopped=true;}};
  assert.equal(t.recording.start({stream:{getAudioTracks:()=>[sound]},release:()=>released++}),true);
  t.expire();t.recording.stop();
  assert.equal(released,1);assert.ok(t.tracks.every(x=>x.stopped));
  assert.equal(t.result()[1],'webm');assert.match(t.result()[2],/60秒/);
  assert.equal(t.recording.active,false);assert.equal(t.recording.finishing,false);
  assert.equal(t.recording.start(),true);t.recording.stop();
});
test('size bound rejects incomplete output and allows a retry',()=>{
  const t=setup({maxBytes:3});t.recording.start();t.recording.stop();
  assert.match(t.failure(),/容量/);assert.equal(t.result(),undefined);assert.ok(t.tracks.every(x=>x.stopped));
  t.recording.maxBytes=100;t.recording.start();t.recording.stop();assert.ok(t.result()[0].size>0);
});
test('unsupported recording does not retain audio; start errors release tracks',()=>{
  const t=setup({Recorder:null});let released=0;
  assert.equal(t.recording.start({release:()=>released++}),false);assert.equal(released,1);assert.match(t.failure(),/対応/);
  class Broken {static isTypeSupported(){return true;}constructor(){throw Error('encoder failed');}}
  const b=setup({Recorder:Broken});assert.equal(b.recording.start(),false);assert.ok(b.tracks.every(x=>x.stopped));
});
