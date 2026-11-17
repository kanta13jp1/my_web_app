import {compare} from './model.mjs';

const conditions = {
  N: '指示ファイルなし', C: 'CLAUDE.mdだけ', A: 'AGENTS.mdだけ',
  B: '両方を配置（既定設定）', I: 'CLAUDE.mdからAGENTS.mdを取り込む',
  E: '両方を読む設定を指定',
};

// These are allowlisted excerpts of saved historical events, not a live runner.
export function inspectRecord(record, marks) {
  if (!record || !Array.isArray(record.events) || !Array.isArray(record.omittedEventTypes) ||
      record.events.some(row => !row?.event || !Number.isInteger(row.sourceLine))) throw new Error('実行記録の形式を確認できません。');
  const events = record.events.map(row => row.event);
  const init = events.filter(event => event.type === 'system' && event.subtype === 'init');
  const end = events.filter(event => event.type === 'result');
  const assistants = events.filter(event => event.type === 'assistant');
  if (init.length !== 1 || end.length !== 1 || !assistants.length ||
      events[0] !== init[0] || events.at(-1) !== end[0] ||
      !Array.isArray(init[0].tools) || end[0].is_error !== false ||
      end[0].subtype !== 'success' || typeof end[0].result !== 'string' ||
      record.exitCode !== 0 || record.timeout !== false ||
      record.sourceEventCount !== events.length + record.omittedEventTypes.length ||
      record.omittedEventTypes.some(type => type !== 'rate_limit_event')) {
    throw new Error('開始・終了・省略範囲を確認できません。ツール回数は未確認です。');
  }
  const tools = [];
  for (const event of assistants) {
    if (!Array.isArray(event.message?.content)) throw new Error('応答イベントが不完全です。');
    for (const block of event.message.content) {
      if (block.type === 'tool_use' && typeof block.name === 'string') tools.push(block.name);
      else if (block.type !== 'text' || typeof block.text !== 'string') throw new Error('未対応の応答イベントです。');
    }
  }
  if (events.some(event => !['system', 'assistant', 'result'].includes(event.type)) ||
      JSON.stringify(tools) !== JSON.stringify(record.toolCalls) ||
      JSON.stringify(init[0].tools) !== JSON.stringify(record.availableTools) ||
      assistants.map(event => event.message.content.filter(block => block.type === 'text').map(block => block.text).join('')).join('\n') !== record.answer ||
      end[0].result !== record.answer || init[0].claude_code_version !== record.version) {
    throw new Error('保存要約とイベントが一致しません。ツール回数は未確認です。');
  }
  return {tools, availableTools: init[0].tools, answer: end[0].result,
    rows: compare(Object.values(marks).join(' '), end[0].result, tools.length).rows};
}

export function setupEvidence() {
  const selection = document.querySelector('#run-select');
  const status = document.querySelector('#evidence-message');
  const panel = document.querySelector('#evidence-panel');
  const load = document.querySelector('#load-evidence');
  let data;
  function show() {
    panel.hidden = true;
    try {
      const record = data.records.find(item => item.id === selection.value);
      const inspected = inspectRecord(record, data.marks);
      document.querySelector('#run-summary').textContent = [
        `実行：${record.startedAt}（UTC）`,
        `Claude Code ${record.version} / ${record.model} / effort ${record.effort}`,
        `条件 ${record.condition}：${conditions[record.condition]}`,
        `終了コード：${record.exitCode} / タイムアウト：なし / 終了イベント：success`,
      ].join('\n');
      document.querySelector('#run-answer').textContent = inspected.answer;
      document.querySelector('#run-comparison').textContent = inspected.rows.map(row => `${row.mark}：${row.seen ? '検出' : '未検出'}`).join('\n');
      document.querySelector('#run-tools').textContent = `ツール使用イベント：${inspected.tools.length}件。開始時に使えるツール：${inspected.availableTools.length}件。\n開始イベントの tools と、応答イベント内の tool_use を確認しています。全${record.sourceEventCount}イベントを抽出時に解析し、表示は${record.events.length}イベント。利用枠通知を${record.omittedEventTypes.length}件省略しています。`;
      document.querySelector('#run-fixture').textContent = JSON.stringify({files: record.fixture, settings: record.settings, prompt: data.prompt, flags: data.flags}, null, 2);
      document.querySelector('#run-events').textContent = record.events.map(row => `元ログ ${row.sourceLine}行目\n${JSON.stringify(row.event, null, 2)}`).join('\n\n');
      document.querySelector('#run-source').href = `https://github.com/kanta13jp1/zenn-content/blob/${data.sourceCommit}/experiments/agents-md-loading/results/${record.id}.json`;
      document.querySelector('#run-log-details').open = false;
      status.textContent = `${record.id}の実行記録を表示しています。`;
      panel.hidden = false;
    } catch (error) { status.textContent = error.message; }
  }
  load.addEventListener('click', async () => {
    load.disabled = true;
    status.textContent = '公開用の実行記録を読み込んでいます。';
    try {
      const response = await fetch('./evidence.json', {cache: 'no-cache'});
      if (!response.ok) throw new Error('実行記録を取得できませんでした。もう一度お試しください。');
      data = await response.json();
      if (data.schema !== 'instruction-evidence-v1' || data.records?.length !== 12) throw new Error('実行記録の形式を確認できません。');
      selection.replaceChildren(...data.records.map(record => {
        const option = document.createElement('option');
        option.value = record.id;
        option.textContent = `${record.version} / ${record.condition}：${conditions[record.condition]}`;
        return option;
      }));
      selection.value = 'new-B';
      selection.disabled = false;
      show();
    } catch (error) {
      panel.hidden = true;
      selection.disabled = true;
      status.textContent = error.message;
    } finally { load.disabled = false; }
  });
  selection.addEventListener('change', show);
}
