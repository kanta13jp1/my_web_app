// public_memo_view.ts — 公開メモの bot / AI 可読ビュー
//
// Flutter SPA (/public-memo?id=X) は JS 実行後に Supabase から本文を取得する
// ため、ChatGPT 等の外部 AI やクローラーは URL を開いても本文を読めない。
// core-hub の匿名 action `memo.public.view` / `memo.public.list` が同じデータを
// サーバー側で描画済みの HTML / JSON / Markdown として返すことで補完する
// (hub 統合 Issue #607 で削除された public-memo-share / get-public-memo-ogp の後継)。

export const PUBLIC_MEMO_SITE_NAME = "自分株式会社";
export const PUBLIC_MEMO_APP_BASE_URL =
  "https://my-web-app-b67f4.web.app/public-memo";

export interface PublicMemoViewRow {
  id: number;
  title: string | null;
  content: string | null;
  category: string | null;
  published_at: string | null;
  updated_at: string | null;
  view_count: number | null;
  like_count: number | null;
}

export type PublicMemoViewFormat = "html" | "json" | "md";

export const PUBLIC_MEMO_VIEW_COLUMNS =
  "id, title, content, category, published_at, updated_at, view_count, like_count";

/// format param 明示が最優先。未指定時は GET/HEAD (ブラウザ / クローラー直
/// アクセス。HEAD は AI フェッチャーのプリフライト) は HTML、POST (API
/// クライアント) は JSON を既定とする。
export function resolvePublicMemoViewFormat(
  format: unknown,
  method: string,
): PublicMemoViewFormat {
  const normalized = typeof format === "string"
    ? format.trim().toLowerCase()
    : "";
  if (normalized === "json") return "json";
  if (normalized === "md" || normalized === "markdown") return "md";
  if (normalized === "html") return "html";
  const upper = method.toUpperCase();
  return upper === "GET" || upper === "HEAD" ? "html" : "json";
}

export function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

export function buildPublicMemoPageUrl(memoId: number): string {
  return `${PUBLIC_MEMO_APP_BASE_URL}?id=${memoId}`;
}

/// PublicMemoService._buildShareExcerpt (Dart) と同じ規則:
/// 空白を単一スペースに正規化し、140 字を超えたら 137 字 + "..." に切り詰める。
export function buildPublicMemoExcerpt(
  content: string | null | undefined,
  maxLength = 140,
): string {
  const normalized = (content ?? "").replace(/\s+/g, " ").trim();
  if (normalized.length <= maxLength) {
    return normalized;
  }
  return `${normalized.slice(0, maxLength - 3)}...`;
}

export function publicMemoToPayload(
  row: PublicMemoViewRow,
): Record<string, unknown> {
  return {
    id: row.id,
    title: row.title ?? "",
    content: row.content ?? "",
    category: row.category,
    publishedAt: row.published_at,
    updatedAt: row.updated_at,
    viewCount: row.view_count ?? 0,
    likeCount: row.like_count ?? 0,
    appUrl: buildPublicMemoPageUrl(row.id),
  };
}

function formatDate(iso: string | null): string {
  if (!iso) return "";
  return iso.slice(0, 10);
}

function memoMetaLine(row: PublicMemoViewRow): string {
  const parts: string[] = [];
  const category = row.category?.trim();
  if (category) parts.push(`カテゴリ: ${category}`);
  const published = formatDate(row.published_at);
  if (published) parts.push(`公開日: ${published}`);
  parts.push(`閲覧 ${row.view_count ?? 0}`);
  parts.push(`いいね ${row.like_count ?? 0}`);
  return parts.join(" / ");
}

function htmlDocument(options: {
  title: string;
  description: string;
  canonicalUrl: string;
  ogType: string;
  body: string;
}): string {
  const title = escapeHtml(options.title);
  const description = escapeHtml(options.description);
  const canonical = escapeHtml(options.canonicalUrl);
  return `<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title} | ${PUBLIC_MEMO_SITE_NAME}</title>
<meta name="description" content="${description}">
<link rel="canonical" href="${canonical}">
<meta property="og:title" content="${title}">
<meta property="og:description" content="${description}">
<meta property="og:url" content="${canonical}">
<meta property="og:type" content="${options.ogType}">
<meta property="og:site_name" content="${PUBLIC_MEMO_SITE_NAME}">
<meta name="twitter:card" content="summary">
<meta name="twitter:title" content="${title}">
<meta name="twitter:description" content="${description}">
</head>
<body>
<main style="max-width:720px;margin:0 auto;padding:24px;font-family:sans-serif;line-height:1.7">
${options.body}
</main>
</body>
</html>
`;
}

