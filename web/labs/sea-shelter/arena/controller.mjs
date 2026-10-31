import {
  advanceTraining,
  newTraining,
  RULES,
  trainingCommand,
} from "./model.mjs";
const $ = (id) => document.getElementById(id);
const motion = matchMedia("(prefers-reduced-motion: reduce)");
const listeners = new AbortController();
let state = null,
  scene = null,
  frame = 0,
  last = 0,
  token = 0,
  loading = false,
  ended = false,
  audio = null;
let latestMessage = "",
  lastCue = "",
  lastPaint = 0,
  short = false,
  endingUntil = 0;
$("quiet").checked = motion.matches;
function announce(text) {
  if (text !== lastCue) {
    $("cue").textContent = text;
    lastCue = text;
  }
}
function controls() {
  const running = state?.status === "running";
  $("attack").disabled = !running || Boolean(state.pending) ||
    state.time < state.nextAttackAt;
  $("guard").disabled = !running || state.time < state.nextGuardAt;
  $("special").disabled = !running || state.charge < 100 ||
    Boolean(state.pending) || state.time < state.nextAttackAt;
  $("pause").disabled = !state || !["running", "paused"].includes(state.status);
  $("pause").textContent = state?.status === "paused"
    ? "訓練を再開"
    : "一時停止";
  $("skip").disabled = !state ||
    !["running", "paused", "won", "lost"].includes(state.status);
  $("retry").hidden = !state ||
    !["won", "lost", "stopped"].includes(state.status);
}
function update(events = []) {
  if (!state) return;
  document.body.dataset.status = state.status;
  $("hp").textContent = `${state.playerHp} / ${RULES.playerHp}`;
  $("enemy-hp").textContent = `${state.targetHp} / ${RULES.targetHp}`;
  $("charge").textContent = `${state.charge} / 100`;
  $("cue").dataset.warning = String(
    state.telegraphing && state.status === "running",
  );
  const descriptions = {
    "guard-success": "ガード成功！ 次の一撃は反撃。",
    "player-hit": "被弾。次は合図を見てガードしよう。",
    "target-hit": "命中！ 灯りの力がたまる。",
    "special-start": "灯の一閃！",
    "enemy-tell": "打ち込みが来る — いま構えて！",
    "attack-start": "踏み込んで攻撃。",
    "guard-start": "ガードの構え。",
  };
  for (const e of events) {
    if (descriptions[e.type]) latestMessage = descriptions[e.type];
    if (["target-hit", "guard-success", "player-hit"].includes(e.type)) {
      beep(e.type);
    }
  }
  let line = state.telegraphing
    ? "打ち込みが来る — 合図の終わりをガード！"
    : latestMessage || "攻撃で力をため、合図が来たらガード。";
  if (state.status === "paused") {
    line = "一時停止中。準備ができたら「訓練を再開」。";
  }
  if (state.status === "won") {
    line = `訓練成功！ ${
      Math.round(state.time / 1000)
    }秒・ガード${state.guards}回・必殺${state.specials}回。資材と保存はそのままです。`;
  }
  if (state.status === "lost") {
    line =
      "訓練終了。合図の終わりにガードしよう。集落の資材と保存はそのままです。";
  }
  if (state.status === "stopped") {
    line = latestMessage ||
      "訓練を終了しました。集落の資材と保存はそのままです。";
  }
  announce(line);
  controls();
}
function diagnostics() {
  if (!scene) return;
  const m = scene.diagnostics();
  $("metrics").textContent =
    `Three.js 0.186.0 / DPR ${m.dpr} / 最大三角形 ${m.peakTriangles} / 最大描画回数 ${m.peakDrawCalls} / 粒子 ${m.particles}`;
}
function draw(events = [], now = performance.now()) {
  try {
    scene?.render(state, events, now);
    if (now - lastPaint > 300) {
      lastPaint = now;
      diagnostics();
    }
  } catch {
    failure(
      "3Dを描画できませんでした。軽量描画で再試行するか、集落へ戻れます。",
    );
  }
}
function tick(now) {
  frame = 0;
  if (!scene || !state || document.hidden) return;
  let events = [];
  if (state.status === "running") {
    const delta = last ? Math.min(50, Math.max(0, now - last)) : 0;
    last = now;
    const result = advanceTraining(state, delta);
    state = result.state;
    events = result.events;
    update(events);
    if (state.status === "won" || state.status === "lost") {
      endingUntil = now + 1200;
    }
  } else if (!["won", "lost"].includes(state.status) || now >= endingUntil) {
    return;
  }
  draw(events, now);
  if (scene && (state.status === "running" || now < endingUntil)) {
    frame = requestAnimationFrame(tick);
  } else diagnostics();
}
function run() {
  if (!frame && scene && state?.status === "running" && !document.hidden) {
    last = 0;
    frame = requestAnimationFrame(tick);
  }
}
function halt() {
  if (frame) cancelAnimationFrame(frame);
  frame = 0;
  last = 0;
}
function release(keepAudio = false) {
  halt();
  if (scene) {
    const m = scene.dispose();
    scene = null;
    $("cleanup").textContent =
      `描画を解放しました：geometry ${m.geometries} / texture ${m.textures}`;
  }
  if (audio && !keepAudio) {
    const closing = audio;
    audio = null;
    closing.close().catch(() => {});
    $("sound").checked = false;
  }
}
function failure(message) {
  ++token;
  loading = false;
  release();
  state = trainingCommand(state ?? newTraining(), "stop").state;
  latestMessage = message;
  update();
  $("reload").hidden = false;
  $("intro").hidden = true;
  $("start").disabled = false;
}
async function start() {
  if (loading || ended) return;
  loading = true;
  const current = ++token;
  release(true);
  state = null;
  short = false;
  $("skip").textContent = "演出を短くする";
  $("cleanup").textContent = "";
  $("start").disabled = true;
  $("retry").disabled = true;
  announce("3Dの甲板を準備しています…");
  $("reload").hidden = true;
  try {
    const { createTrainingScene } = await import("./scene.mjs");
    if (current !== token || ended) return;
    state = newTraining({ assisted: $("assist").checked });
    latestMessage = "";
    scene = createTrainingScene({
      host: $("scene"),
      onFailure: failure,
      low: $("low").checked,
      reducedMotion: $("quiet").checked,
    });
    $("intro").hidden = true;
    loading = false;
    $("retry").disabled = false;
    draw();
    update();
    if (document.hidden) command("pause");
    else run();
    $("attack").focus({ preventScroll: true });
  } catch {
    if (current === token) {
      failure(
        "WebGL2または3D素材を読み込めません。軽量描画で再試行するか、集落へ戻れます。",
      );
      $("retry").disabled = false;
    }
  }
}
function command(name) {
  if (!state || !scene || loading) return;
  const result = trainingCommand(state, name);
  state = result.state;
  if (result.message) latestMessage = result.message;
  if (name === "resume") audio?.resume().catch(() => {});
  if (state.status === "paused") halt();
  update(result.events);
  draw(result.events);
  if (state.status === "running") run();
}
function beep(kind) {
  if (
    !$("sound").checked || !audio || audio.state !== "running" ||
    document.hidden
  ) return;
  const oscillator = audio.createOscillator(),
    gain = audio.createGain(),
    now = audio.currentTime;
  oscillator.frequency.value = kind === "guard-success"
    ? 660
    : kind === "player-hit"
    ? 150
    : 400;
  gain.gain.setValueAtTime(.025, now);
  gain.gain.exponentialRampToValueAtTime(.0001, now + .09);
  oscillator.connect(gain);
  gain.connect(audio.destination);
  oscillator.start(now);
  oscillator.stop(now + .1);
  oscillator.onended = () => {
    oscillator.disconnect();
    gain.disconnect();
  };
}
const on = (target, event, fn) =>
  target.addEventListener(event, fn, { signal: listeners.signal });
