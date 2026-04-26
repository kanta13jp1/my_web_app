# cross-instance-pr: horse_provider_leaderboard_page.dart UI 更新依頼

**起票**: PS版#6 S57 (2026-04-26)
**FROM**: PS版#6 (horse racing / data 担当)
**TO**: VSCode版 (UI/design 担当)
**期限**: 2026-05-03 (1 週間)
**SLA**: severity = normal / 48h 着手

---

## 背景

PS#6 S57 で以下を実装済み:
1. **Migration** `20260426241000_horse_provider_leaderboard_v2.sql`
   - `horse_provider_leaderboard` view に `avg_learning_score` / `skip_accuracy_pct` / `skip_recommendations_evaluated` 追加
2. **EF** `tools-hub:horseracing.provider_leaderboard`
   - レスポンスに `best_bet_type` / `best_bet_hit_rate` を付加 (horse_bet_type_provider_accuracy JOIN)

`horse_provider_leaderboard_page.dart` が現在表示している `first_hit_rate` / `trifecta_hit_rate` だけでは学習ループの成果が見えない。

---

## VSCode 側実装依頼

### 1. 新フィールドの型定義 (dart)

EF レスポンスの各 row に以下が追加された:

```dart
final double avgLearningScore = (row['avg_learning_score'] as num?)?.toDouble() ?? 0;
final double skipAccuracyPct  = (row['skip_accuracy_pct']  as num?)?.toDouble() ?? 0;
final String? bestBetType     = row['best_bet_type'] as String?;
final double bestBetHitRate   = (row['best_bet_hit_rate']  as num?)?.toDouble() ?? 0;
```

### 2. leaderboard カードの変更

現在: `1着率 | 3連単率 | 予想数`

変更後: `学習スコア | 1着率 | スキップ精度 | ベスト券種`

#### ヘッダー変更
```dart
// 現在のヘッダー (SizedBox width:56 × 2 + width:40)
// → 新ヘッダー:
const Row(children: [
  SizedBox(width: 36),  // rank badge
  Expanded(flex: 3, child: Text('プロバイダー', ...)),
  SizedBox(width: 52, child: Text('学習スコア', textAlign: TextAlign.center, ...)),
  SizedBox(width: 44, child: Text('1着率', textAlign: TextAlign.center, ...)),
  SizedBox(width: 52, child: Text('スキップ精度', textAlign: TextAlign.center, ...)),
  SizedBox(width: 56, child: Text('ベスト券種', textAlign: TextAlign.center, ...)),
])
```

#### カード行変更
```dart
// avg_learning_score (0.0–1.0 → 0–100 表示)
SizedBox(
  width: 52,
  child: Text(
    avgLearningScore > 0 ? '${(avgLearningScore * 100).toStringAsFixed(1)}' : '-',
    style: TextStyle(
      color: avgLearningScore > 0.5 ? const Color(0xFF4ADE80) : Colors.white,
      fontSize: 13, fontWeight: FontWeight.bold, height: 1.5,
    ),
    textAlign: TextAlign.center,
  ),
),
// first_hit_rate (既存)
SizedBox(
  width: 44,
  child: Text('${(firstHitRate * 100).toStringAsFixed(1)}%', ...),
),
// skip_accuracy_pct
SizedBox(
  width: 52,
  child: Text(
    skipAccuracyPct > 0 ? '${skipAccuracyPct.toStringAsFixed(1)}%' : '-',
    style: TextStyle(
      color: skipAccuracyPct > 60 ? const Color(0xFF4ADE80)
           : skipAccuracyPct > 40 ? const Color(0xFFFBBF24)
           : Colors.white,
      fontSize: 12, height: 1.5,
    ),
    textAlign: TextAlign.center,
  ),
),
// best_bet_type
SizedBox(
  width: 56,
  child: bestBetType != null
    ? Column(mainAxisSize: MainAxisSize.min, children: [
        Text(bestBetType, style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.5)),
        Text('${bestBetHitRate.toStringAsFixed(1)}%',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, height: 1.5)),
      ])
    : const Text('-', style: TextStyle(color: Color(0xFF64748B), height: 1.5), textAlign: TextAlign.center),
),
```

### 3. 3連単率カラムは削除 (情報整理)

trifecta_hit_rate は avg_learning_score に統合されているため削除 OK。
もし残すなら tooltip に移動を推奨。

---

## 関連 commit

- PS#6 S57 Migration + EF: TBD (このセッションのコミット)
- 対象ファイル: `lib/pages/horse_provider_leaderboard_page.dart` (344行)

## Philosophy Alignment

- 5 (商品=ユーザー価値): 「スキップ精度」で購入判断の質が直感的に分かる ✅
- 8 (KPI=昨日の自分): 学習スコアで「今日のモデルは昨日より賢い」が可視化 ✅
