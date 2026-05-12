// AI Action Schema — 自分株式会社 AI 機能共通アクション契約
//
// docs/IMBUE_PATTERNS.md のパターン 6 (Reasoning → DB Action) を実装する
// 共通スキーマ。AI EF が「ユーザーの悩みを推論で分解 → 構造化アクションを
// 出力 → ユーザー承認後に Supabase へ書き込み」という Sculptor フロー
// (パターン 7) と組み合わせて使う。
//
// ソース: NotebookLM Notebook 2fc6d86f-2bbd-4fdc-ad9e-f302d93b5c6e
// "Imbue: Empowering Human Agency Through AI Reasoning and Coding"

/**
 * 1 件の AI 提案アクション。AI EF が出力する `actions: AiAction[]` の要素。
 *
 * - `op: 'insert'` — 新規レコード追加 (例: 新習慣 / 新目標)
 * - `op: 'update'` — 既存レコード更新 (id 必須)
 * - `op: 'delete'` — 既存レコード削除 (id 必須)
 *
 * `payload` は table の RLS で許可された範囲のみ。`reasoning` は AI が
 * 「なぜこのアクションを提案したか」を 1-2 文で説明する欄で、Sculptor UI
 * (パターン 7) でユーザーが見て理解できることを保証する。
 */
export interface AiAction {
  op: "insert" | "update" | "delete";
  table: string;
  /** insert 以外で必須 — 対象レコードの主キー */
  id?: string;
  /** insert / update で必須 — RLS で許可されたカラムのみ */
  payload?: Record<string, unknown>;
  /** Sculptor UI 表示用の根拠文 (パターン 7 必須) */
  reasoning: string;
  /** パターン 2 (cost-aware): 投入予算 (分) と期待 KGI 寄与 */
  cost_estimate_minutes?: number;
  expected_kgi_lift?: number;
}

/** AI EF レスポンスのうちアクション部分の標準フォーマット */
export interface AiActionEnvelope {
  /** ユーザー向けの自然言語説明 (任意 / Sculptor UI で先頭表示) */
  summary?: string;
  /** 提案アクション群 (空配列 OK = 「今は何もしない」も valid な提案) */
  actions: AiAction[];
}

const ALLOWED_TABLES = new Set([
  // ライフ管理コア
  "goals",
  "tasks",
  "habits",
  "journal_entries",
  "schedule_items",
  // ホーム画面ウィジェット系
  "shopping_list",
  "thought_captures",
  "wbs_tasks",
]);

/**
 * AI 出力をパースする前のガード。RLS をクライアント側でも 1 段守る
 * (= AI が変なテーブル名を出力しても拒否)。
 *
 * 戻り値は { ok: true, value } か { ok: false, error } のいずれか。
 * 例外を投げない (= 呼び出し側 EF の try/catch を汚さない)。
 */
export function parseAiActionEnvelope(
  raw: unknown,
): { ok: true; value: AiActionEnvelope } | { ok: false; error: string } {
  if (typeof raw !== "object" || raw === null) {
    return { ok: false, error: "envelope must be an object" };
  }
  const obj = raw as Record<string, unknown>;
  const actions = obj.actions;
  if (!Array.isArray(actions)) {
    return { ok: false, error: "envelope.actions must be an array" };
  }

  const validated: AiAction[] = [];
  for (let i = 0; i < actions.length; i++) {
    const a = actions[i];
    if (typeof a !== "object" || a === null) {
      return { ok: false, error: `actions[${i}] must be an object` };
    }
    const ax = a as Record<string, unknown>;
    if (ax.op !== "insert" && ax.op !== "update" && ax.op !== "delete") {
      return {
        ok: false,
        error: `actions[${i}].op must be insert|update|delete`,
      };
    }
    if (typeof ax.table !== "string" || !ALLOWED_TABLES.has(ax.table)) {
      return {
        ok: false,
        error: `actions[${i}].table '${ax.table}' is not in the allowed list`,
      };
    }
    if (typeof ax.reasoning !== "string" || ax.reasoning.trim() === "") {
      return {
        ok: false,
        error: `actions[${i}].reasoning is required (Sculptor UI needs it)`,
      };
    }
    if (
      (ax.op === "update" || ax.op === "delete") && typeof ax.id !== "string"
    ) {
      return {
        ok: false,
        error: `actions[${i}] op=${ax.op} requires string id`,
      };
    }
    if (
      (ax.op === "insert" || ax.op === "update") &&
      (typeof ax.payload !== "object" || ax.payload === null)
    ) {
      return {
        ok: false,
        error: `actions[${i}] op=${ax.op} requires payload object`,
      };
    }

    const built: AiAction = {
      op: ax.op,
      table: ax.table,
      reasoning: ax.reasoning.trim(),
    };
    if (typeof ax.id === "string") built.id = ax.id;
    if (ax.payload && typeof ax.payload === "object") {
      built.payload = ax.payload as Record<string, unknown>;
    }
    if (typeof ax.cost_estimate_minutes === "number") {
      built.cost_estimate_minutes = ax.cost_estimate_minutes;
    }
    if (typeof ax.expected_kgi_lift === "number") {
      built.expected_kgi_lift = ax.expected_kgi_lift;
    }
    validated.push(built);
  }

  const summary = typeof obj.summary === "string" ? obj.summary : undefined;
  return { ok: true, value: { summary, actions: validated } };
}

/**
 * AI EF 用の system prompt 追加文。AI に actions[] 形式の出力を強制したい
 * ときに `${AI_CHARACTER_PREAMBLE}\n\n${AI_ACTION_INSTRUCTIONS}\n\n${task}` で
 * 連結して使う。
 */
export const AI_ACTION_INSTRUCTIONS = `応答の最後に、ユーザーの状況に応じて
アプリ内で実行すべきアクション群を必ず JSON 形式で出力してください。フォーマット:

{
  "summary": "1-2 文のユーザー向け説明 (任意)",
  "actions": [
    {
      "op": "insert",
      "table": "goals" | "tasks" | "habits" | "journal_entries" | "schedule_items" | "shopping_list" | "thought_captures" | "wbs_tasks",
      "payload": { ...RLS で許可されたカラムのみ },
      "reasoning": "なぜこのアクションを提案したかの 1-2 文",
      "cost_estimate_minutes": 数値 (任意),
      "expected_kgi_lift": 数値 (任意)
    }
  ]
}

- 提案するアクションがなければ "actions": [] を返してください (= 「今は何もしない」)。
- ユーザー承認前にアプリは絶対に DB 書き込みを行いません。あなたは叩き台を提示する役です。`;
