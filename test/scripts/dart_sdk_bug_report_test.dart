import 'package:flutter_test/flutter_test.dart';

import '../../scripts/dart_sdk_bug_report.dart';

void main() {
  group('dart_sdk_bug_report', () {
    test('extracts final analyzer error and Windows crash exit code', () {
      const log = '''
[Info] Starting analysis server
[Error] The Dart Analyzer has terminated.
mojibake: \\u7e67\\uff7d\\u7e5d analyzer crash line
Process exited with code 3221226505
''';

      final summary = parseAnalyzerLog(log);

      expect(summary.exitCode, '3221226505');
      expect(summary.finalError, contains('mojibake:'));
      expect(
        summary.tail,
        contains('[Error] The Dart Analyzer has terminated.'),
      );
    });

    test('builds Dart SDK issue Markdown with expected sections', () {
      const input = BugReportInput(
        title: 'Analyzer crash in VS Code',
        expected: 'Analyzer keeps running.',
        reproductionSteps: '1. Open project\n2. Edit a Dart file',
        logPath: 'C:/tmp/dart.log',
        logContent: 'The Dart Analyzer has terminated.\nexit code: 3221226505',
        dartVersion: 'Dart SDK version: 3.10.0',
        dartInfo: 'Dart SDK: 3.10.0\nFlutter: 3.38.0',
        osInfo: 'OS: windows 10.0',
      );

      final markdown = buildDartSdkBugReport(input);

      expect(markdown, contains('## Expected behavior'));
      expect(markdown, contains('## Actual behavior'));
      expect(markdown, contains('## Environment'));
      expect(markdown, contains('## dart info'));
      expect(markdown, contains('3221226505'));
      expect(markdown, contains('C:/tmp/dart.log'));
    });
  });
}
