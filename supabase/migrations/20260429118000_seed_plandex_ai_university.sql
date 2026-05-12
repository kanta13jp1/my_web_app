-- PS#3 S129: AI大学 353→354社化 — Plandex (長タスク対応AIコーディングエンジン / ロールバック / OSS)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'plandex', 'overview',
  'Plandex — 長タスク対応 AI コーディングエンジン・ロールバック・ブランチ管理・OSS (9/9)',
  $$## Plandex とは

**Plandex** は「長くて複雑なタスク」に特化した AI コーディングエンジン。多くの AI コーディングツールが短いタスクに向いている中、Plandex は**数十ファイルにまたがる長期的な実装**を管理するために設計された。

**git のような変更管理**を AI コーディングに導入し、試行錯誤を安全に行える「バージョン管理付き AI 開発」を実現する。

## Plandex のユニークな特徴

```
Plandex の差別化ポイント:

  1. Pending Changes バッファ:
    ・AI の変更は即座に適用されない
    ・まず「pending changes」として蓄積
    ・まとめて確認 → 承認 or 却下
    ・部分的な承認も可能

  2. ロールバック機能:
    ・変更履歴を全て保持
    ・任意のステップに戻れる
    ・「あのバージョンに戻して」で即ロールバック

  3. ブランチ機能:
    ・AI との会話にブランチを作れる
    ・「このアプローチ vs あのアプローチ」を並列探索
    ・良い方を採用して悪い方を捨てる

  4. 長期コンテキスト管理:
    ・大きなコードベースを段階的に読み込む
    ・コンテキストウィンドウ超過を防ぐ自動管理
```

## Plandex の実際の使い方

```bash
# インストール
curl -sL https://plandex.ai/install.sh | bash

# プロジェクトで初期化
plandex new

# ファイルをコンテキストに追加
plandex load lib/ supabase/

# タスクを実行
plandex tell "認証システムを JWT から Supabase Auth に移行して"

# 変更を確認
plandex diff  # 全 pending changes を確認

# 一部だけ承認
plandex apply lib/auth_service.dart  # このファイルの変更のみ適用

# ロールバック
plandex rewind  # 直前のステップに戻る
plandex rewind 3  # 3ステップ前に戻る
```

## 長タスク向け設計の背景

```
なぜ「長タスク」に特化するのか:

  短タスク (5分以内):
    ・GitHub Copilot / ChatGPT で十分
    ・コンテキスト管理が不要
    ・ロールバックもほぼ不要

  長タスク (数時間〜数日):
    ・多数ファイルの変更が積み重なる
    ・途中で方針変更が起きる
    ・「どこまで進んだか」の管理が重要
    ・失敗時の回復手段が必要

  → Plandex は長タスクの「進捗管理」問題を解く
```

## Aider / Claude Code との比較

| 項目 | Plandex | Aider | Claude Code |
|------|---------|-------|-------------|
| タスク規模 | 長期 (数時間+) | 中期 | 中〜長期 |
| ロールバック | ◎ (専用機能) | △ (git 依存) | △ (git 依存) |
| ブランチ | ◎ (AI 会話レベル) | × | × |
| OSS | ✓ (MIT) | ✓ (Apache) | × (商用) |
| UI | CLI | CLI | CLI + Desktop |

## 自分株式会社との関連

Plandex の「Pending Changes バッファ → 確認 → 承認/却下」パターンは、自分株式会社の 12 インスタンスフリートの PR レビューフロー（コード変更 → PR 作成 → claude-agent-review.yml → マージ）と同様の Generator-Verifier パターン。また「AI 会話のブランチ機能」は、複数の実装アプローチを並列に試す自分株式会社の Agent Teams パターンとも対応する。
$$,
  'https://github.com/plandex-ai/plandex',
  NOW(),
  354
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
