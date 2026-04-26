# Cross-Instance PR: comparison_page.dart → Supabase fetch 移行

**作成**: PS#4 S70 / 2026-04-27  
**依頼先**: VSCode版 (Flutter 担当)  
**優先度**: HIGH — pricing + japan_presence データが DB にあるが UI に表示されていない  
**推定工数**: 3-4 hours / 500-700行変更  
**ブロッカーなし**: Supabase テーブルは全て deploy 済み

---

## 背景

`lib/pages/comparison_page.dart` (2189行) は現在 const map (`_competitorInfo`) で
21社をハードコード。PS#4 が以下のデータを DB に投入済みだが UI に反映されていない:

| テーブル | 追加済みデータ | commit |
|---------|-------------|--------|
| `competitors` | 172社 / jp_strength + jp_weakness | e4fe33fd |
| `competitor_features` | 172社 × 10機能 | a9cc556c |
| `competitors.pricing_tier/usd/notes_ja` | 41社 | 24fd20b4 |
| `competitors.japan_presence_level/launch_year/users` | 43社 | 6705bf1b |

**目標**: const map → Supabase fetch にリファクタして、DB データを UI に自動反映する。

---

## 実装仕様

### 1. 新モデルクラス追加 (lib/models/competitor_model.dart 新規)

```dart
class CompetitorModel {
  final String id;
  final String displayName;
  final String category;
  final String? description;
  final String? jpStrength;
  final String? jpWeakness;
  final String? threatLevel;         // 'critical' / 'high' / 'medium' / 'low'
  final String? pricingTier;         // 'free' / 'freemium' / 'paid' / 'enterprise'
  final double? pricingStartUsd;
  final String? pricingNotesJa;
  final String? japanPresenceLevel;  // 'dominant' / 'strong' / 'growing' / 'limited' / 'not_present'
  final int? japanLaunchYear;
  final List<CompetitorFeatureModel> features;

  factory CompetitorModel.fromJson(Map<String, dynamic> json) { ... }
}

class CompetitorFeatureModel {
  final String featureKey;
  final String featureNameJa;
  final bool hasFeature;
  final String jibunStatus; // 'done' / 'inProgress' / 'planned' / 'notYet'

  factory CompetitorFeatureModel.fromJson(Map<String, dynamic> json) { ... }
}
```

### 2. Supabase fetch ロジック

`ComparisonPage.build()` に `FutureBuilder` を追加:

```dart
// supabase query
final data = await supabase
    .from('competitors')
    .select('*, competitor_features(*)')
    .eq('id', competitorKey)
    .maybeSingle();
```

**フォールバック**: fetch 失敗 or 404 → 既存 `_competitorInfo` const map を使用
(後方互換を維持し、21社以外のページも安全に動く)

### 3. `_CompetitorInfo` へのマッピング

DB フィールド → `_CompetitorInfo` の対応:

| DB カラム | `_CompetitorInfo` フィールド | 変換ルール |
|-----------|---------------------------|---------| 
| `display_name` | `name` | そのまま |
| `description` | `tagline` | NULL なら const map の tagline を使用 |
| `jp_weakness` | `painPoints` | `\n` or `。` で split して List<String> に変換 |
| `threat_level` | `accentColor` | critical→Red / high→Orange / medium→Amber / low→Green / null→Indigo |
| `competitor_features` rows | `features` | `feature_name_ja` + `has_feature` + `jibun_status=='done'` |
| emoji | — | 既存 const map から emoji を引く (DB にない) |

### 4. 新 UI 要素: pricing バッジ

`_ComparisonShell` の competitorName 下に追加:

```dart
// pricing tier バッジ
if (competitor.pricingTier != null) ...[
  const SizedBox(height: 8),
  Row(children: [
    _PricingBadge(tier: competitor.pricingTier!),
    if (competitor.pricingStartUsd != null) ...[
      const SizedBox(width: 8),
      Text(
        '最安 \$${competitor.pricingStartUsd!.toStringAsFixed(2)}/月',
        style: TextStyle(color: _textSecondary, fontSize: 12),
      ),
    ],
    if (competitor.pricingNotesJa != null) ...[
      const SizedBox(width: 4),
      Tooltip(
        message: competitor.pricingNotesJa!,
        child: Icon(Icons.info_outline, size: 14, color: _textMuted),
      ),
    ],
  ]),
],

// pricing badge widget
class _PricingBadge extends StatelessWidget {
  final String tier;
  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (tier) {
      'free'       => ('完全無料', Colors.green),
      'freemium'   => ('無料プランあり', Colors.teal),
      'paid'       => ('有料', Colors.orange),
      'enterprise' => ('要見積', Colors.blueGrey),
      _            => ('?', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
```

### 5. 新 UI 要素: japan_presence バッジ

competitorName 下 (pricing の横) に追加:

```dart
if (competitor.japanPresenceLevel != null) ...[
  const SizedBox(width: 8),
  _JapanPresenceBadge(level: competitor.japanPresenceLevel!),
],

class _JapanPresenceBadge extends StatelessWidget {
  final String level;
  @override
  Widget build(BuildContext context) {
    final (emoji, label, color) = switch (level) {
      'dominant'    => ('🇯🇵', '日本No.1', Colors.red),
      'strong'      => ('🇯🇵', '日本主要', Colors.orange),
      'growing'     => ('📈', '日本成長中', Colors.amber),
      'limited'     => ('🌐', '日本限定的', Colors.blueGrey),
      'not_present' => ('⚠️', '日本未展開', Colors.grey),
      _             => ('', '', Colors.grey),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$emoji $label', style: TextStyle(color: color, fontSize: 11)),
    );
  }
}
```

### 6. `_relatedCompetitors` を DB から取得

現在: `_competitorInfo.keys` からの static list  
変更後: `supabase.from('competitors').select('id,display_name,category').eq('is_active', true).order('sort_order')` で全社取得 → ページネーション表示

---

## 移行フェーズ (推奨)

| フェーズ | 内容 | リスク |
|---------|------|--------|
| **Phase A** | `CompetitorModel` + fetch ロジック追加、フォールバック維持 | Low |
| **Phase B** | pricing/japan_presence バッジ表示追加 | Low |
| **Phase C** | `_relatedCompetitors` を DB fetch に変更 | Medium (ページ数依存) |
| **Phase D** | const map 削除 (DB が full に埋まってから) | 後回し可 |

**Phase A+B だけでも十分な価値あり。** Phase C/D は後続 session でも可。

---

## テスト項目

- [ ] `/vs-notion` → DB fetch 成功 → pricing + japan_presence バッジ表示
- [ ] `/vs-evernote` → DB fetch 成功
- [ ] `/vs-unknown-competitor` → フォールバック (const map の `_defaultInfo`) 表示
- [ ] pricing_tier=NULL の競合 → バッジなし (エラーなし)
- [ ] `flutter analyze` 0件
- [ ] 本番デプロイ後 `/vs-notion` 動作確認

---

## Supabase クエリ参考

```sql
-- 動作確認用 (comparison_page のデータ確認)
SELECT id, display_name, pricing_tier, pricing_start_usd, japan_presence_level,
       threat_level, jp_strength
FROM competitors
WHERE id IN ('notion','evernote','moneyforward','slack','line')
ORDER BY sort_order;

-- competitor_features 確認
SELECT c.display_name, cf.feature_name_ja, cf.has_feature, cf.jibun_status
FROM competitor_features cf
JOIN competitors c ON c.id = cf.competitor_id
WHERE c.id = 'notion'
ORDER BY cf.feature_key;
```

---

*PS#4 S70 / 2026-04-27 作成 / VSCode版 担当*
