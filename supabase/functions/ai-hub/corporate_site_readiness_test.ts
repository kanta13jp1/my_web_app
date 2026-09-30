import {
  assertEquals,
  assertStringIncludes,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  generateCorporateSiteHtml,
  reviewCorporateSiteDocument,
} from "./corporate_site_readiness.ts";

const profile = {
  companyName: "株式会社テストラボ",
  representativeName: "山田 太郎",
  registeredAddress: "東京都千代田区丸の内1-1-1",
  businessPlanSummary:
    "中小企業向けのWebサイト制作サービスを月額5万円で提供します。",
  virtualOffice: false,
};

Deno.test("corporate site review finds exact company profile and concrete business details", () => {
  const result = reviewCorporateSiteDocument(
    `# 株式会社テストラボ

## 事業内容
中小企業向けWebサイト制作を月額50,000円で提供します。

## 会社概要
代表取締役 山田太郎
本店所在地 東京都千代田区丸の内1丁目1番1号`,
    profile,
  );

  assertEquals(result.readyForDocumentReview, true);
  assertEquals(result.score, 100);
  assertEquals(result.missingRequiredItems, []);
  assertEquals(result.checks.at(-1)?.status, "manual_review");
});

Deno.test("corporate site review reports required missing fields conservatively", () => {
  const result = reviewCorporateSiteDocument(
    "# 株式会社テストラボ\n\n事業については準備中です。公開までお待ちください。",
    { ...profile, virtualOffice: true },
  );

  assertEquals(result.readyForDocumentReview, false);
  assertEquals(result.score, 25);
  assertEquals(result.missingRequiredItems, [
    "representative_name",
    "registered_address",
    "business_details",
  ]);
  assertEquals(
    result.manualReviewItems.includes("virtual_office_evidence"),
    true,
  );
  assertStringIncludes(result.disclaimer, "審査通過を保証しません");
});

Deno.test("generated corporate HTML escapes inputs and includes WBS milestones", () => {
  const html = generateCorporateSiteHtml({
    ...profile,
    companyName: "<script>alert(1)</script>株式会社",
    contact: "hello@example.com",
    wbsMilestones: ["商品β版を公開", "初回顧客へ納品"],
  });

  assertStringIncludes(html, "&lt;script&gt;alert(1)&lt;/script&gt;株式会社");
  assertEquals(html.includes("<script>"), false);
  assertStringIncludes(html, "商品β版を公開");
  assertStringIncludes(html, "代表取締役 山田 太郎");
  assertStringIncludes(html, "@media (max-width: 600px)");
});

Deno.test("corporate site inputs enforce required values and bounds", () => {
  assertThrows(() => reviewCorporateSiteDocument("", profile));
  assertThrows(() =>
    generateCorporateSiteHtml({
      ...profile,
      contact: "hello@example.com",
      wbsMilestones: [],
    })
  );
  assertThrows(() =>
    generateCorporateSiteHtml({
      ...profile,
      contact: "hello@example.com",
      wbsMilestones: ["x".repeat(301)],
    })
  );
});
