import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/utils/error_reporter.dart';

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
}
