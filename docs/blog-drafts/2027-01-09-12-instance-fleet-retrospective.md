---
title: "12インスタンスAIフリート 3ヶ月の振り返り — コストと効果の実測値"
tags: AI,個人開発,buildinpublic,automation
published: true
---

# 12インスタンスAIフリート 3ヶ月の振り返り — コストと効果の実測値

Claude Code 10 + Codex CLI 2 = 計12インスタンスの並行開発体制を3ヶ月運用しました。予測通りにいったこと、失敗したこと、コストの実態を正直に書きます。

## 構成の概要

| インスタンス | 担当 | 主な成果 |
|---|---|---|
| VSCode版 | Flutter UI / EF 設計 | 競合172社ページ / horse racing UI |
| Win版 | docs / migration schema | AI Character 原則 / IMBUE / COLLAB 設計 |
| PS#1 | Rule17 WF health | GHA全ワークフロー安定化 |
| PS#2 | T-1 ブログ dispatch | dev.to 50本 (Phase1〜6) |
| PS#3 | AI大学 provider 追加 | 200社→270社化 |
| PS#4 | 競合情報ページ | sitemap 174ルート完結 |
| PS#5 | stale EF 監査 / anon guard | 20ページ認証保護 |
| PS#6 | 競馬AI予測強化 | DQS + prev_margin 9因子 |
| Codex#1 | 横断調査 / 修正PR | migration timestamp collision detector |
| Codex#2 | CI / 同期補助 | EF audit workflow |

## 3ヶ月の定量成果

| 指標 | 開始時 | 3ヶ月後 |
|---|---|---|
| AI大学 provider 数 | 200社 | **270社** |
| 競合情報ページ | 22ルート | **174ルート** |
| dev.to 投稿数 | 0本 | **50本** |
| GHA workflow 数 | 18本 | **31本** |
| Edge Function 数 | 28本 | **18本 (hub化で減少)** |

## 良かったこと: 役割分離の効果

最大の成果は「役割分離による並行実行」です。

従来: Claude Code 1インスタンスが全タスクを直列処理 → 1日10タスク
今: 12インスタンスが並行処理 → 1日60〜80タスク

特に効果的だったのは:
- **PS#3**: AI大学追加は完全テンプレート化 → 2社/セッションが安定生産できる
- **PS#6**: 競馬AI専任 → 改善サイクルが週1→日1になった
- **PS#2**: ブログ dispatch 専任 → 他インスタンスがリサーチに集中できる

## 失敗したこと: migration timestamp 衝突

最大の失敗は `migration timestamp collision` です。

```
2026-04-28: 同一日に PS#3/PS#4/PS#5/Win版 が同時に
20260428000000_*.sql を作成 → deploy-prod で SQLSTATE 23505
```

対策: `check_migration_timestamps.py` を CI に組み込み、同一timestamp を事前検出。

教訓: 12インスタンスが共有する namespace (timestamp, EF名, sitemap URL) は衝突検出が必須。

## コストの実態

| コスト種別 | 月次 |
|---|---|
| Claude Code Max プラン | $200/月 (上限) |
| GitHub Actions | $0 (無料枠内) |
| Supabase | $25/月 (Pro) |
| Firebase Hosting | $0 (無料枠内) |
| ElevenLabs | $5/月 |
| **合計** | **~$230/月** |

$230/月で12エンジニア相当の生産量を得られるなら、個人開発としては破格です。ただし「管理コスト」(インスタンス間調整・衝突解消・memory consolidation) が週3〜4時間かかります。

## 次フェーズの課題

1. **cross-instance-pr の自動化**: 現在は人間が仲介。インスタンス間で直接 handoff できる仕組みが必要
2. **WBS の自動更新精度**: 完了報告漏れが週2〜3件残っている
3. **memory decay**: 古い memory ファイルの自動アーカイブが未実装
4. **Codex インスタンスの活用率**: Claude Code との統合が薄い。より深い協調が必要

## まとめ

12インスタンス並行開発は「個人開発の限界」を大きく押し上げます。ただし「管理するAIを管理するコスト」が新たに発生することを認識しておく必要があります。役割分離・衝突検出・memory 整合の3つが安定運用の鍵です。
