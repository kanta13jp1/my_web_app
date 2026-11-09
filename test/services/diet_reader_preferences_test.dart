import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_web_app/services/diet_reader_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('保存先のfalseと例外を呼び出し元へ返し、その後の確認と保存を続行する', () async {
    const existing = 'diet_debates.v1.read.reader-a.note:existing';
    const size = 'diet_debates.font_size';
    SharedPreferences.setMockInitialValues({
      existing: true, size: 16.0, 'unrelated.setting': 'preserved',
    });
    final entered = Completer<void>();
    final release = Completer<void>();
    final order = <String>[];
    final settings = DietReaderPreferences(write: (prefs, key, value) async {
      order.add(key);
      if (key == existing && value == null) {
        entered.complete();
        await release.future;
        await prefs.remove(key); // Simulate a locally changed cache.
        return false;
      }
      if (value == 24.0) {
        await prefs.setDouble(key, 24.0);
        throw StateError('storage unavailable');
      }
      if (value == null) return prefs.remove(key);
      if (value is bool) return prefs.setBool(key, value);
      return prefs.setDouble(key, value as double);
    });
    final failedRemove = expectLater(settings.setRead('reader-a', 'note:existing', false),
        throwsA(isA<StateError>()));
    final failedSize = expectLater(settings.setFontSize(24.0), throwsA(isA<StateError>()));
    final afterErrors = settings.load('reader-a');
    final nextWrite = settings.setRead('reader-a', 'note:next', true);
    await entered.future;
    expect(order, [existing]);
    release.complete();
    await Future.wait([failedRemove, failedSize, nextWrite]);
    final restored = await afterErrors;
    expect(restored.readIds, {'note:existing'});
    expect(restored.uncertainReadIds, {'note:existing'});
    expect(restored.fontSize, 16.0);
    expect(restored.fontSizeUncertain, isTrue);
    final saved = await settings.load('reader-a');
    expect(saved.readIds, {'note:existing', 'note:next'});
    expect((await settings.load('reader-b')).readIds, isEmpty);
    await settings.setFontSize(20.0);
    expect((await settings.load('reader-a')).fontSize, 20.0);
    expect((await settings.load('reader-a')).fontSizeUncertain, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('unrelated.setting'), 'preserved');
  });

  test('書込前の例外も書込後の応答消失も、手動再設定まで結果は不明', () async {
    SharedPreferences.setMockInitialValues({});
    var fail = true;
    final settings = DietReaderPreferences(write: (prefs, key, value) async {
      if (fail && key.endsWith(':before')) throw StateError('before write');
      if (value == null) return prefs.remove(key);
      final result = await prefs.setBool(key, value as bool);
      if (fail) throw StateError('after write');
      return result;
    });
    for (final id in ['note:before', 'note:after']) {
      await expectLater(settings.setRead('A', id, true), throwsA(isA<StateError>()));
    }
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('diet_debates.v1.read.A.note:before'), isNull);
    expect(prefs.getBool('diet_debates.v1.read.A.note:after'), isTrue);
    expect((await settings.load('A')).uncertainReadIds, {'note:before', 'note:after'});
    expect((await settings.load('B')).uncertainReadIds, isEmpty);
    fail = false;
    await settings.setRead('A', 'note:before', true);
    await settings.setRead('A', 'note:after', false);
    final state = await settings.load('A');
    expect(state.uncertainReadIds, isEmpty);
    expect(state.readIds, {'note:before'});
  });
}
