import { cropStatus } from "./farm.mjs";
import {
  act,
  capacity,
  decode,
  facilities,
  initialState,
  neighbors,
  quests,
  SAVE_KEY,
} from "./model.mjs";
const $ = (id) => document.getElementById(id);
let state = initialState(),
  selected = null,
  selectedGarden = null,
  saveWarning = "";
try {
  const raw = localStorage.getItem(SAVE_KEY);
  if (raw !== null) state = decode(raw);
} catch {
  saveWarning =
    "保存を読み込めません。初期状態で開始しました。次の操作でこのゲームの保存を更新します。";
}
const symbols = { dock: "⚑", deck: "▦", home: "⌂", garden: "♧" };
const iconSymbols = { 灯台: "♜", 帆船: "⛵", 貝: "◉" };
function save() {
  try {
    localStorage.setItem(SAVE_KEY, JSON.stringify(state));
    saveWarning = "このブラウザに保存しました。";
  } catch {
    saveWarning = "保存できません。この画面を閉じると進行が失われます。";
  }
}
function dispatch(action) {
  const result = act(state, action);
  state = result.state;
  if (result.changed && action.type === "build") selected = null;
  if (result.changed) save();
  render();
  $("status").textContent = result.message;
  if (result.changed && saveWarning.startsWith("保存できません")) {
    $("status").textContent += ` ${saveWarning}`;
  }
}
function render() {
  for (const key of ["wood", "metal", "xp"]) $(key).textContent = state[key];
  $("residents").textContent = `${state.residents} / ${capacity(state)}`;
  $("tile-count").textContent = `${state.tiles.length} / 25区画`;
  $("captain-name").textContent = state.profile.name;
  $("captain-title").textContent = state.profile.title;
  $("bubble").textContent = state.profile.bubble;
  $("avatar").textContent = iconSymbols[state.profile.icon];
  $("avatar").className =
    { 波: "", 夕日: "sun", 星: "star" }[state.profile.frame];
  $("save-status").textContent = saveWarning ||
    "回収・建設などの操作後に自動保存します。";
  $("collect").textContent = `漂流物を回収　木材 +${
    3 + Math.floor(state.residents / 3)
  } / 金属 +2`;
  $("guide").textContent = state.claimed.length === 3
    ? "3件の依頼達成！ 潮灯の守り手の称号をプロフィールで選べます。自由に拡張を続けましょう。"
    : !state.claimed.includes("supplies")
    ? "① 漂流物を3回回収して、ミナへ報告しよう。"
    : !state.claimed.includes("shelter")
    ? "② 住居を選び、拠点に隣接する海へ建設しよう。"
    : "③ 住民3人と菜園を迎えよう。菜園はEXP24で解放。";
  // Keep board and action buttons stable so repeated taps and keyboard focus do not jump.
  for (const cell of $("board").children) {
    const x = Number(cell.dataset.x),
      y = Number(cell.dataset.y),
      tile = state.tiles.find((t) => t.x === x && t.y === y);
    cell.className = tile
      ? "built"
      : `sea ${neighbors(state, x, y) ? "near" : ""}`;
    const name = tile
      ? (tile.kind === "dock" ? "船着場" : facilities[tile.kind].name)
      : "海";
    cell.setAttribute(
      "aria-label",
      `${y + 1}行${x + 1}列 ${name}${
        !tile && neighbors(state, x, y) ? " 建設可能な隣接区画" : ""
      }`,
    );
    cell.firstChild.textContent = tile ? symbols[tile.kind] : "≈";
    cell.lastChild.textContent = tile ? name : "";
  }
  $("cancel-build").hidden = !selected;
  $("placement-label").textContent = selected
    ? `${facilities[selected].name}を配置：木材${
      facilities[selected].wood
    } / 金属${facilities[selected].metal}`
    : "菜園を選ぶか、建設タブで施設を選びましょう";
  renderFarm();
  for (const button of $("facilities").children) {
    const kind = button.dataset.kind, f = facilities[kind];
    button.setAttribute("aria-pressed", String(kind === selected));
    button.querySelector("small").textContent =
      `木材${f.wood} / 金属${f.metal}　${
        state.xp < f.xp ? `EXP ${f.xp}で解放` : "解放済み"
      }`;
  }
  quests.forEach((q) => {
    const button = $(`quest-${q.id}`), done = state.claimed.includes(q.id);
    button.disabled = done || !q.ready(state);
    button.textContent = done ? "報告済み ✓" : `報告する　EXP +${q.reward}`;
  });
}
for (let y = 0; y < 5; y++) {
  for (let x = 0; x < 5; x++) {
    const b = document.createElement("button");
    b.dataset.x = x;
    b.dataset.y = y;
    b.append(document.createElement("span"), document.createElement("small"));
    b.addEventListener(
      "click",
      () => {
        if (selected) dispatch({ type: "build", x, y, kind: selected });
        else if (
          state.tiles.some((t) => t.x === x && t.y === y && t.kind === "garden")
        ) {
          selectedGarden = `${x},${y}`;
          setView("farm");
          renderFarm();
        } else {$("status").textContent =
            "建設タブで施設を選ぶと配置できます。菜園はタップして栽培できます。";}
      },
    );
    $("board").append(b);
  }
}
for (const [kind, f] of Object.entries(facilities)) {
  const b = document.createElement("button");
  b.dataset.kind = kind;
  b.append(
    document.createTextNode(`${symbols[kind]} ${f.name}`),
    document.createElement("small"),
  );
  b.addEventListener("click", () => {
    selected = kind;
    setView("board");
    render();
    $("status").textContent =
      `${f.name}を選択。建設先の海をタップしてください。`;
  });
  $("facilities").append(b);
}
quests.forEach((q) => {
  const div = document.createElement("div");
  div.className = "quest";
  const label = document.createElement("p");
  label.textContent = q.name;
  const b = document.createElement("button");
  b.id = `quest-${q.id}`;
  b.addEventListener("click", () => dispatch({ type: "claim", id: q.id }));
  div.append(label, b);
  $("quests").append(div);
});
$("collect").addEventListener("click", () => dispatch({ type: "collect" }));
$("invite").addEventListener("click", () => dispatch({ type: "invite" }));
$("reset").addEventListener("click", () => $("reset-dialog").showModal());
$("cancel-reset").addEventListener("click", () => $("reset-dialog").close());
$("confirm-reset").addEventListener("click", () => {
  state = initialState();
  selected = null;
  selectedGarden = null;
  setView("board");
  save();
  render();
  $("status").textContent = "新しい船出です。漂流物から集めましょう。";
  $("reset-dialog").close();
});
$("edit-profile").addEventListener("click", () => {
  $("profile-error").textContent = "";
  const form = $("profile-form");
  for (const key of ["name", "bubble", "icon", "frame"]) {
    form.elements.namedItem(key).value = state.profile[key];
  }
  const titles = [
    "漂流の船長",
    ...(state.xp >= 24 ? ["海の建築家"] : []),
    ...(state.claimed.length === 3 ? ["潮灯の守り手"] : []),
  ];
  const select = form.elements.namedItem("title");
  select.replaceChildren(...titles.map((t) => new Option(t, t)));
  select.value = state.profile.title;
  $("profile-dialog").showModal();
});
$("cancel-profile").addEventListener(
  "click",
  () => $("profile-dialog").close(),
);
$("profile-form").addEventListener("submit", (event) => {
  event.preventDefault();
  const profile = Object.fromEntries(new FormData(event.currentTarget));
  const result = act(state, { type: "profile", profile });
  if (result.changed) {
    dispatch({ type: "profile", profile });
    $("profile-dialog").close();
  } else $("profile-error").textContent = result.message;
});

