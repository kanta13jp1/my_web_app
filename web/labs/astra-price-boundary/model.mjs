/**
 * GPT-6 Astra Standard-rate boundary calculator (frozen 2026-09-26 prices).
 * Uses BigInt decimal arithmetic so results match Python Decimal without floating-point drift.
 * Pure synthetic arithmetic only: performs no API billing calls or network requests.
 */

export const THRESHOLD_TOKENS = 272000;

export const FROZEN_RATES_UPDATED = '2026-09-26';

export const STANDARD_RATES_USD_PER_M = Object.freeze({
  normal: Object.freeze({
    uncachedInput: '10',
    cachedRead: '1',
    cachedWrite: '12.50',
    output: '50',
  }),
  longContext: Object.freeze({
    uncachedInput: '20',
    cachedRead: '2',
    cachedWrite: '25',
    output: '75',
  }),
});

export const PRESET_CASES = Object.freeze([
  Object.freeze({
    id: 'ordinary',
    label: '通常入力 (100,000 / 20,000)',
    totalInput: 100000,
    cachedRead: 0,
    cachedWrite: 0,
    output: 20000,
    expectedUsd: '2',
  }),
  Object.freeze({
    id: 'exact-boundary',
    label: '境界ちょうど (272,000 / 1,000)',
    totalInput: 272000,
    cachedRead: 0,
    cachedWrite: 0,
    output: 1000,
    expectedUsd: '2.77',
  }),
  Object.freeze({
    id: 'one-over',
    label: '1トークン超過 (272,001 / 1,000)',
    totalInput: 272001,
    cachedRead: 0,
    cachedWrite: 0,
    output: 1000,
    expectedUsd: '5.51502',
  }),
  Object.freeze({
    id: 'article-example',
    label: '原記事の例 (300,000 / 30,000)',
    totalInput: 300000,
    cachedRead: 0,
    cachedWrite: 0,
    output: 30000,
    expectedUsd: '8.25',
  }),
  Object.freeze({
    id: 'cached-long',
    label: '読みキャッシュ長文 (300K / 読み200K / 出力30K)',
    totalInput: 300000,
    cachedRead: 200000,
    cachedWrite: 0,
    output: 30000,
    expectedUsd: '4.65',
  }),
  Object.freeze({
    id: 'all-read-boundary',
    label: '全入力が読み・境界 (272,000)',
    totalInput: 272000,
    cachedRead: 272000,
    cachedWrite: 0,
    output: 0,
    expectedUsd: '0.272',
  }),
  Object.freeze({
    id: 'all-read-over',
    label: '全入力が読み・超過 (272,001)',
    totalInput: 272001,
    cachedRead: 272001,
    cachedWrite: 0,
    output: 0,
    expectedUsd: '0.544002',
  }),
  Object.freeze({
    id: 'zero',
    label: '全区分ゼロ',
    totalInput: 0,
    cachedRead: 0,
    cachedWrite: 0,
    output: 0,
    expectedUsd: '0',
  }),
  Object.freeze({
    id: 'cache-write',
    label: '全入力が書き (100,000)',
    totalInput: 100000,
    cachedRead: 0,
    cachedWrite: 100000,
    output: 0,
    expectedUsd: '1.25',
  }),
  Object.freeze({
    id: 'mixed-long',
    label: '3区分混在 (300K / 読み100K / 書き100K / 出力1K)',
    totalInput: 300000,
    cachedRead: 100000,
    cachedWrite: 100000,
    output: 1000,
    expectedUsd: '4.775',
  }),
  Object.freeze({
    id: 'all-write-over',
    label: '全入力が書き・超過 (272,001)',
    totalInput: 272001,
    cachedRead: 0,
    cachedWrite: 272001,
    output: 0,
    expectedUsd: '6.800025',
  }),
  Object.freeze({
    id: 'negative',
    label: '不正例: 負数 (-1)',
    totalInput: -1,
    cachedRead: 0,
    cachedWrite: 0,
    output: 0,
    expectedError: 'NONNEGATIVE_INTEGER',
  }),
  Object.freeze({
    id: 'overlapping-parts',
    label: '不正例: 内数超過 (100 < 60 + 41)',
    totalInput: 100,
    cachedRead: 60,
    cachedWrite: 41,
    output: 0,
    expectedError: 'CACHE_EXCEEDS_TOTAL',
  }),
  Object.freeze({
    id: 'fraction',
    label: '不正例: 小数入力 (1.5)',
    totalInput: 1.5,
    cachedRead: 0,
    cachedWrite: 0,
    output: 0,
    expectedError: 'NONNEGATIVE_INTEGER',
  }),
  Object.freeze({
    id: 'boolean',
    label: '不正例: 真偽値 (true)',
    totalInput: true,
    cachedRead: 0,
    cachedWrite: 0,
    output: 0,
    expectedError: 'NONNEGATIVE_INTEGER',
  }),
]);

