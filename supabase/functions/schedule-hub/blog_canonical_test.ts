import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { buildOwnSiteBlogPostUrl } from "./blog_canonical.ts";

Deno.test("buildOwnSiteBlogPostUrl: 自サイト /blog/post?id=X を返す", () => {
  assertEquals(
    buildOwnSiteBlogPostUrl("123"),
    "https://my-web-app-b67f4.web.app/blog/post?id=123",
  );
});

Deno.test("buildOwnSiteBlogPostUrl: id を URL エンコードする", () => {
  const url = buildOwnSiteBlogPostUrl("a b/c?d");
  assertStringIncludes(url, "id=a%20b%2Fc%3Fd");
  // クエリ区切りが 1 つだけ (injection されない)
  assertEquals(url.split("?").length, 2);
});

Deno.test("buildOwnSiteBlogPostUrl: 自ドメインを指す (dev.to 側ではない)", () => {
  const url = buildOwnSiteBlogPostUrl("456");
  assertStringIncludes(url, "https://my-web-app-b67f4.web.app/blog/post");
});
