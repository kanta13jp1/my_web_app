import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/utils/error_reporter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  test(
    'ignores Flutter web focus traversal layout errors from current release',
    () {
      const message =
          'Bad state: RenderBox was not laid out: minified:azD#35b6f';
      final currentReleaseStack = StackTrace.fromString('''
at Object.aX (https://my-web-app-b67f4.web.app/main.dart.js:3974:30)
at azD.gO (https://my-web-app-b67f4.web.app/main.dart.js:118967:18)
at azD.gng (https://my-web-app-b67f4.web.app/main.dart.js:118968:18)
at iu.ge3 (https://my-web-app-b67f4.web.app/main.dart.js:135700:45)
at Object.egE (https://my-web-app-b67f4.web.app/main.dart.js:29573:5)
at Object.dJ8 (https://my-web-app-b67f4.web.app/main.dart.js:29537:5)
at bs8.alY (https://my-web-app-b67f4.web.app/main.dart.js:136158:11)
at bs8.aG3 (https://my-web-app-b67f4.web.app/main.dart.js:136162:22)
at aiq.aVg (https://my-web-app-b67f4.web.app/main.dart.js:150561:45)
at a82.atO (https://my-web-app-b67f4.web.app/main.dart.js:132893:52)
''');
      final previousReleaseStack = StackTrace.fromString('''
at Object.aW (https://my-web-app-b67f4.web.app/main.dart.js:3974:30)
at azw.gN (https://my-web-app-b67f4.web.app/main.dart.js:118480:18)
at azw.gng (https://my-web-app-b67f4.web.app/main.dart.js:118481:18)
at ir.ge3 (https://my-web-app-b67f4.web.app/main.dart.js:135213:45)
at Object.efG (https://my-web-app-b67f4.web.app/main.dart.js:29571:5)
at Object.dIe (https://my-web-app-b67f4.web.app/main.dart.js:29535:5)
at brF.alP (https://my-web-app-b67f4.web.app/main.dart.js:135786:11)
at brF.aFP (https://my-web-app-b67f4.web.app/main.dart.js:135790:22)
at ail.aUW (https://my-web-app-b67f4.web.app/main.dart.js:150265:45)
at a8_.atB (https://my-web-app-b67f4.web.app/main.dart.js:132591:52)
''');

      for (final stack in [currentReleaseStack, previousReleaseStack]) {
        expect(
          ErrorReporter.instance
              .isIgnorableFlutterWebFocusTraversalLayoutErrorForTesting(
            message,
            stack,
          ),
          isTrue,
        );
      }
    },
  );

  test('does not ignore unrelated RenderBox layout errors', () {
    const message = 'Bad state: RenderBox was not laid out: RenderFlex#1234';
    final stack = StackTrace.fromString('''
at Object.throwError (main.dart.js:1:1)
at CalendarEventsPage.build (main.dart.js:2:1)
at RenderFlex.performLayout (main.dart.js:3:1)
''');

    expect(
      ErrorReporter.instance
          .isIgnorableFlutterWebFocusTraversalLayoutErrorForTesting(
        message,
        stack,
      ),
      isFalse,
    );
  });

  test('validates Sentry DSN format and rejects malformed commands', () {
    expect(
      ErrorReporter.isValidSentryDsn(
        'https://abc123@o456.ingest.us.sentry.io/789',
      ),
      isTrue,
    );
    expect(ErrorReporter.isValidSentryDsn(''), isFalse);
    expect(
      ErrorReporter.isValidSentryDsn(
        'gh secret set SENTRY_AUTH_TOKEN --repo kanta13jp1/my_web_app',
      ),
      isFalse,
    );
    expect(
      ErrorReporter.isValidSentryDsn('https://sentry.io/123'),
      isFalse,
    );
  });

  test('buildSentryUser includes only opaque user ID and omits email PII', () {
    final user = ErrorReporter.buildSentryUser('synthetic-user-id');
    expect(user.id, 'synthetic-user-id');
    expect(user.email, isNull);
  });

  group('Client error PoC pipeline (#2768)', () {
    tearDown(() {
      ErrorReporter.instance.resetForTesting();
    });

    test('sanitizeMessage redacts emails, bearer tokens, and JWTs', () {
      const bearerHeader = 'Bearer ' 'sample_opaque_987';
      const jwtSample = 'eyJ' 'hbGciOiJIUzI1NiJ9.' 'payload123.sig456';
      const raw =
          'Failed for user@example.com with $bearerHeader and $jwtSample';
      final cleaned = ErrorReporter.sanitizeMessage(raw);
      expect(cleaned, isNot(contains('user@example.com')));
      expect(cleaned, isNot(contains('sample_opaque_987')));
      expect(cleaned, isNot(contains('payload123')));
      expect(cleaned, contains('[REDACTED_EMAIL]'));
      expect(cleaned, contains('Bearer [REDACTED]'));
      expect(cleaned, contains('[REDACTED_JWT]'));
    });

    test('buildTelemetryPayload creates structured non-public hub payload', () {
      final trace = StackTrace.fromString(
        List<String>.generate(10, (final i) => 'frame_$i').join('\n'),
      );
      final payload = ErrorReporter.buildTelemetryPayload(
        message: 'Checkout failed for alice@example.com',
        error: StateError('network timeout'),
        stackTrace: trace,
      );
      expect(payload['action'], 'feedback.submit');
      expect(payload['category'], 'bug');
      expect(payload['source'], 'auto_error_report');
      final msg = payload['message'] as String;
      expect(msg, startsWith('[自動エラー報告]'));
      expect(msg, contains('[REDACTED_EMAIL]'));
      expect(msg, contains('frame_5'));
      expect(msg, isNot(contains('frame_6')));
      expect(msg.length, lessThanOrEqualTo(2000));
    });

    test('dispatches PoC errors to Sentry & Supabase and enforces dedup/cap',
        () {
      final sentryEvents = <String>[];
      final hubPayloads = <Map<String, Object?>>[];
      ErrorReporter.instance.resetForTesting();
      ErrorReporter.instance.setTestSinks(
        sentrySink: (
          final message, {
          final Object? error,
          final StackTrace? stackTrace,
        }) {
          sentryEvents.add(message);
        },
        supabaseSink: hubPayloads.add,
        sentryEnabled: true,
        authenticated: true,
      );

      ErrorReporter.instance.report('First error user@example.com');
      ErrorReporter.instance.report('First error user@example.com');

      expect(sentryEvents.length, 1);
      expect(hubPayloads.length, 1);
      expect(sentryEvents.first, contains('[REDACTED_EMAIL]'));

      for (var i = 0; i < 12; i++) {
        ErrorReporter.instance.report('Distinct failure #$i');
      }
      final snap = ErrorReporter.instance.diagnosticSnapshot();
      expect(snap.sentryEnabled, isTrue);
      expect(snap.reportedCount, 10);
      expect(snap.suppressedDuplicateCount, 1);
      expect(snap.suppressedThrottleCount, 3);
      expect(hubPayloads.length, 10);
    });
  });

  group('Sentry beforeSend session dedupe and cap (MY-WEB-APP-4)', () {
    tearDown(() {
      ErrorReporter.instance.resetForTesting();
    });

    SentryEvent buildExceptionEvent({
      required String type,
      required String value,
      required String fileName,
      required String function,
      required int lineNo,
      required int colNo,
    }) {
      return SentryEvent(
        exceptions: [
          SentryException(
            type: type,
            value: value,
            stackTrace: SentryStackTrace(
              frames: [
                SentryStackFrame(
                  fileName: 'lib/app_root.dart',
                  function: 'runFrame',
                  lineNo: 10,
                  colNo: 1,
                ),
                SentryStackFrame(
                  fileName: fileName,
                  function: function,
                  lineNo: lineNo,
                  colNo: colNo,
                ),
              ],
            ),
          ),
        ],
      );
    }

    test('configures beforeSend while keeping sendDefaultPii disabled', () {
      final options = SentryFlutterOptions();
      ErrorReporter.instance.configureSentryForTesting(options);
      expect(options.beforeSend, isNotNull);
      expect(options.sendDefaultPii, isFalse);
    });

    test('deduplicates repeated CanvasKit null-check events per session', () {
      final hint = Hint();
      SentryEvent? first;
      var dropped = 0;

      for (var i = 0; i < 20; i++) {
        final event = buildExceptionEvent(
          type: 'NoSuchMethodError',
          value: 'Null check operator used on a null value',
          fileName: 'main.dart.js',
          function: 'hm1.a',
          lineNo: 117119,
          colNo: 33,
        );
        final res = ErrorReporter.instance.beforeSendSentryEvent(event, hint);
        if (i == 0) {
          first = res;
        } else if (res == null) {
          dropped++;
        }
      }

      expect(first, isNotNull);
      expect(dropped, 19);
      final snap = ErrorReporter.instance.diagnosticSnapshot();
      expect(snap.sentryReportedCount, 1);
      expect(snap.suppressedSentryDuplicateCount, 19);
      expect(snap.suppressedSentryThrottleCount, 0);
    });

    test('allows distinct exception locations while capping session at 10', () {
      final hint = Hint();

      final e1 = buildExceptionEvent(
        type: 'NoSuchMethodError',
        value: 'Null check operator used on a null value',
        fileName: 'surface.dart',
        function: 'Surface.rasterizeToCanvas',
        lineNo: 132,
        colNo: 20,
      );
      final e2 = buildExceptionEvent(
        type: 'NoSuchMethodError',
        value: 'Null check operator used on a null value',
        fileName: 'other_widget.dart',
        function: 'OtherWidget.build',
        lineNo: 42,
        colNo: 5,
      );

      expect(ErrorReporter.instance.beforeSendSentryEvent(e1, hint), isNotNull);
      expect(ErrorReporter.instance.beforeSendSentryEvent(e2, hint), isNotNull);
      var snap = ErrorReporter.instance.diagnosticSnapshot();
      expect(snap.sentryReportedCount, 2);
      expect(snap.suppressedSentryDuplicateCount, 0);

      for (var i = 0; i < 11; i++) {
        final distinct = SentryEvent(
          message: SentryMessage('Synthetic distinct failure #$i'),
        );
        ErrorReporter.instance.beforeSendSentryEvent(distinct, hint);
      }

      snap = ErrorReporter.instance.diagnosticSnapshot();
      expect(snap.sentryReportedCount, 10);
      expect(snap.suppressedSentryThrottleCount, 3);
    });

    test('sanitizes PII emails inside exception values before deduplicating',
        () {
      final hint = Hint();
      final e1 = buildExceptionEvent(
        type: 'StateError',
        value: 'Sync failed for alice@example.com',
        fileName: 'sync_service.dart',
        function: 'sync',
        lineNo: 88,
        colNo: 12,
      );
      final e2 = buildExceptionEvent(
        type: 'StateError',
        value: 'Sync failed for bob@example.org',
        fileName: 'sync_service.dart',
        function: 'sync',
        lineNo: 88,
        colNo: 12,
      );

      expect(ErrorReporter.instance.beforeSendSentryEvent(e1, hint), isNotNull);
      expect(ErrorReporter.instance.beforeSendSentryEvent(e2, hint), isNull);
      final snap = ErrorReporter.instance.diagnosticSnapshot();
      expect(snap.sentryReportedCount, 1);
      expect(snap.suppressedSentryDuplicateCount, 1);
    });
  });
}
