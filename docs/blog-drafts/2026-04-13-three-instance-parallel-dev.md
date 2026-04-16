---
title: "Claude Code を3インスタンス並行運用して個人開発を3倍速にした話"
tags: ClaudeCode,個人開発,Flutter,Supabase,buildinpublic
published: true
---

# Claude Code を3インスタンス並行運用して個人開発を3倍速にした話

## はじめに

Flutter Web + Supabase のアプリを個人開発していると、「やることが多すぎて追いつかない」という問題に直面します。

- フロントエンド (Dart) を直している間にバックエンド (Edge Function) が放置される
- CI/CD を最適化したいのにコード変更が止まらない
- ドキュメントは常に更新遅れ

この問題を解決するために、**Claude Code を3つのインスタンスで並行起動**し、それぞれに専任ロールを与えるアーキテクチャを導入しました。

---

## 3インスタンス体制の概要

| インスタンス | 担当ファイル | 専任タスク |
|-------------|-------------|-----------|
| **VSCode版** | `lib/` + `supabase/functions/` | Flutter UI実装・Edge Function開発 |
| **Windowsアプリ版** | `docs/` + `supabase/migrations/` | ドキュメント管理・DBスキーマ追加 |
| **PowerShell版** | `.github/workflows/` | CI/CD最適化・ブログ自動投稿管理 |

各インスタンスは **担当外ファイルには一切触れない**ことを厳守します。

---

## なぜ分けるのか？

### 問題1: コンテキスト汚染

1つのセッションで全てを扱うと、Claude のコンテキストが混在して判断精度が落ちます。

- `lib/` の Dart コードと `.github/workflows/` の YAML は全く異なる文法
- 同時に考えると、修正すべき箇所の見落としが増える

### 問題2: ファイルの競合

同一ディレクトリで複数の作業を並行すると、Git の競合が頻発します。ファイルを厳密に分割することで競合がほぼゼロになりました。

### 問題3: セッション長の制限

Claude Code のコンテキスト圧縮により、1セッションで長時間作業すると初期の判断が失われます。短いセッションを3つ並行することで、各インスタンスが常に鮮明なコンテキストを保ちます。

---

## インスタンス間の協調: cross-instance-prs

直接ファイルを操作できないインスタンスが、他のインスタンスへ作業依頼をする仕組みが `docs/cross-instance-prs/` ディレクトリです。

```
docs/cross-instance-prs/
├── 20260412_groq_provider_ui.md        # Windows版 → VSCode版 へ依頼
├── 20260413_allenai_naver_provider_ui.md
└── done/
    └── 20260412_anthropic_provider_ui.md  # 完了済み
```

例えば Windowsアプリ版が新しい AI プロバイダーの migration を追加したとき:

```markdown
# AI大学 Allen AI UI追加依頼 (Windows版#67 → VSCode版)

## 作業内容
`lib/pages/gemini_university_v2_page.dart` の `_providerMeta` に以下を追加:

| Key | Value |
|-----|-------|
| provider | `allen_ai` |
| name | `Allen AI (AI2)` |
| emoji | `🔬` |
| color | `Color(0xFF1565C0)` |

migration: `20260413049000_seed_allenai_ai_university.sql` 追加済み
```

VSCode版がUIを追加したら `done/` フォルダに移動してクローズします。

---

## 共有状態: COMPRESSED_PROMPT_V3.md

3インスタンスが共通して参照するのが `.github/COMPRESSED_PROMPT_V3.md` です。

- **現在の数値** (EF本数・LP表示数・ページ数・AI大学社数) を常に最新化
- **インスタンス別スコープ早見表** で担当範囲を明確化
- **実装待ちリスト** で次のタスクを管理

```markdown
# 現状数値スナップショット
- EF: 15本 (ハードキャップ50本以下)
- AI大学: DB 66社 / UI 66社
- LP: 126のこと
- 総ページ数: 223ページ
```

このファイルを全インスタンスが共有することで、「別インスタンスが既に実装済み」の二重作業を防ぎます。

---

## メモリシステム: セッション間の記憶

Claude Code はセッションをまたいで記憶を保持しないため、3層のメモリシステムを使います。

```
C:\Users\kanta\.claude\projects\...\memory\
├── MEMORY.md                    # 全メモリのインデックス (200行以内)
├── user_instance_powershell.md  # このインスタンスはPS版
├── project_20260413_ps55.md     # PS版#55 完了状態
├── feedback_success_*.md        # 成功パターン記録
└── feedback_correction_*.md     # 失敗・禁止事項記録
```

セッション開始時に `MEMORY.md` を読み込み、前回の成功パターン・禁止事項を確認します。

---

## 実際の1日の作業フロー

```
09:00 JST  各インスタンス起動 → MEMORY.md 確認 → COMPRESSED_PROMPT 確認
           ↓ 並行作業開始
VSCode版   : AI大学 UI追加 (lib/pages/gemini_university_v2_page.dart)
Windows版  : AI大学 migration 追加 (supabase/migrations/)
PS版       : blog-publish.yml 修正 + T-1記事 dispatch

11:00 JST  cross-instance-pr 確認
           Windows版: "Allen AI migration追加済み → VSCode版へUI追加依頼"
           VSCode版: PR を受け取り → UI実装 → done/ に移動

セッション終了時:
           各インスタンス: ROADMAP 末尾に実施内容を追記
           memory/ に成功パターン・失敗パターンを保存
```

---

## CI/CD の統合管理 (PowerShell版 専任)

3インスタンスが同じリポジトリに push するため、CI/CD の最適化は PowerShell版が専任で管理します:

- **Rule 17**: 全ワークフロー (25本) を毎セッション確認
- **deploy-prod 競合防止**: `concurrency` 設定で最新コミットのみデプロイ
- **EF ハードキャップ**: `ci.yml` で 50本超過を CI ブロック
- **SQL artifact 検出**: `'"'"'` パターンを CI で検出してブロック (SQLSTATE 42601 再発防止)

---

## 成果: 1日で何ができるか

**実績 (2026-04-12〜04-13):**

| インスタンス | 1日の成果 |
|-------------|----------|
| VSCode版 | AI大学 UI 17社追加 + OGP シェアカード実装 + ページ4本追加 |
| Windowsアプリ版 | AI大学 DB 39社追加 (migration 39ファイル作成) |
| PowerShell版 | T-1 ブログ記事 35本 dispatch + CI 25本最適化 |

1人で1日にここまでの量をこなせるのは、3インスタンス並行運用のおかげです。

---

## まとめ

Claude Code を単一セッションで使うより、**専任ロール × 3インスタンス**に分割することで:

- コンテキスト汚染を防ぎ判断精度が上がる
- ファイル競合がほぼゼロになる
- 担当範囲が明確で「やること」が絞られる

`cross-instance-prs/` + `COMPRESSED_PROMPT_V3.md` + `memory/` の3点セットで協調すれば、Claude Code が実質3人のエンジニアとして機能します。

---

自分株式会社: https://my-web-app-b67f4.web.app/
#ClaudeCode #個人開発 #Flutter #Supabase #buildinpublic
