---
title: "月$230のAIツールスタック — ソロ創業者が選んだ構成と理由"
tags: AI,個人開発,buildinpublic,automation
published: true
---

# 月$230のAIツールスタック — ソロ創業者が選んだ構成と理由

個人開発で本当に使っているAIツールスタックを全部公開します。合計月$230。これで12インスタンス並行開発・50本以上のブログ投稿・競馬AI予測・カスタマーサポート自動化を回しています。

## スタック全体像

| ツール | 月額 | 主な用途 | 代替不可理由 |
|---|---|---|---|
| Claude Code Max | $200 | アーキテクチャ判断・コード生成・12インスタンス | 判断・統合は Claude 独占 |
| Supabase Pro | $25 | PostgreSQL + EF + Auth + Realtime | Flutter との相性最良 |
| ElevenLabs | $5 | 動画コンテンツ音声生成 | 日本語音質が最高 |
| GitHub Actions | $0 | CI/CD・全自動化タスク | 無料枠で十分 |
| Firebase Hosting | $0 | Flutter Web 本番ホスティング | Google CDN 無料 |
| NotebookLM | $0 | ゼロトークンリサーチ・Master Brain | Google インフラで無料 |
| GitHub Copilot | $0* | インラインコード補完 | Claude Code補助 |

*VS Code拡張の無料枠

## Claude Code Max: なぜ$200払うか

```
月$200 = 12インスタンスが1日中作業できる無制限プラン
         ↓
        vs
月従量課金 = 同等の作業量で推定 $800-1200/月
```

Max プランは「使えば使うほど得」な設計。12インスタンスで最大限活用することで cost-per-task が劇的に下がる。

**実際の生産量 (2026年4月実績)**:
- AI大学 70社追加 (PS#3)
- 競合ページ 174ルート完成 (PS#4)
- dev.to 54本投稿 (PS#2)
- stale EF 監査・修正 (PS#5)
- 競馬AI 10因子化 (PS#6)

同等の作業をフリーランサーに依頼したら月$5,000-10,000は軽く超える。

## Supabase Pro: なぜ $25 に留まれるか

**hub パターン** で EF を18本に抑えているから。

個別 EF だと追加コスト発生するプランへの移行が必要になる。hub に詰め込むことで Pro プランの制限内に収まる。

加えて:
- Row Level Security で認証ロジックをDB層に集約
- Edge Functions で複雑なロジックをサーバー側に移動
- Realtime でポーリング不要 → クライアントからのリクエスト削減

## ゼロコストの武器: GHA + Firebase + NotebookLM

**GitHub Actions**: 月2,000分まで無料。現在の全自動化タスク (blog-publish / cs-check / daily-report / ai-university-update) で月約1,200分使用。余裕あり。

**Firebase Hosting**: 10GB/月 + CDN 無料。Flutter Web の SPA は圧縮後 2MB 以下。全然足りる。

**NotebookLM**: Google の無料サービス。月$200節約に貢献している最大の「無料ツール」。

## 使わなかったツール

| ツール | 見送り理由 |
|---|---|
| OpenAI API | Claude の方が日本語品質高い |
| Vercel | Firebase で十分 + Google 統合が良い |
| PlanetScale / Neon | Supabase でPG+EF+Auth全部入り |
| Sentry | GHA エラー通知で代替 |
| Datadog / Grafana | 個人開発規模には重すぎる |

## コスト効率の原則

**1. 無制限プランを最大活用する**  
月額固定のツールは「使わないと損」。Claude Code Max は12インスタンスで飽和するまで使う。

**2. 無料枠の天井を知る**  
GHA 2000分 / Firebase 10GB / Supabase 無料枠 — どこまで無料かを正確に把握。超える前に設計で対処。

**3. AI でコスト削減する AI ツールを選ぶ**  
NotebookLM で Claude Code の token 消費を50%削減 → 実質 $100 分の価値。ツール自体がコスト削減に貢献するか確認する。

## まとめ

月$230でエンジニア12人相当の生産量を出す構成のポイントは:
1. 無制限プランを限界まで活用 (Claude Code Max)
2. 設計でコストを抑える (hub パターン / ゼロトークンリサーチ)
3. 無料ツールの価値を最大化 (GHA / Firebase / NotebookLM)

AIツールへの投資は「能力の購入」ではなく「レバレッジの購入」。同じ$230でどれだけの力を借りられるかが問われています。
