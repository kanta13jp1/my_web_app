# リファクタリング計画書 [Archive]

**作成日**: 2025年11月14日
**最終更新**: 2025年11月14日
**目的**: 大きなファイルの分割とコード品質の向上

---

## 📊 現状分析

### コードベース統計
- **総Dartファイル数**: ~80ファイル
- **総行数**: 33,625行
- **1,000行超ファイル**: 2ファイル
- **500行超ファイル**: 15ファイル

### 問題のある大きなファイル

| ファイル | 行数 | 問題点 | 影響 |
|---------|------|--------|------|
| `note_editor_page.dart` | 1,428 | 多機能が1ファイルに集中 | 保守性低下、テスト困難 |
| `home_app_bar.dart` | 1,231 | UI/ロジックが混在 | 再利用困難、複雑度高 |
| `home_page.dart` | 855 | 状態管理が複雑 | デバッグ困難 |
| `share_note_card_dialog.dart` | 810 | 画像生成ロジックが大きい | パフォーマンス低下 |
| `gamification_service.dart` | 690 | 複数の責務が混在 | 単一責任原則違反 |

---

## 🎯 リファクタリング目標

### SOLID原則への準拠
1. **S - Single Responsibility Principle**: 各クラス/ファイルは1つの責務のみ
2. **O - Open/Closed Principle**: 拡張に開いて修正に閉じる
3. **L - Liskov Substitution Principle**: サブクラスは親クラスと置き換え可能
4. **I - Interface Segregation Principle**: クライアントは使わないメソッドに依存しない
5. **D - Dependency Inversion Principle**: 具象ではなく抽象に依存

### 定量目標
- ✅ 全ファイルを500行以下に削減
- ✅ サイクロマティック複雑度を20以下に削減
- ✅ テストカバレッジを80%以上に向上
- ✅ Linterエラー/警告を0件に削減

---

## 📋 詳細リファクタリング計画

### 優先度1: note_editor_page.dart（1,428行）

#### 現在の構造
```
note_editor_page.dart (1,428行)
├── ウィジェット状態管理 (~200行)
├── テキスト編集機能 (~150行)
├── マークダウンプレビュー (~100行)
├── 添付ファイル管理 (~150行)
├── AIアシスタント統合 (~100行)
├── タイマー機能 (~80行)
├── 自動保存/Undo/Redo (~100行)
├── カテゴリ管理 (~80行)
├── UI構築 (~468行)
```

#### 問題点
- 単一ファイルに多すぎる責務
- テストが困難
- 変更時の影響範囲が大きい
- 複数の開発者が同時編集できない

#### 推奨分割

```
lib/pages/
└── note_editor_page.dart (250行)  # メインページ、状態管理のみ

lib/widgets/note_editor/
├── editor_toolbar.dart (150行)  # ツールバーウィジェット
├── editor_content.dart (200行)  # テキスト編集エリア
├── editor_ai_panel.dart (150行)  # AIアシスタントパネル
├── editor_attachment_panel.dart (180行)  # 添付ファイルパネル
├── editor_markdown_preview.dart (120行)  # マークダウンプレビュー
├── editor_category_selector.dart (100行)  # カテゴリ選択
└── editor_dialogs.dart (既存)  # 各種ダイアログ

lib/services/
└── note_editor_service.dart (200行)  # エディターのビジネスロジック
```

#### 実装手順

**フェーズ1: サービス層の抽出（2-3時間）**
```dart
// lib/services/note_editor_service.dart
class NoteEditorService {
  final Supabase supabase;

  NoteEditorService(this.supabase);

  // メモの保存
  Future<Note> saveNote({
    required String title,
    required String content,
    String? categoryId,
    bool isFavorite = false,
    DateTime? reminderDate,
  }) async {
    // ... 保存ロジック
  }

  // カテゴリの取得
  Future<List<Category>> loadCategories() async {
    // ... カテゴリ取得ロジック
  }

  // 添付ファイルの取得
  Future<List<Attachment>> loadAttachments(int noteId) async {
    // ... 添付ファイル取得ロジック
  }
}
```

**フェーズ2: ウィジェットの分割（4-5時間）**

1. **editor_toolbar.dart の作成**
```dart
class EditorToolbar extends StatelessWidget {
  final VoidCallback onAIAssist;
  final VoidCallback onPreview;
  final VoidCallback onAttach;
  final VoidCallback onTimer;

  const EditorToolbar({
    required this.onAIAssist,
    required this.onPreview,
    required this.onAttach,
    required this.onTimer,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(icon: Icon(Icons.smart_toy), onPressed: onAIAssist),
        IconButton(icon: Icon(Icons.preview), onPressed: onPreview),
        IconButton(icon: Icon(Icons.attach_file), onPressed: onAttach),
        IconButton(icon: Icon(Icons.timer), onPressed: onTimer),
      ],
    );
  }
}
```

