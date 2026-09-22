// Pure helpers for the Jwenv lab: no DOM, no WebGPU. Unit-tested with `node --test`.

export const MODEL = Object.freeze({
  repo: 'kishida/jwenv-0.6b-poc-gguf',
  revision: 'fd39b70075029880f46507aa39f7733bb7f1d31d',
  file: 'jwenv-0.6b-poc-q8_0.gguf',
  bytes: 639446848,
  sha256: '293ef32a06953c06d1ba9a9bbd23cf734ece3fb94ad1a360faa9ca3c86294a95',
  page: 'https://huggingface.co/kishida/jwenv-0.6b-poc-gguf/tree/fd39b70075029880f46507aa39f7733bb7f1d31d',
});

export const ENGINE = Object.freeze({
  space: 'kishida/jwenv-demo',
  revision: '8263b814fde5ca11e47718a7ac82945639c02d8d',
  vendorDir: 'vendor/jwenv-8263b81',
});

// Same values as the upstream demo (dist/web/src/app.js).
export const LOAD_OPTIONS = Object.freeze({
  weights: 'q8', maxTokens: 4096, maxSeqLen: 2048, maxSeqs: 64, kvCacheTokens: 2048,
});

// The input example printed in the Zenn article, unchanged.
export const ARTICLE_EXAMPLE = Object.freeze({
  model: 'jev-latest',
  state: '三井住友カード株式会社から5,000円の利用通知を受信',
  questions: {
    category: {
      type: 'choice',
      instructions: '支出の勘定科目を分類してください',
      criteria: {
        utilities: '水道光熱費',
        food: '食費・飲食代',
        transport: '交通費',
        credit_repayment: 'クレジットカード利用代金',
      },
    },
  },
});

export const NOUL_THRESHOLD = 0.5;

// Same wording as scripts/expense_comparison/fixtures.json `instructions` (checked by test_contract.py).
export const EXPENSE_DOMAIN = '日本の一般的な個人家計簿・支出管理における品目分類';

/** One choice question with every category: exceeds the 8-option limit on purpose. */
export function limitCheckRequest(categories) {
  return {
    model: 'jev-latest',
    state: 'スーパーで自炊用の野菜とお米を購入',
    questions: {
      category: {
        type: 'choice',
        instructions: '支出のカテゴリを選んでください',
        criteria: Object.fromEntries(Object.entries(categories).map(([id, c]) => [id, c.label])),
      },
    },
  };
}

/** One yes/no (noul) question per category, so 12 categories fit the 8-option limit. */
export function expenseRequest(text, categories, domain) {
  const questions = {};
  for (const [id, c] of Object.entries(categories)) {
    questions[id] = {
      type: 'noul',
      instructions: `${domain}として、この支出は「${c.label}」（${c.description}）に当てはまりますか？`,
    };
  }
  if (Object.keys(questions).length > 64) throw Error('too many categories for one request');
  return { model: 'jev-latest', state: text, questions };
}

/** Categories sorted by P(yes), highest first. */
export function rankNoul(answers, categoryIds) {
  return categoryIds
    .map((id) => {
      const a = answers[id];
      if (a?.type !== 'noul' || !Number.isFinite(a.noul)) throw Error(`missing noul answer: ${id}`);
      return { id, p: a.noul };
    })
    .sort((x, y) => y.p - x.p);
}

export function pickCategory(ranked, threshold = NOUL_THRESHOLD) {
  const top = ranked[0];
  return { choice: top.id, p: top.p, review: top.p < threshold };
}

/** Same formula as upstream jev.js, used to re-check returned confidences. */
export function normalizedEntropyConfidence(probabilities) {
  const n = probabilities.length;
  let h = 0;
  for (const x of probabilities) if (x > 0) h -= x * Math.log(x);
  return Math.max(0, 1 - h / Math.log(n));
}

export function median(values) {
  const v = [...values].sort((a, b) => a - b);
  if (!v.length) return null;
  const m = Math.floor(v.length / 2);
  return v.length % 2 ? v[m] : (v[m - 1] + v[m]) / 2;
}

/** Counts agreement with the reference only for samples that have one. */
export function agreement(rows, key) {
  const referenced = rows.filter((r) => r.expected);
  return { referenced: referenced.length, matches: referenced.filter((r) => r[key] === r.expected).length };
}

export function isHtmlFallback(text) {
  return /^\s*</.test(text);
}
