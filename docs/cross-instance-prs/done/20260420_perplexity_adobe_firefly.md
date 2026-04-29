---
date: 2026-04-20
from: PS版#4 (競合モニタリング)
to: VSCode版 (LP / landing_page.dart 差別化コピー)
status: done
completed_by: VSCode版 2026-04-24 (commit 8112a607)
priority: MEDIUM
---

# 新規脅威: Perplexity Mac Agent + Adobe Firefly Workflows — LP 差別化対応

## 新規競合 2社の概要

### Perplexity Mac Agent (2026-04-20 リリース)

- **機能**: macOS デスクトップエージェント。日常タスクをチャット指示だけで自律実行
- **強み**: 「messy work」 — ブラウザ・アプリ横断操作、メール返信、カレンダー管理
- **自分株式会社との競合箇所**: `daily-judgment` EF (毎日の優先事項決定) / `schedule-hub` (予定管理)
- **差別化ポイント**: Perplexity は「何でも」エージェント。自分株式会社は「CEO としての自分」フレームワーク
  - Perplexity: 「タスクを代行する」
  - 自分株式会社: 「ユーザーが最終決定権を持つ (原則1: CEO感)」

### Adobe Firefly Multi-Step Workflows (2026-04-20 GA)

- **機能**: 自然言語で複数アプリ (Photoshop/Premiere/Illustrator) を横断実行
- **強み**: クリエイター向け多ステップ自動化
- **自分株式会社との競合箇所**: `schedule-hub` (タスク自動化) / 将来的な `media-hub`
- **差別化ポイント**: Adobe はクリエイター特化。自分株式会社は 6部署 (財務・健康・人事等) の統合管理
  - Adobe: 「クリエイティブワークの自動化」
  - 自分株式会社: 「人生のバランスシート管理」

---

## VSCode版への依頼

### LP 更新箇所 (`lib/pages/landing_page.dart`)

**1. 「なぜ競合とは違うか」セクションに以下を追加**:

```
Perplexity Mac Agent や Adobe Firefly は強力な自動化ツールですが、
「何をするか」はあなたが指示し続ける必要があります。

自分株式会社は違います。
CEOとしての「判断基準」を持ち、毎日の優先事項を自分で決める
— AI はその判断をサポートするメンターです。
```

**2. 差別化テーブル更新** (競合比較行):

| 比較軸 | Perplexity Mac Agent | Adobe Firefly | 自分株式会社 |
|--------|---------------------|---------------|------------|
| ゴール | タスク代行 | クリエイティブ自動化 | CEO としての自己成長 |
| 対象 | デスクトップ操作 | クリエイティブアプリ | 人生 6 部署の統合管理 |
| KPI | 処理速度 | 制作時間削減 | 昨日の自分より成長 |
| 哲学 | AI が代わりに動く | AI が仕事を自動化 | ユーザーが最終決定権 (CEO感) |

**3. 「担当インスタンス」**: VSCode版 (LP 更新専任)

---

## 優先度の根拠

Perplexity Mac Agent は `daily-judgment` の直接代替として認知される可能性がある。
「毎日の優先事項を AI に決めてもらう」訴求では差別化困難。
「CEOとして自分が決める、AIはメンター」という哲学的差別化を LP に明示することで
機能比較ではなく理念差別化に持ち込む。
