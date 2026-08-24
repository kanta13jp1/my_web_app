import 'package:url_launcher/url_launcher.dart';

abstract interface class GuitarLessonLinkService {
  Future<bool> openExternal(Uri uri);
}

class UrlLauncherGuitarLessonLinkService implements GuitarLessonLinkService {
  const UrlLauncherGuitarLessonLinkService();

  @override
  Future<bool> openExternal(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
