---
title: Self-Hosted OSS AI Observability PoC & Cost Comparison
last_reviewed: 2026-11-26
review_cycle_days: 90
related_issue: 2813
---

# セルフホスト型 AI 監視インフラ（OSS）技術検証 PoC (#2813)

## 1. 一次情報確認と検証スコープ

| 対象 | 一次 URL / 環境 | 確認結果 |
|---|---|---|
| OpenTelemetry OTLP 仕様 | `https://opentelemetry.io/docs/specs/otlp/` | `200 OK` (`OTLP Specification 1.11.1 | OpenTelemetry`)。HTTP JSON (`resourceSpans`) 送信契約に準拠 |
| Langfuse Self-Host | `https://langfuse.com/docs/deployment/self-host` | `200 OK` (`Self-host Langfuse (Open Source LLM Observability) - Langfuse`) |
| TraceHawk / Datadog 価格主張 | NotebookLM 抽出メモ | **未確認**（一次ベンダー契約・最新公式価格表の直接取得は未実施） |
| Docker コンテナ実機デプロイ | ステージング / ローカル Docker | **未確認** (`not-run`: 本 PoC では Edge OTLP 送信ヘルパーとコスト試算スクリプトまでを実装) |

## 2. 構成比較（OSS セルフホスト vs 商用 SaaS vs 現行 Supabase）

| 項目 | OSS セルフホスト (OTLP + Langfuse 等) | 商用 SaaS (Datadog 等) | 現行 `my_web_app` (`app_analytics`) |
|---|---|---|---|
| **データ主権** | 自社インフラ内で完結可能 | 外部 SaaS 側へ送信 | Supabase PostgreSQL (RLS) 内に保持 |
| **トレース送信標準** | OpenTelemetry OTLP/HTTP (`_shared/oss_trace_emitter.ts`) | 専用エージェント / OTLP | Edge Function 経由の構造化ログ |
| **課金モデル** | 固定コンピュート＋ストレージ実費 | 従量課金・シート課金（具体見積は **未確認**） | Supabase Free / Pro 枠内 |

## 3. Fail-Open OTLP PoC 設計

- `supabase/functions/_shared/oss_trace_emitter.ts` は `OTLP_TRACES_ENDPOINT` 未設定時に `skipped_unconfigured` を返し、通信障害やタイムアウト時も本処理（AI 応答）をブロックしない Fail-Open 設計とする。
- DB マイグレーションは `0` 件。
