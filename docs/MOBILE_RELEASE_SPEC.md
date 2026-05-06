# Mobile Release Spec — iOS / Android 同時リリース設計

> **Win版#132 part 159 (2026-05-07)**: Issue #1495 [P0][Mobile] 設計 spec.
> Win Claude territory = ストア公開方針 / 審査要件 / プロダクト判断 / リリースゲート設計.
> 実装 hand-off → Win Codex (= GHA / signing / build artifact / 自動化).

---

## 1. ゴールと非ゴール

### ゴール (= 2026-05-30 期限)

1. **Android internal testing 配布** が再現可能 (= AAB → Play Console internal track)
2. **iOS TestFlight 配布** が再現可能 (= IPA → App Store Connect)
3. **GHA workflow** で 2 platform 同時 build artifact 生成
4. **同時リリース判定 checklist** が doc 化済
5. ストア申請前 blocker が WBS / Issue に分解済

### 非ゴール (= Phase 2 以降)

- 一般公開 (= production track) — internal/beta 配布で十分
- App 内課金 — 自分株式会社の現状商品設計 (= ユーザー価値増大型) では非該当
- Push 通知 — 既存 mobile push fleet rollout (= cross-instance-pr 20260429) と重複回避
- Deep Link / Universal Link 完全対応 — Phase 2 (= ストア公開後)

---

## 2. ストア公開方針

### 2.1 段階配布 (= staged rollout)

```
Phase 0 (本 spec / 2026-05-30): Internal testing / TestFlight 限定
  ↓ feedback loop 1-2 week
Phase 1 (2026 Q3): Closed beta (= 100 user)
  ↓ ストア審査クリア確認
Phase 2 (2026 Q4): Open beta / production track 公開
```

**理由**: [PHILOSOPHY-22] 原則 1 (CEO 感) / 原則 8 (KPI = 昨日の自分) より、**段階的に user feedback を吸収しながら品質確保**。一気に production はリスク高 (= 審査 reject / 1 star レビュー初期固定リスク)。

### 2.2 ストア掲載情報

| 項目 | iOS App Store | Google Play |
|------|---------------|-------------|
| **App Name** | 自分株式会社 (Jibun K.K.) | 自分株式会社 |
| **Bundle ID / App ID** | jp.kanta13.jibun | jp.kanta13.jibun (= 既存 Android applicationId と統一) |
| **Category** | Productivity | Productivity |
| **Age Rating** | 4+ (= 一般 / メンタルヘルス area あるが clinical 助言なし) | All Ages |
| **Privacy Policy URL** | <https://my-web-app-b67f4.web.app/privacy> (= **Phase 0 で新規必要**) | 同上 |
| **Support URL** | <https://github.com/kanta13jp1/my_web_app/issues> | 同上 |

⚠️ **Phase 0 blocker**: Privacy Policy URL の作成が `web/` route として追加必要 (= Win Codex hand-off task).

