import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/deadline_weight_models.dart';
import 'package:my_web_app/pages/deadline_weight_page.dart';
import 'package:my_web_app/services/deadline_weight_service.dart';

/// Supabase を初期化せずに分岐を検証するためのフェイク。
class _FakeDeadlineWeightService extends DeadlineWeightService {
  _FakeDeadlineWeightService({
    this.signedIn = true,
    this.items = const <Map<String, dynamic>>[],
    this.settings,
  }) : super();

  final bool signedIn;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic>? settings;

  @override
  bool get isSignedIn => signedIn;

  @override
  Future<List<Map<String, dynamic>>> fetchItems() async => items;

  @override
  Future<Map<String, dynamic>?> fetchSettings() async => settings;
}

// 固定 now: 2026-11-30 (月) 12:00 — 1 日のちょうど半分が経過した時点。
final DateTime kNow = DateTime(2026, 11, 30, 12);

/// 毎日 120 分だけ手を動かせる設定 (計算を読みやすくするため全曜日同じ)。
const DisposableTimeSettings kFlat120 = DisposableTimeSettings(
  minutesByWeekday: <int, int>{
    DateTime.monday: 120,
    DateTime.tuesday: 120,
    DateTime.wednesday: 120,
    DateTime.thursday: 120,
    DateTime.friday: 120,
    DateTime.saturday: 120,
    DateTime.sunday: 120,
  },
);

Map<String, dynamic> itemRow({
  String id = 'i1',
  String title = '確定申告の書類',
  String dueOn = '2026-12-04',
  int requiredMinutes = 120,
  String? completedAt,
}) {
  return <String, dynamic>{
    'id': id,
    'title': title,
    'due_on': dueOn,
    'required_minutes': requiredMinutes,
    'completed_at': completedAt,
  };
}

Map<String, dynamic> settingsRow(int minutes) => <String, dynamic>{
      'monday_minutes': minutes,
      'tuesday_minutes': minutes,
      'wednesday_minutes': minutes,
      'thursday_minutes': minutes,
      'friday_minutes': minutes,
      'saturday_minutes': minutes,
      'sunday_minutes': minutes,
    };

