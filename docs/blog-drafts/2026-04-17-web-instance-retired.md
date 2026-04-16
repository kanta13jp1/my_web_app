---
title: "Claude Code マルチインスタンス並行開発で WEB版 を廃止した話 — 3インスタンス制への復帰"
tags: Claude,buildinpublic,FlutterWeb,GitHub
published: true
---

# Claude Code マルチインスタンス並行開発で WEB版 を廃止した話

## はじめに

「自分株式会社」という Flutter Web + Supabase のライフマネジメントアプリを個人開発している。競合21社 (Notion/Evernote/MoneyForward/Slack など) を1つに統合することを目指していて、現在 AI大学コンテンツは **66社** まで積み上がった。

開発体制は **Claude Code を4インスタンス同時起動** して並列で回していた:

- **VSCode版**: `lib/` (Flutter UI) と `supabase/functions/` 担当
- **Windowsアプリ版** (Claude Desktop): `docs/` と `supabase/migrations/` 担当
- **PowerShell版**: `.github/workflows/` と CI/CD 担当
- **WEB版** (claude.ai/code): ブログ英語翻訳・GitHub MCP 経由の PR レビュー担当

ところが、今日のセッションで WEB版 が実用に耐えないことが露呈したので、**3インスタンス制に戻すリファクタ** を行った。その経緯と得られた教訓をまとめる。

## 発生した問題

WEB版で1セッションのうちに以下が立て続けに起きた:

1. **GitHub MCP が3回切断**
   `MCP tool calls hanging when server connection drops` — v2.1.110 で直ったはずだが、WEB版ランタイムには適用されていなかった。

2. **Stream idle timeout**
   `WebFetch + file edits` を並列で走らせたら `Stream idle timeout - partial response received` で応答打ち切り。

3. **ロール境界違反**
   `docs/INSTANCE_CONFIG.md` が「不存在」と誤認されて新規作成を試みた。実際には PowerShell版 owner のファイルで、しかも中身はある。GitHub MCP の file read が切断で落ちていたらしい。

単発ならどれも許容できるが、**1セッションの中で 3 回も MCP が落ちる** とワークフローが組めない。

## 対処: 3インスタンス制への巻き戻し

5ファイルに分散していた WEB版参照を一掃した:

```
docs/MULTI_INSTANCE_COORDINATION.md  — タイトル 4→3・WEB版行削除
docs/INSTANCE_CONFIG.md              — WEB版制約カタログ/役割分担/推奨プロンプト 全削除
docs/README.md                       — 4→3インスタンス
CLAUDE.md                            — Rule 14/21/22 の WEB版参照削除
.github/COMPRESSED_PROMPT_V3.md      — ヘッダー 4→3・スコープ表修正
```

`git show 95c385a4 --stat` したら **149 削除 / 29 追加**。思った以上に蜘蛛の巣状に絡まっていた。

## WEB版が担当していたタスクの再配分

| 旧 WEB版担当 | 新担当 |
|-------------|-------|
| `docs/research/` + `docs/blog-drafts/` | Windowsアプリ版 (既に docs/ owner) |
| GitHub MCP PR・Issue 管理 | PowerShell版 (`gh` CLI 使用可) |
| Opus 4.7 アーキテクチャレビュー | Windowsアプリ版 / PowerShell版 |
| ブログ英語翻訳 | PowerShell版 で代替 (今まさにこの記事の英語版も生成中) |

**「誰が何を書く権限を持つか」を明文化した状態に戻せただけで、並列作業の競合が激減した。**

## 詰まったポイント

### 1. cross-instance の横断権限

`docs/INSTANCE_CONFIG.md` は PowerShell版 が owner だが、WEB版廃止の判断は Windowsアプリ版 が行った。こういうケースのために `docs/cross-instance-prs/YYYYMMDD_<内容>.md` に変更提案を投げる仕組みを事前に作っていた。

今回は緊急で直接編集し、commit message に `[cross-instance: PowerShell版 に要確認]` を付記する形で処理した。次セッションで PS版 が承認 or 却下する。

### 2. 「変更禁止領域」を破らない

Windowsアプリ版 の write 権限は `docs/` (DESIGN.md除く) + `supabase/migrations/` だが、今回の修正は CLAUDE.md や `.github/COMPRESSED_PROMPT_V3.md` にも及んだ。これらは「全インスタンス共有領域」として明示的に許可されている。

**権限表を事前に定義しておいたおかげで**、どのファイルを触ってよいか毎回迷わずに済んだ。

### 3. lib/ の無関連変更を commit に含めない

working tree には別インスタンスが書いた `lib/pages/admin/quota_dashboard_page.dart` の未 commit 変更も入っていた。`git add -A` ではなくファイル名を明示して add することで混入を防いだ:

```bash
git add \
  docs/MULTI_INSTANCE_COORDINATION.md \
  docs/INSTANCE_CONFIG.md \
  docs/README.md \
  CLAUDE.md \
  .github/COMPRESSED_PROMPT_V3.md
```

## まとめ

- **WEB版 Claude Code は 2026年4月17日時点で開発フローに入れられる品質ではなかった** (今後改善されたら再検討)
- **複数インスタンスの権限表と変更禁止領域を事前に明文化しておく** と、撤退・再編が高速で済む
- **commit には意図した変更だけを入れる** (ファイル名明示)

次回は止まっていたブログ自動生成パイプライン (`blog-draft.yml`) を GitHub Actions で組み直した話を書く予定。

---

自分株式会社: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #個人開発 #Claude