function renderFarm() {
  $("food").textContent = state.farm.food;
  const allGardens = state.tiles.filter((t) => t.kind === "garden");
  const current = allGardens.find((t) => `${t.x},${t.y}` === selectedGarden) ??
    allGardens[0];
  selectedGarden = current ? `${current.x},${current.y}` : null;
  const gardens = current ? [current] : [];
  $("farm-empty").hidden = gardens.length > 0;
  const container = $("crops");
  const keys = new Set(gardens.map((t) => `${t.x},${t.y}`));
  for (const row of [...container.children]) {
    if (!keys.has(row.dataset.key)) row.remove();
  }
  for (const t of gardens) {
    const key = `${t.x},${t.y}`;
    let row = [...container.children].find((r) => r.dataset.key === key);
    if (!row) {
      row = document.createElement("div");
      row.className = "quest";
      row.dataset.key = key;
      const label = document.createElement("p");
      const button = document.createElement("button");
      button.addEventListener("click", () =>
        dispatch({
          type: state.farm.crops[key] === undefined ? "plant" : "harvest",
          x: t.x,
          y: t.y,
        }));
      row.append(label, button);
      container.append(row);
    }
    const start = state.farm.crops[key];
    row.firstChild.textContent = `${t.y + 1}行${t.x + 1}列 菜園：${
      start === undefined ? "種まきできます" : cropStatus(start, Date.now())
    }`;
    row.lastChild.textContent = start === undefined
      ? "種をまく 木材2"
      : "収穫する";
  }
}
$("donate-food").addEventListener(
  "click",
  () => dispatch({ type: "donate-food" }),
);
setInterval(renderFarm, 1000);

function setView(view) {
  document.querySelector("main").dataset.view = view;
  for (const button of document.querySelectorAll(".tabs button")) {
    button.setAttribute("aria-pressed", String(button.dataset.view === view));
  }
}
for (const button of document.querySelectorAll(".tabs button")) {
  button.addEventListener("click", () => setView(button.dataset.view));
}
$("cancel-build").addEventListener("click", () => {
  selected = null;
  render();
  $("status").textContent = "建設を取り消しました。資材は使っていません。";
});
$("help").addEventListener("click", () => $("help-dialog").showModal());
$("close-help").addEventListener("click", () => $("help-dialog").close());
render();
if (saveWarning) $("status").textContent = saveWarning;
