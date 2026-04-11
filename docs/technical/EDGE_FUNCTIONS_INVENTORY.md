# Supabase Edge Functions 一覧

**最終更新**: 2026-04-12  
**ステータス**: ✅ 全 Edge Functions に UI 実装済み (2026-04-05 VSCode#3 にてゼロ達成)

> ⚠️ **注意**: このドキュメントは概要のみ記録するスナップショットです。  
> 関数の詳細は常にアプリ内 `/edge-functions` ページで確認してください。

---

## ソース・オブ・トゥルース

Edge Functions の一覧・UI 接続状況・操作手順は以下で確認:

| 参照先 | 場所 | 説明 |
| --- | --- | --- |
| **ホーム画面カード** | `/home` → 「Edge Functions 実装状況」カード | 全関数の UI 有無・操作手順 |
| **詳細ステータスページ** | `/edge-functions` | 全関数のテスト・カバレッジ確認 |
| **ウィジェット実装** | `lib/widgets/edge_function_summary_card.dart` | 関数定義リスト (静的) |
| **ステータスページ実装** | `lib/pages/edge_function_status_page.dart` | 詳細 UI (動的テスト機能付き) |

---

## 概要統計 (2026-04-10 時点)

- **合計関数数**: 250 件 (Tier1: 99本デプロイ済 / Tier2: 151本コードのみ)
- **UI カバレッジ**: **100%** (UI 実装が必要なものはすべて対応済み)

---

## 自動チェック

`cs-check` Schedule タスク (毎時実行) の Step 0 が:

1. `supabase/functions/` の全関数をスキャン
2. `lib/` の invoke 呼び出しとの照合
3. UI 未連携の関数を自動検出
4. 最大3件まで自動実装してコミット・プッシュ

手動確認は `/edge-functions` ページから実施可能。
