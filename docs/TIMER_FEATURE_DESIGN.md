# タイマー機能設計ドキュメント ⏱️

**作成日**: 2025年11月10日
**最終更新**: 2025年11月10日
**目的**: メモを書きながら設定できるタイマー機能の設計と実装

---

## 📋 要件定義

### ユーザーからの要望
> メモを書きながら設定できるタイマー機能が欲しい
> 操作方法が不明

### 機能要件
1. **メモ編集中にタイマーを設定できる**
2. **タイマーが視覚的にわかりやすい**
3. **操作が簡単**
4. **通知機能**（時間になったらアラーム）
5. **バックグラウンド動作**（他のページに移動しても継続）
6. **複数タイマー対応**（将来的に）

### 非機能要件
- パフォーマンス: タイマー動作が軽量
- UI/UX: 直感的で使いやすい
- アクセシビリティ: 視覚・聴覚障害者にも対応

---

## 🎨 UI/UX設計

### デザインコンセプト
**"シンプルで直感的、邪魔にならない"**

### 配置案

#### 案1: フローティングタイマー（推奨）
```
┌─────────────────────────────────────┐
│ タイトル                            │
│─────────────────────────────────────│
│                                     │
│ メモ本文...                         │
│                                     │
│                                     │
│                         ┌─────────┐ │ ← フローティングタイマー
│                         │ ⏱ 25:00 │ │   （右下に固定）
│                         │ [一時停止]│ │
│                         └─────────┘ │
└─────────────────────────────────────┘
```

#### 案2: ヘッダー統合タイマー
```
┌─────────────────────────────────────┐
│ タイトル          ⏱ 25:00 [停止]   │ ← ヘッダーにタイマー
│─────────────────────────────────────│
│                                     │
│ メモ本文...                         │
│                                     │
└─────────────────────────────────────┘
```

#### 案3: サイドバータイマー
```
┌────────────┬────────────────────────┐
│ タイマー   │ タイトル               │
│ ⏱ 25:00    │────────────────────────│
│ [停止]     │                        │
│            │ メモ本文...            │
│ ポモドーロ │                        │
│ [ ] 25分   │                        │
│ [ ] 5分休憩│                        │
└────────────┴────────────────────────┘
```

**推奨**: **案1（フローティングタイマー）**
- 画面を占有しない
- ドラッグ可能で位置調整可能
- 最小化/最大化可能

---

### タイマー設定ダイアログ

```
┌─────────────────────────────────┐
│ タイマー設定                    │
├─────────────────────────────────┤
│                                 │
│ 時間を設定                      │
│ ┌───┐  ┌───┐  ┌───┐            │
│ │ 0 │時│ 25│分│ 00│秒          │
│ └───┘  └───┘  └───┘            │
│                                 │
│ クイック設定                    │
│ [5分] [10分] [15分] [25分]      │
│ [30分] [45分] [1時間]           │
│                                 │
│ タイマー名（任意）              │
│ ┌───────────────────────────┐   │
│ │ ポモドーロ                │   │
│ └───────────────────────────┘   │
│                                 │
│ 終了時の動作                    │
│ ☑ サウンドで通知              │
│ ☑ ブラウザ通知                │
│ □ 自動保存                    │
│                                 │
│         [キャンセル] [開始]     │
└─────────────────────────────────┘
```

---

### タイマー実行中UI

#### 最小化状態
```
┌─────────────┐
│ ⏱ 24:35     │
│ [⏸] [⏹]    │
└─────────────┘
```

#### 最大化状態
```
┌─────────────────────┐
│ ポモドーロ          │
│                     │
│       24:35         │ ← 大きく表示
│                     │
│ ━━━━━━━━━━          │ ← プログレスバー
│ 2% (残り24分)       │
│                     │
│ [⏸ 一時停止]        │
│ [⏹ 停止]           │
│ [🔄 リセット]       │
└─────────────────────┘
```

---

## 🏗️ 技術設計

### データモデル

#### 1. Timer モデル
```dart
class Timer {
  final int id;
  final int? noteId;          // 関連するメモID（nullの場合は汎用タイマー）
  final String name;          // タイマー名（例: "ポモドーロ"）
  final int durationSeconds;  // 設定時間（秒）
  final DateTime startedAt;   // 開始時刻
  final TimerStatus status;   // 実行中、一時停止、完了
  final bool soundNotification;   // サウンド通知ON/OFF
  final bool browserNotification; // ブラウザ通知ON/OFF
  final bool autoSave;            // 終了時に自動保存

  Timer({
    required this.id,
    this.noteId,
    required this.name,
    required this.durationSeconds,
    required this.startedAt,
    required this.status,
    this.soundNotification = true,
    this.browserNotification = true,
    this.autoSave = false,
  });
}

enum TimerStatus {
  running,   // 実行中
  paused,    // 一時停止
  completed, // 完了
  stopped,   // 停止
}
```

