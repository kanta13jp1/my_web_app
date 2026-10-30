export const GROW_MS = 60000;
const MAX_GAP = 7 * 86400000;
const validTime = (n) =>
  Number.isSafeInteger(n) && n >= 0 && n <= 8640000000000000;
export const newFarm = () => ({ food: 0, harvested: 0, crops: {} });

export function checkFarm(farm, tiles) {
  if (
    !farm || !Number.isInteger(farm.food) || farm.food < 0 ||
    farm.food > 99999 ||
    !Number.isInteger(farm.harvested) || farm.harvested < 0 ||
    farm.harvested > 99999 ||
    !farm.crops || typeof farm.crops !== "object" || Array.isArray(farm.crops)
  ) throw Error("farm");
  for (const [key, time] of Object.entries(farm.crops)) {
    if (
      !tiles.some((t) => t.kind === "garden" && `${t.x},${t.y}` === key) ||
      !validTime(time)
    ) throw Error("crop");
  }
  return farm;
}

export function cropStatus(start, now) {
  if (!validTime(now) || now < start) {
    return "時計を確認してください（生育を一時停止）";
  }
  if (now - start > MAX_GAP) {
    return "長い経過を確認しました。収穫操作で育て直します";
  }
  return now - start >= GROW_MS
    ? "収穫できます"
    : `収穫まで ${Math.ceil((GROW_MS - now + start) / 1000)}秒`;
}

export function farmAction(state, action, now) {
  const fail = (message) => ({ state, message, changed: false });
  const s = structuredClone(state);
  s.farm ??= newFarm();
  const f = s.farm;
  if (action.type === "donate-food") {
    if (f.food < 3) {
      return fail(
        "食卓の依頼には食料3が必要です。菜園で育てて収穫しましょう。",
      );
    }
    f.food -= 3;
    s.wood = Math.min(99999, s.wood + 4);
    s.metal = Math.min(99999, s.metal + 1);
    s.xp = Math.min(99999, s.xp + 2);
    return {
      state: s,
      changed: true,
      message: "食卓の依頼を達成！ 食料 -3 / 木材 +4 / 金属 +1 / EXP +2",
    };
  }
  if (!validTime(now)) return fail("端末の時計を確認してください。");
  const tile = s.tiles.find((t) =>
    t.x === action.x && t.y === action.y && t.kind === "garden"
  );
  if (!tile) return fail("菜園を建ててから育てましょう。");
  const key = `${tile.x},${tile.y}`;
  const start = f.crops[key];
  if (action.type === "plant") {
    if (start !== undefined) {
      return fail("この菜園は栽培中です。収穫まで待ちましょう。");
    }
    if (s.wood < 2) return fail("種まきには木材2が必要です。");
    s.wood -= 2;
    f.crops[key] = now;
    return {
      state: s,
      changed: true,
      message:
        "種をまきました。60秒で食料3を収穫できます。閉じている間も育ちます。",
    };
  }
  if (start === undefined) return fail("まず種をまきましょう。");
  if (now < start || now - start < GROW_MS) return fail(cropStatus(start, now));
  if (now - start > MAX_GAP) {
    f.crops[key] = now;
    return {
      state: s,
      changed: true,
      message:
        "7日を超える時刻の変化を検出しました。報酬を増やさず、今から60秒育て直します。",
    };
  }
  if (f.food > 99996) {
    return fail("食料がいっぱいです。食卓の依頼に届けましょう。");
  }
  delete f.crops[key];
  f.food += 3;
  f.harvested = Math.min(99999, f.harvested + 1);
  return {
    state: s,
    changed: true,
    message: "収穫できました！ 食料 +3。食卓の依頼に届けられます。",
  };
}