export class AstraInputError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'AstraInputError';
    this.code = code;
  }
}

const SCALE_FACTOR = 5000n;
const DECIMALS_BASE = 10000000000n;

function formatScaledNumerator(numeratorOverTwoMillion) {
  const scaled = numeratorOverTwoMillion * SCALE_FACTOR;
  const intPart = scaled / DECIMALS_BASE;
  const fracRaw = (scaled % DECIMALS_BASE).toString().padStart(10, '0');
  const fracTrimmed = fracRaw.replace(/0+$/, '');
  if (!fracTrimmed) {
    return intPart.toString();
  }
  return `${intPart.toString()}.${fracTrimmed}`;
}

export function parseNonNegativeInt(value, fieldLabel) {
  if (typeof value === 'boolean') {
    throw new AstraInputError(
      'NONNEGATIVE_INTEGER',
      `${fieldLabel} に真偽値は指定できません。0以上の半角整数を入力してください。`,
    );
  }
  if (typeof value === 'number') {
    if (!Number.isFinite(value) || !Number.isInteger(value) || value < 0) {
      throw new AstraInputError(
        'NONNEGATIVE_INTEGER',
        `${fieldLabel} は 0 以上の整数である必要があります。`,
      );
    }
    return BigInt(value);
  }
  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (!trimmed) {
      throw new AstraInputError(
        'NONNEGATIVE_INTEGER',
        `${fieldLabel} が空欄です。0 以上の半角整数を入力してください。`,
      );
    }
    if (/[０-９]/.test(trimmed)) {
      throw new AstraInputError(
        'NONNEGATIVE_INTEGER',
        `${fieldLabel} に全角数字が含まれています。半角整数で入力してください。`,
      );
    }
    if (!/^[0-9]+$/.test(trimmed)) {
      throw new AstraInputError(
        'NONNEGATIVE_INTEGER',
        `${fieldLabel} は小数や記号を含まない 0 以上の半角整数で入力してください。`,
      );
    }
    return BigInt(trimmed);
  }
  throw new AstraInputError(
    'NONNEGATIVE_INTEGER',
    `${fieldLabel} は 0 以上の半角整数で入力してください。`,
  );
}

function computeNumerators(totalInput, cachedRead, cachedWrite, output, applyThreshold) {
  const isLong = applyThreshold && totalInput > BigInt(THRESHOLD_TOKENS);
  const im = isLong ? 2n : 1n;
  const omNum = isLong ? 3n : 2n;
  const uncached = totalInput - cachedRead - cachedWrite;

  const uncachedNum = uncached * 20n * im;
  const cachedReadNum = cachedRead * 2n * im;
  const cachedWriteNum = cachedWrite * 25n * im;
  const outputNum = output * 50n * omNum;
  const totalNum = uncachedNum + cachedReadNum + cachedWriteNum + outputNum;

  return {
    isLong,
    uncached,
    uncachedNum,
    cachedReadNum,
    cachedWriteNum,
    outputNum,
    totalNum,
  };
}

function toSafeCount(bigVal) {
  if (bigVal <= BigInt(Number.MAX_SAFE_INTEGER)) {
    return Number(bigVal);
  }
  return bigVal.toString();
}

