# タイマー機能 設計ドキュメント

**作成日**: 2025年11月9日
**ステータス**: 設計中
**優先度**: 中

---

## 📋 概要

メモを書きながら設定できるタイマー機能を実装し、生産性向上とゲーミフィケーション要素を強化します。

---

## 🎯 ユーザーストーリー

### AS A ユーザー
### I WANT メモを書きながらタイマーを設定できる
### SO THAT 時間を意識して効率的にメモを書くことができる

---

## 📊 要件定義

### 機能要件

#### 1. タイマー機能（基本）
- **タイマータイプ**:
  - カウントダウンタイマー（5分、10分、15分、25分、カスタム）
  - カウントアップタイマー（ストップウォッチ）
  - ポモドーロタイマー（25分 + 5分休憩）

- **タイマーコントロール**:
  - 開始
  - 一時停止
  - リセット
  - 停止

- **タイマー通知**:
  - 画面内通知（終了時）
  - サウンド通知（オプション）
  - バイブレーション（モバイル、オプション）

#### 2. メモとの連携
- **タイマー付きメモ**:
  - メモにタイマー記録を保存
  - タイマー時間の履歴（合計時間、セッション数）
  - タイマー統計（日次、週次、月次）

- **ゲーミフィケーション**:
  - タイマー完了でポイント獲得（25分完了 = 50ポイント）
  - タイマー関連アチーブメント
    - 「初めてのタイマー」- 初回タイマー完了
    - 「ポモドーロマスター」- 10回のポモドーロ完了
    - 「集中力の鬼」- 累計10時間のタイマー完了
    - 「連続記録」- 7日連続でタイマー使用

#### 3. 自動保存機能

**段階的実装アプローチ**:

##### フェーズ1: 保存ボタンの改善（即座に実装）
- **画面遷移しない保存ボタン**を追加
  - 保存後も画面に留まる
  - 「保存して閉じる」と「保存」の2つのボタン
  - 保存後にスナックバーで「保存しました」と表示

##### フェーズ2: 自動保存（中期）
- **自動保存トリガー**:
  - 3秒間入力がない場合に自動保存
  - ブラウザを閉じる前に自動保存
  - 定期的な自動保存（30秒ごと）

- **ステータス表示**:
  - 「保存中...」
  - 「すべての変更が保存されました」
  - 「オフライン - 変更はローカルに保存されています」

##### フェーズ3: UNDO/REDO機能（長期）
- **UNDO/REDO実装**:
  - Ctrl+Z / Ctrl+Y（Windows/Linux）
  - Cmd+Z / Cmd+Shift+Z（macOS）
  - 最大50ステップの履歴
  - 履歴のローカルストレージ保存

---

## 🎨 UI/UX設計

### タイマーUI

#### オプション1: フローティングタイマー（推奨）
```
┌──────────────────────────────────────┐
│ メモエディタ                         │
│                                      │
│  [タイトル入力欄]                   │
│                                      │
│  [本文入力欄...]                     │
│  ...                                 │
│                                      │
│  ┌─────────────────┐               │
│  │  ⏱️ 25:00       │  ← フローティング │
│  │  [▶] [⏸] [⏹]   │               │
│  └─────────────────┘               │
└──────────────────────────────────────┘
```

#### オプション2: ヘッダー統合型
```
┌──────────────────────────────────────┐
│ [< 戻る] メモエディタ     [保存] [⋮] │
│ ⏱️ 25:00  [▶] [⏸] [⏹]              │
├──────────────────────────────────────┤
│  [タイトル入力欄]                   │
│                                      │
│  [本文入力欄...]                     │
└──────────────────────────────────────┘
```

#### オプション3: ボトムバー
```
┌──────────────────────────────────────┐
│ メモエディタ                         │
│                                      │
│  [タイトル入力欄]                   │
│  [本文入力欄...]                     │
│                                      │
├──────────────────────────────────────┤
│ ⏱️ 25:00  [▶] [⏸] [⏹]  [保存]     │
└──────────────────────────────────────┘
```

### 保存ボタンのUI変更

#### 現在の実装
```dart
AppBar(
  actions: [
    IconButton(
      icon: const Icon(Icons.save),
      onPressed: _saveNote, // 保存後に画面を閉じる
    ),
  ],
)
```

#### 新しい実装（フェーズ1）
```dart
AppBar(
  actions: [
    IconButton(
      icon: const Icon(Icons.save_outlined),
      tooltip: '保存',
      onPressed: _saveNoteWithoutClosing, // 保存後も画面に留まる
    ),
    IconButton(
      icon: const Icon(Icons.check),
      tooltip: '保存して閉じる',
      onPressed: _saveNote, // 保存後に画面を閉じる
    ),
    // ... その他のボタン
  ],
)
```

---

## 🔧 技術実装

### データモデル

#### 1. Timer Session（新規テーブル）

