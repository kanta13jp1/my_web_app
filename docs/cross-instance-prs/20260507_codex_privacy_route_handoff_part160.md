# Cross-Instance PR: `/privacy` route 実装 hand-off (= Issue #1495 Phase 0 blocker)

> **作成**: Win版#132 part 160 / 2026-05-07
> **From**: Win Claude (= architect / docs)
> **To**: Win Codex (= 実装)
> **優先度**: high (= Phase 0 blocker / 期限 2026-05-25)
> **関連**: Issue [#1495](https://github.com/kanta13jp1/my_web_app/issues/1495) / [`docs/MOBILE_RELEASE_SPEC.md`](../MOBILE_RELEASE_SPEC.md) §2.2 / [`docs/PRIVACY_POLICY_DRAFT.md`](../PRIVACY_POLICY_DRAFT.md)

---

## 概要

iOS App Store + Google Play 申請の Phase 0 blocker である **Privacy Policy 公開 URL** の `/privacy` route 実装を Win Codex へ hand-off。

**Win Claude 完了分** (= part 160):
- ドラフト本文 [`docs/PRIVACY_POLICY_DRAFT.md`](../PRIVACY_POLICY_DRAFT.md) 作成 (= 18 section / 法的 framing + AI 取扱 + メンタルヘルス免責 + 国際移転)
- 4 軸 alignment チェック内蔵 (= PHILOSOPHY-22 9/9 + AI-CHARACTER-24 8/8 + MCP-AUTH-27 10/10 + AI-DEV-23 7/7 ✅)
- [`docs/MOBILE_RELEASE_SPEC.md`](../MOBILE_RELEASE_SPEC.md) §2.2 にドラフト着地 note 追加

---

## Codex 依頼内容 (= 実装スコープ)

### 1. `lib/pages/privacy_policy_page.dart` 新規作成

- ドラフト [`docs/PRIVACY_POLICY_DRAFT.md`](../PRIVACY_POLICY_DRAFT.md) §1-§14 を `flutter_markdown` でレンダリング (= §0 + §16-§18 = 内部 alignment 表は **公開ページから除外**)
- `assets/legal/privacy_policy.md` に公開用 markdown を別出 (= 内部 alignment 表を削除した版を配置)
- `pubspec.yaml` の `assets:` に `assets/legal/` を追加
- DESIGN.md (Orange + Indigo dark) に従ったコンテナ + scroll + 戻るボタン

### 2. ルーティング登録

- 既存ルーティング (= `lib/main.dart` 等) に `/privacy` route を追加
- mobile / web 両対応 (= `MOBILE_RELEASE_SPEC` §4.1 hybrid)
- `lib/main_mobile.dart` でも到達可能

### 3. Firebase Hosting 公開 URL 確保

- <https://my-web-app-b67f4.web.app/privacy> アクセスで本ページが 200 で返ることを確認
- ストア審査者向け **認証不要** で閲覧可能 (= deep link 直 hit OK)
- pre-flight checklist 「Privacy Policy URL アクセス可能」項目を満たす

### 4. iOS Privacy Manifest との整合 ([`docs/MOBILE_RELEASE_SPEC.md`](../MOBILE_RELEASE_SPEC.md) §3.1)

- `ios/Runner/PrivacyInfo.xcprivacy` を新規作成 (= 既存ない場合)
- ドラフト §2.2 の data category と xcprivacy `NSPrivacyCollectedDataTypes` を一致させる:
  - `NSPrivacyCollectedDataTypeEmailAddress` (= Google OAuth profile)
  - `NSPrivacyCollectedDataTypeName` (= 表示名)
  - `NSPrivacyCollectedDataTypeUserContent` (= ブログ / WBS / 食事ログ等)
  - `NSPrivacyCollectedDataTypeCrashData` (= Firebase 経由がある場合)
  - linking = `false` / tracking = `false` (= §3 広告配信なし)
- `NSPrivacyAccessedAPITypes`: `flutter_native_splash` 等が利用する API category を明示

### 5. Google Play Data Safety form 入力値の reference doc

- `docs/google_play_data_safety_input.md` 新規 (= ストア管理者がコピペできる形)
- ドラフト §2 + §4 の data category を Play Console 用に変換した tabular form
- 「Data shared with third parties」「Data collected」「Security practices」の 3 section
- ユーザー (= ストア account 操作者) は本 doc から転記するだけで済むようにする

### 6. Cookie / 同意 banner (= 任意 / Phase 1 候補)

- 現状 §9 で「解析 cookie 未導入」と明示しているため Phase 0 では banner 不要
- Phase 1 で解析導入時に再評価 (= 同意取得 UI 実装)

---

## 受け入れ条件 (= Definition of Done)

- [ ] `/privacy` route が web で 200 で返る
- [ ] mobile (= iOS + Android) でも到達可能
- [ ] レンダリング崩れなし (= スクロール / リンク踏める)
- [ ] `ios/Runner/PrivacyInfo.xcprivacy` 存在 / 中身がドラフト §2 と整合
- [ ] `docs/google_play_data_safety_input.md` 作成
- [ ] DESIGN.md tokens 遵守 (= Orange + Indigo dark / 独自色なし)
- [ ] `flutter analyze` 0 errors / 0 warnings
- [ ] `dart format --set-exit-if-changed` pass
- [ ] minimal-e2e-gate workflow pass
- [ ] PR description に Issue #1495 close note + ドラフトへのリンク

---

## 注意事項 ([NO-SCOPE-CREEP])

- ドラフトの **本文修正は禁止** (= 法的内容変更は別 PR / 法律専門家レビュー後)
- typo / リンク切れ等の軽微修正は OK
- 「ついでに」プライバシー関連の他機能 (= 同意撤回 UI 等) を追加しない (= TODO に書いて別 session)
- AI-CHARACTER 倫理免責文 (§7) は **literal** に維持 (= 言い換え禁止)

---

## 期限 / SLA

- **2026-05-25**: 実装完了 + Firebase Hosting 公開
- **2026-05-30**: Issue #1495 Phase 0 mobile release blocker 解消

---

## related

- Issue [#1495](https://github.com/kanta13jp1/my_web_app/issues/1495)
- [`docs/MOBILE_RELEASE_SPEC.md`](../MOBILE_RELEASE_SPEC.md) §2.2 + §6 hand-off matrix
- [`docs/PRIVACY_POLICY_DRAFT.md`](../PRIVACY_POLICY_DRAFT.md) §17 hand-off
- [`docs/cross-instance-prs/20260507_q2_fleet_strategy_action_guidelines.md`](20260507_q2_fleet_strategy_action_guidelines.md) (= Q2 fleet strategy への組込候補)

---

*Win版#132 part 160 / 2026-05-07 / Win Claude → Win Codex / Phase 0 blocker hand-off*
