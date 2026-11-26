# LLM ツール提案とユーザーエンゲージメント相関モニタリング仕様 (#2794)

## 1. 概要

AI が意味的抽象化を用いて生成した UI アクションボタンが実際のユーザーに利用されているかを定量評価し、低エンゲージメントなツール定義を次回 LLM 呼び出しスキーマから削減するための相関モニタリング基盤を定義する。

## 2. トラッキング仕様

- 必須ペア: `(actionType, generatedLabel, eventKind)`
  - `actionType`: 実際のバックエンド/クライアントアクション種別（例: `invite`）
  - `generatedLabel`: LLM が生成した UI ラベル文字列（例: `Pay $30 Cash`）
  - `eventKind`: `impression`（表示）または `click`（クリック）
- Flutter 側 `LlmToolEngagementService` は任意の非同期 `EngagementEventSink` 経由で既存アナリティクス / Supabase RPC へイベントを送信できる。

## 3. CTR 集計とスキーマ削減判定

- `(actionType, generatedLabel)` ごとに `ctr = clicks / impressions`（`impressions == 0` の場合は `0`）を算出する。
- `impressions >= minImpressions`（既定 `20`）かつ `ctr < minCtrThreshold`（既定 `0.02`）を満たすアクションを `SchemaPruningReport.prunedActionTypes` として抽出し、サンプル不足のアクションを誤って除外しない。

## 4. 実装ファイル

- Edge Function 共有モジュール:
  - `supabase/functions/_shared/llm_tool_engagement.ts`
  - `supabase/functions/_shared/llm_tool_engagement_test.ts`
- Flutter サービス・ユニットテスト:
  - `lib/services/llm_tool_engagement_service.dart`
  - `test/services/llm_tool_engagement_service_test.dart`
