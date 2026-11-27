// Local canvas capture only: no camera, microphone, display capture or upload.
export class GameRecording {
  constructor({ canvas, changed = () => {}, ready = () => {}, failed = () => {},
    Recorder = globalThis.MediaRecorder, schedule = (fn, ms) => setTimeout(fn, ms), cancel = id => clearTimeout(id),
    maxMs = 60000, maxBytes = 32 * 1024 * 1024 }) {
    Object.assign(this, { canvas, changed, ready, failed, Recorder, schedule, cancel, maxMs, maxBytes });
    this.active = false; this.finishing = false;
  }
  get supported() { return !!this.Recorder && typeof this.canvas.captureStream === 'function'; }
  start(audio = null) {
    if (this.active || this.finishing) { audio?.release(); return false; }
    let video, recorder;
    try {
      if (!this.supported) throw new Error('このブラウザは録画に対応していません。');
      video = this.canvas.captureStream(this.canvas.width>=1280?60:30);
      const tracks = audio?.stream.getAudioTracks() ?? [];
      for (const track of tracks) video.addTrack(track);
      const types = tracks.length ? ['video/webm;codecs=vp8,opus', 'video/webm', 'video/mp4'] : ['video/webm;codecs=vp8', 'video/webm', 'video/mp4'];
      const mimeType = types.find(t => this.Recorder.isTypeSupported(t));
      if (!mimeType) throw new Error('保存できる動画形式がありません。別のブラウザをお試しください。');
      recorder = new this.Recorder(video, { mimeType, videoBitsPerSecond: this.canvas.width>=1280?4000000:1500000 });
      const chunks = []; let bytes = 0, error = null;
      this.recorder = recorder; this.active = true; this.reason = '録画を停止しました';
      recorder.ondataavailable = e => {
        if (!e.data.size) return;
        if (bytes + e.data.size > this.maxBytes) { error = '録画容量の上限を超えました。短い録画で再試行してください。'; this.stop(error); return; }
        chunks.push(e.data); bytes += e.data.size;
      };
      recorder.onerror = () => { error = '録画中にエラーが発生しました。もう一度お試しください。'; this.stop(error); };
      recorder.onstop = () => {
        this.cancel(this.timer); video.getTracks().forEach(t => t.stop()); audio?.release();
        this.active = false; this.finishing = false; this.recorder = null;
        if (error || !bytes) this.failed(error || '動画を保存できませんでした。少し長く録画して再試行してください。');
        else {
          const type = recorder.mimeType || mimeType;
          this.ready(new Blob(chunks, { type }), type.includes('mp4') ? 'mp4' : 'webm', this.reason);
        }
        this.changed();
      };
      recorder.start(1000);
      this.timer = this.schedule(() => this.stop('60秒の上限で録画を停止しました'), this.maxMs);
      this.changed(); return true;
    } catch (e) {
      if(recorder){recorder.ondataavailable=null;recorder.onstop=null;recorder.onerror=null;if(recorder.state!=='inactive')try{recorder.stop();}catch{}}
      this.cancel(this.timer);
      video?.getTracks().forEach(t => t.stop()); audio?.release();
      this.active = false; this.finishing = false; this.recorder = null;
      this.failed(e.message || '録画を開始できませんでした'); this.changed(); return false;
    }
  }
  stop(reason = '録画を停止しました') {
    if (!this.active || this.finishing) return;
    this.reason = reason; this.cancel(this.timer); this.finishing = true;
    if (this.recorder.state !== 'inactive') this.recorder.stop();
    this.changed();
  }
}
