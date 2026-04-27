# Cross-Instance PR: 複勝コンセンサス + 全期間命中率 UI表示

**From**: PS#6 (horse racing backend)  
**To**: VSCode (Flutter UI)  
**Priority**: Medium  
**Created**: 2026-04-27  
**Source commits**: `9c0c6e5e` (S65 place_votes), `a2e7dbdb` (S67 aggregate)

---

## 背景

PS#6 S65/S67 でバックエンドに新フィールドを追加済みだが Flutter UI 未対応:

| フィールド | EF action | 追加セッション | 現状 |
|---|---|---|---|
| `place_consensus` | `horseracing.consensus` | S65 | 未表示 |
| `place_distribution` | `horseracing.consensus` | S65 | 未表示 |
| `bet_type_accuracy[複勝/ワイド]` | `horseracing.accuracy` | 既存 | カードあり (フィルタで取り出し可) |

---

## Change 1: `lib/pages/horseracing_race_detail_page.dart`

### 現状 (line 44)
`_consensus` に格納されているキー:
- `first_pick` (string) — 現在表示中
- `votes` (int) — 現在表示中
- `agreement_rate` (double) — 現在表示中
- `place_consensus` (string | null) — **S65追加・未表示**
- `place_distribution` (List) — **S65追加・未表示** — `[{horse_name, score, rank}]` 形式

### 変更内容: `_buildConsensusBar()` (line 328)

現在の `_buildConsensusBar()` はコンセンサスバーを1行で表示:
```
◎ {first_pick}  ({votes}社一致)      信頼度 XX%
```

変更後は `place_consensus` が存在する場合、2行目を追加:
```
◎ {first_pick}  ({votes}社一致)      信頼度 XX%
複勝 {place_consensus}  (複数AI評価)   {上位3頭 chips}
```

**実装ガイド**:
```dart
Widget _buildConsensusBar() {
  final firstPick = _consensus!['first_pick'] as String? ?? '?';
  final votes = _consensus!['votes'] as int? ?? 0;
  final agreementRate =
      ((_consensus!['agreement_rate'] as num?)?.toDouble() ?? 0) * 100;
  final placePick = _consensus!['place_consensus'] as String?;
  final placeDistribution = (_consensus!['place_distribution'] as List?)
      ?.take(3)
      .cast<Map<String, dynamic>>()
      .toList();

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: const Color(0xFFDC2626).withValues(alpha: 0.08),
    child: Column(
      children: [
        // 既存の1行目 (変更なし)
        Row(
          children: [
            const Icon(Icons.group_work, color: Color(0xFFDC2626), size: 14),
            const SizedBox(width: 6),
            const Text('コンセンサス', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.6)),
            const SizedBox(width: 8),
            Text('◎ $firstPick  ($votes社一致)',
                style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 13, height: 1.6)),
            const Spacer(),
            Text('信頼度 ${agreementRate.toStringAsFixed(0)}%',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, height: 1.5)),
          ],
        ),
        // 複勝コンセンサス行 (place_consensus が存在する場合のみ)
        if (placePick != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const SizedBox(width: 20),
              const Text('複勝', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, height: 1.5)),
              const SizedBox(width: 8),
              Text(placePick,
                  style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 12, height: 1.5)),
              if (placeDistribution != null) ...[
                const SizedBox(width: 8),
                ...placeDistribution.map((h) {
                  final name = h['horse_name'] as String? ?? '';
                  final rank = h['rank'] as int? ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$rank位 $name',
                          style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 9, height: 1.4)),
                    ),
                  );
                }),
              ],
            ],
          ),
        ],
      ],
    ),
  );
}
```

---

## Change 2: `lib/pages/horse_racing_predictor_page.dart`

### 現状
統計タブの `_buildBetTypeLearningSection()` (line ~3170) は `betTypeAccuracy` を全件 `Wrap` で表示。複勝・ワイドの的中率が含まれるが他の券種に埋もれている。

### 変更内容: 学習サマリー行を追加

`_buildBetTypeLearningSection()` 内の `Wrap(children: betTypeAccuracy...)` の**上**に、複勝とワイドの命中率を目立つサマリー行として追加:

```dart
// betTypeAccuracy から複勝・ワイドを抽出してサマリー表示
final placeRow = betTypeAccuracy.where((r) => r['bet_type'] == '複勝').firstOrNull;
final wideRow = betTypeAccuracy.where((r) => r['bet_type'] == 'ワイド').firstOrNull;

if (placeRow != null || wideRow != null) ...[
  const SizedBox(height: 8),
  Row(
    children: [
      if (placeRow != null)
        Expanded(child: _learningHighlightCard(
          '複勝命中率',
          '${(placeRow['hit_rate_pct'] as num?)?.toStringAsFixed(1) ?? '-'}%',
          Icons.trending_up,
          const Color(0xFF10B981),
        )),
      if (placeRow != null && wideRow != null) const SizedBox(width: 8),
      if (wideRow != null)
        Expanded(child: _learningHighlightCard(
          'ワイド命中率',
          '${(wideRow['hit_rate_pct'] as num?)?.toStringAsFixed(1) ?? '-'}%',
          Icons.expand,
          const Color(0xFF8B5CF6),
        )),
    ],
  ),
  const SizedBox(height: 8),
],
```

`_learningHighlightCard` は既存の `_statCard` と同じパターンで実装可。

---

## テスト確認項目

- [ ] `_consensus!['place_consensus']` が `null` の場合、複勝行が表示されない
- [ ] `place_distribution` が空の場合、chips なしで馬名のみ表示
- [ ] `betTypeAccuracy` が空の場合、サマリー行が表示されない (既存の `if (betTypeAccuracy.isEmpty)` ガードに加えて)
- [ ] `dart format` → `flutter analyze` 0 warnings

## 参考: EF レスポンス構造

```json
// horseracing.consensus レスポンス
{
  "consensus": {
    "first_pick": "アーバンシック",
    "votes": 3,
    "agreement_rate": 0.75,
    "place_consensus": "タスティエーラ",
    "place_distribution": [
      {"horse_name": "タスティエーラ", "score": 2.1, "rank": 1},
      {"horse_name": "アーバンシック", "score": 1.8, "rank": 2},
      {"horse_name": "ソールオリエンス", "score": 1.2, "rank": 3}
    ]
  }
}

// horseracing.accuracy レスポンス (既存フィールド)
{
  "bet_type_accuracy": [
    {"bet_type": "複勝", "total_predictions": 42, "hit_rate_pct": 38.1},
    {"bet_type": "ワイド", "total_predictions": 38, "hit_rate_pct": 28.9},
    ...
  ]
}
```
