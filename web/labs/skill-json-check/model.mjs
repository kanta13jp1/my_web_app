export const FROZEN_CASES = [
  {
    "id": "deploy",
    "task": "staging向け設定を作る。service=delta、replicas=3、region=ap-northeast-1、health_path=/ready、timeout_s=17。必須キーはこの5つ。",
    "example": {
      "service": "demo",
      "replicas": 1,
      "region": "us-east-1"
    },
    "expected": {
      "service": "delta",
      "replicas": 3,
      "region": "ap-northeast-1",
      "health_path": "/ready",
      "timeout_s": 17
    }
  },
  {
    "id": "csv",
    "task": "CSV出力設定を作る。delimiterはタブ1文字、encoding=utf-8、header=false、columnsはskuとqtyの順。必須キーはこの4つ。",
    "example": {
      "delimiter": ",",
      "encoding": "shift_jis",
      "header": true
    },
    "expected": {
      "delimiter": "\t",
      "encoding": "utf-8",
      "header": false,
      "columns": [
        "sku",
        "qty"
      ]
    }
  },
  {
    "id": "retry",
    "task": "再試行設定を作る。attempts=4、backoff_ms=[50,100,200]、retry_codes=[429,503]、jitter=false。必須キーはこの4つ。",
    "example": {
      "attempts": 2,
      "backoff_ms": [
        1000
      ],
      "retry_codes": [
        500
      ]
    },
    "expected": {
      "attempts": 4,
      "backoff_ms": [
        50,
        100,
        200
      ],
      "retry_codes": [
        429,
        503
      ],
      "jitter": false
    }
  },
  {
    "id": "report",
    "task": "レポート設定を作る。format=json、path=reports/daily.json、include_totals=true、currency=JPY。必須キーはこの4つ。",
    "example": {
      "format": "csv",
      "path": "output.csv",
      "include_totals": false
    },
    "expected": {
      "format": "json",
      "path": "reports/daily.json",
      "include_totals": true,
      "currency": "JPY"
    }
  },
  {
    "id": "filter",
    "task": "検索設定を作る。top_k=7、min_score=0.65、exclude_archived=true、tags=[alpha,beta]、sort=desc。必須キーはこの5つ。",
    "example": {
      "top_k": 3,
      "min_score": 0.8,
      "tags": [
        "demo"
      ]
    },
    "expected": {
      "top_k": 7,
      "min_score": 0.65,
      "exclude_archived": true,
      "tags": [
        "alpha",
        "beta"
      ],
      "sort": "desc"
    }
  }
];

