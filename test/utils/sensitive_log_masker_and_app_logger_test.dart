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
      const raw =
          'POST /hub?api_key=abc123def&page=2 Authorization: Bearer mySecretJwtHeaderValue '
          '{"password":"p@ss123","note":"ok"} jwt=eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.sig12345 '
          'contact=user@example.com card=4111-2222-3333-4444';

      final masked = SensitiveLogMasker.maskString(raw);
      expect(masked, isNot(contains('abc123def')));
      expect(masked, isNot(contains('mySecretJwtHeaderValue')));
      expect(masked, isNot(contains('p@ss123')));
      expect(masked, isNot(contains('eyJhbGciOiJIUzI1NiJ9')));
      expect(masked, isNot(contains('user@example.com')));
      expect(masked, isNot(contains('4111-2222-3333-4444')));
      expect(masked, contains('page=2'));
      expect(masked, contains('"note":"ok"'));
      expect(masked, contains('***'));
    });

    test('masks nested maps, lists, and handles circular maps safely', () {
      final circular = <String, dynamic>{
        'name': 'public-item',
        'secret': 'top-secret-value',
      };
      circular['self'] = circular;

      final payload = <String, dynamic>{
        'requestId': 'req-42',
        'headers': <String, dynamic>{
          'Authorization': 'Bearer tok_999',
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
      expect(headers['Authorization'], '***');
      expect(headers['Content-Type'], 'application/json');

      final items = masked['items'] as List<dynamic>;
      final firstItem = items[0] as Map<String, dynamic>;
      expect(firstItem['email'], '***');
      expect(firstItem['count'], 3);

      final cyclicCopy = items[1] as Map<String, dynamic>;
      expect(cyclicCopy['name'], 'public-item');
      expect(cyclicCopy['secret'], '***');
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

      AppLogger.info(<String, dynamic>{
        'action': 'login',
        'password': 'plainPassword!',
        'token': 'tok-123456',
      });
      AppLogger.error(
        'Failed call email=tester@example.com token=secret_xyz',
        error: StateError('Authorization: Bearer raw_bearer_999'),
      );

      expect(capturedLogs, hasLength(2));
      final infoPayload = capturedLogs[0]['message'] as Map<String, dynamic>;
      expect(infoPayload['action'], 'login');
      expect(infoPayload['password'], '***');
      expect(infoPayload['token'], '***');

      expect(capturedReports, hasLength(1));
      final reportMsg = capturedReports[0]['message'] as String;
      final reportErr = capturedReports[0]['error'] as String;
      expect(reportMsg, isNot(contains('tester@example.com')));
      expect(reportMsg, isNot(contains('secret_xyz')));
      expect(reportErr, isNot(contains('raw_bearer_999')));
      expect(reportErr, contains('Bearer ***'));
    });
  });
}
