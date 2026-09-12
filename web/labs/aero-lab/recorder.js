// Browser consent is required every time. No upload, microphone or account data.
export function createRecorder(button, message, download) {
  let recorder, stream, url, timer, pending = false, disposed = false;
  const stopTracks = () => stream?.getTracks().forEach((track) => track.stop());
  const stop = () => { if (recorder?.state === 'recording') recorder.stop(); };
  const show = (text) => { if (!disposed) message.textContent = text; };
  button.onclick = async () => {
    if (recorder?.state === 'recording') { stop(); return; }
    if (pending || disposed) return;
    if (!navigator.mediaDevices?.getDisplayMedia || typeof MediaRecorder === 'undefined') {
      show('このブラウザーでは画面録画を利用できません。'); return;
    }
    pending = true; button.disabled = true;
    try {
      stream = await navigator.mediaDevices.getDisplayMedia({
        video: { frameRate: 30, displaySurface: 'browser' }, audio: false,
        selfBrowserSurface: 'include', preferCurrentTab: true,
        monitorTypeSurfaces: 'exclude', surfaceSwitching: 'exclude',
      });
      if (disposed) { stopTracks(); return; }
      if (stream.getVideoTracks()[0]?.getSettings().displaySurface !== 'browser') {
        stopTracks(); show('録画は開始していません。AERO LABのタブを選び直してください。'); return;
      }
      const mimeType = ['video/webm;codecs=vp9', 'video/webm;codecs=vp8', 'video/webm'].find((type) => MediaRecorder.isTypeSupported(type));
      if (!mimeType) { stopTracks(); show('このブラウザーはWebM録画に対応していません。EdgeまたはChromeでお試しください。'); return; }
      recorder = new MediaRecorder(stream, { ...(mimeType ? { mimeType } : {}), videoBitsPerSecond: 8_000_000 });
      const chunks = [];
      recorder.ondataavailable = (event) => { if (!disposed && event.data.size) chunks.push(event.data); };
      recorder.onstop = () => {
        clearTimeout(timer); stopTracks();
        if (disposed) return;
        button.textContent = '○ 画面を録画';
        button.classList.remove('recording');
        if (!chunks.length) { show('動画データがありません。もう一度録画してください。'); return; }
        if (url) URL.revokeObjectURL(url);
        url = URL.createObjectURL(new Blob(chunks, { type: recorder.mimeType }));
        download.href = url; download.hidden = false;
        show('録画できました。動画を保存して再生確認してください。');
      };
      recorder.onerror = () => { stop(); stopTracks(); show('録画中にエラーが発生しました。'); };
      stream.getVideoTracks()[0].onended = stop;
      recorder.start(1000);
      button.textContent = '■ 録画を停止'; button.classList.add('recording');
      show('録画中 — 最大2分。共有したタブの表示内容が記録されます。');
      timer = setTimeout(stop, 120_000);
    } catch (error) {
      stopTracks();
      show(error.name === 'NotAllowedError' ? '画面共有がキャンセルされました。' : '録画を開始できませんでした。必要なら実験室を別タブで開いてお試しください。');
    } finally { pending = false; if (!disposed) button.disabled = false; }
  };
  return { dispose() { disposed = true; clearTimeout(timer); stop(); stopTracks(); if (url) URL.revokeObjectURL(url); button.onclick = null; } };
}