export const FROZEN_RESPONSES = [
  {
    "id": "csv",
    "variant": "A",
    "repeat": 1,
    "answer": "```json\n{\"delimiter\": \"\\t\", \"encoding\": \"utf-8\", \"header\": false, \"columns\": [\"sku\", \"qty\"]}\n```"
  },
  {
    "id": "report",
    "variant": "A",
    "repeat": 1,
    "answer": "{\"format\": \"json\", \"path\": \"reports/daily.json\", \"include_totals\": true, \"currency\": \"JPY\"}"
  },
  {
    "id": "report",
    "variant": "B",
    "repeat": 1,
    "answer": "{\"format\": \"json\", \"path\": \"reports/daily.json\", \"include_totals\": true, \"currency\": \"JPY\"}"
  },
  {
    "id": "report",
    "variant": "A",
    "repeat": 2,
    "answer": "```json\n{\"format\": \"json\", \"path\": \"reports/daily.json\", \"include_totals\": true, \"currency\": \"JPY\"}\n```"
  },
  {
    "id": "retry",
    "variant": "A",
    "repeat": 1,
    "answer": "{\"attempts\": 4, \"backoff_ms\": [50, 100, 200], \"retry_codes\": [429, 503], \"jitter\": false}"
  },
  {
    "id": "csv",
    "variant": "B",
    "repeat": 1,
    "answer": "{\"delimiter\": \"\\t\", \"encoding\": \"utf-8\", \"header\": false, \"columns\": [\"sku\", \"qty\"]}"
  },
  {
    "id": "retry",
    "variant": "B",
    "repeat": 2,
    "answer": "{\"attempts\": 4, \"backoff_ms\": [50, 100, 200], \"retry_codes\": [429, 503], \"jitter\": false}"
  },
  {
    "id": "filter",
    "variant": "B",
    "repeat": 2,
    "answer": "{\"top_k\": 7, \"min_score\": 0.65, \"exclude_archived\": true, \"tags\": [\"alpha\", \"beta\"], \"sort\": \"desc\"}"
  },
  {
    "id": "retry",
    "variant": "A",
    "repeat": 2,
    "answer": "{\"attempts\": 4, \"backoff_ms\": [50, 100, 200], \"retry_codes\": [429, 503], \"jitter\": false}"
  },
  {
    "id": "deploy",
    "variant": "B",
    "repeat": 2,
    "answer": "{\"service\": \"delta\", \"replicas\": 3, \"region\": \"ap-northeast-1\", \"health_path\": \"/ready\", \"timeout_s\": 17}"
  },
  {
    "id": "filter",
    "variant": "A",
    "repeat": 1,
    "answer": "{\"top_k\": 7, \"min_score\": 0.65, \"exclude_archived\": true, \"tags\": [\"alpha\", \"beta\"], \"sort\": \"desc\"}"
  },
  {
    "id": "report",
    "variant": "B",
    "repeat": 2,
    "answer": "{\"format\": \"json\", \"path\": \"reports/daily.json\", \"include_totals\": true, \"currency\": \"JPY\"}"
  },
  {
    "id": "filter",
    "variant": "B",
    "repeat": 1,
    "answer": "{\"top_k\": 7, \"min_score\": 0.65, \"exclude_archived\": true, \"tags\": [\"alpha\", \"beta\"], \"sort\": \"desc\"}"
  },
  {
    "id": "filter",
    "variant": "A",
    "repeat": 2,
    "answer": "{\"top_k\": 7, \"min_score\": 0.65, \"exclude_archived\": true, \"tags\": [\"alpha\", \"beta\"], \"sort\": \"desc\"}"
  },
  {
    "id": "retry",
    "variant": "B",
    "repeat": 1,
    "answer": "{\"attempts\": 4, \"backoff_ms\": [50, 100, 200], \"retry_codes\": [429, 503], \"jitter\": false}"
  },
  {
    "id": "csv",
    "variant": "A",
    "repeat": 2,
    "answer": "```json\n{\"delimiter\": \"\\t\", \"encoding\": \"utf-8\", \"header\": false, \"columns\": [\"sku\", \"qty\"]}\n```"
  },
  {
    "id": "csv",
    "variant": "B",
    "repeat": 2,
    "answer": "```json\n{\"delimiter\": \"\\t\", \"encoding\": \"utf-8\", \"header\": false, \"columns\": [\"sku\", \"qty\"]}\n```"
  },
  {
    "id": "deploy",
    "variant": "A",
    "repeat": 1,
    "answer": "{\"service\": \"delta\", \"replicas\": 3, \"region\": \"ap-northeast-1\", \"health_path\": \"/ready\", \"timeout_s\": 17}"
  },
  {
    "id": "deploy",
    "variant": "A",
    "repeat": 2,
    "answer": "{\"service\": \"delta\", \"replicas\": 3, \"region\": \"ap-northeast-1\", \"health_path\": \"/ready\", \"timeout_s\": 17}"
  },
  {
    "id": "deploy",
    "variant": "B",
    "repeat": 1,
    "answer": "{\"service\": \"delta\", \"replicas\": 3, \"region\": \"ap-northeast-1\", \"health_path\": \"/ready\", \"timeout_s\": 17}"
  }
];

const FENCE_RE = /^```(?:json|JSON)?\s*\n([\s\S]*?)\n```$/;

