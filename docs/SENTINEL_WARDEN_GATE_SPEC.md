# Sentinel & Warden 出力品質監視ゲート仕様書 (#2783)

## 1. 目的

自律的に動作する AI エージェントの出力が、事実確認やフォーマット検証を経ずに直接ユーザーへ公開されたり DB へ保存されたりすると、ハルシネーション・個人情報漏洩・レイアウト崩れによる品質低下を招く。
本仕様では、公開（`published`）前に **Sentinel（第1段階）** と **Warden（第2段階）** の二段階品質ゲートを配置し、ブロックされた出力を破棄（`discarded`）または修正キュー（`revision_queue`）へ隔離する仕組みを定義する。

## 2. 二段階パイプライン

```text
[AI Output Candidate]
        │
        ▼
[Stage 1: Sentinel] ──(PII/秘密情報・重大欠陥)──▶ [discarded]
        │             ──(スキーマ欠損・要検証表現)──▶ [revision_queue]
        │ (PASS)
        ▼
[Stage 2: Warden]   ──(構文崩れ・プレースホルダ残存)──▶ [revision_queue]
        │
        │ (PASS)
        ▼
   [published] (publishable = true)
```

### 各ステージの責務
- **Sentinel**:
  1. 空出力・最小文字数チェック
  2. 必須構造化フィールド（`requiredKeys`）のスキーマ検証
  3. PII（メールアドレス・電話番号）および秘密情報パターン検出
  4. ハルシネーション / 未確定プレースホルダ（`TODO`, `FIXME`, `[citation needed]` 等）検出
- **Warden**:
  1. Markdown コードフェンスの開閉整合性
  2. テンプレート変数（`{{...}}` 等）の未展開残存チェック
  3. 最終品質スコア（`qualityScore >= 0.7`）の判定

## 3. フロントエンド連携と運用

- `SentinelWardenGateService` は `evaluateOutput()` による即時ゲート判定と、`listRevisionQueue()` / `resolveRevisionItem()` による修正キューの可視化・再承認を提供する。
- DB スキーマ変更は行わない（`0` DB migrations）。
