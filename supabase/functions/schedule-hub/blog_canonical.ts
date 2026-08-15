// blog_canonical.ts — dev.to / Qiita へ syndicate する記事の canonical_url を
// 自サイトの公開ブログ (/blog/post?id=X) に向けるためのヘルパー。
//
// SEO 監査 H7: dev.to に投稿した記事は dev.to 側が canonical 扱いになり、
// 検索エンジンの評価 (authority) が外部ドメインに流出していた。Forem (dev.to) API の
// article.canonical_url に自サイト URL を渡すと「原典は自サイト」と宣言でき、
// authority を自ドメインへ集約できる。向け先は core-hub blog_view.ts が SSR 配信する
// /blog/post?id=X (= blog_posts の status='posted' 行) と同一形状にする。

export const BLOG_APP_BASE_URL = "https://my-web-app-b67f4.web.app/blog/post";

// blog_posts.id を受け取り、自サイトの公開ブログ URL を返す。
// core-hub blog_view.ts の buildBlogPostUrl と同じ形状 (?id=<encoded>)。
export function buildOwnSiteBlogPostUrl(id: string): string {
  return `${BLOG_APP_BASE_URL}?id=${encodeURIComponent(id)}`;
}
