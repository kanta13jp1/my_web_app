---
title: Flutter WebでForest競合のポモドーロタイマーを実装した — CustomPainter円形タイマー + Supabase Edge Function連携
emoji: ⏱️
type: tech
topics: [flutter, supabase, pomodoro, dart, webdev]
published: true
---

# ブログ下書き 2026-04-09 — 2026-04-09-pomodoro-focus-timer

## タイトル案
1. Flutter WebでForest競合のポモドーロタイマーを実装した — CustomPainter円形タイマー + Supabase Edge Function連携
2. ポモドーロタイマーをFlutter Webで作る — dart:async Timer × カスタム円形プログレス × Edge Function集中スコア
3. 21競合統合アプリにポモドーロ機能を追加した実装記録 — Forest/Focusmateを自前実装する方法

## 投稿先候補
- [ ] Zenn
- [ ] Qiita
- [ ] note
- [ ] はてなブログ
- [ ] X Article
- [ ] Medium
- [ ] dev.to
- [ ] Hashnode
- [ ] Substack
- [ ] GitHub Pages
- [ ] NOTION

---

## 本文下書き (約2500字)

### はじめに

「自分株式会社」はFlutter Web + Supabase Edge Functions (Deno) で構築したAI統合ライフマネジメントアプリです。Notion・Slack・MoneyForward・Forestなど21社の競合機能を1つに集約することを目標にしています。

今回はForest/Focusmate競合として **ポモドーロ集中タイマー** を実装しました。127行のスタブから全面刷新し、以下の機能を持つ本実装に仕上げました。

- **CustomPainter による円形アニメーション**タイマー
- **dart:async Timer** でリアルタイムカウントダウン
- **作業/休憩モード** の自動切り替え (WORK/BREAK)
- **セッション開始/完了/キャンセル** を Supabase Edge Function で永続化
- **集中スコア** (30日ウィンドウ) とストリーク日数の統計タブ

---

### 実装のポイント 1: dart:async Timer でカウントダウン

Flutter の `dart:async` パッケージには `Timer.periodic` があり、1秒ごとにコールバックを呼び出してカウントダウンを実現できます。

```dart
Timer? _ticker;

void _startCountdown() {
  setState(() => _isRunning = true);
  _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
    if (!mounted) return;
    if (_secondsLeft > 0) {
      setState(() => _secondsLeft--);
    } else {
      _onTimerComplete();
    }
  });
}
```

**注意点**: `if (!mounted) return;` のガードは必須です。`dispose()` 後にタイマーコールバックが走ると `setState` がクラッシュします。

```dart
@override
void dispose() {
  _ticker?.cancel();  // 必ずキャンセル
  super.dispose();
}
```

---

### 実装のポイント 2: CustomPainter で円形プログレスバー

Flutter標準の `CircularProgressIndicator` は細部のカスタマイズが難しいため、`CustomPainter` で実装しました。

```dart
class _TimerPainter extends CustomPainter {
  _TimerPainter({
    required this.progress,  // 0.0〜1.0
    required this.color,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // 背景の円弧
    final bgPaint = Paint()
      ..color = bgColor
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // 進捗の円弧 (上から時計回り)
    final sweepAngle = 2 * math.pi * progress;
    final fgPaint = Paint()
      ..color = color
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,  // 12時の位置からスタート
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_TimerPainter old) =>
      old.progress != progress || old.color != color;
}
```

`shouldRepaint` で `progress` または `color` が変わった時のみ再描画することでパフォーマンスを確保しています。

---

### 実装のポイント 3: Edge Function でセッションを永続化

セッションの開始・完了・キャンセルはSupabase Edge Function (`focus-timer`) で管理します。これにより:
- データはSupabaseのPostgreSQLに保存されクロスデバイス同期
- クライアントはシンプルなREST呼び出しのみ
- 集中スコア算出などのロジックはバックエンドに集約

```dart
// セッション開始
final res = await _supabase.functions.invoke(
  'focus-timer',
  body: {
    'action': 'start',
    'task_label': _taskController.text,
    'duration_minutes': _workMinutes,
  },
);
final data = res.data;
if (data is Map<String, dynamic>) {
  final session = data['session'];
  if (session is Map<String, dynamic>) {
    _activeSessionId = session['id']?.toString();
  }
}
```

**型安全のポイント**: `res.data` は `dynamic` 型なので、`is Map<String, dynamic>` でチェックしてからキャストします。さらに `session` も同様にキャストして `avoid_dynamic_calls` lint エラーを防いでいます。

---

### 実装のポイント 4: 統計データの型安全な取り扱い

Edge FunctionからJSONで返ってくる数値は `dynamic` 型になるため、`num` → `int` のキャストが必要です:

```dart
// 間違い (avoid_dynamic_calls lint エラー)
final focusScore = _stats['focus_score'];
value: focusScore / 100.0,  // dynamic呼び出しでエラー

// 正しい
final focusScore = (_stats['focus_score'] as num?)?.toInt() ?? 0;
value: focusScore / 100.0,  // int / double → OK
```

`num?` にキャストしてから `toInt()` を呼ぶことで、`int` または `double` のどちらが来ても安全に処理できます。

---

### DBスキーマ (focus_sessions テーブル)

```sql
CREATE TABLE focus_sessions (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  task_label       TEXT NOT NULL DEFAULT '集中作業',
  duration_minutes INTEGER NOT NULL DEFAULT 25,
  status           TEXT NOT NULL DEFAULT 'active'
                   CHECK (status IN ('active', 'completed', 'cancelled')),
  started_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at     TIMESTAMPTZ
);

-- RLS: ユーザーは自分のセッションのみアクセス可
ALTER TABLE focus_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users manage own"
  ON focus_sessions FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
```

---

### ポモドーロプリセットの実装

25/5、50/10、90/20 の3つのプリセットを Record 型のリストで定義:

```dart
static const _presets = [
  ('25 / 5', 25, 5),
  ('50 / 10', 50, 10),
  ('90 / 20', 90, 20),
];

// 使用箇所
Row(
  children: _presets.map((p) {
    final (label, work, brk) = p;  // Dart 3 record destructuring
    return ChoiceChip(
      label: Text(label),
      selected: work == _workMinutes && brk == _breakMinutes,
      onSelected: (v) {
        if (!v) return;
        setState(() {
          _workMinutes = work;
          _breakMinutes = brk;
          _secondsLeft = (_isBreak ? brk : work) * 60;
        });
      },
    );
  }).toList(),
)
```

Dart 3 のパターンマッチング (Record destructuring) を使って `(label, work, brk)` と簡潔に分解できます。

---

### まとめ

今回の実装で学んだポイント:
1. `Timer.periodic` + `mounted` ガードで安全なカウントダウン
2. `CustomPainter` で円形タイマーを自由にカスタマイズ
3. `dynamic` 型の安全なキャスト (`num?)?.toInt()`) で `avoid_dynamic_calls` lint を回避
4. `require_trailing_commas` lint: Flutter では全ての引数リストに末尾コンマが必要
5. Edge Function + Supabase RLS でデータを安全に永続化

「自分株式会社」ではForest・Habitica・Duolingoのような習慣化機能を自前実装し、Notion・Slack・MoneyForwardなど21競合と戦っています。

👉 今すぐ試す: https://my-web-app-b67f4.web.app/

---
URL: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #Pomodoro #buildinpublic #Flutter
