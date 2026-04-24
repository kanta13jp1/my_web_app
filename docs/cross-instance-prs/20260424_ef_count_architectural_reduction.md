# Cross-Instance PR: EF Count 85→50 Architectural Reduction Plan

**作成**: PS#6 S31 2026-04-24  
**宛先**: Win版 (アーキテクチャ判断)  
**優先度**: Medium (cap 超過だが動作中)  
**前提**: PS#5/PS#6 の hub migration 継続中 — このドキュメントはバックログ整理

---

## 現状

| 項目 | 値 |
|------|-----|
| EF source dirs (supabase/functions/) | **85** |
| EF cap ルール ([EF-CAP-50]) | **50** |
| オーバー | **+35** |
| 既存 hubs | admin-hub / ai-hub / app-hub / core-hub / enterprise-hub / growth-hub / lifestyle-hub / media-hub / schedule-hub / social-commerce-hub / social-feed / tools-hub |

**重要発見 (PS#6 S30)**: 85 EF source dirs はすべて Flutter から invoke されており dead EF は 0。
単純削除不可 — hub migration 必須。

---

## 既存 Hub への統合候補 (優先度順)

### 1. enterprise-hub (現在: 多数のビジネス系 EF が standalone)
統合候補 (推定 -15):
- `access-control` → enterprise-hub:access.*
- `document-esignature` → enterprise-hub:doc.sign / doc.list
- `email-template-builder` → enterprise-hub:email.template.*
- `leave-management` → enterprise-hub:leave.*
- `performance-review` → enterprise-hub:review.*
- `recruitment-job-board` → enterprise-hub:recruit.*
- `legal-compliance-manager` → enterprise-hub:compliance.*
- `vehicle-fleet-manager` → enterprise-hub:fleet.*
- `video-meeting-manager` → enterprise-hub:meeting.*
- `inventory-barcode` → enterprise-hub:inventory.*
- `github-pr-manager` → enterprise-hub:pr.*
- `dns-domain-manager` → enterprise-hub:dns.*
- `form-builder` → enterprise-hub:form.*
- `password-vault` → enterprise-hub:vault.*
- `two-factor-auth` → admin-hub:auth.2fa.*

### 2. lifestyle-hub (現在: 多数のライフスタイル系 EF が standalone)
統合候補 (推定 -10):
- `fitness-health-tracker` → lifestyle-hub:fitness.*
- `recipe-meal-planner` → lifestyle-hub:recipe.*
- `travel-itinerary-planner` → lifestyle-hub:travel.*
- `pet-care-manager` → lifestyle-hub:pet.*
- `family-sharing-manager` → lifestyle-hub:family.*
- `home-iot-manager` → lifestyle-hub:iot.*
- `carbon-footprint-tracker` → lifestyle-hub:eco.*
- `elearning-course-manager` → lifestyle-hub:elearn.*
- `language-learning` → lifestyle-hub:lang.*
- `emergency-contacts` → lifestyle-hub:emergency.*

### 3. media-hub (現在: 多数のメディア系 EF が standalone)
統合候補 (推定 -7):
- `guitar-recording-studio` → media-hub:guitar.*
- `photo-gallery-manager` → media-hub:gallery.*
- `podcast-manager` → media-hub:podcast.*
- `screen-recorder` → media-hub:screen.*
- `viral-video-generator` → media-hub:video.generate
- `viral-video-ad-generator` → media-hub:video.ad
- `music-playlist-manager` → media-hub:playlist.*

### 4. tools-hub (現在: ユーティリティ系が散在)
統合候補 (推定 -5):
- `qr-code-generator` → tools-hub:qr.*
- `mindmap-diagram` → tools-hub:mindmap.*
- `virtual-whiteboard` → tools-hub:whiteboard.*
- `bookmark-sync` → tools-hub:bookmark.*
- `smart-inbox-triage` → tools-hub:inbox.*

### 5. social-commerce-hub (現在: 取引系が散在)
統合候補 (推定 -4):
- `auction-marketplace` → social-commerce-hub:auction.*
- `loyalty-points` → social-commerce-hub:loyalty.*
- `donation-crowdfunding` → social-commerce-hub:donation.*
- `event-ticketing` → social-commerce-hub:ticket.*

---

## 移行対象外 (standalone 維持が妥当)

| EF | 理由 |
|----|------|
| `ai-assistant` | 大規模マルチ AI fallback ロジック |
| `get-home-dashboard` | ホーム画面統合データ — 巨大 |
| `health-check` | SERVICE_ROLE_KEY 認証 (infra-health-check GHA 専用) |
| `semantic-search` | 重いベクター処理 |
| `check-competitor-updates` | 21社 HTTP チェック (長時間) |
| `discord-notifications` | Webhook 固定 |
| `line-notifications` | LINE API 固定 |
| `schedule-hub` | スケジュール系ハブ |
| `growth-hub` | グロース系ハブ |
| `social-feed` | ソーシャル系ハブ |

---

## 実施方針

1. **PS#5 継続**: 各 EF を対応 hub の action として実装 → Flutter 側 EF 名を hub に変更
2. **PS#6 継続**: 移行完了した EF の source dir 削除 → DEAD_LIST に追加
3. **優先順**: enterprise-hub 15本 → lifestyle-hub 10本 → media-hub 7本 = **32本消化で 85→53**
   さらに tools-hub 5本 → social-commerce-hub 4本 = **合計 41本で 85→44** (cap達成)

**見積もり**: 1本/セッション = 約 41 セッション。PS#5+PS#6 並行で ~20 セッション。

---

## 依頼事項 (Win版)

- アーキテクチャ判断: enterprise-hub への大量 migration は hub index.ts が肥大化しないか?
  → 案A: enterprise-hub を enterprise-hr-hub / enterprise-ops-hub に分割
  → 案B: 現行通り enterprise-hub にすべて追加 (action prefix で分類)
- 判断後、PS#5/PS#6 migration backlog の優先順を更新すること
