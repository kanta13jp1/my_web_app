# AI Slop・セキュリティ自動コードレビューゲート仕様書 (#2789)

## 1. 背景と目的

高性能 AI によるコード生成・脆弱性解析が普及する一方で、未実装スタブ・過度な `dynamic`/`any`・重複ゴーストファイル・セキュリティ欠陥を含む低品質 PR（AI Slop）が増加している。
本仕様では、既存の `scripts/check_ai_code_antipatterns.py` を基盤として、**決定的静的スキャン＋セキュリティリスク検出＋オプションの LLM 監査** を統合した PR レビューゲートを定義する。

## 2. 判定ロジックと `ai-slop-warning` ラベル運用

| 検出カテゴリ | 例 | 判定 (`decision`) | `ai-slop-warning` ラベル | マージブロック |
|---|---|---|---|---|
| **重大セキュリティリスク** | `eval()` / `new Function()` / 秘密情報ハードコード / `dangerouslySetInnerHTML` | `block` | 付与 (`true`) | ブロック (`true`) |
| **AI Slop 多発** | `check_ai_code_antipatterns` 検出が `2` 件以上 | `block` | 付与 (`true`) | ブロック (`true`) |
| **軽微な AI Slop** | `check_ai_code_antipatterns` 検出が `1` 件 | `warn` | 付与 (`true`) | 非ブロック (`false`) |
| **問題なし** | 検出 `0` 件 | `approve` | 付与なし (`false`) | 非ブロック (`false`) |

## 3. オプション LLM 監査との併用（Fail-Open）

- GitHub Actions / Claude Code Routines で `ANTHROPIC_API_KEY` 等が設定されている場合は、`xhigh` エフォート相当の厳密監査プロンプトを併用できる。
- キー未設定環境やオフライン検証時は `optional_llm_status = "skipped_missing_key"` として安全にスキップし、決定論的ゲート（フォーマット・静的解析・セキュリティ・アンチパターン）を権威ある基準として維持する。
- DB スキーマ変更は行わない（`0` DB migrations）。