void main() {
  group('disposableMinutesUntil', () {
    test('当日が期日なら、今日の残りぶんだけ按分される', () {
      // 12:00 時点 = 1 日の半分が残っている → 120 分 * 0.5 = 60 分。
      expect(
        disposableMinutesUntil(kNow, DateTime(2026, 11, 30), kFlat120),
        60,
      );
    });

    test('朝に見ると残りは多く、夜に見ると少ない', () {
      final morning = DateTime(2026, 11, 30, 6);
      final night = DateTime(2026, 11, 30, 21);
      final due = DateTime(2026, 11, 30);

      expect(disposableMinutesUntil(morning, due, kFlat120), 90);
      expect(disposableMinutesUntil(night, due, kFlat120), 15);
    });

    test('翌日以降は曜日設定をそのまま積み上げる', () {
      // 今日の残り 60 分 + 12/1〜12/4 の 4 日 * 120 分 = 540 分。
      expect(
        disposableMinutesUntil(kNow, DateTime(2026, 12, 4), kFlat120),
        540,
      );
    });

    test('曜日ごとの差が反映される', () {
      // 11/30(月) 残り 60 + 12/1(火) 0 + 12/2(水) 300 = 360。
      const settings = DisposableTimeSettings(
        minutesByWeekday: <int, int>{
          DateTime.monday: 120,
          DateTime.tuesday: 0,
          DateTime.wednesday: 300,
          DateTime.thursday: 120,
          DateTime.friday: 120,
          DateTime.saturday: 120,
          DateTime.sunday: 120,
        },
      );
      expect(
        disposableMinutesUntil(kNow, DateTime(2026, 12, 2), settings),
        360,
      );
    });

    test('期日が過ぎていれば 0', () {
      expect(
        disposableMinutesUntil(kNow, DateTime(2026, 11, 29), kFlat120),
        0,
      );
    });
  });

  group('calendarDaysLeft / 表記', () {
    test('今日を 1 日目として数える', () {
      expect(calendarDaysLeft(kNow, DateTime(2026, 11, 30)), 1);
      expect(calendarDaysLeft(kNow, DateTime(2026, 12, 4)), 5);
      expect(calendarDaysLeft(kNow, DateTime(2026, 11, 29)), 0);
    });

    test('残り日数の表記', () {
      expect(formatDaysLeft(5), 'あと5日');
      expect(formatDaysLeft(1), '今日まで');
      expect(formatDaysLeft(0), '1日超過');
      expect(formatDaysLeft(-1), '2日超過');
    });

    test('分の表記', () {
      expect(formatMinutes(0), '0分');
      expect(formatMinutes(45), '45分');
      expect(formatMinutes(120), '2時間');
      expect(formatMinutes(1110), '18時間30分');
    });
  });

  group('buildCard の判定', () {
    DeadlineWeightCard cardFor(int requiredMinutes, String dueOn) {
      return buildCard(
        DeadlineItem.fromRow(
          itemRow(dueOn: dueOn, requiredMinutes: requiredMinutes),
        ),
        kFlat120,
        kNow,
      );
    }

    test('可処分が必要の 1.5 倍以上なら「間に合う」', () {
      // 12/4 まで = 540 分。必要 300 分 → 540 >= 450。
      expect(cardFor(300, '2026-12-04').verdict, DeadlineVerdict.comfortable);
    });

    test('足りてはいるが余裕が 5 割未満なら「ギリギリ」', () {
      // 540 分に対して必要 500 分 → 540 < 750。
      expect(cardFor(500, '2026-12-04').verdict, DeadlineVerdict.tight);
    });

    test('可処分が必要に届かなければ「時間が足りない」', () {
      expect(cardFor(900, '2026-12-04').verdict, DeadlineVerdict.short);
    });

    test('期日を過ぎていれば「期日を過ぎた」で可処分は 0', () {
      final card = cardFor(60, '2026-11-28');
      expect(card.verdict, DeadlineVerdict.overdue);
      expect(card.disposableMinutes, 0);
      expect(card.recovery, isNull);
    });

    test('余り・不足が符号付きで出る', () {
      expect(cardFor(300, '2026-12-04').slackMinutes, 240);
      expect(cardFor(900, '2026-12-04').slackMinutes, -360);
    });
  });

  group('責めない 3 択 (RecoveryOptions)', () {
    test('不足時は 3 つとも具体的な数字が入る', () {
      // 12/4 まで = 540 分、必要 900 分 → 360 分不足。残り 5 日。
      final card = buildCard(
        DeadlineItem.fromRow(
          itemRow(dueOn: '2026-12-04', requiredMinutes: 900),
        ),
        kFlat120,
        kNow,
      );
      final recovery = card.recovery;

      expect(recovery, isNotNull);
      expect(recovery!.cutMinutes, 360);
      // 360 分を残り 5 日に割る → 1 日 72 分。
      expect(recovery.extraMinutesPerDay, 72);
      // 1 日 120 分なので 3 日延ばせば 540 + 360 = 900 に届く。
      expect(recovery.postponeDays, 3);
    });

    test('可処分が週 0 分なら、期日の後ろ倒しでは解決しない', () {
      const empty = DisposableTimeSettings(minutesByWeekday: <int, int>{});
      final card = buildCard(
        DeadlineItem.fromRow(
          itemRow(dueOn: '2026-12-04', requiredMinutes: 60),
        ),
        empty,
        kNow,
      );

      expect(card.verdict, DeadlineVerdict.short);
      expect(card.recovery!.postponeDays, isNull);
      expect(card.recovery!.cutMinutes, 60);
    });
  });

  group('buildDeadlineWeightSnapshot', () {
    test('完了したものは一覧から外れる', () {
      final snapshot = buildDeadlineWeightSnapshot(
        <Map<String, dynamic>>[
          itemRow(id: 'open'),
          itemRow(id: 'done', completedAt: '2026-11-29T10:00:00Z'),
        ],
        settingsRow(120),
        kNow,
      );

      expect(snapshot.totalCount, 1);
      expect(snapshot.active.single.item.id, 'open');
    });

    test('期日を過ぎたものは別枠に入る', () {
      final snapshot = buildDeadlineWeightSnapshot(
        <Map<String, dynamic>>[
          itemRow(id: 'future', dueOn: '2026-12-10'),
          itemRow(id: 'past', dueOn: '2026-11-20'),
        ],
        settingsRow(120),
        kNow,
      );

      expect(snapshot.active.single.item.id, 'future');
      expect(snapshot.overdue.single.item.id, 'past');
    });

    test('期日の近い順に並び、同じ期日なら不足の大きいものが上', () {
      final snapshot = buildDeadlineWeightSnapshot(
        <Map<String, dynamic>>[
          itemRow(id: 'later', dueOn: '2026-12-20', requiredMinutes: 60),
          itemRow(id: 'soon-easy', dueOn: '2026-12-02', requiredMinutes: 10),
          itemRow(id: 'soon-hard', dueOn: '2026-12-02', requiredMinutes: 900),
        ],
        settingsRow(120),
        kNow,
      );

      expect(
        snapshot.active.map((c) => c.item.id).toList(),
        <String>['soon-hard', 'soon-easy', 'later'],
      );
    });

    test('不足件数を数える', () {
      final snapshot = buildDeadlineWeightSnapshot(
        <Map<String, dynamic>>[
          itemRow(id: 'ok', dueOn: '2026-12-20', requiredMinutes: 60),
          itemRow(id: 'ng', dueOn: '2026-12-01', requiredMinutes: 900),
        ],
        settingsRow(120),
        kNow,
      );

      expect(snapshot.shortCount, 1);
    });

    test('空入力でも壊れず、設定は初期値になる', () {
      final snapshot = buildDeadlineWeightSnapshot(
        <Map<String, dynamic>>[],
        null,
        kNow,
      );

      expect(snapshot.isEmpty, isTrue);
      expect(snapshot.totalCount, 0);
      expect(
        snapshot.settings.weeklyMinutes,
        DisposableTimeSettings.initial.weeklyMinutes,
      );
    });

    test('タイトルが空の行は無視する', () {
      final snapshot = buildDeadlineWeightSnapshot(
        <Map<String, dynamic>>[itemRow(title: '   ')],
        settingsRow(120),
        kNow,
      );

      expect(snapshot.isEmpty, isTrue);
    });
  });

  group('DisposableTimeSettings', () {
    test('行が無ければ初期値 (平日2時間 / 週末5時間)', () {
      const initial = DisposableTimeSettings.initial;
      expect(
        DisposableTimeSettings.fromRow(null).weeklyMinutes,
        initial.weeklyMinutes,
      );
      expect(initial.weeklyMinutes, 120 * 5 + 300 * 2);
    });

    test('往復 (fromRow → toRow) で値が保たれる', () {
      final parsed = DisposableTimeSettings.fromRow(settingsRow(90));
      expect(parsed.toRow()['wednesday_minutes'], 90);
      expect(parsed.weeklyMinutes, 90 * 7);
    });

    test('1 日 1440 分を超える値はクランプされる', () {
      final parsed = DisposableTimeSettings.fromRow(settingsRow(9999));
      expect(parsed.minutesOn(DateTime(2026, 11, 30)), 1440);
    });

    test('copyWith は指定した曜日だけ変える', () {
      final next = kFlat120.copyWith(weekday: DateTime.friday, minutes: 300);
      expect(next.minutesByWeekday[DateTime.friday], 300);
      expect(next.minutesByWeekday[DateTime.monday], 120);
    });
  });

  group('DeadlineWeightPage', () {
    testWidgets('未ログインはログイン導線のみ表示し、盤面を出さない', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DeadlineWeightPage(
            service: _FakeDeadlineWeightService(signedIn: false),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('この機能はログインが必要です'), findsOneWidget);
      expect(find.text('ログインする'), findsOneWidget);
      expect(find.text('締め切りを追加'), findsNothing);
    });

    testWidgets('ログイン済みで締め切りが無ければ空状態を出す', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DeadlineWeightPage(service: _FakeDeadlineWeightService()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text('まだ締め切りがありません'), findsOneWidget);
      expect(find.text('締め切りを追加'), findsOneWidget);
    });

    testWidgets('締め切りがあれば残り時間と判定を表示する', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DeadlineWeightPage(
            service: _FakeDeadlineWeightService(
              items: <Map<String, dynamic>>[
                // 十分に先の期日なので「間に合う」側に倒れる。
                itemRow(
                  title: '確定申告の書類',
                  dueOn: '2099-12-31',
                  requiredMinutes: 60,
                ),
              ],
              settings: settingsRow(120),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text('確定申告の書類'), findsOneWidget);
      expect(find.text('間に合う'), findsOneWidget);
      expect(find.textContaining('必要と見ているのは 1時間'), findsOneWidget);
      expect(find.text('まだ締め切りがありません'), findsNothing);
    });

    testWidgets('足りないときは責めず「打てる手」を出す', (tester) async {
      final soon = DateTime.now().add(const Duration(days: 1));
      final dueOn = '${soon.year}-'
          '${soon.month.toString().padLeft(2, '0')}-'
          '${soon.day.toString().padLeft(2, '0')}';

      await tester.pumpWidget(
        MaterialApp(
          home: DeadlineWeightPage(
            service: _FakeDeadlineWeightService(
              items: <Map<String, dynamic>>[
                itemRow(
                  title: '引っ越しの手続き',
                  dueOn: dueOn,
                  requiredMinutes: 3000,
                ),
              ],
              settings: settingsRow(60),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text('時間が足りない'), findsOneWidget);
      expect(find.text('打てる手'), findsOneWidget);
      expect(find.textContaining('削る'), findsOneWidget);
      expect(find.textContaining('増やす'), findsOneWidget);
    });
  });
}
