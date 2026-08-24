import 'package:flutter/material.dart';

/// Opens an embedded YouTube lesson without a modal barrier.
///
/// Flutter Web represents a dialog's modal barrier as a full-screen hit-test
/// element. That element can sit above an [HtmlElementView] in the browser and
/// prevent the YouTube iframe from receiving pointer events. A regular opaque
/// page route has no modal barrier, keeps the previous page non-interactive,
/// and lets the embedded player receive clicks directly.
class AiUniversityYoutubeViewerRoute<T> extends MaterialPageRoute<T> {
  AiUniversityYoutubeViewerRoute({
    required WidgetBuilder viewerBuilder,
    super.settings,
  }) : super(
          fullscreenDialog: true,
          builder: (routeContext) => ColoredBox(
            color: const Color(0xFF0A0A0A),
            child: SafeArea(child: Center(child: viewerBuilder(routeContext))),
          ),
        );
}

Future<T?> showAiUniversityYoutubeViewer<T>({
  required BuildContext context,
  required WidgetBuilder viewerBuilder,
  bool useRootNavigator = true,
}) {
  return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
    AiUniversityYoutubeViewerRoute<T>(
      viewerBuilder: viewerBuilder,
      settings: const RouteSettings(name: '/ai-university?tab=openai'),
    ),
  );
}
