import { downloadJson } from '/labs/shared/download-json.mjs';
import {
  FROZEN_CASES,
  evaluateSkillJsonResponse,
  runTwentyTrialSelfCheck,
} from './model.mjs';

const deployCase = FROZEN_CASES.find((c) => c.id === 'deploy');
const csvCase = FROZEN_CASES.find((c) => c.id === 'csv');

const PRESETS = {
  'deploy-ok': {
    rawOutput: JSON.stringify(deployCase.expected, null, 2),
    requiredKeys: Object.keys(deployCase.expected).join(', '),
    exampleJson: JSON.stringify(deployCase.example, null, 2),
    allowExtraKeys: false,
  },
  'csv-fenced': {
    rawOutput: `\`\`\`json\n${JSON.stringify(csvCase.expected, null, 2)}\n\`\`\``,
    requiredKeys: Object.keys(csvCase.expected).join(', '),
    exampleJson: JSON.stringify(csvCase.example, null, 2),
    allowExtraKeys: false,
  },
  'copied-missing': {
    rawOutput: JSON.stringify(
      {
        service: 'demo',
        replicas: 3,
        region: 'ap-northeast-1',
        health_path: '   ',
      },
      null,
      2,
    ),
    requiredKeys: Object.keys(deployCase.expected).join(', '),
    exampleJson: JSON.stringify(deployCase.example, null, 2),
    allowExtraKeys: false,
  },
  'extra-broken': {
    rawOutput: '{"service":"delta","replicas":3,"extra_debug":true',
    requiredKeys: Object.keys(deployCase.expected).join(', '),
    exampleJson: JSON.stringify(deployCase.example, null, 2),
    allowExtraKeys: false,
  },
};

const rawOutputEl = document.getElementById('raw-output');
const requiredKeysEl = document.getElementById('required-keys');
const exampleJsonEl = document.getElementById('example-json');
const allowExtraEl = document.getElementById('allow-extra');

const evalBtn = document.getElementById('eval-btn');
const downloadBtn = document.getElementById('download-btn');
const selfcheckBtn = document.getElementById('selfcheck-btn');

const errorEl = document.getElementById('error');
const resultEl = document.getElementById('result');
const violationsBodyEl = document.getElementById('violations-body');
const normalizedJsonEl = document.getElementById('normalized-json');
const selfcheckStatusEl = document.getElementById('selfcheck-status');
const selfcheckBodyEl = document.getElementById('selfcheck-body');

let lastSnapshot = null;

function clearChildren(node) {
  while (node.firstChild) {
    node.removeChild(node.firstChild);
  }
}

function appendCell(tr, text, className = '') {
  const td = document.createElement('td');
  td.textContent = text;
  if (className) {
    td.className = className;
  }
  tr.appendChild(td);
}

function renderViolations(violations) {
  clearChildren(violationsBodyEl);
  if (violations.length === 0) {
    const tr = document.createElement('tr');
    appendCell(tr, 'none', 'badge-pass');
    appendCell(tr, '正常');
    appendCell(tr, 'すべての必須キー・値・構文チェックを通過しました。');
    violationsBodyEl.appendChild(tr);
    return;
  }
  for (const v of violations) {
    const tr = document.createElement('tr');
    appendCell(tr, v.code);
    appendCell(
      tr,
      v.severity === 'block' ? 'ブロック' : '自動修正',
      v.severity === 'block' ? 'badge-fail' : 'badge-warn',
    );
    appendCell(tr, v.message);
    violationsBodyEl.appendChild(tr);
  }
}

