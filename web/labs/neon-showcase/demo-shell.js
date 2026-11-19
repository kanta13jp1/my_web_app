// Shared responsive stage scaler, zero-overlap fixed-chrome toolbar & game-pad dock,
// robust native+fallback fullscreen control, and rich Pure Web Audio synthesizer for NEON SHOWCASE.
// Zero external dependencies; safe DOM APIs only.
(() => {
  if (window.__RECORDING__ || window.__NEON_SHELL_LOADED__) return;
  window.__NEON_SHELL_LOADED__ = true;

  const body = document.body;
  const stageAttr = (body?.dataset?.stage || '1280x720').split('x');
  const baseW = Math.max(320, Number(stageAttr[0]) || 1280);
  const baseH = Math.max(240, Number(stageAttr[1]) || 720);
  const soundProfile = body?.dataset?.sound || 'cinema';

  // ---- 1. Zero-Overlap Fixed-Chrome Viewport Layout ----
  const styleEl = document.createElement('style');
  styleEl.textContent = `
    html {
      width: 100vw !important;
      height: 100vh !important;
      margin: 0 !important;
      padding: 0 !important;
      overflow: hidden !important;
      background: #020611 !important;
      position: relative !important;
    }
    #neon-shell-bar {
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      min-height: 36px;
      box-sizing: border-box;
      padding: 4px 10px;
      background: rgba(5, 9, 20, 0.96);
      border-bottom: 1px solid rgba(148, 163, 184, 0.22);
      z-index: 2147483647;
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      justify-content: space-between;
      gap: 6px;
      font-family: system-ui, -apple-system, 'Segoe UI', sans-serif;
      pointer-events: auto;
      transition: padding 0.16s ease, min-height 0.16s ease;
    }
    html.ns-theater #neon-shell-bar {
      min-height: 28px;
      padding: 2px 8px;
      background: rgba(5, 9, 20, 0.88);
    }
    #neon-shell-bar .ns-left,
    #neon-shell-bar .ns-right {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 5px;
      min-width: 0;
    }
    #neon-shell-bar .ns-left {
      flex: 1 1 200px;
    }
    #neon-shell-bar .ns-right {
      justify-content: flex-end;
    }
    #neon-shell-hint {
      color: #cbd5e1;
      font-size: 11.5px;
      font-weight: 600;
      letter-spacing: 0.015em;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      max-width: min(56vw, 680px);
      padding: 2px 6px;
    }
    body {
      position: fixed !important;
      left: 50% !important;
      top: 50% !important;
      width: ${baseW}px !important;
      height: ${baseH}px !important;
      margin: 0 !important;
      transform-origin: center center !important;
      overflow: hidden !important;
      box-shadow: 0 18px 60px rgba(0, 0, 0, 0.72);
    }
    #neon-shell-bar .ns-btn {
      appearance: none;
      border: 1px solid rgba(148, 163, 184, 0.34);
      background: rgba(12, 20, 38, 0.92);
      color: #e2e8f0;
      border-radius: 999px;
      padding: 4px 10px;
      font-size: 11.5px;
      font-weight: 700;
      line-height: 1.25;
      cursor: pointer;
      text-decoration: none;
      transition: background 0.14s ease, border-color 0.14s ease, color 0.14s ease;
      white-space: nowrap;
    }
    #neon-shell-bar .ns-btn:hover {
      background: rgba(24, 36, 64, 0.98);
      border-color: rgba(56, 189, 248, 0.85);
      color: #ffffff;
    }
    #neon-shell-bar .ns-btn.active {
      background: rgba(245, 158, 11, 0.94);
      border-color: #fde68a;
      color: #0b1020;
    }
    #neon-shell-pads {
      position: fixed;
      bottom: 0;
      left: 0;
      right: 0;
      box-sizing: border-box;
      padding: 5px 10px 6px;
      background: rgba(5, 9, 20, 0.96);
      border-top: 1px solid rgba(56, 189, 248, 0.24);
      z-index: 2147483646;
      display: flex;
      gap: 7px;
      flex-wrap: wrap;
      justify-content: center;
      align-items: center;
      font-family: system-ui, -apple-system, 'Segoe UI', sans-serif;
    }
    #neon-shell-pads .ns-pad {
      appearance: none;
      border: 1px solid rgba(56, 189, 248, 0.55);
      background: rgba(11, 20, 42, 0.94);
      color: #f8fafc;
      border-radius: 8px;
      padding: 6px 13px;
      font-size: 12.5px;
      font-weight: 800;
      cursor: pointer;
      user-select: none;
      touch-action: manipulation;
    }
    #neon-shell-pads .ns-pad:active,
    #neon-shell-pads .ns-pad.pressed {
      background: rgba(56, 189, 248, 0.92);
      color: #020617;
    }
  `;
  document.head.appendChild(styleEl);

  let currentScale = 1;
  let barEl = null;
  let padsEl = null;
  let theaterFallback = false;

  function fitStage() {
    const vw = window.innerWidth || baseW;
    const vh = window.innerHeight || baseH;
    const barH = barEl ? barEl.getBoundingClientRect().height : 0;
    const padsH = padsEl ? padsEl.getBoundingClientRect().height : 0;
    const availW = Math.max(160, vw);
    const availH = Math.max(120, vh - barH - padsH);
    currentScale = Math.min(availW / baseW, availH / baseH);
    const centerY = barH + availH * 0.5;
    body.style.setProperty('top', `${centerY.toFixed(2)}px`, 'important');
    body.style.setProperty('transform', `translate(-50%, -50%) scale(${currentScale.toFixed(5)})`, 'important');
  }

  // ---- 2. Rich Studio-Level Pure Web Audio API Engine (Instant Start + Limiter) ----
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
      ch[i] = last * 3.4;
    }
    return buf;
  }

  function playTone(freq, dur, type = 'sine', vol = 0.22, delay = 0, endFreq = null) {
    if (!ctx || !master || !audioOn || ctx.state !== 'running') return;
    const now = ctx.currentTime + delay;
    const osc = ctx.createOscillator();
    const g = ctx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(Math.max(30, freq), now);
    if (endFreq !== null) {
      osc.frequency.exponentialRampToValueAtTime(Math.max(30, endFreq), now + dur);
    }
    g.gain.setValueAtTime(0.0001, now);
    g.gain.linearRampToValueAtTime(vol, now + Math.min(0.016, dur * 0.22));
    g.gain.exponentialRampToValueAtTime(0.0001, now + dur);
    osc.connect(g);
    g.connect(master);
    osc.start(now);
    osc.stop(now + dur + 0.025);
  }

  function playNoiseBurst(dur, freq = 800, vol = 0.2, q = 1.2) {
    if (!ctx || !master || !audioOn || ctx.state !== 'running') return;
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

  function stopAmbientLoop() {
    if (loopTimer) {
      clearInterval(loopTimer);
      loopTimer = null;
    }
    if (engineOsc) {
      try { engineOsc.stop(); } catch (_) {}
      engineOsc = null;
      engineGain = null;
    }
  }

  function startAmbientLoop() {
    stopAmbientLoop();
    if (!ctx || !master || !audioOn || ctx.state !== 'running') return;

    const runLoop = (tickFn, intervalMs) => {
      // Play the first beat/chord immediately at t=0 so users hear crisp audio right away!
      tickFn();
      loopTimer = setInterval(() => {
        if (!audioOn) return;
        tickFn();
      }, intervalMs);
    };

    if (soundProfile === 'sea-train') {
      const surf = ctx.createBufferSource();
      surf.buffer = createNoiseBuffer(ctx, 3);
      surf.loop = true;
      const lp = ctx.createBiquadFilter();
      lp.type = 'lowpass';
      lp.frequency.value = 380;
      const g = ctx.createGain();
      g.gain.value = 0.28;
      surf.connect(lp);
      lp.connect(g);
      g.connect(master);
      surf.start();
      engineOsc = surf;
      engineGain = g;

      const notes = [293.66, 329.63, 369.99, 440.0, 493.88, 587.33];
      runLoop(() => {
        playNoiseBurst(0.15, stepIdx % 2 === 0 ? 520 : 700, 0.22, 1.6);
        if (stepIdx % 4 === 0) {
          const n = notes[(stepIdx / 4) % notes.length | 0];
          playTone(n, 1.4, 'triangle', 0.18);
          playTone(n * 0.5, 1.5, 'sine', 0.14);
        }
        stepIdx += 1;
      }, 290);
    } else if (soundProfile === 'watch') {
      runLoop(() => {
        const isTick = stepIdx % 2 === 0;
        playTone(isTick ? 4200 : 3550, 0.022, 'triangle', isTick ? 0.24 : 0.19, 0, isTick ? 1800 : 1400);
        playNoiseBurst(0.016, isTick ? 5400 : 4400, 0.18, 2.8);
        if (stepIdx % 16 === 0) playTone(220, 0.9, 'sine', 0.11);
        stepIdx += 1;
      }, 125);
    } else if (soundProfile === 'koto') {
      const breeze = ctx.createBufferSource();
      breeze.buffer = createNoiseBuffer(ctx, 3);
      breeze.loop = true;
      const bp = ctx.createBiquadFilter();
      bp.type = 'bandpass';
      bp.frequency.value = 380;
      bp.Q.value = 0.7;
      const g = ctx.createGain();
      g.gain.value = 0.16;
      breeze.connect(bp);
      bp.connect(g);
      g.connect(master);
      breeze.start();
      engineOsc = breeze;
      engineGain = g;

      const scale = [293.66, 329.63, 349.23, 440.0, 466.16, 587.33, 659.25, 880.0];
      const pat = [0, 3, 5, 4, 3, 1, 2, 5, 6, 5, 3, 0];
      runLoop(() => {
        const f = scale[pat[stepIdx % pat.length]];
        playTone(f, 1.55, 'triangle', 0.22, 0, f * 0.996);
        playTone(f * 2, 0.55, 'sine', 0.09);
        if (stepIdx % 4 === 0) playTone(146.83, 2.2, 'sine', 0.16);
        stepIdx += 1;
      }, 620);
    } else if (soundProfile === 'solarpunk') {
      const river = ctx.createBufferSource();
      river.buffer = createNoiseBuffer(ctx, 3);
      river.loop = true;
      const lp = ctx.createBiquadFilter();
      lp.type = 'lowpass';
      lp.frequency.value = 460;
      const g = ctx.createGain();
      g.gain.value = 0.16;
      river.connect(lp);
      lp.connect(g);
      g.connect(master);
      river.start();
      engineOsc = river;
      engineGain = g;

      const arp = [261.63, 329.63, 392.0, 493.88, 523.25, 659.25, 523.25, 392.0];
      runLoop(() => {
        const f = arp[stepIdx % arp.length];
        playTone(f, 1.15, 'triangle', 0.2);
        if (stepIdx % 4 === 0) playTone(f * 0.5, 1.8, 'sine', 0.14);
        stepIdx += 1;
      }, 420);
    } else if (soundProfile === 'crystal') {
      const bells = [523.25, 659.25, 783.99, 1046.5, 880.0, 783.99, 659.25, 587.33];
      runLoop(() => {
        const f = bells[stepIdx % bells.length];
        playTone(f, 0.85, 'sine', 0.2);
        playTone(f * 1.5, 0.45, 'triangle', 0.09);
        stepIdx += 1;
      }, 333);
    } else if (soundProfile === 'blackhole') {
      const organ = ctx.createOscillator();
      organ.type = 'sawtooth';
      organ.frequency.value = 73.42;
      const lp = ctx.createBiquadFilter();
      lp.type = 'lowpass';
      lp.frequency.value = 240;
      const g = ctx.createGain();
      g.gain.value = 0.22;
      organ.connect(lp);
      lp.connect(g);
      g.connect(master);
      organ.start();
      engineOsc = organ;
      engineGain = g;

      const chords = [146.83, 220.0, 261.63, 293.66];
      runLoop(() => {
        playTone(880, 0.045, 'sine', 0.16, 0, 440);
        if (stepIdx % 4 === 0) {
          const f = chords[(stepIdx / 4) % chords.length | 0];
          playTone(f, 2.8, 'triangle', 0.18);
        }
        stepIdx += 1;
      }, 950);
    } else if (soundProfile === 'rhythm') {
      const bass = [110, 110, 130.81, 146.83, 98, 98, 123.47, 130.81];
      runLoop(() => {
        const beat = stepIdx % 16;
        if (beat % 4 === 0) playTone(150, 0.14, 'sine', 0.45, 0, 42);
        if (beat === 4 || beat === 12) playNoiseBurst(0.11, 1900, 0.32, 0.9);
        if (beat % 2 === 1) playNoiseBurst(0.035, 6500, 0.12, 2.2);
        if (beat % 2 === 0) {
          const bf = bass[(beat / 2) % bass.length];
          playTone(bf, 0.16, 'sawtooth', 0.17);
        }
        stepIdx += 1;
      }, 117.2);
    } else if (soundProfile === 'racer') {
      const eng = ctx.createOscillator();
      eng.type = 'sawtooth';
      eng.frequency.value = 92;
      const lp = ctx.createBiquadFilter();
      lp.type = 'lowpass';
      lp.frequency.value = 360;
      const g = ctx.createGain();
      g.gain.value = 0.18;
      eng.connect(lp);
      lp.connect(g);
      g.connect(master);
      eng.start();
      engineOsc = eng;
      engineGain = g;

      const arp = [220, 261.63, 329.63, 392.0, 329.63, 261.63];
      runLoop(() => {
        playTone(arp[stepIdx % arp.length], 0.16, 'triangle', 0.16);
        if (stepIdx % 4 === 0) playTone(125, 0.12, 'sine', 0.3, 0, 48);
        stepIdx += 1;
      }, 140);
    } else if (soundProfile === 'shooter') {
      const bass = [82.41, 82.41, 98.0, 110.0, 82.41, 123.47, 110.0, 98.0];
      runLoop(() => {
        const b = stepIdx % 8;
        if (b % 2 === 0) playTone(130, 0.12, 'sine', 0.34, 0, 44);
        playTone(bass[b], 0.18, 'sawtooth', 0.16);
        stepIdx += 1;
      }, 220);
    } else if (soundProfile === 'wind') {
      const wind = ctx.createBufferSource();
      wind.buffer = createNoiseBuffer(ctx, 3);
      wind.loop = true;
      const bp = ctx.createBiquadFilter();
      bp.type = 'bandpass';
      bp.frequency.value = 500;
      bp.Q.value = 0.8;
      const g = ctx.createGain();
      g.gain.value = 0.28;
      wind.connect(bp);
      bp.connect(g);
      g.connect(master);
      wind.start();
      engineOsc = wind;
      engineGain = g;

      runLoop(() => {
        playTone(196, 0.9, 'sine', 0.12);
        stepIdx += 1;
      }, 1200);
    } else if (soundProfile === 'workstation') {
      const notes = [220, 261.63, 329.63, 392.0];
      runLoop(() => {
        if (stepIdx % 4 === 0) playTone(110, 1.8, 'sine', 0.16);
        playTone(notes[stepIdx % notes.length] * 2, 0.11, 'triangle', 0.11);
        stepIdx += 1;
      }, 480);
    } else if (soundProfile === 'algo') {
      const scale = [261.63, 293.66, 329.63, 392.0, 440.0, 523.25, 587.33, 659.25];
      runLoop(() => {
        const n = scale[(stepIdx * 3) % scale.length];
        playTone(n, 0.16, 'triangle', 0.17);
        stepIdx += 1;
      }, 240);
    } else {
      const prog = [
        [220, 261.63, 329.63],
        [174.61, 220, 261.63],
        [196.0, 246.94, 293.66],
        [164.81, 220, 329.63],
      ];
      runLoop(() => {
        const chord = prog[stepIdx % prog.length];
        for (const f of chord) playTone(f, 2.0, 'triangle', 0.13);
        playTone(chord[0] * 0.5, 2.1, 'sine', 0.14);
        stepIdx += 1;
      }, 1800);
    }
  }

  function finishEnable() {
    if (userMuted) return;
    if (!ctx || ctx.state !== 'running') return;
    if (!audioOn) {
      audioOn = true;
      startAmbientLoop();
      updateSoundBtn();
    }
  }

  function enableAudio() {
    if (!AudioCtx) return;
    userMuted = false;
    if (!ctx) {
      ctx = new AudioCtx();
      const comp = ctx.createDynamicsCompressor();
      comp.threshold.value = -10;
      comp.ratio.value = 6;
      master = ctx.createGain();
      master.gain.value = 0.62;
      master.connect(comp);
      comp.connect(ctx.destination);
    }
    if (ctx.state === 'running') {
      finishEnable();
    } else {
      const p = ctx.resume?.();
      if (p && typeof p.then === 'function') {
        p.then(() => finishEnable()).catch(() => {});
      }
    }
  }

  function disableAudio() {
    audioOn = false;
    userMuted = true;
    stopAmbientLoop();
    updateSoundBtn();
  }

  const NeonAudio = {
    enable: enableAudio,
    disable: disableAudio,
    isEnabled: () => audioOn && Boolean(ctx) && ctx.state === 'running',
    playTone,
    playNoiseBurst,
    setPitch(mult) {
      if (engineOsc && engineOsc.frequency && ctx) {
        engineOsc.frequency.setTargetAtTime(Math.max(45, 92 * mult), ctx.currentTime, 0.08);
      }
    },
    sfx(kind = 'click', pitch = 1.0) {
      if (!audioOn || !ctx || ctx.state !== 'running') return;
      if (kind === 'laser') {
        playTone(920 * pitch, 0.1, 'sawtooth', 0.24, 0, 240);
      } else if (kind === 'missile') {
        playTone(540 * pitch, 0.18, 'triangle', 0.24, 0, 1220);
      } else if (kind === 'explosion') {
        playNoiseBurst(0.32, 220, 0.38, 0.7);
        playTone(115, 0.26, 'sawtooth', 0.28, 0, 36);
      } else if (kind === 'shatter') {
        playNoiseBurst(0.2, 2400 * pitch, 0.26, 1.5);
        playTone(1320 * pitch, 0.13, 'triangle', 0.2, 0, 620);
      } else if (kind === 'clack') {
        playTone(740 * pitch, 0.05, 'triangle', 0.28, 0, 320);
        playNoiseBurst(0.032, 1850 * pitch, 0.2, 2.0);
      } else if (kind === 'chime') {
        playTone(587.33 * pitch, 0.45, 'sine', 0.24);
        playTone(880.0 * pitch, 0.38, 'triangle', 0.16, 0.03);
      } else if (kind === 'hit' || kind === 'ring') {
        playTone(587.33 * pitch, 0.14, 'triangle', 0.28);
        playTone(880.0 * pitch, 0.18, 'sine', 0.24, 0.04);
      } else if (kind === 'miss') {
        playTone(150, 0.16, 'sawtooth', 0.22, 0, 90);
      } else if (kind === 'boost' || kind === 'roll') {
        playTone(260, 0.24, 'sawtooth', 0.22, 0, 760);
        playNoiseBurst(0.2, 1200, 0.22, 1.1);
      } else if (kind === 'whistle') {
        playTone(587.33, 0.38, 'triangle', 0.22);
        playTone(739.99, 0.38, 'sine', 0.18, 0.02);
      } else {
        playTone(660 * pitch, 0.08, 'triangle', 0.2, 0, 880 * pitch);
      }
    },
  };
  window.NeonAudio = NeonAudio;

  // ---- 3. Dedicated Top Header Bar (Zero Overlap + Robust Fullscreen) ----
  const bar = document.createElement('div');
  bar.id = 'neon-shell-bar';
  barEl = bar;

  const leftGroup = document.createElement('div');
  leftGroup.className = 'ns-left';

  const rightGroup = document.createElement('div');
  rightGroup.className = 'ns-right';

  if (window.self === window.top) {
    const backLink = document.createElement('a');
    backLink.className = 'ns-btn';
    backLink.href = '../index.html?v=20261120-33';
    backLink.textContent = '← 作品館';
    leftGroup.appendChild(backLink);
  }

  const hintEl = document.createElement('div');
  hintEl.id = 'neon-shell-hint';
  hintEl.textContent = 'クリック / キー操作でサウンドON · ドラッグ＆ボタンで操作可能';
  leftGroup.appendChild(hintEl);

  const soundBtn = document.createElement('button');
  soundBtn.type = 'button';
  soundBtn.className = 'ns-btn';
  soundBtn.id = 'neon-sound-btn';
  function updateSoundBtn() {
    const active = NeonAudio.isEnabled();
    soundBtn.textContent = active ? '🔊 音ON' : '🔇 音OFF';
    soundBtn.classList.toggle('active', active);
  }
  updateSoundBtn();
  soundBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    if (NeonAudio.isEnabled()) {
      disableAudio();
    } else {
      enableAudio();
      setTimeout(() => NeonAudio.sfx(soundProfile === 'sea-train' ? 'whistle' : 'click'), 35);
    }
  });
  rightGroup.appendChild(soundBtn);

  const fsBtn = document.createElement('button');
  fsBtn.type = 'button';
  fsBtn.className = 'ns-btn';
  fsBtn.id = 'neon-fs-btn';
  function isNativeFs() {
    return Boolean(document.fullscreenElement || document.webkitFullscreenElement);
  }
  function updateFsBtn() {
    const active = isNativeFs() || theaterFallback;
    document.documentElement.classList.toggle('ns-theater', active);
    fsBtn.textContent = active ? '⛶ 解除' : '⛶ フル画面';
    fsBtn.classList.toggle('active', active);
    fitStage();
  }
  updateFsBtn();
  fsBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    if (isNativeFs()) {
      const exitFn = document.exitFullscreen || document.webkitExitFullscreen;
      Promise.resolve(exitFn?.call(document)).finally(() => {
        theaterFallback = false;
        setTimeout(updateFsBtn, 40);
      });
    } else if (theaterFallback) {
      theaterFallback = false;
      updateFsBtn();
    } else {
      const el = document.documentElement;
      const reqFn = el.requestFullscreen || el.webkitRequestFullscreen;
      if (typeof reqFn === 'function') {
        try {
          const p = reqFn.call(el);
          if (p && typeof p.then === 'function') {
            p.then(() => setTimeout(updateFsBtn, 40)).catch(() => {
              theaterFallback = true;
              updateFsBtn();
            });
          } else {
            setTimeout(updateFsBtn, 80);
          }
        } catch (_) {
          theaterFallback = true;
          updateFsBtn();
        }
      } else {
        theaterFallback = true;
        updateFsBtn();
      }
    }
  });
  document.addEventListener('fullscreenchange', () => {
    if (!isNativeFs()) theaterFallback = false;
    updateFsBtn();
  });
  document.addEventListener('webkitfullscreenchange', () => {
    if (!isNativeFs()) theaterFallback = false;
    updateFsBtn();
  });
  rightGroup.appendChild(fsBtn);

  bar.appendChild(leftGroup);
  bar.appendChild(rightGroup);
  document.documentElement.insertBefore(bar, body);

  fitStage();
  window.addEventListener('resize', fitStage);
  if (typeof ResizeObserver !== 'undefined') {
    const ro = new ResizeObserver(fitStage);
    ro.observe(bar);
  }

  function firstGestureUnlock(e) {
    if (bar.contains(e.target)) return;
    if (!NeonAudio.isEnabled() && !userMuted) enableAudio();
  }
  window.addEventListener('pointerdown', firstGestureUnlock, { passive: true });
  window.addEventListener('keydown', firstGestureUnlock, { passive: true });

  body.addEventListener('click', (e) => {
    if (e.target.closest('button')) {
      NeonAudio.sfx(soundProfile === 'sea-train' ? 'whistle' : 'click');
    }
  });

  // ---- 4. Public Helper API for Individual Demos ----
  window.NeonShell = {
    getScale: () => currentScale,
    refit: fitStage,
    addControl(label, onClick, opts = {}) {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'ns-btn' + (opts.active ? ' active' : '');
      if (opts.id) btn.id = opts.id;
      btn.textContent = label;
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        if (!NeonAudio.isEnabled() && !userMuted) enableAudio();
        setTimeout(() => NeonAudio.sfx('click'), 25);
        onClick(btn);
      });
      rightGroup.insertBefore(btn, soundBtn);
      fitStage();
      return btn;
    },
    setHint(text) {
      hintEl.textContent = text;
    },
    addPads(specs) {
      if (!padsEl) {
        padsEl = document.createElement('div');
        padsEl.id = 'neon-shell-pads';
        document.documentElement.appendChild(padsEl);
        if (typeof ResizeObserver !== 'undefined') {
          const ro = new ResizeObserver(fitStage);
          ro.observe(padsEl);
        }
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
          if (!NeonAudio.isEnabled() && !userMuted) enableAudio();
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
      fitStage();
    },
  };
})();
