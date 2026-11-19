// Shared responsive stage scaler, native fullscreen control, interactive toolbar,
// and procedural Pure Web Audio synthesizer for NEON SHOWCASE standalone demos.
// Zero external dependencies; safe DOM APIs only.
(() => {
  if (window.__RECORDING__ || window.__NEON_SHELL_LOADED__) return;
  window.__NEON_SHELL_LOADED__ = true;

  const body = document.body;
  const stageAttr = (body?.dataset?.stage || '1280x720').split('x');
  const baseW = Math.max(320, Number(stageAttr[0]) || 1280);
  const baseH = Math.max(240, Number(stageAttr[1]) || 720);
  const soundProfile = body?.dataset?.sound || 'cinema';

  // ---- 1. Responsive Full-Viewport Stage Fit ----
  const styleEl = document.createElement('style');
  styleEl.textContent = `
    html {
      width: 100vw !important;
      height: 100vh !important;
      margin: 0 !important;
      padding: 0 !important;
      overflow: hidden !important;
      background: #020611 !important;
      display: flex !important;
      align-items: center !important;
      justify-content: center !important;
    }
    body {
      width: ${baseW}px !important;
      height: ${baseH}px !important;
      margin: 0 !important;
      flex: 0 0 auto !important;
      transform-origin: center center !important;
      position: relative !important;
      overflow: hidden !important;
      box-shadow: 0 18px 60px rgba(0, 0, 0, 0.72);
    }
    #neon-shell-bar {
      position: fixed;
      right: 10px;
      top: 10px;
      z-index: 2147483647;
      display: flex;
      flex-wrap: wrap;
      justify-content: flex-end;
      align-items: center;
      gap: 6px;
      max-width: calc(100vw - 20px);
      font-family: system-ui, -apple-system, 'Segoe UI', sans-serif;
      pointer-events: auto;
    }
    #neon-shell-bar .ns-btn {
      appearance: none;
      border: 1px solid rgba(148, 163, 184, 0.34);
      background: rgba(6, 11, 24, 0.84);
      color: #e2e8f0;
      border-radius: 999px;
      padding: 5px 11px;
      font-size: 12px;
      font-weight: 700;
      line-height: 1.25;
      cursor: pointer;
      text-decoration: none;
      backdrop-filter: blur(8px);
      transition: background 0.14s ease, border-color 0.14s ease, color 0.14s ease;
      white-space: nowrap;
    }
    #neon-shell-bar .ns-btn:hover {
      background: rgba(15, 23, 42, 0.96);
      border-color: rgba(56, 189, 248, 0.8);
      color: #ffffff;
    }
    #neon-shell-bar .ns-btn.active {
      background: rgba(245, 158, 11, 0.92);
      border-color: #fde68a;
      color: #0b1020;
    }
    #neon-shell-hint {
      position: fixed;
      left: 50%;
      bottom: 10px;
      transform: translateX(-50%);
      z-index: 2147483646;
      background: rgba(6, 11, 24, 0.82);
      border: 1px solid rgba(56, 189, 248, 0.32);
      color: #cbd5e1;
      border-radius: 999px;
      padding: 5px 13px;
      font-family: system-ui, -apple-system, 'Segoe UI', sans-serif;
      font-size: 11.5px;
      font-weight: 600;
      letter-spacing: 0.02em;
      backdrop-filter: blur(8px);
      pointer-events: none;
      max-width: calc(100vw - 24px);
      text-align: center;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    #neon-shell-pads {
      position: fixed;
      left: 50%;
      bottom: 42px;
      transform: translateX(-50%);
      z-index: 2147483646;
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
      justify-content: center;
      max-width: calc(100vw - 20px);
      font-family: system-ui, -apple-system, 'Segoe UI', sans-serif;
    }
    #neon-shell-pads .ns-pad {
      appearance: none;
      border: 1px solid rgba(56, 189, 248, 0.52);
      background: rgba(7, 14, 30, 0.84);
      color: #f8fafc;
      border-radius: 10px;
      padding: 8px 14px;
      font-size: 13px;
      font-weight: 800;
      cursor: pointer;
      user-select: none;
      touch-action: manipulation;
      backdrop-filter: blur(8px);
    }
    #neon-shell-pads .ns-pad:active,
    #neon-shell-pads .ns-pad.pressed {
      background: rgba(56, 189, 248, 0.9);
      color: #020617;
    }
  `;
  document.head.appendChild(styleEl);

  let currentScale = 1;
  function fitStage() {
    const vw = window.innerWidth || baseW;
    const vh = window.innerHeight || baseH;
    currentScale = Math.min(vw / baseW, vh / baseH);
    body.style.transform = `scale(${currentScale.toFixed(5)})`;
  }
  fitStage();
  window.addEventListener('resize', fitStage);
  document.addEventListener('fullscreenchange', fitStage);

  // ---- 2. Procedural Pure Web Audio API Engine ----
  const AudioCtx = window.AudioContext || window.webkitAudioContext;
  let ctx = null;
  let master = null;
  let audioOn = false;
  let userMuted = false;
  let loopTimer = null;
  let engineOsc = null;
  let engineGain = null;
  let stepIdx = 0;

  function createNoiseBuffer(audioCtx, seconds = 2) {
    const len = Math.floor(audioCtx.sampleRate * seconds);
    const buf = audioCtx.createBuffer(1, len, audioCtx.sampleRate);
    const ch = buf.getChannelData(0);
    let last = 0;
    for (let i = 0; i < len; i += 1) {
      const white = Math.random() * 2 - 1;
      last = (last + 0.04 * white) / 1.04;
      ch[i] = last * 3.2;
    }
    return buf;
  }

  function playTone(freq, dur, type = 'sine', vol = 0.14, delay = 0, endFreq = null) {
    if (!ctx || !master || !audioOn) return;
    const now = ctx.currentTime + delay;
    const osc = ctx.createOscillator();
    const g = ctx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(Math.max(30, freq), now);
    if (endFreq !== null) {
      osc.frequency.exponentialRampToValueAtTime(Math.max(30, endFreq), now + dur);
    }
    g.gain.setValueAtTime(0.0001, now);
    g.gain.linearRampToValueAtTime(vol, now + Math.min(0.015, dur * 0.25));
    g.gain.exponentialRampToValueAtTime(0.0001, now + dur);
    osc.connect(g);
    g.connect(master);
    osc.start(now);
    osc.stop(now + dur + 0.02);
  }

  function playNoiseBurst(dur, freq = 800, vol = 0.12, q = 1.2) {
    if (!ctx || !master || !audioOn) return;
    const now = ctx.currentTime;
    const src = ctx.createBufferSource();
    src.buffer = createNoiseBuffer(ctx, Math.max(0.25, dur + 0.05));
    const filt = ctx.createBiquadFilter();
    filt.type = 'bandpass';
    filt.frequency.setValueAtTime(freq, now);
    filt.Q.value = q;
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, now);
    g.gain.linearRampToValueAtTime(vol, now + 0.01);
    g.gain.exponentialRampToValueAtTime(0.0001, now + dur);
    src.connect(filt);
    filt.connect(g);
    g.connect(master);
    src.start(now);
    src.stop(now + dur + 0.03);
  }

  function startAmbientLoop() {
    if (loopTimer) clearInterval(loopTimer);
    if (engineOsc) {
      try { engineOsc.stop(); } catch (_) {}
      engineOsc = null;
      engineGain = null;
    }
    if (!ctx || !master || !audioOn) return;

    if (soundProfile === 'sea-train') {
      // Gentle ocean surf + rhythmic steam locomotive chug + nostalgic pentatonic chimes
      const surf = ctx.createBufferSource();
      surf.buffer = createNoiseBuffer(ctx, 3);
      surf.loop = true;
      const lp = ctx.createBiquadFilter();
      lp.type = 'lowpass';
      lp.frequency.value = 340;
      const g = ctx.createGain();
      g.gain.value = 0.16;
      surf.connect(lp);
      lp.connect(g);
      g.connect(master);
      surf.start();
      engineOsc = surf;
      engineGain = g;

      const notes = [293.66, 329.63, 369.99, 440.0, 493.88, 587.33];
      loopTimer = setInterval(() => {
        if (!audioOn) return;
        playNoiseBurst(0.14, stepIdx % 2 === 0 ? 520 : 680, 0.11, 1.8);
        if (stepIdx % 4 === 0) {
          const n = notes[(stepIdx / 4) % notes.length | 0];
          playTone(n, 1.35, 'triangle', 0.08);
          playTone(n * 0.5, 1.5, 'sine', 0.06);
        }
        stepIdx += 1;
      }, 290);
    } else if (soundProfile === 'blackhole') {
      // Deep Interstellar-inspired organ fifths + relativistic tick pulse
      const organ = ctx.createOscillator();
      organ.type = 'sawtooth';
      organ.frequency.value = 73.42;
      const lp = ctx.createBiquadFilter();
      lp.type = 'lowpass';
      lp.frequency.value = 210;
      const g = ctx.createGain();
      g.gain.value = 0.13;
      organ.connect(lp);
      lp.connect(g);
      g.connect(master);
      organ.start();
      engineOsc = organ;
      engineGain = g;

      const chords = [146.83, 220.0, 261.63, 293.66];
      loopTimer = setInterval(() => {
        if (!audioOn) return;
        playTone(880, 0.035, 'sine', 0.07, 0, 440);
        if (stepIdx % 4 === 0) {
          const f = chords[(stepIdx / 4) % chords.length | 0];
          playTone(f, 2.8, 'triangle', 0.08);
        }
        stepIdx += 1;
      }, 950);
    } else if (soundProfile === 'rhythm') {
      // True 128 BPM synthwave beat (16th-note step = 117.1875 ms)
      const bass = [110, 110, 130.81, 146.83, 98, 98, 123.47, 130.81];
      loopTimer = setInterval(() => {
        if (!audioOn) return;
        const beat = stepIdx % 16;
        if (beat % 4 === 0) playTone(145, 0.14, 'sine', 0.34, 0, 42);
        if (beat === 4 || beat === 12) playNoiseBurst(0.11, 1800, 0.22, 0.9);
        if (beat % 2 === 1) playNoiseBurst(0.035, 6500, 0.07, 2.5);
        if (beat % 2 === 0) {
          const bf = bass[(beat / 2) % bass.length];
          playTone(bf, 0.16, 'sawtooth', 0.09);
        }
        stepIdx += 1;
      }, 117.2);
    } else if (soundProfile === 'racer') {
      const eng = ctx.createOscillator();
      eng.type = 'sawtooth';
      eng.frequency.value = 92;
      const lp = ctx.createBiquadFilter();
      lp.type = 'lowpass';
      lp.frequency.value = 320;
      const g = ctx.createGain();
      g.gain.value = 0.1;
      eng.connect(lp);
      lp.connect(g);
      g.connect(master);
      eng.start();
      engineOsc = eng;
      engineGain = g;

      const arp = [220, 261.63, 329.63, 392.0, 329.63, 261.63];
      loopTimer = setInterval(() => {
        if (!audioOn) return;
        playTone(arp[stepIdx % arp.length], 0.16, 'triangle', 0.07);
        if (stepIdx % 4 === 0) playTone(120, 0.12, 'sine', 0.18, 0, 48);
        stepIdx += 1;
      }, 140);
    } else if (soundProfile === 'shooter') {
      const bass = [82.41, 82.41, 98.0, 110.0, 82.41, 123.47, 110.0, 98.0];
      loopTimer = setInterval(() => {
        if (!audioOn) return;
        const b = stepIdx % 8;
        if (b % 2 === 0) playTone(125, 0.11, 'sine', 0.2, 0, 45);
        playTone(bass[b], 0.18, 'sawtooth', 0.075);
        stepIdx += 1;
      }, 220);
    } else if (soundProfile === 'wind') {
      const wind = ctx.createBufferSource();
      wind.buffer = createNoiseBuffer(ctx, 3);
      wind.loop = true;
      const bp = ctx.createBiquadFilter();
      bp.type = 'bandpass';
      bp.frequency.value = 460;
      bp.Q.value = 0.8;
      const g = ctx.createGain();
      g.gain.value = 0.18;
      wind.connect(bp);
      bp.connect(g);
      g.connect(master);
      wind.start();
      engineOsc = wind;
      engineGain = g;

      loopTimer = setInterval(() => {
        if (!audioOn) return;
        playTone(185, 0.7, 'sine', 0.04);
        stepIdx += 1;
      }, 1400);
    } else if (soundProfile === 'workstation') {
      const notes = [220, 261.63, 329.63, 392.0];
      loopTimer = setInterval(() => {
        if (!audioOn) return;
        if (stepIdx % 4 === 0) playTone(110, 1.8, 'sine', 0.06);
        playTone(notes[stepIdx % notes.length] * 2, 0.08, 'sine', 0.035);
        stepIdx += 1;
      }, 520);
    } else if (soundProfile === 'algo') {
      const scale = [261.63, 293.66, 329.63, 392.0, 440.0, 523.25, 587.33, 659.25];
      loopTimer = setInterval(() => {
        if (!audioOn) return;
        const n = scale[(stepIdx * 3) % scale.length];
        playTone(n, 0.15, 'triangle', 0.08);
        stepIdx += 1;
      }, 240);
    } else {
      // Ethereal synthwave pad (cinema / shaders)
      const prog = [
        [220, 261.63, 329.63],
        [174.61, 220, 261.63],
        [196.0, 246.94, 293.66],
        [164.81, 220, 329.63],
      ];
      loopTimer = setInterval(() => {
        if (!audioOn) return;
        const chord = prog[stepIdx % prog.length];
        for (const f of chord) playTone(f, 2.1, 'triangle', 0.045);
        stepIdx += 1;
      }, 1900);
    }
  }

  function enableAudio() {
    if (!AudioCtx) return;
    if (!ctx) {
      ctx = new AudioCtx();
      master = ctx.createGain();
      master.gain.value = 0.22;
      master.connect(ctx.destination);
    }
    if (ctx.state === 'suspended') ctx.resume();
    if (!audioOn) {
      audioOn = true;
      userMuted = false;
      startAmbientLoop();
      updateSoundBtn();
    }
  }

  function disableAudio() {
    audioOn = false;
    userMuted = true;
    if (loopTimer) {
      clearInterval(loopTimer);
      loopTimer = null;
    }
    if (engineOsc) {
      try { engineOsc.stop(); } catch (_) {}
      engineOsc = null;
      engineGain = null;
    }
    updateSoundBtn();
  }

  const NeonAudio = {
    enable: enableAudio,
    disable: disableAudio,
    isEnabled: () => audioOn,
    setPitch(mult) {
      if (engineOsc && engineOsc.frequency && ctx) {
        engineOsc.frequency.setTargetAtTime(Math.max(45, 92 * mult), ctx.currentTime, 0.08);
      }
    },
    sfx(kind = 'click') {
      if (!audioOn && !userMuted) enableAudio();
      if (!audioOn) return;
      if (kind === 'laser') {
        playTone(920, 0.09, 'sawtooth', 0.14, 0, 240);
      } else if (kind === 'missile') {
        playTone(540, 0.16, 'triangle', 0.14, 0, 1180);
      } else if (kind === 'explosion') {
        playNoiseBurst(0.28, 220, 0.28, 0.7);
        playTone(110, 0.24, 'sawtooth', 0.18, 0, 36);
      } else if (kind === 'hit' || kind === 'ring') {
        playTone(587.33, 0.12, 'triangle', 0.18);
        playTone(880.0, 0.16, 'sine', 0.15, 0.04);
      } else if (kind === 'miss') {
        playTone(150, 0.14, 'sawtooth', 0.12, 0, 95);
      } else if (kind === 'boost' || kind === 'roll') {
        playTone(260, 0.22, 'sawtooth', 0.13, 0, 740);
        playNoiseBurst(0.18, 1200, 0.12, 1.1);
      } else if (kind === 'whistle') {
        playTone(587.33, 0.36, 'triangle', 0.11);
        playTone(739.99, 0.36, 'sine', 0.09, 0.02);
      } else {
        playTone(660, 0.07, 'triangle', 0.11, 0, 880);
      }
    },
  };
  window.NeonAudio = NeonAudio;

  // ---- 3. Floating Control Toolbar (outside scaled body on <html>) ----
  const bar = document.createElement('div');
  bar.id = 'neon-shell-bar';

  const soundBtn = document.createElement('button');
  soundBtn.type = 'button';
  soundBtn.className = 'ns-btn';
  soundBtn.id = 'neon-sound-btn';
  function updateSoundBtn() {
    soundBtn.textContent = audioOn ? '🔊 音ON' : '🔇 音OFF';
    soundBtn.classList.toggle('active', audioOn);
  }
  updateSoundBtn();
  soundBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    if (audioOn) disableAudio();
    else {
      enableAudio();
      NeonAudio.sfx(soundProfile === 'sea-train' ? 'whistle' : 'click');
    }
  });
  bar.appendChild(soundBtn);

  const fsBtn = document.createElement('button');
  fsBtn.type = 'button';
  fsBtn.className = 'ns-btn';
  fsBtn.id = 'neon-fs-btn';
  function updateFsBtn() {
    const isFs = Boolean(document.fullscreenElement);
    fsBtn.textContent = isFs ? '⛶ 解除' : '⛶ フル画面';
    fsBtn.classList.toggle('active', isFs);
  }
  updateFsBtn();
  fsBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    if (document.fullscreenElement) {
      document.exitFullscreen?.().catch(() => {});
    } else {
      document.documentElement.requestFullscreen?.().catch(() => {});
    }
  });
  document.addEventListener('fullscreenchange', updateFsBtn);
  bar.appendChild(fsBtn);

  if (window.self === window.top) {
    const backLink = document.createElement('a');
    backLink.className = 'ns-btn';
    backLink.href = '../index.html';
    backLink.textContent = '← 作品館';
    bar.appendChild(backLink);
  }

  document.documentElement.appendChild(bar);

  // Auto-unlock audio smoothly on first user interaction inside the demo (unless muted)
  function firstGestureUnlock(e) {
    if (bar.contains(e.target)) return;
    if (!audioOn && !userMuted) enableAudio();
  }
  window.addEventListener('pointerdown', firstGestureUnlock, { passive: true });
  window.addEventListener('keydown', firstGestureUnlock, { passive: true });

  // Subtle click SFX for interactive demo buttons
  body.addEventListener('click', (e) => {
    if (e.target.closest('button')) {
      NeonAudio.sfx(soundProfile === 'sea-train' ? 'whistle' : 'click');
    }
  });

  // ---- 4. Public Helper API for Individual Demos ----
  let hintEl = null;
  let padsEl = null;
  window.NeonShell = {
    getScale: () => currentScale,
    addControl(label, onClick, opts = {}) {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'ns-btn' + (opts.active ? ' active' : '');
      if (opts.id) btn.id = opts.id;
      btn.textContent = label;
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        if (!audioOn && !userMuted) enableAudio();
        NeonAudio.sfx('click');
        onClick(btn);
      });
      bar.insertBefore(btn, soundBtn);
      return btn;
    },
    setHint(text) {
      if (!hintEl) {
        hintEl = document.createElement('div');
        hintEl.id = 'neon-shell-hint';
        document.documentElement.appendChild(hintEl);
      }
      hintEl.textContent = text;
    },
    addPads(specs) {
      if (!padsEl) {
        padsEl = document.createElement('div');
        padsEl.id = 'neon-shell-pads';
        document.documentElement.appendChild(padsEl);
      }
      padsEl.textContent = '';
      for (const spec of specs) {
        const pad = document.createElement('button');
        pad.type = 'button';
        pad.className = 'ns-pad';
        pad.textContent = spec.label;
        const press = (e) => {
          e.preventDefault();
          e.stopPropagation();
          if (!audioOn && !userMuted) enableAudio();
          pad.classList.add('pressed');
          spec.onDown?.();
        };
        const release = () => {
          pad.classList.remove('pressed');
          spec.onUp?.();
        };
        pad.addEventListener('pointerdown', press);
        pad.addEventListener('pointerup', release);
        pad.addEventListener('pointerleave', release);
        pad.addEventListener('pointercancel', release);
        padsEl.appendChild(pad);
      }
    },
  };
})();
