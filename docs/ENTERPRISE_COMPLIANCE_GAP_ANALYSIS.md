---
title: Enterprise Compliance Gap Analysis (SOC2 Type II / HIPAA / PCI DSS)
last_reviewed: 2026-11-26
review_cycle_days: 90
related_issue: 2812
---

# エンタープライズ向けコンプライアンス（SOC2 Type II / HIPAA / PCI DSS）ギャップ分析 (#2812)

## 1. 現状アーキテクチャの統制（リポジトリ実測）

- **クライアント (`pubspec.yaml`)**: `supabase_flutter: 2.14.2`, `posthog_flutter: ^5.53.0`, `crypto: ^3.0.7`
- **バックエンド認証・分離 (`supabase/required_secrets.json`)**: `SUPABASE_ANON_KEY` によるユーザー単位 RLS 検証、`INTERNAL_HMAC_SECRET` による内部サービス間署名検証、`STRIPE_SECRET_KEY` / `STRIPE_WEBHOOK_SECRET` による決済分離
- **AI ルーティング**: `GROQ_API_KEY` / `SILICONFLOW_API_KEY` / `NOVITA_API_KEY` 等のマルチプロバイダ構成

## 2. フレームワーク別ギャップ分析

| 基準 | 現状の充足状況 | 主なギャップ | 推奨是正アクション |
|---|---|---|---|
| **SOC2 Type II** | RLS・HMAC 署名・CI シークレット検査・Sentinel/Warden 品質ゲートを実装済み | 変更管理・アクセス棚卸し・外部監査証跡（ログ長期保全・定期棚卸し手順）の制度化が未整備 | 監査ログ保持ポリシー策定、年次権限レビュー自動化、Supabase SOC 2 レポート取得 |
| **HIPAA** | 転送/保存暗号化基盤は Supabase 側に依存可能 | BAA（Business Associate Agreement）締結、PHI（保護対象保健情報）の外部 AI 送信遮断・ZDR 契約が未完了 | PHI 含むリクエストの外部無料枠 AI 転送禁止ルール化、BAA 対象プラン/プロバイダ選定 |
| **PCI DSS** | カード決済は Stripe Checkout / Webhook (`STRIPE_WEBHOOK_SECRET`) へ委譲し、カード番号を DB 保存しない構成 | SAQ A 自己問診票の定期更新・CSP/SRI 監査・Webhook 署名検証の定期テスト証跡の定常化 | Stripe SAQ A 要件の年次チェックリスト化、決済ページ周辺 CSP 監視強化 |

## 3. プロバイダ別 一次情報確認状況マトリクス

> 一次情報精査ルールに基づき、本環境で直接取得・確認できた事実のみ記載し、JS 描画等で直接読取できなかった項目は **未確認** として区別する。

| プロバイダ / 基盤 | 参照一次 URL（確認結果） | 認証・保持ポリシー確認状況 |
|---|---|---|
| **Supabase** | `https://supabase.com/security` (`200 OK`), `https://supabase.com/docs/guides/security/soc-2-compliance` (`200 OK`) | ページ内で `SOC 2` / `HIPAA` / `BAA` / `ISO 27001` への言及を確認。プラン別 BAA 適用条件・監査報告書本体は **未確認**（組織アカウントで要取得） |
| **OpenAI** | `https://openai.com/security-and-privacy/` (`200 OK`) | ページ内で `SOC 2` / `HIPAA` / `ISO 27001` / `PCI-DSS`（委任決済処理コンポーネント） / `RETENTION` への言及を確認。API 契約別の ZDR 適用条件は **未確認** |
| **Anthropic** | `https://trust.anthropic.com/` (`200 OK`, JS SPA) | 静的 HTML 取得では認証一覧が描画されず **未確認**（Trust Center ブラウザ閲覧および Enterprise BAA/ZDR 条件の個別確認が必要） |
| **Google Cloud / Gemini** | `https://cloud.google.com/security/compliance/offerings` (`200 OK`) | 静的 HTML スライスで対象製品別一覧を取得できず **未確認**（Vertex AI / Gemini API 契約別のデータ保持・BAA 確認が必要） |
| **Groq / SiliconFlow / Novita** | `supabase/required_secrets.json` 登録済み | 無料枠〜標準 API における SOC 2 / HIPAA / ZDR 契約条件は **未確認**（エンタープライズ顧客向けルートからは除外推奨） |

## 4. DB 影響

- 本タスクは調査・ギャップ分析ドキュメントおよび検証スクリプトの追加のみであり、DB マイグレーションは `0` 件とする。
