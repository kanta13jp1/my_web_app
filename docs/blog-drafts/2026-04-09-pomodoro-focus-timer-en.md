---
title: "Building a Pomodoro Timer in Flutter Web: CustomPainter Circle + Dart 3 Record Destructuring"
tags: Flutter,Supabase,buildinpublic,Dart,productivity
published: true
---

# Building a Pomodoro Timer in Flutter Web: CustomPainter Circle + Dart 3 Record Destructuring

## What We Built

A full Pomodoro timer for [自分株式会社](https://my-web-app-b67f4.web.app/) competing with Forest and Focusmate:

- `CustomPainter` circular progress ring
- `Timer.periodic` countdown with `mounted` safety guard
- Work / Break mode auto-switch
- Session start / complete / cancel persisted to Supabase
- Focus score (30-day window) + streak stats tab

---

## Timer: `Timer.periodic` + `mounted` Guard

```dart
Timer? _ticker;

void _startCountdown() {
  setState(() => _isRunning = true);
  _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
    if (!mounted) return;           // guard against disposed widget
    if (_secondsLeft > 0) {
      setState(() => _secondsLeft--);
    } else {
      _onTimerComplete();
    }
  });
}

@override
void dispose() {
  _ticker?.cancel();                // always cancel — prevents setState after dispose
  super.dispose();
}
```

`if (!mounted) return` inside the callback is non-negotiable. If the user navigates away while the timer is running, the widget gets disposed but the `Timer` keeps firing — without the guard, `setState` throws.

---

## Circular Progress: `CustomPainter`

`CircularProgressIndicator` doesn't allow fine-grained control over stroke width, cap style, or colors. `CustomPainter` does:

```dart
class _TimerPainter extends CustomPainter {
  _TimerPainter({
    required this.progress,   // 0.0–1.0
    required this.color,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Background ring
    final bgPaint = Paint()
      ..color = bgColor
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc — starts at 12 o'clock (-π/2), sweeps clockwise
    final sweepAngle = 2 * math.pi * progress;
    final fgPaint = Paint()
      ..color = color
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,   // start angle: top of circle
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

Key details:
- `-math.pi / 2` starts the arc at 12 o'clock (default `drawArc` starts at 3 o'clock)
- `StrokeCap.round` gives rounded endpoints
- `shouldRepaint` skips repaints when neither `progress` nor `color` changed

---

## Dart 3 Record Destructuring for Presets

Three Pomodoro presets defined as a `const` list of records:

```dart
static const _presets = [
  ('25 / 5',  25, 5),
  ('50 / 10', 50, 10),
  ('90 / 20', 90, 20),
];

Row(
  children: _presets.map((p) {
    final (label, work, brk) = p;    // Dart 3 record destructuring
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

`final (label, work, brk) = p` unpacks the tuple in one line. No separate class or enum needed for a (label, int, int) tuple.

---

## Edge Function: Session Persistence

Sessions are persisted to Supabase — not local state:

```dart
final res = await _supabase.functions.invoke(
  'focus-timer',
  body: {
    'action': 'start',
    'task_label': _taskController.text,
    'duration_minutes': _workMinutes,
  },
);
final data = res.data as Map<String, dynamic>?;
final session = data?['session'] as Map<String, dynamic>?;
_activeSessionId = session?['id']?.toString();
```

`_activeSessionId` is stored in state. On `complete` or `cancel`, this ID is passed back to the Edge Function to update the record — even if the user navigated away and returned.

### Type-Safe Stats: `(num?)?.toInt()`

JSON numbers from the Edge Function arrive as `dynamic`. Direct arithmetic triggers `avoid_dynamic_calls`:

```dart
// WRONG — lint error
value: _stats['focus_score'] / 100.0;

// CORRECT
final focusScore = (_stats['focus_score'] as num?)?.toInt() ?? 0;
value: focusScore / 100.0;
```

Cast to `num?` first (handles both `int` and `double`), then call `.toInt()`. One extra line prevents a class of runtime type errors.

---

## DB Schema: `focus_sessions`

```sql
CREATE TABLE focus_sessions (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  task_label       TEXT NOT NULL DEFAULT 'Focus Session',
  duration_minutes INTEGER NOT NULL DEFAULT 25,
  status           TEXT NOT NULL DEFAULT 'active'
                   CHECK (status IN ('active', 'completed', 'cancelled')),
  started_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at     TIMESTAMPTZ
);

ALTER TABLE focus_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users manage own"
  ON focus_sessions FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
```

RLS ensures each user sees only their own sessions — no `user_id` filter needed in the Edge Function.

---

## Summary

| Pattern | What it solves |
|---------|---------------|
| `Timer.periodic` + `mounted` guard | Safe countdown without setState after dispose |
| `CustomPainter` arc | Full control over circle timer appearance |
| Dart 3 record destructuring | Preset tuples without a class |
| `(num?)?.toInt()` cast | Type-safe JSON stats from Edge Function |
| `_activeSessionId` in state | Correct session tracking across navigations |

---

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #Dart #productivity
