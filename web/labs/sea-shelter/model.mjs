import {
  buildWarehouse,
  changeResources,
  checkStorage,
  collectionPlan,
  newStorage,
  recoverStorage,
} from "./storage.mjs";
import { checkFarm, farmAction, newFarm } from "./farm.mjs";
export const SAVE_KEY = "my_web_app.sea_shelter.v1";
export const initialState = () => ({
  version: 1,
  farm: newFarm(),
  storage: newStorage(),
  wood: 0,
  metal: 0,
  xp: 0,
  residents: 1,
  collected: 0,
  claimed: [],
  tiles: [{ x: 2, y: 2, kind: "dock" }],
  profile: {
    name: "新米船長",
    icon: "灯台",
    frame: "波",
    bubble: "今日も一歩ずつ",
    title: "漂流の船長",
  },
});
export const facilities = {
  deck: { name: "浮き床", wood: 4, metal: 0, xp: 0 },
  home: { name: "住居", wood: 8, metal: 3, xp: 8 },
  garden: { name: "菜園", wood: 10, metal: 5, xp: 24 },
};
export const quests = [
  {
    id: "supplies",
    name: "ミナの依頼：漂流物を3回回収",
    ready: (s) => s.collected >= 3,
    reward: 8,
  },
  {
    id: "shelter",
    name: "ソラの依頼：住居を建てる",
    ready: (s) => s.tiles.some((t) => t.kind === "home"),
    reward: 12,
  },
  {
    id: "community",
    name: "ナギの依頼：住民3人と菜園を迎える",
    ready: (s) => s.residents >= 3 && s.tiles.some((t) => t.kind === "garden"),
    reward: 20,
  },
];
export const capacity = (s) =>
  1 + s.tiles.filter((t) => t.kind === "home").length * 2;
export const neighbors = (s, x, y) =>
  s.tiles.some((t) => Math.abs(t.x - x) + Math.abs(t.y - y) === 1);