export function jsonValuesEqual(a, b) {
  if (Object.is(a, b)) return true;
  if (a === null || b === null || typeof a !== typeof b) return false;
  if (Array.isArray(a)) {
    if (!Array.isArray(b) || a.length !== b.length) return false;
    return a.every((v, i) => jsonValuesEqual(v, b[i]));
  }
  if (typeof a === 'object') {
    if (Array.isArray(b)) return false;
    const keysA = Object.keys(a);
    const keysB = Object.keys(b);
    if (keysA.length !== keysB.length) return false;
    return keysA.every((k) => Object.prototype.hasOwnProperty.call(b, k) && jsonValuesEqual(a[k], b[k]));
  }
  return a === b;
}

export function parseRequiredKeys(input) {
  if (Array.isArray(input)) {
    return [...new Set(input.map((v) => String(v).trim()).filter(Boolean))];
  }
  return [...new Set(String(input ?? '').split(',').map((v) => v.trim()).filter(Boolean))];
}

export function evaluateSkillJsonResponse({
  rawOutput,
  requiredKeys = [],
  exampleObject = {},
  expectedObject = null,
  allowExtraKeys = false,
}) {
  const trimmed = String(rawOutput ?? '').trim();
  const keys = parseRequiredKeys(requiredKeys);
  const violations = [];

  if (!trimmed) {
    violations.push({ code: 'empty_output', severity: 'block', message: 'AI出力が空のためブロックしました。' });
    return {
      decision: 'blocked',
      decisionLabel: 'ブロック',
      strictJsonPass: false,
      fenceStripped: false,
      normalizedJson: null,
      legacyTrimBlockedKeys: [],
      missingKeys: keys,
      extraKeys: [],
      copiedExampleKeys: [],
      matchesExpected: false,
      violations,
    };
  }

  let strictJsonPass = false;
  try {
    const strictParsed = JSON.parse(trimmed);
    if (strictParsed !== null && typeof strictParsed === 'object' && !Array.isArray(strictParsed)) {
      strictJsonPass = true;
    }
  } catch {
    strictJsonPass = false;
  }

  let working = trimmed;
  let fenceStripped = false;
  const fenceMatch = FENCE_RE.exec(working);
  if (fenceMatch) {
    working = fenceMatch[1].trim();
    fenceStripped = true;
    violations.push({
      code: 'json_code_fence_stripped',
      severity: 'remediate',
      message: 'JSON周囲のMarkdownコードフェンスを除去しました。',
    });
  }

  let parsed;
  try {
    parsed = JSON.parse(working);
  } catch {
    violations.push({
      code: 'invalid_json_syntax',
      severity: 'block',
      message: 'JSON構文のパースに失敗しました。',
    });
    return {
      decision: 'blocked',
      decisionLabel: 'ブロック',
      strictJsonPass,
      fenceStripped,
      normalizedJson: null,
      legacyTrimBlockedKeys: [],
      missingKeys: keys,
      extraKeys: [],
      copiedExampleKeys: [],
      matchesExpected: false,
      violations,
    };
  }

  if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) {
    violations.push({
      code: 'invalid_json_object_type',
      severity: 'block',
      message: 'JSON出力はオブジェクト形式である必要があります。',
    });
    return {
      decision: 'blocked',
      decisionLabel: 'ブロック',
      strictJsonPass,
      fenceStripped,
      normalizedJson: null,
      legacyTrimBlockedKeys: [],
      missingKeys: keys,
      extraKeys: [],
      copiedExampleKeys: [],
      matchesExpected: false,
      violations,
    };
  }

  const missingKeys = [];
  const legacyTrimBlockedKeys = [];
  const allowedSet = new Set(keys);

  for (const field of keys) {
    const hasField = Object.prototype.hasOwnProperty.call(parsed, field);
    const val = hasField ? parsed[field] : undefined;
    const legacyBlank = val === undefined || val === null || (typeof val === 'string' && val.trim() === '');
    if (legacyBlank) {
      legacyTrimBlockedKeys.push(field);
    }
    const isBlankString = typeof val === 'string' && val.trim() === '' && !val.includes('\t');
    if (val === undefined || val === null || isBlankString) {
      missingKeys.push(field);
      violations.push({
        code: `missing_required_field_${field}`,
        severity: 'block',
        message: `必須JSONフィールド「${field}」が欠落しています。`,
      });
    }
  }

  const extraKeys = [];
  if (!allowExtraKeys && allowedSet.size > 0) {
    for (const key of Object.keys(parsed)) {
      if (!allowedSet.has(key)) {
        extraKeys.push(key);
        violations.push({
          code: `unexpected_extra_field_${key}`,
          severity: 'block',
          message: `指定外のJSONフィールド「${key}」が含まれています。`,
        });
      }
    }
  }

  const copiedExampleKeys = [];
  if (exampleObject && typeof exampleObject === 'object' && !Array.isArray(exampleObject)) {
    for (const [k, exVal] of Object.entries(exampleObject)) {
      if (Object.prototype.hasOwnProperty.call(parsed, k) && jsonValuesEqual(parsed[k], exVal)) {
        copiedExampleKeys.push(k);
        violations.push({
          code: `copied_example_value_${k}`,
          severity: 'block',
          message: `サンプル値と同一の値がフィールド「${k}」に混入しています。`,
        });
      }
    }
  }

  const hasBlock = violations.some((v) => v.severity === 'block');
  const hasRemediate = violations.some((v) => v.severity === 'remediate');
  const decision = hasBlock ? 'blocked' : (hasRemediate ? 'remediated' : 'passed');
  const decisionLabel = decision === 'blocked' ? 'ブロック' : (decision === 'remediated' ? '自動修正' : '通過');

  const matchesExpected = expectedObject ? jsonValuesEqual(parsed, expectedObject) : !hasBlock;

  return {
    decision,
    decisionLabel,
    strictJsonPass,
    fenceStripped,
    normalizedJson: JSON.stringify(parsed, null, 2),
    legacyTrimBlockedKeys,
    missingKeys,
    extraKeys,
    copiedExampleKeys,
    matchesExpected,
    violations,
  };
}

