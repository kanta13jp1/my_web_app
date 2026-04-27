# cross-instance-pr: comparison_page Phase C — 競合ブラウズページ新規

**作成**: PS#4 S75 / 2026-04-27  
**宛先**: VSCode版  
**優先度**: 🟡 MEDIUM  
**推定工数**: 2〜3時間  

---

## 背景

- Phase A+B (2026-04-27): `comparison_page.dart` を StatefulWidget 化し Supabase から pricing/japan_presence をオーバーレイ (commit `2e0be914`)
- pricing Batch1-10 (2026-04-27): 全172社+重複ID の `pricing_tier / pricing_start_usd / pricing_notes_ja / japan_presence_level / japan_notes_ja` を 100% 充填 (commits `795f2f37`〜`09b691d1`)
- **課題**: `/vs-{id}` ルートは original 21社のみ。172社全体を発見・閲覧できるページがない

---

## 実装内容

### 1. 新規ページ `lib/pages/competitor_browse_page.dart`

```dart
// ルート: /competitors
// アクセス: 全ユーザー (anon OK — 公開情報のみ)
```

#### UI 構成

```
[競合ランドスケープ]  ← AppBar タイトル
[フィルタバー]
  pricing_tier: [すべて] [無料] [Freemium] [有料] [Enterprise]
  japan_presence: [すべて] [Dominant] [Strong] [Growing] [Limited]
  (オプション) category ドロップダウン
[ソートボタン] 脅威度 / overlap / 名前
[競合グリッド] 2列(モバイル) / 3列(タブレット) / 4列(デスクトップ)
  ┌──────────────────────┐
  │  🔔  Notion           │
  │  freemium • $16/月    │
  │  🇯🇵 Dominant         │
  │  overlap: 9 / 高脅威  │
  └──────────────────────┘
```

#### データフェッチ

```dart
// Supabase クエリ (RLS: is_active=true のみ)
final rows = await Supabase.instance.client
    .from('competitors')
    .select('id, display_name, emoji, category, pricing_tier, pricing_start_usd, '
            'japan_presence_level, our_overlap_score, threat_level')
    .eq('is_active', true)
    .order('our_overlap_score', ascending: false);
```

#### カードタップ動作

- `id` が `/vs-*` ルートに存在する場合 → `Navigator.pushNamed('/vs-$id')`
- 存在しない場合 → スナックバー「詳細ページは準備中です」または何もしない

#### _PricingBadge / _JapanPresenceBadge

`comparison_page.dart` の既存ウィジェットを `lib/widgets/competitor_badges.dart` に切り出し (Phase C で共用)。

---

### 2. ルート追加 `lib/main.dart`

```dart
case '/competitors':
  return MaterialPageRoute(
    builder: (_) => const CompetitorBrowsePage(),
    settings: const RouteSettings(name: '/competitors'),
  );
```

### 3. ランディングページからリンク `lib/pages/landing_page.dart`

既存の「競合比較」ボタン周辺に「全172社を見る →」ボタンを追加。  
またはフッターに `/competitors` リンクを追加。

### 4. `web/sitemap.xml` に追加

```xml
<url>
  <loc>https://my-web-app-b67f4.web.app/competitors</loc>
  <changefreq>weekly</changefreq>
  <priority>0.7</priority>
</url>
```

---

## デザイン要件 (`docs/DESIGN.md` 参照)

- **ダークテーマ**: `surface = #1E1B2E`, `primary = #FF6B35` (オレンジ)
- **pricing_tier バッジ色**:
  - `free` → `Colors.green[700]`
  - `freemium` → `Colors.blue[700]`
  - `paid` → `Colors.orange[700]`
  - `enterprise` → `Colors.purple[700]`
- **japan_presence_level バッジ色**:
  - `dominant` → `Colors.red[800]`
  - `strong` → `Colors.orange[700]`
  - `growing` → `Colors.green[700]`
  - `limited` → `Colors.grey[600]`
- カードは `BorderRadius.circular(12)`, `elevation: 2`
- フィルタバーは `SingleChildScrollView` + `Wrap` (横スクロール対応)

---

## フィルタ実装のヒント

```dart
// フィルタ状態
String? _selectedPricingTier; // null = すべて
String? _selectedJapanPresence;

// フィルタ適用
List<Map<String, dynamic>> get _filtered => _competitors.where((c) {
  if (_selectedPricingTier != null && c['pricing_tier'] != _selectedPricingTier) return false;
  if (_selectedJapanPresence != null && c['japan_presence_level'] != _selectedJapanPresence) return false;
  return true;
}).toList();
```

---

## 完了条件

- [ ] `/competitors` にアクセスすると全172社のグリッドが表示される
- [ ] pricing_tier フィルタが動作する
- [ ] japan_presence_level フィルタが動作する
- [ ] 既存 21社のカードをタップすると `/vs-{id}` に遷移する
- [ ] `dart format` / `flutter analyze` 0 issues
- [ ] sitemap.xml に `/competitors` 追加済み

---

## 補足: 既存バッジウィジェットの場所

現在 `comparison_page.dart` 内に `_PricingBadge` と `_JapanPresenceBadge` がプライベートウィジェットとして存在。  
新ページで使う場合は `lib/widgets/competitor_badges.dart` に昇格させること。

---

*PS#4 S75 / 担当: VSCode版*
