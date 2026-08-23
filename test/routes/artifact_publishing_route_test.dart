import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'admin artifact publishing page has a stable named route and entry point',
      () {
    final mainSource = File(
      'lib/main.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    final adminSource = File(
      'lib/pages/admin_analytics_page.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');

    expect(mainSource, contains("case '/admin/artifact-publishing':"));
    expect(mainSource, contains('const AdminArtifactPublishingPage()'));
    expect(
      adminSource,
      contains(
        "Navigator.pushNamed(\n                          context,\n                          '/admin/artifact-publishing'",
      ),
    );
  });
}
