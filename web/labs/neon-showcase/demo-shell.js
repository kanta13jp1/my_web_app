// Shared responsive stage scaler, zero-overlap flex toolbar & game-pad dock,
// native fullscreen control, and Pure Web Audio synthesizer for NEON SHOWCASE demos.
// Zero external dependencies; safe DOM APIs only.
(() => {
  if (window.__RECORDING__ || window.__NEON_SHELL_LOADED__) return;
  window.__NEON_SHELL_LOADED__ = true;

  const body = document.body;
  const stageAttr = (body?.dataset?.stage || '1280x720').split('x');
  const baseW = Math.max(320, Number(stageAttr[0]) || 1280);
  const baseH = Math.max(240, Number(stageAttr[1]) || 720);
  const soundProfile = body?.dataset?.sound || 'cinema';

  // ---- 1. Zero-Overlap Fixed-Chrome Viewport Layout (Header + Centered Stage + Optional Pads) ----
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

  // ---- 2. Procedural Pure Web Audio API Engine (Gesture-Safe) ----
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
    g.gain.linearRampToValueAtTime(vol, now + Math.min(0.015, dur * 0.25));
    g.gain.exponentialRampToValueAtTime(0.0001, now + dur);
    osc.connect(g);
    g.connect(master);
    osc.start(now);
    osc.stop(now + dur + 0.02);
  }

  function playNoiseBurst(dur, freq = 800, vol = 0.12, q = 1.2) {
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

    if (soundProfile === 'sea-train') {
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
    } else if (soundProfile === 'watch') {
      // Swiss 28,800 vph (8 beats/sec = 125ms) escapement tick-tock + warm mechanical resonance
      loopTimer = setInterval(() => {
        if (!audioOn) return;
        const isTick = stepIdx % 2 === 0;
        playTone(isTick ? 4200 : 3550, 0.018, 'triangle', isTick ? 0.11 : 0.085, 0, isTick ? 1800 : 1400);
        playNoiseBurst(0.014, isTick ? 5400 : 4400, 0.08, 3.2);
        if (stepIdx % 16 === 0) {
          playTone(220, 0.9, 'sine', 0.045);
        }
        stepIdx += 1;
      }, 125);
    } else if (soundProfile === 'koto') {
      // Japanese pentatonic Hirajoshi scale (D, E, F, A, Bb) + soft mountain breeze
      const breeze = ctx.createBufferSource();
      breeze.buffer = createNoiseBuffer(ctx, 3);
      breeze.loop = true;
      const bp = ctx.createBiquadFilter();
      bp.type = 'bandpass';
      bp.frequency.value = 360;
      bp.Q.value = 0.7;
      const g = ctx.createGain();
      g.gain.value = 0.09;
      breeze.connect(bp);
      bp.connect(g);
      g.connect(master);
      breeze.start();
      engineOsc = breeze;
      engineGain = g;

      const scale = [293.66, 329.63, 349.23, 440.0, 466.16, 587.33, 659.25, 880.0];
      const pat = [0, 3, 5, 4, 3, 1, 2, 5, 6, 5, 3, 0];
      loopTimer = setInterval(() => {
        if (!audioOn) return;
        const f = scale[pat[stepIdx % pat.length]];
        playTone(f, 1.6, 'triangle', 0.11, 0, f * 0.996);
        playTone(f * 2, 0.55, 'sine', 0.04);
        if (stepIdx % 4 === 0) playTone(146.83, 2.4, 'sine', 0.07);
        stepIdx += 1;
      }, 640);
    } else if (soundProfile === 'solarpunk') {
      // Warm sunlit harp arpeggio + soft river water
      const river = ctx.createBufferSource();
      river.buffer = createNoiseBuffer(ctx, 3);
      river.loop = true;
      const lp = ctx.createBiquadFilter();
      lp.type = 'lowpass';
      lp.frequency.value = 420;
      const g = ctx.createGain();
      g.gain.value = 0.09;
      river.connect(lp);
      lp.connect(g);
      g.connect(master);
      river.start();
      engineOsc = river;
      engineGain = g;

      const arp = [261.63, 329.63, 392.0, 493.88, 523.25, 659.25, 523.25, 392.0];
      loopTimer = setInterval(() => {
        if (!audioOn) return;
        const f = arp[stepIdx % arp.length];
        playTone(f, 1.15, 'triangle', 0.09);
        if (stepIdx % 4 === 0) playTone(f * 0.5, 1.8, 'sine', 0.06);
        stepIdx += 1;
      }, 420);
    } else if (soundProfile === 'crystal') {
      // Shimmering crystalline marimba / harmonic bell loop
      const bells = [523.25, 659.25, 783.99, 1046.5, 880.0, 783.99, 659.25, 587.33];
      loopTimer = setInterval(() => {
        if (!audioOn) return;
        const f = bells[stepIdx % bells.length];
        playTone(f, 0.85, 'sine', 0.085);
        playTone(f * 1.5, 0.45, 'triangle', 0.035);
        stepIdx += 1;
      }, 333);
    } else if (soundProfile === 'blackhole') {
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
      master = ctx.createGain();
      master.gain.value = 0.24;
      master.connect(ctx.destination);
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
      // Never auto-enable AudioContext from background simulation timers before user gesture!
      if (!audioOn || !ctx || ctx.state !== 'running') return;
      if (kind === 'laser') {
        playTone(920 * pitch, 0.09, 'sawtooth', 0.14, 0, 240);
      } else if (kind === 'missile') {
        playTone(540 * pitch, 0.16, 'triangle', 0.14, 0, 1180);
      } else if (kind === 'explosion') {
        playNoiseBurst(0.28, 220, 0.28, 0.7);
        playTone(110, 0.24, 'sawtooth', 0.18, 0, 36);
      } else if (kind === 'shatter') {
        playNoiseBurst(0.18, 2400 * pitch, 0.16, 1.6);
        playTone(1320 * pitch, 0.12, 'triangle', 0.11, 0, 620);
      } else if (kind === 'clack') {
        playTone(720 * pitch, 0.045, 'triangle', 0.16, 0, 320);
        playNoiseBurst(0.03, 1800 * pitch, 0.11, 2.2);
      } else if (kind === 'chime') {
        playTone(587.33 * pitch, 0.42, 'sine', 0.13);
        playTone(880.0 * pitch, 0.36, 'triangle', 0.08, 0.03);
      } else if (kind === 'hit' || kind === 'ring') {
        playTone(587.33 * pitch, 0.12, 'triangle', 0.18);
        playTone(880.0 * pitch, 0.16, 'sine', 0.15, 0.04);
      } else if (kind === 'miss') {
        playTone(150, 0.14, 'sawtooth', 0.12, 0, 95);
      } else if (kind === 'boost' || kind === 'roll') {
        playTone(260, 0.22, 'sawtooth', 0.13, 0, 740);
        playNoiseBurst(0.18, 1200, 0.12, 1.1);
      } else if (kind === 'whistle') {
        playTone(587.33, 0.36, 'triangle', 0.11);
        playTone(739.99, 0.36, 'sine', 0.09, 0.02);
      } else {
        playTone(660 * pitch, 0.07, 'triangle', 0.11, 0, 880 * pitch);
      }
    },
  };
  window.NeonAudio = NeonAudio;

  // ---- 3. Dedicated Top Header Bar (Zero Overlap with Demo Stage) ----
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
    backLink.href = '../index.html';
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
      setTimeout(() => NeonAudio.sfx(soundProfile === 'sea-train' ? 'whistle' : 'click'), 30);
    }
  });
  rightGroup.appendChild(soundBtn);

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
  document.addEventListener('fullscreenchange', () => {
    updateFsBtn();
    fitStage();
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

  // Unlock audio cleanly on genuine user gesture (unless user explicitly muted)
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
        setTimeout(() => NeonAudio.sfx('click'), 20);
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
