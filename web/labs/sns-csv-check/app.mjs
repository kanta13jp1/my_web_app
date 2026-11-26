import { downloadJson } from "/labs/shared/download-json.mjs";
import {
  evaluateArticleCsv,
  evaluateXAnalyticsCsv,
  PRESETS,
  runTwelveCaseSelfCheck,
} from "./model.mjs";

const form = document.querySelector("#csv-form");
const csvInput = document.querySelector("#csv-input");
const errorEl = document.querySelector("#error");
const resultEl = document.querySelector("#result");
const detailEl = document.querySelector("#detail-area");
const runTwelveBtn = document.querySelector("#run-twelve");
const downloadBtn = document.querySelector("#download-json");
const modeRadios = [...document.querySelectorAll('input[name="mode"]')];

let lastReport = null;

function getMode() {
  const checked = modeRadios.find((r) => r.checked);
  return checked ? checked.value : "article";
}

function setMode(mode) {
  for (const r of modeRadios) {
    r.checked = r.value === mode;
  }
}

function clearDetails() {
  detailEl.replaceChildren();
}

function renderWarnings(issues) {
  clearDetails();
  if (!issues || issues.length === 0) return;
  const heading = document.createElement("h3");
  heading.textContent = `検出された診断警告（${issues.length}件）`;
  const ul = document.createElement("ul");
  ul.className = "warning-list";
  for (const issue of issues) {
    const li = document.createElement("li");
    li.textContent = `[${issue.code}] ${issue.message}`;
    ul.appendChild(li);
  }
  detailEl.append(heading, ul);
}

function renderTwelveTable(report) {
  clearDetails();
  const wrap = document.createElement("div");
  wrap.className = "table-wrap";
  const table = document.createElement("table");
  const thead = document.createElement("thead");
  const hr = document.createElement("tr");
  for (const label of ["ケース", "判定", "実測結果"]) {
    const th = document.createElement("th");
    th.scope = "col";
    th.textContent = label;
    hr.appendChild(th);
  }
  thead.appendChild(hr);

  const tbody = document.createElement("tbody");
  for (const item of report.results) {
    const tr = document.createElement("tr");
    const tdTitle = document.createElement("td");
    tdTitle.textContent = item.title;
    const tdPass = document.createElement("td");
    tdPass.textContent = item.passed ? "合格" : "不一致";
    tdPass.className = item.passed ? "badge-ok" : "badge-ng";
    const tdSummary = document.createElement("td");
    tdSummary.textContent = item.summary;
    tr.append(tdTitle, tdPass, tdSummary);
    tbody.appendChild(tr);
  }
  table.append(thead, tbody);
  wrap.appendChild(table);
  detailEl.appendChild(wrap);
}

function inspectCurrent() {
  const mode = getMode();
  errorEl.textContent = "";
  try {
    if (mode === "x_analytics") {
      const res = evaluateXAnalyticsCsv(csvInput.value);
      const rateText = res.weightedRate === null ? "計算不能 (None)" : `${res.weightedRate}%`;
      resultEl.textContent = [
        `[X Analytics CSV診断] 有効投稿 ${res.posts} 件（重複Post id除外 ${res.duplicatePostIdsSkipped} 件 / 空行除外 ${res.blankRowsSkipped} 件）`,
        `合計インプレッション ${res.totalImpressions} / 4反応合計 ${res.totalReactions} / URLクリック ${res.totalUrlClicks}`,
        `重み付き反応率 ${rateText} / 不正数値セル ${res.invalidNumericCells} 件 / 重複ヘッダ ${res.duplicateHeadersIgnored.length} 件`,
      ].join("\n");
      renderWarnings(res.issues);
      lastReport = { checkedAt: new Date().toISOString(), ...res };
      return;
    }

    const res = evaluateArticleCsv(csvInput.value);
    const rateText = res.weightedRate === null ? "計算不能 (None)" : `${res.weightedRate}%`;
    const meanText = res.simpleMeanRate === null ? "計算不能 (None)" : `${res.simpleMeanRate}%`;
    resultEl.textContent = [
      `[記事6列 厳密検査] 投稿 ${res.posts} 件（BOM除去: ${res.bomStripped ? "あり" : "なし"} / 空行除外 ${res.blankRowsSkipped} 件）`,
      `合計表示数 ${res.totalViews} / 反応数合計 ${res.totalReactions}`,
      `重み付き反応率 ${rateText}（参考・投稿ごとの単純平均 ${meanText}）`,
    ].join("\n");
    clearDetails();
    lastReport = { checkedAt: new Date().toISOString(), ...res };
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    errorEl.textContent = msg;
    resultEl.textContent = "仕様違反を検出したため集計を停止しました。";
    clearDetails();
    lastReport = {
      checkedAt: new Date().toISOString(),
      mode,
      error: msg,
    };
  }
}

function runTwelveCheck() {
  errorEl.textContent = "";
  const report = runTwelveCaseSelfCheck();
  resultEl.textContent = `12ケース一括セルフチェック: ${report.passed} / ${report.total} 件合格（失敗 ${report.failed} 件）`;
  renderTwelveTable(report);
  lastReport = { checkedAt: new Date().toISOString(), mode: "twelve_case_selfcheck", ...report };
}

form.addEventListener("submit", (e) => {
  e.preventDefault();
  inspectCurrent();
});

csvInput.addEventListener("input", () => {
  errorEl.textContent = "";
});

for (const radio of modeRadios) {
  radio.addEventListener("change", () => {
    inspectCurrent();
  });
}

document.querySelectorAll("[data-preset]").forEach((btn) => {
  btn.addEventListener("click", () => {
    const preset = PRESETS[btn.dataset.preset];
    if (!preset) return;
    setMode(preset.mode);
    csvInput.value = preset.csv;
    inspectCurrent();
  });
});

runTwelveBtn.addEventListener("click", () => {
  runTwelveCheck();
});

downloadBtn.addEventListener("click", () => {
  if (!lastReport) {
    inspectCurrent();
  }
  try {
    downloadJson(lastReport, "sns-csv-check-result.json");
  } catch (err) {
    errorEl.textContent = err instanceof Error ? err.message : "JSON保存に失敗しました。";
  }
});

inspectCurrent();