export function renderPublicMemoHtml(row: PublicMemoViewRow): string {
  const title = row.title ?? `Public Memo #${row.id}`;
  const appUrl = buildPublicMemoPageUrl(row.id);
  const jsonHref = escapeHtml(
    `?action=memo.public.view&id=${row.id}&format=json`,
  );
  const body = `<article>
<h1>${escapeHtml(title)}</h1>
<p>${escapeHtml(memoMetaLine(row))}</p>
<div style="white-space:pre-wrap">${escapeHtml(row.content ?? "")}</div>
</article>
<footer style="margin-top:32px;font-size:0.9em">
<p><a href="${escapeHtml(appUrl)}">アプリで開く (${
    escapeHtml(PUBLIC_MEMO_SITE_NAME)
  })</a> | <a href="${jsonHref}">JSON</a></p>
</footer>`;
  return htmlDocument({
    title,
    description: buildPublicMemoExcerpt(row.content),
    canonicalUrl: appUrl,
    ogType: "article",
    body,
  });
}

export function renderPublicMemoMarkdown(row: PublicMemoViewRow): string {
  const title = row.title ?? `Public Memo #${row.id}`;
  const lines = [
    `# ${title}`,
    "",
    `- ${memoMetaLine(row)}`,
    `- App URL: ${buildPublicMemoPageUrl(row.id)}`,
    "",
    row.content ?? "",
    "",
  ];
  return lines.join("\n");
}

export function renderPublicMemoNotFoundHtml(memoId: number): string {
  const body = `<h1>Public memo #${memoId} not found</h1>
<p>このメモは存在しないか、非公開に変更されています。</p>
<p><a href="${escapeHtml(PUBLIC_MEMO_APP_BASE_URL)}s">公開メモ一覧</a></p>`;
  return htmlDocument({
    title: `Public memo #${memoId} not found`,
    description: "指定された公開メモは存在しないか、非公開に変更されています。",
    canonicalUrl: buildPublicMemoPageUrl(memoId),
    ogType: "website",
    body,
  });
}

export function renderPublicMemoListHtml(rows: PublicMemoViewRow[]): string {
  const items = rows
    .map((row) => {
      const viewHref = escapeHtml(
        `?action=memo.public.view&id=${row.id}`,
      );
      const title = escapeHtml(row.title ?? `Public Memo #${row.id}`);
      const excerpt = escapeHtml(buildPublicMemoExcerpt(row.content, 100));
      const published = escapeHtml(formatDate(row.published_at));
      return `<li style="margin-bottom:16px">
<a href="${viewHref}">${title}</a>
<small> (${published})</small>
<p style="margin:4px 0">${excerpt}</p>
</li>`;
    })
    .join("\n");
  const body = `<h1>公開メモ一覧 (${rows.length}件)</h1>
<ol>
${items}
</ol>
<footer style="margin-top:32px;font-size:0.9em">
<p><a href="${escapeHtml(`${PUBLIC_MEMO_APP_BASE_URL}s`)}">アプリで開く (${
    escapeHtml(PUBLIC_MEMO_SITE_NAME)
  })</a> | <a href="${
    escapeHtml("?action=memo.public.list&format=json")
  }">JSON</a></p>
</footer>`;
  return htmlDocument({
    title: "公開メモ一覧",
    description: `${PUBLIC_MEMO_SITE_NAME}の公開メモ 最新${rows.length}件`,
    canonicalUrl: `${PUBLIC_MEMO_APP_BASE_URL}s`,
    ogType: "website",
    body,
  });
}

export function renderPublicMemoListMarkdown(
  rows: PublicMemoViewRow[],
): string {
  const items = rows.map((row) => {
    const title = row.title ?? `Public Memo #${row.id}`;
    const published = formatDate(row.published_at);
    return `- [#${row.id}] ${title} (${published}) — ${
      buildPublicMemoExcerpt(row.content, 100)
    }`;
  });
  return [`# 公開メモ一覧 (${rows.length}件)`, "", ...items, ""].join("\n");
}