```sql
CREATE TABLE timer_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  note_id UUID REFERENCES notes(id) ON DELETE CASCADE,
  timer_type VARCHAR(20) NOT NULL, -- 'countdown', 'countup', 'pomodoro'
  duration_seconds INTEGER, -- 設定時間（カウントダウン用）
  actual_seconds INTEGER, -- 実際の経過時間
  completed BOOLEAN DEFAULT FALSE,
  started_at TIMESTAMPTZ NOT NULL,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- インデックス
CREATE INDEX idx_timer_sessions_user_id ON timer_sessions(user_id);
CREATE INDEX idx_timer_sessions_note_id ON timer_sessions(note_id);
CREATE INDEX idx_timer_sessions_started_at ON timer_sessions(started_at);
```

#### 2. Note Auto-Save History（フェーズ3用）

```sql
CREATE TABLE note_versions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  note_id UUID REFERENCES notes(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  version_number INTEGER NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- インデックス
CREATE INDEX idx_note_versions_note_id ON note_versions(note_id);
CREATE INDEX idx_note_versions_created_at ON note_versions(created_at);

-- 古いバージョンの自動削除（50バージョン以上保持しない）
-- Database Triggerで実装
```

### Flutter実装

#### 1. TimerService

```dart
class TimerService {
  Timer? _timer;
  int _seconds = 0;
  TimerType _type = TimerType.countdown;
  TimerStatus _status = TimerStatus.idle;

  // コールバック
  Function(int)? onTick;
  Function()? onComplete;

  void start({required int duration, required TimerType type}) {
    _seconds = type == TimerType.countdown ? duration : 0;
    _type = type;
    _status = TimerStatus.running;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_type == TimerType.countdown) {
        _seconds--;
        if (_seconds <= 0) {
          complete();
        }
      } else {
        _seconds++;
      }
      onTick?.call(_seconds);
    });
  }

  void pause() {
    _timer?.cancel();
    _status = TimerStatus.paused;
  }

  void resume() {
    // タイマーを再開
    start(duration: _seconds, type: _type);
  }

  void stop() {
    _timer?.cancel();
    _status = TimerStatus.idle;
    _seconds = 0;
  }

  void complete() {
    _timer?.cancel();
    _status = TimerStatus.completed;
    onComplete?.call();
  }

  Future<void> saveSession({required String userId, String? noteId}) async {
    await supabase.from('timer_sessions').insert({
      'user_id': userId,
      'note_id': noteId,
      'timer_type': _type.name,
      'duration_seconds': _type == TimerType.countdown ? _seconds : null,
      'actual_seconds': _seconds,
      'completed': _status == TimerStatus.completed,
      'started_at': DateTime.now().toIso8601String(),
      'completed_at': _status == TimerStatus.completed
        ? DateTime.now().toIso8601String()
        : null,
    });
  }
}

enum TimerType { countdown, countup, pomodoro }
enum TimerStatus { idle, running, paused, completed }
```

#### 2. NoteEditorPageの変更

```dart
class _NoteEditorPageState extends State<NoteEditorPage> {
  // 既存のコード...

  late final TimerService _timerService;
  bool _showTimer = false;

  @override
  void initState() {
    super.initState();
    // ... 既存の初期化
    _timerService = TimerService();
    _timerService.onTick = (seconds) {
      setState(() {});
    };
    _timerService.onComplete = () {
      _onTimerComplete();
    };
  }

  @override
  void dispose() {
    _timerService.stop();
    super.dispose();
  }

  // 保存（画面を閉じない）
  Future<void> _saveNoteWithoutClosing() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final isNewNote = widget.note == null;

      // ... 保存処理（既存の_saveNoteとほぼ同じ）

      // Navigator.pop(context); を削除

      // 保存完了メッセージを表示
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ 保存しました'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (error) {
      // エラー処理
    }
  }

  // タイマー完了時の処理
  Future<void> _onTimerComplete() async {
    final userId = supabase.auth.currentUser!.id;

    // タイマーセッションを保存
    await _timerService.saveSession(
      userId: userId,
      noteId: widget.note?.id,
    );

    // ゲーミフィケーション: ポイント獲得
    await GamificationService().onTimerCompleted(userId);

    // 通知を表示
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⏱️ タイマーが完了しました！+50ポイント'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  // タイマーウィジェット
  Widget _buildTimer() {
    if (!_showTimer) return const SizedBox.shrink();

    return Positioned(
      right: 16,
      bottom: 80,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                _formatTime(_timerService._seconds),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _timerService._status == TimerStatus.running
                        ? Icons.pause
                        : Icons.play_arrow,
                    ),
                    onPressed: () {
                      if (_timerService._status == TimerStatus.running) {
                        _timerService.pause();
                      } else {
                        _timerService.resume();
                      }
                      setState(() {});
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.stop),
                    onPressed: () {
                      _timerService.stop();
                      setState(() {});
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // ...
        actions: [
          // タイマーボタン
          IconButton(
            icon: const Icon(Icons.timer_outlined),
            tooltip: 'タイマー',
            onPressed: () {
              setState(() {
                _showTimer = !_showTimer;
              });
              if (_showTimer) {
                _showTimerSetupDialog();
              }
            },
          ),
          // 保存ボタン（画面を閉じない）
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: '保存',
            onPressed: _saveNoteWithoutClosing,
          ),
          // 保存して閉じるボタン
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: '保存して閉じる',
            onPressed: _saveNote,
          ),
          // ... その他のボタン
        ],
      ),
      body: Stack(
        children: [
          // メモエディタ本体
          // ...

          // フローティングタイマー
          _buildTimer(),
        ],
      ),
    );
  }

  void _showTimerSetupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⏱️ タイマーを設定'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('5分'),
              onTap: () {
                _timerService.start(duration: 300, type: TimerType.countdown);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('10分'),
              onTap: () {
                _timerService.start(duration: 600, type: TimerType.countdown);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('25分（ポモドーロ）'),
              onTap: () {
                _timerService.start(duration: 1500, type: TimerType.pomodoro);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('カウントアップ'),
              onTap: () {
                _timerService.start(duration: 0, type: TimerType.countup);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 📊 ゲーミフィケーション統合

### ポイント獲得

```dart
// gamification_service.dart に追加

