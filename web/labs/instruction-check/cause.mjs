const changes = {interactive:'対話モードから入力',hooks_off:'ユーザー設定でdisableAllHooksを有効',plugins_off:'無関係な7プラグインを無効',old_first:'旧2.1.170の起動後に同じ設定で起動',slash:'スラッシュコマンドを有効',tools:'通常のツールを有効',user:'ユーザー設定を読み込み対象に追加',no_strict:'MCPの厳密指定を除去',persist:'会話保存を有効',no_budget:'予算上限の引数を除去',chrome:'Chrome無効指定を除去',default_permission:'権限モードをdefaultに変更',ancestor:'上の階層にCLAUDE.mdを追加'};
export function validateCause(data) {
  if (data?.schema !== 1 || data.kind !== 'intercepted-request-no-model' || !Array.isArray(data.runs) || !data.runs.length) throw new Error('読み込み試験の記録形式を確認できません。');
  const ids = new Set();
  for (const r of data.runs) {
    if (typeof r.id !== 'string' || ids.has(r.id) || !['Windows','Linux'].includes(r.platform) || !['2.1.278','2.1.281'].includes(r.version) || r.modelCalls !== 0 || !r.condition || !Array.isArray(r.observations) || !r.observations.length || !Array.isArray(r.loaderLog) || r.loaderLog.some(x => typeof x !== 'string') || !/^[a-f0-9]{64}$/.test(r.source?.sha256 ?? '')) throw new Error('読み込み試験の根拠が不足しています。');
    ids.add(r.id);
    if (typeof r.condition.telemetry !== 'boolean' || ![true,false,null].includes(r.condition.gate) || !/^[a-f0-9]{40}$/.test(r.source.head ?? '')) throw new Error('実行条件を確認できません。');
    for (const o of r.observations) {
      if (!o.markers || !['system','messages'].every(k => Array.isArray(o.markers[k]) && o.markers[k].every(m => ['A','C'].includes(m))) || !Number.isSafeInteger(o.tools_count) || o.tools_count < 0 || !/^[a-f0-9]{64}$/.test(o.request_sha256 ?? '')) throw new Error('受信記録を確認できません。');
    }
  }
  return data;
}
export function setupCause(root = document, fetcher = fetch) {
  const button = root.querySelector('#load-cause'), select = root.querySelector('#cause-select'), panel = root.querySelector('#cause-panel'), message = root.querySelector('#cause-message');
  let records;
  function show() {
    const r = records.runs.find(x => x.id === select.value);
    const found = [...new Set(r.observations.flatMap(o => [...o.markers.system,...o.markers.messages]))].sort();
    root.querySelector('#cause-result').textContent = `${found.length ? found.map(m => m === 'A' ? 'AGENTS.md側の目印' : 'CLAUDE.md側の目印').join('・') : 'どちらの目印も入力にありませんでした'}\nモデル呼び出し：0回。AIの返答は生成していません。`;
    const c = r.condition;
    root.querySelector('#cause-condition').textContent = [`${r.platform} / Claude Code ${r.version}`,`実行時刻：${r.startedAt}`,`利用状況の通信：${c.telemetry ? '有効（外部通信は試験用受信先で拒否）' : '無効'}`,`機能の有効値：${c.gate === true ? '有効' : c.gate === false ? '無効' : '保存値なし・配布版の既定値'}`,`配置：${c.claude ? 'CLAUDE.mdとAGENTS.md' : 'AGENTS.mdだけ'}`,`読み方：${c.mode ?? '明示設定なし'}`,...Object.entries(changes).filter(([k]) => c[k]).map(([,v]) => `変更：${v}`)].join('\n');
    root.querySelector('#cause-log').textContent = JSON.stringify({receivedRequests:r.observations.length,requests:r.observations,loaderLog:r.loaderLog},null,2);
    root.querySelector('#cause-source').textContent = `元記録：${r.source.artifact}/${r.source.file}\n元記録SHA-256：${r.source.sha256}\n試験コード：${r.source.head}\n公開用抜粋です。全通信内容や個人の設定は含めていません。`;
    root.querySelector('#cause-code').href = `https://github.com/kanta13jp1/zenn-content/blob/${r.source.head}/experiments/agents-md-cause-20261004/cloud_probe.py`;
    panel.hidden = false;
  }
  select.addEventListener('change',show);
  button.addEventListener('click',async () => {
    panel.hidden = true; select.disabled = true; button.disabled = true; message.textContent = '記録を取得しています。';
    try {
      const response = await fetcher('./cause.json');
      if (!response.ok) throw new Error('記録を取得できません。もう一度表示ボタンを押してください。');
      records = validateCause(await response.json());
      select.replaceChildren(...records.runs.map(r => {
        const o = root.createElement('option'); o.value = r.id;
        const c = r.condition;
        o.textContent = `${r.platform} ${r.version}：${Object.entries(changes).find(([k]) => c[k])?.[1] ?? (c.claude ? '両方を読む設定' : 'AGENTS.md単独')} / 機能${c.gate === true ? '有効' : c.gate === false ? '無効' : '既定'}`;
        return o;
      }));
      select.disabled = false; message.textContent = `${records.runs.length}件の追加試験。受信後に停止し、モデル呼び出しは0回です。`; show();
    } catch(error) { records = undefined; message.textContent = error.message; }
    finally { button.disabled = false; }
  });
}
