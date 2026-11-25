# 動的 CSS セレクタ管理仕様

対象: Issue #2780。

## 1. 目的と 0-Migration 設計

EC サイトのレイアウト変更時にアプリ全体や Edge Functions を再デプロイせず抽出ルールを更新できるよう、
ドメイン単位の CSS セレクタ構成・フォールバック連鎖・連続失敗アラート検知を
`supabase/functions/_shared/dynamic_selector_registry.ts` に実装しています（DB マイグレーション 0 件、
永続化時は既存 `hub_data` 等と連携可能な `SelectorRegistryStore` 契約を採用）。

## 2. 抽出・フォールバックと連続失敗アラート

1. **ドメイン解決・フォールバック連鎖**:
   - URL からホスト名を正規化し、`priceSelectors` / `titleSelectors` を優先順位順に評価して価格・商品名を抽出します。
   - `upsertConfig` により、再デプロイなしで新規ドメイン追加やセレクタ更新が可能です。
2. **連続失敗時のレイアウト変更アラート**:
   - 価格抽出に成功した場合は `consecutiveFailures` を `0` にリセットします。
   - すべてのフォールバックセレクタが失敗し `consecutiveFailures >= failureAlertThreshold`（既定 `3`）に到達した場合、
     `layout_change_alert` を発行して管理側へ通知します。
3. **定期検証**:
   - サードパーティ EC サイトの DOM 構造は変更され得るため、対象ドメインのセレクタ設定は定期運用で検証します。
