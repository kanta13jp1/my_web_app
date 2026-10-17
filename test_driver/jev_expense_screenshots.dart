import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
      writeResponseOnFailure: true,
      onScreenshot: (name, image, [args]) async {
        final directory = Directory('.ci-logs/jev-screenshots');
        await directory.create(recursive: true);
        await File('${directory.path}/$name.png').writeAsBytes(image);
        // The image is evidence for visual review, not an automatic visual pass.
        return image.isNotEmpty;
      },
    );
