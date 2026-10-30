import {
  collectionPlan,
  resourceLimit,
  resourceRoom,
  resourceTotal,
  WAREHOUSE_COST,
} from "./storage.mjs";
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
const RECOVERY_PREFIX = `${SAVE_KEY}.recovery.`;
const RECOVERY_LATEST = `${SAVE_KEY}.recovery-latest`;
let recoveryRaw = null, recoverySafe = true, originalReadable = false;
let rawSave = null;
try {
  rawSave = localStorage.getItem(SAVE_KEY);
  originalReadable = true;
  if (rawSave !== null) state = decode(rawSave);
} catch (error) {
  if (error.recoveredState) state = error.recoveredState;
  saveWarning = error.recoveryMessage ??
    "保存を読み込めません。初期状態で開始しました。元の保存の退避を確認するまで上書きしません。";
  if (rawSave !== null) {
    recoveryRaw = rawSave;
    recoverySafe = preserveOriginal();
    saveWarning += recoverySafe
      ? " 元の保存を退避しました。遊び方と保存から書き出せます。"
      : " 退避できないため、元の保存は上書きしません。遊び方と保存から書き出せます。";
  }
}
if (recoveryRaw === null) {
  try {
    const key = localStorage.getItem(RECOVERY_LATEST);
    if (key?.startsWith(RECOVERY_PREFIX)) {
      recoveryRaw = localStorage.getItem(key);
    }
  } catch {
    /* Saving availability is reported separately; export is optional. */
  }
}
function preserveOriginal() {
  if (recoveryRaw === null) return true;
  try {
    for (let n = 0; n < 1000; n++) {
      const key = `${RECOVERY_PREFIX}${Date.now()}-${n}`;
      if (localStorage.getItem(key) !== null) continue;
      localStorage.setItem(key, recoveryRaw);
      if (localStorage.getItem(key) !== recoveryRaw) return false;
      localStorage.setItem(RECOVERY_LATEST, key);
      return true;
    }
  } catch { /* Do not overwrite the original if backup cannot be verified. */ }
  return false;
}
const symbols = { dock: "⚑", deck: "▦", home: "⌂", garden: "♧" };
const iconSymbols = { 灯台: "♜", 帆船: "⛵", 貝: "◉" };
function save() {
  if (!originalReadable) {
    saveWarning =
      "保存できません。既存保存を読み取れないため上書きしていません。再読込して確認してください。";
    return false;
  }
  if (!recoverySafe) recoverySafe = preserveOriginal();
  if (!recoverySafe) {
    saveWarning =
      "保存できません。元の保存の退避に失敗したため上書きしていません。遊び方と保存から書き出してください。";
    return false;
  }
  try {
    localStorage.setItem(SAVE_KEY, JSON.stringify(state));
    saveWarning = "このブラウザに保存しました。";
    return true;
  } catch {
    saveWarning =
      "保存できません。この画面を閉じると未保存の進行は失われます。";
    return false;
  }
}
function dispatch(action) {
  const result = act(state, action);
  state = result.state;
  if (result.changed && action.type === "build") selected = null;
  if (result.changed) save();
  if (result.remedy === "storage") setView("storage");
  render();
  $("status").textContent = result.message;
  if (result.changed && saveWarning.startsWith("保存できません")) {
    $("status").textContent += ` ${saveWarning}`;
  }
}
function render() {
  for (const key of ["wood", "metal"]) {
    $(key).textContent = resourceTotal(state, key);
  }
  $("xp").textContent = state.xp;
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
  const plan = collectionPlan(state);
  $("collect").textContent = state.collected >= 10000
    ? "回収回数の上限（10,000回）"
    : plan.wood + plan.metal === 0
    ? "保管が満杯です 倉庫を確認"
    : `漂流物を回収 木材 +${plan.wood} / 金属 +${plan.metal}`;
  $("export-recovery").hidden = recoveryRaw === null;
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
      ? (tile.kind === "dock"
        ? (state.storage.built ? "船着場・倉庫" : "船着場")
        : facilities[tile.kind].name)
      : "海";
    cell.setAttribute(
      "aria-label",
      `${y + 1}行${x + 1}列 ${name}${
        !tile && neighbors(state, x, y) ? " 建設可能な隣接区画" : ""
      }`,
    );
    cell.firstChild.textContent = tile ? symbols[tile.kind] : "≈";
    cell.lastChild.textContent = tile
      ? (tile.kind === "dock" && state.storage.built ? "倉庫" : name)
      : "";
  }
  $("cancel-build").hidden = !selected;
  $("placement-label").textContent = selected
    ? `${facilities[selected].name}を配置：木材${
      facilities[selected].wood
    } / 金属${facilities[selected].metal}`
    : "菜園を選ぶか、建設タブで施設を選びましょう";
  renderFarm();
  renderStorage();
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
      (event) => {
        if (selected) dispatch({ type: "build", x, y, kind: selected });
        else if (
          state.tiles.some((t) => t.x === x && t.y === y && t.kind === "dock")
        ) {
          setView("storage");
          renderStorage();
          if (event.detail === 0) {
            $("storage-heading").focus({ preventScroll: true });
          }
        } else if (
          state.tiles.some((t) => t.x === x && t.y === y && t.kind === "garden")
        ) {
          selectedGarden = `${x},${y}`;
          setView("farm");
          renderFarm();
          if (event.detail === 0) {
            $("crops").querySelector("button:not(:disabled)")?.focus({
              preventScroll: true,
            });
          }
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
  b.addEventListener("click", (event) => {
    selected = kind;
    setView("board");
    render();
    if (event.detail === 0) focusBoard();
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
  $("food").textContent = resourceTotal(state, "food");
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
      const plant = document.createElement("button");
      const harvest = document.createElement("button");
      plant.textContent = "種をまく 木材2";
      harvest.textContent = "収穫する";
      for (const [button, type] of [[plant, "plant"], [harvest, "harvest"]]) {
        button.addEventListener("click", (event) => {
          dispatch({ type, x: t.x, y: t.y });
          // A completed keyboard action must not focus another paid action.
          if (event.detail === 0) $("status").focus({ preventScroll: true });
        });
      }
      // Keep two distinct controls and positions: a second harvest click can
      // never turn into planting, even when a crop completes between clicks.
      row.append(label, plant, harvest);
      container.append(row);
    }
    const start = state.farm.crops[key];
    row.firstChild.textContent = `${t.y + 1}行${t.x + 1}列 菜園：${
      start === undefined ? "種まきできます" : cropStatus(start, Date.now())
    }`;
    row.children[1].disabled = start !== undefined;
    row.children[2].disabled = start === undefined;
  }
}
function renderStorage() {
  const names = { wood: "木材", metal: "金属", food: "食料" };
  for (const key of Object.keys(names)) {
    const total = resourceTotal(state, key), cap = resourceLimit(state);
    $(`storage-${key}`).textContent = `${total.toLocaleString("ja-JP")} / ${
      cap.toLocaleString("ja-JP")
    }${total === cap ? " 満杯" : ""}`;
    const meter = $(`meter-${key}`);
    meter.max = cap;
    meter.value = total;
    meter.setAttribute("aria-label", `${names[key]} ${total} / ${cap}`);
  }
  $("warehouse-state").textContent = state.storage.built
    ? "船着場に増設済み。各資源の保管上限は199,998です。"
    : "船着場へ1棟増設すると、木材・金属・食料の保管上限が各99,999から199,998になります。";
  const wood = Math.max(0, WAREHOUSE_COST.wood - resourceTotal(state, "wood"));
  const metal = Math.max(
    0,
    WAREHOUSE_COST.metal - resourceTotal(state, "metal"),
  );
  $("warehouse-requirements").textContent = state.storage.built
    ? "倉庫は1棟まで。資材は追加で使いません。"
    : wood || metal
    ? `不足：木材あと${wood} / 金属あと${metal}。下の「回収へ」から集められます。`
    : "増設できます。新しい区画は使わず、盤面25区画でも増設できます。";
  $("warehouse-build").disabled = state.storage.built;
  $("delivery-room").textContent =
    resourceRoom(state, "wood") >= 4 && resourceRoom(state, "metal") >= 1
      ? "食卓のお礼（木材4・金属1）を保管できます。食料3が必要です。"
      : "食卓のお礼を保管する空きが足りません。食料は自動で使いません。建設・種まきで空きを作るか、お礼なしで分けられます。";
  $("share-food").disabled = resourceTotal(state, "food") < 3;
}
$("choose-warehouse").addEventListener("click", (event) => {
  selected = null;
  setView("storage");
  render();
  if (event.detail === 0) $("storage-heading").focus({ preventScroll: true });
});
$("warehouse-build").addEventListener("click", (event) => {
  dispatch({ type: "build-warehouse" });
  if (event.detail === 0) $("status").focus({ preventScroll: true });
});
$("storage-collect").addEventListener("click", () => {
  setView("board");
  $("collect").focus({ preventScroll: true });
});
$("storage-build").addEventListener("click", () => {
  setView("build");
  $("facilities").firstElementChild.focus({ preventScroll: true });
});
$("storage-farm").addEventListener("click", () => {
  setView("farm");
  $("donate-food").focus({ preventScroll: true });
});
$("share-food").addEventListener("click", () => $("share-dialog").showModal());
$("cancel-share").addEventListener("click", () => $("share-dialog").close());
$("confirm-share").addEventListener("click", () => {
  dispatch({ type: "share-food" });
  $("share-dialog").close();
  $("status").focus({ preventScroll: true });
});
$("export-recovery").addEventListener("click", () => {
  if (recoveryRaw === null) return;
  const url = URL.createObjectURL(
    new Blob([recoveryRaw], { type: "application/json" }),
  );
  const link = document.createElement("a");
  link.href = url;
  link.download = `sea-shelter-recovery-${Date.now()}.json`;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
});
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
$("cancel-build").addEventListener("click", (event) => {
  selected = null;
  render();
  $("status").textContent = "建設を取り消しました。資材は使っていません。";
  if (event.detail === 0) focusBoard();
});
$("help").addEventListener("click", () => $("help-dialog").showModal());
$("close-help").addEventListener("click", () => $("help-dialog").close());
render();
if (saveWarning) $("status").textContent = saveWarning;

function focusBoard() {
  (document.querySelector("#board button.near") ?? $("board").firstElementChild)
    ?.focus({ preventScroll: true });
}
function fitBoard() {
  const play = document.querySelector(".play");
  if (!play.clientHeight) return;
  const main = document.querySelector("main");
  const previousExtra = Number(main.dataset.layoutExtra ?? 0);
  const tileCount = $("tile-count").getBoundingClientRect().height;
  const room = play.clientHeight -
    document.querySelector(".placement").getBoundingClientRect().height -
    tileCount - 8;
  // Long warnings and enlarged text may need more than a viewport. Preserve
  // 44px cells by adding reachable page height instead of overlapping controls.
  const extra = Math.max(0, Math.ceil(246 - (room - previousExtra)));
  if (extra !== previousExtra) {
    main.dataset.layoutExtra = String(extra);
    main.style.setProperty("--layout-extra", `${extra}px`);
  }
  const size = Math.max(246, Math.floor(Math.min(play.clientWidth, room)));
  $("board").style.setProperty("--board-size", `${size}px`);
}
new ResizeObserver(() => requestAnimationFrame(fitBoard)).observe(
  document.querySelector(".play"),
);
fitBoard();

new ResizeObserver(() => {
  const main = document.querySelector("main");
  const height =
    Math.ceil(document.querySelector(".tabs").getBoundingClientRect().height) +
    6;
  const value = `${height}px`;
  if (main.style.getPropertyValue("--tabs-room") !== value) {
    main.style.setProperty("--tabs-room", value);
  }
  requestAnimationFrame(fitBoard);
}).observe(document.querySelector(".tabs"));
