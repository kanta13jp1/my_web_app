# Issue Fix Plan #918

- Issue: [[追加要望] 合成メディア同意・透かし・商用ライセンス監査レイヤー](https://github.com/kanta13jp1/my_web_app/issues/918)
- Labels: enhancement,追加要望
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/26136207171

## Goal

[追加要望] 合成メディア同意・透かし・商用ライセンス監査レイヤー

## Current Context

```text
## 背景
NotebookLM対象資料では、合成メディアの倫理的利用、同意、プライバシー保護、偽情報拡散防止、透かし/追跡可能性、出演者・著作権の保護が重要論点として整理されている。また、料金プラン資料では商用利用可否、API連携、透かし削除、追加オプション、プラン制約の確認が必要とされている。

my_web_appがAI動画生成やアバター共有を扱う場合、単に生成できるだけではなく、利用権限・商用可否・出所表示・監査ログを最初から設計に入れる必要がある。

## 追加要望
AI動画/アバター生成機能に共通して適用する「合成メディア同意・透かし・商用ライセンス監査レイヤー」を追加する。

## MVPスコープ
- 生成前チェック: 顔画像/音声/台本の利用権限確認チェックリスト
- 商用利用チェック: 利用プラン、用途、透かし有無、外部公開可否を記録
- 生成物メタデータ: 生成日時、入力元、モデル/API、同意状態、公開範囲を保存
- 共有前警告: X/Slack/Notion/公開ページへ出す前に合成メディアであることを明示
- 管理画面で監査ログを検索できる

## 受け入れ条件
- 動画生成前に「本人/素材の利用許諾」「商用利用可否」「公開範囲」を確認できる
- 生成物ごとに監査ログが残り、後から誰が何を根拠に生成・共有したか追える
- 外部共有時にAI生成/合成メディアである旨の表示オプションがある
- プランやAPI制限に応じて、透かし削除などリスクの高い操作を制御できる
- 既存の全AI機能ガードレールIssueと連携できるが、動画/アバター固有の同意項目を持つ

## NotebookLM根拠
- D-ID倫理資料: バイアス排除、偽情報拡散防止、透明性、追跡可能性、出演者権利・著作権尊重
- D-ID料金プラン資料: 商用ライセンス、API連携、透かし削除、プラン別制約の管理が必要
- Decentralized Identifier資料: デジタルアイデンティティを安全に管理する標準概念が合成メディアの本人性/出所管理に関係

Notebook: https://notebooklm.google.com/notebook/da2a95d1-2db3-4677-9e67-52fae69fb8e9

```

## Autonomous Repair Loop

1. Reproduce the smallest failing path for this issue.
2. Apply the minimum safe fix on this branch.
3. Let normal CI run on the draft PR.
4. If CI fails on mechanical issues, `ci-auto-fix.yml` attempts `dart fix --apply` and `deno fmt`.
5. Merge only after CI is green and the issue scope is satisfied.

## Checklist

- [ ] Reproduction is clear
- [ ] Smallest safe fix is implemented
- [ ] Analyze/tests/CI are checked
- [ ] PR notes explain the change and the remaining risk