export function act(state, action, now = Date.now()) {
  if (action.type === "build-warehouse") return buildWarehouse(state);
  if (["plant", "harvest", "donate-food", "share-food"].includes(action.type)) {
    return farmAction(state, action, now);
  }
  const s = changeResources(structuredClone(state));
  const fail = (message, remedy) => ({
    state,
    message,
    changed: false,
    remedy,
  });
  let message;
  if (action.type === "collect") {
    if (s.collected >= 10000) {
      return fail(
        "回収回数の上限10,000回です。建設・菜園・食卓を続けられます。",
      );
    }
    const plan = collectionPlan(s);
    if (plan.wood === 0 && plan.metal === 0) {
      return fail(
        "木材と金属の保管が満杯です。倉庫で空きと解消方法を確認しましょう。",
        "storage",
      );
    }
    changeResources(s, { wood: plan.wood, metal: plan.metal });
    s.collected++;
    s.xp = Math.min(99999, s.xp + 1);
    const partial = plan.wood < plan.desired.wood ||
      plan.metal < plan.desired.metal;
    message = `漂流物を回収！ 木材 +${plan.wood} / 金属 +${plan.metal}${
      partial
        ? "。保管できる分だけ受け取り、満杯の資源は回収していません。"
        : ""
    }`;
  } else if (action.type === "build") {
    const { x, y, kind } = action,
      f = Object.hasOwn(facilities, kind) ? facilities[kind] : null;
    if (
      !f || !Number.isInteger(x) || !Number.isInteger(y) || x < 0 || y < 0 ||
      x > 4 || y > 4
    ) return fail("建設場所を選んでください。");
    const existing = s.tiles.findIndex((t) => t.x === x && t.y === y);
    if (
      existing >= 0 &&
      (s.tiles[existing].kind === "dock" || s.tiles[existing].kind === kind)
    ) {
      return fail(
        "同じ施設や船着場には建設できません。別の区画か施設を選んでください。",
      );
    }
    if (existing < 0 && !neighbors(s, x, y)) {
      return fail("拠点に上下左右で隣接する海だけに建設できます。");
    }
    if (s.xp < f.xp) return fail(`${f.name}は EXP ${f.xp} で解放されます。`);
    if (s.wood < f.wood || s.metal < f.metal) {
      return fail(
        `資材不足：木材あと${Math.max(0, f.wood - s.wood)} / 金属あと${
          Math.max(0, f.metal - s.metal)
        }`,
      );
    }
    if (existing >= 0 && s.farm?.crops[`${x},${y}`] !== undefined) {
      return fail("栽培中の菜園は収穫してから建て替えましょう。");
    }
    if (existing >= 0) s.tiles[existing] = { x, y, kind };
    else s.tiles.push({ x, y, kind });
    if (s.residents > capacity(s)) {
      return fail(
        "住民が暮らす住居は減らせません。先に別の住居を建てましょう。",
      );
    }
    changeResources(s, { wood: -f.wood, metal: -f.metal });
    s.xp = Math.min(99999, s.xp + 3);
    message = `${f.name}を建設しました！`;
  } else if (action.type === "invite") {
    if (s.residents >= capacity(s)) {
      return fail("住居を建てて定員を増やしましょう。");
    }
    if (s.wood < 3 || s.metal < 1) {
      return fail("迎え入れには木材3・金属1が必要です。");
    }
    changeResources(s, { wood: -3, metal: -1 });
    s.residents++;
    s.xp = Math.min(99999, s.xp + 2);
    message = "新しい住民が到着！ 住民3人ごとに回収木材が1増えます。";
  } else if (action.type === "claim") {
    const q = quests.find((q) => q.id === action.id);
    if (!q || s.claimed.includes(q.id) || !q.ready(s)) {
      return fail("依頼は達成後に一度だけ報告できます。");
    }
    s.claimed.push(q.id);
    s.xp = Math.min(99999, s.xp + q.reward);
    message = `依頼達成！ EXP +${q.reward}`;
  } else if (action.type === "profile") {
    const p = action.profile;
    if (
      !p || typeof p.name !== "string" || !p.name.trim() ||
      p.name.trim().length > 16 || typeof p.bubble !== "string" ||
      p.bubble.length > 40 || !["灯台", "帆船", "貝"].includes(p.icon) ||
      !["波", "夕日", "星"].includes(p.frame) ||
      ![
        "漂流の船長",
        ...(s.xp >= 24 ? ["海の建築家"] : []),
        ...(s.claimed.length === 3 ? ["潮灯の守り手"] : []),
      ].includes(p.title)
    ) {
      return fail(
        "名前は1〜16文字、吹き出しは40文字以内。解放済みの称号を選んでください。",
      );
    }
    s.profile = {
      name: p.name.trim(),
      bubble: p.bubble,
      icon: p.icon,
      frame: p.frame,
      title: p.title,
    };
    message = "プロフィールを更新しました。";
  } else return fail("操作を確認してください。");
  return { state: s, message, changed: true };
}
export function decode(raw) {
  const s = JSON.parse(raw);
  if (!s || s.version !== 1) throw Error("version");
  for (const key of ["wood", "metal", "xp", "residents", "collected"]) {
    if (
      !Number.isInteger(s[key]) || s[key] < 0 ||
      s[key] > (key === "collected" ? 10000 : 99999)
    ) throw Error(key);
  }
  if (
    !Array.isArray(s.tiles) || s.tiles.length < 1 || s.tiles.length > 25 ||
    !Array.isArray(s.claimed) ||
    s.claimed.some((id) => !quests.some((q) => q.id === id)) ||
    new Set(s.claimed).size !== s.claimed.length
  ) throw Error("shape");
  if (s.tiles[0].x !== 2 || s.tiles[0].y !== 2 || s.tiles[0].kind !== "dock") {
    throw Error("dock");
  }
  const seen = new Set();
  s.tiles.forEach((t, i) => {
    if (
      !t || !Number.isInteger(t.x) || !Number.isInteger(t.y) || t.x < 0 ||
      t.x > 4 || t.y < 0 || t.y > 4 ||
      !(i === 0 ? t.kind === "dock" : Object.hasOwn(facilities, t.kind))
    ) throw Error("tile");
    const key = `${t.x},${t.y}`;
    if (
      seen.has(key) ||
      (i > 0 && !neighbors({ tiles: s.tiles.slice(0, i) }, t.x, t.y))
    ) throw Error("connection");
    seen.add(key);
  });
  if (s.residents < 1 || s.residents > capacity(s)) throw Error("progress");
  if (s.farm === undefined) s.farm = newFarm();
  const checked = act({ ...s, farm: newFarm(), storage: newStorage() }, {
    type: "profile",
    profile: s.profile,
  });
  if (!checked.changed) throw Error("profile");
  s.profile = checked.state.profile;
  const recovery = [];
  try {
    checkFarm(s.farm, s.tiles);
  } catch {
    s.farm = newFarm();
    recovery.push(
      "農園の保存を読み込めません。農園だけを初期化し、拠点・基礎資源・依頼・プロフィールは保護しました。",
    );
  }
  if (s.storage === undefined) s.storage = newStorage();
  try {
    checkStorage(s.storage);
  } catch {
    s.storage = recoverStorage(s.storage);
    recovery.push(
      "倉庫の保存に不整合があります。基礎資源と有効な拡張枠を保護して復旧しました。",
    );
  }
  changeResources(s);
  if (recovery.length) {
    throw Object.assign(Error("recovery"), {
      recoveredState: s,
      recoveryMessage: recovery.join(" "),
    });
  }
  return s;
}
