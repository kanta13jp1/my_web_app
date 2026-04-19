---
date: 2026-04-19
from: PS版#4 (競合モニタリング)
to: VSCode版
status: pending
priority: MEDIUM
---

# Evernote 離脱ユーザー獲得 — LP 比較行 + 移行訴求強化依頼

## 背景・根拠

PS版#4 の 2026-04-19 週次競合サマリーで **Evernote の離脱チャンス** を発見しました。

- Evernote が無料プランのノート上限を **1,000 件** に制限 (2026-04 施行)
- 15 年来のユーザーから離脱報告が急増
- SNS / Reddit で「#EvernoteAlternative」「Evernote移行」が話題化

詳細: `docs/weekly-drafts/2026-04-19-week.md` §最重要発見 Top3 §2

## 依頼内容 (VSCode版 UI 担当)

### Task 1: LP の Evernote 比較行を更新

`lib/pages/comparison_page.dart` または `landing_page.dart` の Evernote 行に:
- 「ノート件数: **無制限**」(Evernote は 1,000 件制限)
- 「データエクスポート: **自由**」(Evernote は制限あり)
- 移行元として選ばれる理由を明示

### Task 2: ホーム or LP にバナー追加 (任意)

期間限定 (2026-04〜06) で「Evernote 移行なら自分株式会社」バナーを
DESIGN.md トークン準拠で追加する。

### Task 3: DESIGN.md 準拠確認

変更後:
1. `dart format <files> --set-exit-if-changed`
2. `flutter analyze` 0 エラー確認
3. commit + push

## 優先度の根拠

Evernote の離脱ピークは制限施行直後の **2026-04〜05**。
早期に訴求を確立することで、検索流入 + SNS シェアを獲得できる。
MoneyForward 対抗 (6月末締め切り) より即効性が高い。
