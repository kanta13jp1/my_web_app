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

/** フィードバック投稿から GitHub Issue の下書きを生成する。 */
export function buildFeedbackIssue(params: {
  category: string;
  message: string;
  userEmail?: string;
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
    trimmedMessage.length > 0 ? trimmedMessage : "(本文なし)",
    "",
    "### メタデータ",
    "",
    `- 種別: ${config.label} (${params.category})`,
    `- 送信者: ${
      params.userEmail && params.userEmail.length > 0
        ? params.userEmail
        : "(不明)"
    }`,
  ];
  if (params.createdAt && params.createdAt.length > 0) {
    lines.push(`- 受付: ${params.createdAt}`);
  }
  lines.push(
    "",
    "---",
    "このIssueは自分株式会社アプリの「ご意見・ご要望」フォームから自動起票されました。",
    "`github-issue-fix` レーンが draft PR を起票し、Claude / Codex の AI フリートが対応に着手します。",
  );

  return { title, body: lines.join("\n"), labels: config.labels };
}
