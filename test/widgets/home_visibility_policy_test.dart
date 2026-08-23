import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/home_visibility_policy.dart';

void main() {
  test('hides internal operations from the standard home', () {
    expect(
      HomeVisibilityPolicy.showInternalOperations(
        showLegacyOperations: false,
        showLegacyHomeSections: false,
      ),
      isFalse,
    );
  });

  test('keeps internal operations available in the legacy operations mode', () {
    expect(
      HomeVisibilityPolicy.showInternalOperations(
        showLegacyOperations: true,
        showLegacyHomeSections: false,
      ),
      isTrue,
    );
  });
}
