import { downloadJson } from '/labs/shared/download-json.mjs';
import {
  AstraInputError,
  calculateAstraCost,
  runFifteenCaseSelfCheck,
} from './model.mjs';

const totalInputEl = document.getElementById('total-input');
const cachedReadEl = document.getElementById('cached-read');
const cachedWriteEl = document.getElementById('cached-write');
const outputCountEl = document.getElementById('output-count');

const calcBtn = document.getElementById('calc-btn');
const selfcheckBtn = document.getElementById('selfcheck-btn');
const downloadBtn = document.getElementById('download-btn');

const errorEl = document.getElementById('error');
const resultEl = document.getElementById('result');
const breakdownBodyEl = document.getElementById('breakdown-body');
const selfcheckStatusEl = document.getElementById('selfcheck-status');
const selfcheckBodyEl = document.getElementById('selfcheck-body');

let lastSnapshot = null;

function formatUsdDisplay(usdString) {
  return `${usdString} USD`;
}

function clearTableBody(tbody) {
  while (tbody.firstChild) {
    tbody.removeChild(tbody.firstChild);
  }
}

function renderBreakdown(calc) {
  clearTableBody(breakdownBodyEl);
  const rows = [
    ['通常入力', calc.counts.uncachedInput, calc.breakdownUsd.uncachedInput],
    ['キャッシュ読み', calc.counts.cachedRead, calc.breakdownUsd.cachedRead],
    ['キャッシュ書き', calc.counts.cachedWrite, calc.breakdownUsd.cachedWrite],
    ['出力トークン', calc.counts.output, calc.breakdownUsd.output],
  ];
  for (const [label, count, usd] of rows) {
    const tr = document.createElement('tr');
    const tdLabel = document.createElement('td');
    tdLabel.textContent = label;
    const tdCount = document.createElement('td');
    tdCount.textContent = Number(count).toLocaleString('en-US');
    const tdUsd = document.createElement('td');
    tdUsd.textContent = formatUsdDisplay(usd);
    tr.append(tdLabel, tdCount, tdUsd);
    breakdownBodyEl.appendChild(tr);
  }
}

function runCalculation() {
  errorEl.textContent = '';
  try {
    const calc = calculateAstraCost({
      totalInput: totalInputEl.value,
      cachedRead: cachedReadEl.value,
      cachedWrite: cachedWriteEl.value,
      output: outputCountEl.value,
    });
    resultEl.textContent = [
      `適用単価: ${calc.tierLabel}`,
      `正確な合計金額: ${formatUsdDisplay(calc.actualUsd)}`,
      `閾値無視時の誤算出額: ${formatUsdDisplay(calc.thresholdIgnoredUsd)}（過小評価差額: ${formatUsdDisplay(calc.underestimateUsd)}）`,
    ].join('\n');
    renderBreakdown(calc);
    lastSnapshot = {
      tool: 'astra-price-boundary',
      mode: 'single-calculation',
      calculatedAt: new Date().toISOString(),
      ...calc,
    };
  } catch (err) {
    const msg = err instanceof AstraInputError || err instanceof Error ? err.message : String(err);
    errorEl.textContent = `入力エラー: ${msg}`;
    resultEl.textContent = '不正な入力のため計算を停止しました（上の案内を確認してください）。';
    clearTableBody(breakdownBodyEl);
    lastSnapshot = {
      tool: 'astra-price-boundary',
      mode: 'input-error',
      errorCode: err instanceof AstraInputError ? err.code : 'UNKNOWN',
      message: msg,
    };
  }
}

function runSelfCheck() {
  const report = runFifteenCaseSelfCheck();
  selfcheckStatusEl.textContent = `15ケース一括検証: ${report.passed} / ${report.total} 件合格（実API呼び出し ${report.apiCalls} 回 / 固定単価 ${report.frozenRatesUpdated}）`;
  clearTableBody(selfcheckBodyEl);
  for (const row of report.rows) {
    const tr = document.createElement('tr');
    const tdId = document.createElement('td');
    tdId.textContent = row.label;
    const tdExpected = document.createElement('td');
    tdExpected.textContent = row.expected;
    const tdActual = document.createElement('td');
    tdActual.textContent = row.actual;
    const tdDiff = document.createElement('td');
    tdDiff.textContent = row.underestimateUsd;
    const tdPass = document.createElement('td');
    tdPass.textContent = row.passed ? 'PASS' : 'FAIL';
    tdPass.className = row.passed ? 'badge-pass' : 'badge-fail';
    tr.append(tdId, tdExpected, tdActual, tdDiff, tdPass);
    selfcheckBodyEl.appendChild(tr);
  }
  lastSnapshot = {
    tool: 'astra-price-boundary',
    mode: 'fifteen-case-selfcheck',
    checkedAt: new Date().toISOString(),
    ...report,
  };
}

document.querySelectorAll('.presets button[data-total]').forEach((btn) => {
  btn.addEventListener('click', () => {
    totalInputEl.value = btn.dataset.total ?? '0';
    cachedReadEl.value = btn.dataset.read ?? '0';
    cachedWriteEl.value = btn.dataset.write ?? '0';
    outputCountEl.value = btn.dataset.output ?? '0';
    runCalculation();
  });
});

calcBtn.addEventListener('click', runCalculation);
selfcheckBtn.addEventListener('click', runSelfCheck);
downloadBtn.addEventListener('click', () => {
  if (!lastSnapshot) {
    runCalculation();
  }
  downloadJson(lastSnapshot, 'astra-price-boundary-result.json');
});

runCalculation();
