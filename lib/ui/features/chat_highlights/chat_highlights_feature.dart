import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'data/chat_highlight_export_gateway.dart';
import 'data/chat_highlight_gateway.dart';
import 'view_models/chat_highlights_view_model.dart';
import 'views/chat_highlights_page.dart';

class ChatHighlightsFeature extends StatelessWidget {
  const ChatHighlightsFeature({
    super.key,
    this.gateway,
    this.exportGateway,
    this.now,
  });

  static const routeName = '/chat-highlights';

  final ChatHighlightGateway? gateway;
  final ChatHighlightExportGateway? exportGateway;
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ChatHighlightsViewModel>(
      create: (_) => ChatHighlightsViewModel(
        gateway: gateway ?? SharedPreferencesChatHighlightGateway(),
        exportGateway:
            exportGateway ?? const BrowserChatHighlightExportGateway(),
        now: now,
      )..load(),
      child: const ChatHighlightsPage(),
    );
  }
}
