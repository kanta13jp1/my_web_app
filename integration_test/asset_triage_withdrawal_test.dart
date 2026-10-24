import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Scrollable, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'asset_triage_withdrawal_scenarios.dart' as scenarios;

class _DiagnosticBinding extends IntegrationTestWidgetsFlutterBinding {
  @override
  void reportExceptionNoticed(FlutterErrorDetails exception) {
    final data = reportData ??= <String, dynamic>{};
    data.putIfAbsent('firstFrameworkError', () => exception.toString());
    final errors = data.putIfAbsent(
      'frameworkErrors',
      () => <String>[],
    ) as List<String>;
    final message = exception.toString();
    if (errors.length < 20 && !errors.contains(message)) {
      errors.add(message);
    }
    super.reportExceptionNoticed(exception);
  }
}

// Synthetic persistence boundaries; no authenticated backend or real withdrawal.
void main() {
  final binding = _DiagnosticBinding();
  const mobile = bool.fromEnvironment('TRIAGE_MOBILE');
  const viewport = mobile ? Size(390, 851) : Size(1440, 1000);
  scenarios.main(
    evidenceViewport: viewport,
    captureEvidence: (tester, name, target) async {
      for (var frame = 0; frame < 3; frame++) {
        // Canvas-rendered Flutter motion: advance beyond ordinary transitions.
        await tester.pump(const Duration(milliseconds: 500));
        // Layout can move after the preceding frame. Reposition immediately
        // before capture and reject evidence whose target is off screen.
        await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
        await tester.pump();
        expect(target.hitTestable(), findsOneWidget);
        final targetRect = tester.getRect(target);
        await binding.takeScreenshot(
          '${mobile ? 'mobile' : 'desktop'}-$name-$frame',
          <String, Object?>{
            'width': viewport.width,
            'height': viewport.height,
            'devicePixelRatio': mobile ? 2.75 : 1.0,
            'frame': frame,
            'targetLeft': targetRect.left,
            'targetTop': targetRect.top,
            'targetWidth': targetRect.width,
            'targetHeight': targetRect.height,
            'targetHitTestable': true,
            'settling': 'Flutter pump 500ms; injected date stays fixed',
          },
        );
      }
    },
  );
}