✅ **part 160 進捗**: ドラフト本文は [`docs/PRIVACY_POLICY_DRAFT.md`](PRIVACY_POLICY_DRAFT.md) で着地済 (= Win版#132 part 160 / 2026-05-07). PHILOSOPHY-22 9/9 + AI-CHARACTER-24 8/8 + MCP-AUTH-27 10/10 + AI-DEV-23 7/7 ✅. Win Codex は `lib/pages/privacy_policy_page.dart` 実装 + ルーティング登録 + Firebase Hosting 公開 URL 確認のみ残. 詳細 hand-off 表はドラフト §17.

---

## 3. 審査要件 (= store review compliance)

### 3.1 iOS App Store Review Guideline 主要対応

| Guideline | 対応 |
|-----------|------|
| **2.1 App Completeness** | TestFlight build で全画面遷移確認 |
| **3.1 Payments** | App 内課金なし (= 該当なし) |
| **4.0 Design** | iOS HIG 準拠 (= flutter material/cupertino のみ) |
| **5.1.1 Privacy** | Privacy Manifest (`PrivacyInfo.xcprivacy`) 必須 (= 2024-05〜) |
| **5.1.2 Data Use** | Supabase / Firebase / Google OAuth の data flow を Privacy Policy に明記 |
| **5.4 VPN Apps** | 該当なし |

⚠️ **iOS 17+ 必須**: `PrivacyInfo.xcprivacy` を `ios/Runner/` に追加 (= [`docs/cross-instance-prs/20260507_q2_fleet_strategy_action_guidelines.md`](cross-instance-prs/20260507_q2_fleet_strategy_action_guidelines.md) Codex 依頼に追加).

### 3.2 Google Play Policy 主要対応

| Policy | 対応 |
|--------|------|
| **Data Safety** | Play Console > Data Safety form 記入 (= Supabase data handling 明記) |
| **Permissions** | `INTERNET` のみ (= 既存 minimum) / `ACCESS_FINE_LOCATION` 等は申請しない |
| **Target API Level** | API 34 (Android 14) 以上 (= 2025-08-31〜 強制) |
| **App Bundle (AAB)** | 必須 (= 2021-08〜 / `flutter build appbundle`) |
| **Sensitive Permission Declaration Form** | 該当なし (= 機微 permission 未使用) |

### 3.3 共通: 必要なメンタルヘルス免責

`/mental_health_*` route 群 (= mental health risk 設計 spec part 147) は **clinical advice ではなく self-care helper** という stance を Privacy Policy + ストア説明文に明記:

> 本アプリは医療・診療行為を行いません。深刻な症状を感じた場合は専門医へご相談ください。

= [AI-CHARACTER-24] 8 原則 + 設計 spec [`mental_health_risk_spec.md`](../mental_health_risk_spec.md) に既設置の倫理 review section と整合。

---

## 4. プロダクト判断

### 4.1 mobile-only / web-only / hybrid 機能 matrix

| 機能 | Web | iOS | Android | 判断 |
|------|-----|-----|---------|------|
| home / AI 大学 / LP / ranking | ✅ | ✅ | ✅ | hybrid (= core) |
| 競馬予想 (= ML harness) | ✅ | ✅ | ✅ | hybrid |
| ブログ管理 (= dashboard) | ✅ | 🟡 view only | 🟡 view only | mobile = read-only Phase 0 |
| /admin/* (= admin pages) | ✅ | ❌ | ❌ | web-only (= mobile UX 不適) |
| project-gantt (= WBS) | ✅ | 🟡 view only | 🟡 view only | mobile = read-only Phase 0 |
| 動画 pipeline | ✅ | ❌ | ❌ | web-only |
| 食事ログ (= MealLogPage) | ✅ | ✅ | ✅ | mobile が main UX |

**判断ロジック**: 編集 UX (= 大画面 / keyboard) は web-first / 閲覧 + 軽 input は mobile-first.

### 4.2 mobile-specific UX 削除

Flutter Web のままでは以下が mobile UX で問題:

1. **巨大 admin page** (= `admin_analytics_page.dart` 5000+ 行) → mobile では非表示 (= route 制限)
2. **table-heavy widget** (= ranking 等) → mobile は card list view へ自動切替 (=既存 `MediaQuery.of` 分岐)
3. **drag-drop** (= 動画 pipeline 編集) → mobile 非対応 → web-only badge 表示

= 個別実装は Codex hand-off (= 既存 `lib/widgets/responsive_*.dart` pattern 拡張).

---

## 5. リリースゲート設計

### 5.1 Pre-flight checklist (= 配布前 必須)

```
[ ] flutter analyze 0 errors / 0 warnings
[ ] dart format --set-exit-if-changed
[ ] minimal-e2e-gate workflow pass
[ ] ios/Runner/PrivacyInfo.xcprivacy 存在
[ ] android applicationId == ios CFBundleIdentifier == jp.kanta13.jibun
[ ] versionCode / versionName / CFBundleVersion / CFBundleShortVersionString 同期
[ ] Privacy Policy URL アクセス可能 (= /privacy route 200)
[ ] Supabase prod env 接続 OK (= EF auth 200)
[ ] Firebase prod env 接続 OK
[ ] mobile route 制限 (= /admin/* mobile では 404 or redirect)
[ ] アプリアイコン 1024x1024 (iOS) + adaptive icon (Android)
[ ] スプラッシュ画面 (= flutter_native_splash 設定済)
```

### 5.2 GHA workflow gate (= Codex 実装)

```yaml
# .github/workflows/mobile-release.yml (= Codex 実装 spec)
trigger: workflow_dispatch / tag v*.*.*-mobile
jobs:
  android-build:
    - flutter pub get
    - flutter build appbundle --release
    - signing via key.properties (= GitHub secrets injected)
    - upload artifact (= internal track 自動 upload は Phase 1 以降)
  ios-build:
    - macos-latest runner
    - flutter pub get
    - flutter build ipa --release --export-method app-store
    - signing via App Store Connect API key (= secrets)
    - upload artifact (= TestFlight 自動 upload は Phase 1 以降)
  release-notes:
    - generate from git log (= since last v*.*.*-mobile tag)
```

### 5.3 ロールバック設計

ストア配布後の問題発覚時:

1. **Phase 0 (internal/TestFlight)**: 配布 build を kill switch (= remote config flag) で disable / 次 build で fix
2. **Phase 1+ (closed/open)**: ストア側で旧 version への halt 不可能 → **必ず先行 internal で 1 week soak** (= Phase 0 の存在意義)

---

## 6. Hand-off matrix

| 領域 | Owner | 期限 |
|------|-------|------|
| 本 spec ship + Privacy Policy ドラフト | Win Claude | 2026-05-30 (= 本 spec で完了) |
| `/privacy` route + Supabase data flow doc | Win Codex | 2026-05-25 |
| `PrivacyInfo.xcprivacy` 追加 | Win Codex | 2026-05-25 |
| `mobile-release.yml` GHA workflow | Win Codex | 2026-05-30 |
| Android signing config (= keystore + key.properties via GH secrets) | Win Codex | 2026-05-30 |
| iOS signing (= App Store Connect API key + provisioning) | Win Codex | 2026-05-30 |
| mobile route 制限 (= admin/動画 web-only) | Win Codex | 2026-05-25 |
| アプリアイコン 1024x1024 + adaptive icon | Win Claude (= design-skills) | 2026-05-25 |
| TestFlight / Play Console internal 配布実施 | ユーザー (= 自身でストア account 操作) | 2026-05-30 |

---

## 7. PHILOSOPHY-22 9/9 チェック

| 原則 | ✅/❌ | 確認 |
|------|------|------|
| 1. CEO 感 | ✅ | 段階配布で user フィードバック吸収 / 一気にリリースしない |
| 2. ミッション駆動 | ✅ | mobile = ユーザー導線拡大 (= 商品価値増大) |
| 3. 優しい mentor | ✅ | mental health 免責文をストア掲載で押付け回避 |
| 4. 6 部署バランス | ✅ | R&D (build) + マーケ (ストア掲載) + 本社 (リリース判断) 横断 |
| 5. 商品 = 価値 | ✅ | mobile 配布で価値接点増 |
| 6. 資本 = 時間 | ✅ | GHA 自動化で release 工数最小 |
| 7. 資産 vs 負債 | ✅ | 本 spec が長期資産 / TestFlight build が短期検証資産 |
| 8. KPI = 昨日の自分 | ✅ | Phase 0/1/2 段階 KPI 設定 |
| 9. IPO / ウェルビーイング | ✅ | mobile presence = IPO 準備の必須条件 |

**判定: 9/9 ✅**

---

## 8. 関連 docs

- [`docs/STRATEGIC_INTELLIGENCE_2026Q2.md`](STRATEGIC_INTELLIGENCE_2026Q2.md) §3 Google I/O 防衛戦略 (= mobile presence 確立の優先理由)
- [`docs/MULTI_INSTANCE_FLEET.md`](MULTI_INSTANCE_FLEET.md) §Q2-Q3 roadmap (= Mobile P0 / 2026-05-30)
- [`docs/cross-instance-prs/20260507_q2_fleet_strategy_action_guidelines.md`](cross-instance-prs/20260507_q2_fleet_strategy_action_guidelines.md) (= Codex 4 依頼へ #1495 追加候補)
- [`docs/AI_CHARACTER_PRINCIPLES.md`](AI_CHARACTER_PRINCIPLES.md) (= mental health 免責文の根拠)
- [Issue #1495](https://github.com/kanta13jp1/my_web_app/issues/1495)

---

*Win版#132 part 159 / 2026-05-07 / Issue #1495 設計 spec / 期限 2026-05-30 / Win Claude architect 完了 / Win Codex 実装 hand-off / PHILOSOPHY-22 9/9 ✅*
