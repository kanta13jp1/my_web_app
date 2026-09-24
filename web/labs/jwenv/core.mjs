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

// Method B, pre-registered in docs/JWENV_DECISION_METHOD.md (do not tune after seeing results).
export const STAGE2_OPTIONS = 8;
export const STAGE2_PERMUTATIONS = 8;
export const CHOICE_MAJORITY = 0.5;

/** Stage 2: one choice over the top-8 categories of stage 1, averaged over all 8 label rotations. */
export function stage2Request(text, ranked, categories, domain) {
  const top = ranked.slice(0, STAGE2_OPTIONS);
  return {
    model: 'jev-latest',
    state: text,
    options: { permutations: STAGE2_PERMUTATIONS },
    questions: {
      category: {
        type: 'choice',
        instructions: `${domain}として、この支出に最も当てはまるカテゴリを選んでください`,
        criteria: Object.fromEntries(top.map(({ id }) => [id, `${categories[id].label}（${categories[id].description}）`])),
      },
    },
  };
}

export function decideStage2(answer) {
  if (answer?.type !== 'choice' || !answer.probabilities) throw Error('missing choice answer');
  const p = answer.probabilities[answer.choice];
  return { choice: answer.choice, p, confidence: answer.confidence, review: p < CHOICE_MAJORITY };
}

/** Pre-registered metrics for one set of rows ({expected, a: {choice, review}, b: {choice, review, expected_in_top8}}). */
export function summarizeMethods(rows) {
  const referenced = rows.filter((r) => r.expected);
  const ambiguous = rows.filter((r) => !r.expected);
  const of = (k) => ({
    referenced: referenced.length,
    matches: referenced.filter((r) => r[k].choice === r.expected).length,
    false_reviews: referenced.filter((r) => r[k].review).length,
    review_required: ambiguous.length,
    flagged: ambiguous.filter((r) => r[k].review).length,
  });
  return { a: of('a'), b: of('b'), b_expected_in_top8: referenced.filter((r) => r.b.expected_in_top8).length };
}

/** Adoption rule fixed before the run: B flags more review memos and loses fewer than 2 matches. */
export function adoptionCheck(summary) {
  const matchDrop = summary.a.matches - summary.b.matches;
  const flagsMore = summary.b.flagged > summary.a.flagged;
  return { b_flags_more: flagsMore, match_drop: matchDrop, adopt: flagsMore && matchDrop < 2 };
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
