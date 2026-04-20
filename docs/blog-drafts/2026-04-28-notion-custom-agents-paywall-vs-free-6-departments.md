---
title: "Notion Custom Agents 5/4 から $10/1000 credit 課金 — 無料で 6 部署を全部回す方法"
tags: Notion,AI,個人開発,buildinpublic,SaaS
published: false
---

# Notion Custom Agents 5/4 から $10/1000 credit 課金 — 無料で 6 部署を全部回す方法

## 何が起きるか

**2026-05-04** から、Notion Custom Agents (Business/Enterprise add-on) が **$10 / 1000 credit** の従量課金に移行する。
2026-05-03 までは全 Business/Enterprise 顧客に無料試用で開放されていた機能だ。

Source:
- <https://www.notion.com/help/custom-agent-pricing>
- <https://www.notion.com/releases/2026-04-14>

credit は **1 回の AI 実行で数〜数十消費される**ため、1000 credit は数十〜 100 回程度の実行量に相当する。
個人で Custom Agents をヘビーに使っていた人ほど、課金モードに切り替わった直後の **credit 残高ウォッチ** が始まることになる。

## credit 残高ウォッチ = 時間資本の浪費

自分株式会社 (Jibun Inc.) では「**資本 = 時間**」という原則で設計している。

AI ツールを使うたびに「あと何 credit 残ってる?」と気にする瞬間、**その確認行為そのもの**が時間資本を消費する。
課金ラインが近づけば「もう 1 回使うか、節約するか」で躊躇する時間が発生する。
**1 回 5 秒 × 1 日 20 回 = 100 秒/日 = 年 10 時間の「残高チェック労働」** が発生する。

これは Notion を否定する話ではない。Notion Custom Agents は企業データの RAG 統合で他の追随を許さない強みを持つ。
ただ個人利用で毎日ライフログを回すユースケースでは、**予測可能な無料** の方が時間保全になる。

## 自分株式会社の 6 部署統合モデル

自分株式会社は「1 人株式会社」をそのまま Flutter Web + Supabase に写像した個人ツール。
以下の **6 部署** を無料で統合している:

| 部署 | 扱う範囲 |
|---|---|
| **R&D** | 学習ログ / AI 大学 133 プロバイダー |
| **財務** | 家計 KPI / 支出カテゴリ |
| **マーケ** | 個人発信 / SNS 投稿履歴 / 反応 |
| **人事** | 健康ログ / 睡眠 / 運動 / ムード |
| **本社** | ミッション / 9 原則 / 意思決定ログ |
| **健康** | 体調 / 予防 / 医療メモ |

Notion Custom Agents が主に扱う「ノート / Wiki / タスク / カレンダー」は概ね **本社 + R&D + マーケ** に対応する。
その一方で **人事・健康** (自分自身の体調管理) と **財務** (個人家計) は Notion の主戦場ではない。
ここが「仕事業務中心の Notion」と「人生全体を扱う自分株式会社」の住み分けになる。

## 技術スタック (予測可能な無料を実現している仕組み)

- **Flutter Web (Dart)**: 同じ画面を iPhone Safari / Android Chrome / PC で出せる
- **Supabase**: PostgreSQL + Edge Function (Deno) + Auth + Storage が一式無料枠
- **Edge Function 16 hub 構成**: core / growth / ai / admin / app / schedule / tools / media / enterprise / social-commerce / lifestyle + standalone 5
- **AI ルーティング**: ai-hub で 130 超プロバイダーを統合、無料枠を組み合わせて課金回避
- **Firebase Hosting**: 静的配信の無料枠で本番運用

「無料」と言っても、Supabase / Firebase / Flutter / dev.to / Qiita すべてが **オープンで SLA のある** サービスで、
野良の無料サーバーではない。「credit 残高を気にせず使える」安心感 = 予測可能性が設計の核心。

## 対比の 4 軸

| 軸 | Notion Custom Agents | 自分株式会社 |
|---|---|---|
| 価格 | $10 / 1000 credit 従量 | 無料 |
| スコープ | ノート / Wiki / タスク / カレンダー | **6 部署** (R&D / 財務 / マーケ / 人事 / 本社 / 健康) |
| 日本語 UX | 英語主 + 翻訳 | **日本語ネイティブ** |
| データ永続化 | Notion クラウド (有料依存) | **Supabase (個人 PostgreSQL)** |

## 併用パターンの提案

この記事の主張は「Notion を置き換えろ」ではない。**適切に分担する方が両者の強みが出る**:

- **Notion = 仕事ノート / Wiki / 企業データ統合**
- **自分株式会社 = 健康 / 家計 / 日次 KPI (=昨日の自分 比較)**

仕事用の credit を節約しつつ、個人の 6 部署は無料で回す。これが時間資本の保全になる。

## 試してみる

- 本番: <https://my-web-app-b67f4.web.app/>
- LP: <https://my-web-app-b67f4.web.app/>
- 21 競合比較: <https://my-web-app-b67f4.web.app/comparison>

Notion Custom Agents 課金切替は **5/4** から。切替前に「個人 6 部署は無料で分散」という選択肢を知っておくと、
課金モード突入後の「credit 残高ウォッチ症候群」を回避できる。
