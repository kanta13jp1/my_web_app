import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  featureRequestCandidateKey,
  matchExistingFeatureRequestIssues,
  normalizeFeatureRequestIssueTitle,
} from "./feature_request_dedupe.ts";

Deno.test("feature request title normalization removes GitHub and asset prefixes", () => {
  assertEquals(
    normalizeFeatureRequestIssueTitle(
      "[追加要望] [資産管理] 実支払額と推定額の差分管理",
    ),
    normalizeFeatureRequestIssueTitle("実支払額と推定額の差分管理"),
  );
});

Deno.test("feature request issue matching maps candidate keys to existing issues", () => {
  const key = featureRequestCandidateKey(
    "支払原資口座の未設定レビュー",
    "未設定項目を一括で確認できるようにする",
    "asset_management_developer_request",
  );
  const matches = matchExistingFeatureRequestIssues(
    [{ key, title: "支払原資口座の未設定レビュー" }],
    [
      {
        number: 2939,
        title: "[追加要望] [資産管理] 支払原資口座の未設定レビュー",
        html_url: "https://example.test/issues/2939",
        state: "open",
      },
    ],
    "github_title",
  );

  assertEquals(matches, [{
    key,
    number: 2939,
    title: "[追加要望] [資産管理] 支払原資口座の未設定レビュー",
    html_url: "https://example.test/issues/2939",
    state: "open",
    matched_by: "github_title",
  }]);
});
