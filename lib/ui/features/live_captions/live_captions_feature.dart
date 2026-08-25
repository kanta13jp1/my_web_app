import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'data/live_caption_translation_gateway.dart';
import 'services/live_speech_recognizer.dart';
import 'view_models/live_captions_view_model.dart';
import 'views/live_captions_page.dart';

class LiveCaptionsFeature extends StatelessWidget {
  const LiveCaptionsFeature({
    super.key,
    this.translationGateway,
    this.speechRecognizer,
  });

  final LiveCaptionTranslationGateway? translationGateway;
  final LiveSpeechRecognizer? speechRecognizer;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LiveCaptionsViewModel>(
      create: (_) => LiveCaptionsViewModel(
        translationGateway:
            translationGateway ?? AiLiveCaptionTranslationGateway(),
        speechRecognizer: speechRecognizer ?? createLiveSpeechRecognizer(),
      ),
      child: const LiveCaptionsPage(),
    );
  }
}