on($("start"), "click", start);
on($("retry"), "click", start);
on($("reload"), "click", () => location.reload());
for (const name of ["attack", "guard", "special"]) {
  on($(name), "click", () => command(name));
}
on(
  $("pause"),
  "click",
  () => command(state?.status === "paused" ? "resume" : "pause"),
);
on($("skip"), "click", () => {
  short = !short;
  scene?.setReducedMotion(short || $("quiet").checked);
  $("skip").textContent = short ? "短い演出に設定中" : "演出を短くする";
  draw();
});
on($("quiet"), "change", () => {
  scene?.setReducedMotion(short || $("quiet").checked);
  draw();
});
on(motion, "change", () => {
  $("quiet").checked = motion.matches;
  scene?.setReducedMotion(short || motion.matches);
  draw();
});
on($("sound"), "change", async () => {
  if (!$("sound").checked) {
    if (audio) {
      await audio.close().catch(() => {});
      audio = null;
    }
    return;
  }
  try {
    const Context = globalThis.AudioContext ?? globalThis.webkitAudioContext;
    if (!Context) throw Error();
    audio ??= new Context();
    await audio.resume();
  } catch {
    $("sound").checked = false;
    announce("この端末では効果音を使えません。無音で訓練できます。");
  }
});
on(document, "keydown", (event) => {
  if (
    event.repeat || event.altKey || event.ctrlKey || event.metaKey ||
    event.target.closest("input,select,textarea,[contenteditable=true]")
  ) return;
  const name =
    { a: "attack", g: "guard", s: "special" }[event.key.toLowerCase()];
  if (name) {
    event.preventDefault();
    command(name);
  }
});
on(document, "visibilitychange", () => {
  if (document.hidden) {
    if (state?.status === "running") command("pause");
    halt();
    audio?.suspend().catch(() => {});
  }
});
on(window, "pagehide", (event) => {
  ++token;
  loading = false;
  release();
  if (!event.persisted) {
    ended = true;
    listeners.abort();
  }
});
on(window, "pageshow", (event) => {
  if (event.persisted) {
    state = null;
    document.body.dataset.status = "idle";
    $("intro").hidden = false;
    $("start").disabled = false;
    $("retry").hidden = true;
    announce("甲板から戻りました。開始操作で新しく訓練できます。");
    controls();
  }
});
