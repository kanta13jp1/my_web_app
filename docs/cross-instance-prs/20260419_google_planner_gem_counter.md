---
date: 2026-04-19
from: PS版#4 (競合モニタリング)
to: VSCode版
status: pending
priority: HIGH
---

# Google Productivity Planner Gem 対抗 — LP + ホームページ訴求強化依頼

## 背景・根拠

PS版#4 の 2026-04-19 競合モニタリングで **Google Productivity Planner Gem** が発見されました。
これは Gmail + Calendar + Drive を集約した毎日の業務ブリーフィング機能で、
当社の `daily-judgment` EF と機能重複が最も大きい直接競合です。

**Gemini Notebooks × NotebookLM 同期** も追加されており、Google の個人生産性ハブ化が加速しています。

詳細: `docs/competitor-reports/2026-04-19.md` §18 Google

## 対抗軸

Google Planner Gem との決定的な差:
- Planner Gem: **Google Workspace データのみ** (Gmail/Calendar/Drive)
- 自分株式会社: **財務 + 健康 + 習慣 + 6部署 + 競馬 + AI大学** = 人生全体

この差を LP とホーム画面の **コピー・見出し・比較セクション** で明確に示すことが急務です。

## 依頼内容 (VSCode版 UI/Design 担当)

### Task 1: LP (`lib/pages/landing_page.dart`) 訴求文言強化

競合比較セクション (または Hero セクション) に以下の軸を追加:

```
❌ Google Gemini Planner: メール・カレンダーのみ
✅ 自分株式会社: 財務・健康・習慣・仕事・6部署を一元管理
```

現在の `comparison_page.dart` にある Google 行の説明を更新し、
「Workspace 外のデータ統合」を差別化ポイントとして明記する。

### Task 2: ホーム画面 (`lib/pages/home_page.dart`) 「今日の判断」セクション強調

`daily-judgment` 機能の説明に以下を追加:
- 「財務・健康・仕事・習慣を横断した AI 判断 (Google には真似できない)」
- ウィジェットの subtitle または tooltip で差別化を訴求

### Task 3: DESIGN.md 準拠確認

変更後は必ず:
1. `dart format <files> --set-exit-if-changed`
2. `flutter analyze` 0 エラー確認
3. commit + push

## 優先度の根拠

Google は 2026-04 に Gemini for macOS GA + Notebooks × NotebookLM 同期を展開中。
日本語ユーザーへのリーチも急拡大しており、**早期に差別化訴求を確立することが急務**。
MoneyForward AI Cowork の 7 月 GA よりも先に対処すべき脅威と判断。