function runEvaluation() {
  errorEl.textContent = '';
  let exampleObject = {};
  const exampleRaw = exampleJsonEl.value.trim();
  if (exampleRaw) {
    try {
      const parsedExample = JSON.parse(exampleRaw);
      if (parsedExample === null || typeof parsedExample !== 'object' || Array.isArray(parsedExample)) {
        throw new Error('参考例の値は JSON オブジェクト形式で入力してください。');
      }
      exampleObject = parsedExample;
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      errorEl.textContent = `参考例 JSON エラー: ${msg}`;
      resultEl.textContent = '参考例 JSON の構文エラーにより検査を停止しました。';
      normalizedJsonEl.textContent = '[STOPPED]';
      clearChildren(violationsBodyEl);
      lastSnapshot = { tool: 'skill-json-check', mode: 'example-parse-error', message: msg };
      return;
    }
  }

  const evalResult = evaluateSkillJsonResponse({
    rawOutput: rawOutputEl.value,
    requiredKeys: requiredKeysEl.value,
    exampleObject,
    allowExtraKeys: allowExtraEl.checked,
  });

  if (evalResult.decision === 'blocked') {
    errorEl.textContent = evalResult.violations
      .filter((v) => v.severity === 'block')
      .map((v) => v.message)
      .join(' / ');
  }

  const legacyNote = evalResult.legacyTrimBlockedKeys.length > 0 && evalResult.missingKeys.length === 0
    ? `修正前 trim 判定: 誤ブロック対象 (${evalResult.legacyTrimBlockedKeys.join(', ')}) → 修正後: 保持`
    : '修正前 trim 判定との差: なし';

  resultEl.textContent = [
    `最終判定: ${evalResult.decisionLabel} (${evalResult.decision})`,
    `素の JSON 解釈: ${evalResult.strictJsonPass ? '合格' : '不可'} / コードフェンス除去: ${evalResult.fenceStripped ? 'あり' : 'なし'}`,
    legacyNote,
  ].join('\n');

  normalizedJsonEl.textContent = evalResult.normalizedJson ?? '[BLOCKED]';
  renderViolations(evalResult.violations);

  lastSnapshot = {
    tool: 'skill-json-check',
    mode: 'single-evaluation',
    checkedAt: new Date().toISOString(),
    ...evalResult,
  };
}

function applyPreset(presetKey) {
  const p = PRESETS[presetKey];
  if (!p) return;
  rawOutputEl.value = p.rawOutput;
  requiredKeysEl.value = p.requiredKeys;
  exampleJsonEl.value = p.exampleJson;
  allowExtraEl.checked = p.allowExtraKeys;
  runEvaluation();
}

function runSelfCheck() {
  const report = runTwentyTrialSelfCheck();
  const a = report.summary.A;
  const b = report.summary.B;
  selfcheckStatusEl.textContent = [
    `20 応答検証完了（外部 API 呼出 ${report.apiCalls} 回）`,
    `A（ラベルなし）: 素JSON ${a.strictPass}/${a.n}・フェンス除去後内容一致 ${a.semanticPass}/${a.n}・修正前trim誤ブロック ${a.legacyTrimFalseBlock}/${a.n} → 修正後ブロック ${a.fixedBlock}/${a.n}`,
    `B（ラベルあり）: 素JSON ${b.strictPass}/${b.n}・フェンス除去後内容一致 ${b.semanticPass}/${b.n}・修正前trim誤ブロック ${b.legacyTrimFalseBlock}/${b.n} → 修正後ブロック ${b.fixedBlock}/${b.n}`,
  ].join('\n');

  clearChildren(selfcheckBodyEl);
  for (const row of report.rows) {
    const tr = document.createElement('tr');
    appendCell(tr, `${row.id} #${row.repeat}`);
    appendCell(tr, row.variant);
    appendCell(tr, row.strictJsonPass ? 'PASS' : 'WRAP', row.strictJsonPass ? 'badge-pass' : 'badge-warn');
    appendCell(tr, row.fenceStripped ? '除去あり' : 'なし');
    appendCell(
      tr,
      row.legacyTrimFalseBlock ? `誤ブロック (${row.legacyBlockedFields.join(',')})` : '通過',
      row.legacyTrimFalseBlock ? 'badge-fail' : 'badge-pass',
    );
    appendCell(
      tr,
      `${row.decisionLabel} (${row.matchesExpected ? '内容一致' : '不一致'})`,
      row.decision === 'blocked' ? 'badge-fail' : (row.decision === 'remediated' ? 'badge-warn' : 'badge-pass'),
    );
    selfcheckBodyEl.appendChild(tr);
  }

  lastSnapshot = {
    tool: 'skill-json-check',
    mode: 'twenty-trial-selfcheck',
    checkedAt: new Date().toISOString(),
    ...report,
  };
}

document.querySelectorAll('.presets button[data-preset]').forEach((btn) => {
  btn.addEventListener('click', () => {
    applyPreset(btn.dataset.preset);
  });
});

evalBtn.addEventListener('click', runEvaluation);
selfcheckBtn.addEventListener('click', runSelfCheck);
downloadBtn.addEventListener('click', () => {
  if (!lastSnapshot) {
    runEvaluation();
  }
  downloadJson(lastSnapshot, 'skill-json-check-result.json');
});

applyPreset('csv-fenced');
