import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/x_copy_guardrails.dart';

void main() {
  const xSpec = <String, String>{
    'goal': 'X向けに3秒で伝わる短文を作る',
    'titleRule': '見出しは28文字以内で強いフックを入れる',
    'bodyRule': '本文は80-140文字。問題提起、便益、CTAを1つずつ入れる',
    'tone': 'sharp, compact, high-contrast',
  };
  const fbSpec = <String, String>{
    'goal': 'Facebook向けに文脈説明つきの長文を作る',
    'titleRule': '見出しは28-48文字で内容が分かるようにする',
    'bodyRule': '本文は220-420文字。課題、価値、CTAの3段落で書く',
    'tone': 'warm, persuasive, slightly detailed',
  };

  group('buildCmoDraftPrompt injects the anti-slop apparatus', () {
    final xPrompt = buildCmoDraftPrompt(
      channelKey: 'x_share',
      channelLabel: 'X',
      spec: xSpec,
      hashtags: const ['#自分株式会社', '#個人開発', '#buildinpublic'],
    );

    test('carries feature facts, first-person ban, and slop bans', () {
      expect(xPrompt, contains('給料日サイクル'));
      expect(xPrompt, contains('一人称'));
      expect(xPrompt, contains('私たち')); // banned brand-voice explicitly listed
      // observed slop tokens are present as bans.
      for (final t in ['埋もれていませんか', '自分集客力', '最大限にアピール']) {
        expect(xPrompt, contains(t), reason: 'ban $t missing');
      }
      // still a valid {title,body,hashtags} contract.
      expect(xPrompt, contains('title'));
      expect(xPrompt, contains('body'));
      expect(xPrompt, contains('hashtags'));
    });

    test('R23: carries the measured data-report archetype lesson', () {
      // 2026-07-12 同日3連投の実測(データレポート型 3.2K vs ニュース要約 517
      // vs 製品転換 28)を両生成経路が共有定数経由で受け取ることを固定する。
      expect(xPrompt, contains(kDataReportArchetypeLesson));
      expect(kDataReportArchetypeLesson, contains('データレポート型'));
      expect(kDataReportArchetypeLesson, contains('3.2K'));
      expect(kDataReportArchetypeLesson, contains('捏造は禁止'));
      // CmoPage 経路には実数の供給源が無い(見出しも実測データも渡さない)ため、
      // 教訓は「冒頭に実数」命令を含まず、数字の新規生成を明示的に禁止する
      // ガードと併記される(レビュー F3/F4 の捏造圧力対策)。
      expect(kDataReportArchetypeLesson, isNot(contains('冒頭1行目に')));
      expect(xPrompt, contains('新しい数字を作るな'));
    });

    test('preserves per-channel length spec (facebook 220-420 not overridden)',
        () {
      final fbPrompt = buildCmoDraftPrompt(
        channelKey: 'facebook',
        channelLabel: 'Facebook',
        spec: fbSpec,
        hashtags: const ['#自分株式会社'],
      );
      expect(fbPrompt, contains('220-420'));
      expect(xPrompt, contains('80-140'));
    });
  });

  group('detectSlop / hasFeatureAnchor', () {
    const observedSlop = 'あなたの価値、埋もれていませんか？埋もれた才能を最大限にアピールし、'
        '社会で輝くための自分集客力を構築。理想の未来へ、今すぐ一歩を踏み出しましょう。';
    const goodCopy = '『給料日サイクル』は支出の窓を給料日起点に切る機能。作って分かったのは、'
        '月初をまたぐ引き落としが二重計上されず支出が実額で出ること。';

    test('detectSlop flags the real prod slop, passes the good copy', () {
      final flagged = detectSlop('あなたの価値、埋もれていませんか？', observedSlop);
      expect(flagged, contains('埋もれていませんか'));
      expect(flagged, contains('自分集客力'));
      expect(detectSlop('給料日サイクルの話', goodCopy), isEmpty);
    });

    test('hasFeatureAnchor: good copy names a feature, slop does not', () {
      expect(hasFeatureAnchor('', goodCopy), isTrue);
      expect(hasFeatureAnchor('', observedSlop), isFalse);
    });

    test('drift guard: core R11 terms are in the shared banlist', () {
      expect(kSlopBannedTokens, contains('強力なツール'));
      expect(kSlopBannedTokens, contains('可能性があります'));
    });

    test('R22: observed dodge tokens are detectable', () {
      // 2026-07-11 実投稿で exact 禁止をかわした変形。
      const lead = '私のウェブアプリ『給料日サイクル』では支出を把握。'
          '家計の透明性が向上しました。ぜひ試してみてください。';
      final hits = detectSlop('', lead);
      expect(hits, contains('ウェブアプリ'));
      expect(hits, contains('が向上しました'));
      expect(hits, contains('ぜひ試して'));
    });

    test('composeSlopWarning: null when clean, message when hits', () {
      expect(composeSlopWarning(const []), isNull);
      final w = composeSlopWarning(const ['ぜひ試して'])!;
      expect(w, contains('言い換え候補'));
      expect(w, contains('ぜひ試して'));
      // 投稿は止めない文言(再生成の推奨に留める)。
      expect(w, contains('このまま投稿も可能'));
    });
  });
}
