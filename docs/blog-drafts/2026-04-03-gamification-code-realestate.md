---
title: Flutter WebでHabitica・GitHub Gist・不動産管理を同時実装 — 競合3社を1日で攻略した話
emoji: 🎮
type: tech
topics: [flutter, supabase, dart, gamification]
published: true
---

# はじめに — 2026-04-03-gamification-code-realestate

自分株式会社（Notion・Evernote・MoneyForward・Slack・GitHub など21社の機能を1つに統合するAI生産性プラットフォーム）の日次開発として、本日は3つの新機能を実装しました。

1. **習慣ゲーミフィケーション** — Duolingo/Forest/Habitica競合
2. **コードプレイグラウンド** — GitHub Gist/CodePen/Codex競合
3. **不動産管理** — MoneyForward/Suumo競合

## 実装方針: Edge Function First

すべての機能において「Edge Function First」を徹底しました。

- `habit-gamification` Edge Function: XP計算・バッジ付与・ストリーク管理
- `code-playground` Edge Function: スニペット保存・コレクション・共有リンク生成
- `real-estate-tracker` Edge Function: 物件管理・収支記録・ROI計算

FlutterフロントエンドはUIと操作性に集中し、複雑なビジネスロジックはすべてDenoバックエンドに委譲しています。

## 習慣ゲーミフィケーション

### XPとレベルシステム

```dart
// XPを元にレベル計算（Edge Function側のロジックをUI表示）
final level = _profile['level'] as int? ?? 1;
final currentXp = _profile['currentXp'] as int? ?? 0;
final nextLevelXp = _profile['nextLevelXp'] as int? ?? 100;
final progress = nextLevelXp > 0 ? currentXp / nextLevelXp : 0.0;

LinearProgressIndicator(
  value: progress.clamp(0.0, 1.0),
  backgroundColor: Colors.white24,
  valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
)
```

### デイリーチャレンジ完了

```dart
Future<void> _completeChallenge(String type) async {
  final res = await _supabase.functions.invoke(
    'habit-gamification',
    body: {'action': 'complete_challenge', 'type': type},
  );
  final data = res.data;
  if (data is Map<String, dynamic> && data['success'] == true) {
    final xp = data['xpEarned'] as int? ?? 0;
    final newBadges = data['newBadges'] as List? ?? [];
    // 新バッジ取得をSnackBarで通知
  }
}
```

### バッジシステム

12種類のバッジ（はじめの一歩・3日連続・1週間連続・30日連続・100日連続など）をEdge Functionで管理。バッジIDをJSON配列でapp_analyticsテーブルのmetadataに保存するシンプルな設計です。

## コードプレイグラウンド

### 20言語対応スニペット管理

```dart
Widget _langIcon(String lang) {
  final Map<String, Color> langColors = {
    'javascript': Colors.yellow.shade700,
    'typescript': Colors.blue,
    'python': Colors.green,
    'dart': Colors.lightBlue,
    'rust': Colors.orange,
    'go': Colors.cyan,
    // ...
  };
  final color = langColors[lang] ?? Colors.grey;
  return CircleAvatar(
    backgroundColor: color.withValues(alpha: 0.15), // deprecated withOpacity → withValues
    child: Text(lang.substring(0, 1).toUpperCase(), ...),
  );
}
```

### DropdownButtonFormField の deprecated API 対応

Flutter 3.33.0+ から `value` プロパティが非推奨になりました。`initialValue` へ移行しています。

```dart
// NG: value: _selectedLanguage (deprecated)
DropdownButtonFormField<String>(
  initialValue: _selectedLanguage, // OK
  ...
)
```

### コードのコピー機能

```dart
TextButton.icon(
  onPressed: () {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('コピーしました')),
    );
  },
  icon: const Icon(Icons.copy, size: 16),
  label: const Text('コピー'),
)
```

## 不動産管理

### 収支ROI計算

Edge Functionが物件別の収支を集計してROIを返します。

```typescript
const roi = totalValue > 0
  ? Math.round((totalIncome - totalExpense) / totalValue * 10000) / 100
  : 0;
```

Flutter側はこれを受け取って表示するだけです。

### 金額フォーマット

大きな金額を億・万単位で表示するヘルパーメソッド。

```dart
String _fmt(double v) {
  if (v >= 1e8) return '${(v / 1e8).toStringAsFixed(1)}億';
  if (v >= 1e4) return '${(v / 1e4).toStringAsFixed(1)}万';
  return v.toStringAsFixed(0);
}
```

## flutter analyze 0件維持

今回の3ページ実装で検出した lint エラーと対処：

| エラー | 対処 |
|--------|------|
| `withOpacity` deprecated | → `withValues(alpha: 0.15)` |
| `value` deprecated (Dropdown) | → `initialValue` |
| `unnecessary_brace_in_string_interps` | → `$streak` に変更 |
| `curly_braces_in_flow_control_structures` | → if-else にブレース追加 |

## まとめ

今回の実装で：
- **習慣ゲーミフィケーション**: Duolingo/Habiticaへの対抗機能完成
- **コードプレイグラウンド**: 開発者ユーザー向けのGitHub Gist代替
- **不動産管理**: MoneyForwardの資産管理機能をさらに拡張

自分株式会社のサービスURL: https://my-web-app-b67f4.web.app/

#FlutterWeb #Supabase #buildinpublic #Dart #EdgeFunctions
