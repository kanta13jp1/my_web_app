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

    test('R26: carries the measured 97K data-digest lesson', () {
      // 過去3ヶ月トップ 97K と同日比較(3.2K / 517 / 28)を両生成経路が
      // 共有定数経由で受け取り、単発要因の過剰断定と数値流用も禁止する。
      expect(xPrompt, contains(kDataReportArchetypeLesson));
      expect(kDataReportArchetypeLesson, contains('97K'));
      expect(kDataReportArchetypeLesson, contains('データダイジェスト型'));
      expect(kDataReportArchetypeLesson, contains('3.2K'));
      expect(kDataReportArchetypeLesson, contains('因果とは断定しない'));
      expect(kDataReportArchetypeLesson, contains('公式ソース'));
      expect(kDataReportArchetypeLesson, contains('流用してはならない'));
      expect(kDataReportArchetypeLesson, contains('捏造は禁止'));
      // CmoPage 経路には実数の供給源が無い(見出しも実測データも渡さない)ため、
      // 教訓は「冒頭に実数」命令を含まず、数字の新規生成を明示的に禁止する
      // ガードと併記される(レビュー F3/F4 の捏造圧力対策)。
      expect(kDataReportArchetypeLesson, isNot(contains('冒頭1行目に')));
      expect(xPrompt, contains('新しい数字を作るな'));
    });

    test(
      'preserves per-channel length spec (facebook 220-420 not overridden)',
      () {
        final fbPrompt = buildCmoDraftPrompt(
          channelKey: 'facebook',
          channelLabel: 'Facebook',
          spec: fbSpec,
          hashtags: const ['#自分株式会社'],
        );
        expect(fbPrompt, contains('220-420'));
        expect(xPrompt, contains('80-140'));
      },
    );

    test('R23 F3: measured data line unlocks the real-number path', () {
      // 実測供給源が無いとき(既定): 捏造禁止ガード。
      expect(xPrompt, contains('新しい数字を作るな'));
      expect(xPrompt, isNot(contains('冒頭1行目にこの実測値')));

      // 実測データ行があるとき: 実数を使ってよい経路+この行に無い数字は禁止。
      const line =
          'Own measured data (REAL numbers you MAY publish first-person as '
          'build-in-public stats): measured posts=12, median impressions=517, '
          'best impressions=17200.';
      final measuredPrompt = buildCmoDraftPrompt(
        channelKey: 'x_share',
        channelLabel: 'X (Twitter)',
        spec: xSpec,
        hashtags: const ['#自分株式会社'],
        measuredDataLine: line,
      );
      expect(measuredPrompt, contains('best impressions=17200'));
      expect(measuredPrompt, contains('冒頭1行目にこの実測値を1つ置け'));
      expect(measuredPrompt, contains('この実測行と上の実在機能リストに無い数字は作るな'));
      // 供給源がある日は「新しい数字を作るな(供給源なし)」ガードは出さない。
      expect(measuredPrompt, isNot(contains('渡していないので、新しい数字を作るな')));
    });
  });

  group('extractOwnMeasuredDataLine', () {
    test('pulls the Own measured data line from performance context', () {
      const context = 'Measured X performance context for the next post:\n'
          'Target: 10K impressions. Current best variant: daily_briefing.\n'
          'Own measured data (REAL numbers you MAY publish first-person as '
          'build-in-public stats): measured posts=12, median impressions=517, '
          'best impressions=17200.\n'
          'Use the winning structure, test one variable at a time.';
      final line = extractOwnMeasuredDataLine(context);
      expect(line, isNotNull);
      expect(line, startsWith('Own measured data'));
      expect(line, contains('best impressions=17200'));
    });

    test('returns null when absent, empty, or null', () {
      expect(extractOwnMeasuredDataLine(null), isNull);
      expect(extractOwnMeasuredDataLine(''), isNull);
      expect(
        extractOwnMeasuredDataLine('No measured X performance yet.'),
        isNull,
      );
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

  group('detectStaleYears (年号誤りの事後検出)', () {
    // 実測: プロンプトに「never write 2024」があるのに X へ出荷された実例。
    final now = DateTime(2026, 7, 28);

    test('実際に出荷された 2024 誤記を検出する', () {
      final hits = detectStaleYears(
        'デイリーブリーフィング — 2024/07/05 朝',
        now: now,
      );
      expect(hits, ['2024']);
    });

    test('当年・近傍年・翌年の正当な参照は誤検出しない', () {
      // 2023年統一地方選実績 / 2027年統一地方選 は実在の投稿文面。
      final hits = detectStaleYears(
        '2026/07/28時点。2023年統一地方選実績: 183。次回は2027年春。',
        now: now,
      );
      expect(hits, isEmpty);
    });

    test('年に見えない4桁や年号でない数値は拾わない', () {
      // 「700まで残り 317人」「公式地方議員数: 383人」などの実数行。
      final hits = detectStaleYears(
        '公式地方議員数: 383人 基準340との差分: 43人 700まで残り: 317人',
        now: now,
      );
      expect(hits, isEmpty);
    });

    test('裸の年(過去実績への言及)は見ない — 完全な日付だけを見る', () {
      // 実在の投稿文面。ここを拾うと毎回誤警告になり、警告自体が無視される。
      final hits = detectStaleYears(
        '2023年統一地方選実績: 62 + 121 = 183',
        now: now,
      );
      expect(hits, isEmpty);
    });

    test('将来の節目の完全な日付は許す', () {
      final hits = detectStaleYears(
        '次回統一地方選(2027/04/11目安)まであと263日',
        now: now,
      );
      expect(hits, isEmpty);
    });

    test('ISO 形式の取得日時(当年)は許す', () {
      final hits = detectStaleYears(
        '取得日時: 2026-07-22T23:13:36.375',
        now: now,
      );
      expect(hits, isEmpty);
    });

    test('composeStaleYearWarning は投稿を止めず今年を示す', () {
      final w = composeStaleYearWarning(['2024'], now: now);
      expect(w, isNotNull);
      expect(w, contains('2024'));
      expect(w, contains('2026年'));
    });

    test('クリーンなら警告は出ない', () {
      expect(composeStaleYearWarning(const [], now: now), isNull);
    });
  });
}
