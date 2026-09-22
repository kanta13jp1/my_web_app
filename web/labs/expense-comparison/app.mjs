const byId = (id) => document.getElementById(id);
let report;

function validate(data) {
  if (data.schema_version !== 1 || data.synthetic !== true ||
      data.mode !== 'saved_real_model_measurement' || !/^\d+$/.test(data.run_id) ||
      !Array.isArray(data.samples) || data.samples.length !== 14 ||
      Object.keys(data.categories ?? {}).length !== 12) throw Error('Invalid record');
  const ids = Object.keys(data.categories);
  for (const sample of data.samples) {
    if (typeof sample.text !== 'string' || !ids.includes(sample.rule) ||
        !Array.isArray(sample.trials) || sample.trials.length !== 2) throw Error('Invalid sample');
    for (const trial of sample.trials) {
      if (!Number.isFinite(trial.http_ms) || trial.http_ms < 0) throw Error('Invalid timing');
      if (trial.status === 'error') continue;
      if (trial.status !== 'ok' || trial.model !== 'jevbert-poc-nli-ja-en-0.2.0' ||
          trial.answer?.type !== 'choice' || !ids.includes(trial.answer.choice)) throw Error('Invalid answer');
      const scores = trial.answer.probabilities;
      if (!scores || Object.keys(scores).length !== ids.length ||
          ids.some((id) => !Number.isFinite(scores[id]) || scores[id] < 0 || scores[id] > 1) ||
          Math.abs(Object.values(scores).reduce((a, b) => a + b, 0) - 1) > .01 ||
          !Number.isFinite(trial.answer.confidence) || trial.answer.confidence < 0 || trial.answer.confidence > 1) {
        throw Error('Invalid distribution');
      }
    }
  }
  return data;
}

function render() {
  const sample = report.samples[Number(byId('sample').value)];
  const trial = sample.trials[Number(byId('trial').value)];
  const label = (id) => report.categories[id]?.label ?? '候補なし';
  byId('memo').textContent = sample.text;
  byId('expected').textContent = sample.expected ? `検証用の参照カテゴリ：${label(sample.expected)}` : '参照カテゴリなし：明細を確認しないと判断できないサンプル';
  byId('rule').textContent = label(sample.rule);
  byId('scores').replaceChildren();
  byId('latency').textContent = `HTTP往復 ${trial.http_ms.toLocaleString('ja-JP', {maximumFractionDigits: 1})} ms（${Number(byId('trial').value)+1}回目）`;
  if (trial.status !== 'ok') {
    byId('bert').textContent = '推論失敗・候補なし';
    byId('confidence').textContent = '失敗した応答を分類結果として採用していません。';
    byId('review').textContent = '要確認：モデルの候補を取得できませんでした。';
    return;
  }
  const answer = trial.answer;
  byId('bert').textContent = label(answer.choice);
  byId('confidence').textContent = `分布の集中度（confidence）：${answer.confidence.toFixed(3)} ／ 正答率ではありません。`;
  byId('review').textContent = sample.review_required
    ? '要確認：情報不足・複数用途を含むメモです。候補が一致しても確定できません。'
    : sample.rule !== answer.choice
      ? '要確認：辞書とBERTの候補が異なります。内容とカテゴリ定義を照合してください。'
      : '候補は一致しました。正しさの保証ではないため、明細との照合が必要です。';
  for (const [id, score] of Object.entries(answer.probabilities).sort((a, b) => b[1]-a[1])) {
    const row = document.createElement('div'); row.className = 'score';
    const title = document.createElement('span'); title.textContent = label(id);
    const track = document.createElement('div'); track.className = 'track'; track.setAttribute('aria-hidden', 'true');
    const fill = document.createElement('div'); fill.className = 'fill'; fill.style.width = `${score*100}%`; track.append(fill);
    const number = document.createElement('span'); number.className = 'number'; number.textContent = `${(score*100).toFixed(1)}%`;
    row.append(title, track, number); byId('scores').append(row);
  }
}

async function load() {
  byId('workspace').hidden = true; byId('retry').hidden = true;
  byId('status').className = ''; byId('status').textContent = '比較記録を読み込んでいます…';
  try {
    const response = await fetch(new URL('results.json', import.meta.url), {cache:'no-store', signal:AbortSignal.timeout(10000)});
    if (!response.ok) throw Error('Unavailable');
    report = validate(await response.json());
    byId('sample').replaceChildren(...report.samples.map((sample, index) => {
      const option = document.createElement('option'); option.value = index; option.textContent = sample.text; return option;
    }));
    byId('provenance').textContent = `モデル：${report.model} / CPU・2スレッド / 記録日時：${report.recorded_at} / 上流：${report.upstream_revision} / 重み：${report.model_revision}`;
    byId('run').href = `https://github.com/kanta13jp1/my_web_app/actions/runs/${report.run_id}`;
    render(); byId('workspace').hidden = false;
    byId('status').textContent = '保存済み実測：合成メモ14件 × 各2回。ここで新しい推論は実行していません。';
  } catch {
    byId('status').className = 'error'; byId('status').textContent = '比較記録を読み込めませんでした。接続を確認して再読み込みしてください。';
    byId('retry').hidden = false;
  }
}
byId('sample').addEventListener('change', render);
byId('trial').addEventListener('change', render);
byId('retry').addEventListener('click', load);
load();
