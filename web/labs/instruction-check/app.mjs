import {compare} from './model.mjs';
const form = document.querySelector('form');
const alert = document.querySelector('[role=alert]');
const result = document.querySelector('[role=status]');
const expected = document.querySelector('#expected');
const response = document.querySelector('#response');
const calls = document.querySelector('#calls');
form.addEventListener('input', () => {
  alert.textContent = '';
  result.textContent = '入力が変わりました。もう一度照合してください。';
});
form.addEventListener('submit', event => {
  event.preventDefault();
  alert.textContent = '';
  result.textContent = '照合結果はありません。';
  try {
    const knownCalls = calls.value.trim() !== '';
    // Only the marker rows are used when the tool count is unknown.
    const comparison = compare(expected.value, response.value, knownCalls ? Number(calls.value) : 0);
    const missing = comparison.rows.filter(row => !row.seen);
    const detected = comparison.rows.length - missing.length;
    const lines = [
      `返答にあった目印：${comparison.rows.length}個中${detected}個`,
      ...comparison.rows.map(row => `${row.mark}：${row.seen ? '検出（返答にありました）' : '未検出（返答にありませんでした）'}`),
      missing.length
        ? '未検出は「返答に同じ文字がなかった」という意味です。ファイルを読んでいないとは断定できません。返答に省略や句読点がないかも確認してください。'
        : '比べたい目印がすべて返答にありました。ただし、ファイルの指示をすべて守ったという意味ではありません。',
      !knownCalls
        ? 'ツール使用回数：未確認。目印の有無だけを照合しました。起動時に渡された内容かを考えるには、実行ログの確認が必要です。'
        : Number(calls.value) === 0
        ? 'ツール使用回数：0（入力された記録）。途中のツール使用はないという記録ですが、この画面がログを確認したわけではありません。'
        : `ツール使用回数：${calls.value}（入力された記録）。途中でファイルを開いて答えを見つけた可能性を除外できません。実行ログで、何のツールを使ったか確認してください。`,
      'この結果だけでは、起動時にどの経路でファイルが読み込まれたかや、操作の安全性は証明できません。',
    ];
    result.textContent = lines.join('\n\n');
  } catch (error) {
    alert.textContent = error.message;
  }
});
document.querySelectorAll('[data-example]').forEach(button => {
  button.addEventListener('click', () => {
    expected.value = 'MARK_C MARK_A';
    response.value = button.dataset.example === 'missing' ? 'MARK_C' : 'MARK_C MARK_A';
    calls.value = button.dataset.example === 'tools' ? '1' : '0';
    form.requestSubmit();
  });
});

import {setupEvidence} from './evidence.mjs';
setupEvidence();

import {setupCause} from './cause.mjs';
setupCause();
