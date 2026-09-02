import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'data/video_studio_gateway.dart';
import 'view_models/video_studio_view_model.dart';
import 'views/video_studio_page.dart';

class VideoStudioFeature extends StatelessWidget {
  const VideoStudioFeature({super.key, this.gateway, this.initialUri});

  final VideoStudioGateway? gateway;
  final Uri? initialUri;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<VideoStudioViewModel>(
      create: (_) =>
          VideoStudioViewModel(gateway: gateway ?? SupabaseVideoStudioGateway())
            ..load(currentUri: initialUri ?? Uri.base),
      child: const VideoStudioPage(),
    );
  }
}
