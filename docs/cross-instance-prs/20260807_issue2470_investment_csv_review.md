---
date: 2026-08-07
from: Codex #1 (Windows app)
to: Claude Code #1 (Windows app)
status: pending
priority: high
---

# Issue #2470 投資CSV import 実装レビュー

## 概要

WBS期限順の次タスク Issue #2470 として、楽天証券/SBI証券の保有商品CSVを
投資資産へ preview 後に取り込む実装です。Claude Code #1 は product/UX と
安全境界をレビューし、Codex #1 が指摘対応・CI・merge・WBS同期を担当します。

## 依頼内容

1. 楽天/SBIの列mappingと、tickerを自然キーにした重複判定をレビューする。
2. preview確定前に書き込みがないこと、既定値がskipであることを確認する。
3. 同一CSV内の同一tickerを数量合算＋取得単価の加重平均で統合する判断を確認する。
4. UTF-8→Shift_JIS→malformed UTF-8の共通decoderと既存SMBC回帰を確認する。
5. 問題がなければPRをapproveし、問題があれば具体的な変更要求を残す。

## Delegation Packet

- WBS / Issue: `389a5139-d893-403d-9af6-dffeb22e60c6` / `#2470`
- Due date: `2026-07-21..2026-07-22`
- Current owner: Codex #1（実装・CI・WBS同期）/ Claude Code #1（レビュー）
- Objective: 楽天証券/SBI証券CSVの選択・preview・重複ticker skip/update
- Branch: `codex/issue-2470-investment-csv-import`
- Worktree: `C:\tmp\my_web_app-issue2470`
- Allowed write set: 下記関連ファイルへのレビュー指摘。修正実装はCodex #1が担当。
- Prohibited write set: root worktreeの既存dirty 274 paths、NotebookLM intake 4変更、既存memory変更
- Required validation: `flutter analyze --no-pub`、対象service/widget tests、GitHub Actions
- Expected output: GitHub PR review（approve または actionable request changes）
- Risk triggers that must return to Claude Code: 実CSVと列mappingの不一致、自然キー変更、production schema/RLS変更
- Memory/disk hygiene action for this session: 重いFlutter処理を直列化し、merge後に専用worktree/.dart_toolを削除
- Subagent plan: none（2トップレベルインスタンス制を維持）

## 関連ファイル

- `lib/services/investment_csv_import_service.dart`
- `lib/services/csv_bytes_decoder.dart`
- `lib/services/smbc_csv_import_service.dart`
- `lib/widgets/investment_asset_management_panel.dart`
- `lib/pages/asset_management_page.dart`
- `test/services/investment_csv_import_service_test.dart`
- `test/services/csv_bytes_decoder_test.dart`
- `test/widgets/investment_asset_management_panel_test.dart`

## Result Contract

- Changed files: service 5、Flutter UI/page 2、tests 3、このhandoff 1
- Validation result: `flutter analyze --no-pub` 0 issues、対象service 9 tests pass、投資panel 10 tests pass
- PR / Issue links: Issue `#2470`、PRはpush後に追記
- Remaining risk: broker側export列名変更、VM/nativeでのShift_JIS直接decode非対応（WebではTextDecoder対応）。ローカルClaude Code reviewはOAuth期限切れ（401）のため、PR上のreview laneへ引き継ぐ
- Next owner: Claude Code #1 review → Codex #1 CI/merge/deploy/WBS同期
- Subagent evidence: none

## 完了条件

- [ ] Claude Code #1 のレビュー結果がPRに記録されている
- [ ] 指摘がある場合はCodex #1が修正し、再検証している
- [ ] CI全緑後に通常mergeする

完了後は `done/` へ移動してください。
