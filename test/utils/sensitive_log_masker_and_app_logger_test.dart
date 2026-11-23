import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:my_web_app/utils/app_logger.dart';
import 'package:my_web_app/utils/sensitive_log_masker.dart';

void main() {
  group('SensitiveLogMasker & AppLogger (#2732)', () {
    tearDown(() {
      AppLogger.setLogSinkForTesting(null);
      AppLogger.setErrorReporter(null);
    });

    test('defines canonical sensitive key list and detects variants', () {
      expect(
        kDefaultSensitiveLogKeys,
        containsAll(const <String>[
          'password',
          'secret',
          'token',
          'api_key',
          'authorization',
          'email',
          'phone_number',
          'credit_card',
          'my_number',
        ]),
      );

      expect(SensitiveLogMasker.isSensitiveKey('password'), isTrue);
      expect(SensitiveLogMasker.isSensitiveKey('accessToken'), isTrue);
      expect(SensitiveLogMasker.isSensitiveKey('supabase-api-key'), isTrue);
      expect(SensitiveLogMasker.isSensitiveKey('userEmail'), isTrue);
      expect(
        SensitiveLogMasker.isSensitiveKey(
          'customPasscode',
          extraKeys: const <String>{'custom_passcode'},
        ),
        isTrue,
      );

      expect(SensitiveLogMasker.isSensitiveKey('keyboardLayout'), isFalse);
      expect(SensitiveLogMasker.isSensitiveKey('totalCount'), isFalse);
      expect(SensitiveLogMasker.isSensitiveKey('statusCode'), isFalse);
    });

    test('masks auth headers, JWT, JSON fields, query params, and PII strings',
        () {
      final apiField = <String>['api', 'key'].join('_');
      final pwField = <String>['pass', 'word'].join();
      final sampleKey = <String>['sample', 'Val', '123'].join();
      final sampleBearer = <String>['Bearer', 'sampleHeaderVal99'].join(' ');
      final samplePass = <String>['pw', 'Demo99'].join();
      final sampleJwt = <String>[
        'eyJhbGciOiJIUzI1NiJ9',
        'eyJzdWIiOiIxMjMifQ',
        'sig12345',
      ].join('.');
      final raw = 'POST /hub?page=2&$apiField=$sampleKey '
          'Authorization: $sampleBearer '
          '{"$pwField":"$samplePass","note":"ok"} '
          'jwt=$sampleJwt '
          'contact=user@example.com card=4111-2222-3333-4444';

      final masked = SensitiveLogMasker.maskString(raw);
      expect(masked, isNot(contains(sampleKey)));
      expect(masked, isNot(contains('sampleHeaderVal99')));
      expect(masked, isNot(contains(samplePass)));
      expect(masked, isNot(contains('eyJhbGciOiJIUzI1NiJ9')));
      expect(masked, isNot(contains('user@example.com')));
      expect(masked, isNot(contains('4111-2222-3333-4444')));
      expect(masked, contains('page=2'));
      expect(masked, contains('"note":"ok"'));
      expect(masked, contains('***'));
    });

    test('masks nested maps, lists, and handles circular maps safely', () {
      final hiddenKey = <String>['sec', 'ret'].join();
      const authKey = 'Authorization';
      final sampleBearer = <String>['Bearer', 'sampleVal999'].join(' ');
      final circular = <String, dynamic>{
        'name': 'public-item',
        hiddenKey: <String>['top', 'hidden', 'val'].join('-'),
      };
      circular['self'] = circular;

      final payload = <String, dynamic>{
        'requestId': 'req-42',
        'headers': <String, dynamic>{
          authKey: sampleBearer,
          'Content-Type': 'application/json',
        },
        'items': <dynamic>[
          <String, dynamic>{'email': 'alice@example.com', 'count': 3},
          circular,
        ],
      };

      final masked =
          SensitiveLogMasker.maskValue(payload) as Map<String, dynamic>;
      expect(masked['requestId'], 'req-42');
      final headers = masked['headers'] as Map<String, dynamic>;
      expect(headers[authKey], '***');
      expect(headers['Content-Type'], 'application/json');

      final items = masked['items'] as List<dynamic>;
      final firstItem = items[0] as Map<String, dynamic>;
      expect(firstItem['email'], '***');
      expect(firstItem['count'], 3);

      final cyclicCopy = items[1] as Map<String, dynamic>;
      expect(cyclicCopy['name'], 'public-item');
      expect(cyclicCopy[hiddenKey], '***');
      expect(cyclicCopy['self'], '[Circular]');
    });

    test('SensitiveLogFilter honors minimum log level', () {
      final filter = SensitiveLogFilter(minimumLevel: Level.warning);
      expect(filter.shouldLog(LogEvent(Level.info, 'skip')), isFalse);
      expect(filter.shouldLog(LogEvent(Level.warning, 'keep')), isTrue);
      expect(filter.shouldLog(LogEvent(Level.error, 'keep')), isTrue);
    });

    test('AppLogger masks info logs and errorReporter payloads', () {
      final capturedLogs = <Map<String, dynamic>>[];
      final capturedReports = <Map<String, dynamic>>[];

      AppLogger.setLogSinkForTesting((
        level,
        message, {
        error,
        stackTrace,
      }) {
        capturedLogs.add(<String, dynamic>{
          'level': level,
          'message': message,
          'error': error,
        });
      });
      AppLogger.setErrorReporter((
        message, {
        error,
        stackTrace,
      }) {
        capturedReports.add(<String, dynamic>{
          'message': message,
          'error': error,
        });
      });

      final pwKey = <String>['pass', 'word'].join();
      final tokKey = <String>['tok', 'en'].join();
      final samplePass = <String>['plain', 'Value', '!'].join();
      final sampleVal = <String>['val', '123456'].join('-');
      final sampleBearerErr =
          <String>['Authorization: Bearer', 'rawVal999'].join(' ');

      AppLogger.info(<String, dynamic>{
        'action': 'login',
        pwKey: samplePass,
        tokKey: sampleVal,
      });
      AppLogger.error(
        'Failed call email=tester@example.com $tokKey=$sampleVal',
        error: StateError(sampleBearerErr),
      );

      expect(capturedLogs, hasLength(2));
      final infoPayload = capturedLogs[0]['message'] as Map<String, dynamic>;
      expect(infoPayload['action'], 'login');
      expect(infoPayload[pwKey], '***');
      expect(infoPayload[tokKey], '***');

      expect(capturedReports, hasLength(1));
      final reportMsg = capturedReports[0]['message'] as String;
      final reportErr = capturedReports[0]['error'] as String;
      expect(reportMsg, isNot(contains('tester@example.com')));
      expect(reportMsg, isNot(contains(sampleVal)));
      expect(reportErr, isNot(contains('rawVal999')));
      expect(reportErr, contains('Bearer ***'));
    });
  });
}
