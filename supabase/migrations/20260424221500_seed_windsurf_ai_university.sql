-- Session Win#132 part 2: AI大学 150 社化 — Windsurf (旧 Codeium) 追加
-- vibe-coding クラスタ完結: Cursor (Anysphere) と並ぶ IDE agent の主要二強。
-- Windsurf = Codeium のリブランディングで「Cascade」(agent mode) + Supercomplete
-- (predictive edit) が主軸。エンタープライズ向け契約と SOC 2 / SAML SSO 対応が特徴。

INSERT INTO ai_university_content (provider, category, title, content, updated_at)
VALUES
  (
    'windsurf',
    'overview',
    'Windsurf — Cascade agent + Supercomplete 搭載 AI IDE',
    $md$
# Windsurf — Cascade agent + Supercomplete 搭載 AI IDE

2024 年 Codeium から リブランディングして生まれた AI-native IDE。
VS Code fork に Cascade agent (自律 multi-file edit) + Supercomplete (predictive edit)
を統合。エンタープライズ契約 + SOC 2 + SAML SSO の 3 点が Cursor との差別化軸。

## 既存 149 社との差別化

| 観点 | Windsurf | Cursor | Cline (OSS) | Continue.dev |
|------|----------|--------|-------------|--------------|
| 価格 | Free + Pro $15/月 | Free + Pro $20/月 | BYOK (OSS) | BYOK (OSS) |
| Agent | **Cascade** (自律 multi-file) | Composer (対話型) | Plan/Act | Chat/Edit |
| Autocomplete | **Supercomplete** (predictive) | Tab Completion | ❌ | ❌ |
| Enterprise | **SOC 2 + SAML SSO 強み** | 追加課金 | 個人のみ | 個人のみ |
| モデル | 自社 + Claude + GPT-4o | Claude + GPT-4o | 自由 | 自由 |

## Cascade agent の特徴 (2025 launch)

- **自律 multi-file edit**: 指示 1 回で repo 横断変更 (refactor / 大規模機能追加)
- **Flow state**: ユーザーの操作を agent がリアルタイム把握・先読み
- **Undo history**: 各 step snapshot → 自然言語 rollback 可
- **Terminal integration**: コマンド実行 + 出力 parse → 次 step 自動起案

## Supercomplete (autocomplete 進化)

- ファイル横断の文脈を把握した predictive edit
- 次にユーザーが書きそうな「diff」を先回り提案 (複数行 / Tab で accept)
- Cursor Tab と並ぶ IDE agent 2 大 autocomplete

## 業績 (推定 / 2026-04)

- Codeium 時代から 100万+ 個人開発者 + 1000+ 法人顧客
- Fortune 500 企業 (Dell / Atlassian / Zoom 等) 採用事例
- Pro 月額 $15 / Enterprise 要相談 (per seat + usage)

## 自分株式会社での活用

- **Cursor との routing**: 大規模 refactor = Cursor Composer / agent 自律タスク = Cascade
- **Enterprise 向け解説コンテンツ**: SOC 2 + SSO 必須企業向けの AI IDE として AI大学で推薦
- **競合 watchlist**: PS#4 S31 vibe-coding 🟠 に追補 (Cursor + Windsurf + Cognition 三強)

## 関連リンク

- 公式: <https://windsurf.com/>
- Cascade 紹介: <https://windsurf.com/cascade>
- Supercomplete: <https://windsurf.com/editor>
$md$,
    NOW()
  ),
  (
    'windsurf',
    'models',
    'Windsurf モデル構成 — 自社 + 外部 LLM 併用',
    $md$
# Windsurf モデル構成

Windsurf は自社モデル (旧 Codeium 由来) + 外部 LLM の hybrid 構成。

## 主要モデル (2026-04 時点)

| 用途 | 採用モデル | 理由 |
|------|-----------|------|
| Autocomplete (Supercomplete) | **自社 fine-tune** | latency 優先 + code-specific |
| Agent (Cascade) 複雑タスク | **Claude Sonnet 4.5** | 長 context + planning |
| Agent (Cascade) 軽量タスク | GPT-4o | cost 最適化 |
| Chat (Q&A) | 選択可 (Claude / GPT / Gemini) | ユーザー設定 |
| リファクタ提案 | Claude Opus 4 | reasoning 優先 |

## Enterprise 向け差別化

- **Self-hosted option**: VPC 内 deploy で企業コードを外部送信しないモード
- **Audit log**: 全 agent action を内部監査用に記録
- **Role-based access**: SAML SSO + IAM 連携
- **Compliance**: SOC 2 Type II + HIPAA 対応 (2026-Q1)
$md$,
    NOW()
  ),
  (
    'windsurf',
    'use_cases',
    '自分株式会社での活用パターン',
    $md$
# 自分株式会社での活用パターン

## 1. 大規模 refactor での Cascade 活用

`lib/pages/*` 全体の DESIGN token 適用等、repo 横断の refactor タスク:
- **Cursor Composer**: 対話的に 1 file ずつ確認しながら修正
- **Windsurf Cascade**: 1 指示で全 file を agent が自律修正 → review

## 2. Enterprise 向け競合観察

Notion / Slack 等 法人 SaaS と連携した顧客体験記事を書く際、
Windsurf が SOC 2 + SAML SSO を前面に出している構造は参考になる。
- 「自分株式会社 Enterprise Plan」(仮) の compliance KPI 設計時 referent

## 3. AI大学 vibe-coding カテゴリの IDE 三強対比

docs/competitor-reports/vibe_coding_compare_YYYYQQ.md に以下 comparison 蓄積:
- Cursor (consumer $20/月) / Windsurf (enterprise $15+) / Cline (OSS BYOK)
- 四半期ごとに Agent quality / latency / compliance を review
$md$,
    NOW()
  )
ON CONFLICT (provider, category) DO UPDATE
SET title = EXCLUDED.title,
    content = EXCLUDED.content,
    updated_at = EXCLUDED.updated_at;
