export const RESOURCE_KEYS = ["wood", "metal", "food"];
export const BASE_CAP = 99999;
export const WAREHOUSE_COST = { wood: 30, metal: 15 };
export const newStorage = () => ({
  version: 1,
  built: false,
  reserve: { wood: 0, metal: 0, food: 0 },
});
export const resourceLimit = (state) =>
  state.storage?.built ? BASE_CAP * 2 : BASE_CAP;
const baseValue = (state, key) => key === "food" ? state.farm.food : state[key];
export const resourceTotal = (state, key) =>
  baseValue(state, key) + (state.storage?.reserve?.[key] ?? 0);
export const resourceRoom = (state, key) =>
  resourceLimit(state) - resourceTotal(state, key);

export function checkStorage(value) {
  if (
    !value || value.version !== 1 || typeof value.built !== "boolean" ||
    !value.reserve || typeof value.reserve !== "object" ||
    Array.isArray(value.reserve)
  ) throw Error("storage");
  for (const key of RESOURCE_KEYS) {
    const n = value.reserve[key];
    if (
      !Number.isInteger(n) || n < 0 || n > BASE_CAP || (!value.built && n !== 0)
    ) throw Error("reserve");
  }
  return value;
}

// Keep every individually valid quantity; the caller preserves the raw save
// before allowing any repaired state to overwrite it.
export function recoverStorage(value) {
  const result = newStorage();
  for (const key of RESOURCE_KEYS) {
    const n = value?.reserve?.[key];
    if (Number.isInteger(n) && n >= 0 && n <= BASE_CAP) result.reserve[key] = n;
  }
  result.built = value?.built === true ||
    RESOURCE_KEYS.some((key) => result.reserve[key] > 0);
  return result;
}

export function changeResources(state, deltas = {}) {
  const next = Object.fromEntries(
    RESOURCE_KEYS.map((
      key,
    ) => [key, resourceTotal(state, key) + (deltas[key] ?? 0)]),
  );
  // Validate the whole transaction before changing any field. Never clamp gains.
  for (const n of Object.values(next)) {
    if (!Number.isInteger(n) || n < 0 || n > resourceLimit(state)) {
      throw Error("resource transaction");
    }
  }
  state.storage ??= newStorage();
  for (const key of RESOURCE_KEYS) {
    const core = Math.min(BASE_CAP, next[key]);
    if (key === "food") state.farm.food = core;
    else state[key] = core;
    state.storage.reserve[key] = next[key] - core;
  }
  return state;
}

export function collectionPlan(state) {
  const desired = { wood: 3 + Math.floor(state.residents / 3), metal: 2 };
  return {
    wood: Math.min(resourceRoom(state, "wood"), desired.wood),
    metal: Math.min(resourceRoom(state, "metal"), desired.metal),
    desired,
  };
}

export function buildWarehouse(state) {
  const fail = (message) => ({ state, changed: false, message });
  if (state.storage?.built) {
    return fail("倉庫は増設済みです。資材は使っていません。");
  }
  const missing = Object.entries(WAREHOUSE_COST).map(([key, cost]) =>
    Math.max(0, cost - resourceTotal(state, key))
  );
  if (missing.some((n) => n > 0)) {
    return fail(
      `増設には木材があと${missing[0]} / 金属があと${
        missing[1]
      }必要です。回収へ進みましょう。`,
    );
  }
  const s = structuredClone(state);
  s.storage ??= newStorage();
  s.storage.built = true;
  changeResources(s, {
    wood: -WAREHOUSE_COST.wood,
    metal: -WAREHOUSE_COST.metal,
  });
  return {
    state: s,
    changed: true,
    message:
      "船着場に倉庫を増設しました。木材・金属・食料の上限が各199,998になりました。新しい区画は使いません。",
  };
}