export function calculateAstraCost(rawInput) {
  const totalInput = parseNonNegativeInt(rawInput?.totalInput, '総入力トークン');
  const cachedRead = parseNonNegativeInt(rawInput?.cachedRead ?? 0, 'キャッシュ読み');
  const cachedWrite = parseNonNegativeInt(rawInput?.cachedWrite ?? 0, 'キャッシュ書き');
  const output = parseNonNegativeInt(rawInput?.output ?? 0, '出力トークン');

  if (cachedRead + cachedWrite > totalInput) {
    throw new AstraInputError(
      'CACHE_EXCEEDS_TOTAL',
      'キャッシュ読みとキャッシュ書きの合計が総入力トークンを超えています。',
    );
  }

  const actual = computeNumerators(totalInput, cachedRead, cachedWrite, output, true);
  const ignored = computeNumerators(totalInput, cachedRead, cachedWrite, output, false);
  const underestimateNum = actual.totalNum - ignored.totalNum;

  return {
    tier: actual.isLong ? 'long-context' : 'standard',
    tierLabel: actual.isLong ? '長文単価（272,000超過：入力・キャッシュ2倍 / 出力1.5倍）' : '通常単価（272,000以下）',
    thresholdTokens: THRESHOLD_TOKENS,
    frozenRatesUpdated: FROZEN_RATES_UPDATED,
    counts: {
      totalInput: toSafeCount(totalInput),
      uncachedInput: toSafeCount(actual.uncached),
      cachedRead: toSafeCount(cachedRead),
      cachedWrite: toSafeCount(cachedWrite),
      output: toSafeCount(output),
    },
    actualUsd: formatScaledNumerator(actual.totalNum),
    thresholdIgnoredUsd: formatScaledNumerator(ignored.totalNum),
    underestimateUsd: formatScaledNumerator(underestimateNum),
    breakdownUsd: {
      uncachedInput: formatScaledNumerator(actual.uncachedNum),
      cachedRead: formatScaledNumerator(actual.cachedReadNum),
      cachedWrite: formatScaledNumerator(actual.cachedWriteNum),
      output: formatScaledNumerator(actual.outputNum),
    },
  };
}

export function runFifteenCaseSelfCheck() {
  const rows = [];
  let passedCount = 0;

  for (const testCase of PRESET_CASES) {
    if (testCase.expectedError) {
      let actualError = null;
      let message = '';
      try {
        calculateAstraCost(testCase);
      } catch (err) {
        actualError = err instanceof AstraInputError ? err.code : 'UNKNOWN_ERROR';
        message = err instanceof Error ? err.message : String(err);
      }
      const passed = actualError === testCase.expectedError;
      if (passed) passedCount += 1;
      rows.push({
        id: testCase.id,
        label: testCase.label,
        kind: 'invalid',
        expected: `エラー (${testCase.expectedError})`,
        actual: actualError ? `エラー (${actualError})` : 'エラーなし',
        underestimateUsd: '-',
        message,
        passed,
      });
    } else {
      let calc = null;
      let errMsg = '';
      try {
        calc = calculateAstraCost(testCase);
      } catch (err) {
        errMsg = err instanceof Error ? err.message : String(err);
      }
      const passed = Boolean(calc && calc.actualUsd === testCase.expectedUsd);
      if (passed) passedCount += 1;
      rows.push({
        id: testCase.id,
        label: testCase.label,
        kind: 'valid',
        expected: `${testCase.expectedUsd} USD`,
        actual: calc ? `${calc.actualUsd} USD` : `ERROR: ${errMsg}`,
        underestimateUsd: calc ? `${calc.underestimateUsd} USD` : '-',
        tier: calc ? calc.tier : '-',
        passed,
      });
    }
  }

  return {
    total: PRESET_CASES.length,
    passed: passedCount,
    apiCalls: 0,
    frozenRatesUpdated: FROZEN_RATES_UPDATED,
    rows,
  };
}
