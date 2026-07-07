import {
  assert,
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildPublicMemoExcerpt,
  buildPublicMemoPageUrl,
  escapeHtml,
  publicMemoToPayload,
  type PublicMemoViewRow,
  renderPublicMemoHtml,
  renderPublicMemoListHtml,
  renderPublicMemoListMarkdown,
  renderPublicMemoMarkdown,
  renderPublicMemoNotFoundHtml,
  resolvePublicMemoViewFormat,
} from "./public_memo_view.ts";

function sampleRow(overrides: Partial<PublicMemoViewRow> = {}) {
  return {
    id: 44,
    title: "地方議員データ更新メモ",
    content: "最近追加された地方議員は4人です。\n新規公認: 2人 / 入党: 2人。",
    category: "選挙",
    published_at: "2026-07-01T09:30:00+09:00",
    updated_at: "2026-07-02T10:00:00+09:00",
    view_count: 12,
    like_count: 3,
    ...overrides,
  } as PublicMemoViewRow;
}

Deno.test("resolvePublicMemoViewFormat honors explicit format first", () => {
  assertEquals(resolvePublicMemoViewFormat("json", "GET"), "json");
  assertEquals(resolvePublicMemoViewFormat("md", "GET"), "md");
  assertEquals(resolvePublicMemoViewFormat("markdown", "POST"), "md");
  assertEquals(resolvePublicMemoViewFormat(" HTML ", "POST"), "html");
});

Deno.test("resolvePublicMemoViewFormat defaults by method", () => {
  assertEquals(resolvePublicMemoViewFormat(null, "GET"), "html");
  assertEquals(resolvePublicMemoViewFormat(undefined, "get"), "html");
  assertEquals(resolvePublicMemoViewFormat(null, "HEAD"), "html");
  assertEquals(resolvePublicMemoViewFormat(undefined, "head"), "html");
  assertEquals(resolvePublicMemoViewFormat("", "POST"), "json");
  assertEquals(resolvePublicMemoViewFormat("bogus", "POST"), "json");
});

Deno.test("escapeHtml escapes markup-sensitive characters", () => {
  assertEquals(
    escapeHtml(`<script>alert("x&y")</script>'`),
    "&lt;script&gt;alert(&quot;x&amp;y&quot;)&lt;/script&gt;&#39;",
  );
});

Deno.test("buildPublicMemoExcerpt collapses whitespace and truncates", () => {
  assertEquals(buildPublicMemoExcerpt("  foo\n\nbar\t baz  "), "foo bar baz");
  assertEquals(buildPublicMemoExcerpt(null), "");
  const long = "あ".repeat(200);
  const excerpt = buildPublicMemoExcerpt(long);
  assertEquals(excerpt.length, 140);
  assert(excerpt.endsWith("..."));
});

Deno.test("publicMemoToPayload exposes app URL and normalized counts", () => {
  const payload = publicMemoToPayload(
    sampleRow({ view_count: null, like_count: null }),
  );
  assertEquals(payload.id, 44);
  assertEquals(payload.viewCount, 0);
  assertEquals(payload.likeCount, 0);
  assertEquals(payload.appUrl, buildPublicMemoPageUrl(44));
  assertEquals(
    payload.appUrl,
    "https://my-web-app-b67f4.web.app/public-memo?id=44",
  );
});

Deno.test("renderPublicMemoHtml embeds escaped content and OGP tags", () => {
  const html = renderPublicMemoHtml(
    sampleRow({ content: "<b>本文</b> & memo" }),
  );
  assertStringIncludes(html, '<html lang="ja">');
  assertStringIncludes(
    html,
    "<title>地方議員データ更新メモ | 自分株式会社</title>",
  );
  assertStringIncludes(html, "&lt;b&gt;本文&lt;/b&gt; &amp; memo");
  assert(!html.includes("<b>本文</b>"));
  assertStringIncludes(
    html,
    '<meta property="og:title" content="地方議員データ更新メモ">',
  );
  assertStringIncludes(
    html,
    '<link rel="canonical" href="https://my-web-app-b67f4.web.app/public-memo?id=44">',
  );
  assertStringIncludes(html, "カテゴリ: 選挙 / 公開日: 2026-07-01");
  assertStringIncludes(
    html,
    "?action=memo.public.view&amp;id=44&amp;format=json",
  );
});

Deno.test("renderPublicMemoMarkdown carries title, meta, and body", () => {
  const md = renderPublicMemoMarkdown(sampleRow());
  assertStringIncludes(md, "# 地方議員データ更新メモ");
  assertStringIncludes(md, "公開日: 2026-07-01");
  assertStringIncludes(md, "最近追加された地方議員は4人です。");
  assertStringIncludes(
    md,
    "App URL: https://my-web-app-b67f4.web.app/public-memo?id=44",
  );
});

Deno.test("renderPublicMemoNotFoundHtml mentions the memo id", () => {
  const html = renderPublicMemoNotFoundHtml(44);
  assertStringIncludes(html, "Public memo #44 not found");
  assertStringIncludes(html, "非公開に変更されています");
});

Deno.test("renderPublicMemoListHtml links each memo view action", () => {
  const html = renderPublicMemoListHtml([
    sampleRow(),
    sampleRow({ id: 45, title: "第二のメモ", content: "short" }),
  ]);
  assertStringIncludes(html, "公開メモ一覧 (2件)");
  assertStringIncludes(html, 'href="?action=memo.public.view&amp;id=44"');
  assertStringIncludes(html, 'href="?action=memo.public.view&amp;id=45"');
  assertStringIncludes(html, "第二のメモ");
});

Deno.test("renderPublicMemoListMarkdown renders one bullet per memo", () => {
  const md = renderPublicMemoListMarkdown([sampleRow()]);
  assertStringIncludes(md, "# 公開メモ一覧 (1件)");
  assertStringIncludes(md, "- [#44] 地方議員データ更新メモ (2026-07-01)");
});
