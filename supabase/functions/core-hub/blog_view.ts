// blog_view.ts — 公開ブログ (blog_posts status='posted') の bot / AI 可読ビュー
//
// /blog/post は Flutter SPA でアプリ内ナビ引数から記事を特定するため、クローラーが
// URL で直接アクセスできず、公開ブログ (anon 可読 / migration 20260504050000) が
// インデックスされていなかった (SEO 監査 H7)。core-hub の匿名 action
// blog.public.view / blog.public.list が同じ記事をサーバー描画済みの
// HTML / JSON / Markdown で返し、非JSクローラー / LLM / 検索エンジンに開放する。
// 公開メモの public_memo_view.ts と同じ設計。汎用ヘルパーは同ファイルから再利用する。

import {
  buildPublicMemoExcerpt,
  clampPublicMemoLimit,
  escapeHtml,
  normalizePublicMemoSearchQuery,
  type PublicMemoViewFormat,
  resolvePublicMemoViewFormat,
  searchParamsToActionBody,
} from "./public_memo_view.ts";

export const BLOG_SITE_NAME = "自分株式会社";
export const BLOG_APP_BASE_URL = "https://my-web-app-b67f4.web.app/blog/post";

// 再エクスポート (core-hub index.ts が blog 用に import する汎用ヘルパー)
export {
  clampPublicMemoLimit,
  normalizePublicMemoSearchQuery,
  resolvePublicMemoViewFormat,
  searchParamsToActionBody,
};
export type { PublicMemoViewFormat };

export interface BlogPostRow {
  id: string;
  title: string | null;
  content: string | null;
  excerpt: string | null;
  posted_at: string | null;
  published_at: string | null;
  url: string | null;
  tags?: unknown;
}

export const BLOG_VIEW_COLUMNS =
  "id, title, content, excerpt, posted_at, published_at, url, tags";

export function buildBlogPostUrl(id: string): string {
  return `${BLOG_APP_BASE_URL}?id=${encodeURIComponent(id)}`;
}

function blogExcerpt(row: BlogPostRow): string {
  const raw = (row.excerpt ?? "").trim();
  return raw || buildPublicMemoExcerpt(row.content);
}

export function extractBlogTags(row: BlogPostRow): string[] {
  const raw = row.tags;
  const tags: string[] = [];
  const push = (v: unknown) => {
    if (typeof v !== "string") return;
    const t = v.trim();
    if (t && !tags.includes(t)) tags.push(t);
  };
  if (Array.isArray(raw)) raw.forEach(push);
  else if (typeof raw === "string") raw.split(",").forEach(push);
  return tags;
}

export function blogPostToPayload(row: BlogPostRow): Record<string, unknown> {
  return {
    id: row.id,
    title: row.title ?? "",
    content: row.content ?? "",
    excerpt: blogExcerpt(row),
    tags: extractBlogTags(row),
    postedAt: row.posted_at,
    publishedAt: row.published_at,
    externalUrl: row.url,
    appUrl: buildBlogPostUrl(row.id),
  };
}

function blogDate(iso: string | null): string {
  return iso ? iso.slice(0, 10) : "";
}

export function renderBlogArticleJsonLd(row: BlogPostRow): string {
  const appUrl = buildBlogPostUrl(row.id);
  const article: Record<string, unknown> = {
    "@context": "https://schema.org",
    "@type": "BlogPosting",
    headline: row.title ?? `Blog #${row.id}`,
    description: blogExcerpt(row),
    inLanguage: "ja",
    mainEntityOfPage: appUrl,
    url: appUrl,
    author: { "@type": "Organization", name: BLOG_SITE_NAME },
    publisher: {
      "@type": "Organization",
      name: BLOG_SITE_NAME,
      logo: {
        "@type": "ImageObject",
        url: "https://my-web-app-b67f4.web.app/ogp-image-gen2-20260428.png",
      },
    },
  };
  const tags = extractBlogTags(row);
  if (tags.length > 0) article.keywords = tags.join(", ");
  const published = row.posted_at ?? row.published_at;
  if (published) {
    article.datePublished = published;
    article.dateModified = published;
  }
  const json = JSON.stringify(article).replaceAll("<", "\\u003c");
  return `<script type="application/ld+json">${json}</script>`;
}

