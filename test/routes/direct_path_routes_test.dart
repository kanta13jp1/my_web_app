import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('static Navigator.pushNamed paths are registered in main routes', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final registeredRoutes = RegExp(
      r"case\s+'([^']+)'",
    ).allMatches(mainSource).map((match) => match.group(1)!).toSet();

    final pushedRoutes = <String>{};
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      final matches = RegExp(
        r"""push(?:Replacement)?Named(?:AndRemoveUntil)?\s*\([\s\S]{0,240}?['"](/[^'"?$]+)['"]""",
      ).allMatches(source);
      for (final match in matches) {
        final route = match.group(1)!;
        if (route.contains(r'$') || route.contains('?')) continue;
        pushedRoutes.add(route);
      }
    }

    final missing = pushedRoutes
        .where((route) => !registeredRoutes.contains(route))
        .toList()
      ..sort();

    expect(missing, isEmpty);
  });

  test('home catalog page classes have direct path route builders', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final routedPageClasses = RegExp(
      r"case\s+'([^']+)'[\s\S]*?builder:\s*\([^)]*\)\s*=>\s*(?:const\s+)?([A-Za-z0-9_]+)\(",
    ).allMatches(mainSource).map((match) => match.group(2)!).toSet();

    final catalogSource =
        File('lib/data/home_tool_catalog.dart').readAsStringSync();
    final catalogPageClasses = RegExp(
      r'_pushPage\(context,\s*(?:const\s+)?([A-Za-z0-9_]+)\(',
    ).allMatches(catalogSource).map((match) => match.group(1)!).toSet();

    const dynamicOnlyPages = {
      'PublicProfilePage',
    };
    final missing = catalogPageClasses
        .where(
          (pageClass) =>
              !dynamicOnlyPages.contains(pageClass) &&
              !routedPageClasses.contains(pageClass),
        )
        .toList()
      ..sort();

    expect(missing, isEmpty);
  });
}