#### 2. データベーススキーマ（Supabase）

```sql
-- タイマー履歴テーブル（将来的な統計機能用）
CREATE TABLE timers (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  note_id BIGINT REFERENCES notes(id) ON DELETE CASCADE,
  name TEXT NOT NULL DEFAULT 'タイマー',
  duration_seconds INTEGER NOT NULL,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'running' CHECK (status IN ('running', 'paused', 'completed', 'stopped')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- インデックス
CREATE INDEX idx_timers_user_id ON timers(user_id);
CREATE INDEX idx_timers_note_id ON timers(note_id);
CREATE INDEX idx_timers_status ON timers(status);

-- RLSポリシー
ALTER TABLE timers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own timers"
  ON timers FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own timers"
  ON timers FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own timers"
  ON timers FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own timers"
  ON timers FOR DELETE
  USING (auth.uid() = user_id);
```

---

### サービス設計

#### TimerService
```dart
// lib/services/timer_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TimerService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // アクティブなタイマー
  AppTimer? _activeTimer;

  // カウントダウン用のStreamController
  StreamController<int>? _countdownController;

  // 残り時間（秒）
  int _remainingSeconds = 0;

  AppTimer? get activeTimer => _activeTimer;
  int get remainingSeconds => _remainingSeconds;
  bool get isRunning => _activeTimer?.status == TimerStatus.running;
  bool get isPaused => _activeTimer?.status == TimerStatus.paused;

  // タイマー開始
  Future<void> startTimer({
    required String name,
    required int durationSeconds,
    int? noteId,
    bool soundNotification = true,
    bool browserNotification = true,
    bool autoSave = false,
  }) async {
    try {
      // 既存のタイマーがあれば停止
      if (_activeTimer != null) {
        await stopTimer();
      }

      // Supabaseに保存
      final response = await _supabase.from('timers').insert({
        'user_id': _supabase.auth.currentUser!.id,
        'note_id': noteId,
        'name': name,
        'duration_seconds': durationSeconds,
        'started_at': DateTime.now().toIso8601String(),
        'status': 'running',
      }).select().single();

      // タイマー作成
      _activeTimer = AppTimer.fromJson(response);
      _remainingSeconds = durationSeconds;

      // カウントダウン開始
      _startCountdown();

      notifyListeners();
    } catch (e) {
      print('Error starting timer: $e');
      rethrow;
    }
  }

  // カウントダウン開始
  void _startCountdown() {
    _countdownController?.close();
    _countdownController = StreamController<int>();

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_activeTimer?.status != TimerStatus.running) {
        timer.cancel();
        return;
      }

      _remainingSeconds--;
      _countdownController?.add(_remainingSeconds);
      notifyListeners();

      // 完了
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _onTimerComplete();
      }
    });
  }

  // タイマー完了時の処理
  Future<void> _onTimerComplete() async {
    if (_activeTimer == null) return;

    try {
      // ステータス更新
      await _supabase.from('timers').update({
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', _activeTimer!.id);

      _activeTimer = _activeTimer!.copyWith(status: TimerStatus.completed);

      // 通知
      if (_activeTimer!.soundNotification) {
        _playSoundNotification();
      }
      if (_activeTimer!.browserNotification) {
        _showBrowserNotification();
      }

      // 自動保存
      if (_activeTimer!.autoSave && _activeTimer!.noteId != null) {
        // メモを自動保存（NoteServiceを使用）
      }

      notifyListeners();
    } catch (e) {
      print('Error completing timer: $e');
    }
  }

  // 一時停止
  Future<void> pauseTimer() async {
    if (_activeTimer == null || _activeTimer!.status != TimerStatus.running) {
      return;
    }

    try {
      await _supabase.from('timers').update({
        'status': 'paused',
      }).eq('id', _activeTimer!.id);

      _activeTimer = _activeTimer!.copyWith(status: TimerStatus.paused);
      notifyListeners();
    } catch (e) {
      print('Error pausing timer: $e');
    }
  }

  // 再開
  Future<void> resumeTimer() async {
    if (_activeTimer == null || _activeTimer!.status != TimerStatus.paused) {
      return;
    }

    try {
      await _supabase.from('timers').update({
        'status': 'running',
      }).eq('id', _activeTimer!.id);

      _activeTimer = _activeTimer!.copyWith(status: TimerStatus.running);
      _startCountdown();
      notifyListeners();
    } catch (e) {
      print('Error resuming timer: $e');
    }
  }

  // 停止
  Future<void> stopTimer() async {
    if (_activeTimer == null) return;

    try {
      await _supabase.from('timers').update({
        'status': 'stopped',
      }).eq('id', _activeTimer!.id);

      _countdownController?.close();
      _activeTimer = null;
      _remainingSeconds = 0;
      notifyListeners();
    } catch (e) {
      print('Error stopping timer: $e');
    }
  }

  // リセット（再スタート）
  Future<void> resetTimer() async {
    if (_activeTimer == null) return;

    final name = _activeTimer!.name;
    final durationSeconds = _activeTimer!.durationSeconds;
    final noteId = _activeTimer!.noteId;

    await stopTimer();
    await startTimer(
      name: name,
      durationSeconds: durationSeconds,
      noteId: noteId,
    );
  }

  // サウンド通知
  void _playSoundNotification() {
    // HTML AudioElement を使用
    // assets/sounds/timer_complete.mp3 を再生
  }

  // ブラウザ通知
  Future<void> _showBrowserNotification() async {
    // Web Notification API を使用
    // 「タイマーが終了しました」を表示
  }

  @override
  void dispose() {
    _countdownController?.close();
    super.dispose();
  }
}
```

