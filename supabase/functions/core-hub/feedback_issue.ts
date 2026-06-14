// feedback_issue.ts — 「ご意見・ご要望」フォームの投稿を GitHub Issue 化するための
// 純粋なタイトル/本文/ラベル生成ロジック。
//
// ユーザーの要望・不具合報告を `github-issue-fix` レーン (draft PR 自動起票 +
// AI フリート対応) に確実に載せるため、カテゴリごとに正しいラベルを付与する。
// 副作用を持たないため Deno test で網羅検証する。

export interface FeedbackIssueDraft {
  title: string;
  body: string;
  labels: string[];
}

interface FeedbackCategoryConfig {
  /** タイトル接頭辞。 */
  prefix: string;
  /** 人間可読なカテゴリ名。 */
  label: string;
  /**
   * Issue ラベル。`github-issue-fix.yml` は
   * bug / enhancement / feature / user-feedback のいずれかを対象に拾う。
   */
  labels: string[];
}

const FEEDBACK_CATEGORY_CONFIGS: Record<string, FeedbackCategoryConfig> = {
  feature: {
    prefix: "[追加要望]",
    label: "機能改善・追加要望",
    labels: ["enhancement", "追加要望", "user-feedback", "wbs"],
  },
  bug: {
    prefix: "[不具合]",
    label: "不具合・動作不良",
    labels: ["bug", "user-feedback", "wbs"],
  },
  other: {
    prefix: "[ご意見]",
    label: "その他のご意見",
    labels: ["user-feedback", "wbs"],
  },
};

/** カテゴリ設定を取得する（未知のカテゴリは other 扱い）。 */
export function feedbackCategoryConfig(
  category: string,
): FeedbackCategoryConfig {
  return FEEDBACK_CATEGORY_CONFIGS[category] ?? FEEDBACK_CATEGORY_CONFIGS.other;
}

/** 本文の先頭行から Issue タイトルの要約を作る。 */
export function buildFeedbackIssueTitle(
  category: string,
  message: string,
): string {
  const { prefix } = feedbackCategoryConfig(category);
  const firstLine = message
    .split(/\r?\n/)
    .map((line) => line.trim())
    .find((line) => line.length > 0) ?? "";
  const summary = firstLine.length > 60
    ? `${firstLine.slice(0, 57)}...`
    : firstLine;
  const safeSummary = summary.length > 0
    ? summary
    : "ユーザーからのフィードバック";
  return `${prefix} ${safeSummary}`;
}

/**
 * ユーザー入力を GitHub Issue 本文へ安全に埋め込む。
 *
 * 公開リポジトリの Issue 本文では `@mention` が通知を飛ばし、画像 Markdown が
 * トラッキングピクセルになり、HTML が描画されてしまう。フェンス済みコードブロック
 * に包むとこれらが全て無効化される（コードブロック内の @mention は通知されない）。
 * フェンスは本文中のバッククォート連続数より長くして「閉じ忘れ」による脱出を防ぐ。
 */
export function fencedUserContent(message: string): string {
  const runs = message.match(/`+/g) ?? [];
  const longest = runs.reduce((max, run) => Math.max(max, run.length), 0);
  const fence = "`".repeat(Math.max(3, longest + 1));
  return `${fence}text\n${message}\n${fence}`;
}

/** フィードバック投稿から GitHub Issue の下書きを生成する。 */
export function buildFeedbackIssue(params: {
  category: string;
  message: string;
  /** 擬似匿名の user_id。公開 Issue にメール等の PII は載せない。 */
  userId?: string;
  createdAt?: string;
}): FeedbackIssueDraft {
  const config = feedbackCategoryConfig(params.category);
  const title = buildFeedbackIssueTitle(params.category, params.message);
  const trimmedMessage = params.message.trim();

  const lines: string[] = [
    `## ${config.label}`,
    "",
    "### 内容",
    "",
    // ユーザー入力はフェンスで包み、@mention 通知・画像/HTML 描画を無効化する。
    trimmedMessage.length > 0
      ? fencedUserContent(trimmedMessage)
      : "(本文なし)",
    "",
    "### メタデータ",
    "",
    `- 種別: ${config.label} (${params.category})`,
    // PII 保護: メールは公開 Issue 本文に載せず、識別は擬似匿名の user_id のみ。
    `- 送信者ID: ${
      params.userId && params.userId.length > 0 ? params.userId : "(不明)"
    }`,
  ];
  if (params.createdAt && params.createdAt.length > 0) {
    lines.push(`- 受付: ${params.createdAt}`);
  }
  lines.push(
    "",
    "---",
    "このIssueは自分株式会社アプリの「ご意見・ご要望」フォームから自動起票されました。",
    "`github-issue-fix` レーンが draft PR を起票し、対応に着手します。",
  );

  return { title, body: lines.join("\n"), labels: config.labels };
}
