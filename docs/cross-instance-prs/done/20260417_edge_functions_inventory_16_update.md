# Cross-Instance PR: EDGE_FUNCTIONS_INVENTORY.md を 15本 → 16本 に更新

**作成**: 2026-04-17 PS版#94並列 (objective-cannon worktree)
**担当インスタンス**: Windowsアプリ版 (docs/ 担当)
**優先度**: 🟢 低 (情報鮮度維持)

## 概要

`docs/technical/EDGE_FUNCTIONS_INVENTORY.md` の概要統計で「デプロイ済み関数数: 15本」と記載されているが、現在は 16本 (11 hubs + 5 standalone)。CLAUDE.md Rule 7 と `deploy-prod.yml` は 16本を記載済み。INVENTORY.md だけ 15本のまま。

## 差分

| 項目 | 現状 | 修正後 |
| --- | --- | --- |
| デプロイ済み関数数 | 15本 | 16本 |
| standalone | 4本 (get-home-dashboard / ai-assistant / growth-weekly-digest / guitar-recording-studio) | 5本 (＋ local-election-intelligence) |
| 日付 | 2026-04-12 時点 | 2026-04-17 時点 |

## 修正パッチ (目安)

```diff
-## 概要統計 (2026-04-12 時点)
+## 概要統計 (2026-04-17 時点)

-- **デプロイ済み関数数**: **15本** (ハードキャップ50本以下 / Tier1/Tier2分類は廃止済み)
-  - standalone 4本: get-home-dashboard / ai-assistant / growth-weekly-digest / guitar-recording-studio
+- **デプロイ済み関数数**: **16本** (ハードキャップ50本以下 / Tier1/Tier2分類は廃止済み)
+  - standalone 5本: get-home-dashboard / ai-assistant / growth-weekly-digest / guitar-recording-studio / local-election-intelligence
   - macro-hub 6本: core-hub / growth-hub / ai-hub / admin-hub / app-hub / schedule-hub
   - mega-hub 5本: tools-hub / media-hub / enterprise-hub / social-commerce-hub / lifestyle-hub
```

## 依頼理由

- PS版は `.github/workflows/` 専任のため `docs/` 書き込み不可 (MULTI_INSTANCE_COORDINATION.md 参照)
- 1行パッチなので Windowsアプリ版セッション冒頭で即処理可能

## 完了時

この PR ファイルを `done/20260417_edge_functions_inventory_16_update.md` にリネーム。
