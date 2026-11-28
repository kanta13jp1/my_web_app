# 階層型モデルルーティングと自動エスカレーション仕様 (#2784)

## 1. 概要

コスト・レイテンシ・品質のバランスを最適化するため、タスク難易度に応じて 4 段階のモデル層（`Free` / `Budget` / `Performance` / `Premium`）へ初期ルーティングし、下位層での失敗・タイムアウト・レート制限・低信頼度応答を検知した際に自動で上位層へエスカレーションする仕組みを定義する。

## 2. モデル階層と初期マッピング

| 階層 (`ModelTier`) | 想定用途 | 対応する既定難易度 (`TaskDifficulty`) |
| --- | --- | --- |
| `free` (`Free`) | 単純分類・定型整形 | `trivial` |
| `budget` (`Budget`) | 一般的な要約・抽出・補助生成 | `standard` |
| `performance` (`Performance`) | 複雑な推論・複数制約の統合 | `complex` |
| `premium` (`Premium`) | 最重要判断・最終フォールバック | `critical` |

- リクエスト単位で `minTier` / `maxTier` を指定し、初期層をクランプできる。
- `allowEscalation = false` の場合は初期層のみ試行し、エスカレーションを行わない。

## 3. 自動エスカレーション条件

以下のいずれかに該当した場合、`maxTier`（既定 `premium`）に達するまで直近の次の層へ自動昇格する。

1. `provider_error`: プロバイダ側の実行失敗・不正応答
2. `timeout`: タイムアウト
3. `rate_limited`: レート制限超過
4. `low_confidence`: 応答は成功したが `confidence < minConfidence`（既定 `0.6`）

## 4. テレメトリと継続計測に関する注意

`TieredModelRouter`（Edge Function 共有モジュール）および `TieredModelEscalationService`（Flutter サービス）は以下を記録する。

- `totalRequests` / `succeededRequests` / `escalatedRequests` / `escalationRate`
- 層別（`free` / `budget` / `performance` / `premium`）の開始数・試行数・成功数・失敗数・累積レイテンシ

> **外部要因に関する注記**: 各プロバイダの実際の成功率・レイテンシ・レート制限は外部プロバイダの稼働状況や時間帯負荷などの外部要因に依存するため、固定の数値目標を事前保証せず、運用開始後もエスカレーション率および層別レイテンシを継続的に実測して閾値とマッピングを見直すこと。

## 5. 実装ファイル

- Edge Function 共有モジュール:
  - `supabase/functions/_shared/tiered_model_escalation.ts`
  - `supabase/functions/_shared/tiered_model_escalation_test.ts`
- Flutter サービス・ユニットテスト:
  - `lib/services/tiered_model_escalation_service.dart`
  - `test/services/tiered_model_escalation_service_test.dart`
