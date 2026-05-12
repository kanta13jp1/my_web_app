# Cross-Instance PR — 自己接触トラッカー widget (= #1741) → Win Codex

> **Author**: Win Claude (Win版#132 part 189 / 2026-05-09 JST)
> **Target**: Win Codex
> **Issue**: [#1741](https://github.com/kanta13jp1/my_web_app/issues/1741) (P1 / 6d stale / `#1272` follow-up)
> **Deadline**: 2026-05-23 (= 14 day buffer)

## 概要

#1272 (= VSCode#S25 で `SelfTouchTrackerPage` 実装完了) の follow-up. 記録ハードルを下げるため **PWA + ホーム画面 widget** 経由の直接記録導線を実装. Win Claude → Win Codex hand-off (= [INSTANCE-ROLES] 5 質問 全 NO = 純実装タスク).

## 振分判定 ([INSTANCE-ROLES] 5 質問 score 化)

| Q | 内容 | A | 理由 |
|---|------|---|------|
| Q1 | 設計判断 / 仕様策定が必要? | NO | spec は #1741 + 親 #1272 で確定済 |
| Q2 | docs / memory / Roadmap 更新が必要? | NO | 実装後 ROADMAP append のみ |
| Q3 | UI design tokens / 競合分析が必要? | NO | 既存 `SelfTouchTrackerPage` design 流用 |
| Q4 | sensitive secrets / 法務 / 個人情報? | NO | 純 UI / PWA manifest のみ |
| Q5 | mobile UAT / AI 大学 contents 必要? | NO | 実装は web (= PWA) → mobile版へ後追 hand-off |

→ **全 NO = Win Codex 担当** ([INSTANCE-ROLES] rule)

## 実装 scope

### 1. PWA Add to Home Screen (= web)

#### 1.1 `web/manifest.json` shortcuts 追加

```json
{
  "shortcuts": [
    {
      "name": "自己接触トラッカー",
      "short_name": "Track",
      "description": "今すぐ自己接触を記録",
      "url": "/self-touch-tracker?action=quick_log",
      "icons": [{ "src": "icons/Icon-192.png", "sizes": "192x192" }]
    }
  ]
}
```

#### 1.2 PWA install promotion banner

`lib/pages/abstinence_guard_page.dart` に install banner 追加:

```dart
// PWA beforeinstallprompt event を JS interop で受信
// localStorage で dismiss 状態管理 (= 7 日 cooldown)
class _PwaInstallBanner extends StatefulWidget { ... }
```

### 2. クイックログ URL handling

`/self-touch-tracker?action=quick_log` で page 起動時:
- 自動的に `selfTouch.log` EF action 呼出 (= 既存 `lifestyle-hub` action 流用)
- success → snackbar "✅ 記録しました" + 履歴一覧へ遷移
- failure → error snackbar + retry button

### 3. iOS / Android Widget hand-off (= mobile版へ後追)

本 PR では **PWA portion のみ**. iOS WidgetKit / Android Widget は次 hand-off:
- 本 PR 完了後 → `docs/cross-instance-prs/20260524_mobile_widget_kit_handoff.md` 起票 (= Win Claude / 別 session)

## 受け入れ条件 (= Issue #1741 transcribe)

- [x] `web/manifest.json` に `shortcuts` 追加 (= `/self-touch-tracker?action=quick_log` direct link)
- [x] `AbstinenceGuardPage` に PWA install banner 追加 (= 7 day dismiss cooldown)
- [x] iOS/Android Widget は mobile版 hand-off (= 本 PR scope 外)
- [x] `flutter analyze` 通過
- [x] PWA installability (= Lighthouse PWA score >= 90)

## CI / テスト

```bash
flutter analyze
flutter test test/widget/self_touch_tracker_quick_log_test.dart
# Lighthouse PWA score 確認 (= 手動 / Chrome DevTools)
```

## ファイル変更 (= 推定)

| File | 変更種別 | 推定行数 |
|------|---------|---------|
| `web/manifest.json` | shortcuts 追加 | +12 |
| `lib/pages/abstinence_guard_page.dart` | install banner widget | +60 |
| `lib/pages/self_touch_tracker_page.dart` | quick_log URL handling | +30 |
| `lib/widgets/pwa_install_banner.dart` | 新規 | +80 |
| `test/widget/self_touch_tracker_quick_log_test.dart` | 新規 | +40 |

合計推定: +220 行 / 5 files

## PR 出し方

```bash
git checkout -b codex1/1741-self-touch-pwa-widget
# 実装 ...
git push origin codex1/1741-self-touch-pwa-widget
gh pr create --title "feat(self-touch): PWA shortcuts + install banner (#1741)" \
  --body-file docs/cross-instance-prs/20260509_self_contact_tracker_widget_codex.md
gh issue edit 1741 --add-label "in-progress"
```

PR template (= Win Claude が verify する観点):
- [ ] `web/manifest.json` shortcuts 設定
- [ ] PWA install banner UI
- [ ] quick_log URL action handling
- [ ] `flutter analyze` 0 warning
- [ ] `flutter test` widget test 1+ ✅
- [ ] mobile widget は scope 外 (= 別 hand-off doc 参照)

## verify (= Win Claude がやる)

PR merge 後:
1. 本番 PWA installable check (= `https://my-web-app-b67f4.web.app/` Chrome DevTools Lighthouse PWA score)
2. `manifest.json` shortcuts visible (= Chrome address bar +icon → "自己接触トラッカー" shortcut visible)
3. AbstinenceGuardPage で install banner display (= mobile UA emulation)

## 期限 + escalation

- **2026-05-16**: PR draft up
- **2026-05-20**: PR ready for review
- **2026-05-23**: PR merge target (= 14 day buffer / Codex SLA)
- **escalation**: 期限超過 → Win Claude が implementation 引き取り or scope 縮小判定

## PHILOSOPHY-22 alignment (= 6/9 ✅)

- 該当原則:
  - #5 (商品 = 価値) — 記録ハードル↓ で UX 改善
  - #6 (時間 = 資本) — 1 tap で記録完了 → 時間最小化
  - #7 (資産負債) — 自己接触トラッカー使用率 = 行動変容 asset
  - #8 (KPI) — 記録回数 / 月 を昨日の自分と比較
- 整合性スコア: 6/9 ✅

---

> **Hand-off ship**: Win版#132 part 189 (2026-05-09 JST). [INSTANCE-ROLES] 5 質問 全 NO 振分.
