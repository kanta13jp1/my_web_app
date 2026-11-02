# Pull Request

## Minimal E2E Gate

- [ ] Implementation-detail independent: the E2E plan checks user-visible input/output, not private internals.
- [ ] Minimal scope: about 3 cases only (happy path, error path, recovery or empty state).
- [ ] E2E included: Flutter `integration_test/` or Playwright `test/e2e/`.
- [ ] Exception reason, if no E2E file is included: <!-- reason + manual verification steps -->

## Visual E2E Evidence

- Reference: `docs/CODEX_UI_QA_PLAYBOOK.md`
- [ ] Desktop and mobile Playwright evidence captured for landing/home/auth/notion-wbs/agent-org, or the current equivalent public routes.
- [ ] Screenshots plus low-FPS frame sequence are attached in Playwright artifacts.
- [ ] Console errors, page errors, request failures, and HTTP 5xx responses are reviewed.
- [ ] `getAnimations()` wait path ran, or the fallback is documented in the PR.
- [ ] Codex in-app browser or equivalent browser verification notes are included when UI changed.

## Codex UI QA / Prototyping

- [ ] Changed routes/surfaces are listed:
- [ ] Codex in-app browser check is included for UI/layout/interaction changes, or this PR explains why it is not applicable.
- [ ] Playwright command or artifact is listed, for example `npm run e2e:visual -- --project=chromium --project=mobile-chrome --workers=1`.
- [ ] Desktop and mobile viewport findings are summarized.
- [ ] Generated imagery status is recorded:
  - [ ] No generated image was used.
  - [ ] Generated image was used and the prompt, intended use, asset path, rights statement, and verification note are included.
- [ ] Generated imagery is not being used as proof of the actual product state.

## Design Accessibility Audit

- Reference: `docs/DESIGN_ACCESSIBILITY_AUDIT.md`
- Scope: <!-- routes=...; components=...; states=...; viewports=... -->
- Surface-Type: <!-- checkout-form — reason | other — reason -->
- Design-Plugin-Status: <!-- pass; UI changes cannot use pending or not-applicable -->
- Design-Plugin-Reviewed-At: <!-- YYYY-MM-DD of the final re-review -->
- Design-Plugin-Evidence: <!-- HTTPS URL, PR comment #, artifact:name, or repository evidence file -->
- WCAG-2.1-AA-Findings: <!-- result=pass; unresolved-high=0; summary/remaining risks -->
- Remediation: <!-- resolved=<count>; changes after plugin review, or why none was required -->
- Deterministic-Evidence: <!-- tests=...; keyboard-contrast=...; AT=result or not-run owner/follow-up -->
- Error-Microcopy-Review: <!-- reviewed — result; or not-applicable — specific reason when no checkout/form error state exists -->

## 📝 変更内容
<!-- このPRで実施した変更内容を簡潔に説明してください -->

### 変更の種類
<!-- 該当するものにチェックを入れてください -->

- [ ] 新機能 (breaking changeを含まない機能追加)
- [ ] バグ修正 (breaking changeを含まないバグ修正)
- [ ] リファクタリング (機能変更を含まないコード改善)
- [ ] ドキュメント更新
- [ ] パフォーマンス改善
- [ ] テスト追加・修正
- [ ] CI/CD関連
- [ ] Breaking change (既存機能に影響する変更)

## 🔗 関連Issue
<!-- 関連するIssueがあればリンクしてください -->

Closes #
Related to #

## 🎯 変更の目的
<!-- この変更を行った背景や目的を説明してください -->

## 📋 実装の詳細
<!-- 技術的な実装の詳細や設計の意図を説明してください -->

### 主な変更点

1.
2.
3.

### 技術的な詳細
<!-- 特筆すべき技術的な詳細があれば記載してください -->

## ✅ テスト結果
<!-- テスト結果を記載してください -->

### テスト実施項目

- [ ] 単体テスト
- [ ] 統合テスト
- [ ] E2Eテスト
- [ ] 手動テスト
- [ ] ブラウザ互換性テスト

### テスト環境

- **ブラウザ**: <!-- 例: Chrome, Firefox, Safari -->
- **OS**: <!-- 例: Windows, macOS, Linux -->
- **デバイス**: <!-- 例: PC, タブレット, モバイル -->

### テストケース

| テストケース | 結果 | 備考 |
| --- | --- | --- |
| | ✅/❌ | |

## 📸 スクリーンショット・動画
<!-- UIに変更がある場合は、Before/Afterのスクリーンショットを添付してください -->

### Before
<!-- 変更前のスクリーンショット -->

### After
<!-- 変更後のスクリーンショット -->

## 🚨 Breaking Changes
<!-- Breaking Changesがある場合は詳細を記載してください -->