function blogHtmlDocument(opts: {
  title: string;
  description: string;
  canonicalUrl: string;
  body: string;
}): string {
  const title = escapeHtml(opts.title);
  const description = escapeHtml(opts.description);
  const canonical = escapeHtml(opts.canonicalUrl);
  return `<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title} | ${BLOG_SITE_NAME}</title>
<meta name="description" content="${description}">
<link rel="canonical" href="${canonical}">
<meta property="og:title" content="${title}">
<meta property="og:description" content="${description}">
<meta property="og:url" content="${canonical}">
<meta property="og:type" content="article">
<meta property="og:site_name" content="${BLOG_SITE_NAME}">
<meta name="twitter:card" content="summary">
</head>
<body>
<main style="max-width:720px;margin:0 auto;padding:24px;font-family:sans-serif;line-height:1.7">
${opts.body}
</main>
</body>
</html>
`;
}

export function renderBlogHtml(row: BlogPostRow): string {
  const title = row.title ?? `Blog #${row.id}`;
  const appUrl = buildBlogPostUrl(row.id);
  const meta: string[] = [];
  const posted = blogDate(row.posted_at ?? row.published_at);
  if (posted) meta.push(`公開日: ${posted}`);
  const tags = extractBlogTags(row);
  if (tags.length) meta.push(`タグ: ${tags.join(", ")}`);
  const body = `${renderBlogArticleJsonLd(row)}
<article>
<h1>${escapeHtml(title)}</h1>
<p>${escapeHtml(meta.join(" / "))}</p>
<div style="white-space:pre-wrap">${escapeHtml(row.content ?? "")}</div>
</article>
<footer style="margin-top:32px;font-size:0.9em">
<p><a href="${escapeHtml(appUrl)}">アプリで開く (${
    escapeHtml(BLOG_SITE_NAME)
  })</a></p>
</footer>`;
  return blogHtmlDocument({
    title,
    description: blogExcerpt(row),
    canonicalUrl: appUrl,
    body,
  });
}

export function renderBlogMarkdown(row: BlogPostRow): string {
  const title = row.title ?? `Blog #${row.id}`;
  const posted = blogDate(row.posted_at ?? row.published_at);
  const lines = [
    `# ${title}`,
    "",
    posted ? `- 公開日: ${posted}` : "",
    `- App URL: ${buildBlogPostUrl(row.id)}`,
    "",
    row.content ?? "",
    "",
  ].filter((l) => l !== "");
  return lines.join("\n");
}

export function renderBlogNotFoundHtml(id: string): string {
  return blogHtmlDocument({
    title: `Blog ${escapeHtml(id)} not found`,
    description: "指定された記事は存在しないか、未公開です。",
    canonicalUrl: buildBlogPostUrl(id),
    body:
      `<h1>Blog post not found</h1><p>この記事は存在しないか、未公開です。</p>` +
      `<p><a href="https://my-web-app-b67f4.web.app/blog">ブログ一覧</a></p>`,
  });
}

export function renderBlogListHtml(rows: BlogPostRow[]): string {
  const items = rows.map((row) => {
    const href = escapeHtml(buildBlogPostUrl(row.id));
    const title = escapeHtml(row.title ?? `Blog #${row.id}`);
    const ex = escapeHtml(blogExcerpt(row));
    const posted = escapeHtml(blogDate(row.posted_at ?? row.published_at));
    return `<li style="margin-bottom:16px"><a href="${href}">${title}</a>` +
      `<small> (${posted})</small><p style="margin:4px 0">${ex}</p></li>`;
  }).join("\n");
  return blogHtmlDocument({
    title: "ブログ",
    description: `${BLOG_SITE_NAME}の公式ブログ 最新${rows.length}件`,
    canonicalUrl: "https://my-web-app-b67f4.web.app/blog",
    body: `<h1>ブログ (${rows.length}件)</h1>\n<ol>\n${items}\n</ol>`,
  });
}

export function renderBlogListMarkdown(rows: BlogPostRow[]): string {
  const items = rows.map((row) =>
    `- [${row.title ?? `Blog #${row.id}`}](${buildBlogPostUrl(row.id)}) (${
      blogDate(row.posted_at ?? row.published_at)
    })`
  );
  return [`# ブログ (${rows.length}件)`, "", ...items, ""].join("\n");
}