---

### ウィジェット設計

#### FloatingTimerWidget
```dart
// lib/widgets/floating_timer_widget.dart

class FloatingTimerWidget extends StatefulWidget {
  const FloatingTimerWidget({Key? key}) : super(key: key);

  @override
  State<FloatingTimerWidget> createState() => _FloatingTimerWidgetState();
}

class _FloatingTimerWidgetState extends State<FloatingTimerWidget> {
  bool _isExpanded = false;
  Offset _position = const Offset(20, 100);

  @override
  Widget build(BuildContext context) {
    final timerService = Provider.of<TimerService>(context);

    if (timerService.activeTimer == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
          });
        },
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _isExpanded ? _buildExpandedTimer(timerService) : _buildMinimizedTimer(timerService),
          ),
        ),
      ),
    );
  }

  Widget _buildMinimizedTimer(TimerService timerService) {
    final minutes = timerService.remainingSeconds ~/ 60;
    final seconds = timerService.remainingSeconds % 60;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.timer, size: 20),
        const SizedBox(width: 8),
        Text(
          '$minutes:${seconds.toString().padLeft(2, '0')}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          icon: Icon(timerService.isRunning ? Icons.pause : Icons.play_arrow),
          onPressed: () {
            if (timerService.isRunning) {
              timerService.pauseTimer();
            } else {
              timerService.resumeTimer();
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.expand_more),
          onPressed: () {
            setState(() {
              _isExpanded = true;
            });
          },
        ),
      ],
    );
  }

  Widget _buildExpandedTimer(TimerService timerService) {
    // 展開版のUI
    // ...
  }
}
```

---

## 🎯 実装計画

### フェーズ1: 基本機能（1週間）
- [ ] TimerServiceクラス作成
- [ ] Timerモデル作成
- [ ] Supabaseマイグレーション作成
- [ ] FloatingTimerWidget作成（最小化状態のみ）
- [ ] タイマー設定ダイアログ作成
- [ ] 基本的なカウントダウン機能

### フェーズ2: UI/UX改善（3-5日）
- [ ] 展開状態のUI実装
- [ ] ドラッグ&ドロップ機能
- [ ] プログレスバー表示
- [ ] アニメーション追加

### フェーズ3: 通知機能（2-3日）
- [ ] サウンド通知実装
- [ ] ブラウザ通知実装
- [ ] 通知設定UI

### フェーズ4: 統計・履歴（将来的に）
- [ ] タイマー履歴表示
- [ ] 統計ダッシュボード
- [ ] ポモドーロ統計

---

## 🧪 テスト計画

### ユニットテスト
- TimerServiceのメソッドテスト
- カウントダウンロジックのテスト
- 通知機能のテスト

### ウィジェットテスト
- FloatingTimerWidgetの表示テスト
- ボタンのタップテスト

### E2Eテスト
- タイマー開始→完了のフロー
- 一時停止→再開のフロー
- 通知が正しく表示されるか

---

## 📚 参考資料

### 参考アプリ
- **Forest**: ゲーミフィケーションタイマー
- **Focus To-Do**: ポモドーロタイマー
- **Toggl Track**: 時間トラッキング

### 技術参考
- [Web Notification API](https://developer.mozilla.org/en-US/docs/Web/API/Notifications_API)
- [HTML Audio Element](https://developer.mozilla.org/en-US/docs/Web/API/HTMLAudioElement)

---

**最終更新**: 2025年11月10日
**次回レビュー**: 実装完了後
**作成者**: Claude Code
