---
date: 2026-04-20
from: PS版#4 (競合モニタリング)
to: VSCode版 (LP / comparison_page.dart)
status: done
completed_by: VSCode版 2026-04-24 (commit 8112a607)
priority: HIGH
deadline: 2026-05-01
---

# Slack × Salesforce Agentforce 完全 AI 化対応 — LP 差別化更新依頼

## 背景

Salesforce が 2026-03-31 に Slackbot の完全 AI エージェント化を発表。2026-04 から Business+/Enterprise+ で運用開始。30+ 新機能追加。**Anthropic Claude 採用 (自分株式会社と同じ)** + **MCP client 化** で Agentforce / Google Workspace / Microsoft 365 / Notion / Workday + 6,000+ アプリと連携。

## 技術的な共通点と差別化ポイント

| 項目 | Slackbot (Agentforce) | 自分株式会社 |
|------|----------------------|--------------|
| AI モデル | Anthropic Claude | Anthropic Claude + Gemini + OpenAI + ... (ai-hub routing) |
| アーキテクチャ | MCP client | ai-hub hub-action routing (~= MCP 相当) |
| Reusable Skills | ✅ 名前付きワークフロー保存 | schedule-hub action / tools-hub action (同発想) |
| 対象ユーザー | **組織・企業** (Business+ $15/seat/月〜) | **個人 CEO** (無料) |
| フォーカス | **仕事のみ** (CRM/営業/Slack 内) | **人生 6 部署** (R&D/財務/マーケ/人事/本社/健康) |
| UI | Slack 内完結 | Flutter Web 独立ダッシュボード |
| 言語 | 英語中心 | 日本語 first |

## 依頼内容

### 1. comparison_page.dart の Slack 比較行を更新

現状: 「Slack = チーム communication」レベルの比較

**更新後フォーマット**:

```dart
{
  'competitor': 'Slack (Salesforce Agentforce 搭載)',
  'monthlyPrice': '\$15/seat〜 (Business+)',
  'target': '企業・組織',
  'strength': '6,000+ アプリ MCP 連携 + reusable AI skills',
  'limitation': '個人利用不可・仕事のみ・英語中心',
  'jibunAdvantage': '個人 CEO 向け無料・人生 6 部署統合・日本語 first',
}
```

### 2. landing_page.dart に Slack/Slackbot 差別化セクション追加

以下のメッセージを LP 末尾 (もしくは「14 の競合 SaaS を超える」セクション直後) に追加:

```markdown
## Slack Agentforce との違い

Slack Agentforce は **企業の仕事を AI 化** するツール。
自分株式会社は **個人の人生を AI CEO 化** するツール。

| 軸 | Slack Agentforce | 自分株式会社 |
|---|------------------|--------------|
| 対象 | チーム・企業 | 個人 |
| 範囲 | 仕事のコミュニケーション | 仕事 + 健康 + 財務 + 学習 + 家族 + 習慣 |
| 価格 | $15/seat〜 | 無料 |
| 言語 | 英語メイン | 日本語 first |
```

### 3. AI モデル採用の一貫性を強調

Slack Agentforce と同じ Anthropic Claude を採用しているが、**自分株式会社は multi-provider (ai-hub)** で更に柔軟。この点を Rule 19 (UI改善) ツールチェーンで強調。

---

## 検証項目 (VSCode版が完了時に報告)

- [ ] `lib/pages/comparison_page.dart` に Slack 比較行更新
- [ ] `lib/pages/landing_page.dart` に差別化セクション追加
- [ ] `flutter analyze` 0 エラー
- [ ] 本番デプロイ後 `https://my-web-app-b67f4.web.app/#/comparison` で確認

## 参考

- TechCrunch: https://techcrunch.com/2026/03/31/salesforce-announces-an-ai-heavy-makeover-for-slack-with-30-new-features/
- Salesforce Investor Release: https://investor.salesforce.com/news/news-details/2026/Salesforce-Announces-the-General-Availability-of-Slackbot--Your-Personal-Agent-for-Work/default.aspx

---

## 重要度

🔴 **HIGH** — Slack は競合 21 社のコア。Agentforce で「仕事 AI」が commodity 化する前に、個人向け差別化を明確にしないと LP メッセージが陳腐化する。

生成: PS版#4 | 2026-04-20
