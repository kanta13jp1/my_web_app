---
title: "12インスタンス並行開発の設計 — Claude Code 10台 + Codex 2台のフリート運用"
tags: claude-code,AI,個人開発,architecture
published: true
---

# 12インスタンス並行開発の設計 — Claude Code 10台 + Codex 2台のフリート運用

個人開発者が「AIを複数台並行稼働させる」というアイデアを実際に運用に落とし込んだ話をします。現在、私のプロジェクトでは **Claude Code 10インスタンス + Codex CLI 2インスタンス = 計12スロット** を同時に動かしています。

## なぜ12インスタンス？

シングルAIで開発を続けていると、いくつかの限界が見えてきます：

- **コンテキスト汚染**: 長いセッションで前半の判断がブレる
- **並行作業の限界**: Flutterの UIとDB migrationを同時に触れない
- **専門性の欠如**: すべてを1つのインスタンスに任せると中途半端

解決策として「役割分担した専用インスタンス」を設計しました。

## インスタンス役割表

| インスタンス | 担当領域 | worktree |
|---|---|---|
| VSCode版 | Flutter UI + Edge Function | `instance-vscode` |
| Win版 | ドキュメント + 動画パイプライン | `instance-win` |
| PS版#1 | WF健全性監視 | `instance-ps1` |
| PS版#2 | ブログ自動投稿 (dev.to/Qiita) | `instance-ps2` |
| PS版#3 | AI大学コンテンツ追加 | `instance-ps3` |
| PS版#4 | 競合172社データ整備 | `instance-ps4` |
| PS版#5 | EF統合・anon guard | `instance-ps5` |
| PS版#6 | 競馬AI予測パイプライン | `instance-ps6` |
| Codex#1 | 横断調査・修正PR | `instance-codex1` |
| Codex#2 | CI/同期/運用補助 | `instance-codex2` |

## Worktree による隔離

最重要ルール: **main リポジトリを直接編集しない**。

```bash
# 各インスタンスは専用 worktree で作業
git worktree add .claude/worktrees/instance-ps2 -b claude/ps2-wip
cd .claude/worktrees/instance-ps2
```

複数インスタンスが同じファイルを触るとコンフリクトが起きます。worktree 分離により：
- 各インスタンスが独立ブランチで作業
- push 後に main へマージ
- コンフリクト解決は rebase で吸収

## push コンフリクトの現実

12台が並行 push すると衝突は日常茶飯事です。対策：

```bash
# push 前に必ず fetch + rebase
git pull --rebase origin main && git push origin HEAD:main
```

1日に10〜20回程度の `rejected` が発生しますが、`--rebase` で自動解決できるケースがほとんどです。

## Migration timestamp 衝突問題

12インスタンスが同日に SQL migration を作ると `YYYYMMDD000000` タイムスタンプが衝突します。

**解決策**: 500刻みで予約
- instance-ps3: `20260428001000`, `001500`, `002000`...
- instance-win: `20260428010000`, `010500`...

## Claude vs Codex の使い分け

| タスク | Primary | 理由 |
|---|---|---|
| アーキテクチャ判断 | Claude | 設計推論が必要 |
| SQL最適化 | Codex | コード生成が速い |
| GHA workflow | Codex | YAML生成得意 |
| memory consolidation | Claude | 横断的判断が必要 |

## 月次コスト感

- Claude Max plan: 月$100 (10インスタンス)
- Codex: 月$20程度 (API従量)
- 合計: 月$120 で「中規模チーム相当」の開発速度を実現

1人の個人開発者として、これは最も費用対効果の高い投資だと感じています。

## まとめ

12インスタンス並行開発は「複雑に見えて、実はシンプルなルールの積み重ね」です：

1. 役割を固定する (scope creep を防ぐ)
2. worktree で隔離する (コンフリクトを減らす)
3. rebase で統合する (push 競合を吸収する)
4. timestamp を予約する (DB衝突を防ぐ)

このアーキテクチャにより、私のプロジェクトは1日あたり50〜80件のコミットを安定して生産できるようになりました。