2. **editor_content.dart の作成**
```dart
class EditorContent extends StatefulWidget {
  final TextEditingController contentController;
  final VoidCallback onChanged;

  const EditorContent({
    required this.contentController,
    required this.onChanged,
  });

  @override
  State<EditorContent> createState() => _EditorContentState();
}

class _EditorContentState extends State<EditorContent> {
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.contentController,
      onChanged: (_) => widget.onChanged(),
      maxLines: null,
      // ... その他の設定
    );
  }
}
```

3. **editor_ai_panel.dart の作成**
```dart
class EditorAIPanel extends StatelessWidget {
  final String selectedText;
  final Function(String) onAIResponse;

  const EditorAIPanel({
    required this.selectedText,
    required this.onAIResponse,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // AI機能のボタン
        ElevatedButton(
          onPressed: () => _improveText(selectedText),
          child: Text('文章改善'),
        ),
        // ... 他のAI機能
      ],
    );
  }

  Future<void> _improveText(String text) async {
    // AI処理
  }
}
```

**フェーズ3: メインページの整理（1-2時間）**
```dart
// lib/pages/note_editor_page.dart (250行に削減)
class NoteEditorPage extends StatefulWidget {
  final Note? note;

  const NoteEditorPage({super.key, this.note});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final NoteEditorService _editorService;
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _editorService = NoteEditorService(supabase);
    _titleController = TextEditingController(text: widget.note?.title);
    _contentController = TextEditingController(text: widget.note?.content);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('メモ編集'),
        actions: [EditorToolbar(...)],
      ),
      body: Column(
        children: [
          EditorContent(contentController: _contentController, ...),
          if (_showMarkdownPreview) EditorMarkdownPreview(...),
        ],
      ),
    );
  }

  Future<void> _saveNote() async {
    final note = await _editorService.saveNote(
      title: _titleController.text,
      content: _contentController.text,
    );
    // ...
  }
}
```

**推定時間**: 7-10時間
**優先度**: 🔴 最高

---

### 優先度2: home_app_bar.dart（1,231行）

#### 現在の構造
```
home_app_bar.dart (1,231行)
├── 検索バー (~150行)
├── フィルターメニュー (~200行)
├── ユーザープロフィールメニュー (~250行)
├── ナビゲーションドロワー (~400行)
├── 統計表示 (~150行)
├── その他UI (~81行)
```

#### 推奨分割

```
lib/widgets/home_page/
├── home_app_bar.dart (150行)  # メインAppBar

lib/widgets/home_page/app_bar/
├── search_bar_widget.dart (180行)  # 検索バー
├── filter_menu_widget.dart (220行)  # フィルターメニュー
├── profile_menu_widget.dart (280行)  # プロフィールメニュー
├── navigation_drawer_widget.dart (450行)  # ナビゲーションドロワー
└── stats_display_widget.dart (180行)  # 統計表示
```

#### 実装手順

**フェーズ1: 検索バーの分離（1時間）**
```dart
// lib/widgets/home_page/app_bar/search_bar_widget.dart
class SearchBarWidget extends StatelessWidget {
  final bool isSearching;
  final TextEditingController searchController;
  final VoidCallback onToggleSearch;

  const SearchBarWidget({
    required this.isSearching,
    required this.searchController,
    required this.onToggleSearch,
  });

  @override
  Widget build(BuildContext context) {
    if (!isSearching) {
      return IconButton(
        icon: Icon(Icons.search),
        onPressed: onToggleSearch,
      );
    }

    return TextField(
      controller: searchController,
      decoration: InputDecoration(
        hintText: 'メモを検索...',
      ),
    );
  }
}
```

**フェーズ2: フィルターメニューの分離（1.5時間）**
```dart
// lib/widgets/home_page/app_bar/filter_menu_widget.dart
class FilterMenuWidget extends StatelessWidget {
  final VoidCallback onShowCategoryFilter;
  final VoidCallback onShowDateFilter;
  final VoidCallback onShowReminderFilter;
  final bool hasCategoryFilter;
  final bool hasDateFilter;

  const FilterMenuWidget({
    required this.onShowCategoryFilter,
    required this.onShowDateFilter,
    required this.onShowReminderFilter,
    required this.hasCategoryFilter,
    required this.hasDateFilter,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      icon: Icon(Icons.filter_list),
      itemBuilder: (context) => [
        PopupMenuItem(
          child: ListTile(
            leading: Icon(Icons.category),
            title: Text('カテゴリ'),
            trailing: hasCategoryFilter ? Icon(Icons.check) : null,
          ),
          onTap: onShowCategoryFilter,
        ),
        // ... 他のフィルター
      ],
    );
  }
}
```

