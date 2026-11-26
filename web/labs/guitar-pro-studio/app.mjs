import * as alphaTab from "./vendor/alphaTab.min.mjs";
import { PRESETS } from "./presets.mjs";

const MAX_UPLOAD_BYTES = 5 * 1024 * 1024;
const ALLOWED_EXTENSIONS = new Set([
  "gp",
  "gp3",
  "gp4",
  "gp5",
  "gpx",
  "musicxml",
  "xml",
  "tex",
]);

const LIGHT_RESOURCES = {
  mainGlyphColor: "#111827",
  secondaryGlyphColor: "#374151",
  staffLineColor: "#6b7280",
  barSeparatorColor: "#374151",
  barNumberColor: "#b45309",
  scoreInfoColor: "#111827",
};

const DARK_RESOURCES = {
  mainGlyphColor: "#f3f4f6",
  secondaryGlyphColor: "#d1d5db",
  staffLineColor: "#6b7280",
  barSeparatorColor: "#9ca3af",
  barNumberColor: "#ff8c5a",
  scoreInfoColor: "#f9fafb",
};

const presetButtonsEl = document.getElementById("preset-buttons");
const presetDescriptionEl = document.getElementById("preset-description");
const trackSelectEl = document.getElementById("track-select");
const staveProfileEl = document.getElementById("stave-profile");
const tempoSpeedEl = document.getElementById("tempo-speed");
const playPauseBtn = document.getElementById("btn-play-pause");
const stopBtn = document.getElementById("btn-stop");
const loopBtn = document.getElementById("btn-loop");
const metronomeBtn = document.getElementById("btn-metronome");
const sheetThemeBtn = document.getElementById("btn-sheet-theme");
const fileInputEl = document.getElementById("score-file-input");
const statusEl = document.getElementById("status-message");
const errorEl = document.getElementById("error-message");
const viewportEl = document.getElementById("score-viewport");
const surfaceEl = document.getElementById("alphaTab-surface");

let activePresetId = PRESETS[0].id;
let isDarkSheet = false;
let isLooping = false;
let isMetronomeOn = false;
let currentScore = null;

function setStatus(message) {
  statusEl.textContent = message;
}

function showError(message) {
  errorEl.textContent = message;
  errorEl.hidden = false;
}

function clearError() {
  errorEl.textContent = "";
  errorEl.hidden = true;
}

function renderPresetButtons() {
  presetButtonsEl.innerHTML = "";
  for (const preset of PRESETS) {
    const button = document.createElement("button");
    button.type = "button";
    button.className =
      preset.id === activePresetId ? "btn btn-active" : "btn";
    button.dataset.presetId = preset.id;
    button.setAttribute("aria-pressed", String(preset.id === activePresetId));
    button.textContent = preset.title;
    button.addEventListener("click", () => selectPreset(preset.id));
    presetButtonsEl.appendChild(button);
  }
  const active = PRESETS.find((item) => item.id === activePresetId);
  presetDescriptionEl.textContent = active ? active.description : "";
}

const bravuraWoff2Url = new URL("./vendor/font/Bravura.woff2", import.meta.url)
  .href;

const api = new alphaTab.AlphaTabApi(surfaceEl, {
  core: {
    scriptFile: new URL("./vendor/alphaTab.min.mjs", import.meta.url).href,
    fontDirectory: new URL("./vendor/font/", import.meta.url).href,
    smuflFontSources: new Map([[alphaTab.FontFileFormat.Woff2, bravuraWoff2Url]]),
    useWorkers: true,
    enableLazyLoading: false,
    includeNoteBounds: false,
  },
  display: {
    layoutMode: alphaTab.LayoutMode.Page,
    staveProfile: alphaTab.StaveProfile.ScoreTab,
    scale: window.innerWidth < 600 ? 0.85 : 1.0,
    resources: LIGHT_RESOURCES,
  },
  player: {
    enablePlayer: true,
    enableCursor: true,
    enableUserInteraction: true,
    soundFont: new URL("./vendor/soundfont/sonivox.sf3", import.meta.url).href,
    scrollElement: viewportEl,
  },
});

function selectPreset(presetId) {
  const preset = PRESETS.find((item) => item.id === presetId);
  if (!preset) return;
  clearError();
  activePresetId = preset.id;
  renderPresetButtons();
  viewportEl.dataset.renderState = "loading";
  api.stop();
  api.tex(preset.alphaTex);
}

api.scoreLoaded.on((score) => {
  currentScore = score;
  trackSelectEl.innerHTML = "";
  for (const track of score.tracks) {
    const option = document.createElement("option");
    option.value = String(track.index);
    option.textContent = track.name || `Track ${track.index + 1}`;
    trackSelectEl.appendChild(option);
  }
  setStatus(
    `読込完了: ${score.title || "無題スコア"} (${score.tracks.length} トラック / ${score.tempo} BPM)`,
  );
});

