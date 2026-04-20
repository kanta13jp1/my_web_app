---
title: "Notion Custom Agents 本日課金開始 — 無料で人生 6 部署を回すオルタナティブ"
tags: Notion,AI,個人開発,buildinpublic,SaaS
published: false
---

# Notion Custom Agents 本日課金開始 — 無料で人生 6 部署を回すオルタナティブ

## 本日 5/4 から

**2026-05-04 00:00 UTC** (日本時間 09:00) から、Notion Custom Agents (Business/Enterprise add-on) が **$10 / 1000 credit** の従量課金に切り替わる。
2026-05-03 までの無料試用は本日で終了。

2 社交差検証 (公式 45-90 runs/1000 credits + 独立分析 30-60) で conservative 採用 = 1 回 **$0.11-$0.33 (約 17-50 円)**。
1 日 10 回なら月 **$33-$99 (5,000-15,000 円)**。しかも credits は **月次リセット = 使わなくても消える**。

Source:
- <https://www.notion.com/help/custom-agent-pricing>
- <https://www.notion.com/releases/2026-04-14>

2 本の予告記事を書いてきた:

- 本A (D-6): [Notion Custom Agents 5/4 から $10/1000 credit 課金 — 無料で 6 部署を全部回す方法](https://my-web-app-b67f4.web.app/)
- 本B (D-2): [Notion 課金まであと 2 日 — 切替前に個人 AI 管理を無料 6 部署に分散しておこう](https://my-web-app-b67f4.web.app/)

この D-0 記事は **2 択** の提示で締める。

## 2 つの選択肢

### 選択肢 A: 代替 (Notion を抜けて自分株式会社だけで回す)

Notion Custom Agents の credit 課金を **避ける** 道。
自分株式会社 (Flutter Web + Supabase) だけで 6 部署を無料運用する。

**向く人**:
- 個人開発者 / フリーランス
- 仕事ノートも個人ログも規模が小さい
- 従量課金の認知コストを嫌う
- 英語 UI より日本語ネイティブ UX を重視

**得られるもの**:
- credit 残高ウォッチ ゼロ
- 6 部署 (R&D / 財務 / マーケ / 人事 / 本社 / 健康) 統合
- Supabase 永続化 (自分の PostgreSQL)
- ai-hub routing で Claude + OpenAI + Gemini + fallback 束ね

### 選択肢 B: 併用 (Notion = 仕事中心 / 自分株式会社 = 個人・健康・家計)

Notion を **仕事専用** に絞り、credit 課金を意味ある支出として受け入れる。
個人側 (健康・家計・日次 KPI) は自分株式会社に分担。

**向く人**:
- 企業所属 / 組織で Notion Custom Agents を使い続けたい
- 仕事データと個人データを **意識的に分離** したい
- チーム RAG 機能 (Notion の強み) を活用中

**得られるもの**:
- 仕事用 credit を節約 (個人ログで摩耗しない)
- 「Notion で会議 → 自分株式会社で帰宅後の健康ログ」の役割分担
- Notion の全面依存から単一 vendor 負債を軽減

どちらも合理解。選択の軸は「個人 CEO として BS のどちら側を厚くしたいか」。

## 6 部署サマリ画面 (自分株式会社側)

自分株式会社のダッシュボードを 1 画面で見ると:

```text
┌─────────────────────────────────────────────────┐
│  🏢 自分株式会社 — 6 部署 本日のサマリ           │
├─────────────────────────────────────────────────┤
│  🔬 R&D          | AI 大学 133 社 / 今日 +2 学習│
│  💰 財務          | 昨日比 -¥1,200 / 月次 -3.2% │
│  📢 マーケ        | 投稿 2 / 反応 +14           │
│  🧑 人事          | 睡眠 7.2h / ムード 7/10     │
│  🏛️ 本社          | 9 原則 / 意思決定 1 件       │
│  ❤️ 健康          | 運動 30min / 体調 good       │
└─────────────────────────────────────────────────┘
```

全部 **無料** で回る。credit 残高を見る必要はなく、KPI=昨日の自分との比較だけ見る。

## Notion 側 (選択肢 B を選ぶ場合)

Notion Custom Agents を引き続き使う場合、**個人 credit 消費を最小化** する設定を推奨:

1. 個人ノートの Custom Agents 連携を外す (Agent が走らないページに移動)
2. 日次ルーチン (健康ログ / 家計) は自分株式会社に移行
3. Custom Agents は **仕事プロジェクト限定** で使う
4. 月次 credit レビューを自分株式会社の財務部署に記録

→ **「仕事で credit 使う / 個人で自分株式会社使う」の線引き** を明確化。

## 技術スタック確認

自分株式会社の無料運用の裏側:

- **Flutter Web (Dart)**: 1 codebase で iPhone Safari / Android Chrome / PC 対応
- **Supabase**: PostgreSQL + Edge Function (Deno) + Auth + Storage 一式無料枠
- **16 Edge Function hub**: core / growth / ai / admin / app / schedule / tools / media / enterprise / social-commerce / lifestyle + standalone 5
- **ai-hub**: 130 超 AI プロバイダー統合 (Claude + OpenAI + Gemini + fallback)
- **Firebase Hosting**: 静的配信の無料枠で本番運用

「無料」と言っても Supabase / Firebase / Flutter は **オープンで SLA のある** サービス。credit 残高ウォッチしないで済む **予測可能性** が設計の核心。

## 今すぐできる 3 アクション

1. **自分株式会社を開く**: <https://my-web-app-b67f4.web.app/>
2. **6 部署サマリ画面を眺める**: 自分の人生をどう分解できるか体感
3. **選択肢 A/B を決める**: 代替 か 併用 か、自分の BS に合わせて選ぶ

## 試してみる

- 本番: <https://my-web-app-b67f4.web.app/>
- LP: <https://my-web-app-b67f4.web.app/>
- 21 競合比較: <https://my-web-app-b67f4.web.app/comparison>

## これは Notion だけの話ではない (vendor paywall パターン)

6 ソース検証 (公式 + The Register + PYMNTS + Gizmodo + Kingy AI + npifinancial) で、**Anthropic Enterprise も 2025-11 から $20/seat + usage の新構造に移行済**。新構造 3 点:

1. **強制コミット枠**: Anthropic 推定の月次 token 量を pre-pay → **実消費が下回っても請求**
2. **大口割引廃止**: 従来の 10-15% volume discount が消滅
3. **per-token 単価は不変**

Redress Compliance の heavy user 試算では **2-3 倍コスト増**。
Notion も Anthropic も同じ方向 = **vendor 側は metered + commit で課金安定化、ユーザー側は予測不能性を被る**。

自分株式会社は **コミット枠ゼロ・credit ゼロ・完全無料**。vendor 側の「課金改訂ニュース」から構造的に切り離されている。

本日 5/4 から credit 課金モード突入。「代替 か 併用 か」は個人 CEO 自身が決めればいい。**どちらを選んでも、自分株式会社という受け皿があれば時間資本は守れる**。