**フェーズ3: ナビゲーションドロワーの分離（2時間）**
```dart
// lib/widgets/home_page/app_bar/navigation_drawer_widget.dart
class NavigationDrawerWidget extends StatelessWidget {
  final UserStats? userStats;
  final VoidCallback onSignOut;

  const NavigationDrawerWidget({
    required this.userStats,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          _buildUserHeader(),
          _buildMenuItems(),
          Divider(),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text('ログアウト'),
            onTap: onSignOut,
          ),
        ],
      ),
    );
  }

  Widget _buildUserHeader() {
    return UserAccountsDrawerHeader(
      accountName: Text(userStats?.displayName ?? 'ユーザー'),
      accountEmail: Text('レベル ${userStats?.level ?? 1}'),
      currentAccountPicture: CircleAvatar(
        child: Text('${userStats?.level ?? 1}'),
      ),
    );
  }

  Widget _buildMenuItems() {
    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.archive),
          title: Text('アーカイブ'),
          onTap: () => Navigator.push(...),
        ),
        // ... 他のメニュー項目
      ],
    );
  }
}
```

**推定時間**: 5-7時間
**優先度**: 🔴 高

---

### 優先度3: gamification_service.dart（690行）

#### 現在の構造
```
gamification_service.dart (690行)
├── ポイント管理 (~150行)
├── レベル計算 (~100行)
├── アチーブメント管理 (~200行)
├── リーダーボード (~150行)
├── デイリーチャレンジ連携 (~90行)
```

#### 問題点
- 複数の責務が1つのサービスに集中
- 単一責任原則違反
- テストが困難

#### 推奨分割

```
lib/services/gamification/
├── points_service.dart (180行)  # ポイント管理
├── level_service.dart (120行)  # レベル計算
├── achievement_service.dart (220行)  # アチーブメント
└── leaderboard_service.dart (180行)  # リーダーボード

lib/services/
└── gamification_facade.dart (100行)  # ファサードパターン
```

#### 実装手順

**フェーズ1: ポイントサービスの分離（2時間）**
```dart
// lib/services/gamification/points_service.dart
class PointsService {
  final SupabaseClient _supabase;

  PointsService(this._supabase);

  /// アクティビティに応じたポイント付与
  Future<int> awardPoints(String userId, String activityType) async {
    final points = _getPointsForActivity(activityType);
    await _updateUserPoints(userId, points);
    return points;
  }

  int _getPointsForActivity(String activityType) {
    return switch (activityType) {
      'note_created' => 10,
      'note_updated' => 5,
      'note_deleted' => -5,
      'category_created' => 15,
      // ... 他のアクティビティ
      _ => 0,
    };
  }

  Future<void> _updateUserPoints(String userId, int points) async {
    await _supabase.from('user_stats').update({
      'total_points': SupabaseClient.raw('total_points + $points'),
    }).eq('user_id', userId);
  }
}
```

**フェーズ2: レベルサービスの分離（1.5時間）**
```dart
// lib/services/gamification/level_service.dart
class LevelService {
  /// ポイントからレベルを計算
  int calculateLevel(int totalPoints) {
    return (totalPoints / 100).floor() + 1;
  }

  /// 次のレベルまでに必要なポイント
  int pointsToNextLevel(int currentPoints) {
    final currentLevel = calculateLevel(currentPoints);
    final nextLevelPoints = currentLevel * 100;
    return nextLevelPoints - currentPoints;
  }

  /// レベルアップ時のボーナスポイント
  int getLevelUpBonus(int newLevel) {
    return newLevel * 50;  // レベルごとに50ポイント
  }
}
```

**フェーズ3: アチーブメントサービスの分離（2.5時間）**
```dart
// lib/services/gamification/achievement_service.dart
class AchievementService {
  final SupabaseClient _supabase;

  AchievementService(this._supabase);

  /// アクティビティから達成可能な実績をチェック
  Future<List<Achievement>> checkAchievements(
    String userId,
    String activityType,
    Map<String, dynamic> context,
  ) async {
    final unlockedAchievements = <Achievement>[];

    // 各実績の条件をチェック
    for (final achievement in _allAchievements) {
      if (await _isAchievementUnlocked(userId, achievement, context)) {
        unlockedAchievements.add(achievement);
        await _unlockAchievement(userId, achievement);
      }
    }

    return unlockedAchievements;
  }

  Future<bool> _isAchievementUnlocked(
    String userId,
    Achievement achievement,
    Map<String, dynamic> context,
  ) async {
    // 実績の条件をチェック
    // ...
  }
}
```