api.renderFinished.on(() => {
  viewportEl.dataset.renderState = "ready";
});

api.playerReady.on(() => {
  viewportEl.dataset.playerReady = "true";
  playPauseBtn.disabled = false;
  stopBtn.disabled = false;
});

api.playerStateChanged.on((args) => {
  const playing = args.state === alphaTab.synth.PlayerState.Playing;
  playPauseBtn.textContent = playing ? "一時停止" : "再生";
  playPauseBtn.setAttribute("aria-pressed", String(playing));
});

api.error.on((err) => {
  const detail = err && err.message ? err.message : String(err ?? "不明なエラー");
  showError(`楽譜の読み込みに失敗しました: ${detail}`);
});

trackSelectEl.addEventListener("change", () => {
  if (!currentScore) return;
  const idx = Number(trackSelectEl.value);
  const track = currentScore.tracks.find((item) => item.index === idx);
  if (track) {
    viewportEl.dataset.renderState = "loading";
    api.renderTracks([track]);
  }
});

staveProfileEl.addEventListener("change", () => {
  const value = staveProfileEl.value;
  api.settings.display.staveProfile =
    value === "tab"
      ? alphaTab.StaveProfile.Tab
      : value === "score"
        ? alphaTab.StaveProfile.Score
        : alphaTab.StaveProfile.ScoreTab;
  viewportEl.dataset.renderState = "loading";
  api.updateSettings();
  api.render();
});

tempoSpeedEl.addEventListener("change", () => {
  api.playbackSpeed = Number(tempoSpeedEl.value) || 1.0;
});

playPauseBtn.addEventListener("click", () => {
  clearError();
  api.playPause();
});

stopBtn.addEventListener("click", () => {
  api.stop();
});

loopBtn.addEventListener("click", () => {
  isLooping = !isLooping;
  api.isLooping = isLooping;
  loopBtn.textContent = isLooping ? "ループ ON" : "ループ OFF";
  loopBtn.setAttribute("aria-pressed", String(isLooping));
});

metronomeBtn.addEventListener("click", () => {
  isMetronomeOn = !isMetronomeOn;
  api.metronomeVolume = isMetronomeOn ? 1.0 : 0.0;
  metronomeBtn.textContent = isMetronomeOn
    ? "メトロノーム ON"
    : "メトロノーム OFF";
  metronomeBtn.setAttribute("aria-pressed", String(isMetronomeOn));
});

sheetThemeBtn.addEventListener("click", () => {
  isDarkSheet = !isDarkSheet;
  viewportEl.classList.toggle("sheet-dark", isDarkSheet);
  viewportEl.classList.toggle("sheet-light", !isDarkSheet);
  sheetThemeBtn.textContent = isDarkSheet ? "白紙譜面" : "ダーク譜面";
  sheetThemeBtn.setAttribute("aria-pressed", String(isDarkSheet));
  api.settings.fillFromJson({
    display: {
      resources: isDarkSheet ? DARK_RESOURCES : LIGHT_RESOURCES,
    },
  });
  viewportEl.dataset.renderState = "loading";
  api.updateSettings();
  api.render();
});

fileInputEl.addEventListener("change", async () => {
  const file = fileInputEl.files && fileInputEl.files[0];
  if (!file) return;

  const dotIdx = file.name.lastIndexOf(".");
  const ext = dotIdx >= 0 ? file.name.slice(dotIdx + 1).toLowerCase() : "";
  if (!ALLOWED_EXTENSIONS.has(ext)) {
    showError(
      "対応形式は .gp / .gp3 / .gp4 / .gp5 / .gpx / .musicxml / .xml / .tex のみです。",
    );
    fileInputEl.value = "";
    return;
  }
  if (file.size <= 0 || file.size > MAX_UPLOAD_BYTES) {
    showError("譜面ファイルサイズは 1B〜5MB の範囲で指定してください。");
    fileInputEl.value = "";
    return;
  }

  clearError();
  activePresetId = "";
  renderPresetButtons();
  presetDescriptionEl.textContent = `ローカル非公開譜面を表示中: ${file.name}`;
  viewportEl.dataset.renderState = "loading";
  api.stop();

  try {
    if (ext === "tex") {
      const text = await file.text();
      api.tex(text);
    } else {
      const bytes = new Uint8Array(await file.arrayBuffer());
      const ok = api.load(bytes);
      if (!ok) {
        showError("ファイル形式の解析に失敗しました。破損や未対応形式を確認してください。");
      }
    }
  } catch (err) {
    showError(
      `ローカル譜面の読み込みに失敗しました: ${err?.message ?? String(err)}`,
    );
  } finally {
    fileInputEl.value = "";
  }
});

renderPresetButtons();
selectPreset(PRESETS[0].id);
