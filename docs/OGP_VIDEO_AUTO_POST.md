# OGP 画像自動更新 + AI 動画 X 投稿 設計

**策定**: 2026-04-25 (Win版#132 part 14)
**契機**: ユーザー要請「OGP 画像が古い / scheduled task で自動更新 / AI 生成動画 + リンク付き X 投稿」

---

## 1. 現状分析

### 1-1. OGP 現状
- `web/index.html` の `og:image` = `https://my-web-app-b67f4.web.app/ogp.png` (固定)
- `web/ogp.png` 現役 (= cache buster 付きで deploy-prod が配信) / 旧 `ogp_v1.png` / `ogp_v2.png` / `ogp_v3.png` は未参照のため削除済 (egress 削減 / 2026-06-21)
- **問題**:
  - 機能追加されたのに OGP 反映なし
  - X cache が古い image を 7-30 日保持 → URL 変更で cache buster 必要
  - 季節性 / トレンド反映無し

### 1-2. 既存 AI 動画 / 画像 infra
- ✅ `viral-video-ad-generator` EF 実装済 (FAL.AI flux/schnell + Hedra)
- ✅ `FAL_KEY` / `HEDRA_API_KEY` secret 設定済
- ✅ Dark War / feature_highlight 等の AD_TEMPLATES 整備済
- ❌ **OGP image refresh task 無し** (未実装)
- ❌ **X 投稿は schedule-hub:x.post が log のみ** (実 API call 無し)
- ✅ X_OAUTH_* secret は CLAUDE.md / COMPRESSED_PROMPT で言及あり (post-x-update 旧 EF で使用)

---

## 2. 3-Phase 計画

| Phase | 内容 | 担当 | 期日 |
|-------|------|------|------|
| **1 (本 commit)** | OGP image 週次自動更新 (FAL flux/schnell + GHA cron + git commit) | Win | 2026-04-30 |
| 2 | 動画自動生成 (viral-video-ad-generator 既存 API call) | Win | 2026-05-07 |
| 3 | X 自動投稿 (動画 + LP リンク / X API v2 OAuth 1.0a) | Win | 2026-05-15 |
| 4 | OGP 効果測定 (CTR / engagement KPI ダッシュボード) | VSCode | 2026-05-30 |

---

## 3. Phase 1: OGP 画像自動更新

### 3-1. アーキテクチャ

```
GHA cron (週次 / 月曜 09:00 JST)
    ↓
1. FAL flux/schnell で 1200x630 OGP 画像生成
   prompt: "21の競合 SaaS を統合する自分株式会社..."
2. PNG download → web/ogp-YYYYWW.png に保存
3. web/index.html の og:image URL を週番号付き URL に更新
4. og_assets テーブルに記録 (生成履歴 + 失敗 log)
5. git commit + push (auto-deploy で反映)
6. X cache buster: 旧 URL を新 URL でリプレース → X が再 crawl
```

### 3-2. AI image prompt (週変更可能)

```yaml
weekly_prompts:
  base: "Modern minimalist OGP banner for life management SaaS, 1200x630, Japanese typography, gradient orange-purple, futuristic UI elements floating, no text"
  this_week: "+spring vibrant cherry blossom motif"  # 季節 / 月変更
  this_month_event: "+Series A milestone celebration"  # mvp-launch 直前等
```

実装: GHA で `date` から週番号取得 → prompt template 差替え。

### 3-3. og_assets テーブル

```sql
CREATE TABLE public.og_assets (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_type      text NOT NULL CHECK (asset_type IN ('ogp_image','ad_video','x_post')),
  url             text NOT NULL,
  prompt          text,
  generated_by    text,                   -- 'fal-flux-schnell' / 'fal-ltx2' / 'manual'
  cost_usd        numeric DEFAULT 0,
  posted_to_x     boolean DEFAULT false,
  x_post_id       text,                   -- X 投稿の tweet_id
  metadata        jsonb DEFAULT '{}'::jsonb,
  created_at      timestamptz DEFAULT now()
);
```

### 3-4. Cost
- FAL flux/schnell: $0.003/image
- 週次 1 枚 = **$0.012/月** (誤差レベル)
- X 投稿 = 無料 (OAuth 1.0a tier 内)

---

## 4. Phase 2: AI 動画自動生成

### 4-1. 既存 `viral-video-ad-generator` EF を call

```
GHA cron (月次 / 第一月曜 10:00 JST)
    ↓
POST /functions/v1/viral-video-ad-generator
  body: {action: "generate", template: "dark_war"}
    ↓
EF 内:
  1. AD_TEMPLATES から動画スクリプト取得
  2. FAL flux で keyframe 画像 (5 枚) 生成
  3. Hedra avatar narration → MP4 (15-30秒)
  4. Supabase Storage に upload
  5. og_assets に登録
    ↓
GHA: video URL を取得 → og_assets.posted_to_x=false で X 投稿待ち queue
```

### 4-2. 既存 Template 活用
- `dark_war`: 21 SaaS と戦う / Notion・Slack・MoneyForward
- `feature_highlight`: 実装機能ショーケース
- `vs_competitor`: 特定競合 (Notion 等) との比較
- 月替わり ローテーション (Jan→dark_war / Feb→feature_highlight / Mar→vs_competitor / ...)

### 4-3. Cost
- FAL flux 5 枚: $0.015
- Hedra avatar: ~$0.30 / 30 秒
- 月 1 動画 = **$0.32/月**

---

## 5. Phase 3: X 自動投稿

### 5-1. アーキテクチャ

既存 `schedule-hub:x.post` action は log のみ → 実 API call に拡張:

```typescript
case "x.post": {
  // 1. media upload (X API v2 v1.1 media/upload)
  if (body.video_url) {
    const mediaId = await uploadMediaToX(body.video_url, x_oauth);
    // media_id を tweet body に attach
  }
  // 2. tweet create (X API v2 /2/tweets)
  const tweet = await postTweet({
    text: body.text,
    media: { media_ids: [mediaId] },
  }, x_oauth);
  // 3. og_assets.posted_to_x=true / x_post_id 記録
  await admin.from('og_assets').update({...}).eq('id', body.asset_id);
  return json({ success: true, tweet_id: tweet.id });
}
```

### 5-2. X API tier 制限
- Free tier: tweets 50/month / media upload 含む
- 本目的 (月 4 投稿: 週次 OGP + 月次 video) = 無料枠で十分

### 5-3. Tweet template

```
✨ 自分株式会社 - {{milestone}} 達成
21の競合SaaSを1つに統合する AI life management

🎁 完全無料で開始: https://my-web-app-b67f4.web.app/

#自分株式会社 #buildinpublic #SaaS統合 #FlutterWeb
```

---

## 6. Phase 4: 効果測定 KPI

`og_assets` テーブル + Google Analytics:
- OGP CTR (X → LP 流入数 / OGP 表示数)
- 動画再生数 (X analytics API)
- 投稿後 7 日内のサインアップ数 (UTM パラメータ追跡)

---

## 7. Philosophy 9 原則 ✅

1. **CEO 感** ✅ (週次自動だが、AD_TEMPLATES の選択は人間がローテ管理)
2. **ミッション駆動** ✅ (集客 = ミッション)
3. **優しい mentor** ✅
4. **6 部署バランス** ✅ (マーケ部署の自動化)
5. **商品=ユーザー価値** ⚠️ → 動画品質 quality gate 必須 (低品質なら post 中断)
6. **資本=時間** ✅
7. **資産負債 BS** ✅ ($0.33/月 = 軽微)
8. **KPI=昨日の自分** ✅ (週次 CTR トレンド)
9. **ゴール=IPO** ✅ (PR 効果 = IPO 直結)

→ **9/9 ✅** (5 のみ要 quality gate)

---

## 8. AI-DEV 7 原則 ✅

1. **Auth** ✅ FAL_KEY / HEDRA_API_KEY / X_OAUTH_*
2. **Deny-by-default** ✅ secret 欠落で skip
3. **trace_id** ✅ GHA run_id を og_assets.metadata に
4. **Cost CB** ✅ 月 $1 ceiling (FAL daily cap で防護)
5. **Team memory** ✅ og_assets table
6. **Checkpoint+retry** ✅ 失敗 record は次 cron で retry
7. **Quality gate** ✅ AI 画像 quality score < 7 なら post 中断 (将来 vision 検証)

→ **7/7 ✅**

---

## 9. 改訂履歴

- **2026-04-25 (Win版#132 part 14)**: 初版作成。3-Phase 設計 + Phase 1 (OGP) GHA cron 実装。
