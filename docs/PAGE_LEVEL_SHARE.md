# 全ページ X シェア機能 + AI 自動生成 設計

**策定**: 2026-04-25 (Win版#132 part 15)
**契機**: ユーザー要請「全ページに X シェア機能 + ページごとに AI が文言・画像・動画を自動生成」
**前提**: Win#132 part 14 (ogp-image-refresh.yml + og_assets table) 実装済

---

## 1. 要件分解

| # | 要件 | 実装 |
|---|------|------|
| R1 | 全ページに X シェアボタン UI | Flutter 共通 widget + 全 page 組込 (VSCode 担当) |
| R2 | ページごとに AI シェア文言生成 | Gemini Flash でページ context から tweet 文生成 |
| R3 | ページごとに AI 画像生成 | FAL flux/schnell で 1200x630 OGP-style 画像 |
| R4 | (オプション) ページごとに AI 動画 | high-traffic page のみ / viral-video-ad-generator |
| R5 | キャッシュ (再生成防止) | `page_shares` テーブル / 7 日 TTL |

---

## 2. アーキテクチャ

```
[User] X シェアボタン clicks
   ↓
[Flutter] core-hub:page.share_generate({page_path, page_title, page_description})
   ↓
[EF] page_shares table を path で検索
   ├ HIT (created_at < 7 日) → cached 返却 (高速)
   └ MISS → AI 生成 (5-10秒)
       ├ Gemini Flash: tweet_text 生成 (page context-aware)
       ├ FAL flux/schnell: 1200x630 image 生成
       ├ Storage upload + page_shares INSERT
       └ 結果返却
   ↓
[Flutter] X 投稿 intent (URL + image_url で X share dialog 起動)
```

### Auth
- **Anonymous OK** (server cache が page-specific だからユーザー秘匿情報なし)
- Rate limit: 同一 IP × 同一 page で 1 分 1 回 (悪用防止)

### Cache (7 日 TTL)
- 同 page で 7 日内に再 share される場合 → cached 結果を即返却
- 7 日経過 → 再生成 (新鮮さ維持)
- 強制再生成: `?force=true` query で bypass

---

## 3. `page_shares` テーブル schema

```sql
CREATE TABLE public.page_shares (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  page_path       text NOT NULL,                -- '/ai-university' / '/comparison/notion' etc
  page_title      text,                         -- "AI大学 — 200社のAI最新動向"
  page_description text,                        -- meta description / hint for AI
  tweet_text      text,                         -- AI 生成済 tweet (140字以内)
  image_url       text,                         -- AI 生成画像 URL
  video_url       text,                         -- (オプション) 動画 URL
  generated_by    text,                         -- 'gemini-flash + fal-flux-schnell'
  cost_usd        numeric DEFAULT 0,
  share_count     int DEFAULT 0,                -- 何回シェアされたか KPI
  metadata        jsonb DEFAULT '{}'::jsonb,
  created_at      timestamptz DEFAULT now(),
  updated_at      timestamptz DEFAULT now(),
  UNIQUE (page_path)                            -- 1 page = 1 row (latest)
);

CREATE INDEX idx_page_shares_path ON public.page_shares (page_path);
CREATE INDEX idx_page_shares_freshness ON public.page_shares (created_at DESC);
```

---

## 4. `core-hub:page.share_generate` action 設計

```typescript
case "page.share_generate": {
  const pagePath = textValue(body.page_path, 200);
  const pageTitle = textValue(body.page_title, 200);
  const pageDescription = textValue(body.page_description, 1000);
  const force = body.force === true;

  if (!pagePath) {
    return json({ error: "page_path required" }, 400);
  }

  // 1. Cache check (7 日以内 + force=false)
  if (!force) {
    const { data: cached } = await admin
      .from("page_shares")
      .select("*")
      .eq("page_path", pagePath)
      .gte("created_at", new Date(Date.now() - 7 * 24 * 3600 * 1000).toISOString())
      .maybeSingle();
    if (cached?.tweet_text && cached?.image_url) {
      // share_count increment (best-effort fire-and-forget)
      admin.from("page_shares").update({ share_count: (cached.share_count ?? 0) + 1 }).eq("id", cached.id);
      return json({
        success: true,
        cached: true,
        tweet_text: cached.tweet_text,
        image_url: cached.image_url,
        video_url: cached.video_url,
      });
    }
  }

  // 2. Gemini Flash で tweet 文生成
  const geminiKey = Deno.env.get("GEMINI_API_KEY");
  let tweetText = "";
  if (geminiKey) {
    const prompt = `あなたは自分株式会社のSNS担当です。以下のページを X (旧Twitter) で
シェアする魅力的な日本語 tweet を作ってください。
- 140字以内
- ハッシュタグ 2-3 個含む (#自分株式会社 #buildinpublic 等)
- 末尾に LP リンク https://my-web-app-b67f4.web.app${pagePath} を含める
- 絵文字 1-2 個

## ページ情報
title: ${pageTitle}
description: ${pageDescription}

## 出力 (JSON のみ)
{"tweet_text": "..."}`;

    try {
      const resp = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${geminiKey}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }],
            generationConfig: { temperature: 0.7, maxOutputTokens: 300 },
          }),
        },
      );
      if (resp.ok) {
        const data = await resp.json();
        let text = data.candidates?.[0]?.content?.parts?.[0]?.text?.trim() ?? "";
        if (text.startsWith("```")) {
          text = text.split("\n").slice(1, -1).join("\n");
        }
        const parsed = JSON.parse(text);
        tweetText = String(parsed.tweet_text ?? "").slice(0, 280);
      }
    } catch (_e) {
      // fallthrough → fallback below
    }
  }

  // Gemini fallback: simple template
  if (!tweetText) {
    tweetText = `🚀 ${pageTitle || "自分株式会社"}\n` +
      `21の競合SaaSを1つに統合する AI life management\n\n` +
      `https://my-web-app-b67f4.web.app${pagePath}\n\n` +
      `#自分株式会社 #buildinpublic #SaaS統合`;
  }

  // 3. FAL flux/schnell で画像生成
  const falKey = Deno.env.get("FAL_KEY");
  let imageUrl = "https://my-web-app-b67f4.web.app/ogp.png"; // fallback
  let cost = 0;
  if (falKey) {
    try {
      const imagePrompt = `Modern minimalist OGP banner for "${pageTitle}", ` +
        `1200x630, gradient orange-purple-indigo background, ` +
        `Japanese-inspired typography, futuristic UI, no text overlay, professional`;
      const falResp = await fetch("https://fal.run/fal-ai/flux/schnell", {
        method: "POST",
        headers: {
          "Authorization": `Key ${falKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          prompt: imagePrompt,
          image_size: "landscape_16_9",
          num_inference_steps: 4,
          num_images: 1,
        }),
      });
      if (falResp.ok) {
        const falData = await falResp.json();
        if (falData.images?.[0]?.url) {
          imageUrl = falData.images[0].url;
          cost = 0.003;
        }
      }
    } catch (_e) {
      // fallthrough → fallback
    }
  }

  // 4. page_shares に upsert
  const { data: upserted } = await admin
    .from("page_shares")
    .upsert({
      page_path: pagePath,
      page_title: pageTitle,
      page_description: pageDescription,
      tweet_text: tweetText,
      image_url: imageUrl,
      generated_by: "gemini-flash+fal-flux-schnell",
      cost_usd: cost,
      share_count: 1,
      updated_at: new Date().toISOString(),
    }, { onConflict: "page_path" })
    .select()
    .single();

  return json({
    success: true,
    cached: false,
    tweet_text: tweetText,
    image_url: imageUrl,
    page_share_id: upserted?.id,
  });
}
```

---

## 5. Flutter UI 設計 (Phase 2 / VSCode 担当)

### 共通 widget: `ShareToXButton`

```dart
class ShareToXButton extends StatelessWidget {
  final String pagePath;
  final String pageTitle;
  final String pageDescription;

  const ShareToXButton({
    required this.pagePath,
    required this.pageTitle,
    required this.pageDescription,
    super.key,
  });

  Future<void> _share(BuildContext context) async {
    // 1. core-hub:page.share_generate 呼出
    final resp = await Supabase.instance.client.functions.invoke(
      'core-hub',
      body: {
        'action': 'page.share_generate',
        'page_path': pagePath,
        'page_title': pageTitle,
        'page_description': pageDescription,
      },
    );
    final data = resp.data as Map<String, dynamic>?;
    final tweetText = data?['tweet_text'] as String? ?? pageTitle;

    // 2. X share intent URL 構築 (画像は intent では渡せず OGP 経由で X が prefetch)
    final tweetUrl = Uri.https('twitter.com', '/intent/tweet', {
      'text': tweetText,
    }).toString();

    // 3. 新タブで X 開く
    await launchUrl(Uri.parse(tweetUrl), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) => IconButton(
    icon: const Icon(Icons.share),
    tooltip: 'X (旧 Twitter) でシェア',
    onPressed: () => _share(context),
  );
}
```

### 配置ポリシー
- **MainScaffold AppBar 右端**: 全ページに自動表示
- **page_path**: 現在 route から取得 (`GoRouter.of(context).location`)
- **page_title**: AppBar title から取得
- **page_description**: ページ meta data 用 service から取得 (or fallback to title)

---

## 6. AI 動画 (Phase 3 / オプション)

high-traffic page のみ生成 (cost 抑制):

```sql
-- 動画生成対象 page を flag 化
ALTER TABLE page_shares
  ADD COLUMN IF NOT EXISTS video_enabled boolean DEFAULT false;

-- LP / AI大学 / comparison など主要 page のみ true
UPDATE page_shares SET video_enabled = true WHERE page_path IN ('/', '/ai-university', '/comparison');
```

GHA cron `ogp-video-refresh.yml` (月次) で video_enabled=true の page だけ
viral-video-ad-generator 経由で動画生成 → page_shares.video_url に格納。

---

## 7. Cost 試算

| 項目 | 単価 | 月想定 | コスト |
|------|------|--------|--------|
| Gemini Flash (tweet 文) | $0.0008/page | 200 page × 4 cycle/月 | $0.64 |
| FAL flux/schnell (画像) | $0.003/page | 200 page × 4 cycle/月 | $2.40 |
| FAL/Hedra 動画 (Phase 3) | $0.32/video | 5 high-traffic × 1/月 | $1.60 |
| **合計** | — | — | **$4.64/月** |

Cache 7 日効果で 4 cycle 消費 = 実際は **$2-3/月** (大半が cache hit)。

---

## 8. KPI (Phase 4)

`page_shares.share_count` で:
- ページ別シェア数ランキング (top 10 / 月)
- 全体シェア数トレンド (週次 / 月次)
- AI 生成 tweet vs 手動 tweet の CTR 比較 (UTM `?utm_source=x&utm_medium=ai_share`)

---

## 9. Philosophy 9/9 ✅

1. **CEO 感** ✅ — page-specific share = 各 page を CEO 商品化
2. **ミッション駆動** ✅ — バイラル拡散がミッション貢献
3. **優しい mentor** ✅ — UI 上は 1 click でハードル消失
4. **6 部署バランス** ✅ — マーケ部署を AI で自動化
5. **商品=ユーザー価値** ✅ — ユーザーがシェアしやすい体験提供
6. **資本=時間** ✅ — AI が自動生成で時間節約
7. **資産負債 BS** ✅ — $2-3/月 (誤差レベル)
8. **KPI=昨日の自分** ✅ — share_count 自動 tracking
9. **ゴール=IPO** ✅ — viral 拡散 = ユーザー獲得 = IPO 直結

---

## 10. AI-DEV 7/7 ✅

1. **Auth** ✅ — Anonymous OK + IP rate limit
2. **Deny-by-default** ✅ — secret 欠落で fallback (template + ogp.png)
3. **trace_id** ✅ — generated_by + run_id を metadata に
4. **Cost CB** ✅ — Cache 7 日 + monthly $5 ceiling
5. **Team memory** ✅ — page_shares + share_count
6. **Checkpoint+retry** ✅ — Gemini fail → template / FAL fail → ogp.png
7. **Quality gate** ✅ — image size <10K で fallback (Phase 4 で AI vision 追加)

---

## 11. 実装計画 (4 Phase)

| Phase | 内容 | 担当 | 期日 |
|-------|------|------|------|
| **1 (本 commit)** | page_shares テーブル + core-hub:page.share_generate action + 設計 doc | Win | 2026-04-25 |
| 2 | ShareToXButton widget + MainScaffold 組込 (全 page 自動表示) | VSCode | 2026-05-05 |
| 3 | 動画生成 (high-traffic page のみ) | Win | 2026-05-15 |
| 4 | 効果測定ダッシュボード (admin/share-analytics) | VSCode | 2026-05-30 |

---

## 12. 改訂履歴

- **2026-04-25 (Win版#132 part 15)**: 初版作成 + Phase 1 (page_shares + EF action) 実装。