Future<List<dynamic>> onTimerCompleted(String userId) async {
  try {
    // ポイント付与
    await _awardPoints(userId, 50, 'timer_completed');

    // タイマー関連の統計を更新
    await _incrementTimerCount(userId);

    // アチーブメント判定
    final achievements = await _checkTimerAchievements(userId);

    return achievements;
  } catch (error) {
    print('Error in onTimerCompleted: $error');
    return [];
  }
}

Future<void> _incrementTimerCount(String userId) async {
  await supabase.rpc('increment_timer_count', params: {
    'p_user_id': userId,
  });
}

Future<List<dynamic>> _checkTimerAchievements(String userId) async {
  final achievements = <dynamic>[];

  // タイマー統計を取得
  final stats = await supabase
    .from('timer_sessions')
    .select('id, completed')
    .eq('user_id', userId)
    .eq('completed', true);

  final completedCount = stats.length;
  final totalSeconds = stats.fold<int>(
    0,
    (sum, session) => sum + (session['actual_seconds'] as int? ?? 0),
  );

  // アチーブメント判定
  if (completedCount == 1) {
    achievements.add({'name': '初めてのタイマー', 'points': 100});
  }
  if (completedCount == 10) {
    achievements.add({'name': 'ポモドーロマスター', 'points': 500});
  }
  if (totalSeconds >= 36000) { // 10時間
    achievements.add({'name': '集中力の鬼', 'points': 1000});
  }

  return achievements;
}
```

---

## 🚀 実装スケジュール

### フェーズ1: 保存ボタン改善（Week 1）
- [ ] 「保存」と「保存して閉じる」の2つのボタンを追加
- [ ] 保存後のスナックバー表示
- [ ] テスト

### フェーズ2: タイマー機能（Week 2-3）
- [ ] データベーステーブル作成（timer_sessions）
- [ ] TimerServiceの実装
- [ ] NoteEditorPageへのタイマーUI追加
- [ ] タイマー設定ダイアログ
- [ ] ゲーミフィケーション統合
- [ ] タイマー統計ページ

### フェーズ3: 自動保存（Month 2）
- [ ] 自動保存ロジックの実装
- [ ] ステータス表示
- [ ] オフライン対応

### フェーズ4: UNDO/REDO（Month 3）
- [ ] note_versionsテーブル作成
- [ ] UNDO/REDOロジック実装
- [ ] キーボードショートカット
- [ ] 履歴UI

---

## 📋 テスト計画

### ユニットテスト
- [ ] TimerService.start()
- [ ] TimerService.pause()
- [ ] TimerService.resume()
- [ ] TimerService.complete()

### 統合テスト
- [ ] タイマー開始→一時停止→再開→完了
- [ ] タイマー完了時のポイント獲得
- [ ] タイマーセッションの保存

### E2Eテスト
- [ ] メモエディタでタイマーを設定
- [ ] タイマー完了まで待機
- [ ] 通知とポイントを確認

---

## 🎯 成功指標

### KPI
- タイマー使用率: 20%以上のユーザーが使用
- タイマー完了率: 80%以上
- ユーザーエンゲージメント: タイマー使用ユーザーの平均セッション時間 +30%
- リテンション: タイマー使用ユーザーの7日間リテンション +20%

---

## 📚 関連ドキュメント

- [成長戦略ロードマップ](../roadmaps/GROWTH_STRATEGY_ROADMAP.md)
- [ゲーミフィケーション機能](../user-docs/GAMIFICATION_README.md)

---

**最終更新**: 2025年11月9日
**次回レビュー**: 実装開始時