export function runTwentyTrialSelfCheck() {
  const caseMap = Object.fromEntries(FROZEN_CASES.map((c) => [c.id, c]));
  const rows = [];
  const summary = {
    A: { n: 0, strictPass: 0, semanticPass: 0, fenced: 0, legacyTrimFalseBlock: 0, fixedBlock: 0 },
    B: { n: 0, strictPass: 0, semanticPass: 0, fenced: 0, legacyTrimFalseBlock: 0, fixedBlock: 0 },
  };

  for (const r of FROZEN_RESPONSES) {
    const c = caseMap[r.id];
    const reqKeys = Object.keys(c.expected);
    const res = evaluateSkillJsonResponse({
      rawOutput: r.answer,
      requiredKeys: reqKeys,
      exampleObject: c.example,
      expectedObject: c.expected,
      allowExtraKeys: false,
    });
    const s = summary[r.variant];
    s.n += 1;
    if (res.strictJsonPass) s.strictPass += 1;
    if (res.matchesExpected) s.semanticPass += 1;
    if (res.fenceStripped) s.fenced += 1;
    if (res.legacyTrimBlockedKeys.length > 0 && res.missingKeys.length === 0) s.legacyTrimFalseBlock += 1;
    if (res.decision === 'blocked') s.fixedBlock += 1;

    rows.push({
      key: `${r.id}-${r.variant}${r.repeat}`,
      id: r.id,
      variant: r.variant,
      repeat: r.repeat,
      strictJsonPass: res.strictJsonPass,
      fenceStripped: res.fenceStripped,
      decision: res.decision,
      decisionLabel: res.decisionLabel,
      legacyTrimFalseBlock: res.legacyTrimBlockedKeys.length > 0,
      legacyBlockedFields: res.legacyTrimBlockedKeys,
      matchesExpected: res.matchesExpected,
    });
  }

  return {
    total: rows.length,
    apiCalls: 0,
    summary,
    rows,
  };
}
