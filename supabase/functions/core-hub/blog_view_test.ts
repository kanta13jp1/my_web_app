import {
  assert,
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  BLOG_VIEW_COLUMNS,
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
    content_preview: "実装ログの要約",
    posted_at: "2026-07-01T09:30:00+09:00",
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
  const p = blogPostToPayload(sampleRow({ content_preview: null }));
  assertEquals(
    p.appUrl,
    "https://my-web-app-b67f4.web.app/blog/post?id=abc-123",
  );
  assertEquals(p.excerpt, "本文です。 実装の詳細を書きます。");
  assertEquals(p.externalUrl, "https://dev.to/kanta13jp1/foo");
  assertEquals(p.postedAt, "2026-07-01T09:30:00+09:00");
  assertEquals(p.publishedAt, p.postedAt);
});

Deno.test("blog payload keeps preview and nullable publication date", () => {
  const p = blogPostToPayload(sampleRow({ posted_at: null }));
  assertEquals(p.excerpt, "実装ログの要約");
  assertEquals(p.postedAt, null);
  assertEquals(p.publishedAt, null);
  assertEquals(
    blogPostToPayload(sampleRow({ content_preview: "  " })).excerpt,
    "本文です。 実装の詳細を書きます。",
  );
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

// BLOG_VIEW_COLUMNS が実在しない列を選ぶと PostgREST 42703 を返し、core-hub の
// json() が 5xx を "Internal server error" にマスクするため原因が消える。
// #3925 以降 blog.public.view / list が本番で常時 500 だったのはこれが理由 (excerpt /
// published_at は blog_posts に存在しない)。フィクスチャでは捕まらないので、
// migration が実際に宣言した列と突き合わせる。
function declaredBlogPostsColumns(): Set<string> {
  const dir = new URL("../../migrations/", import.meta.url);
  const cols = new Set<string>();
  for (const entry of Deno.readDirSync(dir)) {
    if (!entry.isFile || !entry.name.endsWith(".sql")) continue;
    const raw = Deno.readTextFileSync(new URL(entry.name, dir));
    // migration は 2000 本超。blog_posts に触れない file は正規化前に落とす。
    if (!raw.includes("blog_posts")) continue;
    const sql = raw.replace(/\s+/g, " ");
    const create = sql.match(
      /CREATE TABLE (?:IF NOT EXISTS )?(?:public\.)?blog_posts \((.*?)\);/i,
    );
    if (create) {
      let depth = 0;
      let field = "";
      for (const ch of create[1]) {
        if (ch === "(") depth++;
        else if (ch === ")") depth--;
        if (ch === "," && depth === 0) {
          cols.add(field.trim().split(" ")[0].toLowerCase());
          field = "";
        } else field += ch;
      }
      if (field.trim()) cols.add(field.trim().split(" ")[0].toLowerCase());
    }
    for (
      const m of sql.matchAll(
        /ALTER TABLE (?:public\.)?blog_posts ADD COLUMN (?:IF NOT EXISTS )?([a-z_]+)/gi,
      )
    ) {
      cols.add(m[1].toLowerCase());
    }
  }
  cols.delete("constraint");
  return cols;
}

Deno.test("BLOG_VIEW_COLUMNS only selects columns declared by migrations", () => {
  const declared = declaredBlogPostsColumns();
  // パーサ自体が壊れて空集合を返すと検証力ゼロになるので先に固定
  assert(
    declared.has("posted_at"),
    "migration parser found no blog_posts columns",
  );
  const selected = BLOG_VIEW_COLUMNS.split(",").map((c) => c.trim());
  const missing = selected.filter((c) => !declared.has(c));
  assertEquals(
    missing,
    [],
    `BLOG_VIEW_COLUMNS selects columns absent from blog_posts: ${
      missing.join(", ")
    }`,
  );
});
