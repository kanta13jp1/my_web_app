---
title: "Claude Code hooks 設計 — UserPromptSubmit で毎ターンルールを強制注入する"
tags: AI,個人開発,automation,buildinpublic
published: true
---

# Claude Code hooks 設計 — UserPromptSubmit で毎ターンルールを強制注入する

Claude Code の最大の弱点は「CLAUDE.md を一度読んだらあとは忘れる」ことです。指示を500個書いても、最高精度モデルで68%しか遵守しないという研究結果があります。これを解決するのが **hooks** です。

## CLAUDE.md の限界

```
CLAUDE.md → セッション開始時に一度だけ読まれる
           → 長い会話になると圧縮・忘却される
           → 複数インスタンスでルールが形骸化する
```

特に12インスタンス並行開発では、各インスタンスが同じ CLAUDE.md を読むものの、セッションが長くなると遵守率が下がる問題が顕著でした。

## 解決策: UserPromptSubmit hook

```json
// ~/.claude/settings.json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "cat ~/.claude/hooks/inject-rules.txt"
          }
        ]
      }
    ]
  }
}
```

ユーザーがプロンプトを送るたびに `inject-rules.txt` の内容が system-reminder として注入されます。**毎ターン強制**なので忘却の余地がない。

## inject-rules.txt の構造

```text
RULES (毎ターン注入・全プロジェクト共通):

[INSTANCE] セッション冒頭でインスタンス種別確認必須

[WBS-SYNC] セッション開始時に wbs.priority_for_instance を呼び出し、
  担当タスクを確認すること

[DART-FORMAT] Dart編集後は dart format → flutter analyze 0 → push

[REBASE] push前に git pull --rebase origin main

[EF-CAP-50] EF数 ≤ 50 絶対制約 / hub action 追加最優先

[AI-CHARACTER-24] AI Character 8原則チェック (人格・倫理)

[ROADMAP-LOG] docs/GROWTH_STRATEGY_ROADMAP.md 毎セッション末尾追記
```

各ルールは `[TAG]` 形式で識別。ルール違反は `wbs-staleness-audit` で自動検出される。

## 運用で学んだ設計原則

### 原則1: CLAUDE.md はfacts(事実)のみ

```
CLAUDE.md に残すもの:
✅ 技術スタック (Flutter / Supabase / GHA)
✅ EF 一覧
✅ コマンド例

inject-rules.txt に移すもの:
✅ 行動ルール ([DART-FORMAT] / [REBASE] 等)
✅ インスタンス役割 ([INSTANCE-ROLES])
✅ 制約チェック ([EF-CAP-50] / [NO-SCOPE-CREEP])
```

facts は変わらないが、rules は進化する。分離することで管理しやすくなる。

### 原則2: ルールに [TAG] をつける

`[EF-CAP-50]` のように bracket タグをつけると:
- grep で遵守確認できる (`grep "\[EF-CAP-50\]" git log`)
- GHA の audit cron でスキャンできる
- cross-instance-pr で「このルール追加」と言及しやすい

### 原則3: なぜ(Why)を1行書く

```text
[STASH-SAFETY] git stash 禁止・WIP commit 推奨
  ← Why: 複数 worktree 環境で stash はインスタンス固有。
         別インスタンスが同 worktree に入ったとき消える可能性あり
```

理由があると、エッジケースで自分で判断できる。

## 効果の実測

12インスタンス導入前後のルール遵守率 (週次 wbs-staleness-audit 検出件数):

| 期間 | CLAUDE.md のみ | inject-rules.txt 導入後 |
|---|---|---|
| 2026-02 | 週8件違反 | — |
| 2026-03 | 週6件違反 | — |
| 2026-04 (導入) | — | 週1〜2件 |

違反の大半は「push前にrebaseしなかった」「published:trueを手動更新しなかった」等の手順漏れ。毎ターン注入でほぼ解消。

## まとめ

Claude Code hooks は「AIに訓練で覚えさせる」代わりに「毎回思い出させる」仕組みです。記憶に頼るな、仕組みに頼れ。この設計思想が12インスタンス並行開発を安定させた核心です。
