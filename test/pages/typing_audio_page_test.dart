import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/typing_game_page.dart';
import 'package:my_web_app/services/typing_audio.dart';

class PageAudio implements TypingAudioBackend {
  bool active = false;
  int unlocks = 0;
  int disposed = 0;
  @override
  Future<bool> unlock() async {
    unlocks++;
    return true;
  }

  @override
  void levels(double music, double effects) {}
  @override
  void playing(bool value) => active = value;
  @override
  void effect(TypingSound sound) {}
  @override
  void suspend() => active = false;
  @override
  void dispose() {
    disposed++;
    active = false;
  }
}

void main() {
  testWidgets('sound controls are opt-in, separate, muted and route-safe',
      (tester) async {
    final backend = PageAudio();
    final audio = TypingAudio(backend: backend);
    await tester.pumpWidget(MaterialApp(home: TypingGamePage(audio: audio)));
    final settings = find.text('サウンド設定');
    await tester.ensureVisible(settings);
    await tester.tap(settings);
    await tester.pumpAndSettle();
    expect(backend.unlocks, 0);
    final enable = find.byKey(const Key('typing-audio-enable'));
    await tester.ensureVisible(enable);
    await tester.tap(enable);
    await tester.pumpAndSettle();
    expect(backend.unlocks, 1);
    expect(backend.active, isFalse);
    tester
        .widget<Slider>(find.byKey(const Key('typing-music-volume')))
        .onChanged!(0);
    tester
        .widget<Slider>(find.byKey(const Key('typing-effects-volume')))
        .onChanged!(0.6);
    await tester.pump();
    expect(audio.musicVolume, 0);
    expect(audio.effectsVolume, 0.6);
    await tester.ensureVisible(find.text('10問じっくり練習'));
    await tester.tap(find.text('10問じっくり練習'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('typing-start')));
    await tester.tap(find.byKey(const Key('typing-start')));
    await tester.pump();
    expect(backend.active, isTrue);
    final mute = find.byType(SwitchListTile);
    tester.widget<SwitchListTile>(mute).onChanged!(true);
    await tester.pump();
    expect(backend.active, isFalse);
    tester.widget<SwitchListTile>(mute).onChanged!(false);
    await tester.pump();
    expect(backend.active, isTrue);
    final context = tester.element(find.byType(TypingGamePage));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('Covered')),
      ),
    );
    await tester.pumpAndSettle();
    expect(backend.active, isFalse);
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(audio.enabled, isFalse);
    expect(backend.active, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(backend.disposed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unsupported sound retains silent game controls', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TypingGamePage()));
    await tester.ensureVisible(find.text('サウンド設定'));
    await tester.tap(find.text('サウンド設定'));
    await tester.pumpAndSettle();
    final enable = find.byKey(const Key('typing-audio-enable'));
    await tester.ensureVisible(enable);
    await tester.tap(enable);
    await tester.pumpAndSettle();
    expect(find.textContaining('無音でそのまま遊べます'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('typing-start')));
    await tester.tap(find.byKey(const Key('typing-start')));
    await tester.pump();
    expect(find.byKey(const Key('typing-input')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