**フェーズ4: ファサードの作成（1時間）**
```dart
// lib/services/gamification_facade.dart
class GamificationFacade {
  final PointsService _pointsService;
  final LevelService _levelService;
  final AchievementService _achievementService;
  final LeaderboardService _leaderboardService;

  GamificationFacade({
    required PointsService pointsService,
    required LevelService levelService,
    required AchievementService achievementService,
    required LeaderboardService leaderboardService,
  })  : _pointsService = pointsService,
        _levelService = levelService,
        _achievementService = achievementService,
        _leaderboardService = leaderboardService;

  /// アクティビティを記録（ポイント付与、レベルチェック、実績チェック）
  Future<GamificationResult> recordActivity(
    String userId,
    String activityType,
  ) async {
    // ポイント付与
    final points = await _pointsService.awardPoints(userId, activityType);

    // レベルチェック
    final userStats = await _getUserStats(userId);
    final newLevel = _levelService.calculateLevel(userStats.totalPoints);

    // レベルアップチェック
    if (newLevel > userStats.level) {
      final bonus = _levelService.getLevelUpBonus(newLevel);
      await _pointsService.awardPoints(userId, 'level_up_bonus');
    }

    // 実績チェック
    final achievements = await _achievementService.checkAchievements(
      userId,
      activityType,
      {'points': points, 'level': newLevel},
    );

    return GamificationResult(
      points: points,
      newLevel: newLevel,
      achievements: achievements,
    );
  }
}
```

**推定時間**: 7-9時間
**優先度**: 🟡 中

---

## 🔄 バックエンド移行計画

### Supabase Edge Functionsへの移行

#### ゲーミフィケーション計算

**理由**: クライアント側での改ざん防止

**実装**:
```typescript
// supabase/functions/record-activity/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from '@supabase/supabase-js'

serve(async (req) => {
  const { userId, activityType } = await req.json()

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL'),
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  )

  // ポイント計算（サーバーサイド）
  const points = getPointsForActivity(activityType)

  // ユーザー統計更新
  const { data, error } = await supabase.rpc('update_user_stats', {
    p_user_id: userId,
    p_points: points,
    p_activity_type: activityType
  })

  return new Response(JSON.stringify({ points, level: data.level }))
})

function getPointsForActivity(activityType: string): number {
  const pointsMap = {
    'note_created': 10,
    'note_updated': 5,
    // ...
  }
  return pointsMap[activityType] || 0
}
```

---

## 📊 リファクタリング進捗トラッキング

### マイルストーン

| マイルストーン | 対象ファイル | 推定時間 | 優先度 | ステータス |
|-------------|------------|---------|--------|----------|
| M1 | note_editor_page.dart | 7-10時間 | 🔴 最高 | ⏳ 未着手 |
| M2 | home_app_bar.dart | 5-7時間 | 🔴 高 | ⏳ 未着手 |
| M3 | gamification_service.dart | 7-9時間 | 🟡 中 | ⏳ 未着手 |
| M4 | share_note_card_dialog.dart | 3-4時間 | 🟡 中 | ⏳ 未着手 |
| M5 | home_page.dart | 4-5時間 | 🟢 低 | ⏳ 未着手 |

### 累積推定時間
- **フェーズ1（M1-M2）**: 12-17時間
- **フェーズ2（M3-M4）**: 10-13時間
- **フェーズ3（M5）**: 4-5時間
- **合計**: 26-35時間

---

## ✅ 成功基準

### コード品質指標
- [ ] 全ファイルが500行以下
- [ ] サイクロマティック複雑度が20以下
- [ ] Linterエラー/警告が0件
- [ ] テストカバレッジが80%以上

### パフォーマンス指標
- [ ] 初回レンダリング時間が2秒以下
- [ ] メモ保存時間が1秒以下
- [ ] 検索応答時間が0.5秒以下

### 保守性指標
- [ ] 新機能追加時の変更ファイル数が3ファイル以下
- [ ] バグ修正時の影響範囲が明確
- [ ] コードレビュー時間が30分以内

---

**作成者**: Claude Code
**承認**: プロジェクトオーナー
**次回レビュー**: M1完了後
