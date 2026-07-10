import {
  assert,
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  type BlogPostRow,
  blogPostToPayload,
  buildBlogPostUrl,
  extractBlogTags,
  renderBlogArticleJsonLd,
  renderBlogHtml,
  renderBlogListHtml,
  renderBlogListMarkdown,
  renderBlogMarkdown,
  renderBlogNotFoundHtml,
} from "./blog_view.ts";

function sampleRow(overrides: Partial<BlogPostRow> = {}) {
  return {
    id: "abc-123",
    title: "Flutter × Supabase 実装ログ",
    content: "本文です。\n実装の詳細を書きます。",
    excerpt: "実装ログの要約",
    posted_at: "2026-07-01T09:30:00+09:00",
    published_at: null,
    url: "https://dev.to/kanta13jp1/foo",
    tags: ["flutter", "supabase"],
    ...overrides,
  } as BlogPostRow;
}

Deno.test("buildBlogPostUrl builds crawlable /blog/post URL", () => {
  assertEquals(
    buildBlogPostUrl("abc-123"),
    "https://my-web-app-b67f4.web.app/blog/post?id=abc-123",
  );
});

Deno.test("extractBlogTags normalizes array and CSV", () => {
  assertEquals(extractBlogTags(sampleRow()), ["flutter", "supabase"]);
  assertEquals(
    extractBlogTags(sampleRow({ tags: "a, b ,a," })),
    ["a", "b"],
  );
  assertEquals(extractBlogTags(sampleRow({ tags: null })), []);
});

Deno.test("blogPostToPayload exposes app URL and excerpt fallback", () => {
  const p = blogPostToPayload(sampleRow({ excerpt: null }));
  assertEquals(
    p.appUrl,
    "https://my-web-app-b67f4.web.app/blog/post?id=abc-123",
  );
  assertEquals(p.excerpt, "本文です。 実装の詳細を書きます。");
  assertEquals(p.externalUrl, "https://dev.to/kanta13jp1/foo");
});

Deno.test("renderBlogHtml embeds self-canonical + escaped content", () => {
  const html = renderBlogHtml(sampleRow({ content: "<b>x</b> & y" }));
  assertStringIncludes(
    html,
    '<link rel="canonical" href="https://my-web-app-b67f4.web.app/blog/post?id=abc-123">',
  );
  assertStringIncludes(
    html,
    "<title>Flutter × Supabase 実装ログ | 自分株式会社</title>",
  );
  assertStringIncludes(html, "&lt;b&gt;x&lt;/b&gt; &amp; y");
  assert(!html.includes("<b>x</b>"));
  assertStringIncludes(html, '"@type":"BlogPosting"');
});

Deno.test("renderBlogArticleJsonLd is valid and escaped", () => {
  const script = renderBlogArticleJsonLd(
    sampleRow({ content: "本文 </script>" }),
  );
  assert(!script.slice(30).includes("</script>本文"));
  const json = script
    .replace('<script type="application/ld+json">', "")
    .replace("</script>", "")
    .replaceAll("\\u003c", "<");
  const parsed = JSON.parse(json);
  assertEquals(parsed["@type"], "BlogPosting");
  assertEquals(parsed.datePublished, "2026-07-01T09:30:00+09:00");
  assertEquals(parsed.keywords, "flutter, supabase");
});

Deno.test("renderBlogMarkdown carries title/date/body", () => {
  const md = renderBlogMarkdown(sampleRow());
  assertStringIncludes(md, "# Flutter × Supabase 実装ログ");
  assertStringIncludes(md, "公開日: 2026-07-01");
  assertStringIncludes(md, "実装の詳細を書きます。");
});

Deno.test("renderBlogNotFoundHtml mentions not found", () => {
  const html = renderBlogNotFoundHtml("zzz");
  assertStringIncludes(html, "not found");
  assertStringIncludes(html, "未公開");
});

Deno.test("renderBlogListHtml / Markdown list each post", () => {
  const rows = [sampleRow(), sampleRow({ id: "d2", title: "第二の記事" })];
  const html = renderBlogListHtml(rows);
  assertStringIncludes(html, "ブログ (2件)");
  assertStringIncludes(
    html,
    'href="https://my-web-app-b67f4.web.app/blog/post?id=abc-123"',
  );
  assertStringIncludes(html, "第二の記事");
  const md = renderBlogListMarkdown(rows);
  assertStringIncludes(md, "# ブログ (2件)");
  assertStringIncludes(md, "第二の記事");
});
