const counts = ['input', 'cacheWrite', 'cacheRead', 'output', 'turns'];
export function parse(text) {
  if (text.length > 500000) throw Error('入力は50万文字以内にしてください。');
  let rows;
  try { rows = JSON.parse(text); } catch { throw Error('JSONの形式を確認してください。'); }
  if (!Array.isArray(rows) || !rows.length || rows.length > 200) throw Error('1〜200試行の配列を入力してください。');
  const ids = new Set(), models = new Set();
  const clean = rows.map((r, i) => {
    if (!r || typeof r !== 'object' || Array.isArray(r)) throw Error(`${i + 1}行目の形式を確認してください。`);
    const row = {};
    for (const key of ['id', 'condition', 'model']) {
      if (typeof r[key] !== 'string' || !r[key].trim() || r[key].length > 80) throw Error(`${i + 1}行目の${key}は1〜80文字で指定してください。`);
      row[key] = r[key].trim();
    }
    if (ids.has(row.id)) throw Error('試行のidが重複しています。');
    ids.add(row.id); models.add(row.model);
    for (const key of counts) {
      if (!Number.isSafeInteger(r[key]) || r[key] < 0 || r[key] > 1e12 || (key === 'turns' && !r[key])) throw Error(`${i + 1}行目の${key}は適切な整数で指定してください（turnsは1以上）。`);
      row[key] = r[key];
    }
    for (const key of ['modelUSD', 'runUSD']) {
      if (typeof r[key] !== 'number' || !Number.isFinite(r[key]) || r[key] < 0 || r[key] > 1e9) throw Error(`${i + 1}行目の${key}は0以上の数値で指定してください。`);
      row[key] = r[key];
    }
    if (row.modelUSD > row.runUSD + 1e-9) throw Error('モデル分の換算額が作業全体を超えています。');
    return row;
  });
  if (models.size !== 1) throw Error('同じモデルの試行だけで比較してください。');
  if (new Set(clean.map(r => r.condition)).size > 12) throw Error('条件は12種類以内にしてください。');
  return clean;
}
export function compare(rows, baseline) {
  const groups = new Map();
  for (const r of rows) {
    if (!groups.has(r.condition)) groups.set(r.condition, {condition:r.condition, n:0, input:0, cacheWrite:0, cacheRead:0, output:0, turns:0, modelUSD:0, runUSD:0});
    const g = groups.get(r.condition); g.n++;
    for (const key of [...counts, 'modelUSD', 'runUSD']) g[key] += r[key];
  }
  const result = [...groups.values()].map(g => ({...g, totalInput:g.input + g.cacheWrite + g.cacheRead,
    meanInput:(g.input + g.cacheWrite + g.cacheRead) / g.n,
    perTurn:(g.input + g.cacheWrite + g.cacheRead) / g.turns}));
  const base = result.find(g => g.condition === baseline);
  if (!base) throw Error('基準にする条件を選んでください。');
  return result.map(g => ({...g, ratio:base.meanInput === 0 ? null : g.meanInput / base.meanInput}));
}
