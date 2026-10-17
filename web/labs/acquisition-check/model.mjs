const DAY = 86400000;
export function day(value) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) throw Error('日付は YYYY-MM-DD の形で入力してください。');
  const n = Date.parse(`${value}T00:00:00Z`);
  if (!Number.isFinite(n) || new Date(n).toISOString().slice(0, 10) !== value) throw Error(`存在しない日付です: ${value}`);
  return n;
}
export function count(value, label) {
  if (!/^\d+$/.test(value)) throw Error(`${label}: 件数には0以上の整数を入力してください。空欄は0件に置き換えません。`);
  const n = Number(value);
  if (!Number.isSafeInteger(n)) throw Error(`${label}: 件数が大きすぎます。`);
  return n;
}
export function parseRows(text) {
  if (text.length > 150000) throw Error('入力は15万文字以内にしてください。');
  const lines = text.trim().replace(/^\uFEFF/, '').split(/\r?\n/);
  const header = lines.shift().split(',').map(s => s.trim());
  if (!['date,count', 'date,count,control', 'date,count,control,impressions'].includes(header.join(','))) {
    throw Error('先頭行は date,count または date,count,control または date,count,control,impressions にしてください。');
  }
  if (!lines.length || lines.length > 730) throw Error('日別の記録を1〜730行で入力してください。');
  const seen = new Set();
  return lines.map((line, i) => {
    const cells = line.split(',').map(s => s.trim());
    if (cells.length !== header.length) throw Error(`${i + 2}行目: 列の数が違います。`);
    day(cells[0]);
    if (seen.has(cells[0])) throw Error(`日付が重複しています: ${cells[0]}`);
    seen.add(cells[0]);
    const row = { date: cells[0], count: count(cells[1], `${i + 2}行目`) };
    header.slice(2).forEach((key, j) => { row[key] = count(cells[j + 2], `${i + 2}行目 ${key}`); });
    return row;
  });
}
function range(start, end) {
  const a = day(start), b = day(end);
  if (b < a || (b - a) / DAY >= 366) throw Error('各期間は開始日から366日以内で指定してください。');
  return Array.from({ length: (b - a) / DAY + 1 }, (_, i) => new Date(a + i * DAY).toISOString().slice(0, 10));
}
export function signTest(differences) {
  const plus = differences.filter(v => v > 0).length, minus = differences.filter(v => v < 0).length;
  const n = plus + minus;
  let term = 2 ** -n, sum = term;
  for (let k = 1; k <= Math.min(plus, minus); k++) { term *= (n - k + 1) / k; sum += term; }
  return { plus, minus, ties: differences.length - n, p: n ? Math.min(1, 2 * sum) : 1 };
}
export function compare(rows, periods) {
  const beforeDates = range(periods.beforeStart, periods.beforeEnd), afterDates = range(periods.afterStart, periods.afterEnd);
  if (beforeDates.some(d => afterDates.includes(d))) throw Error('変更前と変更後の期間が重なっています。');
  const index = new Map(rows.map(r => [r.date, r]));
  const missing = [...beforeDates, ...afterDates].filter(d => !index.has(d));
  if (missing.length) return { ready: false, missing, explanation: '記録のない日があります。0件とは扱わず、比較を保留しました。' };
  const summarize = dates => {
    const records = dates.map(d => index.get(d));
    const result = { days: dates.length };
    for (const key of ['count', 'control', 'impressions']) {
      if (records.every(r => Number.isSafeInteger(r[key]))) {
        const total = records.reduce((s, r) => s + r[key], 0);
        if (!Number.isSafeInteger(total)) throw Error('合計が大きすぎます。期間を短くしてください。');
        result[key] = total; result[`${key}PerDay`] = total / dates.length;
      }
    }
    return result;
  };
  const before = summarize(beforeDates), after = summarize(afterDates);
  const ratio = before.countPerDay === 0 ? null : after.countPerDay / before.countPerDay;
  let sign = null;
  if (beforeDates.length === afterDates.length && (day(afterDates[0]) - day(beforeDates[0])) / DAY % 7 === 0) {
    const diffs = beforeDates.map((d, i) => index.get(afterDates[i]).count - index.get(d).count);
    const sensitivity = diffs.map((_, i) => signTest(diffs.filter((__, j) => i !== j)).p);
    sign = { ...signTest(diffs), leaveOneOut: [Math.min(...sensitivity), Math.max(...sensitivity)] };
  }
  const controlRatio = before.controlPerDay > 0 ? after.controlPerDay / before.controlPerDay : null;
  const searchRatio = before.impressionsPerDay > 0 ? after.impressionsPerDay / before.impressionsPerDay : null;
  return { ready: true, before, after, ratio, sign, controlRatio, searchRatio,
    relativeRatio: ratio !== null && controlRatio > 0 ? ratio / controlRatio : null,
    causalEffect: null };
}
export function calendarDate(timestamp, zone) {
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/.test(timestamp)) throw Error('時刻は秒と時差まで入力してください。例: 2026-09-20T15:30:00Z');
  day(timestamp.slice(0,10));
  const time = new Date(timestamp);
  if (!Number.isFinite(time.getTime())) throw Error('時刻が正しくありません。');
  const parts = new Intl.DateTimeFormat('en-US', { timeZone: zone, year:'numeric', month:'2-digit', day:'2-digit' }).formatToParts(time);
  const get = key => parts.find(p => p.type === key).value;
  return `${get('year')}-${get('month')}-${get('day')}`;
}
export function reconcile(text) {
  if (text.length > 150000) throw Error('照合する記録が大きすぎます。');
  const lines = text.trim().split(/\r?\n/);
  if (lines.shift().trim() !== 'id,stage') throw Error('先頭行を id,stage にしてください。');
  const stages = ['occurred', 'attempted', 'accepted', 'duplicate', 'saved'];
  const events = new Map();
  for (const line of lines) {
    const [id, stage, extra] = line.split(',').map(s => s.trim());
    if (!id || extra !== undefined || !stages.includes(stage)) throw Error('照合用の番号と段階を確認してください。');
    if (!events.has(id)) events.set(id, new Set());
    events.get(id).add(stage);
  }
  let unattempted = 0, unacknowledged = 0, unsaved = 0, saved = 0, duplicates = 0;
  for (const values of events.values()) {
    if (!values.has('occurred') || (values.has('accepted') && !values.has('attempted')) || (values.has('duplicate') && !values.has('attempted')) || (values.has('saved') && !values.has('accepted'))) throw Error('前の段階の記録がありません。別の期間や番号を混ぜていないか確認してください。');
    if (values.has('accepted') && values.has('duplicate')) throw Error('同じ番号が受付と重複の両方です。結果を確認してください。');
    if (!values.has('attempted')) unattempted++;
    else if (!values.has('accepted') && !values.has('duplicate')) unacknowledged++;
    if (values.has('accepted') && !values.has('saved')) unsaved++;
    if (values.has('saved')) saved++;
    if (values.has('duplicate')) duplicates++;
  }
  return { occurred: events.size, unattempted, unacknowledged, unsaved, saved, duplicates };
}