- [ ] このPRにはBreaking Changesが含まれていません

<!-- Breaking Changesがある場合は以下に記載 -->
### 影響範囲

### マイグレーション手順

## 📊 パフォーマンスへの影響
<!-- パフォーマンスに影響がある場合は記載してください -->

- [ ] パフォーマンスへの影響はありません

<!-- 影響がある場合は以下に記載 -->
### パフォーマンス測定結果

| 項目 | Before | After | 改善率 |
| --- | --- | --- | --- |
| | | | |

## 🔒 セキュリティへの影響
<!-- セキュリティに影響がある場合は記載してください -->

- [ ] セキュリティへの影響はありません
- [ ] 脆弱性スキャンを実施しました

## 📚 ドキュメント更新
<!-- ドキュメントの更新が必要な場合はチェックしてください -->

- [ ] READMEの更新
- [ ] APIドキュメントの更新
- [ ] ユーザーガイドの更新
- [ ] 技術ドキュメントの更新
- [ ] ドキュメント更新は不要

## ✅ レビュー観点
<!-- レビュアーに特に確認してほしい点を記載してください -->

### 重点的にレビューしてほしい箇所

1.
2.

### 懸念事項・相談したい点

## 🚀 デプロイメモ
<!-- デプロイ時に注意すべき点があれば記載してください -->

- [ ] データベースマイグレーションが必要
- [ ] 環境変数の追加・変更が必要
- [ ] 外部サービスの設定変更が必要
- [ ] 特別なデプロイ手順は不要

### デプロイ手順

1.
2.

## ✅ チェックリスト
<!-- マージ前に以下の項目を確認してください -->

### コード品質

- [ ] `flutter analyze` 0エラーを確認しました（必須 — CIゲート）
- [ ] `deno lint` 0エラーを確認しました（Edge Function変更時は必須 — CIゲート）
- [ ] `dart format .` を実行しました
- [ ] ダミーデータを使用していません（Supabase実データのみ）
- [ ] 不要なコメントや console.log を削除しました
- [ ] コードレビューを受ける準備ができています（Claude Agent が自動レビューします）

### Rule / Script / Hook wiring 同期（追加時のみ — part 185 finding）
<!-- inject-rules.txt rule 追加 / scripts/ 新 primitive 追加 / hook 配線変更時にチェック -->

- [ ] 該当なし（rule / script / hook 追加・変更なし）
- [ ] `inject-rules.txt` に rule 追加時: `scripts/sync_inject_rules.py` の `EXPECTED_RULE_COUNT` + `CRITICAL_RULES` 同時更新済（= 二重 source-of-truth back-fill 漏れ防止 / part 185 KPI integrity fix 教訓）
- [ ] `scripts/*.py` `scripts/*.ps1` 新規 primitive 追加時: `~/.claude/settings.json` `SessionStart` / `SessionEnd` hooks 配線済 — または別 issue で配線計画明記（= part 185b hook wiring gap 教訓）
- [ ] hook wiring 変更時: 配線後 **次セッション起動で auto-fire 動作 verify** 済（= log/CSV path に SessionStart timestamp 一致 row 追加確認 / **manual invoke だけでは不十分** — Win 環境では `python C:\...` raw 直叩きが WindowsApps stub で silent fail しても manual invoke は通る / part 187 finding）
- [ ] hook command が `python` `node` 等 interpreter を直接呼ぶ場合: Win では `powershell -NoProfile -ExecutionPolicy Bypass -Command "& <interp> <args>"` でラップ済（= WindowsApps reparse-point stub 0-byte で非インタラクティブ silent fail 回避 / part 187 finding）

### テスト

- [ ] 新しいコードにテストを追加しました
- [ ] すべてのテストが通ることを確認しました
- [ ] 手動テストを実施しました
- [ ] エッジケースを考慮しました

### ドキュメント

- [ ] コードコメントを適切に記載しました
- [ ] **`docs/GROWTH_STRATEGY_ROADMAP.md` にセッション記録を追記しました**（開発ルール#3 必須）
- [ ] 必要なドキュメントを更新しました
- [ ] CHANGELOG（リリースノート）の更新が必要な場合は実施しました

### セキュリティ

- [ ] 機密情報がコミットされていないことを確認しました
- [ ] 入力値の検証を適切に実装しました
- [ ] セキュリティベストプラクティスに従っています

### その他

- [ ] Breaking Changesがないことを確認しました（またはドキュメント化しました）
- [ ] パフォーマンスへの悪影響がないことを確認しました
- [ ] ブラウザ互換性を確認しました
- [ ] モバイル対応を確認しました（該当する場合）

## 💬 追加コメント
<!-- その他、レビュアーに伝えたい情報があれば記載してください -->
